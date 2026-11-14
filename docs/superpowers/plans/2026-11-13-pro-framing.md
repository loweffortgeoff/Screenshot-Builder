# Screenshot Builder — Pro framing pass

Status: complete. Approved by Geoff on 2026-11-13. Final median 7.3; Geoff then opened chapter 2 (`2026-11-13-per-shot-layouts.md`). Branch `feature/pro-framing`, base `origin/main` @ 12b6a2e.

## Context

Screenshot Builder v1 (merged as PR #1, `origin/main` 12b6a2e) works, but it looks flat. It has solid colors only, captions that float like annotations, and a generic black rounded rectangle for a frame. Goal: make it compete with real screenshot-framing apps. Done when an ad-hoc council (Opus, Sonnet, Fable) gives a median UI score of 8 or more.

**Facts (checked):**
- Machine: MacBook Pro (`MacBook-Pro`), macOS 27.2, Xcode 27.2 (27B52). Sim runtimes: iOS 27.1 and 27.2.
- Project: a **macOS SwiftPM app** (`Package.swift`, macOS 14+, no Xcode project), about 600 lines. No iOS simulator and no physical device are needed for the app itself. Tests run with `swift test --filter`. The app is built with `scripts/build-app.sh`.
- Repo: root checkout on `main` is clean and 3 commits behind `origin/main`. One worktree (the root). The `dev/screenshot-builder` branch is merged. No parallel work. The untracked `build/` and `.build/` folders in the root stay untouched.
- No `/council` skill exists on this Mac. Geoff approved an ad-hoc panel.

## Answers from Geoff (2026-11-13)

- Council: ad-hoc panel of 3 judges (Opus, Sonnet, Fable). Each judges the editor window **and** an exported 5-shot set, 1–10, against a fixed rubric. Pass = median ≥ 8. Baseline on current `main` first. Max 3 rounds, then escalate.
- Frames: vector frames drawn in code. Geometry is measured from Apple Design Resources bezel PNGs, downloaded to the scratchpad only for measurement and not bundled.
- Samples: I capture 5 screenshots from an iOS 27.2 simulator running a Low Effort Apps project on this Mac. They stay in the scratchpad.
- Permissions: Geoff grants Screen Recording, Accessibility, and Automation (System Events) to **T3 Code (Nightly)**, and stays until the probe passes.

## Isolation

- Worktree: `~/.t3/worktrees/Screenshot-Builder/pro-framing`, branch `feature/pro-framing`, base `origin/main` @ 12b6a2e.
- Local `main` is not fast-forwarded or changed.
- Commits: one per milestone, and fixes in separate commits. Geoff approves push, PR, and merge.

## Milestones (each one is a review stop)

**M0 — Probe and baseline (no product code)**
1. Permission probe: build the app, open it, capture its window with `screencapture -l`, and do one scripted click with System Events. Geoff stays until this passes.
2. Capture 5 simulator screenshots (iPhone 18 Pro Max, iOS 27.2, its UDID pinned) from List-Happens or Bookmark-Collections. Tell Geoff when I take and release the Pro Max.
3. Add a render harness test or script that writes a sample set to the scratchpad as PNGs. This checks export quality with no permissions.
4. Baseline council run on current `main`. Record the scores and the top complaints.

**M1 — Backgrounds and color**
- Background kinds: solid, linear gradient (2–3 stops plus angle), radial or soft-mesh gradient.
- Curated palette presets (about 12 named themes). Each theme sets the background, text, accent, and frame finish together. Swatch grid in the inspector.
- Optional soft device shadow.

**M2 — Accurate device frames**
- Measure the Apple Design Resources bezels: body size, corner radius, screen inset, display corner radius, Dynamic Island size and position, button positions. Store them in a spec table (`DeviceSpec`) with source notes. No numbers from memory.
- Draw frames in vector (body, bezel, buttons, Dynamic Island). Clip the screenshot to the real display corner radius.
- Current devices first: iPhone 6.9 / 6.3, iPad 13 / 11, MacBook. Older presets (6.5, 6.1, 5.5, 12.9) get the closest matching frame.
- Finishes: 3–4 per device (for example black, silver, natural, a color).
- Frame modes: none, flat border, device.

**M3 — Typography and caption composition**
- Fonts: SF, SF Rounded, New York, and macOS-installed families (for example Avenir Next, Futura, Helvetica Neue). Nothing bundled.
- Controls: weight, size (S/M/L), alignment (left/center), tracking, subtitle opacity.
- Accent highlight: wrap words in `*asterisks*` to color them with the theme accent.
- Caption is part of the layout. Type scale and spacing are tuned so the headline reads as a marketing title, not as a label.

**M4 — Layout templates and editor UI**
- Templates: caption top, caption bottom, device bleeds off the bottom edge, device bleeds off the top edge, screenshot only. Stays fixed-layout (no freeform editing or layers, per the TODO backlog).
- Editor: a set filmstrip (all shots side by side, as in App Store Connect), an inspector rebuilt into clear sections (Template, Background, Device, Text) with visual pickers, and a polished toolbar and empty state.

**M5 — Council loop**
- Re-run the council after M4. Fix the top findings as separate commits. Re-run, up to 3 rounds total. If the median stays below 8, stop and escalate with the scores.
- Independent code review (code-reviewer agent, with Fable as an optional second reviewer) before the PR.

## Compatibility and superseded items

- File format: bump to `version 2`. Decode v1 files with defaults (`decodeIfPresent`), so old `.shotset` projects still open. Add a test with a v1 JSON fixture.
- Superseded (I update the docs in the same commits):
  - README line "A generic frame … does not imitate a specific device".
  - DECISIONS: "Keep source captures … uncropped". Display-corner clipping crops only the rounded corners, as on the real device.
  - DECISIONS: the fixed caption band entries. The templates replace them, but the shot stays aligned across the set.
  - "No external dependencies" still holds.
- Tests to update: `captureIsUprightAndUncropped` (corner clip) and `layoutFitsEveryPresetAndOrientation` (new templates and frames).

## Critical files

- `Sources/ScreenshotBuilder/Model/SetStyle.swift` — new background, theme, frame, and text style types; migration.
- `Sources/ScreenshotBuilder/Model/ShotDocument.swift` — version 2 decoding and validation.
- `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift` — split into layout, background, device frame, and text drawing. Keep one shared renderer for preview and export.
- New: `Rendering/DeviceFrame.swift`, `Model/DeviceSpec.swift`, `Model/Theme.swift`.
- `Sources/ScreenshotBuilder/Editor/*` — inspector sections, swatch and template pickers, filmstrip.
- `Tests/ScreenshotBuilderTests/BuilderTests.swift`.
- Docs: README, DECISIONS, CHANGELOG, TODO, and a plan copy in `docs/superpowers/plans/2026-11-13-pro-framing.md`.

## Verification

- After each milestone: `swift build`, then focused tests (`swift test --filter BuilderTests/<test>`), render the sample set to the scratchpad and inspect the PNGs, and capture the live window.
- Before merge: the full `swift test`, plus the v1 project migration test.
- Council: 3 judges with a fixed rubric (visual polish, color, typography, frame realism, editor UX, competitiveness). Inputs: window captures and the exported set. I report each judge's score and the median.

## Human stops

**Unavoidable (3):**
1. **Now — approve this plan and grant permissions.** Grant Screen Recording, Accessibility, and Automation (System Events) to T3 Code (Nightly). Stay about 5 minutes after approval for the M0 probe. These are macOS privacy grants; only you can grant them.
2. **End — hands-on acceptance on this MacBook Pro.** One install: run `scripts/build-app.sh` in the worktree and open the `.app`. About 15 minutes. Taste and feel cannot be automated. I give you a pass/fail checklist then.
3. **End — push, PR, and merge approval.** Your call by the brief.

**Contingencies (only if they occur):**
- macOS asks for Screen Recording again, or captures come out black (screen locked or asleep). Fallback: a debug flag where the app writes snapshots of its own window, at lower fidelity.
- Apple Design Resources downloads need a login or are unavailable. Then I ask you to supply the bezel PNGs.
- The council median stays below 8 after 3 rounds. Then I ask you for direction.
- Product forks I cannot settle from this plan. I ask them once in T3.

**Device pass:** none. This is a Mac app, so no iPhone install. Acceptance stop 2 is one install of about 15 minutes.

## Keep the MacBook Pro

Leave it logged in, unlocked, and awake for the whole run.

## Council results

Rubric: seven criteria (output polish, color, typography, frame realism, editor UX, editor craft, competitiveness), overall 1–10. Judges: Opus, Sonnet, Fable. Pass = median ≥ 8.

| Round | Build | Opus | Sonnet | Fable | Median |
|---|---|---|---|---|---|
| Baseline | `main` 12b6a2e | 4.0 | 3.8 | 3.8 | 3.8 |
| 1 | d6f618d (M1–M4) | 6.6 | 7.4 | 6.6 | 6.6 |
| 2 | f4277db (round 1 fixes) | 6.7 | 6.9 | 6.8 | 6.8 |
| 3 (final) | d04479b (round 2 and review fixes) | 7.0 | 7.3 | 7.3 | 7.3 |

Result: below the 8.0 gate after the 3-round cap. Escalated to Geoff on 2026-11-13 as a scope decision.

Round 3 themes, all three judges:
- Per-shot variety (tilt, offset, two devices, callouts) caps competitiveness at 6–7. This is outside the fixed-layout scope.
- The bleed fade tints the bottom of the screenshot. Judges prefer a clean crop.
- iPad set: the review input used iPhone captures, so they letterboxed inside the iPad. An aspect-mismatch warning, or a phone frame on an iPad canvas, would address it.
- Light themes: white subtitles on Sunset and Peach need a contrast check.
- Empty state: the import card covers the placeholder device.

