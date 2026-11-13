# Screenshot Builder

A native Mac app to frame screenshots, write captions, and export an App Store set.

## Run

Requires macOS 14 or later and Xcode command line tools. Run `./scripts/build-app.sh`, then open `build/Screenshot Builder.app`. Open `Package.swift` in Xcode to edit.

## Workflow

Import PNG or JPEG images, select a size, write captions, and export. Select a thumbnail before dragging it to reorder, or use its context menu. Choose captions above, below, or screenshot only. Overflow warnings block export; low-resolution warnings flag possible softness. Styling applies to the full set. Save a `.shotset` project through the File menu; source images travel with it.

Size presets follow [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) checked on 2026-09-07. Exports use opaque RGB PNGs. A generic frame surrounds the complete capture; it does not imitate a specific device.
