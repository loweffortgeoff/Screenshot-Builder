# Chapter 3 handoff (paused 2026-11-14)

Read this first, then the plan and the spec. Pick up at "Next steps".

## Where things are

- **Machine:** MacBook Pro (`MacBook-Pro`), macOS 27.2, Xcode 27.2 (27B52), Swift 6.4.2. No simulator is in use.
- **Worktree:** `/Users/geoffreysilva/.t3/worktrees/Screenshot-Builder/chapter-3`, branch `feature/chapter-3`, created from `7a0341d`.
- **HEAD:** `b9afc39`. The working tree was clean at pause.
- **Push state:** `origin/feature/chapter-3` is at `c5d749e`. Two local commits are not pushed: `31fd8d4` and `b9afc39`. Per the plan, push when milestone E ends.
- **Root checkout:** `/Users/geoffreysilva/Developer/Screenshot-Builder` stays on `feature/pro-framing` at `7a0341d` (pushed). Do not touch it.
- **`main`:** `12b6a2e`. Must stay untouched.
- **Helper agents:** none running.

## Documents

- Plan (approved 2026-11-14): `docs/superpowers/plans/2026-11-14-chapter-3-canvas-and-compositions.md`. Its status line still says "draft"; set it to Approved in milestone N.
- Spec: `docs/superpowers/specs/2026-11-13-chapter-3-canvas-and-compositions.md` (R1–R5, H1–H6).
- Council rubric, which is also the judge prompt: `docs/superpowers/council/council-rubric.md`.
- Council input list: `docs/superpowers/council/inputs.md`.
- Earlier chapters: `docs/superpowers/plans/2026-11-13-pro-framing.md` and `2026-11-13-per-shot-layouts.md`.
- The global `~/.claude/CLAUDE.md` holds Geoff's working rules.

## Geoff's 8 answers (2026-11-14)

1. **Pass bar:** median of Opus, Sonnet, and Fable ≥ 8.0, same 7-criterion rubric. After 3 rounds below 8, stop and ask Geoff.
2. **Council inputs:** the 14 chapter 2 slots plus new slots (Set view, a composition set, a Zoom single, Mac Window only, Mac display fill). The list is in `inputs.md`.
3. **Old files (v1–v3):** they open and keep their content and choices. New options default to the old behaviour (Stacked, no stat). The judged fixes apply to every file, so Zoom, iPad, Mac, and weights may render differently.
4. **Stops:** full-send. Send one short update per milestone ("Nothing for you" or "Action needed"). Stop only for real blockers and at the end.
5. **Sidebar:** remove it (done in C).
6. **Big number stat:** free text.
7. **Overlay band:** frosted blur through Core Image.
8. **Mac default frame:** keep the MacBook frame. Window only is an option.

Also from the spec: Shot 7 Duo was intended. Wide Mac captures get a free 0–100% crop-position slider.

## Standing rules

- No merge. Merging into `feature/pro-framing` happens only on Geoff's word.
- Push only `feature/chapter-3`, at milestone ends. Never touch `main` or the root checkout.
- Keep implementation and fix commits separate. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No reset, no rebase of published commits, and no branch or worktree deletion without approval.
- Not for release, so do not change version or build numbers.
- Tests: during work, `swift test --filter BuilderTests/<test>` (or the whole `BuilderTests` suite). Run the full `swift test` before each council round and before any merge request. Report the filter and the counts.
- Updates use ASD-STE100: short, imperative sentences.

## Milestones

| Milestone | State | Commits |
|---|---|---|
| Step 0: assets, permission probe | Done | `ba72856` |
| Z: Zoom quality (R1.1–R1.3, R1.5, R1.6) | Done, pushed | `e110368` |
| C: Canvas, zoom, Set view, sidebar removed (R2.1–R2.3) | Done, pushed | `c5d749e` |
| E: On-canvas editing, tab craft, drag, real weights (R2.4–R2.6, R1.4) | **In progress** | `31fd8d4`, `b9afc39` (local) |
| P: iPad fill, Mac frame, Window only, Mac fit (R3, R4) | Not started | |
| K: Compositions and format v4 (R5) | Not started | |
| N: Freeze, review, council, docs | Not started | |

### Done in E so far

- **Real weights** (`31fd8d4`). `CaptionFont.faces` comes from `NSFontManager` (upright, regular-width faces only). `headlineWeights` = real weights minus the lightest. `resolve` maps a stored weight to the nearest real face, and `subtitleWeight(for:)` picks a lighter real face. `SetStyle.headlineFont` and `subtitleFont` are used everywhere. `CaptionWeight` gained Regular and Medium.
  - Result on this Mac: Futura offers Bold only (Medium becomes the subtitle). Georgia offers Bold over a Regular subtitle. Helvetica Neue offers Medium and Bold. Avenir Next offers Medium to Heavy. The SF designs offer Medium to Black.
  - The spec example said Futura offers "Medium and Bold". The spec rule that the subtitle is always lighter wins. Record this in DECISIONS.
- **Custom Zoom region and card offset** (`31fd8d4`). Adds `CalloutRegion.custom`, `Shot.calloutRect`, `Shot.calloutCardOffset`, and `Shot.snappedCalloutRect`. `Callout` exposes `screen` and `autoRect`. "Reset position" is in the arrangement inspector.
- **On-canvas editing and drag** (`b9afc39`, in `PreviewPane.swift`).
  - Double-click the headline, subtitle, or badge to edit it. Return or a click away commits; Esc cancels.
  - A single click on the device opens the Style tab.
  - Dragging the ring sets a custom region; dragging the card sets its offset.
  - Verified live: the headline edit commits and saves, and Esc restores the old text.

### Next steps (E remainder, then P, K, N)

1. In `PreviewPane.overlays`, add `.frame(minHeight: rect.height * scale, alignment: .top)` to the TextField, before `.padding(6)`. Today the editor shrinks to one line and the rendered second line shows below it. This edit was interrupted and is not in the file.
2. Verify live: ring drag, card drag, and badge and subtitle edits. Use `build/e/Zoom.shotset` (a callout set). In the 1440 × 920 window at Fit, the ring is near window point (355, 498) and the card spans about (262–520, 548–644). Re-measure from a capture first.
3. Caption tab craft (R2.5), in `StyleInspector.textSection` and `CaptionInspector`:
   - a font grid of "Ag" tiles, each drawn in its own family, with names;
   - weight segments drawn in each weight, labelled with `faceName`, from `headlineWeights` (show static text for a single weight);
   - a Highlight hint line under the headline;
   - a two-line minimum for the subtitle editor.
4. Device tab craft (R2.6), in `StyleInspector.deviceSection`:
   - 28 pt finish swatches with a name under each and a tooltip;
   - the device name and a small frame diagram;
   - a Placement group (size, shadow, and a mini preview from the selected shot's thumbnail, passed in from `EditorView.thumbnails`).
5. Window-capture the Caption and Device tabs. Run `BuilderTests`. Commit. Push `feature/chapter-3`. Send the milestone E update.
6. Milestones P, K, and N as the plan describes.

## Decisions made during the run (record in DECISIONS.md at N)

- **Zoom card width:** the card may span the canvas safe width (0.88 × width), not the spec's 0.78. At 0.78 the card showed half-rows ("Note / Store" without values) or the device shrank to half the canvas. Geoff was told in the Z update and has not objected.
- **Zoom whole rows:** whole rows are kept by shrinking the device (scale down to 0.58); the band narrows only when no device size fits. Auto skips the status bar, navigation bar, tab bar, and home indicator (blocks must sit within 0.085–0.885 of the height). Device and card are centered together, moving only away from the caption.
- **Busy-row threshold:** lowered so that faint secondary text counts as content (`contentBlocks`).
- **Sidebar and `ShotRow.swift`:** removed (Geoff approved).
- **Weights:** see "Done in E so far". Futura offers Bold only.

## Delegation, pstack, and judges

- **pstack:** poteto-mode principles (model the domain, sequence verifiable units, prove it works, subtract before add). The model roles are in `~/.claude/rules/pstack-models.md` (feature work: Sonnet, high effort).
- **Delegate brief template:** `subagent_type: pstack:poteto-agent`, `model: sonnet`, `effort: high`, foreground. The brief names the worktree, says "do not commit", and lists tests and render checks. The parent reviews the diff, builds, tests, and commits.
- **Gotcha: subagents believed plan mode was active.** The first delegate (Z) only wrote a plan, then implemented after a SendMessage resume. The second (E) refused even after a resume. With Full Access set, try again. If a delegate still refuses, do the work inline, as was done for E.
- **Judges (milestone N):** three `general-purpose` agents in one message, with `model` set to `opus`, `sonnet`, and `fable`. Each reads `council-rubric.md` and every input image. Report each score, the median, and the SHA.
- **Fable** runs only as the third judge and the second code reviewer (Geoff's brief allows those roles). The code review before the council uses `code-reviewer` plus Fable; verify each finding before fixing, and commit fixes separately.

## Files moved to safe places

All are in the worktree's git-ignored `build/assets/`. They survive a reboot but are not committed.

- `council-rubric.md`. The committed copy is in `docs/superpowers/council/`.
- `samples/`: List Happens, iPhone 6.9, 1320 × 2868, `01.png`–`05.png`.
- `samples-ipad/`: Bookmark-Collections from the iPad Pro 13-inch simulator, 2064 × 2752. Use `captions-ipad.txt` with these.
- `samples-mac6/`: the app window, 1440 × 920.
- `mac-3440x1440.png`: Geoff's full-screen external-display capture, for H3 and R4.4. The original is `Dev Workstation/Visual Verification/screenshot builder/CleanShot 2026-11-14 at 03.41.35.png`. It has an alpha channel but is opaque, so test corner pixels, not `alphaInfo`.
- `Bezel-MacBook-Air-M5.dmg`: Apple Design Resources bezel, for R4.1. Measure only; do not bundle.
- `c2r3/`: the chapter 2 final council inputs (14 images).
- `c2r3src/<slot>/Sample.shotset`: one project per chapter 2 set slot (default, vary, span, sunset, ipad, mac). Re-render one with `SB_PROJECT=<path>`.

The original chapter 2 scratchpad (`/private/tmp/claude-501/-Users-geoffreysilva-Developer-Screenshot-Builder/af5e4e82-…/scratchpad/`) is volatile. Do not rely on it.

## Tools and gotchas

- **Review harness:** `SB_SAMPLES=$PWD/build/assets/samples SB_OUT=$PWD/build/<dir> [knobs] swift test --filter SampleRenderTests`.
  - Knobs from Z: `SB_REGION`, `SB_MARKER`, `SB_LENS`, `SB_PROJECT`.
  - Existing knobs: `SB_ARRANGE` (an `Arrangement` raw value or `vary`), `SB_LAYOUT` (for example `"Caption below"`), and others listed in the README.
  - `SB_PRESET` takes the case name (`pad13`, `mac`), not the title.
- **App and window capture:** `scripts/build-app.sh`, then `scripts/capture-window.sh <project> <png>`.
- **Input helper:** `build/tools/mouse` (source `build/tools/mouse.swift`, git-ignored; compile it with `swiftc -O mouse.swift -o mouse`). Commands: `click x y`, `dclick x y`, `drag x1 y1 x2 y2`, and `key <keycode> [cmd]`. Coordinates are global screen points.
  - Bring the app to the front with System Events before every input, or the click lands on another window.
  - Wait about 0.4–0.8 s between a double-click and typing. `osascript -e 'tell application "System Events" to keystroke "…"'` types text.
  - Key codes: 0 = A, 1 = S, 6 = Z, 18 = 1, 19 = 2, 29 = 0, 36 = Return, 53 = Esc.
  - The window opens at screen point (1029, 305), size 1440 × 920. This display is 1×, so capture pixels equal window points.
- **Permissions:** T3 Code has Screen Recording, Accessibility, and Automation on the MacBook Pro (probe passed). The Mac must stay awake and unlocked.
- **Swift overloads:** `CaptionFont.font(size:weight:)` takes either `CaptionWeight` or `NSFont.Weight`, so `.bold` is ambiguous. Write `CaptionWeight.bold` or `NSFont.Weight.bold`.
- **Display scale:** `PreviewPane` uses `@Environment(\.displayScale)`. Zoom 100% means 1 export pixel per screen pixel.
- **Edit tool error:** the Z delegate once hit an Edit/Write error ("adapter has no active turn"). If it recurs, restart the turn; do not fall back to sed edits.
- **Pinch zoom:** cannot be scripted. It stays on Geoff's end checklist as not verified.

## Human stops still ahead

1. **End:** Geoff's hands-on acceptance (one build, about 20 minutes, checklist in the plan).
2. **End:** merge decision.
3. **Contingencies:** council below 8 after 3 rounds; the Mac bezel cannot be measured; a product fork the spec does not settle.
