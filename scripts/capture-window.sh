#!/bin/zsh
# Opens a .shotset in the built app and captures its window to a PNG.
# Needs Screen Recording permission for the calling process.
# Usage: scripts/capture-window.sh <project.shotset> <output.png>
set -euo pipefail
cd "${0:A:h}/.."
project="${1:?project path}"
output="${2:?output png}"
app="$PWD/build/Screenshot Builder.app"
pkill -x ScreenshotBuilder 2>/dev/null || true
open -n -a "$app" "$project"
for _ in {1..40}; do
  id=$(swift scripts/window-id.swift "${project:t}" 2>/dev/null || true)
  [[ -n "$id" ]] && break
  sleep 0.25
done
[[ -n "${id:-}" ]] || { print "No Screenshot Builder window found"; exit 1; }
osascript -e 'tell application "System Events" to tell process "ScreenshotBuilder" to set frontmost to true' >/dev/null
sleep 1.5
screencapture -x -o -l "$id" "$output"
print "Captured $output"
