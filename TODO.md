# TODO

## Next
- iPhone Duo hands-on check (Geoff): build a real Duo set from new captures and judge it against the live App Store sets. Branch `feature/iphone-duo`, in the main checkout.
- Chapter 4 open call (Geoff): the Style tab still scrolls at 1440 × 920 (spec R6.4 not met). Keep it, or move the shot section to its own place.
- iPad acceptance: not tested by Geoff (2026-11-14, no iPad Pro on hand). iPad output can be checked with iPad Pro simulator captures; Geoff's acceptance stays open.

## Backlog
- Local MCP: explore a local MCP server so Geoff's agents can run the app. Added by Geoff 2026-11-15; exploration only, no scope or version chosen.
- Film grain on large gradients: both GPT judges named it in the chapter 4 calibration (2026-11-14). Outside the chapter 4 scope, and M9 was dropped, so it stays here until Geoff asks.
- Highlight menu: typed markup that spans words (for example `*one tap*`) shows unchecked and cannot be cleared from the menu; a word both typed and stored needs two clicks. Found in code review 2026-11-13; low impact because the menu writes single-word accents.
- Mac fit advisory: when Auto chooses Window, no advisory names that choice (only an explicit Window does). Kept quiet to avoid a warning on every Mac window set. Found in the chapter 3 review, 2026-11-14.
- Editor performance: `PreviewPane` composes the shot in its view body, so a Zoom shot costs about 10 ms per keystroke or drag step (measured 2026-11-14). Cache the layout with the render if typing ever feels slow.
- Zoom narrow crop on a cropped Mac capture: a gap just right of the visible edge could give a thin card. Not reproduced; a reviewer question from 2026-11-14.
- Outside v1: freeform editing, layers, stickers, AI copy, localization management, and direct upload. These do not serve the initial fixed-layout workflow.

## Done
- 2026-11-15 — [x] iPhone Duo device on `feature/iphone-duo`: a 2007 × 2853 size, a drawn open and closed frame measured from Apple's Duo PNGs, and a per-shot frame choice from the capture size. Tucked Duo set rebuilt in Matte for visual acceptance. Not merged.
- 2026-11-14 — Chapter 4 hands-on check passed (Geoff, 29 of 30 items; his question on the scope headers answered: they are labels, not controls). Merged to `main` by fast-forward at `69a6012`; branch and worktree removed.
- 2026-11-14 — Chapter 4 implemented on `feature/chapter-4` (M0 to M8, M10): judge calibration (Sol), Lead, decorations and format 5, backdrops and hue shift, six starter looks, editor polish, Zoom card tint and crop fix; M7 found no frame defects. Code review by code-reviewer and Fable; confirmed bugs fixed in separate commits. M9 (council review) dropped by Geoff.
- 2026-11-14 — Chapter 4 spec and plan approved by Geoff (Q1 B, Q2 keep 1.6×, defaults for Q3 to Q7).
- 2026-11-14 — Chapter 3 hands-on acceptance passed (Geoff). The Set view drag and the Zoom ring fixes are in `fc34097` and `79a6186`. Pinch zoom is not scripted.
- 2026-11-14 — Chapter 3 merged to `main` at `79a6186`. Chapter 4 replaces the score target with a product success sentence (Sol review).
- 2026-11-14 — Chapter 3 implemented (milestones Z, C, E, P, K, N): Zoom quality, fit-to-pane canvas with zoom and Set view, on-canvas editing and drag, real weights, tab craft, iPad fill, Mac fit and Window only, MacBook redraw, five caption compositions, format v4. Code review by code-reviewer and Fable; fixes committed. Council medians 7.3, 7.4, 7.4 (branch feature/chapter-3).
- 2026-11-14 — Geoff's hands-on check of chapters 1–2 on MacBook Pro (iPhone 6.9 and Mac outputs). Findings folded into the chapter 3 spec; iPad not tested.
- 2026-11-13 — Chapter 2, per-shot layouts: Tilt, Hero, Duo, and Zoom arrangements, Vary layouts, badges, theme contrast test, capture-fit warning, clean bleed edge, and empty-state fix. Council median 7.5 (Opus 7.1, Sonnet 7.6, Fable 7.5), accepted by Geoff (branch feature/pro-framing).
- 2026-11-13 — Chapter 1, pro framing pass: themes and gradient backgrounds, measured device frames, marketing captions, layout templates, and a rebuilt editor. Council median 3.8 → 7.3 (branch feature/pro-framing).
- 2026-09-07 — Implemented and verified the approved Screenshot Builder v1.
- 2026-09-07 — Tightened screenshot composition for short captions.
