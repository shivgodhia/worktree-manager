# wt - Git Worktree Manager for Zsh

> **⚠️ This project is no longer maintained.** Use [**grove**](https://github.com/shivgodhia/grove) instead — it does everything `wt` does plus multi-repo workspace support (group multiple projects into a single workspace with one branch name across all of them). All ongoing development happens in grove.

A lightweight Zsh function that manages [git worktrees](https://git-scm.com/docs/git-worktree) across multiple projects. Navigate to any worktree with a single command — if it doesn't exist yet, it gets created automatically.

## Why worktrees?

You're running AI coding agents — [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Codex](https://github.com/openai/codex), [OpenCode](https://opencode.ai/) — and you want to run multiple agents in parallel. The problem: they all need their own checkout or they'll stomp on each other's changes. Git worktrees give each agent an isolated working directory backed by the same repo, no cloning required.

[Conductor](https://www.conductor.build/) gives you a nice UI for this, but it falls apart when you need fine-grained control — stacking PRs with Graphite, running custom post-setup hooks, or integrating with your existing workflow. Wrapper UIs also lag behind the native tools: e.g. Conductor doesn't support Codex's Plan mode. `wt` gives you full control over your worktrees while still being a one-liner.

It works with any terminal-based agent because you're running the real CLI, not a wrapper. No plugins, no feature gaps, no lock-in.

## How it works

You register your git repos once. After that, `wt <project> <worktree>` is all you need:

1. Checks if the worktree already exists locally — if so, opens it.
2. If not, checks whether the branch is already checked out in another worktree and reuses it.
3. If still not found, fetches from origin:
   - **Branch exists on origin** → creates a worktree tracking it
   - **Branch doesn't exist** → creates a new branch `<prefix>/worktree-name` off `origin/main`
4. Opens a tmux session for the worktree, runs post-create hooks (dependency install, codegen, etc.) and approves direnv if applicable.
5. Runs any post-startup hooks (e.g. launching an AI agent, customizing your tmux layout).

That's it. One command to go from "I need to work on X" to being inside an isolated checkout with everything set up.

## Features

- **Smart branch resolution**: If a worktree doesn't exist, `wt` fetches from origin and checks if a matching remote branch exists. If so, it creates a tracking worktree. Otherwise, it creates a new branch named `<prefix>/<worktree-name>` off `origin/main` (all configurable).
- **Post-create hooks**: Run project-specific setup commands (dependency install, codegen, etc.) automatically when a worktree is created.
- **Post-startup hooks**: Run commands every time a new tmux session is created for a worktree — launch an AI agent, add tmux splits/panes, or any per-session setup.
- **tmux session integration**: Each worktree gets its own tmux session, so every agent runs in an isolated terminal that you can switch between and come back to, maintaining your context.
- **Fuzzy-find completion**: Press Tab and get an interactive fzf picker for projects, worktrees, and flags. Falls back to standard Zsh completion if fzf isn't installed.
- **direnv support**: Automatically runs `direnv allow` if the worktree contains an `.envrc` file.
- **Run commands in-place**: Pass a command after the worktree name to execute it there without changing your current directory.

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
4. Ask if I want an AI agent (like Claude Code) to launch automatically in every new worktree session.
   Explain this is a post-startup hook that runs every time a tmux session is created, not just on first
   creation. If yes, ask which agent command to use (default: `claude`) and set it as
   `WT_DEFAULT_POST_STARTUP_COMMAND`. Then ask if any specific projects need a different startup
   command (e.g. a tmux split pane layout) — if so, configure those as per-project overrides
   with `wt_post_startup_commands[project]`.
5. Copy worktree-manager.local.example.zsh to worktree-manager.local.zsh, then edit it with all the
   collected configuration.
6. Ask if I want terminal tab titles to automatically show the worktree name. Explain that this
   makes tmux set the terminal tab title to the session name (e.g. "wt/my-app/feature-auth"), so
   each tab is easy to identify. If yes, find my tmux config (~/.config/tmux/tmux.conf or
   ~/.tmux.conf) and add `set-option -g set-titles on` and `set-option -g set-titles-string '#S'`
   if they aren't already present. Then ask which terminal emulator they use (e.g. iTerm2, Alacritty,
   Kitty, WezTerm, Terminal.app) and walk them through enabling the setting that lets applications
   change the tab/window title — for example, in iTerm2 this is under Profiles → General → Title
   where "Applications in terminal may change the title" must be checked.
7. Ask if they want recommended tmux settings for a better worktree experience. Explain that
   `set -g mouse on` enables mouse support (scroll through output, click to switch panes, drag
   to resize them) and `set -g history-limit 50000` increases the scrollback buffer so you don't
   lose output from long-running commands. If yes, find their tmux config and add these settings
   if they aren't already present, then reload with `tmux source-file <path-to-config>`.
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
- `WT_DEFAULT_POST_STARTUP_COMMAND` — command to run in every new tmux session (default: none). Per-project `wt_post_startup_commands` entries override this.

#### Post-create hooks

Commands that run automatically when a new worktree is created for a project — useful for installing dependencies, generating code, etc.

Uncomment and edit the examples in `worktree-manager.zsh`:

```sh
wt_post_create_commands[my-api]="yarn && npx prisma generate"
wt_post_create_commands[my-app]="pnpm install"
```

#### Post-startup hooks

Commands that run every time a new tmux session is created for a worktree — not just the first time. These run after post-create hooks (if any). Use them to launch AI agents, set up tmux pane layouts, or any per-session setup that should apply to every worktree.

Set a default for all projects with `WT_DEFAULT_POST_STARTUP_COMMAND`, then override specific projects as needed:

```sh
# Launch Claude Code in every new worktree session (all projects)
WT_DEFAULT_POST_STARTUP_COMMAND="claude"

# Override for a specific project — e.g. add a split pane
wt_post_startup_commands[my-api]="tmux split-window -h -c '#{pane_current_path}' && claude"
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

## Recommended tmux settings

Add these to your tmux config (`~/.config/tmux/tmux.conf` or `~/.tmux.conf`):

```
# Enable mouse support (scroll, click panes, resize)
set -g mouse on

# Increase scrollback buffer
set -g history-limit 50000

# Show worktree name as terminal tab title
set-option -g set-titles on
set-option -g set-titles-string '#S'
```

Then reload your config:

```sh
tmux source-file ~/.config/tmux/tmux.conf
```

**Mouse support** lets you scroll through output, click to switch panes, and drag to resize them — it just works so much better.

**Tab titles** — `wt` creates tmux sessions named `wt/<project>/<worktree>`, and `set-titles` pushes that to your terminal as the tab name. Instead of a sea of identical "zsh" tabs, you see exactly which project and worktree each tab is for. Ghostty picks up the tmux title automatically — no extra config needed. In iTerm2, you'll also need to enable **Profiles → General → Title → "Applications in terminal may change the title"**.

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
- **Fuzzy-find tab completion** — fzf-powered interactive picker for projects and worktrees, with fallback to standard Zsh completion
- **Removed legacy `core-wts` path handling** from the original
