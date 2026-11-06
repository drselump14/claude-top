#!/usr/bin/env bash
# Claude Code hook: keep one JSON state file per session in ~/.claude/session-state/
# for the `claude-top` TUI. Wired to: SessionStart, UserPromptSubmit, PreToolUse,
# PostToolUse, PermissionRequest, Notification, Stop, StopFailure, SubagentStart,
# SubagentStop, SessionEnd. Always exits 0 so it can never block Claude.

dir="$HOME/.claude/session-state"
mkdir -p "$dir"
input=$(cat)

sid=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null)
[[ -z $sid || -z $event ]] && exit 0
file="$dir/$sid.json"

if [[ $event == SessionEnd ]]; then
  rm -f "$file"
  exit 0
fi

# Claude process pid: the hook's parent, or its parent if a wrapper shell sits between.
pid=$PPID
if ! ps -o command= -p "$pid" 2>/dev/null | grep -qi claude; then
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
fi

prev='{}'
[[ -f $file ]] && prev=$(cat "$file" 2>/dev/null || echo '{}')

tmp=$(mktemp "$dir/.tmp.XXXXXX")
jq -n \
  --argjson in "$input" \
  --argjson prev "$prev" \
  --arg now "$(date +%s)" \
  --arg pid "${pid:-0}" \
  --arg kwin "${KITTY_WINDOW_ID:-}" \
  --arg klisten "${KITTY_LISTEN_ON:-}" \
  --arg cfg "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" '
  def clip(n): tostring | gsub("[\\n\\t ]+"; " ") | if length > n then .[0:n-1] + "…" else . end;
  def activity:
    ($in.tool_name // "?") as $t
    | ($in.tool_input // {}) as $i
    | ($t | sub("^mcp__[^_]+(_[^_]+)*__"; "")) as $short
    | if   $t == "Bash" then "Bash: " + ($i.command // "" | clip(70))
      elif ($t | test("^(Edit|Write|Read|NotebookEdit)$")) then $t + ": " + ($i.file_path // $i.notebook_path // "" | split("/") | last)
      elif ($t | test("^(Grep|Glob)$")) then $t + ": " + ($i.pattern // "" | clip(50))
      elif ($t | test("^(Agent|Task)$")) then "Agent: " + ($i.description // $i.prompt // "" | clip(60))
      elif $t == "WebFetch" then "Fetch: " + ($i.url // "" | clip(60))
      elif $t == "Skill" then "Skill: " + ($i.skill // "")
      else $short
      end;
  ($now | tonumber) as $ts
  | $in.hook_event_name as $ev
  | ($prev + {
      session_id: $in.session_id,
      cwd: ($in.cwd // $prev.cwd // ""),
      transcript_path: ($in.transcript_path // $prev.transcript_path // ""),
      pid: ($pid | tonumber),
      kitty_window_id: $kwin,
      kitty_listen_on: $klisten,
      config_dir: $cfg,
      updated: $ts,
      started: ($prev.started // $ts)
    }) as $s
  | if $ev == "SessionStart" then
      $s + {state: "idle", activity: ("session " + ($in.source // "start"))}
    elif $ev == "UserPromptSubmit" then
      $s + {state: "working", prompt: ($in.prompt // "" | clip(200)), activity: "thinking…",
            turn_start: $ts, turn_end: null, tools: 0, subagents: 0}
    elif $ev == "PreToolUse" then
      $s + {state: "working", activity: activity, tools: (($s.tools // 0) + 1)}
    elif $ev == "PostToolUse" then
      $s + {state: "working"}
      + (if ($in.tool_name == "TodoWrite") and ($in.tool_input.todos | type == "array") then
           {todo_done: ([$in.tool_input.todos[] | select(.status == "completed")] | length),
            todo_total: ($in.tool_input.todos | length),
            todo_current: ([$in.tool_input.todos[] | select(.status == "in_progress") | (.activeForm // .content)] | first // null)}
         else {} end)
    elif $ev == "PermissionRequest" then
      $s + {state: "waiting", activity: ("permission: " + activity)}
    elif $ev == "Notification" then
      # idle reminder ("waiting for your input") is not a blocker; only real prompts are.
      (($in.notification_type // "") == "idle_prompt"
        or (($in.message // "") | test("waiting for your input"; "i"))) as $idle
      | if $idle then
          (if ($s.state // "") == "" or $s.state == "waiting" then $s + {state: "idle"} else $s end)
        else $s + {state: "waiting", activity: ($in.message // "needs input" | clip(80))}
        end
    elif $ev == "Stop" then
      $s + {state: "done", turn_end: $ts,
            activity: ($in.last_assistant_message // "done" | clip(120))}
    elif $ev == "StopFailure" then
      $s + {state: "error", turn_end: $ts, activity: ($in.error // $in.reason // "API error" | clip(80))}
    elif $ev == "SubagentStart" then
      $s + {subagents: (($s.subagents // 0) + 1)}
    elif $ev == "SubagentStop" then
      $s + {subagents: ([($s.subagents // 1) - 1, 0] | max)}
    else $s end
' >"$tmp" 2>/dev/null && mv "$tmp" "$file" || rm -f "$tmp"
exit 0
