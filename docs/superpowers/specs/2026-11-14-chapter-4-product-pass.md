# Screenshot Builder chapter 4 spec: starter looks and a product pass

Status: Draft, awaiting Geoff's approval. Written 2026-11-14 on the MacBook Pro (macOS 27.2, Xcode 27.2) from `main` at `79a6186`.
Inputs: Geoff's note "Chapter 4 - Screenshot Builder" (section "Revised proposed scope"), the project memory `chapter-4-spec-inputs`, `docs/superpowers/council/` (rubric, inputs, chapter 3 results), and Geoff's six App Store sets.
Plan: `docs/superpowers/plans/2026-11-14-chapter-4-product-pass.md`.

## Why

Chapter 3 held at a council median of 7.4 for three rounds. Geoff accepted a separate review (Sol) that says the score is not the goal. Chapter 4 is a product pass. It makes the app produce sets like Geoff's own App Store sets with fewer manual steps.

Geoff's six sets share one pattern. An eyebrow label sits above a left-aligned headline. A large phone bleeds off the bottom. One decorative layer sits behind the phone. Each set is, in effect, a named recipe. Chapter 4 turns those recipes into starter looks, and the parts of each recipe into controls a user can change.

## Success

Geoff's success sentence: "Create a coherent App Store set with less manual adjustment, clearer controls, and stronger Zoom and portrait compositions."

There is no score target. Each clause has one observable check. Geoff decides when the sentence is met. One council round runs at the end, and then the chapter stops.

| Clause | Check |
|---|---|
| Coherent set | Each of the 6 looks, applied to the dark sample set and to the light sample set, renders 5 shots with no overflow, contrast, or low-resolution issue (unit test over every look and both input sets). Geoff looks at the 12 contact sheets and calls each set coherent or not. |
| Less manual adjustment | Count the inspector actions from "5 captures imported, captions typed" to a set that matches one reference look (Orb, modelled on Task-ed). Measure on `main` first (milestone M0), then on the branch. Typing the app name counts as one action on the branch. `main` has no eyebrow or backdrop, so its count covers only what `main` can match (theme, font, weight, alignment, layout) and lists what it cannot. Pass when the branch needs at most 3 actions (open the gallery, click the look, type the app name). |
| Clearer controls | No pop-up menu remains for Composition. The inspector keeps one width across all tabs and after Set view (window captures). With the advanced background section closed, the Style tab fits a 1440 × 920 window without scrolling. Set-level and shot-level controls sit under separate headers. |
| Stronger Zoom | Depends on decision Q1. At least, the card follows the theme, and the R1.6 marker check still passes. No Zoom finding repeats across two or more judges in the review. |
| Stronger portrait | On portrait iPhone, no shot uses the old Side by side geometry. The new Lead composition device is at least 0.80 × canvas width. No "does not read as side by side" finding in the review. |

The first chapter 4 council round is a new baseline. A new judge replaces Fable, so the score does not compare with chapters 1 to 3.

## Scope

In scope, in Geoff's order.

1. Starter looks gallery (R1).
2. Advanced background menu with one decorative layer and an optional per-shot hue shift (R2).
3. Decorations placed by the layout: an eyebrow label, an accent rule, and small shapes (R3).
4. A portrait iPhone composition that replaces forced Side by side (R4).
5. A lighter, theme-tinted Zoom card. Geoff decides (Q1, Q2).
6. Editor polish (R6).
7. Frame work for specific visible defects only (R7).
8. One review, then stop (R8).

Out of scope: photo backgrounds, more caption fonts, frame realism (side walls, reflections), freeform layers and stickers, AI copy, localization, and direct upload. The one font exception is a monospace eyebrow for the Scoreboard look, if Geoff accepts Q5.

Every `.shotset` file, versions 1 to 4, still opens. It renders the same as on `main`, with one exception. A version 4 file with Side by side on portrait iPhone renders with the new Lead geometry (R4.3).

## Data shape

Chapter 4 adds two set-level values and one shot-level value. Project format becomes version 5. Every new key decodes with a default, as in versions 2 to 4.

```swift
struct Backdrop: Codable, Equatable {        // SetStyle.backdrop
    var kind: BackdropKind = .none            // none, orb, bokeh, arcs, rays
    var hueShift = false                      // per-shot hue steps across the set
}

struct Decor: Codable, Equatable {            // SetStyle.decor
    var eyebrow: EyebrowMode = .off           // off, appName, section, numbered
    var appName = ""                          // set-level text for .appName
    var monoEyebrow = false                   // only if Q5 is accepted
    var rule = false                          // short accent rule
    var shapes = false                        // small accent shapes
}

// Shot.eyebrow: String = ""                  // section label for .section and .numbered
```

An eyebrow with empty text draws nothing. The set reserves the eyebrow row only when at least one shot draws an eyebrow. The App name field shows the placeholder "App name", so the user sees what is missing.

A starter look is a value in a registry, not stored state.

```swift
struct Look: Identifiable {
    let name: String                          // "Orb", "Bokeh", ...
    let apply: (inout SetStyle, inout [Shot]) -> Void
}
```

A look writes into `SetStyle` and clears per-shot composition overrides. The project does not store which look the user picked. The gallery marks a look as current when the style equals the look's output.

## Requirements

### R1. Starter looks gallery

| ID | Requirement | How to check |
|---|---|---|
| R1.1 | The Style tab opens with a **Looks** row: 6 tiles (Orb, Bokeh, Editorial, Scoreboard, Rays, Calm). Each tile is a live thumbnail of the selected shot with that look, rendered by the shared renderer. | Window capture of the Style tab. |
| R1.2 | Clicking a tile applies the look to the whole set in one step. One Undo reverts it. | Unit test: apply, then undo, gives the old document. Live check through the app. |
| R1.3 | A look **overwrites** theme colors and background, font, weight, text size, alignment, caption layout, set composition, backdrop, and decor (except `appName`). It **clears** each shot's own composition. It **keeps** captions, eyebrow text, badges, stats, arrangements, Zoom settings, the device, frame, finish, preset, orientation, and `appName`. | Unit test per look over a document with every kept field set. |
| R1.4 | Every look writes composition Stacked, layout Bleed bottom, and alignment Left. That is the Lead shape (R4) on portrait iPhone, and it is a valid left-aligned bleed on iPad and landscape. Looks never write Side by side, so iPad and landscape never get true Side by side from a look. On Mac, Bleed bottom keeps the chapter 3 Mac rules for the laptop. | Render each look on phone69, pad13, and mac. No issue in `ShotRenderer.issues`. |
| R1.5 | Every look passes the 3:1 large-text contrast test on every background stop, including hue-shifted stops (R2.4). | Unit test over all looks. |
| R1.6 | If the user changes any value after applying a look, the tile loses its "current" mark. Nothing else happens. | Unit test on `Look.matches(style)`. |

The recipes below come from Geoff's sets. Every look uses Stacked, Bleed bottom, and Left (R1.4). Each look's colors are a theme in `Theme.all`, so the theme swatch row shows a selection after a look is applied. Five themes are new (Q6).

| Look | Model | Theme | Type | Backdrop | Decor |
|---|---|---|---|---|---|
| Orb | Task-ed | Violet (new, near-black with a violet accent) | System, Heavy | Orb | Eyebrow app name |
| Bokeh | EveryPaw | Coral (new, warm graphite with a coral accent) | Rounded, Bold | Bokeh | Shapes, rule |
| Editorial | Weather in Words | Ember (new, warm dark gradient) | Serif, Bold | Arcs, hue shift on | Eyebrow section, rule |
| Scoreboard | Offshoots | Field (new, flat olive with a lime accent) | System, Heavy | None | Eyebrow numbered (mono if Q5) |
| Rays | AisleWise | Noir with an orange accent, as a new theme Amber | System, Heavy | Rays | Eyebrow section, rule before it |
| Calm | Tucked | Mist (new, flat pale blue) | System, Bold | None | Eyebrow app name in accent |

Rays makes the sixth new theme, so the count is six (Violet, Coral, Ember, Field, Amber, Mist).

### R2. Advanced background menu

| ID | Requirement | How to check |
|---|---|---|
| R2.1 | Under the theme swatches, a closed disclosure named **Advanced background** holds the backdrop picker (None, Orb, Bokeh, Arcs, Rays, as small tiles) and a **Shift hue per shot** toggle. Closed by default, so the default Style tab stays short. | Window capture, closed and open. |
| R2.2 | A backdrop is one layer between the background fill and the device. The layout places it. The user does not drag it. Orb is one large accent circle behind the device's upper edge, offset to the side away from the caption. Bokeh is 3 to 5 soft blurred discs in accent and foreground tints. Arcs are 3 thin concentric arcs from one top corner. Rays are 12 to 16 thin wedges radiating from behind the device. | Render each backdrop on phone69 Standard, Lead, Tilt, Duo, and Zoom. The layer never draws over the device, the caption, or the Zoom card. |
| R2.3 | Backdrop colors come from the theme accent and foreground at fixed low opacities. Arcs and rays stay below 25% opacity, so text over them keeps its contrast. | Unit test: the contrast test samples the backdrop color under the caption rect. |
| R2.4 | Hue shift applies at render time only. Stored colors do not change, so `SetStyle.theme` still matches. Shot `i` of `n` rotates the background stops by `(i - (n - 1) / 2) × 10°`, capped at ±30°. If a shifted stop fails the contrast test, the shift for that shot steps down by 5° until it passes. | Unit test: stored style unchanged after render; every shifted shot passes contrast. |
| R2.5 | **Span set** and hue shift do not combine. When Span set is on, the hue toggle is disabled with a help tag ("Span set joins neighbours; hue shift would break the seam"). Backdrops draw per shot, also when Span set is on. | Unit test on the effective value. Window capture. |

### R3. Decorations placed by the layout

| ID | Requirement | How to check |
|---|---|---|
| R3.1 | **Eyebrow.** A small label above the headline: uppercase, tracked +8%, 0.36 × headline size, accent color. Modes are Off, App name (from `Decor.appName`, a field on the Caption tab), Section (from `Shot.eyebrow`), and Numbered ("01 — " plus the shot's section text, or just "01"). | Render check. Unit test of the label text per mode. |
| R3.2 | Any eyebrow in a set reserves the eyebrow row on every shot, as the badge row does, so headlines stay aligned. | Extend the caption band tests. |
| R3.3 | Numbered labels follow the set order. Reordering the set renumbers them. No stored number exists. | Unit test: reorder, then read the labels. |
| R3.4 | The eyebrow is editable on the canvas by double-click, as the headline is. App name edits write `Decor.appName`; Section and Numbered edits write `Shot.eyebrow`. | Live check in the app. |
| R3.5 | **Accent rule.** A short accent bar, 0.9 × headline size wide and 0.08 × headline size thick. With an eyebrow, it sits before the eyebrow on the same line. Without an eyebrow, it sits under the subtitle. It follows the caption alignment. | Render check. Text only keeps no bar (chapter 3 decision), so Text only shots skip the rule. |
| R3.6 | **Shapes.** One pill and one rounded square, in accent and foreground at 70% opacity, in the caption-side top corner, clear of the text by at least one margin. They hide when the caption rect leaves less room than the shape box. | Unit test: shape rects never intersect caption, device, or card rects. |
| R3.7 | Decorations apply to every composition except Text only (eyebrow kept, rule and shapes off) and Overlay (eyebrow inside the band, shapes off). | Render check of the composition set. |

### R4. Portrait iPhone composition: Lead

| ID | Requirement | How to check |
|---|---|---|
| R4.1 | On portrait phone presets, the Side by side tile becomes **Lead**: caption top-left over a large phone that bleeds off the bottom. Its geometry is Stacked with left alignment and the Bleed bottom layout, whatever the set layout says. The device is at least 0.80 × canvas width. | Unit test on the composed device rect. A prototype render with Bleed bottom and Left on `main` already shows this shape (plan, Appendix A). |
| R4.2 | On iPad, landscape, and Mac, Side by side keeps its chapter 3 geometry. | Existing Side by side tests still pass. |
| R4.3 | A version 4 file with Side by side on portrait iPhone opens and renders as Lead. This is the only rendering change for old files. Vary layouts needs no change: its "Side by side + Standard" pair becomes Lead on portrait phones. | Unit test on a version 4 fixture. |
| R4.4 | Lead keeps the set's caption band rules, so Lead shots and Stacked shots with the same caption length start on one baseline. | Extend `CaptionBand` tests. |

### R5. Zoom card (Geoff's decision)

This touches Geoff's H1 finding (the marker must not read as a second card), so it waits for Q1 and Q2. The plan schedules Zoom last among the feature milestones, so no other work waits on the answer.

Fixed facts from the code: the card border is `0.0034 × unit` (`ShotRenderer.cardBorder`). The marker stroke is `0.35 × border` (`markerStrokeWidth`), and R1.6 requires at most 40%. A thinner border therefore also thins the marker, which judges already called a hairline.

The approved option becomes R5.1 to R5.n when Geoff answers.

### R6. Editor polish

| ID | Requirement | How to check |
|---|---|---|
| R6.1 | Composition uses tiles like Layout and Arrangement, with an icon per composition. The pop-up menu goes. | Window capture. |
| R6.2 | The inspector has one fixed width across tabs and after Set view. | Window captures before and after Set view; the inspector width matches to the point. |
| R6.3 | The Style tab has two headed groups: **Set** (Looks, theme, Advanced background, layout, composition, Vary layouts) and **This shot** (composition override, arrangement, Mac fit). | Window capture. |
| R6.4 | With Advanced background closed, the Style tab fits at 1440 × 920 without scrolling. | Window capture. |
| R6.5 | The Caption tab gains the eyebrow controls (mode picker, App name field, this shot's section field) in one row group. | Window capture. |

### R7. Frame defects only

Fix only defects that Geoff's 2026-11-14 framing-test exports or the review show, each with its export file named. No new realism work. If no specific defect is found, R7 is empty.

### R8. One review, then stop

- Judges: Opus, Sonnet, and the GPT judge that the calibration picks (plan, milestone M0). Fable is advisor and code reviewer only.
- Rubric: `council-rubric.md`, unchanged.
- Inputs: a new chapter 4 input list (plan, milestone M9). It keeps the dark samples and adds the light AisleWise captures. Each slot names its source folder, so Geoff can swap in better Mac and light captures without changing the list.
- One round. Fix only findings that two or more judges repeat and that fall inside this scope. Then stop and give Geoff the success checks.

## Open questions for Geoff

Each question has a recommended default. If Geoff approves the spec without answering Q3 to Q7, the default applies. Q1 and Q2 have no silent default, because they touch H1. M6 waits for Geoff's explicit answer, and no other milestone depends on it.

**Q1. Zoom card treatment (touches H1).** Which option?
- A. No change. The card stays white with its current border.
- **B. (Recommended.)** Theme-tinted card. The border becomes a tint between white and the accent, at the same width. The shadow becomes softer (alpha 0.40 to 0.28). The lens connector takes the same tint. The marker stays at its current width, so R1.6 (marker at most 40% of the border) is unchanged.
- C. B with a thinner border (0.0034 to 0.0024 × unit) and the marker kept at its current absolute width. The marker becomes 50% of the border, so R1.6 changes from 40% to 50%. The card looks lighter, and the marker could start to read as a second outline.
- D. B with a stronger marker (stroke 0.35 to 0.5 × border, R1.6 to 50%). This answers the "hairline" finding but moves toward the H1 risk.

**Q2. Zoom placement limits.** Keep the 1.6× magnification floor and the 0.24 crop band cap (recommended), or relax the floor to 1.5× on portrait iPhone so the device can grow and the dead space under the card shrinks?

**Q3. Portrait name and old files.** Recommended: the tile reads "Lead" on portrait phones, and old portrait Side by side shots re-render as Lead. Alternative: keep the old geometry as a seventh composition.

**Q4. What a look changes.** Recommended: R1.3 (style yes, captions and arrangements no). Alternative: a look also runs Vary layouts, so it changes arrangements too.

**Q5. Scoreboard eyebrow font.** Recommended: allow the system monospace face (SF Mono, ships with macOS) for the eyebrow only. This is the one font addition. Alternative: Scoreboard uses the caption font for its eyebrow.

**Q6. New themes.** Recommended: add six themes, one per look, so the looks match Geoff's sets and the swatch row stays selected (Violet, Coral, Ember, Field, Amber, Mist). They also appear in the theme swatches, which grow from 14 to 20. Alternative: map the looks to the nearest existing themes (Noir, Graphite, Sky), and accept that a look's accent then differs from Geoff's sets.

**Q7. Council panel.** Recommended: Opus, Sonnet, and the calibrated GPT judge. Fable advises and reviews code. Alternative: GPT judge plus Opus only.
