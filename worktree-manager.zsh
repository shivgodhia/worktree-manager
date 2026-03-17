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

# ─── Configuration (defaults) ────────────────────────────────────────────────
# Override any of these in worktree-manager.local.zsh (see below).
: ${WT_PROJECTS_DIR:="$HOME/projects"}
: ${WT_BASE_BRANCH:="origin/main"}
: ${WT_BRANCH_PREFIX:="$USER"}

# Post-create hooks — commands to run after creating a worktree for a project.
typeset -gA wt_post_create_commands

# Post-startup hooks — commands to run every time a new tmux session is created
# for a worktree (after post-create hooks, if any). Use for launching agents,
# adding tmux splits/panes, or any per-session setup that applies to every worktree.
# Set a default for all projects, then override per-project as needed.
: ${WT_DEFAULT_POST_STARTUP_COMMAND:=""}
typeset -gA wt_post_startup_commands

# ─── Local overrides ────────────────────────────────────────────────────────
# Source user-specific config (projects dir, post-create hooks, env vars, etc.)
# from a file alongside this one. This file is gitignored so you can
# `git pull` updates to worktree-manager.zsh without conflicts.
#
# Example worktree-manager.local.zsh:
#   WT_PROJECTS_DIR="$HOME/Desktop/clones/projects"
#   WT_BRANCH_PREFIX="shivgodhia"
#   wt_post_create_commands[my-api]="yarn && npx prisma generate"
#   wt_post_create_commands[my-app]="pnpm install"
#
local _wt_script_dir="${${(%):-%x}:A:h}"
if [[ -f "$_wt_script_dir/worktree-manager.local.zsh" ]]; then
    source "$_wt_script_dir/worktree-manager.local.zsh"
fi

# Derived defaults (set after local overrides so they pick up custom WT_PROJECTS_DIR)
: ${WT_WORKTREES_DIR:="$WT_PROJECTS_DIR/worktrees"}

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
    if [[ "$1" == "--help" ]]; then
        cat <<'HELP'
wt - Git Worktree Manager with tmux Integration

QUICK START
  wt my-app my-feature        Create a worktree and open it in a tmux session
  ... do your work ...
  wt --rm my-app my-feature   Delete the worktree when you're done

HOW IT WORKS
  Git worktrees let you have multiple branches checked out at once, each in
  its own directory. This tool wraps that with tmux so every worktree gets
  a persistent terminal session you can return to at any time.

CREATING A WORKTREE
  wt <project> <worktree-name>

  The first argument is the name of a project (a git repo in your projects
  directory). The second is a name for your worktree — usually a feature or
  branch name like "add-search" or "fix-login-bug".

  What happens:
    1. A new directory is created for the worktree
    2. If the branch exists on the remote, it checks it out
    3. If not, it creates a new branch (prefixed with your username)
    4. A tmux session is created and you're dropped into it

  If you've configured post-create hooks for the project (e.g. "pnpm install"),
  they run automatically in the new session. Post-startup hooks (e.g. launching
  "claude") run every time a new tmux session is created, not just on first creation.

FINDING AND RETURNING TO A WORKTREE
  wt <project> <worktree-name>

  The same command you used to create it. If the worktree already exists,
  it simply switches you to its tmux session. This is the key workflow:
  you never need to remember paths or find directories — just run `wt`
  with the same project and name.

  Use tab completion to see your existing worktrees — type `wt my-app `
  and press Tab.

  wt --list

  Shows all worktrees across all projects, and marks which ones have an
  active tmux session.

THE TMUX INTEGRATION
  Every worktree gets a dedicated tmux session (named "wt/<project>/<name>").
  This gives you:

  Persistent workspace — Your terminal state is preserved. If you have
    Claude Code running, split panes open, or a dev server going, it's all
    still there when you come back.

  No duplicates — Running `wt my-app my-feature` a second time doesn't
    create a new terminal. It switches to the existing session. This means
    you won't accidentally end up with two Claude Code instances editing the
    same worktree.

  Tab titles — If your terminal supports it (e.g. iTerm2), the tab title
    shows the session name, so you can see at a glance which worktree each
    tab is for. (Requires tmux config: set-option -g set-titles on)

  Clean switching — If you're already inside tmux, `wt` switches sessions
    seamlessly. If you're outside tmux, it attaches to the session.

DELETING A WORKTREE
  wt --rm <project> <worktree-name>

  This removes the worktree directory, deletes the local branch, and kills
  the tmux session. If you have uncommitted changes, add --force:

  wt --rm --force <project> <worktree-name>

RUNNING A ONE-OFF COMMAND
  wt <project> <worktree-name> <command>

  Runs a command in the worktree directory without tmux. Useful for quick
  checks like:
    wt my-app my-feature git status
    wt my-app my-feature npm test

OTHER COMMANDS
  wt --kms         Remove the current worktree (run from inside a worktree)
  wt --kms --force Same, but force-remove even with uncommitted changes
  wt --list        List all worktrees and their tmux session status
  wt --home        cd to your projects directory

CONFIGURATION
  Override defaults in worktree-manager.local.zsh (gitignored):
    WT_PROJECTS_DIR     Where your git repos live (default: ~/projects)
    WT_BASE_BRANCH      Base branch for new worktrees (default: origin/main)
    WT_BRANCH_PREFIX    Prefix for new branches (default: your username)

  Post-create hooks (run automatically when a worktree is first created):
    wt_post_create_commands[my-api]="yarn && npx prisma generate"
    wt_post_create_commands[my-app]="pnpm install"

  Post-startup hooks (run every time a new tmux session is created):
    WT_DEFAULT_POST_STARTUP_COMMAND="claude"          # default for all projects
    wt_post_startup_commands[my-api]="tmux split-window -h && claude"  # override
HELP
        return 0
    elif [[ "$1" == "--home" ]]; then
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
    elif [[ "$1" == "--kms" ]]; then
        # "Kill myself" — remove the current worktree from within it
        shift
        local force_flag=""
        if [[ "$1" == "--force" ]]; then
            force_flag="--force"
            shift
        fi
        local cwd="$PWD"
        # Check if we're inside the worktrees directory
        if [[ "$cwd" != "$worktrees_dir/"* ]]; then
            echo "Not inside a wt-managed worktree"
            return 1
        fi
        # Extract project and worktree from path: $worktrees_dir/<project>/<worktree>/...
        local relative="${cwd#$worktrees_dir/}"
        local project="${relative%%/*}"
        local worktree="${${relative#*/}%%/*}"
        if [[ -z "$project" || -z "$worktree" ]]; then
            echo "Could not determine project/worktree from current path"
            return 1
        fi
        echo "Removing worktree: $project/$worktree"
        wt --rm $force_flag "$project" "$worktree"
        return $?
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
        echo "       wt --kms                              # remove current worktree (from inside it)"
        echo "       wt --home"
        echo "       wt --help"
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
        # Resolve post-startup command: project-specific overrides the default
        local startup_cmd="${wt_post_startup_commands[$project]:-$WT_DEFAULT_POST_STARTUP_COMMAND}"

        # Build the full command to send into the new session.
        # If both post-create and post-startup commands exist, chain them with &&
        # so the startup command waits for the create command to finish.
        local full_cmd=""
        if [[ -n "$is_new_worktree" && -n "${wt_post_create_commands[$project]}" ]]; then
            full_cmd="${wt_post_create_commands[$project]}"
        fi
        if [[ -n "$startup_cmd" ]]; then
            if [[ -n "$full_cmd" ]]; then
                full_cmd="${full_cmd} && ${startup_cmd}"
            else
                full_cmd="$startup_cmd"
            fi
        fi

        if [[ -n "$TMUX" ]]; then
            tmux new-session -d -s "$session_name" -c "$wt_path"
            if [[ -n "$full_cmd" ]]; then
                tmux send-keys -t "$session_name" "$full_cmd" Enter
            fi
            tmux switch-client -t "$session_name"
        else
            tmux new-session -d -s "$session_name" -c "$wt_path"
            if [[ -n "$full_cmd" ]]; then
                tmux send-keys -t "$session_name" "$full_cmd" Enter
            fi
            tmux attach-session -t "$session_name"
        fi
    fi
}

# ─── Tab completion ──────────────────────────────────────────────────────────

# FZF-powered fuzzy-find completion for wt.
# Provides fuzzy matching with colored match highlights for both
# project names and worktree names. Falls back to standard zsh
# completion if fzf is not installed.

_wt_fzf_available() {
    (( $+commands[fzf] ))
}

# Pipe candidates through fzf for fuzzy selection.
# Args: $1 = query (current word being typed), rest = candidates
# Returns selected candidate on stdout, exit code 0 if selected.
_wt_fzf_select() {
    local query="$1"; shift
    local -a candidates=("$@")
    if (( ${#candidates} == 0 )); then
        return 1
    fi
    # Single exact match — skip fzf
    if (( ${#candidates} == 1 )); then
        echo "${candidates[1]}"
        return 0
    fi
    printf '%s\n' "${candidates[@]}" | fzf \
        --height=~40% \
        --layout=reverse \
        --query="$query" \
        --select-1 \
        --exit-0 \
        --color='hl:magenta:underline,hl+:magenta:underline' \
        --no-info \
        --no-sort \
        --bind='tab:accept'
}

# ZLE widget: intercepts tab when typing a `wt` command and uses fzf
# for fuzzy project/worktree selection. For other commands, falls
# through to the normal tab-completion widget.
_wt_fzf_complete_widget() {
    local tokens=(${(z)LBUFFER})
    local cmd="${tokens[1]}"

    # Only intercept for the wt command
    if [[ "$cmd" != "wt" ]]; then
        zle "${_wt_orig_tab_widget:-expand-or-complete}"
        return
    fi

    local nargs=${#tokens}
    # If cursor is right after a space, we're starting a new argument
    local current_word=""
    if [[ "$LBUFFER" == *" " ]]; then
        (( nargs++ ))
    else
        current_word="${tokens[-1]}"
    fi

    local projects_dir="$WT_PROJECTS_DIR"
    local worktrees_dir="$WT_WORKTREES_DIR"

    # Determine what we're completing based on argument position
    case "$nargs" in
        1)
            # Just "wt" with cursor right after — complete projects (position 2)
            ;& # fall through
        2)
            # Completing first argument: flags + projects
            local -a candidates=()

            # Add flags
            candidates+=("--help" "--home" "--kms" "--list" "--rm")

            # Add projects
            for dir in $projects_dir/*(N/); do
                if [[ -d "$dir/.git" ]]; then
                    candidates+=(${dir:t})
                fi
            done

            local selection
            selection=$(_wt_fzf_select "$current_word" "${candidates[@]}")
            if [[ -n "$selection" ]]; then
                # Replace current word (or append) with selection
                if [[ -n "$current_word" ]]; then
                    LBUFFER="${LBUFFER%${current_word}}${selection} "
                else
                    LBUFFER+="${selection} "
                fi
                zle reset-prompt
            fi
            ;;
        3)
            local arg1="${tokens[2]}"
            case "$arg1" in
                --list|--home|--help|--kms)
                    return 0
                    ;;
                --rm)
                    # Completing project for --rm (also offer --force)
                    local -a candidates=("--force")
                    for dir in $projects_dir/*(N/); do
                        if [[ -d "$dir/.git" ]]; then
                            candidates+=(${dir:t})
                        fi
                    done
                    local selection
                    selection=$(_wt_fzf_select "$current_word" "${candidates[@]}")
                    if [[ -n "$selection" ]]; then
                        if [[ -n "$current_word" ]]; then
                            LBUFFER="${LBUFFER%${current_word}}${selection} "
                        else
                            LBUFFER+="${selection} "
                        fi
                        zle reset-prompt
                    fi
                    ;;
                *)
                    # Completing worktree for a project
                    local project="$arg1"
                    local -a candidates=()
                    if [[ -d "$worktrees_dir/$project" ]]; then
                        for wt_dir in $worktrees_dir/$project/*(N/); do
                            candidates+=(${wt_dir:t})
                        done
                    fi
                    if (( ${#candidates} == 0 )); then
                        # No worktrees — let user type a new name
                        zle -M "No existing worktrees for $project — type a new worktree name"
                        return 0
                    fi
                    local selection
                    selection=$(_wt_fzf_select "$current_word" "${candidates[@]}")
                    if [[ -n "$selection" ]]; then
                        if [[ -n "$current_word" ]]; then
                            LBUFFER="${LBUFFER%${current_word}}${selection} "
                        else
                            LBUFFER+="${selection} "
                        fi
                        zle reset-prompt
                    fi
                    ;;
            esac
            ;;
        4)
            local arg1="${tokens[2]}"
            case "$arg1" in
                --rm)
                    local arg2="${tokens[3]}"
                    if [[ "$arg2" == "--force" ]]; then
                        # Completing project after --rm --force
                        local -a candidates=()
                        for dir in $projects_dir/*(N/); do
                            if [[ -d "$dir/.git" ]]; then
                                candidates+=(${dir:t})
                            fi
                        done
                        local selection
                        selection=$(_wt_fzf_select "$current_word" "${candidates[@]}")
                        if [[ -n "$selection" ]]; then
                            if [[ -n "$current_word" ]]; then
                                LBUFFER="${LBUFFER%${current_word}}${selection} "
                            else
                                LBUFFER+="${selection} "
                            fi
                            zle reset-prompt
                        fi
                    else
                        # Completing worktree for --rm <project>
                        local project="$arg2"
                        local -a candidates=()
                        if [[ -d "$worktrees_dir/$project" ]]; then
                            for wt_dir in $worktrees_dir/$project/*(N/); do
                                candidates+=(${wt_dir:t})
                            done
                        fi
                        if (( ${#candidates} == 0 )); then
                            zle -M "No worktrees for $project"
                            return 0
                        fi
                        local selection
                        selection=$(_wt_fzf_select "$current_word" "${candidates[@]}")
                        if [[ -n "$selection" ]]; then
                            if [[ -n "$current_word" ]]; then
                                LBUFFER="${LBUFFER%${current_word}}${selection} "
                            else
                                LBUFFER+="${selection} "
                            fi
                            zle reset-prompt
                        fi
                    fi
                    ;;
                *)
                    # Position 4 for normal flow: command completion — fall through to default
                    zle "${_wt_orig_tab_widget:-expand-or-complete}"
                    return
                    ;;
            esac
            ;;
        5)
            local arg1="${tokens[2]}"
            if [[ "$arg1" == "--rm" && "${tokens[3]}" == "--force" ]]; then
                # Completing worktree for --rm --force <project>
                local project="${tokens[4]}"
                local -a candidates=()
                if [[ -d "$worktrees_dir/$project" ]]; then
                    for wt_dir in $worktrees_dir/$project/*(N/); do
                        candidates+=(${wt_dir:t})
                    done
                fi
                if (( ${#candidates} == 0 )); then
                    zle -M "No worktrees for $project"
                    return 0
                fi
                local selection
                selection=$(_wt_fzf_select "$current_word" "${candidates[@]}")
                if [[ -n "$selection" ]]; then
                    if [[ -n "$current_word" ]]; then
                        LBUFFER="${LBUFFER%${current_word}}${selection} "
                    else
                        LBUFFER+="${selection} "
                    fi
                    zle reset-prompt
                fi
            else
                zle "${_wt_orig_tab_widget:-expand-or-complete}"
                return
            fi
            ;;
        *)
            # Beyond our completion positions — fall through to default
            zle "${_wt_orig_tab_widget:-expand-or-complete}"
            return
            ;;
    esac
}

# Register the fzf completion widget, preserving the original tab binding
if _wt_fzf_available; then
    # Save whatever widget is currently bound to tab, skipping our own widget
    _wt_orig_tab_widget="${$(bindkey '^I' 2>/dev/null)##*\" }"
    if [[ "$_wt_orig_tab_widget" == "_wt_fzf_complete_widget" || -z "$_wt_orig_tab_widget" ]]; then
        _wt_orig_tab_widget="expand-or-complete"
    fi

    # Stub _wt so any cached compdef doesn't error when standard
    # completion falls through (e.g. position 4+ for command args)
    _wt() { return 0; }
    compdef _wt wt

    zle -N _wt_fzf_complete_widget
    bindkey '^I' _wt_fzf_complete_widget
else
    # Fallback: standard zsh completion without fzf
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
            --list|--home|--help|--kms)
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
                        local -a flags=('--help:Show usage guide' '--home:cd to projects directory' '--kms:Remove current worktree' '--list:List all worktrees' '--rm:Remove a worktree')
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
fi
