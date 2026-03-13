# wt - Git Worktree Manager for Zsh

A lightweight Zsh function that manages [git worktrees](https://git-scm.com/docs/git-worktree) across multiple projects. Navigate to any worktree with a single command — if it doesn't exist yet, it gets created automatically.

## Why worktrees?

You're running AI coding agents — [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Codex](https://github.com/openai/codex), [OpenCode](https://opencode.ai/) — and you want to run multiple agents in parallel. The problem: they all need their own checkout or they'll stomp on each other's changes. Git worktrees give each agent an isolated working directory backed by the same repo, no cloning required.

[Conductor](https://www.conductor.build/) gives you a nice UI for this, but it falls apart when you need fine-grained control — stacking PRs with Graphite, running custom post-setup hooks, or integrating with your existing workflow. Wrapper UIs also lag behind the native tools: e.g. Conductor doesn't support Codex's Plan mode. `wt` gives you full control over your worktrees while still being a one-liner.

It works with any terminal-based agent because you're running the real CLI, not a wrapper. No plugins, no feature gaps, no lock-in.

## Features

- **Smart branch resolution**: If a worktree doesn't exist, `wt` fetches from origin and checks if a matching remote branch exists. If so, it creates a tracking worktree. Otherwise, it creates a new branch named `<prefix>/<worktree-name>` off `origin/main` (configurable via `WT_BRANCH_PREFIX` and `WT_BASE_BRANCH`).
- **Post-create hooks**: Run project-specific setup commands (dependency install, codegen, etc.) automatically when a worktree is created.
- **direnv support**: Automatically runs `direnv allow` if the worktree contains an `.envrc` file.
- **Run commands in-place**: Pass a command after the worktree name to execute it there without changing your current directory.
- **tmux session integration**: Each worktree gets its own tmux session, so every agent runs in an isolated terminal that you can switch between and come back to.
- **Tab completion**: Full Zsh completion for project names, existing worktree names, `--list`/`--rm` flags, and common commands.

## Installation

Copy this prompt into Claude Code (or your AI tool of choice):

```
Clone https://github.com/shivgodhia/worktree-manager.git to ~/.zsh/wt and add `source ~/.zsh/wt/worktree-manager.zsh`
to my .zshrc. Then walk me through setting up ~/.zsh/wt/worktree-manager.local.zsh step by step, asking me
one question at a time:

1. Ask where my "projects directory" is — explain this is a single parent folder where all my git clones
   live, and that worktrees get created in a `worktrees/` subdirectory inside it. Suggest ~/projects as
   a default.
2. Ask what branch prefix I want (default: $USER). Explain this is used for naming new branches as
   <prefix>/branch-name.
3. Iteratively ask me for git repos to clone into the projects directory. For each one:
   - Clone it into the projects directory.
   - Read the project's README to figure out what setup commands are needed (e.g. npm install,
     pnpm install, yarn && npx prisma generate) and suggest a post-create hook for it.
   - After each clone, ask if I want to add another repo or if I'm done.
4. Copy worktree-manager.local.example.zsh to worktree-manager.local.zsh, then edit it with all the
   collected configuration.
5. Ask if I want terminal tab titles to automatically show the worktree name. Explain that this
   makes tmux set the terminal tab title to the session name (e.g. "wt/my-app/feature-auth"), so
   each tab is easy to identify. If yes, find my tmux config (~/.config/tmux/tmux.conf or
   ~/.tmux.conf) and add `set-option -g set-titles on` and `set-option -g set-titles-string '#S'`
   if they aren't already present. Then ask which terminal emulator they use (e.g. iTerm2, Alacritty,
   Kitty, WezTerm, Terminal.app) and walk them through enabling the setting that lets applications
   change the tab/window title — for example, in iTerm2 this is under Profiles → General → Title
   where "Applications in terminal may change the title" must be checked.
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

3. Edit `~/.zsh/wt/worktree-manager.zsh` to set your directories and post-create hooks (see below).

4. Restart your terminal or run `source ~/.zshrc`.

### Configuration

Edit the variables at the top of `worktree-manager.zsh` to match your setup.

#### Directories

- `WT_PROJECTS_DIR` — where your git repos live (default: `~/projects`)
- `WT_WORKTREES_DIR` — where worktrees are created (default: `$WT_PROJECTS_DIR/worktrees`)
- `WT_BASE_BRANCH` — base branch for new worktrees (default: `origin/main`)
- `WT_BRANCH_PREFIX` — prefix for new branch names (default: `$USER`, i.e. your system username)

#### Post-create hooks

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
wt --home                            # cd to projects directory
wt --help                            # show usage guide
```

### Examples

```sh
# Jump into a worktree (creates it if it doesn't exist)
wt my-app feature-auth

# Check out a teammate's branch from origin
wt my-app someone/fix-bug

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

## Claude Code skill

This repo includes a [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that lets you manage worktrees with `/worktree` inside Claude Code.

**Install:**

```sh
# From your project directory (or globally in ~/.claude/skills/)
cp -r ~/.zsh/wt/skills/worktree .claude/skills/
```

Or symlink it:

```sh
mkdir -p ~/.claude/skills
ln -s ~/.zsh/wt/skills/worktree ~/.claude/skills/worktree
```

**Usage inside Claude Code:**

```
/worktree create fix the auth bug
/worktree list
/worktree cd fix-auth-bug
/worktree delete fix-auth-bug
```

The skill parses your intent, generates a kebab-case worktree name, confirms with you, and runs the right `wt` commands.

## Terminal tab titles

When you use `wt` to jump into a worktree, it creates a tmux session named `wt/<project>/<worktree>`. If your terminal emulator is configured to display the tmux session name, each tab automatically gets a descriptive title — so instead of a sea of identical "zsh" tabs, you see exactly which project and worktree each tab is for.

To enable this, add the following to your tmux config (`~/.config/tmux/tmux.conf` or `~/.tmux.conf`):

```
set-option -g set-titles on
set-option -g set-titles-string '#S'
```

`#S` is the tmux session name. `set-titles on` tells tmux to push it to the terminal as the window title, which iTerm2 (and most other terminal emulators) display as the tab name.

In iTerm2, make sure **Profiles → General → Title** includes "Applications in terminal may change the title".

## Directory structure

```
~/projects/                      # your git repos live here
├── my-app/                      # main repo checkout
├── backend/                     # another repo
└── worktrees/                   # all worktrees go here
    ├── my-app/
    │   ├── feature-auth/        # worktree → branch: yourname/feature-auth
    │   ├── bugfix-header/       # worktree → branch: yourname/bugfix-header
    │   └── someone-fix-bug/     # worktree → tracks origin/someone/fix-bug
    └── backend/
        └── add-caching/         # worktree → branch: yourname/add-caching
```

## How it works

1. `wt my-app feature-x` checks if `~/projects/worktrees/my-app/feature-x` exists.
2. If not, it checks whether the branch is already checked out in another worktree.
3. If still not found, it fetches from origin and checks if `feature-x` exists as a remote branch:
   - **If it exists on origin** → creates a worktree tracking `origin/feature-x`
   - **If not** → creates a new branch `<prefix>/feature-x` off `origin/main` (prefix defaults to your username)
4. It runs any registered post-create hooks and approves direnv if applicable.
5. Finally, it `cd`s you into the worktree (or runs your command there and returns).

## Requirements

- Zsh
- Git 2.5+ (for worktree support)

## Credits

Based on the worktree manager from [incident.io's blog post on shipping faster with Claude Code and git worktrees](https://incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees). This version adds:

- **Configurable directories and base branch** via variables at the top of the script (the original hard-coded `~/projects`)
- **Post-create hooks** (`wt_post_create_commands`) to run project-specific setup (e.g. `npm install`) automatically when a worktree is created
- **Smart branch resolution** — fetches from origin first; if the branch exists remotely, creates a tracking worktree instead of a new branch
- **Slash-safe directory names** — branch names like `someone/fix-bug` map to directory `someone-fix-bug`
- **Duplicate checkout detection** — warns and reuses if a branch is already checked out in another worktree
- **direnv support** — automatically runs `direnv allow` if the worktree has an `.envrc`
- **`--force` flag for removal** (`wt --rm --force`) to handle worktrees with uncommitted changes
- **Branch cleanup on removal** — `wt --rm` deletes the local branch as well as the worktree
- **Working tab completion** — inline `compdef`-based completion instead of writing to a file, with proper support for `--rm --force` and nested completions
- **Removed legacy `core-wts` path handling** from the original
