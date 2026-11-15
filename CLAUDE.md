# Matte (Screenshot-Builder): notes for Claude

Read `README.md` first. Global rules are in `~/.claude/CLAUDE.md`.

## Live window captures
- `scripts/capture-window.sh` fails from a Claude Code shell with "could not create image from window": the shell has no Screen Recording permission (Mac mini, 2026-11-15).
- Instead, open the project with `open -n -a build/Matte.app <project.shotset>`, then capture with the computer-use `app_screenshot` tool on bundle ID `com.loweffortapps.screenshotbuilder` (request access first). This works in the background.
- `capture-window.sh` runs `pkill -x ScreenshotBuilder`. Check `pgrep -lx ScreenshotBuilder` first so an open Matte with unsaved work is not killed.
