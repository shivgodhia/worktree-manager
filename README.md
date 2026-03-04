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

1. Clone this repo (or copy `worktree-manager.zsh` somewhere):

   ```sh
   git clone https://github.com/YOUR_USERNAME/wt.git ~/.zsh/wt
   ```

2. Add to your `.zshrc`:

   ```sh
   source ~/.zsh/wt/worktree-manager.zsh
   ```

3. Restart your terminal or run `source ~/.zshrc`.

4. Verify: type `wt ` and press Tab — you should see your projects listed.

## Configuration

Set these environment variables in your `.zshrc` **before** sourcing the script:

```sh
# Where your git repos live (default: ~/projects)
WT_PROJECTS_DIR="$HOME/projects"

# Where worktrees are created (default: ~/projects/worktrees)
WT_WORKTREES_DIR="$HOME/projects/worktrees"

# Base branch for new worktrees (default: origin/main)
WT_BASE_BRANCH="origin/main"
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

## Post-create hooks

Register commands to run automatically when a new worktree is created for a project. This is useful for installing dependencies, generating code, etc.

Add these in your `.zshrc` **after** sourcing the script:

```sh
source ~/.zsh/wt/worktree-manager.zsh

# Install deps and generate Prisma client for a Node project
wt_post_create_commands[backend]="yarn && npx prisma generate"

# pnpm monorepo
wt_post_create_commands[frontend]="pnpm install"

# Python project
wt_post_create_commands[ml-service]="python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
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

## License

MIT
