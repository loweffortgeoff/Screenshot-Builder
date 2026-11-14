# Screenshot Builder — Chapter 3 plan: canvas, Zoom, iPad, Mac, and compositions

Status: Approved by Geoff on 2026-11-14 and implemented on `feature/chapter-3` (milestones Z–N done). Council medians 7.3, 7.4, 7.4; the 8.0 bar was not met, so the escalation to Geoff is open. Results: `docs/superpowers/council/chapter-3-results.md`. Written 2026-11-14 on the MacBook Pro.
Spec: `docs/superpowers/specs/2026-11-13-chapter-3-canvas-and-compositions.md` (R1–R5, H1–H3).

## Context

Chapters 1 and 2 raised the UI council median from 3.8 to 7.5. Geoff accepted 7.5, but the 8.0 target was not met. The judges repeated five complaints: a rough Zoom callout, a small editor canvas with no zoom or set view, small iPad devices, a schematic Mac frame, and one caption composition only. Geoff's hands-on test on 2026-11-14 added three findings: the Zoom ring reads as a second card (H1), fake font weights (H2), and wide display captures that shrink on the Mac (H3). Chapter 3 fixes all of these within the fixed-layout model. Done when the same council gives a median of 8.0 or more.

## Geoff's answers (2026-11-14)

| Question | Answer |
|---|---|
| Pass bar | Median of Opus, Sonnet, and Fable ≥ 8.0, same 7-criterion rubric. After 3 rounds below 8, stop and ask Geoff. |
| Council inputs | The same 14 slots as chapter 2, plus new slots for Set view, compositions, a Zoom single, and Mac Window only. |
| Old files (v1–v3) | They open and keep all content and choices. New options default to the old behaviour (Stacked, no stat). The judged defects are fixed for every file, so old files can render differently in Zoom, iPad, Mac, and weights. |
| Milestone stops | Full-send. One short update per milestone ("Nothing for you" or "Action needed"). Stop only for real blockers and at the end. |
| Sidebar | Remove the hidden list sidebar and its toolbar button. Set view and the filmstrip menu replace it. |
| Big number stat | Free text. |
| Overlay band | Frosted blur through Core Image (system framework, no new dependency). |
| Mac default frame | Keep the MacBook frame. Window only is an option. |
| Shot 7 label, crop control | (From the spec.) Duo was intended. Wide captures get a free 0–100% crop-position slider. |

## Facts checked (2026-11-14)

- **Machine.** MacBook Pro (`MacBook-Pro`), macOS 27.2, Xcode 27.2 (27B52), Swift 6.4.2. Simulator runtimes iOS 27.1 and 27.2.
- **Project.** A macOS SwiftPM app (macOS 14+, no Xcode project), about 2,900 lines of app code and 700 lines of tests. Build with `swift build` or `scripts/build-app.sh`. Tests run with `swift test --filter`. No iPhone or iPad install is needed.
- **Repository.** Root checkout `/Users/geoffreysilva/Developer/Screenshot-Builder` is clean on `feature/pro-framing` at `7a0341d`. `git ls-remote` shows `origin/feature/pro-framing` = `7a0341d` and `origin/main` = `12b6a2e`. One worktree (the root). No parallel work found. The untracked `build/` and `.build/` folders stay untouched.
- **Assets from chapter 2** are still in a volatile folder, `/private/tmp/claude-501/-Users-geoffreysilva-Developer-Screenshot-Builder/af5e4e82-…/scratchpad/`:
  - `council-rubric.md`. It is also the judge prompt; no other prompt file exists.
  - Sample captures: `samples/` (List Happens, 1320 × 2868), `samples-ipad/` (Bookmark-Collections from the iPad Pro 13-inch simulator, 2064 × 2752), and `samples-mac6/` (app window, 1440 × 920).
  - `bezels/dmg/Bezel-MacBook-Air-M5.dmg`, for R4.1.
  - `c2r3/`, the chapter 2 final council inputs (14 images).
- **Geoff's 3440 × 1440 capture** for H3: `Dev Workstation/Visual Verification/screenshot builder/CleanShot 2026-11-14 at 03.41.35.png`. It has an alpha channel but is opaque, so display detection must sample corner pixels, not `alphaInfo`.
- **Name clash.** `ShotRenderer.Composition` already exists, so the new caption enum is `CaptionComposition`.

## Isolation

- New branch `feature/chapter-3` from `7a0341d`, in a new worktree `~/.t3/worktrees/Screenshot-Builder/chapter-3` (an approved folder).
- The root checkout stays on `feature/pro-framing`. `main` is not touched.
- Commits: one or more per milestone. Fix commits stay separate from implementation commits.
- Push: I push `feature/chapter-3` (a new branch, so no published history changes) after each milestone, as the brief allows.
- Merge: only on Geoff's word. The proposed target is a fast-forward of `feature/pro-framing`. No reset, rebase of published work, or branch or worktree deletion without approval.

## Step 0 — while Geoff is at the MacBook Pro (about 10 minutes)

1. Make the assets durable. Copy the rubric, samples, bezel DMG, and `c2r3` inputs into this session's scratchpad. Commit `docs/superpowers/council/council-rubric.md` and an input manifest (`inputs.md`: the slot list and the harness command for each slot) on the branch.
2. Run the permission probe with the existing `build/Screenshot Builder.app`. It must show that T3 Code still has Screen Recording, Accessibility, and Automation (System Events). The probe covers each action the smoke tests need:
   - window capture,
   - click,
   - double-click,
   - drag,
   - a key shortcut (⌘0),
   - typing into a field.
   If macOS prompts, Geoff grants the permission and the probe runs again.
3. When the probe passes, Geoff can move to the Mac mini.

## Milestones (full-send; one update each)

Each milestone ends with: `swift build`, the focused tests, harness renders that I inspect, and a live window capture where the UI changed. Then a commit and a push.

### Z — Zoom quality (R1.1–R1.3, R1.5, R1.6; fixes H1 visuals)

- `Shot.swift`: replace `snappedBand` with block snapping. Find runs of busy rows separated by quiet gaps of at least 1% of the height. Choose a block within 0.10–0.24 of the capture height, nearest the target. Otherwise trim the nearest block to whole rows. Reuse the cached `rowProfile`.
- `ShotRenderer.compose` (`.callout`): magnification between 1.6× and 2.2× (Mac ≥ 1.5×). If the card would exceed 0.78 × canvas width, narrow the band instead of reducing the zoom. The card stays inside the safe margin and clear of captions. It covers at most 10% of the ring height.
- `drawCallout`:
  - Card: a 1.5 pt canvas-scaled light border and a soft shadow.
  - Connector: a tapered lens path joining two ring corners to two card corners.
  - Marker: a spotlight (dim the rest of the screen by about 35%; thin accent outline on the source rows, no fill).
- Model fields `calloutMarker` (Spotlight, Outline, None) and `lensStyle` (Lens, Line) arrive here. In-memory defaults only; the format bump happens in K.
- Tests:
  - New: `calloutCropFallsInGaps` (synthetic stripe blocks), `calloutMagnificationBounds` (every preset, orientation, and layout), `lensConnectorJoinsCorners`, and `spotlightMarkerUsesAccentAndThinStroke`.
  - Extended: `everyArrangementStaysVisibleAndClearOfCaptions`.
- Render check: List Happens and Bookmark-Collections captures with Auto, Top, Middle, and Bottom. No glyph is cut at the card edge.

### C — Canvas (R2.1–R2.3, sidebar removal)

- `PreviewPane.swift`: the preview fills the pane with a 24 pt margin. It renders at the pane's backing-pixel size, capped at the export size, and re-renders 120 ms after resizing stops.
- Zoom state: − / Fit / 100% / + in the toolbar, with ⌘−, ⌘0, ⌘1, and ⌘= through `CommandGroup`. Pinch uses `MagnifyGesture`. Above Fit, the preview sits in a `ScrollView` and the render resolution follows the zoom.
- New `SetView.swift`: a Canvas / Set toggle (⌘2). All shots appear side by side at the largest size that fits. A click selects a shot and returns to Canvas. Drag reorders the shots (`draggable` / `dropDestination`).
- `EditorView.swift`: remove `NavigationSplitView`, the list sidebar, and `ShotRow.swift`. Move earlier, move later, replace, and remove stay in the filmstrip's context menu.
- Smoke tests:
  - Window capture at 1440 × 920: preview height ≥ 85% of the pane.
  - Zoom in: a scroll area appears.
  - Set view with 5 shots: each shot ≥ 280 pt tall.
  - A drag reorder persists after save and reopen.

### E — On-canvas editing, tab craft, ring and card drag (R2.4–R2.6, R1.4; fixes H1 drag and H2)

- On-canvas text: double-click the headline, subtitle, or badge to open an overlay `TextField`. Its position comes from `compose(...)`'s rects, scaled to the preview. Return or click-away commits; Esc cancels. A single click on the device opens the Style tab's arrangement section.
- Zoom drag: drag the ring to set a `.custom` region (`calloutRect`, which snaps to blocks on release). Drag the card to set `calloutCardOffset` (clamped to the safe margin and away from captions). "Reset position" returns both to automatic placement.
- Real weights (H2): a per-family table built from `NSFontManager.availableMembers(ofFontFamily:)`. It keeps only faces that are distinct and of the same width (no condensed faces). A stored weight the family lacks maps to the nearest real face and shows that face's name. The subtitle weight is at least one real step lighter than the headline weight.
- Caption tab: font grid of "Ag" tiles, each in its own family; weight segments that preview each weight; a Highlight hint line; two-line editors for the headline and subtitle.
- Device tab: 28 pt finish swatches with names and tooltips; the device name and a small frame diagram; a Placement group (size, shadow, mini preview).
- Tests:
  - `everyOfferedWeightIsADistinctSameWidthFace` (every family), and the headline face differs from the subtitle face.
  - `customCalloutRectAndCardOffsetRoundTrip`.
- Smoke tests:
  - Headline edit: double-click, type, press Return. The inspector field and the export match. Esc restores the old text.
  - Ring drag changes what the card shows. Card drag moves only the card.
  - Window captures of the font grid and the Device tab.

### P — Platforms (R3, R4; fixes H3)

- iPad (`ShotRenderer.compose` image area):
  - Smaller iPad side margins, and `imageScale` up to 1.0 (edge to the safe margin). Standard fills ≥ 70% of the canvas width in portrait. Hero and Tilt use the same fill rule.
  - Duo: back device 0.78, front 0.86, with a 6% vertical offset.
  - Glow strength +20% on canvases wider than 1.6× the iPhone width.
- Mac frame:
  - Re-measure the MacBook Air M5 bezel from the DMG (diagonal method). Update `DeviceSpec` with a source note. Log the measurements in the commit.
  - Redraw the base and lid in `DeviceFrame.swift`: hinge band, gradient deck, specular lip, foot shadow, lid edge highlight, and a 4% glass reflection.
- Window only: a new `FrameStyle.windowOnly` (Mac only; other presets treat it as Rounded). The capture keeps its own corner radius and shadow on the canvas background.
- Mac fit (H3): per-shot `macFit` (Auto, Fill screen, Window) and `macCropPosition` (0–1, default 0.5).
  - Auto treats a capture as a display capture when its four corner pixels are opaque, it is at least 1440 px tall, and wider than 1.5:1.
  - Fill screen covers the screen. The crop slider moves horizontally for wide captures and vertically for tall ones.
  - The advisory names the choice made and how much is cropped.
- Tests:
  - New: iPad fill ratios (`pad13`, `pad11`, Standard and Hero), Duo bounds, 3440 × 1440 → display with crop ≤ 40%, crop at 0 / 0.5 / 1 shows left / center / right, 2560 × 1664 fills with no crop, transparent corners → window.
  - Kept passing: `macCapturesFillOrFloatByAspect`.
- Render checks:
  - The Bookmark-Collections iPad set (Standard, Duo, Hero, Sky theme).
  - Geoff's 3440 × 1440 capture.
  - The app window in Window only.
  - The new Mac frame next to the Apple bezel PNG (scratchpad only), with the silhouette within 1.5% at every measured point.

### K — Compositions and format v4 (R5)

- Model:
  - `SetStyle.composition: CaptionComposition` (default `.stacked`).
  - `Shot.composition: CaptionComposition?` (nil follows the set) and `Shot.stat: String`.
  - `ShotDocument.currentVersion = 4`. Every new key decodes with `decodeIfPresent` and a default.
- Renderer: each composition defines its caption rect and device box before the arrangement runs.
  - Side by side: text measure ≤ 0.42 × canvas width. On portrait iPhone, the device is 0.62 × canvas height and may bleed off the bottom. Duo and Zoom fall back to Stacked.
  - Big number: the stat at 2.2× headline size in the accent color, heavy, tight tracking, tabular figures. An empty stat falls back to Stacked.
  - Overlay: a band at 75% of the background color over a Core Image blur of the device's lower third. Contrast is measured against the band.
  - Text only: no device; headline at 1.6×.
- `CaptionBand` groups shots by composition, so headlines align within each group. Mixed compositions align their top margins only.
- Vary layouts assigns composition and arrangement pairs:
  - Side by side + Standard,
  - Stacked + Duo,
  - Big number + Standard,
  - Stacked + Zoom,
  - Text only (6 or more shots).
- UI:
  - Style tab: a Composition picker beside Layout, and a per-shot override.
  - Caption tab: a Stat field, shown only for Big number.
- Harness knobs: `SB_COMPOSITION`, `SB_STAT`, `SB_FRAME=windowOnly` (`SampleRenderTests.swift`).
- Tests:
  - Composition bounds for every preset × orientation × layout × arrangement × composition, with no caption-device overlap except Overlay.
  - Band grouping.
  - v3 → v4 migration: old files keep their content and decode as Stacked with no stat.
  - Contrast for the stat (accent) and the Overlay band.

### N — Freeze, review, council

1. Freeze: run the full `swift test` (all tests, including the harness with its variables set).
2. Code review: `code-reviewer` (default model), plus Fable as a second reviewer, as your brief allows. I verify each finding before I fix it. Fixes go in separate commits. Then run the full `swift test` again.
3. Build council inputs from the frozen SHA (`scripts/build-app.sh`, harness, `capture-window.sh`):
   - The 14 chapter 2 slots.
   - New slots: Set view; a composition set (Side by side, Big number, Overlay, Text only); a Zoom single; a Mac Window-only export.
   - The rubric text stays unchanged.
4. Council: three `general-purpose` agents in one message, `model` set to `opus`, `sonnet`, and `fable`. Each one reads the rubric and every input. I report each score, the median, and the SHA.
5. A median ≥ 8.0 is done. Otherwise I fix the top repeated findings (in separate commits), rebuild the inputs, and run another round. After 3 rounds below 8, I stop and ask Geoff.
6. Docs:
   - Update README, CHANGELOG, DECISIONS, and TODO.
   - Set the spec status to Approved.
   - Copy this plan to `docs/superpowers/plans/2026-11-14-chapter-3-canvas-and-compositions.md`.
   - Add the council results table.

## Delegation and models

- **Inline (me, Opus).** The editor work: C, E, and the K UI. This is design-sensitive SwiftUI, so I do not delegate it.
- **Delegated.** The renderer and model work for Z, P, and the K renderer goes to `pstack:poteto-agent` on `sonnet` with high effort (your `feature` role line). Each agent runs in the foreground, one at a time (no shared writers), with one complete brief. I review each diff, build, and run the tests myself before I commit.
- **Fable.** Fable runs only as the third council judge and the second code reviewer. Your brief names it for those roles.
- **pstack adaptations.**
  - I use the poteto-mode principles: model the domain, sequence verifiable units, prove it works, and subtract before you add.
  - The multi-phase skeleton assumes Cursor cloud VMs, Bugbot, and one PR per phase, which do not exist in Claude Code. One branch with milestone commits replaces them, and the live smoke tests replace the 10-lane cloud swarm.

## Verification

- During work: `swift build`, then `swift test --filter BuilderTests/<test>` for the tests that cover the change. If no test covers a change, I build only and say so.
- Harness renders to the scratchpad. I open and inspect the PNGs; I do not trust them blind.
- Live smoke tests through `osascript` / System Events and `scripts/capture-window.sh`.
- Full `swift test` before each council round and before the merge request.
- Each update reports what ran: the filter, and the pass/fail count.

## Human stops

**Unavoidable (3):**

1. **Now: approve this plan and run Step 0 (about 10 minutes at the MacBook Pro).** macOS privacy grants (Screen Recording, Accessibility, Automation) are only yours to give. Stay until the probe passes, then move to the Mac mini.
2. **End: hands-on acceptance (one build, about 20 minutes).** Taste and feel cannot be automated. Assumed machine: this MacBook Pro, with `scripts/build-app.sh` in the worktree. On the Mac mini, pull `feature/chapter-3` first. Checklist below.
3. **End: merge decision.** Merging into `feature/pro-framing` happens only on your word.

**Contingencies (only if they occur):**

- macOS asks for a permission again, or captures come out black because the MacBook Pro locked or slept. Keep it awake, unlocked, and logged in. The fallback is a render-only review until you unlock it.
- The council stays below 8 after 3 rounds. I stop and ask.
- The Mac bezel DMG does not mount or measure. I ask you to download the MacBook Air bezel again.
- The volatile sample folder vanishes before Step 0. I recapture the iPad set on the iPad Pro 13-inch (M5) simulator (`364195A0`, iOS 27.2) and tell you when I take and release it. No iPhone 18 Pro Max is needed.
- A product fork the spec does not settle. I ask once in T3.

**Device pass:** none. This is a Mac app. iPad output is checked with iPad Pro simulator captures. Your iPad acceptance stays open in TODO, because no iPad Pro is on hand.

## End checklist for Geoff (one build, about 20 minutes)

- [ ] Zoom: a single marker (spotlight), no second white box. The crop cuts no text. Drag the ring and the card. Reset position.
- [ ] Canvas: the preview fills the pane. ⌘= / ⌘− / ⌘0 / ⌘1. **Pinch zoom on the trackpad** (I cannot script it; not verified until you try it).
- [ ] Set view (⌘2): click a shot to open it; drag to reorder; save and reopen.
- [ ] Double-click the headline on the canvas, type, press Return. Then Esc on a second edit.
- [ ] Caption tab: the font grid, and weight segments that each look different (Futura shows Medium and Bold only).
- [ ] Mac: your 3440 × 1440 capture fills the screen; the crop slider moves it. Window only looks right.
- [ ] Compositions: Side by side, Big number, Overlay, and Text only on one set. Vary layouts.
- [ ] An old chapter 2 `.shotset` opens with its text and choices intact.

## Estimates (guess)

About 10–14 hours of agent time: Z 1.5 h, C 1.5 h, E 2.5 h, P 2 h, K 2.5 h, N 1–3 h depending on rounds. Updates arrive about once per milestone.

## Critical files

- `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift`: compose, callout, compositions, iPad fill, Mac fit.
- `Sources/ScreenshotBuilder/Rendering/DeviceFrame.swift` and `Model/DeviceSpec.swift`: Mac frame, Window only.
- `Sources/ScreenshotBuilder/Model/Shot.swift`, `SetStyle.swift`, and `ShotDocument.swift`: new fields, weight table, v4.
- `Sources/ScreenshotBuilder/Editor/EditorView.swift`, `PreviewPane.swift`, `CaptionInspector.swift`, `StyleInspector.swift`, and `ArrangementInspector.swift`; new `SetView.swift`; delete `ShotRow.swift`.
- `Tests/ScreenshotBuilderTests/BuilderTests.swift` and `SampleRenderTests.swift`.
- Docs: README, CHANGELOG, DECISIONS, TODO, the spec status, `docs/superpowers/council/`, and the plan copy.

## Final handoff will report

The branch and worktree, the commits, the test runs (filter and counts), the review findings and fixes, the council table with the SHA, what was not verified (pinch, macOS 14, VoiceOver, iPad on a real device), and the push and merge status. Implementation complete, Geoff's acceptance, and release readiness are reported separately. This is not for release, so version numbers do not change.
