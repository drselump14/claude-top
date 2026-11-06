#!/usr/bin/env python3
"""Build Claude-Sessions.alfredworkflow (keyword: cls) that fronts the `ccs` backend."""
import plistlib, uuid, zipfile
from pathlib import Path

here = Path(__file__).resolve().parent
env = 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"\n'
sf, act = str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
CMD, ALT = 1048576, 524288

info = {
    "bundleid": "local.ccs.claude-sessions",
    "name": "Claude Sessions",
    "description": "List Claude Code sessions and jump to their kitty pane",
    "createdby": "ccs",
    "category": "Tools",
    "disabled": False,
    "version": "1.0",
    "webaddress": "",
    "readme": "cls [query]  — list sessions (waiting/working first)\n"
              "↩ focus kitty pane · ⌘ show prompt · ⌥↩ forget session\n"
              "Backend: ~/.local/bin/ccs",
    "objects": [
        {"type": "alfred.workflow.input.scriptfilter", "uid": sf, "version": 3, "config": {
            "keyword": "cls", "withspace": True, "argumenttype": 1,
            "title": "Claude sessions", "subtext": "Jump to a Claude Code session",
            "runningsubtext": "Loading sessions…",
            "type": 0, "scriptargtype": 1, "scriptfile": "", "escaping": 102,
            "script": env + 'ccs alfred "$1"',
            "alfredfiltersresults": False, "alfredfiltersresultsmatchmode": 0,
            "queuemode": 1, "queuedelaymode": 0, "queuedelaycustom": 3,
            "queuedelayimmediatelyshowsresults": True,
        }},
        {"type": "alfred.workflow.action.script", "uid": act, "version": 2, "config": {
            "type": 0, "scriptargtype": 1, "scriptfile": "", "escaping": 102, "concurrently": False,
            "script": env + 'ccs alfred-action "$1"',
        }},
    ],
    "connections": {sf: [
        {"destinationuid": act, "modifiers": m, "modifiersubtext": "", "vitoclose": False}
        for m in (0, CMD, ALT)
    ]},
    "uidata": {sf: {"xpos": 50, "ypos": 50}, act: {"xpos": 300, "ypos": 50}},
}

out = here / "Claude-Sessions.alfredworkflow"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("info.plist", plistlib.dumps(info))
print(out)
