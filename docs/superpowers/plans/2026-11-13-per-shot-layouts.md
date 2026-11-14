# Screenshot Builder — Per-shot layouts (chapter 2)

Status: complete. Approved 2026-11-13 (full-send). Final council median 7.5, below the 8.0 target; Geoff accepted 7.5 on 2026-11-13. Remaining gaps: `docs/superpowers/specs/2026-11-13-chapter-3-canvas-and-compositions.md`.

## Context

Chapter 1 ended at a council median of 7.3 (Opus 7.0, Sonnet 7.3, Fable 7.3). All three judges capped competitiveness at 6–7 because every shot in a set uses the same arrangement. Geoff chose to expand scope: each shot can have its own arrangement. Done when the same three judges (Opus, Sonnet, Fable, same rubric) give a median of 8 or more. Stop and ask after 3 rounds below 8.

## Geoff's decisions (2026-11-13)

- Arrangements: Tilt, Hero offset, Duo, Zoom callout.
- Duo back screen: another shot from the set, chosen from a menu (default: the next shot).
- A "Vary layouts" button assigns a curated sequence. New sets stay uniform until it is clicked.
- Contrast: retune theme colors so every theme passes a contrast test.

## Design

**Model**
- `Shot.arrangement`: `standard` (follows the set layout), `tiltLeft`, `tiltRight`, `heroLeft`, `heroRight`, `duo`, or `callout`.
- `Shot.companion: UUID?` sets the Duo back screen. `nil` means the next shot.
- `Shot.calloutRegion`: top, middle, or bottom third of the capture.
- Project format version 3. Older projects open as `standard`. Version 3 makes older builds refuse a new file instead of silently dropping arrangements.

**Rendering** (one shared renderer, as before)
- `compose` returns placed devices (rect, rotation, capture) plus an optional callout card. The set layout (top, bottom, bleed) still defines the image area and the shared caption band, so captions stay aligned across the set.
- **Tilt:** the device rotates ±10° around its center (a CTM rotation, so frame, screen clip, and capture rotate together), grows by about 8%, and may run off the bottom edge. Shadows stay downward.
- **Hero:** the device grows by about 18% and shifts so about a quarter runs off the left or right edge.
- **Duo:** the back device is at about 88% size, tilted −8°, and offset to one side, showing the companion capture. The front device is tilted +4°. Both stay readable.
- **Zoom callout:** a rounded card shows the chosen third of the capture at about 1.6×. It has a light border and a strong shadow, and it overlaps the device's lower side edge.
- Every arrangement works with every device size and orientation. Tests check placement bounds for each one.

**Editor**
- **Caption tab:** an "Arrangement" row of diagram tiles, like the layout tiles, under the shot fields. Duo shows a "Back screen" menu. Callout shows a Top/Middle/Bottom segment.
- **Style tab, Layout section:** a "Vary layouts" button assigns the curated sequence (tilt right, duo, callout, hero left, tilt left, standard, hero right, …). Each Duo uses the next shot as its back screen. A "Make uniform" button resets every shot to standard.
- **Filmstrip and sidebar:** thumbnails show each shot's arrangement.

## Folded-in fixes (separate fix commits, done first)

1. **Bleed fade:** remove it and go back to a clean cut at the canvas edge. Round 3 said the fade tinted the screenshot.
2. **Theme contrast:** add a WCAG contrast test. Headline, subtitle (82% alpha), and accent must each reach at least 3:1 against every background color (large-text threshold). Retune the failing themes, including Sunset and Peach, while keeping their character.
3. **Empty state:** the import card sits inside the blank device screen as the drop target, so it no longer covers the device.
4. **Capture-fit warning:** when a capture's shape does not match the device screen by more than 3% (for example an iPhone capture in an iPad frame), show a non-blocking warning in the Caption tab and a badge on the filmstrip tile. It suggests a matching capture or the Rounded frame.

## Sample captures (scratchpad only, never committed)

- **iPhone 6.9":** the existing 5 List Happens captures (1320×2868).
- **iPad 13":** 5 captures from the iPad Pro 13-inch (M5) simulator (iOS 27.2, `364195A0`) running Bookmark-Collections, which supports iPad. It has no demo-data mode, so I add a few sample collections through its UI in the simulator. Fallbacks: Weather-in-Words or Muzzletoff (both support iPad).
- **Mac:** captures of the Screenshot Builder window (the realistic Mac App Store pattern), which use the window-on-wallpaper path.

## Milestones (each one is a review stop unless Geoff says full-send)

- **N0 — Fixes and samples:** fixes 1–4 as fix commits; iPad captures; harness knob `SB_ARRANGE`.
- **N1 — Arrangements in the model and renderer:** the four arrangements, format v3 and migration, and tests (bounds per size, orientation, and arrangement; rotation keeps the capture upright relative to its device; Duo companion fallback; callout crop).
- **N2 — Editor:** arrangement tiles, Duo and callout controls, Vary layouts and Make uniform, thumbnails. Live-app smoke test: click each arrangement and check the preview changes.
- **N3 — Council:** freeze the candidate first (code review, fixes, full `swift test`), then run up to 3 rounds. Each round gets fresh inputs from the frozen SHA: editor tabs, empty state, a varied iPhone set, an iPad set from real iPad captures, a Mac export, and full-size singles. The rubric and prompt stay unchanged. Median ≥ 8 means done. After 3 rounds below 8, stop and ask.

## Verification

- Focused `swift test --filter BuilderTests/<test>` during work. Full `swift test` before each council round and before handoff.
- Render every arrangement × device family with the harness and look at the PNGs. Capture the live window with `scripts/capture-window.sh` and click controls through the accessibility helper.
- Report each round's three scores and the median, with the build SHA.

## Human stops

**Unavoidable**
1. Now: approve this plan.
2. End: hands-on check on the MacBook Pro (one build, about 15 minutes).
3. End: push and merge decisions.

**Contingencies**
- The MacBook Pro locks or sleeps, so window captures come out black. Fallback: render-only review, or ask Geoff to unlock it.
- Bookmark-Collections cannot show meaningful iPad content. Then switch to the fallback apps, or ask Geoff for iPad captures.
- The council stays below 8 after 3 rounds. Then ask Geoff.

Simulators: I take the iPad Pro 13-inch (M5), `364195A0`, iOS 27.2, and announce when I take and release it. The iPhone 18 Pro Max captures already exist, so I do not boot that simulator.

## Council results (chapter 2)

| Round | Build | Opus | Sonnet | Fable | Median |
|---|---|---|---|---|---|
| 1 | 6353afa | 7.1 | 7.1 | 7.1 | 7.1 |
| 2 | c51d751 | 7.1 | 7.2 | 7.2 | 7.2 |
| 3 (final) | 02f969c | 7.1 | 7.6 | 7.5 | 7.5 |

Result: below 8.0 after the 3-round cap. Escalated on 2026-11-13; Geoff accepted 7.5 the same day.

Themes that repeat across all three judges in round 3:
- Zoom: the crop still cuts a line ("Spend Over Time") on the List Happens Spending screen, and the magnification is low.
- Editor: the preview is small, there is no zoom or whole-set view and no direct caption editing on the canvas, and the Caption and Device tabs look like bare forms.
- iPad: devices fill too little of the canvas.
- Mac: the frame looks schematic next to the iPhone frame.
- Opus and Sonnet ask for more caption compositions (text beside the device, big-number layouts).

