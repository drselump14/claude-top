#!/usr/bin/env bash
# Install claude-top: link commands + hooks, register hooks in Claude Code settings.
# Idempotent: safe to re-run. Usage: ./install.sh [--alfred]
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
bin_dir="${BIN_DIR:-$HOME/.local/bin}"
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$claude_dir/settings.json"
hook_dir="$claude_dir/hooks"

for dep in jq python3; do
  command -v "$dep" >/dev/null || { echo "missing dependency: $dep" >&2; exit 1; }
done
command -v terminal-notifier >/dev/null || echo "note: terminal-notifier not found (brew install terminal-notifier) — notifications disabled"
command -v kitty >/dev/null || echo "note: kitty not found — focus/jump features need kitty with allow_remote_control + listen_on"

mkdir -p "$bin_dir" "$hook_dir"
for f in "$repo"/bin/*; do ln -sf "$f" "$bin_dir/$(basename "$f")"; done
for f in "$repo"/hooks/*.sh; do ln -sf "$f" "$hook_dir/$(basename "$f")"; done
echo "linked commands -> $bin_dir, hooks -> $hook_dir"

# Register hooks (skip ones already present).
[[ -f $settings ]] || echo '{}' > "$settings"
cp "$settings" "$settings.bak.claude-top"
tmp=$(mktemp)
jq --arg state "$hook_dir/session-state.sh" --arg notify "$hook_dir/notify.sh" '
  def add(ev; cmd; extra):
    if any(.hooks[ev][]?.hooks[]?; (.command // "") | endswith("/" + (cmd | split("/") | last))) then .
    else .hooks[ev] = ((.hooks[ev] // []) + [{"hooks": [({"type": "command", "command": cmd, "timeout": 5} + extra)]}])
    end;
  reduce ("SessionStart","UserPromptSubmit","PreToolUse","PostToolUse","PermissionRequest",
          "Notification","Stop","StopFailure","SubagentStart","SubagentStop","SessionEnd") as $e
    (.; add($e; $state; {}))
  | add("Stop"; $notify; {"async": true, "timeout": 10})
  | add("Notification"; $notify; {"async": true, "timeout": 10})
' "$settings" > "$tmp" && cat "$tmp" > "$settings" && rm -f "$tmp"
echo "registered hooks in $settings (backup: $settings.bak.claude-top)"

if [[ ${1:-} == --alfred ]]; then
  wf=$(python3 "$repo/alfred/build.py")
  open "$wf"
  echo "opened $wf — confirm the import in Alfred"
fi

case ":$PATH:" in *":$bin_dir:"*) ;; *) echo "add $bin_dir to PATH";; esac
echo "done. run: claude-top   (or: ccs list)"
