#!/usr/bin/env bash
# Claude Code Stop/Notification hook -> macOS notification (click focuses kitty).
# Stop: shows a short summary of Claude's final reply. Notification: shows Claude's message.
input=$(cat)
proj=$(jq -r '.cwd // "" | split("/")[-1]' <<<"$input")
event=$(jq -r '.hook_event_name // ""' <<<"$input")
sid=$(jq -r '.session_id // ""' <<<"$input")
tp=$(jq -r '.transcript_path // empty' <<<"$input")

# --- which session: name (/rename > auto title > last prompt), kitty tab, account profile
name=""
if [[ -f $tp ]]; then
  name=$(grep -E '"type":"custom-title"' "$tp" | tail -1 | jq -r '.customTitle // empty' 2>/dev/null)
  [[ -z $name ]] && name=$(grep -E '"type":"ai-title"' "$tp" | tail -1 | jq -r '.aiTitle // empty' 2>/dev/null)
fi
if [[ -z $name && -f $HOME/.claude/session-state/$sid.json ]]; then
  name=$(jq -r '.prompt // empty' "$HOME/.claude/session-state/$sid.json")
fi
(( ${#name} > 60 )) && name="${name:0:57}..."
[[ -z $name ]] && name="Claude Code"

case "$(basename "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")" in
  .claude-work) profile=cwk ;; .claude-personal) profile=cpr ;; *) profile=main ;;
esac

tab=""
if [[ -n ${KITTY_WINDOW_ID:-} && -n ${KITTY_LISTEN_ON:-} ]]; then
  tab=$(kitty @ --to "$KITTY_LISTEN_ON" ls --match "id:$KITTY_WINDOW_ID" 2>/dev/null \
        | jq -r '[.[].tabs[] | select(.windows | length > 0) | .title] | first // empty' 2>/dev/null)
fi
subtitle="$proj"
[[ -n $tab && $tab != "$proj" && $tab != *"$proj" ]] && subtitle+=" · tab: $tab"
subtitle+=" · $profile"

if [[ $event == Notification ]]; then
  title="⏳ $name"
  msg=$(jq -r '.message // "Needs your input"' <<<"$input")
else
  title="✅ $name"
  msg=$(jq -r '.last_assistant_message // empty' <<<"$input")
  if [[ -z $msg ]]; then
    [[ -f $tp ]] && msg=$(tail -n 200 "$tp" | jq -rs '
      [ .[] | select(.type=="assistant")
            | (.message.content // []) | map(select(.type=="text") | .text) | join("\n")
            | select(length > 0) ] | last // empty')
  fi
  # strip markdown, collapse whitespace, truncate
  msg=$(printf '%s' "$msg" | sed -E 's/```[a-z]*//g; s/[*_`#>|]//g; s/^[[:space:]]*[-•][[:space:]]+//' \
        | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed -E 's/^ //')
  (( ${#msg} > 220 )) && msg="${msg:0:217}..."
  [[ -z $msg ]] && msg="Task done"
fi

# terminal-notifier treats a leading "-" or "[" specially; prefix guard
[[ $msg == [-\[]* ]] && msg=" $msg"
# On click: focus the exact kitty pane running this Claude session, then raise kitty.
click=(-activate net.kovidgoyal.kitty)
if [[ -n ${KITTY_WINDOW_ID:-} && -n ${KITTY_LISTEN_ON:-} ]]; then
  kitty_bin=$(command -v kitty || echo /opt/homebrew/bin/kitty)
  click=(-execute "$kitty_bin @ --to '$KITTY_LISTEN_ON' focus-window --match id:$KITTY_WINDOW_ID; open -b net.kovidgoyal.kitty")
fi
terminal-notifier -title "$title" -subtitle "$subtitle" -message "$msg" \
  -sound default -group "cc-$proj-${KITTY_WINDOW_ID:-0}" "${click[@]}" >/dev/null 2>&1
exit 0
