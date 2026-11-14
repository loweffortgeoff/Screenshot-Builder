# Screenshot Builder — Chapter 3 spec: canvas, Zoom, iPad, Mac, and compositions

Status: spec only, written 2026-11-13, updated 2026-11-14 with Geoff's hands-on findings and his answers (see "Hands-on findings" and "Resolved questions"). Not approved. No implementation exists.
Branch `feature/pro-framing`, after `4c87fc2`.

## Why

Chapters 1 and 2 raised the ad-hoc UI council median from 3.8 to 7.5. Geoff accepted 7.5 on 2026-11-13. The 8.0 target was not met. In the final round (build `02f969c`), the judges repeated five complaints:

1. **Zoom callout.** The crop still cuts a line on some screens ("Spend Over Time" on the List Happens Spending screen). The zoom is only about 1.3×. The heavy white strokes and the short connector look rough. (All three judges.)
2. **Editor canvas.** The preview is small, and there is no zoom. There is no view of the whole set at a useful size. Captions cannot be edited on the canvas. The Caption and Device tabs look like bare forms. (All three.)
3. **iPad.** Devices fill only about half the canvas, and the iPad Duo looks like it floats. (Opus, Fable.)
4. **Mac frame.** It looks schematic next to the iPhone: a flat base and a thick bezel and chin. (Fable, and Sonnet in round 2.)
5. **Captions.** Every shot uses the same composition: a centered headline over the device. The judges asked for text beside the device and big-number layouts. (Opus, Sonnet.)

## Goal and done-when

- Address all five complaints within the fixed-layout model. Out of scope: freeform drag of arbitrary layers, stickers, and AI copy, as stated in the TODO backlog.
- Done when the same council gives a median of 8.0 or more: the same three judges (Opus, Sonnet, Fable), the same rubric (`council-rubric.md`, seven criteria), the same input list, and a rebuild from the frozen SHA. The cap is 3 rounds, then ask Geoff.
- Every existing `.shotset` file, versions 1 to 3, still opens and renders the same as before, unless the user changes a new setting.

## Requirements

### R1 — Zoom callout quality

| ID | Requirement | How to check |
|---|---|---|
| R1.1 | The crop never cuts a text line. Snap the crop to **block** boundaries: runs of busy rows separated by quiet gaps of at least 1% of the capture height. Snapping to single quiet rows is not enough. If no block fits within 0.10–0.24 of the capture height, take the block nearest the target and trim it to whole rows. | Unit test: synthetic capture with text-like stripe blocks; crop edges fall in gaps. Render check on all 5 List Happens captures and all 5 Bookmark-Collections captures with Auto, Top, Middle, and Bottom: no glyph is cut at the card edge. |
| R1.2 | Magnification is at least 1.6× and at most 2.2× on iPhone and iPad. On Mac it is at least 1.5×. The card width follows from that. When the card would exceed 0.78 × canvas width, crop a narrower band instead of reducing the zoom. | Test: card width ÷ highlight width ≥ 1.6 for every preset, orientation, and layout. |
| R1.3 | New visual treatment. The card has a thin 1.5 pt (canvas-scaled) light border and a soft shadow. The highlight ring is thinner, with a faint inner fill (white at 8%). The connector is a tapered "lens" shape joining two ring corners to two card corners, instead of a stub line. A "Lens style" option offers Lens (default) and Line (the current style). | Visual check at full size. A snapshot test compares the connector path against the four corner points. |
| R1.4 | Manual region and card position. Besides Auto, Top, Middle, and Bottom, a "Custom" region stores a unit rect. In the editor the user drags the highlight ring on the preview (see R2.4); the rect snaps to blocks on release. The card can also be dragged; its position is stored per shot as a unit offset and is clamped to the safe margin and away from captions. "Reset position" returns it to automatic placement. | Model test: custom rect and card offset round-trip through encode and decode. UI smoke test: dragging the ring changes what the card shows; dragging the card moves only the card; the export matches. |
| R1.6 | The source marker must not read as a second card (H1). Replace the current white box, which repeats the card's border, with a **spotlight**: the rest of the screen dims by about 35%, and the source rows get a thin accent-colored outline with no fill. The card keeps the only white border. A "Marker" option offers Spotlight (default), Outline, and None. | Visual check: in a set of 5 Zoom shots, a reviewer cannot mistake the marker for a second magnified card. Snapshot test: the marker stroke color equals the theme accent, and the stroke width is at most 40% of the card border width. |
| R1.5 | The card never covers more than 10% of the ring height. It never leaves the canvas safe margin. It never touches caption text. | Extend `everyArrangementStaysVisibleAndClearOfCaptions`. |

### R2 — Editor canvas

| ID | Requirement | How to check |
|---|---|---|
| R2.1 | **Fit-to-pane preview.** The preview grows to fill the canvas pane with a 24 pt margin, instead of rendering at a fixed size. It renders at the pane's backing-pixel size, capped at the export size, and re-renders after 120 ms of no resizing. | Window capture at 1440 × 920: the preview height is at least 85% of the pane height. |
| R2.2 | **Zoom controls.** The toolbar gets − / Fit / 100% / + controls and the shortcuts ⌘−, ⌘0, ⌘1, ⌘=. Pinch on the trackpad zooms. At zoom levels above Fit, the preview scrolls and the render resolution follows the zoom level. | Live smoke test through the accessibility helper: zoom in, check the scroll area appears and the render is sharp at 100%. |
| R2.3 | **Set view.** A Canvas / Set toggle in the toolbar (⌘2) shows all shots side by side, as in App Store Connect, at the largest size that fits. Clicking a shot selects it and returns to Canvas. Dragging in Set view reorders shots. The filmstrip stays in Canvas view. | Live capture of Set view with 5 shots: every shot is at least 280 pt tall at 1440 × 920. A reorder by drag persists after save and reopen. |
| R2.4 | **On-canvas editing.** Double-click the headline or the subtitle on the preview to edit it in place. The editor is an overlay text field, styled at the preview scale, that commits on Return or click-away and cancels on Esc. Double-click the badge to edit it. In Zoom arrangement, the highlight ring can be dragged (R1.4). A single click on the device selects the shot and opens the Style tab's arrangement section. | Live smoke test: double-click the headline, type, press Return; the inspector field and the export match. Esc restores the old text. |
| R2.5 | **Caption tab craft.** The font picker shows each family rendered in that family, as a grid of "Ag" tiles with names. Weight becomes a segmented control that previews the weight and **lists only the weights the family really has** (H2). Each step must resolve to a different face of the same width: for example, Futura offers Medium and Bold only, because its "Heavy" is the same face as Bold and its "Black" is Condensed ExtraBold. A stored weight the family lacks maps to the nearest real face and shows that face's name. The subtitle weight is always at least one real step lighter than the headline weight. The Highlight menu stays, and a hint line under the headline explains it. Headline and subtitle fields use a larger, two-line minimum editor. | Window capture of the Caption tab: no plain popup remains for font or weight. Unit test: for every family, each offered weight resolves to a distinct font name with the same width trait, and the headline face differs from the subtitle face. |
| R2.6 | **Device tab craft.** Finish swatches are 28 pt with a name under each and a tooltip. The Device section shows the selected device name and a small diagram of the current frame. The empty space is filled by moving **Shadow** and **Size** into a "Placement" group with a live mini preview, not by padding. | Window capture: no swatch without a label. |

### R3 — iPad scale and composition

| ID | Requirement | How to check |
|---|---|---|
| R3.1 | On iPad presets, the Standard device fills at least 70% of the canvas width in portrait. Today it fills about 55%. Grow the image area by reducing iPad side margins, and allow `imageScale` up to 1.0 to mean "edge to the safe margin". | Test: for `pad13` and `pad11` portrait with Standard, device width ≥ 0.70 × canvas width. |
| R3.2 | iPad Duo: back device at 0.78, front at 0.86 of the Standard size, offset vertically by 6% so the pair reads as grounded. Both stay inside the side safe margin. | Test plus render check on the Bookmark-Collections set. |
| R3.3 | iPad Hero and Tilt use the same "fill" rule as R3.1 before they apply their offsets. | Test: Hero front layer width ≥ 0.70 × canvas width on iPad portrait. |
| R3.4 | Mesh and grain apply the same way on iPad as on iPhone. They already do, but light themes such as Sky read as flat at iPad size. Raise the glow strength by 20% on canvases wider than 1.6× the iPhone width, so light themes gain visible depth. | Render check of Sky on `pad13`. |

### R4 — Mac frame realism

| ID | Requirement | How to check |
|---|---|---|
| R4.1 | Re-measure the MacBook Air M5 bezel from Apple Design Resources (the license was already accepted, and nothing is bundled): lid outer radius, bezel per side, chin height, hinge, base depth, base front lip, and thumb notch. The current values give a thick chin. Store the new values with a source note, as `DeviceSpec` already does. | Spec values are recorded. The diagonal-method measurements are logged in the commit. |
| R4.2 | Draw the base as a perspective deck: a darker hinge band, a lit top surface with a subtle gradient from back to front, a thin specular front lip, and rounded feet shadow. Draw the lid with an edge highlight and a faint glass reflection across the screen (white at 4%, diagonal). | Full-size render compared side by side with the Apple bezel PNG (scratchpad only): silhouette within 1.5% at every measured point. |
| R4.3 | Add a **"Window only"** frame style for Mac. It draws the window capture with its own macOS corner radius and shadow on the canvas background, with no laptop. Many Mac App Store screenshots use this look. | Render check with a Mac window capture. |
| R4.4 | **Display captures fill the screen (H3).** Today only a capture whose shape matches the MacBook display (2560 × 1664 or 16:10) fills it. Any other shape floats as a window, so a full-screen capture from an external display (for example 3440 × 1440) appears shrunk. Add a per-shot **Fit** choice for Mac: Auto (default), Fill screen, Window. Auto treats a capture as a display capture when it is opaque at all four corners, at least 1440 px tall, and wider than 1.5:1; otherwise as a window. Fill screen scales to cover the screen and crops the overflow. A free **Crop position** slider (0–100%, default 50%, center) sets which part of the overflow stays visible. It moves horizontally for wide captures and vertically for tall ones, and the preview updates live. Window keeps the current wallpaper float. The capture-fit advisory names the choice made and how much is cropped. | Unit tests: 3440 × 1440 opaque → display, fills the screen, crop ≤ 40% of the width; crop position 0%, 50%, and 100% show the left edge, the center, and the right edge of the capture; 2560 × 1664 → fills with no crop; a capture with transparent corners → window. Render check with Geoff's 3440 × 1440 capture. The existing `macCapturesFillOrFloatByAspect` cases still pass. |

### R5 — Caption compositions

Add a set-level **Composition** choice next to Layout. Each shot can override it, as arrangements do. Every composition keeps headlines aligned across the set, where the geometry allows.

| ID | Composition | Rules |
|---|---|---|
| R5.1 | **Stacked** (current) | Caption centered or left-aligned above or below the device. Default, so existing files are unchanged. |
| R5.2 | **Side by side** | Caption on the left (or right) half, device on the other half, vertically centered. Left-aligned text, measure capped at 0.42 × canvas width. Works with Standard, Tilt, and Hero. Duo and Zoom fall back to Stacked. On portrait iPhone, the device is at 0.62 × canvas height and may bleed off the bottom. On iPad and landscape it is the natural fit. |
| R5.3 | **Big number** | A large stat (for example "2×", "10k", "$0") at 2.2× headline size in the accent color, with the headline beneath it as a label. The stat comes from a new per-shot `stat` field. When `stat` is empty, the shot uses Stacked. Typography: heavy, tight tracking, tabular figures. |
| R5.4 | **Overlay** | The headline sits on top of the device's lower third on a frosted band (background color at 75% with blur). For full-bleed hero shots. Contrast is checked against the band, not the background. |
| R5.5 | **Text only** | No device. Headline at 1.6× size, subtitle, optional badge. For an intro or outro shot of the set. |

Rules for all compositions:

- **Alignment.** The shared caption band (`CaptionBand`) extends to group shots by composition. Shots with the same composition share a band, so their headlines align. Mixed compositions align their top margins only.
- **Vary layouts** may assign compositions as well as arrangements. The curated sequence becomes pairs, for example Side by side + Standard, Stacked + Duo, Big number + Standard, Stacked + Zoom, Text only (if 6 or more shots).
- **Contrast.** The contrast test covers the stat color (accent) and the overlay band.
- **File format.** Version 4. New keys: `composition`, `stat`, `calloutRect`, `calloutCardOffset`, `calloutMarker`, `lensStyle`, `macFit`, `macCropPosition` (Double 0–1), and `frameStyle` value `windowOnly`. Older files decode with Stacked and no stat.

## UI summary

- **Toolbar:** size menu · orientation · zoom controls · Canvas / Set toggle · Export.
- **Style tab:** Layout · Composition · Vary layouts / Make uniform · Shot N arrangement and composition override · Theme · Background.
- **Caption tab:** headline, subtitle, badge, stat (shown only for Big number) · font grid · weight segments · size · alignment · colors.
- **Device tab:** export summary · frame style (None / Rounded / Device / Window only on Mac) · finish swatches with names · Placement group (size, shadow, mini preview).

## Data model changes

```
Shot: + composition: Composition? (nil = follow set) · + stat: String
      · calloutRegion gains .custom · + calloutRect: CGRect? · + calloutCardOffset: CGPoint?
      · + calloutMarker (.spotlight default) · + lensStyle · + macFit (.auto) · + macCropPosition: Double (0.5)
SetStyle: + composition: Composition (default .stacked)
FrameStyle: + .windowOnly (Mac only; other presets treat it as .rounded)
ShotDocument.currentVersion = 4
```

## Testing

- Unit tests:
  - Block snapping.
  - Magnification bounds.
  - Lens geometry.
  - Custom region round-trip.
  - iPad fill ratios.
  - Composition placement bounds for every preset, orientation, layout, arrangement, and composition, with no caption-device overlap except Overlay.
  - Band grouping.
  - v3 → v4 migration.
  - Contrast for stat and overlay.
- Render checks through the harness. Add knobs `SB_COMPOSITION`, `SB_STAT`, and `SB_FRAME=windowOnly`. Use fitting captures: List Happens (iPhone 6.9), Bookmark-Collections (iPad 13), and the app's own window (Mac).
- Live-app smoke tests through the accessibility helper:
  - Zoom controls.
  - Set view select and reorder.
  - On-canvas headline edit, commit, and cancel.
  - Ring drag.
  - Font grid.
- A code review before the first council round. Fixes go in separate commits.

## Milestones (each one a review stop unless Geoff says full-send)

1. **Z — Zoom quality:** R1.1–R1.3, R1.5, and R1.6 (spotlight marker).
2. **C — Canvas:** R2.1–R2.3.
3. **E — On-canvas editing and tab craft:** R2.4–R2.6 (including real weights) and R1.4 (ring and card drag).
4. **P — Platforms:** R3 (iPad) and R4 (Mac, including display-capture fill).
5. **K — Compositions:** R5 and format v4.
6. **N — Council:** freeze, review, then up to 3 rounds.

## Hands-on findings (Geoff, 2026-11-14)

Geoff tested the chapter 2 build (`530d33c`, MacBook Pro) with To-Do app captures on iPhone 6.9 and Screenshot Builder captures on Mac. Evidence is in `Dev Workstation/Visual Verification/screenshot builder/2026-11-14-Framing-test/`. iPad was not tested.

| ID | Finding | Evidence | Where it goes |
|---|---|---|---|
| H1 | "Why are there 2 Zoom boxes? I feel like it should be movable." The white source ring looks like a second card, the ring cuts a row ("Overdue"), and neither box can be moved. | iPhone shot 3 | R1.1 (block snapping, already specified), new R1.6 (spotlight marker), extended R1.4 (drag ring and card). |
| H2 | "Bold weight is very close to Heavy." Checked on 2026-11-14: in Futura, Heavy and Bold resolve to the same face (`Futura-Bold`), Black switches to `Futura-CondensedExtraBold`, Georgia resolves every weight to `Georgia-Bold`, and Helvetica Neue Black is condensed. | Mac shot 2 | R2.5, which now requires real, distinct weights only. |
| H3 | "Image appears to get resized. This is the entire Mac screen, corner to corner." A 3440 × 1440 full-screen capture from an external display does not match the MacBook shape, so it is drawn as a floating window. | Mac shot 3 | R4.4, which now adds display-capture detection and Fill screen. |
| H4 | Duo: "Oh, THIS is what Duo meant. Pretty neat." Also "Use Duo to mask weaker images." | iPhone shots 2 and 8 | Validation. No change. |
| H5 | Tilt and Hero work. "Hero left: slightly less angle than Tilt L" (correct: Hero leans 4°, Tilt 8°). Shot 7 is labelled "Hero Right" but shows a Duo of Calendar and Today. Geoff confirmed on 2026-11-14 that Duo was intended and the label was a stale caption. | iPhone shots 4–7 | No change. |
| H6 | iPad output not tested: no iPad Pro on hand. iPad output does not need a device; captures from the iPad Pro 13-inch simulator work (used in chapter 2). An iPad mini capture is a different shape and would show the capture-fit warning in an iPad Pro frame. | none | Stays open. Chapter 3 milestone P re-checks iPad with simulator captures; Geoff's iPad acceptance stays on the TODO list. |

Decision (2026-11-14): fold H1–H3 into chapter 3 instead of a separate fix pass. None blocks use or corrupts data. Each one touches code that chapter 3 rewrites anyway (the Zoom marker and drag in milestone Z/E, the weight control in E, the Mac fit in P), so fixing them first would be redone. Chapter 3 milestone Z (Zoom) remains first because H1 is the most visible.

## Open questions for Geoff

1. Big number: should `stat` be free text, or a number with a unit picker?
2. Overlay: blur needs Core Image in the renderer. Is that acceptable, or should Overlay use a flat 85% band instead?
3. Set view reorder: should it replace the hidden list sidebar entirely, so the sidebar can be removed?
4. Mac "Window only": should it be the default frame for the Mac preset?

## Resolved questions (Geoff, 2026-11-14)

- **Shot 7 label:** Duo was intended; "Hero Right" was a stale caption. No app change.
- **Crop for wide display captures:** use a free crop-position slider, not left / center / right, because it gives finer control (R4.4).

## Risks

- **Re-render cost.** On-canvas editing and live zoom re-render often. Mitigation: render the preview at pane size, debounce at 90–120 ms, and keep the existing decoded-image and row-profile caches.
- **Wide compositions.** Side by side on portrait iPhone is tight. Mitigation: the device may bleed off the bottom, and the text measure is capped, with a two-line headline limit.
- **Council ceiling.** The judges may keep scoring competitiveness at 7 until the editor matches commercial tools feature for feature. The 3-round cap and the escalation rule still apply.
