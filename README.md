# Screenshot Builder

A native Mac app to frame screenshots, write captions, and export an App Store set.

## Run

Requires macOS 14 or later and Xcode command line tools. Run `./scripts/build-app.sh`, then open `build/Screenshot Builder.app`. Open `Package.swift` in Xcode to edit.

## Status

Two design chapters are on branch `feature/pro-framing` (not merged). An ad-hoc UI council (Opus, Sonnet, Fable) scored the app 3.8 at v1 and 7.5 after both chapters; Geoff accepted 7.5 on 2026-11-13. Plans are in `docs/superpowers/plans/`; the next chapter is specified in `docs/superpowers/specs/`.

## Review harness

`SB_SAMPLES=<folder of 01.png…> SB_OUT=<folder> swift test --filter SampleRenderTests` renders a sample set, a contact sheet, and a project file. `SB_PROJECT=<file.shotset>` renders a saved project as it is, in place of `SB_SAMPLES`. Optional: `SB_REGION`, `SB_MARKER`, `SB_LENS` (Zoom options, applied to every shot, by raw value such as `Top`, `Outline`, `Line`), `SB_THEME`, `SB_LAYOUT`, `SB_PRESET`, `SB_FINISH`, `SB_FRAME` (`windowOnly` for the bare Mac window), `SB_MACFIT` (`auto`, `fill`, `window`) and `SB_CROP` (0 to 1, which part of a cropped Mac capture shows; both applied to every shot), `SB_SPAN=1`, `SB_LANDSCAPE=1`, `SB_ALIGN`, `SB_FONT`, `SB_ARRANGE` (`vary` or an arrangement name), `SB_CAPTIONS` (a file of `headline|subtitle` lines), `SB_BADGES` (for example `1:New,3:Insights`). `scripts/capture-window.sh <project> <png>` opens a project in the built app and captures its window (needs Screen Recording permission).

## Workflow

Import PNG or JPEG images, select a size, write captions, and export. The filmstrip under the preview shows the whole set as it will export; select a shot there, or right-click it to move, replace, or remove it. Show the sidebar (toolbar button) to drag shots into a new order. The inspector has three tabs: Caption (headline, subtitle, badge, type), Style (layout template, Vary layouts, the selected shot's arrangement, theme, background), and Device (export summary, frame, finish, size, shadow). Output size and orientation are in the toolbar. Each shot can use its own arrangement: Tilt, Hero, Duo (a second screen from another shot), or Zoom (a magnified card of part of the screen). "Vary layouts" assigns a curated mix; "Make uniform" resets it. Use the Highlight menu beside the headline to color words with the theme accent; typed *asterisks* also work. Overflow warnings block export; low-resolution warnings flag possible softness. Styling applies to the full set. Save a `.shotset` project through the File menu; source images travel with it.

Size presets follow [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) checked on 2026-09-07. Exports use opaque RGB PNGs. Device frames are drawn in code from measurements of Apple Design Resources bezels (iPhone 18 Pro and Pro Max, iPad Pro M5, MacBook Air M5), checked on 2026-11-13. No Apple images are bundled. The 5.5-inch home-button frame is an estimate. A device frame clips the capture only to the rounded display corners. On the MacBook, a full-display capture fills the screen, and a window capture floats on a wallpaper.
