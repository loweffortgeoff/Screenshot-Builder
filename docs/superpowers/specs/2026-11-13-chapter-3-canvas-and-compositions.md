# Screenshot Builder — Chapter 3 spec: canvas, Zoom, iPad, Mac, and compositions

Status: spec only, written 2026-11-13. Not approved. No implementation exists.
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
| R1.4 | Manual region. Besides Auto, Top, Middle, and Bottom, a "Custom" region stores a unit rect. In the editor the user drags the highlight ring on the preview (see R2.4). The rect snaps to blocks on release. | Model test: custom rect round-trips through encode and decode. UI smoke test: drag in the live app moves the ring, and the export matches. |
| R1.5 | The card never covers more than 10% of the ring height. It never leaves the canvas safe margin. It never touches caption text. | Extend `everyArrangementStaysVisibleAndClearOfCaptions`. |

### R2 — Editor canvas

| ID | Requirement | How to check |
|---|---|---|
| R2.1 | **Fit-to-pane preview.** The preview grows to fill the canvas pane with a 24 pt margin, instead of rendering at a fixed size. It renders at the pane's backing-pixel size, capped at the export size, and re-renders after 120 ms of no resizing. | Window capture at 1440 × 920: the preview height is at least 85% of the pane height. |
| R2.2 | **Zoom controls.** The toolbar gets − / Fit / 100% / + controls and the shortcuts ⌘−, ⌘0, ⌘1, ⌘=. Pinch on the trackpad zooms. At zoom levels above Fit, the preview scrolls and the render resolution follows the zoom level. | Live smoke test through the accessibility helper: zoom in, check the scroll area appears and the render is sharp at 100%. |
| R2.3 | **Set view.** A Canvas / Set toggle in the toolbar (⌘2) shows all shots side by side, as in App Store Connect, at the largest size that fits. Clicking a shot selects it and returns to Canvas. Dragging in Set view reorders shots. The filmstrip stays in Canvas view. | Live capture of Set view with 5 shots: every shot is at least 280 pt tall at 1440 × 920. A reorder by drag persists after save and reopen. |
| R2.4 | **On-canvas editing.** Double-click the headline or the subtitle on the preview to edit it in place. The editor is an overlay text field, styled at the preview scale, that commits on Return or click-away and cancels on Esc. Double-click the badge to edit it. In Zoom arrangement, the highlight ring can be dragged (R1.4). A single click on the device selects the shot and opens the Style tab's arrangement section. | Live smoke test: double-click the headline, type, press Return; the inspector field and the export match. Esc restores the old text. |
| R2.5 | **Caption tab craft.** The font picker shows each family rendered in that family, as a grid of "Ag" tiles with names. Weight becomes a four-step segmented control that previews the weight. The Highlight menu stays, and a hint line under the headline explains it. Headline and subtitle fields use a larger, two-line minimum editor. | Window capture of the Caption tab: no plain popup remains for font or weight. |
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
| R4.4 | A full-display Mac capture (2560 × 1664, menu bar included) fills the screen. A window capture floats on the theme wallpaper at the current 3.5% inset. No change; keep the tests. | The existing `macCapturesFillOrFloatByAspect` test still passes. |

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
- **File format.** Version 4. New keys: `composition`, `stat`, `calloutRect`, `lensStyle`, and `frameStyle` value `windowOnly`. Older files decode with Stacked and no stat.

## UI summary

- **Toolbar:** size menu · orientation · zoom controls · Canvas / Set toggle · Export.
- **Style tab:** Layout · Composition · Vary layouts / Make uniform · Shot N arrangement and composition override · Theme · Background.
- **Caption tab:** headline, subtitle, badge, stat (shown only for Big number) · font grid · weight segments · size · alignment · colors.
- **Device tab:** export summary · frame style (None / Rounded / Device / Window only on Mac) · finish swatches with names · Placement group (size, shadow, mini preview).

## Data model changes

```
Shot: + composition: Composition? (nil = follow set) · + stat: String
      · calloutRegion gains .custom · + calloutRect: CGRect? · + lensStyle
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

1. **Z — Zoom quality:** R1.1–R1.3 and R1.5.
2. **C — Canvas:** R2.1–R2.3.
3. **E — On-canvas editing and tab craft:** R2.4–R2.6 and R1.4.
4. **P — Platforms:** R3 (iPad) and R4 (Mac).
5. **K — Compositions:** R5 and format v4.
6. **N — Council:** freeze, review, then up to 3 rounds.

## Open questions for Geoff

1. Big number: should `stat` be free text, or a number with a unit picker?
2. Overlay: blur needs Core Image in the renderer. Is that acceptable, or should Overlay use a flat 85% band instead?
3. Set view reorder: should it replace the hidden list sidebar entirely, so the sidebar can be removed?
4. Mac "Window only": should it be the default frame for the Mac preset?

## Risks

- **Re-render cost.** On-canvas editing and live zoom re-render often. Mitigation: render the preview at pane size, debounce at 90–120 ms, and keep the existing decoded-image and row-profile caches.
- **Wide compositions.** Side by side on portrait iPhone is tight. Mitigation: the device may bleed off the bottom, and the text measure is capped, with a two-line headline limit.
- **Council ceiling.** The judges may keep scoring competitiveness at 7 until the editor matches commercial tools feature for feature. The 3-round cap and the escalation rule still apply.
