#!/usr/bin/env zsh
# wt - Multi-project git worktree manager
#
# Manages git worktrees across multiple projects with auto-creation,
# per-project setup hooks, direnv support, and full tab completion.
#
# See README.md for installation and usage instructions.

# ─── Configuration ───────────────────────────────────────────────────────────
# Override these in your .zshrc BEFORE sourcing this file:
#   WT_PROJECTS_DIR="$HOME/code"
#   WT_WORKTREES_DIR="$HOME/code/worktrees"
#   WT_BASE_BRANCH="origin/main"
: ${WT_PROJECTS_DIR:="$HOME/projects"}
: ${WT_WORKTREES_DIR:="$HOME/projects/worktrees"}
: ${WT_BASE_BRANCH:="origin/main"}

# Registry of post-create commands per project.
# Add entries in your .zshrc after sourcing this file:
#   wt_post_create_commands[my-app]="npm install"
#   wt_post_create_commands[backend]="pip install -r requirements.txt"
typeset -gA wt_post_create_commands

# ─── Main function ───────────────────────────────────────────────────────────
wt() {
    local projects_dir="$WT_PROJECTS_DIR"
    local worktrees_dir="$WT_WORKTREES_DIR"

    # Handle special flags
    if [[ "$1" == "--list" ]]; then
        echo "=== All Worktrees ==="
        if [[ -d "$worktrees_dir" ]]; then
            for project in $worktrees_dir/*(/N); do
                project_name=$(basename "$project")
                echo "\n[$project_name]"
                for wt in $project/*(/N); do
                    echo "  • $(basename "$wt")"
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
        local branch_name="$USER/$worktree"
        local wt_path="$worktrees_dir/$project/$worktree"
        if [[ ! -d "$wt_path" ]]; then
            echo "Worktree not found: $wt_path"
            return 1
        fi
        (cd "$projects_dir/$project" && git worktree remove $force_flag "$wt_path" && git branch -D "$branch_name")
        return $?
    fi

    # Normal usage: wt <project> <worktree> [command...]
    local project="$1"
    local worktree="$2"
    shift 2
    local command=("$@")

    if [[ -z "$project" || -z "$worktree" ]]; then
        echo "Usage: wt <project> <worktree> [command...]"
        echo "       wt --list"
        echo "       wt --rm [--force] <project> <worktree>"
        return 1
    fi

    # Check if project exists
    if [[ ! -d "$projects_dir/$project" ]]; then
        echo "Project not found: $projects_dir/$project"
        return 1
    fi

    # Determine worktree path
    local wt_path=""
    if [[ -d "$worktrees_dir/$project/$worktree" ]]; then
        wt_path="$worktrees_dir/$project/$worktree"
    fi

    # If worktree doesn't exist, create it
    if [[ -z "$wt_path" || ! -d "$wt_path" ]]; then
        echo "Creating new worktree: $worktree"

        # Ensure worktrees directory exists
        mkdir -p "$worktrees_dir/$project"

        # Branch name: <username>/<worktree-name>
        local branch_name="$USER/$worktree"

        # Create the worktree
        wt_path="$worktrees_dir/$project/$worktree"
        (cd "$projects_dir/$project" && git fetch origin && git worktree add "$wt_path" -b "$branch_name" $WT_BASE_BRANCH) || {
            echo "Failed to create worktree"
            return 1
        }

        # Auto-approve direnv if .envrc exists in the new worktree
        if [[ -f "$wt_path/.envrc" ]] && command -v direnv &> /dev/null; then
            (cd "$wt_path" && direnv allow)
        fi

        # Run post-create command if registered for this project
        if [[ -n "${wt_post_create_commands[$project]}" ]]; then
            echo "Running post-create command for $project..."
            (cd "$wt_path" && eval "${wt_post_create_commands[$project]}") || {
                echo "Warning: post-create command failed"
            }
        fi
    fi

    # Execute based on number of arguments
    if [[ ${#command[@]} -eq 0 ]]; then
        # No command specified - just cd to the worktree
        cd "$wt_path"
    else
        # Command specified - run it in the worktree without cd'ing
        local old_pwd="$PWD"
        cd "$wt_path"
        eval "${command[@]}"
        local exit_code=$?
        cd "$old_pwd"
        return $exit_code
    fi
}

# ─── Tab completion ──────────────────────────────────────────────────────────
_wt() {
    local projects_dir="$WT_PROJECTS_DIR"
    local worktrees_dir="$WT_WORKTREES_DIR"

    _wt_projects() {
        local -a projects
        for dir in $projects_dir/*(N/); do
            if [[ -d "$dir/.git" ]]; then
                projects+=(${dir:t})
            fi
        done
        _describe -t projects 'project' projects
    }

    _wt_worktrees() {
        local project="$1"
        local -a worktrees
        if [[ -d "$worktrees_dir/$project" ]]; then
            for wt_dir in $worktrees_dir/$project/*(N/); do
                worktrees+=(${wt_dir:t})
            done
        fi
        if (( ${#worktrees} > 0 )); then
            _describe -t worktrees 'existing worktree' worktrees
        else
            _message 'new worktree name'
        fi
    }

    case "${words[2]}" in
        --list)
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
                    local -a flags=('--list:List all worktrees' '--rm:Remove a worktree')
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
