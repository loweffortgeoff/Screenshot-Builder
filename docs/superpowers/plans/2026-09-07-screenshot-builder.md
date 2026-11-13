# Screenshot Builder v1

Approved by Geoff on 2026-09-07. Working name: Screenshot Builder.

## Scope

Native Mac window: thumbnails on the left, preview in the center, captions and shared styling on the right. Import and reorder images; choose named App Store dimensions; caption above, below, or screenshot only; solid colors, system font choices, image scale, optional generic frame. Save projects with source images. Warn about caption overflow and insufficient source resolution. Export ordered PNGs.

## Delivery

1. Complete — import, caption, and export one correctly sized PNG.
2. Complete — shared styles, multiple shots, reordering, and batch export.
3. Complete — document saving, generic device frame, and validation.

## Verification

Built on the MacBook Pro running macOS 27.0 (26A5425a) with Xcode-beta and Swift 6.4. Eight Swift Testing tests passed: project round trip, malformed-project rejection, opaque PNG output, orientation and no-cropping behavior, preset layout geometry, fixed caption-band alignment, warnings, and batch files without overwrite. Inspected the running app with a real capture and verified a two-file 1320x2868 opaque-PNG batch export. Read back the saved example project to confirm its three imported shots, reordered IDs and captions, edited headline, and below layout persisted. Light mode, VoiceOver navigation, and macOS 14 remain manual checks.
