# Chapter 4 hands-on checklist

For Geoff. About 25 minutes on either Mac. Each step says what to do and what you should see. Tick a box, or write what you saw instead.

## Set up

1. In the main checkout, the branch is held by the worktree. Build from the worktree: `cd ~/Developer/Screenshot-Builder-ch4 && ./scripts/build-app.sh`, then open `build/Screenshot Builder.app`.
2. Import the five light captures from `~/Documents/Dev Workstation/Visual Verification/screenshot builder/ch4-inputs/light/` (01 to 05), and type a headline on each shot.

## Starter looks (spec R1)

- [x] On the Style tab, the Looks gallery shows six tiles of the selected shot: Orb, Bokeh, Editorial, Scoreboard, Rays, Calm.
- [x] Click **Orb**. The whole set turns near-black with a violet circle behind each phone, a left headline, and the phone running off the bottom.
- [x] Press ⌘Z once. The set returns to how it was before the click.
- [x] Click each other look in turn. Each looks like its model set (Bokeh: EveryPaw, Editorial: Weather in Words, Scoreboard: Offshoots, Rays: AisleWise, Calm: Tucked). Note any look you would not ship.
- [x] After a look, change the text size. The look's tile loses its blue ring.
- [x] Replace one shot's image (right-click in the filmstrip). The gallery tiles show the new image.

## Decorations (spec R3)

- [x] Apply **Orb**. On the Caption tab, type an app name in **App name**. It appears above every headline in the accent color.
- [x] Double-click the eyebrow on the canvas, type a new app name, press Return. Every shot updates. (Not verified by Claude: the Mac was locked when this was tried.)
- [x] Apply **Scoreboard**. Give two shots a section. The labels read "01 — …", "02 — …" in monospace.
- [x] In Set view (⌘2), drag shot 1 to the end. The numbers follow the new order.
- [x] Type a very long app name. It ends in "…", stays in the caption column, and the Caption tab shows an advisory.
- [x] Turn on **Accent shapes**. A pill and a square appear in a top corner and never touch the text or the phone.

## Advanced background and hue shift (spec R2)

- [x] On the Style tab, **Advanced background** under the themes starts closed. Open it: five backdrop tiles, **Shift hue per shot**, then the fill, colors, grain, and flow controls.
- [x] Pick each backdrop. It always sits behind the phone and never covers a caption.
- [x] Pick the Sunset theme and turn on **Shift hue per shot**. The background turns from pink toward yellow across the set.
- [x] Turn on **Flow across the set**. The hue toggle greys out, and its help tag says why.

## Lead and Zoom (spec R4, R5)

- [x] Choose **Lead** in the composition tiles (portrait iPhone). Each shot shows a left caption over a large phone that runs off the bottom.
- [x] Give one Lead shot a long headline (about 60 characters). The set's headlines shrink together, and Export still works.
- [x] Switch to an iPad size. The same tile reads **Side by side** and puts the caption beside the device.
- [x] Set a shot to **Zoom**. The card edge is tinted with the theme accent, and the shadow is softer than in chapter 3. The marker on the phone still reads as a thin outline, not a second card.
- [x] On the List Happens Trips screen (dark sample 04), the Zoom card shows a whole group, not a lone section heading.

## Editor (spec R6)

- [x] The inspector keeps the same width on Caption, Style, and Device, and after leaving Set view.
- [ ] Section headers say **All shots** or **This shot only**. **Greyed Out/Non Selectable. Intent?**
- [x] Decide on the known gap: at 1440 × 920 the Style tab still scrolls (spec R6.4). Keep it, or ask for the shot section to move.

## Old files

- [x] Open `~/Documents/Dev Workstation/Visual Verification/screenshot builder/ch3-check/assets/c2r3src/vary/Sample.shotset` (an older format). It opens with no decorations and no backdrop, and exports. Save it, then reopen it.

## Review questions with no defect found

- [x] Choose a Mac or landscape size with the **Bokeh** look. Check that the accent eyebrow stays readable where a disc sits behind it.
- [x] With an empty section, the eyebrow cannot be double-clicked on the canvas (there is nothing to click). Is the Caption tab field enough?
- [x] When every shot is Lead, the Layout tiles and Alignment change nothing on the canvas. Leave them enabled, or grey them out?

## What only you can judge

- [x] Whether the six looks are a coherent App Store set you would ship, on the light captures and on your dark samples.
- [x] Whether the success sentence is met: "Create a coherent App Store set with less manual adjustment, clearer controls, and stronger Zoom and portrait compositions."
