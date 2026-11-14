# TODO

## Next
- Chapter 3: editor canvas, Zoom quality, iPad scale, Mac frame, and new caption layouts. Spec: `docs/superpowers/specs/2026-11-13-chapter-3-canvas-and-compositions.md`. Updated 2026-11-14 with Geoff's hands-on findings (Zoom marker and drag, real font weights, Mac display-capture fill). Waiting for Geoff's approval.
- iPad acceptance: not tested by Geoff (2026-11-14, no iPad Pro on hand). iPad output can be checked with iPad Pro simulator captures; Geoff's acceptance stays open.

## Backlog
- Highlight menu: typed markup that spans words (for example `*one tap*`) shows unchecked and cannot be cleared from the menu; a word both typed and stored needs two clicks. Found in code review 2026-11-13; low impact because the menu writes single-word accents.
- Outside v1: freeform editing, layers, stickers, AI copy, localization management, and direct upload. These do not serve the initial fixed-layout workflow.

## Done
- 2026-11-14 — Geoff's hands-on check of chapters 1–2 on MacBook Pro (iPhone 6.9 and Mac outputs). Findings folded into the chapter 3 spec; iPad not tested.
- 2026-11-13 — Chapter 2, per-shot layouts: Tilt, Hero, Duo, and Zoom arrangements, Vary layouts, badges, theme contrast test, capture-fit warning, clean bleed edge, and empty-state fix. Council median 7.5 (Opus 7.1, Sonnet 7.6, Fable 7.5), accepted by Geoff (branch feature/pro-framing).
- 2026-11-13 — Chapter 1, pro framing pass: themes and gradient backgrounds, measured device frames, marketing captions, layout templates, and a rebuilt editor. Council median 3.8 → 7.3 (branch feature/pro-framing).
- 2026-09-07 — Implemented and verified the approved Screenshot Builder v1.
- 2026-09-07 — Tightened screenshot composition for short captions.
