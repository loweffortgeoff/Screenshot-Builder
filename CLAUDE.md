# Matte (Screenshot-Builder): notes for Claude

Read `README.md` first. Global rules are in `~/.claude/CLAUDE.md`.

## Installed copy
- `scripts/build-app.sh` updates only `build/Matte.app`. Geoff runs `/Applications/Matte.app`, which stays old until he runs `ditto build/Matte.app /Applications/Matte.app`. Before a manual test, check which binary runs with `pgrep -lf MacOS/ScreenshotBuilder` (2026-11-16).

## Live window captures
- `scripts/capture-window.sh` fails from a Claude Code shell with "could not create image from window": the shell has no Screen Recording permission (MacBook Pro, 2026-11-15; not checked on the Mac mini).
- Instead, open the project with `open -n -a build/Matte.app <project.shotset>`, then capture with the computer-use `app_screenshot` tool on bundle ID `com.loweffortapps.screenshotbuilder` (request access first). This works in the background.
- `capture-window.sh` runs `pkill -x ScreenshotBuilder`. Check `pgrep -lx ScreenshotBuilder` first so an open Matte with unsaved work is not killed.
- When Geoff already has Matte open, do not run `scripts/build-app.sh`: it copies over the running binary and can crash his window. Run a second copy instead:
  1. Run `swift build`, copy `build/Matte.app` to the scratchpad, and put `.build/debug/ScreenshotBuilder` into the copy.
  2. Give the copy its own bundle ID, for example `com.loweffortapps.screenshotbuilder.scratch` (PlistBuddy `Set :CFBundleIdentifier`), then run `codesign --force --sign -`. `app_screenshot` attaches to the first process with a bundle ID, so a copy with the same ID cannot be captured.
  3. Launch with `open -n -a <copy> <project> --args -ApplePersistenceIgnoreState YES`. Without that flag, restored windows reopen files from earlier runs, and Matte autosaves them. Open only scratchpad copies of projects, never the originals in `Dev Workstation`.
  4. Afterwards, quit the copy and unregister it with `lsregister -u <copy>`, so `build/Matte.app` stays the `.shotset` handler.
- On the MacBook Pro's ultra-wide display (3440 × 1440), Matte document windows grow to 1385 pt tall. For a check at 1440 × 920, drag the window's bottom edge with `app_drag`. Confirm the size with `app_list_windows`, then check the capture's coordinate frame, because the listed bounds can be out of date (2026-11-15).
