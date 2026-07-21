import ArgumentParser
import Foundation

extension SwiftyJira {
    /// Prints a complete, self-contained usage guide for AI agents.
    /// Works in ANY project — no AGENTS.md required.
    struct Guide: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Print a full usage guide for AI agents (self-contained, works anywhere)"
        )

        func run() throws {
            print(Guide.text)
        }

        static let text = """
        # swifty-jira — agent guide

        A Jira CLI. Human commands print tables; agent commands print JSON to stdout.
        ALL logs/errors/auth go to stderr — ALWAYS suppress stderr when reading output:
          SWIFTY_JIRA_NONINTERACTIVE=1 swifty-jira <command> 2>/dev/null
        `guide` itself needs no auth and no network — it is always safe to run first.

        ## Setup / auth
        - Server: set JIRA_URL env var, or pass --url <https://jira.example.com>.
        - Auth is a 7-day cached SSO cookie. The user logs in once interactively
          (`swifty-jira user info` in a real terminal). You cannot log in for them.
        - ALWAYS export SWIFTY_JIRA_NONINTERACTIVE=1 before invoking. Then, if the
          session is missing/stale, the CLI exits with code 2 and a message instead
          of hanging on a browser window. On exit 2: ask the user to run
          `swifty-jira user info` in a terminal, then retry.

        ## Orientation (run this first)
          swifty-jira context --project <KEY>
        -> JSON: { user, project, activeSprint{id,name,dates,goal,boardId},
                   myOpenIssues[], hint }
        Use it to learn who the user is, the active sprint, and their open work.
        Omit --project if you only need identity + assigned issues.

        ## Read one issue in full (use whenever a ticket key is mentioned)
          swifty-jira issue export --key <KEY>
        -> JSON: summary, description, status, type, priority, assignee, reporter,
           parent(+summary), subtasks[], linkedIssues[](both directions with the
           relation, e.g. "blocks"/"is blocked by"), comments[], url.
        NEVER guess a ticket's contents — export it.

        ## List issues
          swifty-jira issue list --enable-json                 # your open issues
          swifty-jira issue list --jql "<JQL>" --enable-json   # any query
        Preset --filter values: undone | all | backlog | openSprints |
        openAndFutureSprints | <status name>. --jql overrides --filter.
        JSON: { total, returned, issues[]{key,summary,status,type,assignee,priority,...} }

        ## Discover required fields BEFORE creating (custom fields vary per project)
          swifty-jira issue createmeta --project <KEY> --type Story
          # If global createmeta is disabled (404), read from an existing issue:
          swifty-jira issue createmeta --project <KEY> --type Story --like <EXISTING-KEY>
        -> JSON: requiredFields[] + every field's id, name, required, type, allowedValues.
        To learn the exact WRITE shape of a custom field, dump a real issue:
          swifty-jira issue export --key <EXISTING-KEY> --enable-raw
        (shows e.g. customfield_10211 = {"value":"Technical Story"}, Epic Link
        customfield_10007 = "PROJ-123" as a bare string on Jira Server.)

        ## Clone an issue (EASIEST path for complex projects with required custom fields)
          swifty-jira issue clone --from <EXISTING-KEY> --summary "<new title>" \\
            [--description "<text>"] [--assignee <login>] [--sprint current|next] \\
            [--enable-dry-run]
        Copies all writable fields from the source (including required custom
        fields like Application/Service, Story Type, Epic Link) verbatim, then
        overrides summary/description. Reporter/assignee default to the current
        user. Sprint, comments, links, subtasks and system fields are stripped.
        ALWAYS run with --enable-dry-run first to preview the exact POST body;
        remove the flag to actually create. Prefer this over `create` from scratch
        when a project enforces required custom fields.

        ## Create an issue
          swifty-jira issue create --project <KEY> --type <Task|Bug|Story|Sub-task> \\
            --summary "<title>" [--description "<text>"] [--assignee <login>] \\
            [--parent <KEY>] [--sprint current|next] \\
            [--like <EXISTING-KEY>] [--fields-json '{"customfield_XXXXX":<value>, ...}'] \\
            [--enable-dry-run]
        - --like <KEY>: inherit required custom fields (Epic Link, Story Type,
          Application/Service…) from an existing issue. Use this whenever
          `createmeta` reports opaqueRequiredFields (no allowedValues). The
          inherited fields are merged before --fields-json (so --fields-json wins).
        - Sub-task REQUIRES --parent; Task/Bug/Story do not.
        - --sprint current/next adds to the sprint AFTER create via the agile API.
          Never set the Sprint customfield directly.
        - If create returns 400 the error body names the failing field.
        - --enable-dry-run prints the POST body without creating anything.
        -> JSON on success: { status:"ok", key, url }

        ## Update / fill in an issue
          swifty-jira issue update --key <KEY> --summary "<...>"
          swifty-jira issue update --key <KEY> --description "<...>"
        Use Jira wiki markup in descriptions (*bold*, # list), not Markdown.

        ## Comment (progress updates)
          swifty-jira issue comment --key <KEY> --body "<text>"

        ## Status changes
          swifty-jira issue view --key <KEY> --enable-list-statuses   # discover names
          swifty-jira issue transition --key <KEY> --status "<name>" [--resolution <r>]

        ## Interactive browser (human use; not for agents — needs a TTY)
          swifty-jira browse [--filter <preset>] [--jql "<JQL>"]
        Keys: j/k or arrows move, enter=details, e=edit fields (summary,
        description, status, priority, assignee, labels, Epic Link, raw-JSON
        custom field), f=views picker (choose/add/delete saved views; each shows
        its exact JQL; stored in ~/Library/Application Support/
        swifty-jira-views.json), / = local text search (kept across refresh),
        o=open in browser, y=copy link, r=refresh, q/esc=back/quit.

        ## Other
          swifty-jira user info
          swifty-jira project list | project view --key <KEY>
          swifty-jira issue assignee --key <KEY> --account-id <id>
          swifty-jira clean         # force re-login

        ## Rules
        1. Orient with `context`, then `issue export` before reasoning about a ticket.
        2. Before any write (create/update/comment/transition), state what you'll do
           and confirm — unless the user already told you to proceed.
        3. assignee is a login (e.g. jdoe), not a display name.
        4. Backlog vs sprint = presence/absence of --enable-sprint-current on create.
        5. On non-zero exit, read stderr and report the real error; don't retry blindly.
        6. Project key, board, and the user's role/platform vary — get the key from
           the user or from `context`; don't assume a hardcoded project.
        """
    }
}
