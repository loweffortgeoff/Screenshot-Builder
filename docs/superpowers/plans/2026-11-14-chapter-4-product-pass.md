# Chapter 4 product pass plan

Status. Approved by Geoff on 2026-11-14. Work runs on `feature/chapter-4` in `~/Developer/Screenshot-Builder-ch4`, and Claude pushes only that branch. The spec is `docs/superpowers/specs/2026-11-14-chapter-4-product-pass.md`.

Chapter 4 makes Screenshot Builder produce sets like Geoff's own App Store sets with fewer manual steps. Users get six starter looks, one decorative background layer, layout-placed eyebrows and accents, a Lead composition for portrait iPhone, and a clearer inspector. The rule is product value, not a score. One council round runs at the end, and then the chapter stops. The milestones, in order, are M0 judge calibration, M1 Lead, M2 decorations, M3 backdrops, M4 looks, M5 editor polish, M6 Zoom card, M7 frame defects, M8 code review, M9 council review, M10 hands-on checklist and closeout.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

This plan adapts the pstack multi-phase skeleton to Geoff's rules in `~/.claude/CLAUDE.md`. Those rules win where the two differ.

- One feature branch, `feature/chapter-4`, in one worktree. One section per milestone, not per PR. No PRs and no merges. Claude pushes the branch at the end of each milestone. Geoff decides about `main`.
- Live checks run locally on the MacBook Pro or the Mac mini, not on cloud VMs. They use the review harness (`SampleRenderTests`) and `scripts/capture-window.sh`. Each milestone has fewer than ten lanes, because each milestone touches one area.
- Implementation commits and fix commits stay separate.
- Each milestone ends with a short update to Geoff that ends in "Nothing for you" or "Action needed".
- The pstack plan checker (`check-plan.mjs`) still flags these template rules, which the plan does not follow on purpose. It wants PR, owner, merge, cloud boot, and `/loop` sections. It wants ten lanes per section, a screenshot in every lane (regression lanes compare pixels instead), four perf boxes even where no render path changes, a Merge block, and a screenshot-and-video review gate. It wants "A PR is verified" where this plan says "A milestone is verified". The one long dash it flags is the literal eyebrow label "01 — ".
- The execution playbook is `playbooks/autopilot-stack.md` in spirit (build and verify, Geoff lands). Claude owns commits. Delegates write code only when the plan names them.

Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Arm the program

- [ ] Give Geoff the spec and this plan, then stop. Start only on Geoff's explicit go. Defaults apply to any of Q3 to Q7 he skips. Q1 and Q2 have no default, so M6 waits for his explicit answer.
- [ ] Record Geoff's answers in the spec's "Open questions" section and in `DECISIONS.md` (doc-only commit on `main`).
- [ ] Create the worktree from `main` with `git -C ~/Developer/Screenshot-Builder worktree add ~/Developer/Screenshot-Builder-ch4 -b feature/chapter-4 main`. The evidence is `git worktree list`.
- [ ] Name the machine in the first update (`hostname`, `xcodebuild -version`).

### Shared commands

- **Focused tests.** Run `swift test --filter BuilderTests/<testName>` from the worktree. Report the filter and the pass and fail count.
- **Full suite.** Run `swift test` only at M8 and M9. Chapter 3 ended at 80 tests.
- **Renders.** Run `SB_SAMPLES=<folder> SB_OUT=<scratchpad folder> [knobs] swift test --filter SampleRenderTests`. Knobs are in `README.md`. M2 to M4 add `SB_LOOK`, `SB_BACKDROP`, `SB_EYEBROW`.
- **Window captures.** Run `scripts/build-app.sh`, then `scripts/capture-window.sh <project> <png>`. The terminal needs Screen Recording permission.
- **Regression lane.** Run `scripts/compare-renders.sh <shaA> <shaB>` (built in M1). It renders the six `c2r3src` slot projects at both SHAs and compares pixels with a small Swift helper. Pass when every slot matches exactly. The grain tile is seeded (`ShotRenderer.grainTile`), so renders are deterministic.

### Inputs

- **Dark iPhone.** `~/Documents/Dev Workstation/Visual Verification/screenshot builder/ch3-check/assets/samples/` (List Happens).
- **Light iPhone.** Copy `~/Downloads/aislewise-light-1-list-tab.png` to `-5-settings.png` as `01.png` to `05.png` into `~/Documents/Dev Workstation/Visual Verification/screenshot builder/ch4-inputs/light/`. The source files are read-only. Only the copy is renamed.
- **iPad.** `ch3-check/assets/samples-ipad/`.
- **Mac.** `ch3-check/assets/mac-3440x1440.png` and `samples-mac6/`.
- **Slot projects.** `ch3-check/assets/c2r3src/<slot>/Sample.shotset`.
- Geoff swaps in better Mac and light captures by replacing the files in `ch4-inputs/`. The input list names folders, not files.

## Calibrate the GPT judge and measure the baseline (M0)

**Depends on.** Geoff's go. No code changes.

**Files.**

- [ ] Create `docs/superpowers/council/judge-calibration.md`.

**Build.**

- [ ] Write the pick criteria in `judge-calibration.md` before any run. A judge passes when (a) it states one specific observation per input file that matches that PNG, (b) every issue it lists names a file, and (c) no claim contradicts the image. Scores are recorded and not used.
- [ ] Rebuild the chapter 3 round 3 inputs. They are not on this Mac (only chapter 2's `c2r3` folder exists). Run `git -C ~/Developer/Screenshot-Builder archive d02e7d7 | tar -x -C <scratchpad>/d02e7d7`, then render the 20 slots in `inputs.md` from there. Window captures come from the app built at `d02e7d7`. The chapter 3 notes do not record the `jq` edits behind `set-compositions.png`, so the rebuilt set may differ from the scored one. Record that in `judge-calibration.md`. If Geoff still has the original round 3 PNGs, use those instead.
- [ ] Run `gpt-6.1-sol` (reasoning high) and `gpt-6-astra` (reasoning high) through `delegate_task` on the Codex provider, each with `council-rubric.md` and the 20 PNG paths. Ask each to list every file it opened.
- [ ] Count the style actions from "5 captures imported, captions typed" to a set that matches the Orb reference (Task-ed) on `main` at `79a6186`. Record each action.

**You see.**

- [ ] `judge-calibration.md` holds both reports, the per-file check, the pick, and the reason. It says whether the Codex judge read the PNGs (each report quotes something only visible in the image).

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] None. M0 changes no code.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Claude opens each of the 20 PNGs and checks every judge observation against it. Pass when the picked judge has no contradicted claim.
- [ ] Lane 2. Baseline count on `main`. Save the action list. Pass when the list is complete from import to export.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] None. No code changes.

**Review gate.** Geoff reads the pick in the M0 update. If neither judge passes, stop and ask.

## Replace portrait Side by side with Lead (M1)

**Depends on.** M0 is independent; M1 may start in parallel.

**Files.**

- [ ] Edit `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift` (the `.sideBySide` portrait branch in `compose` and `CaptionMetrics.init`).
- [ ] Edit `Sources/ScreenshotBuilder/Editor/StyleInspector.swift` (tile title on portrait phone).
- [ ] Edit `Tests/ScreenshotBuilderTests/BuilderTests.swift`.
- [ ] Create `scripts/compare-renders.sh` and `scripts/compare-pngs.swift`.

**Build.**

- [ ] On portrait phone presets, `.sideBySide` composes as Stacked with left alignment and Bleed bottom, with the device at 0.80 × width or more (spec R4.1).
- [ ] The composition label reads "Lead" on portrait phones (spec R4.1, Q3).
- [ ] Delete the portrait-only constants (`portraitSideDeviceWidth`, `portraitSideBleed`) once nothing reads them.

**You see.**

- [ ] A Lead export on phone69 matches the Bleed bottom and Left prototype (Appendix A) with the device at 0.80 × width or more.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] `leadComposesLeftCaptionOverBleedingPhone` (device width, bleed, left caption). Run `swift test --filter BuilderTests/leadComposesLeftCaptionOverBleedingPhone`.
- [ ] `version4PortraitSideBySideOpensAsLead`. Run its filter.
- [ ] Existing Side by side, caption band, and arrangement visibility tests. Run `swift test --filter BuilderTests/sideBySide` and `BuilderTests/everyArrangement`.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk. `scripts/compare-renders.sh 79a6186 HEAD`. Pass when all six slots match exactly (none uses portrait Side by side).
- [ ] Lane 2. Render the dark set with `SB_COMPOSITION=sideBySide`. Save `m1-lead-dark.png`. Pass when all 5 shots are Lead and headlines share a baseline.
- [ ] Lane 3. Same on the light set. Save `m1-lead-light.png`. Pass when all 5 shots are Lead and headlines share a baseline.
- [ ] Lane 4. Render iPad and landscape with Side by side. Save `m1-side-ipad.png`. Pass when the geometry equals `main`.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Wall time of `SampleRenderTests` for the dark set. Probe. Run it three times at `79a6186` and at head, interleaved. Baseline first. Rule. Fail if the head median is more than 20% slower.

**Review gate.** Geoff sees `m1-lead-dark.png` and `m1-lead-light.png` in the M1 update.

## Add layout-placed decorations and format v5 (M2)

**Depends on.** M1.

**Files.**

- [ ] Edit `Sources/ScreenshotBuilder/Model/SetStyle.swift` (`Decor`, `EyebrowMode`).
- [ ] Edit `Sources/ScreenshotBuilder/Model/Shot.swift` (`eyebrow`).
- [ ] Edit `Sources/ScreenshotBuilder/Model/ShotDocument.swift` (version 5).
- [ ] Edit `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift` (eyebrow row in `CaptionBand`, eyebrow, rule, shapes drawing).
- [ ] Edit `Sources/ScreenshotBuilder/Editor/CaptionInspector.swift` and `PreviewPane.swift` (eyebrow controls, on-canvas edit).
- [ ] Edit `Tests/ScreenshotBuilderTests/SampleRenderTests.swift` (`SB_EYEBROW`, `SB_APPNAME`, `SB_RULE`, `SB_SHAPES`).
- [ ] Edit `Tests/ScreenshotBuilderTests/BuilderTests.swift`.

**Build.**

- [ ] Spec R3.1 to R3.7, in that order. One commit for the model and format, one for rendering, one for the editor.

**You see.**

- [ ] A dark set with eyebrow "Numbered", rule, and shapes reads "01 — …" to "05 — …" and keeps headlines aligned.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] `eyebrowLabelPerMode`, `eyebrowRowReservedAcrossSet`, `numberedEyebrowFollowsOrder`, `shapesStayClearOfCaptionDeviceAndCard`, `version4FilesDecodeWithDecorOff`. Run each by filter.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk. `scripts/compare-renders.sh 79a6186 HEAD`. Pass when all six slots match exactly (decor off by default).
- [ ] Lane 2. Dark set, every eyebrow mode. Save `m2-eyebrow-<mode>.png`. Pass when labels are correct and aligned.
- [ ] Lane 3. Composition set (Lead, Big number, Overlay, Text only) with all decorations on. Save `m2-compositions.png`. Pass when R3.7 holds.
- [ ] Lane 4. Live app. Double-click an eyebrow, type, press Return. Save `m2-edit.png`. Pass when the inspector field and the export match.
- [ ] Lane 5. Reorder in Set view. Save `m2-reorder.png`. Pass when numbers follow the new order.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Same metric, probe, and rule as M1, with all decorations on at head.

**Review gate.** Geoff sees lanes 2 and 3 in the M2 update.

## Add backdrops, hue shift, and the advanced background menu (M3)

**Depends on.** M2 (format v5).

**Files.**

- [ ] Edit `Sources/ScreenshotBuilder/Model/SetStyle.swift` (`Backdrop`, `BackdropKind`).
- [ ] Edit `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift` (`drawBackdrop`, hue shift in `drawBackground`, contrast sampling).
- [ ] Edit `Sources/ScreenshotBuilder/Editor/StyleInspector.swift` and `BackgroundSwatch.swift` (Advanced background disclosure).
- [ ] Edit `Tests/ScreenshotBuilderTests/SampleRenderTests.swift` (`SB_BACKDROP`, `SB_HUESHIFT`).
- [ ] Edit `Tests/ScreenshotBuilderTests/BuilderTests.swift`.

**Build.**

- [ ] Spec R2.1 to R2.5. One commit for the model, one per pair of backdrops, one for hue shift, one for the editor.

**You see.**

- [ ] Each backdrop sits behind the device and never crosses the caption or the Zoom card.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] `backdropNeverCoversCaptionDeviceOrCard`, `hueShiftLeavesStoredStyleUnchanged`, `hueShiftedShotsPassContrast`, `spanSetDisablesHueShift`. Run each by filter.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk. `scripts/compare-renders.sh 79a6186 HEAD`. Pass when all six slots match exactly.
- [ ] Lane 2. Each backdrop on the dark set with Vary layouts. Save `m3-<backdrop>.png`. Pass when the layer stays behind the device in Standard, Lead, Tilt, Duo, and Zoom.
- [ ] Lane 3. Arcs with hue shift on Ember (or Graphite if Q6 is declined). Save `m3-hue.png`. Pass when the hue steps across shots and every caption is legible.
- [ ] Lane 4. The light set with each backdrop. Save `m3-light-<backdrop>.png`. Pass when no backdrop muddies a light background.
- [ ] Lane 5. Window capture with the disclosure closed and open. Save `m3-window-closed.png`, `m3-window-open.png`. Pass when the closed Style tab shows no backdrop controls and the open one shows the five tiles and the hue toggle.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Same metric and probe as M1, with Bokeh (the blur) at head. Rule. Fail if the head median is more than 30% slower, because a blurred layer is new work.

**Review gate.** Geoff sees lanes 2 and 3 in the M3 update.

## Add the six starter looks and the gallery (M4)

**Depends on.** M2 and M3.

**Files.**

- [ ] Create `Sources/ScreenshotBuilder/Model/Look.swift` (registry of six looks, `apply`, `matches`).
- [ ] Edit `Sources/ScreenshotBuilder/Model/Background.swift` (themes Violet, Coral, Ember, Field, Amber, Mist, if Q6 is accepted).
- [ ] Create `Sources/ScreenshotBuilder/Editor/LookPicker.swift` (tiles with live thumbnails).
- [ ] Edit `Sources/ScreenshotBuilder/Editor/StyleInspector.swift` (Looks row at the top).
- [ ] Edit `Sources/ScreenshotBuilder/Model/SetStyle.swift` (`monoEyebrow`, if Q5 is accepted).
- [ ] Edit `Tests/ScreenshotBuilderTests/SampleRenderTests.swift` (`SB_LOOK`).
- [ ] Edit `Tests/ScreenshotBuilderTests/BuilderTests.swift`.

**Build.**

- [ ] Spec R1.1 to R1.6 with the recipe table. One commit for themes, one for the registry, one for the gallery.

**You see.**

- [ ] One click on a tile turns an imported set into the look. One Undo returns it.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] `everyLookPassesContrastAndHasNoIssues` (6 looks × dark and light inputs × phone69, pad13, mac), `lookKeepsCaptionsArrangementsAndDevice`, `lookApplyIsOneUndoStep`, `lookMatchesOnlyItsOwnOutput`. Run each by filter.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk. `scripts/compare-renders.sh 79a6186 HEAD`. Pass when all six slots match exactly (a look applies only on click).
- [ ] Lane 2. Each look on the dark set. Save `m4-<look>-dark.png`. Pass when it resembles its model set (Appendix D) and has no issue.
- [ ] Lane 3. Each look on the light set. Save `m4-<look>-light.png`. Pass when it resembles its model set and has no issue.
- [ ] Lane 4. Orb on iPad and Mac. Save `m4-orb-ipad.png`, `m4-orb-mac.png`. Pass when R1.4 holds.
- [ ] Lane 5. Window capture of the Style tab with the gallery. Save `m4-window.png`. Pass when six labelled tiles show live thumbnails of the selected shot.
- [ ] Lane 6. Recount the actions to reach Orb, typing the app name included. Save the list in `judge-calibration.md` beside the M0 count. Pass when the count is 3 or fewer.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Time to draw the six gallery thumbnails after a shot changes. Probe. Signpost around the thumbnail render, ten runs. Rule. Fail above 150 ms total on the MacBook Pro. Trunk has no gallery, so this is an absolute budget.

**Review gate.** Geoff sees the 12 look contact sheets in the M4 update. This is the main product check.

## Polish the editor (M5)

**Depends on.** M4 (the Looks row and the eyebrow controls exist).

**Files.**

- [ ] Edit `Sources/ScreenshotBuilder/Editor/StyleInspector.swift`, `CaptionInspector.swift`, `EditorView.swift`, `LayoutPicker.swift` (or a new `CompositionPicker.swift`).

**Build.**

- [ ] Spec R6.1 to R6.5. One commit each.

**You see.**

- [ ] Composition is a tile row. The inspector does not change width. The Style tab has Set and This shot headers.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] No unit test covers view layout. Build only (`swift build`), and say so.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Window captures of each tab at 1440 × 920. Save `m5-<tab>.png`. Pass when no Composition pop-up remains and the Style tab does not scroll with Advanced closed.
- [ ] Lane 2. Capture before and after Set view. Save `m5-width-before.png`, `m5-width-after.png`. Pass when the inspector width matches.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] None. Layout change only, no render path change.

**Review gate.** Geoff sees the tab captures in the M5 update.

## Restyle the Zoom card per Geoff's answer (M6)

**Depends on.** Q1 and Q2. Independent of M2 to M5.

**Files.**

- [ ] Edit `Sources/ScreenshotBuilder/Rendering/ShotRenderer.swift` (`drawCallout`, `cardBorder`, `markerStrokeWidth`, and placement limits only if Q2 relaxes them).
- [ ] Edit `Tests/ScreenshotBuilderTests/BuilderTests.swift` (the R1.6 marker test, adjusted only if Q1 is C or D).

**Build.**

- [ ] Q1 B (Geoff, 2026-11-14). The card border and lens connector take a tint between white and the theme accent, at the same width. The card shadow alpha drops from 0.40 to 0.28. The marker does not change. Q2 keeps the 1.6× floor and the 0.24 band cap.
- [ ] Fold in the M0 finding. The Auto crop on `export-zoom-ch3.png` (List Happens shot 4) takes the "Recent Trips" heading without its rows. Make the crop stop before a heading row whose group does not fit. Add a test with a synthetic heading-then-rows block.

**You see.**

- [ ] The card takes the theme tint on Ocean, Noir, and Mist.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] The marker-ratio test and `everyArrangementStaysVisibleAndClearOfCaptions`. Run both by filter.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk. Render a Zoom shot at `79a6186` and head on the same capture. Save `m6-zoom-before.png`, `m6-zoom-after.png`. Pass when only the card and connector styling differ, unless Q2 relaxes placement.
- [ ] Lane 2. Five Zoom shots on dark and light. Save `m6-zoom-set-dark.png`, `m6-zoom-set-light.png`. Pass when no marker reads as a second card (H1).

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Same metric and rule as M1 on a Zoom set.

**Review gate.** Geoff sees lane 2. H1 is his finding, so he confirms it.

## Fix specific frame defects (M7)

**Depends on.** None.

**Build.**

- [ ] Claude opens Geoff's `2026-11-14-Framing-test` exports and the M1 to M6 renders and lists each frame defect with its file. Fix only listed defects. If the list is empty, skip M7 and say so.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] One test per fixed defect where geometry can be asserted.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Before and after crops of each defect. Pass when the defect is gone and `compare-renders.sh` shows changes only in the frame.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] None unless a fix changes the frame path cost.

**Review gate.** None. M7 is not review-gated beyond the update.

## Run the code review and full suite (M8)

**Depends on.** M1 to M7.

**Build.**

- [ ] Run `code-reviewer` and Fable (`model: fable`) on `git diff main...feature/chapter-4`, with the spec path. Fable checks correctness and bugs.
- [ ] Fix each confirmed finding in separate fix commits. Record rejected findings with a reason.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Full suite `swift test`. Report the count. Pass with zero failures.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk. `scripts/compare-renders.sh 79a6186 HEAD`. Pass when all six slots match exactly.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Re-run the M1 probe at head. Same rule.

**Review gate.** None.

## Run one council round (M9)

**Dropped by Geoff on 2026-11-14.** He no longer chases a score and wants correctness within reason, so M9 did not run. The M0 calibration stays on record for any later review. The boxes below are kept as written and are not checked.

**Depends on.** M8 and M0.

**Files.**

- [ ] Create `docs/superpowers/council/chapter-4-inputs.md` and `chapter-4-results.md`.

**Build.**

- [ ] Freeze the SHA. Build these slots. Each names its source folder.
  - [ ] Windows. `window-looks.png` (gallery), `window-advanced.png` (Advanced background open), `window-caption.png` (eyebrow controls), `window-set.png`, and two interaction captures, `window-edit-before.png` and `window-edit-after.png` (on-canvas eyebrow edit).
  - [ ] Sets. One contact sheet per look, half on dark inputs and half on light (`set-orb.png` to `set-calm.png`), `set-lead.png`, `set-ipad.png`, and `set-compositions.png` (Lead, Big number, Stacked with Zoom, Overlay, Text only), which keeps the hard cases.
  - [ ] Singles. `export-zoom-dark.png`, `export-zoom-light.png`, `export-mac-window.png`, `export-mac-display.png`.
- [ ] Run Opus, Sonnet, and the M0 judge, in one message, with `council-rubric.md` unchanged.
- [ ] Fix findings that two or more judges repeat and that are in scope. Separate fix commits. No second round.

**You see.**

- [ ] `chapter-4-results.md` holds the scores as a new baseline, the repeated findings, the fixes, and the five success checks with evidence.

**Verify, unit.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Full suite after fixes. Report the count.

**Verify, live.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Lane 1. Regression lane against trunk after fixes. Pass when all six slots match exactly.

**Verify, perf.** Tests alone are not sufficient verification. A milestone is verified only when its unit, live, and perf boxes are all checked.

- [ ] Re-run the M1 probe. Same rule.

**Review gate.** Geoff reads the success checks and decides whether the sentence is met.

## Close the program

This is milestone M10. The batched hands-on checklist for Geoff is in `docs/superpowers/plans/2026-11-14-chapter-4-hands-on.md`.

- [ ] Write one hands-on checklist for Geoff, about 20 minutes long. It covers these steps. Apply each look, undo, edit an eyebrow on the canvas, reorder and watch numbers, toggle Advanced background, hue shift with Span set, a Zoom shot, a portrait Lead shot, save and reopen a version 4 file.
- [ ] Run the doc ritual on the branch for `TODO.md`, `DECISIONS.md`, `CHANGELOG.md`, `README.md` (knobs, workflow).
- [ ] Push `feature/chapter-4`. Say where it is checked out. If the worktree is clean and pushed, offer to remove it.
- [ ] Every box above is checked with its evidence.

## Appendix A. Prototype evidence

- Portrait. On `main` at `79a6186`, the dark set rendered with `SB_LAYOUT="Bleed bottom" SB_ALIGN=Left SB_THEME=Midnight` gives a left caption over a large phone that bleeds off the bottom, with headlines on one baseline across all 5 shots. It matches the AisleWise and Task-ed pattern. The same set with `SB_COMPOSITION=sideBySide` puts a narrow four-line caption beside an offset phone. Files are in the session scratchpad (`proto-bleed/set.png`, `proto-side/set.png`). This is why R4 reuses Stacked geometry instead of new layout code.
- Judges. `orchestrator_capabilities` lists `gpt-6.1-sol` and `gpt-6-astra` on the Codex provider, both with reasoning high. Whether a Codex judge reads PNGs is unproven until M0.
- Unproven. Backdrop appearance on light themes, hue shift legibility, and gallery thumbnail cost. M3 and M4 test them.

## Appendix B. Alternatives rejected

- A new composition case for Lead. Stacked with forced left and bleed already draws it, so a new case adds code and a format value for no gain.
- Freeform decorations the user drags. This breaks the fixed-layout model (DECISIONS 2026-09-07) and adds layer state.
- Storing the picked look in the project. A look is a recipe. Storing it creates a second source of truth that drifts once the user edits a value.
- Hue shift written into stored colors. It would break `SetStyle.theme` equality and make undo noisy.
- Ten cloud lanes per milestone. Geoff's projects run local simulators and Mac app captures. Local lanes give the same evidence.

## Appendix C. Risks

- Lead changes old portrait Side by side files (M1). Watch the version 4 fixture test. Q3 lets Geoff keep the old geometry.
- The accent rule could read as a stray dash, as the Text only bar did in chapter 3 (M2). Text only skips it. Watch M2 lane 3.
- Backdrops behind dark captures on dark themes could muddy the device edge (M3). Watch lane 2.
- Gallery thumbnails render six shots on every change (M4). The perf budget covers it. Cache by style hash if it fails.
- The Codex judge may not open images (M0). If so, stop and ask Geoff.
- The Mac display capture is still Geoff's real desktop (M9). It stays fixed input until he supplies a cleaner one.

## Appendix D. Links and reading list

- Geoff's model sets are in `~/Documents/Dev Workstation/App Images/ASC Screenshots/<App>/` (Task-ed, EveryPaw, Offshoots, AisleWise in `App Store Version/`; Weather in Words in `Current App Store Version/`; Tucked in `Current Version/`). Read-only.
- `docs/superpowers/council/council-rubric.md`, `inputs.md`, `chapter-3-results.md`.
- `DECISIONS.md` entries from 2026-11-13 and 2026-11-14 (Zoom, Side by side, Text only, format v4).
- This plan uses the pstack skills `poteto-mode` (multi-phase plan), `technical-writing`, `unslop`.
