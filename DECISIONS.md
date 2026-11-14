# Decisions

- 2026-09-07: Build the approved fixed-layout v1. Use SwiftUI, local document projects, and no external dependencies.
- 2026-09-07: Use one shared renderer for preview and export. Keep source captures proportional and uncropped.
- 2026-09-07: Reserve a fixed caption band for caption layouts so source images stay aligned across different caption lengths.
- 2026-09-07: Size the fixed caption band from the shorter canvas edge, capped for landscape output; keep shots aligned with tighter margins.
- 2026-11-13: Bump the project format to version 2. Decode missing style keys with defaults, so version 1 projects open; a version 1 solid color becomes a solid background.
- 2026-11-13: Ship curated themes (background, text, accent) and gradient fills drawn by the shared renderer. Theme swatches use the same drawing code, so they match the export. Mesh fills are a gradient base with soft glows, not a mesh renderer.
- 2026-11-13: Draw device frames in code from measured Apple Design Resources geometry (screen opening equals native pixels; radii by the 45° diagonal method). Do not bundle Apple images. Supersedes "Keep source captures uncropped": a frame clips only the display corners, and a mismatched capture sits on black glass rather than being cropped.
- 2026-11-13: Replace the v1 "simple device frame" toggle with None, Rounded, and Device styles. Version 1 projects with the toggle on open with the Device style.
- 2026-11-13: Size the caption band per set: tall enough for the longest caption, capped at two headline lines plus two subtitle lines. Headlines in a set share a line count (short headlines of three or more words wrap to match) and start on one baseline, so headlines and screenshots align with no dead gap. Supersedes the fixed caption-band entries.
- 2026-11-13: Balance wrapped captions by narrowing to the smallest width that keeps the line count. Store accent words per shot (set from the Highlight menu) so the headline field stays plain text; typed *asterisks* remain supported.
- 2026-11-13: Add bleed templates that run the device off the top or bottom edge, still within the fixed-layout model (no freeform editing). Sidebar and filmstrip show composed thumbnails rendered by the shared renderer.
- 2026-11-13: The filmstrip is the main navigator and the list sidebar starts hidden. The inspector splits into Caption, Style, and Device tabs.
- 2026-11-13: Accept the UI score from an ad-hoc council (Opus, Sonnet, Fable judges, fixed rubric, median) because no /council skill exists. Rounds capped at 3 per chapter.
- 2026-11-13: Chapter 2. Each shot can override the set layout with an arrangement: Tilt, Hero, Duo (back screen from another shot, default the next), or Zoom callout. Arrangements keep the shared caption band and shift away from the caption. Project format version 3, so older builds refuse files that carry arrangements.
- 2026-11-13: Zoom callout regions default to Auto, which picks the third of the capture with the most luminance variation, skipping the status bar and the bottom bar.
- 2026-11-13: Drop the bleed fade (council round 3: it tinted the screenshot). Theme colors must pass a 3:1 large-text contrast test against every background color.
- 2026-11-13: Badges are per shot. Any badge in a set reserves the badge row on every shot, so headlines stay aligned.
- 2026-11-13: Geoff accepted a council median of 7.5 for chapters 1 and 2. The 8.0 target was not met. The remaining gaps move to a chapter 3 spec (editor canvas, Zoom, iPad scale, Mac frame, caption compositions).
