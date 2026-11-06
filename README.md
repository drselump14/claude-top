# claude-top

See every running [Claude Code](https://claude.com/claude-code) session at a glance — what each one is doing, which are waiting on you, and jump straight to its terminal pane.

```
 Claude sessions   WAITING:1  working:2  done:1                      14:02:11

    STATE    PROJECT              PROF ACCT TURN    TOOLS TODO  CTX   ACTIVITY
 ◆  WAITING  api-server           work alic 3m12s   14    2/5   84k   permission: Bash: npm run migrate
 ⠹  working  web-app              work alic 41s     6     -     120k  Edit: LoginForm.tsx
 ⠹  working  thesis               pers bob@ 5m02s   31    4/7   65k   [2 agents] Agent: review chapter 3
 ✔  done     infra                pers bob@ 2m10s   9     -     40k   Fixed the flaky deploy step.
```

Built for macOS + [kitty](https://sw.kovidgoyal.net/kitty/), with an optional [Alfred](https://www.alfredapp.com/) frontend.

## Features

- **Live session list** — state (waiting / working / done / error / idle), current tool call, turn time, tool count, todo progress, context size.
- **Waiting first** — sessions blocked on a permission prompt or question sort to the top.
- **Jump to session** — click a row (or press enter) to focus the exact kitty pane, across tabs and OS windows.
- **Multiple accounts** — works across separate `CLAUDE_CONFIG_DIR` profiles and shows which account each session uses.
- **Notifications** — macOS notification when a session finishes (with a summary of the result) or needs input; clicking it jumps to the pane.
- **Alfred workflow** — keyword `cls` lists sessions; ↩ jumps to one.

## How it works

```
Claude Code hooks ──► hooks/session-state.sh ──► ~/.claude/session-state/<session>.json
                                                         │
                                                  bin/ccs  (backend)
                                          ┌──────────────┴──────────────┐
                                  bin/claude-top (TUI)         Alfred workflow (cls)
```

- `hooks/session-state.sh` runs on Claude Code hook events and keeps one small JSON state file per session.
- `bin/ccs` is the backend: it reads state files, adds liveness/account/context info, and performs actions. Frontends only talk to `ccs`.
- `hooks/notify.sh` sends notifications on `Stop` / `Notification`.

## Requirements

- macOS, Python 3, `jq`
- kitty with remote control enabled (for jump-to-pane):
  ```conf
  allow_remote_control yes
  listen_on unix:/tmp/mykitty
  ```
- `terminal-notifier` for notifications (`brew install terminal-notifier`)
- Alfred 5 + Powerpack (optional)

## Install

```sh
git clone https://github.com/drselump14/claude-top.git
cd claude-top
./install.sh            # add --alfred to also import the Alfred workflow
```

The installer links `ccs` and `claude-top` into `~/.local/bin`, links the hooks into `~/.claude/hooks`, and registers them in `~/.claude/settings.json` (a backup is written next to it). Re-running is safe.

Using several profiles (`CLAUDE_CONFIG_DIR`)? Run the installer once per profile, e.g. `CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh`, or symlink the profiles' `settings.json` to one file.

Sessions appear after their next hook event (send a message in an already-running session to make it show up).

## Usage

```sh
claude-top                # live TUI
ccs list                  # plain table
ccs list --json [--all]   # data for your own frontend (--all includes dead sessions)
ccs focus <id-prefix>     # jump to a session's kitty pane
ccs forget <id-prefix>    # drop a session from the list
ccs alfred [query]        # Alfred Script Filter JSON
```

**TUI keys:** click / enter — focus · wheel / j / k — move · a — show dead sessions · x — forget · q — quit

**Alfred:** `cls [query]` — filter by project, state, profile, account or prompt. ↩ focus · ⌘ show prompt · ⌥↩ forget.

## Notes

- The hook adds roughly 70 ms per tool call; it always exits 0 and never blocks Claude.
- Todo progress is read from `TodoWrite` tool calls.
- State files are removed on `SessionEnd`; sessions whose process died are hidden (show them with `a` / `--all`).

## License

MIT
