# wt - Git Worktree Manager for Zsh

A lightweight Zsh function that manages [git worktrees](https://git-scm.com/docs/git-worktree) across multiple projects. Navigate to any worktree with a single command — if it doesn't exist yet, it gets created automatically.

## Why worktrees?

Git worktrees let you check out multiple branches of the same repo simultaneously, each in its own directory. This is useful when you:

- Want to work on a feature while keeping `main` clean for code review
- Need to run two branches side-by-side (e.g. comparing behavior)
- Want to hand a branch to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) without disrupting your working copy

`wt` wraps `git worktree` with project awareness, automatic branch creation, post-setup hooks, and tab completion.

## Directory structure

```
~/projects/                      # your git repos live here
├── my-app/                      # main repo checkout
├── backend/                     # another repo
└── worktrees/                   # all worktrees go here
    ├── my-app/
    │   ├── feature-auth/        # worktree → branch: yourname/feature-auth
    │   └── bugfix-header/       # worktree → branch: yourname/bugfix-header
    └── backend/
        └── add-caching/         # worktree → branch: yourname/add-caching
```

## Installation

Copy this prompt into Claude Code (or your AI tool of choice):

```
Clone https://github.com/shivgodhia/worktree-manager.git to ~/.zsh/wt and add `source ~/.zsh/wt/worktree-manager.zsh`
to my .zshrc.
Then open ~/.zsh/wt/worktree-manager.zsh and configure WT_PROJECTS_DIR and WT_WORKTREES_DIR to match where
my git repos live.
Add any post-create hooks I need for my projects.
```

Or do it manually:

1. Clone this repo:

   ```sh
   git clone https://github.com/shivgodhia/worktree-manager.git ~/.zsh/wt
   ```

2. Add to your `.zshrc`:

   ```sh
   source ~/.zsh/wt/worktree-manager.zsh
   ```

3. Edit `~/.zsh/wt/worktree-manager.zsh` to set your directories and post-create hooks.

4. Restart your terminal or run `source ~/.zshrc`.

## Configuration

Edit the variables at the top of `worktree-manager.zsh` to match your setup.

### Directories

- `WT_PROJECTS_DIR` — where your git repos live (default: `~/projects`)
- `WT_WORKTREES_DIR` — where worktrees are created (default: `$WT_PROJECTS_DIR/worktrees`)
- `WT_BASE_BRANCH` — base branch for new worktrees (default: `origin/main`)

### Post-create hooks

Commands that run automatically when a new worktree is created for a project — useful for installing dependencies, generating code, etc.

Uncomment and edit the examples in `worktree-manager.zsh`:

```sh
wt_post_create_commands[my-api]="yarn && npx prisma generate"
wt_post_create_commands[my-app]="pnpm install"
```

## Usage

```sh
wt <project> <worktree>              # cd to worktree (creates if needed)
wt <project> <worktree> <command>    # run a command in the worktree
wt --list                            # list all worktrees
wt --rm <project> <worktree>         # remove a worktree
wt --rm --force <project> <worktree> # force remove (uncommitted changes)
```

### Examples

```sh
# Jump into a worktree (creates it if it doesn't exist)
wt my-app feature-auth

# Run Claude Code in a worktree
wt my-app feature-auth claude

# Git operations in a worktree without leaving your current directory
wt backend add-caching git status
wt backend add-caching git diff

# List everything
wt --list

# Clean up when done
wt --rm my-app feature-auth
```

## Features

- **Auto-creation**: If a worktree doesn't exist, `wt` creates it with a branch named `<your-username>/<worktree-name>` based off `origin/main` (configurable via `WT_BASE_BRANCH`).
- **Post-create hooks**: Run project-specific setup commands (dependency install, codegen, etc.) automatically when a worktree is created.
- **direnv support**: Automatically runs `direnv allow` if the worktree contains an `.envrc` file.
- **Run commands in-place**: Pass a command after the worktree name to execute it there without changing your current directory.
- **Tab completion**: Full Zsh completion for project names, existing worktree names, `--list`/`--rm` flags, and common commands.

## How it works

1. `wt my-app feature-x` checks if `~/projects/worktrees/my-app/feature-x` exists.
2. If not, it runs `git fetch origin` in `~/projects/my-app`, then `git worktree add` to create the worktree with branch `yourname/feature-x` off `origin/main`.
3. It runs any registered post-create hooks and approves direnv if applicable.
4. Finally, it `cd`s you into the worktree (or runs your command there and returns).

## Requirements

- Zsh
- Git 2.5+ (for worktree support)

## Credits

Based on the worktree manager from [incident.io's blog post on shipping faster with Claude Code and git worktrees](https://incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees). This version adds:

- **Configurable directories and base branch** via variables at the top of the script (the original hard-coded `~/projects`)
- **Post-create hooks** (`wt_post_create_commands`) to run project-specific setup (e.g. `npm install`) automatically when a worktree is created
- **`git fetch` before creating worktrees** so new worktrees are based on the latest remote state
- **direnv support** — automatically runs `direnv allow` if the worktree has an `.envrc`
- **`--force` flag for removal** (`wt --rm --force`) to handle worktrees with uncommitted changes
- **Branch cleanup on removal** — `wt --rm` deletes the local branch as well as the worktree
- **Working tab completion** — inline `compdef`-based completion instead of writing to a file, with proper support for `--rm --force` and nested completions
- **Removed legacy `core-wts` path handling** from the original

