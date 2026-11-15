# iPhone Duo device — design

Approved by Geoff 2026-11-15.

## Intent

iPhone Duo is the only App Store device that Matte cannot make screenshots for. Every Low Effort Apps app has Duo screenshots on the App Store, made outside Matte with one-off Python scripts (for example `ASC Screenshots/Tucked/tools/render_duo_screenshots.py`). When an app's UI changes, Geoff must rebuild the Duo set in Matte, like every other device.

## Goals

- An "iPhone Duo" size in the output size menu, 2007 × 2853 (portrait). This matches the live Tucked and Task(ed) Duo sets.
- A drawn iPhone Duo frame, measured from Apple's Duo frame PNGs in `Dev Workstation/App Images/ASC Screenshots/Utility/Frames/iPhone Duo`. Finishes: Night Sky and Star White.
- Each shot picks its fold state and orientation from its capture size:
  - Inner open, portrait: 2007 × 2853
  - Inner open, landscape: 2853 × 2007
  - Outer closed, portrait: 1398 × 2034
  - Outer closed, landscape: 2034 × 1398
- One set can mix open and closed shots, in portrait and landscape.
- Landscape captures sit on the portrait canvas (as in the Tucked set).
- Captions, themes, starter looks, decorations, and backgrounds work as they do on iPhone.

## Non-goals

- A two-iPhones frame. The 2026-11-14 backlog entry described that; it was a misread of the device.
- A landscape output canvas for Duo.
- Duo demo videos.
- A manual fold-state override (capture size decides). Add later only if a real capture needs it.

## Anti-goals

- Do not bundle Apple's frame images. Matte draws every device from measurements (see `DeviceSpec.swift`).
- Do not change the output of existing presets or old `.shotset` files.

## Constraints

- Frame openings in Apple's PNGs match the capture sizes 1:1 (the Tucked script asserts this), so the PNGs give reference-pixel geometry directly.
- The inner open frame is 2247 × 3093 around a 2007 × 2853 opening; the outer closed frame is 1574 × 2194 around 1398 × 2034. Exact insets, corner radii, the hinge or crease, and camera cutouts are measured during the build.
- A capture that matches no Duo shape: fit it to the inner open portrait frame and show the existing capture-fit warning.

## Approaches

1. **Drawn frame from measurements (picked).** Fits how Matte draws every device, supports finishes, and keeps Apple's images out of the app.
2. Bundle Apple's PNG frames. Faster, but breaks the project rule of not bundling Apple images and does not fit the finish system.
3. A two-iPhones frame (the old backlog idea). Not the device Geoff ships on.

## Left to the builder

- How fold state is modeled (a family on `DeviceSpec`, or a spec chosen per shot from the capture).
- Which arrangements fit a landscape Duo shot. Any that do not fit fall back to Stacked, with the existing fallback note.
- Device size and position on the canvas for each of the four shapes; use the Tucked set as the visual reference.
- Project format version bump, if the new preset needs one.
