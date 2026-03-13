# worktree-manager.local.zsh — User-specific configuration
#
# Copy this file to worktree-manager.local.zsh and edit it.
# That file is gitignored, so your settings won't conflict with updates.

# Where your git projects live
WT_PROJECTS_DIR="$HOME/Desktop/clones/projects"

# Base branch for new worktrees (default: origin/main)
# WT_BASE_BRANCH="origin/main"

# Prefix for new branches when the name doesn't exist on remote (default: $USER)
# WT_BRANCH_PREFIX="$USER"

# Where worktrees are created (default: $WT_PROJECTS_DIR/worktrees)
# WT_WORKTREES_DIR="$WT_PROJECTS_DIR/worktrees"

# Post-create hooks — commands to run after creating a new worktree
# wt_post_create_commands[my-api]="yarn && npx prisma generate"
# wt_post_create_commands[my-app]="pnpm install"

# Post-startup hooks — commands to run every time a new tmux session is created
# for a worktree (after post-create hooks). Use for launching agents, tmux panes, etc.
# wt_post_startup_commands[my-app]="claude"
# wt_post_startup_commands[my-api]="tmux split-window -h -c '#{pane_current_path}' && claude"

# Any other env vars or shell config you need
