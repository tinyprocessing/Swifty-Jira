# Swifty-Jira — Terminal Jira Client

A fast command-line Jira client written in Swift with SSO authentication.
Designed for daily use in the terminal and for piping issue context directly to Claude.

## Setup

### 1. Build & install

```sh
swift build -c release
cp .build/release/swifty-jira /usr/local/bin/swifty-jira
```

Or use the included script:

```sh
bash make.sh
```

### 2. Set your Jira URL

Add to `~/.zshrc` or `~/.bashrc`:

```sh
export JIRA_URL=https://your-jira.company.com
```

Or pass it per command:

```sh
swifty-jira --url https://your-jira.company.com issue list
```

### 3. First run — SSO authentication

On first run a browser window opens for SSO login. After successful login, cookies
are cached in `~/Library/Application Support/cookies.txt` and reused for 7 days.
Subsequent commands work instantly without re-authentication.

To force re-login:

```sh
swifty-jira clean
```

---

## Commands

### User

```sh
swifty-jira user info
```

Displays email, login, active status, and key for the authenticated user.

---

### Projects

```sh
swifty-jira project list
swifty-jira project view --key PROJ
```

---

### Issues

##### Interactive browser (TUI)

```sh
swifty-jira browse
swifty-jira browse --filter openSprints
swifty-jira browse --jql "project=MEM AND assignee=currentUser()"
```

A keyboard-driven full-screen browser (k9s style):

| Key | Action |
|-----|--------|
| `↑`/`↓` or `j`/`k` | Move selection |
| `g` / `G` | Jump to top / bottom |
| `Enter` | Open issue details |
| `f` | Cycle server-side preset: openSprints → undone → all → openAndFutureSprints |
| `/` | Local text search within the loaded list (key/summary/status) |
| `o` | Open selected issue in browser |
| `y` | Copy the issue **link** to the clipboard |
| `c` | Copy a ready-to-run **`issue export` command** — paste it to Claude for full context |
| `r` | Refresh from Jira |
| `Esc` / `q` | Back / quit |

`c` copies e.g. `swifty-jira issue export --key MEM-8246`. Paste it into your shell
piped to Claude, or hand the command to Claude directly:

```sh
swifty-jira issue export --key MEM-8246 | claude "Analyze this task and propose a plan"
```

**Two kinds of filtering:**
- **`f`** re-queries Jira with a different preset (this is how you switch to sprints/backlog).
- **`/`** just searches the currently loaded rows by text — it does not re-query.

To browse the backlog (project-specific) or a custom query, launch with a flag:
```sh
swifty-jira browse --filter backlog
swifty-jira browse --jql "project=MEM AND sprint in openSprints()"
```

Requires a real terminal (TTY) and a cached session — log in once with
`swifty-jira user info` first.

### List issues

```sh
# Default: your open issues (not Done or Dev Complete)
swifty-jira issue list

# Preset filters
swifty-jira issue list --filter all
swifty-jira issue list --filter backlog
swifty-jira issue list --filter openSprints
swifty-jira issue list --filter openAndFutureSprints
swifty-jira issue list --filter "In Progress"

# Custom JQL (overrides --filter)
swifty-jira issue list --jql "project=PROJ AND sprint in openSprints() AND assignee=currentUser()"

# JSON output (for scripts / Claude)
swifty-jira issue list --enable-json
swifty-jira issue list --filter openSprints --enable-json
```

#### View issue

```sh
swifty-jira issue view --key PROJ-123
swifty-jira issue view --key PROJ-123 --view-in-web true   # open in browser
swifty-jira issue view --key PROJ-123 --enable-list-statuses  # show available transitions
```

#### Export issue (Claude context)

Full issue export: summary, description, status, assignee, subtasks, linked issues (both directions), and comments — all as clean JSON.

```sh
swifty-jira issue export --key PROJ-123
```

#### Transition (change status)

```sh
# First, see what transitions are available
swifty-jira issue view --key PROJ-123 --enable-list-statuses

# Move to a new status
swifty-jira issue transition --key PROJ-123 --status "In Progress"

# With resolution
swifty-jira issue transition --key PROJ-123 --status Done --resolution Fixed
```

#### Add a comment

```sh
swifty-jira issue comment --key PROJ-123 --body "Fixed in commit abc123"
```

#### Update summary or description

```sh
swifty-jira issue update --key PROJ-123 --summary "New title for the issue"
swifty-jira issue update --key PROJ-123 --description "Updated description with more details"
swifty-jira issue update --key PROJ-123 --summary "New title" --description "New description"
```

#### Clone an issue (recommended for projects with required custom fields)

```sh
# Preview what would be created (safe — creates nothing)
swifty-jira issue clone --from MEM-8146 --summary "New task" --enable-dry-run

# Actually clone into the current sprint
swifty-jira issue clone --from MEM-8146 \
  --summary "New task" \
  --description "..." \
  --sprint current
```

Copies all writable fields from the source verbatim — including required custom
fields (Application/Service, Story Type, Epic Link) — then overrides
summary/description. Reporter/assignee default to you. Sprint, comments, links,
and subtasks are stripped (sprint is set via `--sprint`). Always dry-run first.

#### Create a sub-task

```sh
swifty-jira issue create \
  --parent PROJ-95 \
  --summary "Add unit tests for auth module" \
  --project PROJ \
  --assignee username
```

#### Reassign issue

```sh
swifty-jira issue assignee --key PROJ-123 --account-id <accountId>
```

---

### Context snapshot (who am I + sprint + my issues)

```sh
swifty-jira context --project MEM
```

Returns one JSON blob: the authenticated user, the project's **active sprint**
(id, name, dates, goal), and your open issues. This is the fastest way for an AI
agent to orient itself.

---

## Claude Integration

The CLI is **self-documenting for agents** — it works in any project with no extra
files. Point Claude at the built-in guide first:

```sh
swifty-jira guide
```

This prints a complete, self-contained reference (auth, commands, JSON shapes, rules).
Claude can run it in any repo and know exactly what to call.

> Optional: a project-specific [`AGENTS.md`](./AGENTS.md) adds a **user profile**
> (role, platform, main project key) that the Jira API doesn't expose. Fill it in
> if you want Claude to assume context (e.g. "these are iOS tasks in MEM"). Not required.

### Non-interactive mode (IMPORTANT for AI use)

When an agent invokes the CLI, set `SWIFTY_JIRA_NONINTERACTIVE=1`. Without it, a
stale session would open a WebKit SSO window and hang forever. With it, the CLI
**fails fast** (exit code 2) and prints a message to re-authenticate.

```sh
export SWIFTY_JIRA_NONINTERACTIVE=1
```

The user must log in interactively once (`swifty-jira user info` in a real terminal)
to prime the 7-day cookie cache.


### Pattern 1 — Drop a task into Claude for analysis

```sh
swifty-jira issue export --key PROJ-123 | \
  claude "This is a Jira task. Analyze it, suggest an implementation plan, and ask me if anything is unclear."
```

### Pattern 2 — Claude writes the description / acceptance criteria

```sh
# Export the bare task
swifty-jira issue export --key PROJ-123 | \
  claude "Based on the summary and existing comments, write a detailed description and acceptance criteria for this issue. Return plain text only."
```

Then update the issue:

```sh
swifty-jira issue update --key PROJ-123 --description "$(pbpaste)"
```

### Pattern 3 — Claude creates a comment with a progress update

```sh
swifty-jira issue export --key PROJ-123 | \
  claude "Write a short progress update comment for this Jira issue based on its current state. Be concise, max 3 sentences."
# Copy the output, then:
swifty-jira issue comment --key PROJ-123 --body "$(pbpaste)"
```

### Pattern 4 — Review your sprint with Claude

```sh
swifty-jira issue list --filter openSprints --enable-json | \
  claude "Review this sprint. Which issues look stuck? What should I prioritize today?"
```

### Pattern 5 — Custom JQL + AI summary

```sh
swifty-jira issue list --jql "project=PROJ AND status='In Review' AND updated >= -7d" --enable-json | \
  claude "Summarize what's been in review for the past week. Flag anything that's been sitting too long."
```

---

## Output Modes

| Mode | When to use |
|------|-------------|
| Table (default) | Human reading in terminal |
| `--enable-json` | Scripting, piping to Claude |
| `issue export` | Full rich context for Claude — includes description, comments, links |

All diagnostic messages and auth logs go to **stderr** so they never contaminate JSON on **stdout**.

Tables auto-fit your terminal width (the Summary column wraps by word; fixed columns
truncate with `…`). Override the width with the `COLUMNS` env var:

```sh
COLUMNS=120 swifty-jira issue list
```

---

## Cookie Cache

Cookies are saved to `~/Library/Application Support/cookies.txt` and expire after 7 days.

- `swifty-jira clean` — delete cached cookies (force re-login)
- If auth stops working, run `clean` and re-authenticate

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Browser window doesn't appear | Make sure you're running in a GUI session (not pure SSH) |
| Auth works but API returns 401 | Run `swifty-jira clean` and re-authenticate |
| `JIRA_URL` not set error | Export the variable or pass `--url` explicitly |
| JSON output has extra text | All diagnostics go to stderr; redirect with `2>/dev/null` |
| Transition not found | Run `issue view --enable-list-statuses` to see exact names |
