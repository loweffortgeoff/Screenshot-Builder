# Screenshot Builder

A native Mac app to frame screenshots, write captions, and export an App Store set.

## Run

Requires macOS 14 or later and Xcode command line tools. Run `./scripts/build-app.sh`, then open `build/Screenshot Builder.app`. Open `Package.swift` in Xcode to edit.

## Review harness

`SB_SAMPLES=<folder of 01.png…> SB_OUT=<folder> swift test --filter SampleRenderTests` renders a sample set, a contact sheet, and a project file. Optional: `SB_THEME`, `SB_LAYOUT`, `SB_PRESET`, `SB_FINISH`, `SB_FRAME`, `SB_SPAN=1`, `SB_LANDSCAPE=1`, `SB_ALIGN`, `SB_FONT`. `scripts/capture-window.sh <project> <png>` opens a project in the built app and captures its window (needs Screen Recording permission).

## Workflow

Import PNG or JPEG images, select a size, write captions, and export. The filmstrip under the preview shows the whole set as it will export; select a shot there, or right-click it to move, replace, or remove it. Show the sidebar (toolbar button) to drag shots into a new order. The inspector has three tabs: Caption (headline, subtitle, type), Style (layout template, theme, background), and Device (output size, frame, finish). Use the Highlight menu beside the headline to color words with the theme accent; typed *asterisks* also work. Overflow warnings block export; low-resolution warnings flag possible softness. Styling applies to the full set. Save a `.shotset` project through the File menu; source images travel with it.

Size presets follow [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) checked on 2026-09-07. Exports use opaque RGB PNGs. Device frames are drawn in code from measurements of Apple Design Resources bezels (iPhone 18 Pro and Pro Max, iPad Pro M5, MacBook Air M5), checked on 2026-11-13. No Apple images are bundled. The 5.5-inch home-button frame is an estimate. A device frame clips the capture only to the rounded display corners. On the MacBook, a full-display capture fills the screen, and a window capture floats on a wallpaper.
