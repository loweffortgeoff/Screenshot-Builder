# Council inputs

The UI council (Opus, Sonnet, Fable) reads `council-rubric.md` and every image listed here. The rubric text is also the judge prompt. Do not change it between rounds.

Build every input from one frozen SHA. Record the SHA with the scores.

## Sources

- Captures (never committed): List Happens on the iPhone 18 Pro Max simulator (1320 × 2868), Bookmark-Collections on the iPad Pro 13-inch (M5) simulator (2064 × 2752), and the Screenshot Builder window (1440 × 920). Geoff's 3440 × 1440 full-screen capture covers the Mac display-fill case.
- Slot projects: the chapter 2 final round saved one `.shotset` per set slot (default, vary, span, sunset, ipad, mac). Each project embeds its captures and style, so re-rendering it with a new build reproduces the slot. Chapter 3 keeps these in the worktree's git-ignored `build/assets/c2r3src/`.

## Chapter 2 slots (kept for comparability)

| File | Content |
|---|---|
| `window.png` | Editor window, Style tab, iPhone set. |
| `window-caption.png` | Editor window, Caption tab. |
| `window-device.png` | Editor window, Device tab. |
| `window-empty.png` | Editor window with no shots. |
| `set.png` | iPhone set, all Standard (slot project `default`). |
| `set-varied.png` | iPhone set after Vary layouts, with badges (`vary`). |
| `set-varied-span.png` | Varied set with a spanning background (`span`). |
| `set-varied-sunset.png` | Varied set on a gradient theme (`sunset`). |
| `set-ipad.png` | iPad 13-inch set from iPad captures (`ipad`). |
| `export-mac.png` | Mac export of the app window (`mac`). |
| `export-tilt.png`, `export-duo.png`, `export-zoom.png`, `export-hero.png` | Full-size iPhone singles, one per arrangement. |

## Chapter 3 slots (added 2026-11-14, approved by Geoff)

| File | Content |
|---|---|
| `window-set.png` | Editor in Set view with 5 shots. |
| `window-zoomed.png` | Editor canvas at 100% zoom. |
| `set-compositions.png` | iPhone set mixing Side by side, Big number, Stacked + Zoom, Overlay, and Text only. |
| `export-zoom-ch3.png` | Full-size Zoom single with the spotlight marker and lens connector. |
| `export-mac-window.png` | Mac export in the Window only frame. |
| `export-mac-display.png` | Mac export of the 3440 × 1440 display capture in Fill screen. The capture is Geoff's real full-screen desktop, fixed input: the light strip at the top is its own menu bar, and the light band at the bottom is its desktop wallpaper below the app window. |

## Commands

- Sets and singles: `SB_SAMPLES=<captures> SB_OUT=<folder> [knobs] swift test --filter SampleRenderTests`. The knobs are listed in the README.
- Windows: `scripts/build-app.sh`, then `scripts/capture-window.sh <project> <png>`. Switch tabs and views through System Events and the CGEvent helper before each capture.
