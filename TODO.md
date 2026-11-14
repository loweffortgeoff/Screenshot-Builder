# TODO

## Next
- Chapter 3 decision: the council median stayed at 7.4 after three rounds (pass bar 8.0). Geoff decides: accept 7.4, or approve spec changes for another round. Results: `docs/superpowers/council/chapter-3-results.md`. Branch `feature/chapter-3` (pushed, not merged).
- Chapter 3 hands-on acceptance (Geoff, about 20 minutes): the end checklist in `docs/superpowers/plans/2026-11-14-chapter-3-canvas-and-compositions.md`. Pinch zoom is not verified (it cannot be scripted).
- iPad acceptance: not tested by Geoff (2026-11-14, no iPad Pro on hand). iPad output can be checked with iPad Pro simulator captures; Geoff's acceptance stays open.

## Backlog
- Highlight menu: typed markup that spans words (for example `*one tap*`) shows unchecked and cannot be cleared from the menu; a word both typed and stored needs two clicks. Found in code review 2026-11-13; low impact because the menu writes single-word accents.
- Mac fit advisory: when Auto chooses Window, no advisory names that choice (only an explicit Window does). Kept quiet to avoid a warning on every Mac window set. Found in the chapter 3 review, 2026-11-14.
- Editor performance: `PreviewPane` composes the shot in its view body, so a Zoom shot costs about 10 ms per keystroke or drag step (measured 2026-11-14). Cache the layout with the render if typing ever feels slow.
- Zoom narrow crop on a cropped Mac capture: a gap just right of the visible edge could give a thin card. Not reproduced; a reviewer question from 2026-11-14.
- Outside v1: freeform editing, layers, stickers, AI copy, localization management, and direct upload. These do not serve the initial fixed-layout workflow.

## Done
- 2026-11-14 — Chapter 3 implemented (milestones Z, C, E, P, K, N): Zoom quality, fit-to-pane canvas with zoom and Set view, on-canvas editing and drag, real weights, tab craft, iPad fill, Mac fit and Window only, MacBook redraw, five caption compositions, format v4. Code review by code-reviewer and Fable; fixes committed. Council medians 7.3, 7.4, 7.4 (branch feature/chapter-3).
- 2026-11-14 — Geoff's hands-on check of chapters 1–2 on MacBook Pro (iPhone 6.9 and Mac outputs). Findings folded into the chapter 3 spec; iPad not tested.
- 2026-11-13 — Chapter 2, per-shot layouts: Tilt, Hero, Duo, and Zoom arrangements, Vary layouts, badges, theme contrast test, capture-fit warning, clean bleed edge, and empty-state fix. Council median 7.5 (Opus 7.1, Sonnet 7.6, Fable 7.5), accepted by Geoff (branch feature/pro-framing).
- 2026-11-13 — Chapter 1, pro framing pass: themes and gradient backgrounds, measured device frames, marketing captions, layout templates, and a rebuilt editor. Council median 3.8 → 7.3 (branch feature/pro-framing).
- 2026-09-07 — Implemented and verified the approved Screenshot Builder v1.
- 2026-09-07 — Tightened screenshot composition for short captions.
