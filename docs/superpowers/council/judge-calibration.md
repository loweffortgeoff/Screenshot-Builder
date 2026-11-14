# Chapter 4 judge calibration

Chapter 4 replaces Fable as a council judge with one GPT model. This file records the one-time check between `gpt-6.1-sol` and `gpt-6-astra` (both at reasoning high, Codex provider through T3 `delegate_task`). Run on the MacBook Pro, 2026-11-14.

## Pick rules (written before any run)

A judge passes only when all three hold.

1. **It looks at every image.** For each of the 20 input files, it states one specific observation that matches that PNG and that the file name alone does not give away (for example a color, a word in a caption, or a control's state).
2. **Its findings are specific.** Every issue in its top 5 names the file or files it comes from.
3. **It makes no false claim.** No statement contradicts what the image shows. Claude checks each observation and each issue against the PNG.

If both pass, pick the judge with fewer contradicted or vague claims. If they tie, pick Sol (the Sol review recommended it). Scores are recorded for reference and are not used in the pick. If neither passes, stop and ask Geoff.

## Inputs

The chapter 3 round 3 input set (`inputs.md`, 20 slots), rebuilt from `d02e7d7`. The original round 3 PNGs were not kept on this Mac.

- Folder: `~/Documents/Dev Workstation/Visual Verification/screenshot builder/ch4-check/r3-rebuild-d02e7d7/` (the PNGs, the rubric, and the two scripts that built them in `tools/`).
- Source: `git archive d02e7d7` into the session scratchpad, then `scripts/build-app.sh`, `SampleRenderTests` per slot, and `capture-window.sh` plus mouse clicks for the window slots.
- Known differences from the scored set:
  - `set-compositions.png` uses per-shot compositions set with `jq` on the `vary` project (Side by side, Big number with stat "1 tap", Stacked with Zoom, Overlay, Text only). The original `jq` edit was not recorded, so details may differ.
  - The four arrangement singles (`export-tilt`, `-hero`, `-duo`, `-zoom`) come from the List Happens samples with one arrangement on every shot. The originals may have used other shots.

Both judges see the same files, so these differences do not affect the comparison.

## Baseline action count on `main` (`79a6186`)

Goal state: a set that matches the Orb look (Task-ed). Start state: 5 captures imported, captions typed, default style (Ocean theme, System Heavy, centered, Top layout, Stacked).

| # | Action | Matches |
|---|---|---|
| 1 | Style tab, click theme **Noir** | Near-black background |
| 2 | Caption tab, click the **Accent color** well | |
| 3 | Pick violet in the color panel | Violet accent words |
| 4 | Close the color panel | |
| 5 | Click alignment **Left** | Left headline |
| 6 | Style tab, click layout **Bleed** | Phone bleeds off the bottom |

Six actions reach the closest match. Two parts of Orb cannot be made on `main`: the eyebrow label ("TASK(ED)") and the large accent circle behind the phone. The chapter 4 target is 3 actions or fewer for the full look (open the gallery, click Orb, type the app name).

## Results

Both judges ran on 2026-11-14 through T3 `delegate_task` (Codex provider, reasoning high), with the same brief: read the rubric, open all 20 PNGs, write one observation per file, then the rubric output with a file named on each issue. A first run was stopped before it finished, because `export-zoom.png` and `export-zoom-ch3.png` had no Zoom card (the harness needs `SB_ARRANGE=Callout`). Both judges saw the fixed files.

### Can a Codex judge read the PNGs?

Yes. Both judges reported details that only the pixels show. Examples are the 94% size slider (`window-device.png`), the burgundy FREE badge on panel two (`set-varied-sunset.png`), and the "Recent Trips" heading clipped inside the Zoom card (`export-zoom-ch3.png`).

### Check against the pick rules

Claude opened each PNG and checked every observation and every issue.

| Rule | Sol (`gpt-6.1-sol`) | Astra (`gpt-6-astra`) |
|---|---|---|
| 1. One true, specific observation per file | 20 of 20 true. Most name two details (for example "Heavy weight and centered alignment are selected"). Two are generic: "Five blue panels" (`window-set.png`) and "Five upright phones" (`set.png`). | 20 of 20 true. Mostly one detail per file. Two are generic: "Five upright black phones" (`set.png`) and "Ocean theme selected" (`window.png`). |
| 2. Every top-5 issue names a file | 5 of 5 | 5 of 5 |
| 3. No claim the image contradicts | None found | None found |

Both judges pass. Their findings agree on four of five issues: portrait Side by side leaves the upper right empty, the Zoom connector and border are heavy, set-level and shot-level controls overlap, and the grain is visible. Astra adds one precise point: the Zoom crop takes a heading without its rows.

### Pick

**Sol (`gpt-6.1-sol`, reasoning high).** Both judges pass, and their vague-claim counts are about equal. Sol's observations carry slightly more detail per file. Under the tie rule, Sol wins. The scores (Sol 7.4, Astra 7.5) played no part.

### Findings for chapter 4 (not part of the pick)

- The Zoom crop can include a section heading without its rows ("Recent Trips", `export-zoom-ch3.png`). Both judges saw it. The crop should end at the bottom of a whole group, so this belongs to M6 (Zoom card).
- Both judges named the film grain on large gradients. Grain intensity is not in the chapter 4 scope. It goes to the backlog unless the M9 review repeats it.
