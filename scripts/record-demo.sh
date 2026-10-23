#!/bin/bash
# Records docs/demo.gif: types the demo into a new Terminal window with real key presses, lets
# the running Typo fix it, logs every byte that reaches the terminal and renders that log.
# Needs Typo running, the U.S. and Russian – PC layouts, and Accessibility for the app that runs
# this script (to post key presses). Hands off the keyboard and mouse while it types: it stops
# as soon as Terminal is no longer in front.
# Usage: scripts/record-demo.sh
set -euo pipefail
cd "$(dirname "$0")/.."

WORK=build/demo
rm -rf "$WORK"
mkdir -p "$WORK"
swiftc -O scripts/demo-typer.swift -o "$WORK/typer"
swiftc -O scripts/render-demo.swift -o "$WORK/render"

cat > "$WORK/record.command" <<EOF
#!/bin/sh
exec /usr/bin/python3 -I "$PWD/scripts/demo-recorder.py" "$PWD/$WORK/log.jsonl"
EOF
chmod +x "$WORK/record.command"
open -a Terminal "$WORK/record.command"

"$WORK/typer" "привет" "перезапусти nginx и обнови nodejs" "pushed the fix to github"
"$WORK/render" "$WORK/log.jsonl" docs/demo.gif
echo "Built docs/demo.gif"
