# Chapter 3 council results

Judges: Opus, Sonnet, Fable (`general-purpose` agents, one message per round). Rubric: `council-rubric.md`, unchanged. Inputs: the 20 slots in `inputs.md`, built from the frozen SHA on the MacBook Pro (macOS 27.2, Xcode 27.2). Pass bar: median ≥ 8.0. Cap: 3 rounds, then ask Geoff.

Criteria: 1 output polish · 2 color and background · 3 typography and composition · 4 device frames · 5 editor UX · 6 editor craft · 7 competitiveness.

| Round | SHA | Judge | 1 | 2 | 3 | 4 | 5 | 6 | 7 | Overall |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `60659d2` | Opus | 8 | 7 | 8 | 8 | 7 | 7 | 7 | 7.5 |
| 1 | `60659d2` | Sonnet | 7 | 6 | 7 | 8 | 7 | 7 | 6 | 7.0 |
| 1 | `60659d2` | Fable | 7 | 8 | 8 | 7 | 7 | 7 | 7 | 7.3 |
| | | **Median** | | | | | | | | **7.3** |
| 2 | `5f104f9` | Opus | 7 | 7 | 8 | 8 | 7 | 7 | 7 | 7.4 |
| 2 | `5f104f9` | Sonnet | 7 | 7 | 7 | 7 | 8 | 7 | 7 | 7.3 |
| 2 | `5f104f9` | Fable | 7.5 | 7.5 | 7.5 | 8 | 7.5 | 7 | 7 | 7.4 |
| | | **Median** | | | | | | | | **7.4** |
| 3 | `d02e7d7` | Opus | 7.5 | 7.5 | 7 | 8 | 7 | 7.5 | 7.5 | 7.4 |
| 3 | `d02e7d7` | Sonnet | 7 | 7 | 7 | 7 | 8 | 7 | 7 | 7.3 |
| 3 | `d02e7d7` | Fable | 8 | 7 | 8 | 7 | 8 | 8 | 7 | 7.6 |
| | | **Median** | | | | | | | | **7.4** |

For comparison: chapter 2 final (`02f969c`) scored Opus 7.1, Sonnet 7.6, Fable 7.5, median 7.5 (accepted by Geoff on 2026-11-13).

## Input changes between rounds

- Round 2: the `export-mac-display.png` row in `inputs.md` gained one sentence saying the capture's light strips are its own menu bar and wallpaper. All three round 1 judges had read them as letterbox bands. The note did not change the finding in rounds 2 or 3.
- The composition set comes from the chapter 2 `vary` project with compositions set by `jq` (stat "1 tap"). It is the same in all rounds.

## Fixes between rounds

- After round 1 (`b019ebe`, `4b60cb3`): Zoom uses the largest device the 1.6× floor allows and grows its auto band; Side by side on portrait iPhone keeps the phone inside and grounded; Text only at 2.2× with an accent bar; the per-shot picker is named "This shot".
- After round 2 (`17804a0`, `d02e7d7`): Set view takes the full width; Side by side uses a deliberate 16% bottom bleed; the Text only bar is removed; the Zoom marker gains a soft accent halo and the card a stronger shadow.

## Findings still open after round 3 (repeated by two or more judges)

1. Side by side on portrait iPhone does not read as side by side (all three). The spec's numbers do not close at this size: a 0.42 W text column and a 0.62 H device need about 1.07 W.
2. The Mac Fill screen export shows the capture's own menu bar and wallpaper, with small detail (Opus, Sonnet; the capture is fixed input).
3. The Zoom callout: a thin marker, dead space under the card, and a heavy card stroke (Opus, Fable). R1.6 limits the marker stroke; the 1.6× floor and 0.24 band cap limit the device size.
4. Big number repeats the headline (Opus, Sonnet; partly the sample copy).
5. Editor: Composition is a pop-up menu while Layout and Arrangement are tiles; the inspector width changes after Set view (Opus, Sonnet).
6. Range: one sans, gradient and mesh backgrounds only (Sonnet, Fable).
