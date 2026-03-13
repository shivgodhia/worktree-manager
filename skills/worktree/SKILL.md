---
name: worktree
description: Manage git worktrees - create, delete, list, or cd into worktrees. Usage: /worktree <action> [description]. Actions: create, delete, list, cd.
---

# Worktree Management Skill

You are helping the user manage git worktrees. This skill integrates with the user's `wt` command (worktree manager).

## Worktree Manager Reference

The user has a worktree manager at `~/.zsh/wt/worktree-manager.zsh`. **Before running any commands**, read that file to determine the actual configured values of:

- `WT_PROJECTS_DIR` — where git repos live
- `WT_WORKTREES_DIR` — where worktrees are created
- `WT_BRANCH_PREFIX` — prefix for new branch names

Use those concrete paths (not the variable names) in all Bash commands.

### Available Commands

```bash
wt <project> <worktree>              # Create (if needed) and cd to worktree
wt <project> <worktree> <command>    # Run command in worktree
wt --list                            # List all worktrees
wt --rm <project> <worktree>         # Remove worktree
wt --rm --force <project> <worktree> # Force remove (uncommitted changes)
```

## Parsing User Intent

The user invokes this skill with `/worktree <args>`. Parse the args to determine the action:

| User Input | Action |
|------------|--------|
| `/worktree create ...` or `/worktree new ...` | CREATE |
| `/worktree delete ...` or `/worktree rm ...` or `/worktree remove ...` | DELETE |
| `/worktree list` or `/worktree ls` | LIST |
| `/worktree cd ...` or `/worktree go ...` or `/worktree switch ...` | CD |
| `/worktree` (no args) | LIST (default) |

---

## Action: CREATE

### Step 1: Determine the Project

1. **Check if currently in a git repo**: Run `git rev-parse --show-toplevel 2>/dev/null`
2. **If in a git repo**: Extract the project name from the directory name
3. **If not in a git repo**: Ask the user which project to use

### Step 2: Understand the Task

If the user didn't provide a task description in their command, use AskUserQuestion:
- "What feature, bug fix, or task will you be working on in this worktree?"

### Step 3: Generate Worktree Name

From the user's description, generate a short, kebab-case worktree name:

**Guidelines:**
- Use 2-4 words maximum
- Use kebab-case (lowercase with hyphens)
- Be descriptive but concise
- **Do NOT auto-generate names with numbers** - no ticket numbers, PR numbers, issue numbers, dates, or digits
- Common prefixes: `fix-`, `feat-`, `refactor-`, `test-`, `chore-`

**Examples:**
- "fix the authentication bug in login" → `fix-auth-login`
- "adding dark mode support" → `feat-dark-mode`
- "refactoring the payment service" → `refactor-payments`

### Step 4: Confirm with User

Before creating, confirm:
- Project: `<project-name>`
- Worktree name: `<generated-name>`
- Full path: `$WT_WORKTREES_DIR/<project>/<worktree-name>`
- Branch: `<username>/<worktree-name>`

Ask if they want to proceed or modify the name.

### Step 5: Create the Worktree

```bash
wt <project> <worktree-name>
```

The `wt` command handles fetching, branching off the latest remote, direnv, and post-create hooks automatically.

### Step 6: Report Success

After creation, provide:
- The full path to the worktree
- The branch name that was created

---

## Action: DELETE

### Step 1: Determine Target Worktree

**If user specified a worktree name:**
- Parse it from the command (e.g., `/worktree delete fix-auth-login`)

**If user said "this worktree" or similar:**
- Check if currently in a worktree by checking if path matches `$WT_WORKTREES_DIR/<project>/<worktree-name>`
- Extract project and worktree name from the path

**If unclear:**
- Run `wt --list` to show available worktrees
- Ask user which one to delete

### Step 2: Check for Uncommitted Changes

```bash
cd <worktree-path> && git status --porcelain
```

If there are uncommitted changes:
- Warn the user
- List the changed files
- Ask if they still want to proceed

### Step 3: Confirm Deletion

ALWAYS confirm before deleting:
- Show: `<project>/<worktree-name>`
- Show full path
- Show the branch that will be deleted
- Warn this is destructive

Use AskUserQuestion with "Yes, delete it" / "No, cancel" options.

### Step 4: CRITICAL - Change Directory First

**Working directory trap**: If your current working directory is inside the worktree you're about to delete, ALL subsequent Bash commands will fail because the directory becomes invalid.

**Before deleting, you MUST cd out in a SEPARATE command:**

```bash
# FIRST: Change to the main project directory in a SEPARATE Bash call
cd $WT_PROJECTS_DIR/<project>
```

**Why a separate command?** The Bash tool's working directory persists between calls. If you combine `cd && wt --rm` in one command and the cd fails silently, you'll still be in the invalid directory afterward.

### Step 5: Delete

Only after successfully changing directory:

```bash
wt --rm <project> <worktree-name>
```

### Step 6: Report Result

- Confirm deletion
- The user is now in the main project directory

---

## Action: LIST

Simply run:

```bash
wt --list
```

Display the results to the user in a readable format.

---

## Action: CD

### Step 1: Determine Target

If user specified a worktree (e.g., `/worktree cd fix-auth-login`):
- Use that name

If not specified:
- Run `wt --list` and ask which one

### Step 2: Determine Project

- Check current git repo for project name
- Or ask if ambiguous

### Step 3: Change Directory

```bash
wt <project> <worktree-name>
```

This will cd into the worktree (creating it if it doesn't exist, but that should be rare for cd action).

---

## Error Handling

- If `wt` command is not found: inform user to source their worktree manager
- If project doesn't exist: list available projects and ask
- If worktree doesn't exist (for cd/delete): list available worktrees
- If worktree already exists (for create): ask if they want to cd to it instead

---

## Known Gotchas

### Squash-Merge Detection

When checking if a branch has been merged, `git merge-base --is-ancestor` will NOT detect **squash-merged** branches. The commits are different, so git doesn't recognize them as merged.

**To detect squash-merges:**
- Check if the PR was merged via GitHub API: `gh pr view <branch> --json state,mergedAt`
- Or use Graphite: `gt branch info <branch>`

**Practical advice:** Before deleting a worktree, if the branch appears "unmerged" by git, check the PR status via `gh` or `gt` to confirm.

### Working Directory Persistence

The Bash tool's working directory persists across calls. This causes issues when:
1. You're inside a worktree directory
2. You delete that worktree
3. All subsequent Bash commands fail because the cwd is now invalid

**Solution:** Always cd out of a worktree in a **separate** Bash call before deleting it. Don't combine them with `&&`.
