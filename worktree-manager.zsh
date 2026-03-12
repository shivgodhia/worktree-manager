#!/usr/bin/env zsh
# wt - Multi-project git worktree manager with tmux session integration
#
# Manages git worktrees across multiple projects with auto-creation,
# per-project setup hooks, direnv support, tmux integration, and full
# tab completion.
#
# BRANCH RESOLUTION:
# When you run `wt <project> <name>`, it checks (in order):
# 1. Existing local worktree with that directory name → cd into it
# 2. Remote branch matching <name> on origin → create worktree tracking it
# 3. Otherwise → create new branch as <prefix>/<name> off origin/main
#
# TMUX INTEGRATION:
# Each worktree gets a dedicated tmux session named "wt/<project>/<worktree>".
# - `wt <project> <worktree>` creates/attaches to the tmux session
# - `wt --rm` kills the associated tmux session
# - `wt --list` shows tmux session status alongside worktrees
# - This prevents duplicate Claude Code sessions across terminal tabs
#
# See README.md for installation and usage instructions.

# ─── Configuration ───────────────────────────────────────────────────────────
# Edit these to match your setup:
WT_PROJECTS_DIR="$HOME/projects"
WT_WORKTREES_DIR="$WT_PROJECTS_DIR/worktrees"
WT_BASE_BRANCH="origin/main"
WT_BRANCH_PREFIX="$USER"

# Post-create hooks — commands to run after creating a worktree for a project.
# Add your own projects here:
typeset -gA wt_post_create_commands
# wt_post_create_commands[my-api]="yarn && npx prisma generate"
# wt_post_create_commands[my-app]="pnpm install"

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Generate tmux session name from project and worktree
# Format: wt/<project>/<worktree> (dots/colons replaced with underscores for tmux compat)
_wt_tmux_session_name() {
    local name="wt/$1/$2"
    # tmux doesn't allow dots or colons in session names
    echo "${name//[.:]/_}"
}

# ─── Main function ───────────────────────────────────────────────────────────
wt() {
    local projects_dir="$WT_PROJECTS_DIR"
    local worktrees_dir="$WT_WORKTREES_DIR"

    # Handle special flags
    if [[ "$1" == "--home" ]]; then
        cd "$projects_dir"
        return 0
    elif [[ "$1" == "--list" ]]; then
        echo "=== All Worktrees ==="
        if [[ -d "$worktrees_dir" ]]; then
            for project in $worktrees_dir/*(/N); do
                project_name=$(basename "$project")
                echo "\n[$project_name]"
                for wt in $project/*(/N); do
                    local wt_name=$(basename "$wt")
                    local session_name=$(_wt_tmux_session_name "$project_name" "$wt_name")
                    if tmux has-session -t "$session_name" 2>/dev/null; then
                        echo "  • $wt_name  [tmux: $session_name]"
                    else
                        echo "  • $wt_name"
                    fi
                done
            done
        fi
        return 0
    elif [[ "$1" == "--rm" ]]; then
        shift
        local force_flag=""
        if [[ "$1" == "--force" ]]; then
            force_flag="--force"
            shift
        fi
        local project="$1"
        local worktree="$2"
        if [[ -z "$project" || -z "$worktree" ]]; then
            echo "Usage: wt --rm [--force] <project> <worktree>"
            return 1
        fi
        # Sanitize worktree name for directory (replace / with -)
        local dir_name="${worktree//\//-}"
        local wt_path="$worktrees_dir/$project/$dir_name"
        if [[ ! -d "$wt_path" ]]; then
            echo "Worktree not found: $wt_path"
            return 1
        fi

        # Find the branch name from the worktree
        local branch_name
        branch_name=$(cd "$wt_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)

        (cd "$projects_dir/$project" && git worktree remove $force_flag "$wt_path")
        local rc=$?
        if [[ $rc -eq 0 && -n "$branch_name" && "$branch_name" != "HEAD" ]]; then
            (cd "$projects_dir/$project" && git branch -D "$branch_name" 2>/dev/null)
        fi

        # Kill associated tmux session last — if we're inside it, killing it
        # drops us out of tmux so nothing after this line runs
        if [[ $rc -eq 0 ]]; then
            local session_name=$(_wt_tmux_session_name "$project" "$dir_name")
            if tmux has-session -t "$session_name" 2>/dev/null; then
                echo "Killing tmux session: $session_name"
                tmux kill-session -t "$session_name"
            fi
        fi
        return $rc
    fi

    # Normal usage: wt <project> <worktree> [command...]
    local project="$1"
    local worktree="$2"
    shift 2 2>/dev/null
    local command=("$@")

    if [[ -z "$project" || -z "$worktree" ]]; then
        echo "Usage: wt <project> <worktree>              # attach to tmux session (creates worktree if needed)"
        echo "       wt <project> <worktree> <command>    # run command in worktree (no tmux)"
        echo "       wt --list"
        echo "       wt --rm [--force] <project> <worktree>"
        echo "       wt --home"
        return 1
    fi

    # Check if project exists
    if [[ ! -d "$projects_dir/$project" ]]; then
        echo "Project not found: $projects_dir/$project"
        return 1
    fi

    # Sanitize worktree name for directory (replace / with -)
    local dir_name="${worktree//\//-}"

    # 1. Check if worktree directory already exists
    local wt_path=""
    if [[ -d "$worktrees_dir/$project/$dir_name" ]]; then
        wt_path="$worktrees_dir/$project/$dir_name"
    fi

    # 2. Check if this branch is already checked out in another worktree
    if [[ -z "$wt_path" ]]; then
        local existing_path
        existing_path=$(cd "$projects_dir/$project" && git worktree list --porcelain | awk -v branch="branch refs/heads/$worktree" '/^worktree /{wt=$0} $0 == branch{print wt}' | sed 's/^worktree //')
        if [[ -n "$existing_path" && -d "$existing_path" ]]; then
            echo "Branch already checked out at: $existing_path"
            wt_path="$existing_path"
        fi
    fi

    # 3. Worktree doesn't exist — create it
    if [[ -z "$wt_path" ]]; then
        mkdir -p "$worktrees_dir/$project"
        wt_path="$worktrees_dir/$project/$dir_name"

        # Fetch and check if branch exists on origin
        echo "Fetching from origin..."
        (cd "$projects_dir/$project" && git fetch origin)

        local remote_exists
        remote_exists=$(cd "$projects_dir/$project" && git ls-remote --heads origin "$worktree" 2>/dev/null)

        if [[ -n "$remote_exists" ]]; then
            # Branch exists on origin — check it out as a tracking branch
            echo "Found remote branch: $worktree"
            echo "Creating worktree at $wt_path..."
            (cd "$projects_dir/$project" && git worktree add "$wt_path" -b "$worktree" "origin/$worktree") || {
                echo "Failed to create worktree"
                return 1
            }
        else
            # Branch doesn't exist on origin — create new branch with username prefix
            local branch_name="$WT_BRANCH_PREFIX/$worktree"
            echo "Creating new branch: $branch_name"
            echo "Creating worktree at $wt_path..."
            (cd "$projects_dir/$project" && git worktree add "$wt_path" -b "$branch_name" $WT_BASE_BRANCH) || {
                echo "Failed to create worktree"
                return 1
            }
        fi

        # Auto-approve direnv if .envrc exists in the new worktree
        if [[ -f "$wt_path/.envrc" ]] && command -v direnv &> /dev/null; then
            (cd "$wt_path" && direnv allow)
        fi

        local is_new_worktree=1
    fi

    # Execute based on number of arguments
    if [[ ${#command[@]} -gt 0 ]]; then
        # Command given — run it directly in the worktree (no tmux)
        local old_pwd="$PWD"
        cd "$wt_path"
        eval "${command[@]}"
        local exit_code=$?
        cd "$old_pwd"
        return $exit_code
    fi

    # No command — use tmux session
    local session_name=$(_wt_tmux_session_name "$project" "$dir_name")

    if tmux has-session -t "$session_name" 2>/dev/null; then
        # Session exists — attach or switch to it
        if [[ -n "$TMUX" ]]; then
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        fi
    else
        # Create new tmux session in the worktree directory
        if [[ -n "$TMUX" ]]; then
            tmux new-session -d -s "$session_name" -c "$wt_path"
            # Send post-create command into the new session before switching
            if [[ -n "$is_new_worktree" && -n "${wt_post_create_commands[$project]}" ]]; then
                tmux send-keys -t "$session_name" "${wt_post_create_commands[$project]}" Enter
            fi
            tmux switch-client -t "$session_name"
        else
            # Send post-create command after session starts
            if [[ -n "$is_new_worktree" && -n "${wt_post_create_commands[$project]}" ]]; then
                tmux new-session -d -s "$session_name" -c "$wt_path"
                tmux send-keys -t "$session_name" "${wt_post_create_commands[$project]}" Enter
                tmux attach-session -t "$session_name"
            else
                tmux new-session -s "$session_name" -c "$wt_path"
            fi
        fi
    fi
}

# ─── Tab completion ──────────────────────────────────────────────────────────
_wt() {
    local projects_dir="$WT_PROJECTS_DIR"
    local worktrees_dir="$WT_WORKTREES_DIR"

    _wt_projects() {
        local -a projects displays
        for dir in $projects_dir/*(N/); do
            if [[ -d "$dir/.git" ]]; then
                projects+=(${dir:t})
                displays+=("${dir:t}")
            fi
        done
        compadd -l -d displays -V projects -a projects
    }

    _wt_worktrees() {
        local project="$1"
        local -a worktrees displays
        if [[ -d "$worktrees_dir/$project" ]]; then
            for wt_dir in $worktrees_dir/$project/*(N/); do
                worktrees+=(${wt_dir:t})
                displays+=("${wt_dir:t}")
            done
        fi
        if (( ${#worktrees} > 0 )); then
            compadd -l -d displays -V worktrees -a worktrees
        else
            _message 'new worktree name'
        fi
    }

    case "${words[2]}" in
        --list|--home)
            return 0
            ;;
        --rm)
            case $CURRENT in
                3)
                    local -a force_opt=('--force:Force remove worktree with uncommitted changes')
                    _describe -t options 'option' force_opt
                    _wt_projects
                    ;;
                4)
                    if [[ "${words[3]}" == "--force" ]]; then
                        _wt_projects
                    else
                        _wt_worktrees "${words[3]}"
                    fi
                    ;;
                5)
                    if [[ "${words[3]}" == "--force" ]]; then
                        _wt_worktrees "${words[4]}"
                    fi
                    ;;
            esac
            ;;
        *)
            case $CURRENT in
                2)
                    local -a flags=('--home:cd to projects directory' '--list:List all worktrees' '--rm:Remove a worktree')
                    _describe -t flags 'flag' flags
                    _wt_projects
                    ;;
                3)
                    _wt_worktrees "${words[2]}"
                    ;;
                4)
                    local -a common_commands=(
                        'claude:Start Claude Code session'
                        'gst:Git status'
                        'gaa:Git add all'
                        'gcmsg:Git commit with message'
                        'gp:Git push'
                        'gco:Git checkout'
                        'gd:Git diff'
                        'gl:Git log'
                        'npm:Run npm commands'
                        'yarn:Run yarn commands'
                        'make:Run make commands'
                    )
                    _describe -t commands 'command' common_commands
                    _command_names -e
                    ;;
                *)
                    _normal
                    ;;
            esac
            ;;
    esac
}

compdef _wt wt
