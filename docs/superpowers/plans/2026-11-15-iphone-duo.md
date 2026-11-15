# iPhone Duo Device Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the foldable iPhone Duo as an output size with a drawn frame that picks open or closed, portrait or landscape, from each shot's capture.

**Architecture:** A new `OutputPreset.duo` and two measured `DeviceSpec`s (`duoOpen`, `duoClosed`, family `.foldable`). Today the renderer takes one spec per set from the preset (`DeviceSpec.for(style.preset)`) and rotates the device with the canvas. For Duo, a new `DeviceSpec.for(_:capture:)` picks the spec and the device rotation per shot from the capture size, on an always-portrait canvas. Duo uses the iPad layout path (the canvas aspects are close: 0.70 and 0.75).

**Tech Stack:** Swift 6, SwiftUI, Core Graphics, SwiftPM macOS app, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-15-iphone-duo-design.md`

**Branch:** `feature/iphone-duo`, cut from `main` at the start of Task 1. Claude commits; Geoff pushes.

## Global Constraints

- Output size: 2007 × 2853, portrait only. Duo has no landscape canvas.
- Capture shapes (exact pixels, either order): inner open 2007 × 2853; outer closed 1398 × 2034.
- Finishes: "Night Sky" and "Star White", sampled from the Apple PNGs.
- Do not bundle Apple's frame images. Do not change the output of existing presets or old `.shotset` files.
- Apple frames (reference only): `~/Documents/Dev Workstation/App Images/ASC Screenshots/Utility/Frames/iPhone Duo/`.
- Visual reference set: `.../ASC Screenshots/Tucked/Current Version/Duo/` with captures in `.../Tucked/Captures/duo/2026-10-24/`.
- Tests: `swift test --filter DuoTests/<test>` during work. Full `swift test` before handoff.

## Measured geometry (2026-11-15, from the Night Sky portrait PNGs)

Reference pixels. Insets are from the body edge (buttons excluded). Apple's frame openings match the capture sizes 1:1.

| | Open (`duoOpen`) | Closed (`duoClosed`) |
|---|---|---|
| screen | 2007 × 2853 | 1398 × 2034 |
| bezel T / L / B / R | 70 / 62 / 62 / 62 | 56 / 77 / 48 / 48 |
| body radius | 239 (top), 225 (bottom): use 232 | outer (right) side 230; hinge (left) side 80 |
| screen radius | 160 | outer side 174; hinge side 24 |
| buttons (from body top) | left: 386 / 197, 628 / 197; depth 8 | right: 615 / 338; depth 9 |
| camera | none on the screen | punch hole, 108 diameter, center (1254.5, 143) in screen coordinates |
| fold crease | not drawn (none in Apple's PNG) | n/a |

Small top-edge buttons in Apple's PNGs are left out in v1 (builder's call; they show only as a thin edge line at screenshot size).

## Review Focus

1. **Landscape device rotation direction.** `DeviceFrame` rotates a quarter turn counterclockwise. A landscape closed shot must put the punch hole on the same corner as Apple's `Outer Closed Landscape.png`. If not, the camera covers the wrong part of the capture. Test: `landscapeClosedCameraMatchesApple` (Task 2).
2. **Odd capture sizes** (an iPhone capture, or a scaled 1/2 Duo capture). Expect the open frame in the capture's orientation, the black-bars advisory naming "iPhone Duo", and no crash. Test: `oddCaptureUsesOpenFrameAndWarns` (Task 3).
3. **Duo arrangement on the Duo preset** with one open and one closed shot. Expect both devices on the canvas and clear of the caption. The companion uses the front shot's frame and sits on black glass when its shape differs. Test: `duoArrangementMixesFoldStates` (Task 3).
4. **Switching an existing set to Duo while `landscape` is true.** Expect a portrait 2007 × 2853 canvas and a hidden orientation picker; switching back to an iPhone preset restores landscape. Test: `duoIgnoresStoredLandscape` (Task 1).
5. **Old builds opening a Duo file.** Expect "This project needs a newer version of Matte." and not a decode error. Covered by the version bump test `duoProjectsUseVersion6` (Task 1).

---

### Task 1: Duo preset, specs, and per-capture selection

**Files:**
- Modify: `Sources/ScreenshotBuilder/Model/OutputPreset.swift`
- Modify: `Sources/ScreenshotBuilder/Model/DeviceSpec.swift`
- Modify: `Sources/ScreenshotBuilder/Model/SetStyle.swift:288-322`
- Modify: `Sources/ScreenshotBuilder/Model/ShotDocument.swift:10`
- Create: `Tests/ScreenshotBuilderTests/DuoTests.swift`

**Interfaces:**
- Produces:
  - `OutputPreset.duo` with `title == "iPhone Duo"`, `size == CGSize(width: 2007, height: 2853)`, `symbol == "iphone"`.
  - `OutputPreset.hasOrientation: Bool`: false for `.mac` and `.duo`. Replaces every `preset != .mac` orientation check (SetStyle, Shot, ShotRenderer, PreviewPane, StyleInspector, EditorView).
  - `DeviceSpec.Family.foldable`.
  - `DeviceSpec.duoOpen`, `DeviceSpec.duoClosed` with the measured values above.
  - New optional `DeviceSpec` fields: `hingeBodyRadius: CGFloat?`, `hingeScreenRadius: CGFloat?` (left-side corners), `punchHole: CGRect?` (screen coordinates).
  - `static func for(_ preset: OutputPreset, capture: CGSize) -> (spec: DeviceSpec, landscape: Bool)`. For `.duo`: closed when the capture is exactly 1398 × 2034 or 2034 × 1398, else open; `landscape` is `capture.width > capture.height`. For every other preset: `(DeviceSpec.for(preset), false)`. The caller still applies the set's landscape for those.
  - `DeviceSpec.for(.duo)` returns `duoOpen` (placeholder, frame diagram).
  - `DeviceFinish.all(for: .foldable)`: Night Sky, Star White.
  - `ShotDocument.currentVersion == 6`.

- [ ] **Step 1: Create the branch.** `git -C ~/Developer/Screenshot-Builder switch -c feature/iphone-duo`

- [ ] **Step 2: Write the failing tests** in `DuoTests.swift` (`@MainActor struct DuoTests`):

```swift
@Test func duoPresetSize() {
    #expect(OutputPreset.duo.size == CGSize(width: 2007, height: 2853))
    #expect(OutputPreset.duo.title == "iPhone Duo")
    #expect(!OutputPreset.duo.hasOrientation && !OutputPreset.mac.hasOrientation && OutputPreset.phone69.hasOrientation)
}
@Test func captureSelectsFoldAndOrientation() {
    let cases: [(CGSize, DeviceSpec, Bool)] = [
        (CGSize(width: 2007, height: 2853), .duoOpen, false), (CGSize(width: 2853, height: 2007), .duoOpen, true),
        (CGSize(width: 1398, height: 2034), .duoClosed, false), (CGSize(width: 2034, height: 1398), .duoClosed, true),
        (CGSize(width: 1320, height: 2868), .duoOpen, false)]
    for (capture, spec, landscape) in cases {
        let pick = DeviceSpec.for(.duo, capture: capture)
        #expect(pick.spec == spec && pick.landscape == landscape, "\(capture)")
    }
    #expect(DeviceSpec.for(.phone69, capture: CGSize(width: 2034, height: 1398)).spec == .proMax)
}
@Test func duoIgnoresStoredLandscape() {
    var style = SetStyle(); style.landscape = true; style.preset = .duo
    #expect(style.size == CGSize(width: 2007, height: 2853))
    style.preset = .phone69
    #expect(style.size == CGSize(width: 2868, height: 1320))
}
@Test func duoProjectsUseVersion6() throws {
    #expect(ShotDocument.currentVersion == 6)
}
@Test func duoFinishes() {
    #expect(DeviceFinish.all(for: .foldable).map(\.name) == ["Night Sky", "Star White"])
}
```

- [ ] **Step 3: Run** `swift test --filter DuoTests`. Expected: build failure (`duo` not a member).

- [ ] **Step 4: Implement** the interfaces above. Sample the finish colors (shadow, metal, highlight, button) from the band of each Apple portrait PNG, the same way as the existing finishes. Switch statements over `OutputPreset` and `DeviceSpec.Family` gain the new cases. `isPortraitPhone` stays false for `.foldable`.

- [ ] **Step 5: Run** `swift test --filter DuoTests`, then `swift test --filter BuilderTests/everyArrangementStaysVisibleAndClearOfCaptions`. Expected: all pass (the existing loop now includes `.duo`).

- [ ] **Step 6: Commit** `Add the iPhone Duo preset and measured specs`.

### Task 2: Draw the Duo frame

**Files:**
- Modify: `Sources/ScreenshotBuilder/Rendering/DeviceFrame.swift`
- Test: `Tests/ScreenshotBuilderTests/DuoTests.swift`

**Interfaces:**
- Consumes: `duoOpen`, `duoClosed`, `hingeBodyRadius`, `hingeScreenRadius`, `punchHole` (Task 1).
- Produces: `DeviceFrame.punchHoleRect: CGRect?` (canvas coordinates). `screenPath` and `silhouette` honor the hinge-side radii.

- [ ] **Step 1: Write the failing tests:**

```swift
@Test func closedFrameScreenMatchesCapture() throws {
    let frame = DeviceFrame(spec: .duoClosed, landscape: false, rect: CGRect(origin: .zero, size: DeviceSpec.duoClosed.outer))
    #expect(frame.screenRect.size == CGSize(width: 1398, height: 2034))
    let hole = try #require(frame.punchHoleRect)
    #expect(frame.screenRect.contains(hole))
    #expect(abs(hole.midX - (frame.screenRect.minX + 1254.5)) < 1 && abs(hole.width - 108) < 1)
}
@Test func landscapeClosedCameraMatchesApple() throws {
    // Apple's Outer Closed Landscape.png puts the camera at the screen's top left, center (143, 143).
    let outer = DeviceFrame.outerSize(.duoClosed, landscape: true)
    let frame = DeviceFrame(spec: .duoClosed, landscape: true, rect: CGRect(origin: .zero, size: outer))
    let hole = try #require(frame.punchHoleRect)
    #expect(abs(hole.midX - (frame.screenRect.minX + 143)) < 2 && abs(hole.midY - (frame.screenRect.minY + 143)) < 2)
}
@Test func openFrameHasNoCamera() {
    let frame = DeviceFrame(spec: .duoOpen, landscape: false, rect: CGRect(origin: .zero, size: DeviceSpec.duoOpen.outer))
    #expect(frame.punchHoleRect == nil && frame.screenRect.size == CGSize(width: 2007, height: 2853))
}
```

The existing counterclockwise rotation already moves the portrait top-right camera to the landscape top-left (checked 2026-11-15), so `transform` does not change.

- [ ] **Step 2: Run** `swift test --filter DuoTests`. Expected: FAIL (`punchHoleRect` missing).

- [ ] **Step 3: Implement.** Add a rounded-rect path helper with separate left and right radii, used by the body, the band layers, the glass, and the screen when the hinge radii are set. Draw the punch hole like the existing island camera: black fill, faint rim, lens. `.foldable` gets the phone metal band (no laptop or home-button branches).

- [ ] **Step 4: Run** `swift test --filter DuoTests`. Expected: PASS.

- [ ] **Step 5: Visual check.** Render each spec at 1:1 in Night Sky to the scratchpad and put each beside the Apple PNG on one contact sheet (`scripts/compare-pngs.swift` or a temporary test). Read the sheet. The corners, bezel, camera, and buttons line up within a few pixels.

- [ ] **Step 6: Commit** `Draw the iPhone Duo frame`.

### Task 3: Per-shot frame in the renderer

**Files:**
- Modify: `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift:437-520, 568, 955-959, 1045`
- Modify: `Sources/ScreenshotBuilder/Model/Shot.swift:470` (placeholder)
- Test: `Tests/ScreenshotBuilderTests/DuoTests.swift`

**Interfaces:**
- Consumes: `DeviceSpec.for(_:capture:)`, `hasOrientation` (Task 1), `DeviceFrame` (Task 2).
- Produces: in `compose`, `spec` and `rotatedDevice` come from `DeviceSpec.for(style.preset, capture: sourceSize)`. For non-Duo presets `rotatedDevice` stays `style.landscape && style.preset.hasOrientation`. For Duo, `rotatedDevice` is the pick's `landscape`. `isPad` becomes `usesTabletLayout = spec.family == .pad || spec.family == .foldable`, with the same meaning in the Duo-pair and glow code. A Duo companion uses the front shot's spec and rotation.

- [ ] **Step 1: Write the failing tests:**

```swift
@Test func eachCaptureGetsItsFrame() throws {
    var style = SetStyle(); style.preset = .duo
    for (capture, spec, landscape) in [(CGSize(width: 2007, height: 2853), DeviceSpec.duoOpen, false),
                                       (CGSize(width: 2853, height: 2007), .duoOpen, true),
                                       (CGSize(width: 1398, height: 2034), .duoClosed, false),
                                       (CGSize(width: 2034, height: 1398), .duoClosed, true)] {
        let shot = try fixture(capture)
        let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: capture)
        let device = try #require(c.layers.last?.device)
        #expect(device.spec == spec && device.landscape == landscape)
        #expect(CGRect(origin: .zero, size: style.size).contains(c.layers.last!.bounds))
        #expect(!ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("black bars") })
    }
}
@Test func oddCaptureUsesOpenFrameAndWarns() throws {
    var style = SetStyle(); style.preset = .duo
    let phone = CGSize(width: 1320, height: 2868)
    let shot = try fixture(phone)
    let c = ShotRenderer.compose(shot: shot, style: style, sourceSize: phone)
    #expect(c.layers.last?.device?.spec == .duoOpen)
    #expect(ShotRenderer.warnings(shot: shot, style: style).contains { $0.contains("iPhone Duo") })
}
@Test func duoArrangementMixesFoldStates() throws {
    // Front closed portrait, companion open landscape; both layers on the canvas and clear of the caption.
}
```

`fixture(_ size: CGSize)` builds a solid PNG capture of exactly that size (adapt the `ChapterFourTests` helper). `warnings` reads the size from the shot's image, so the fixture size and `sourceSize` must match. `duoArrangementMixesFoldStates` uses the `compose(... companionSize:)` path the existing Duo test in `BuilderTests` uses, with the same on-canvas and caption-clear assertions as `everyArrangementStaysVisibleAndClearOfCaptions`.

- [ ] **Step 2: Run** `swift test --filter DuoTests`. Expected: FAIL (the open spec is used for every capture).

- [ ] **Step 3: Implement** the interface above. Arrangements that do not fit a landscape Duo device fall back to Stacked through the existing fallback, with its note. Add a fallback only if a Task 3 test or the visual check shows a clipped device.

- [ ] **Step 4: Run** `swift test --filter DuoTests` and `swift test --filter BuilderTests`. Expected: all pass, with no change to existing outputs.

- [ ] **Step 5: Regression check.** Run `scripts/compare-renders.sh` against `main` for the existing sample set. Expected: no pixel change on non-Duo presets.

- [ ] **Step 6: Commit** `Pick the iPhone Duo frame per shot from its capture`.

### Task 4: Editor, visual acceptance, and docs

**Files:**
- Modify: `Sources/ScreenshotBuilder/Editor/EditorView.swift:36-54, 329-337`
- Modify: `Sources/ScreenshotBuilder/Editor/InspectorControls.swift:115-148` (FrameDiagram)
- Modify: `Sources/ScreenshotBuilder/Editor/StyleInspector.swift:162`, `PreviewPane.swift:342`
- Modify: `README.md`, `CHANGELOG.md`, `DECISIONS.md`, `TODO.md`

**Interfaces:**
- Consumes: `OutputPreset.duo`, `hasOrientation`, `.foldable` (Task 1).

- [ ] **Step 1: Size menu.** Add `.duo` at the end of the iPhone section. Show the orientation picker only when `preset.hasOrientation`. FrameDiagram draws `.foldable` with aspect 0.70 and radius factor 0.12.

- [ ] **Step 2: Build** with `swift build` and `scripts/build-app.sh`. Expected: no errors or new warnings.

- [ ] **Step 3: Visual acceptance.** Build a Tucked Duo set from the four captures the Tucked script uses (`Captures/duo/2026-10-24/`: 06.15.26, 06.16.30, 06.16.49, 06.15.38) with the Tucked headlines. Export to the scratchpad and make a contact sheet beside `Tucked/Current Version/Duo/`. Read it. Every export is 2007 × 2853, each frame matches its capture, and no device is clipped. Capture the live window with `scripts/capture-window.sh` with the size menu open. Send the sheet to Geoff.

- [ ] **Step 4: Docs.** README: add iPhone Duo to the sizes and say the frame follows each capture. CHANGELOG: one line under Unreleased. DECISIONS: per-capture fold choice, tablet layout path, companion follows the front frame, top buttons left out, version 6. TODO: check off the Duo entry with the date.

- [ ] **Step 5: Full suite** `swift test`. Report the pass/fail count.

- [ ] **Step 6: Commit** `Add iPhone Duo to the size menu and docs`. Tell Geoff the branch name and that it is in the main checkout.
