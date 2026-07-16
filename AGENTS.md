# AGENTS.md — Instructions for AI agents (Claude) using `swifty-jira`

> The CLI is self-documenting: run `swifty-jira guide` for the full command
> reference (works in any project). This file only adds the **user profile**
> below — context the Jira API doesn't expose. Edit Section 1 for your setup.

---

## Section 1 — User profile (EDIT THIS)

> The Jira API does **not** know the user's role, team, or platform.
> Fill this in so the agent has the right context.

- **Name / login:** Mikhail Safir (`vn55z6z`)
- **Role:** iOS Engineer
- **Platform:** iOS (Swift / SwiftUI / UIKit)
- **Main project key:** `MEM`
- **Board:** 3D Asset (scrum)
- **Typical work:** VTO (virtual try-on), accessibility (ADA/VoiceOver), 3D assets, animations

When creating or filling in issues, assume they are iOS tasks unless told otherwise.

---

## Section 2 — How to drive the CLI

All commands print **JSON to stdout** (when a `--enable-json` flag or an
export/context command is used) and **diagnostics/logs to stderr**.
Always parse stdout only. Add `2>/dev/null` if you want to discard logs.

### Authentication
- Auth is cached (7-day cookie). The user must have logged in at least once
  interactively (`swifty-jira user info` in a real terminal).
- Set `SWIFTY_JIRA_NONINTERACTIVE=1` when invoking so the CLI **fails fast**
  (exit code 2) instead of hanging on an SSO browser window if the session is stale.
- If you get exit code 2, tell the user to run `swifty-jira user info` in a terminal to re-auth.

### Getting oriented — START HERE
```sh
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira context --project MEM 2>/dev/null
```
Returns: the user, the **active sprint** (id, name, dates), and the user's open issues.
Use this first to understand who the user is and what's on their plate.

### Read a single task in full (best for "here's my task")
```sh
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue export --key MEM-8246 2>/dev/null
```
Returns rich JSON: summary, description, status, type, priority, assignee,
reporter, parent, **subtasks**, **linkedIssues** (both directions, with the
relation like "blocks" / "was found by"), and **comments**.
This is the command to run whenever the user drops a ticket key at you.

### List issues
```sh
# Your open issues (default)
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue list --enable-json 2>/dev/null

# Anything via JQL
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue list --jql "project=MEM AND sprint in openSprints() AND assignee=currentUser()" --enable-json 2>/dev/null
```

### Create a task (and optionally add it to the current sprint)
```sh
# Standalone Task in the active sprint
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue create \
  --project MEM \
  --type Task \
  --summary "Fix VoiceOver focus order in ring VTO carousel" \
  --description "..." \
  --assignee vn55z6z \
  --enable-sprint-current 2>/dev/null

# Sub-task under a parent
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue create \
  --project MEM --type Sub-task --parent MEM-8246 \
  --summary "Add accessibility unit tests" --assignee vn55z6z 2>/dev/null
```
- `--type`: `Task` | `Bug` | `Story` | `Sub-task` (Sub-task requires `--parent`)
- `--enable-sprint-current`: resolves the project's active sprint and drops the new issue into it
- On success prints `{"status":"ok","key":"MEM-1234","url":"..."}`

### Fill in / update an existing task
```sh
# After the user says "update the description based on what we did"
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue update --key MEM-8246 \
  --description "Root cause: accessibility container looped focus. Fixed by ..." 2>/dev/null

SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue update --key MEM-8246 \
  --summary "New clearer title" 2>/dev/null
```

### Add a comment (progress updates)
```sh
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue comment --key MEM-8246 \
  --body "Fixed in PR #123. Ready for retest." 2>/dev/null
```

### Change status
```sh
# First discover valid transition names
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue view --key MEM-8246 --enable-list-statuses 2>/dev/null

# Then transition
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue transition --key MEM-8246 --status "In Progress" 2>/dev/null
SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira issue transition --key MEM-8246 --status Done --resolution Fixed 2>/dev/null
```

---

## Section 3 — Command → data reference

| Need | Command |
|------|---------|
| Who is the user + active sprint + their open issues | `context --project MEM` |
| Full detail of one ticket (for analysis) | `issue export --key KEY` |
| List of tickets (table) | `issue list` |
| List of tickets (JSON) | `issue list --enable-json` |
| Arbitrary query | `issue list --jql "..." --enable-json` |
| Create ticket | `issue create --project ... --type ... --summary ...` |
| Add to active sprint on create | add `--enable-sprint-current` |
| Update summary/description | `issue update --key ... --summary/--description ...` |
| Add comment | `issue comment --key ... --body ...` |
| Discover status transitions | `issue view --key ... --enable-list-statuses` |
| Change status | `issue transition --key ... --status ...` |
| Reassign | `issue assignee --key ... --account-id ...` |
| User info | `user info` |
| Projects | `project list`, `project view --key ...` |
| Force re-login | `clean` |

---

## Section 4 — Rules for the agent

1. **Never guess a ticket's content** — always `issue export` first.
2. **Before writing** (create/update/comment/transition), state exactly what you'll
   do and confirm with the user unless they've already told you to proceed.
3. **Descriptions**: use Jira wiki markup (`*bold*`, `# lists`), not Markdown.
4. **Assignee** is a login (e.g. `vn55z6z`), not a display name.
5. **Sub-tasks require a parent**; Tasks/Bugs/Stories do not.
6. If a write returns a non-zero exit, read stderr and report the real error — don't retry blindly.
