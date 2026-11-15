#!/usr/bin/env python3
"""Turn a square icon render into a macOS .icns on Apple's 824-point art box.

Authoring tool, not part of the build. Needs Pillow.

    ./scripts/make-icon.py build/icon-concepts/matte-02-flat.png

Writes Resources/Matte-1024.png (the master) and Resources/Matte.icns.
The render is scaled slightly past the art box and clipped, so any rim or
corner haze the image generator left behind falls outside the mask.
"""
import math
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

CANVAS = 1024
ART_BOX = 824  # Apple's macOS icon art box inside a 1024 canvas
MARGIN = (CANVAS - ART_BOX) // 2
OVERSIZE = 16  # art bleeds this far past the art box and gets clipped
SUPERELLIPSE = 5.0  # Apple's squircle is close to this
UNDERLAY = (15, 15, 18, 255)  # fills any corner the art does not cover

SIZES = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]


def superellipse_mask(size):
    """A supersampled mask for one squircle of the given size."""
    ss = 4
    big = size * ss
    centre = big / 2
    half = big / 2
    points = []
    for i in range(2048):
        t = 2 * math.pi * i / 2048
        c, s = math.cos(t), math.sin(t)
        x = centre + half * math.copysign(abs(c) ** (2 / SUPERELLIPSE), c)
        y = centre + half * math.copysign(abs(s) ** (2 / SUPERELLIPSE), s)
        points.append((x, y))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def build(source):
    art = Image.open(source).convert("RGBA")
    if art.width != art.height:
        raise SystemExit(f"{source} is not square ({art.width}x{art.height})")

    art_size = ART_BOX + OVERSIZE * 2
    art = art.resize((art_size, art_size), Image.LANCZOS)

    master = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    plate = Image.new("RGBA", (ART_BOX, ART_BOX), UNDERLAY)
    offset = (art_size - ART_BOX) // 2
    plate.alpha_composite(art.crop((offset, offset, offset + ART_BOX, offset + ART_BOX)))

    master.paste(plate, (MARGIN, MARGIN), superellipse_mask(ART_BOX))
    return master


def write_icns(master, icns_path):
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "Matte.iconset"
        iconset.mkdir()
        for name, size in SIZES:
            master.resize((size, size), Image.LANCZOS).save(iconset / name)
        import subprocess
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icns_path)],
                       check=True)


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    source = Path(sys.argv[1])
    out = Path(__file__).resolve().parent.parent / "Resources"
    out.mkdir(exist_ok=True)

    master = build(source)
    master.save(out / "Matte-1024.png")
    write_icns(master, out / "Matte.icns")
    print(f"Wrote {out / 'Matte-1024.png'} and {out / 'Matte.icns'}")


if __name__ == "__main__":
    main()
