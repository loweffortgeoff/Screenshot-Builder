# Decisions

- 2026-09-07: Build the approved fixed-layout v1. Use SwiftUI, local document projects, and no external dependencies.
- 2026-09-07: Use one shared renderer for preview and export. Keep source captures proportional and uncropped.
- 2026-09-07: Reserve a fixed caption band for caption layouts so source images stay aligned across different caption lengths.
- 2026-09-07: Size the fixed caption band from the shorter canvas edge, capped for landscape output; keep shots aligned with tighter margins.
- 2026-11-13: Bump the project format to version 2. Decode missing style keys with defaults, so version 1 projects open; a version 1 solid color becomes a solid background.
- 2026-11-13: Ship curated themes (background, text, accent) and gradient fills drawn by the shared renderer. Theme swatches use the same drawing code, so they match the export. Mesh fills are a gradient base with soft glows, not a mesh renderer.
- 2026-11-13: Draw device frames in code from measured Apple Design Resources geometry (screen opening equals native pixels; radii by the 45° diagonal method). Do not bundle Apple images. Supersedes "Keep source captures uncropped": a frame clips only the display corners, and a mismatched capture sits on black glass rather than being cropped.
- 2026-11-13: Replace the v1 "simple device frame" toggle with None, Rounded, and Device styles. Version 1 projects with the toggle on open with the Device style.
