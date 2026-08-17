"""Draw the Passages app icon at every size iOS 12 asks for.

The icon has one job at 60x60 on a home screen: say "a passage, marked". So it
is three muted text lines and one bright band, and nothing else -- no page
outline, no book, no fold. Detail below about 4 px of stroke weight turns to
mush at icon size, and a page outline costs a lot of pixels to say something
the shape of the icon already implies.

Drawn at 8x and downsampled (LANCZOS) rather than drawn at final size: PIL has
no antialiased rectangle fill, and at 60 px the difference between an aliased
and a resampled edge is the difference between "sharp" and "cheap".

    python Tools/generate_icon.py

Writes into Resources/Assets.xcassets/AppIcon.appiconset/.
"""
from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "Resources", "Assets.xcassets",
                   "AppIcon.appiconset")

SS = 8  # supersample factor

INK = (26, 36, 31)        # ground -- near-black with green in it, not grey
LINE = (108, 122, 113)    # unread text: present, deliberately recessive
MARK = (232, 176, 74)     # the marked passage; the only saturated thing here
MARK_TEXT = (32, 28, 18)  # text sitting on the mark

# Every size iOS 12 wants, as (points, scale) -> pixels.
SIZES = [
    ("iphone", 20, 2), ("iphone", 20, 3),
    ("iphone", 29, 2), ("iphone", 29, 3),
    ("iphone", 40, 2), ("iphone", 40, 3),
    ("iphone", 60, 2), ("iphone", 60, 3),
    ("ipad", 20, 1), ("ipad", 20, 2),
    ("ipad", 29, 1), ("ipad", 29, 2),
    ("ipad", 40, 1), ("ipad", 40, 2),
    ("ipad", 76, 1), ("ipad", 76, 2),
    ("ipad", 83.5, 2),
    ("ios-marketing", 1024, 1),
]


def draw(px):
    """Render the icon at `px` pixels square."""
    n = px * SS
    img = Image.new("RGB", (n, n), INK)
    d = ImageDraw.Draw(img)

    # Five text lines on a 1024-unit grid, the third one marked. Ragged right
    # edges -- equal-length lines read as a barcode, not as prose.
    u = n / 1024.0
    left, rows = 208 * u, [286, 396, 506, 616, 726]
    widths = [608, 560, 608, 528, 384]
    h, r = 46 * u, 23 * u

    for i, (y, w) in enumerate(zip(rows, widths)):
        y0, x1 = y * u, left + w * u
        if i == 2:
            # A solid band, not a band with the text drawn on top of it. The
            # first version drew dark text inside the mark, which is literally
            # correct and visually wrong: at 40 px the dark centre reads as a
            # hollow input field. A filled bar the same colour throughout is
            # unambiguous at every size, and the overshoot past the other
            # lines -- the way a highlighter runs past the words -- is what
            # carries the meaning.
            d.rounded_rectangle([left - 34 * u, y0 - 26 * u, x1 + 34 * u,
                                 y0 + h + 26 * u], radius=30 * u, fill=MARK)
        else:
            d.rounded_rectangle([left, y0, x1, y0 + h], radius=r, fill=LINE)

    return img.resize((px, px), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    images, cache = [], {}

    for idiom, pt, scale in SIZES:
        px = int(round(pt * scale))
        name = f"icon-{px}.png"
        if px not in cache:
            draw(px).save(os.path.join(OUT, name))
            cache[px] = name
        images.append({
            "idiom": idiom,
            "size": f"{pt:g}x{pt:g}",
            "scale": f"{scale}x",
            "filename": cache[px],
        })

    with open(os.path.join(OUT, "Contents.json"), "w", encoding="utf-8") as fh:
        json.dump({"images": images,
                   "info": {"version": 1, "author": "xcode"}}, fh, indent=2)

    print(f"{len(cache)} unique sizes -> {OUT}")


if __name__ == "__main__":
    main()
