#!/usr/bin/env python3
"""Draw the mouse-button glyphs used by Cell's Click-Casting Hints bar.

Output: AddOns/Cell/Media/Icons/mouse-{left,right,middle,extra}.png

Run from the Media/Icons folder (save() uses relative names):

    cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/Cell/Media/Icons" \
      && python3 ../../../../.claude/scripts/cell-mouse-icons.py

These are NOT hand-drawn assets. Change the shapes here and re-run; never edit the
PNGs in an image editor, or the next change has no source to start from.

Three constraints drive every shape decision:

1. They render INLINE IN A FONTSTRING at roughly 10-13 px tall, on top of a spell
   icon. That is smaller than the inspect icons and there is no frame around them.
   So: solid silhouette, one white accent, nothing else. Any interior detail turns
   into mush.
2. The background is arbitrary spell art -- bright, dark, busy. A hollow outline
   disappears over pale icons, so the body is a filled dark shape with a white rim;
   the rim is what separates it from the art, and it is deliberately thick.
3. The accent (which button is pressed) has to survive at 10 px. It is a solid white
   block filling a whole quadrant, not a highlight or a tint.

Only four glyphs exist. Scroll wheel and side buttons reuse them with a character
appended by the caller ("wheel + up arrow", "body + 4"), because a distinct glyph
for each would be indistinguishable at this size.
"""

from PIL import Image, ImageChops, ImageDraw

S = 8          # supersample factor; LANCZOS down at the end keeps the edges clean
OUT = 64       # final PNG size
W = OUT * S

WHITE = (255, 255, 255, 255)
DARK = (10, 10, 10, 235)

# The mouse silhouette, in final-image pixels. Taller than it is wide; the caller
# asks for a matching non-square inline size so it is not squashed.
# ⚠ Wider and squarer than a real mouse, and the buttons take up more than half the
# body. Both are deliberate: at 13 px the glyph is only ~10 px across, so a faithful
# slim silhouette leaves each button about 3 px wide and "which side is white" stops
# being readable -- which is the entire job of these icons.
BODY = (10, 6, 54, 58)
RIM = 2.5          # white rim thickness
TOP_R = 21         # corner radius (the palm end sets it; the shape is a lozenge)
SPLIT_Y = 34       # where the buttons stop and the body begins
ACCENT_R = 18      # matches the body corner minus the rim + inset


def _rr(draw, box, radius, fill, corners=None):
    x0, y0, x1, y1 = (v * S for v in box)
    draw.rounded_rectangle((x0, y0, x1, y1), radius=radius * S, fill=fill, corners=corners)


def _body(draw):
    """White rim, then the dark body inset into it."""
    x0, y0, x1, y1 = BODY
    _rr(draw, (x0 - RIM, y0 - RIM, x1 + RIM, y1 + RIM), TOP_R + RIM, WHITE)
    _rr(draw, (x0, y0, x1, y1), TOP_R, DARK)


def _accent(draw, which):
    """Fill one button area white. `which` is left / right / middle / None.

    ⚠ The accent fills the WHOLE quadrant and is squared off on the inner edge. An
    inset pill looked fine at 4x and turned into an unreadable dot at 13 px -- at this
    size the only thing that carries "which button" is a large block of white on one
    side, so the block has to run all the way to the rim.

    Drawn as a plain rectangle that deliberately OVERSHOOTS the body: glyph() clips it
    to the body silhouette afterwards. Trying to round the outer corner to match the
    body by hand left a square corner poking through the white rim.
    """
    x0, y0, x1, y1 = BODY
    mid = (x0 + x1) / 2
    seam = 1.2
    over = 4

    if which == "left":
        _rr(draw, (x0 - over, y0 - over, mid - seam, SPLIT_Y), 0, WHITE)
    elif which == "right":
        _rr(draw, (mid + seam, y0 - over, x1 + over, SPLIT_Y), 0, WHITE)
    elif which == "middle":
        _rr(draw, (mid - 4.5, y0 + 3, mid + 4.5, SPLIT_Y - 2), 4.5, WHITE)


def glyph(name, which):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    _body(ImageDraw.Draw(img))

    if which:
        acc = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        _accent(ImageDraw.Draw(acc), which)
        # clip to the dark inner body, so the accent can never cross the rim
        clip = Image.new("L", (W, W), 0)
        _rr(ImageDraw.Draw(clip), BODY, TOP_R, 255)
        acc.putalpha(ImageChops.multiply(acc.getchannel("A"), clip))
        img.alpha_composite(acc)

    img = img.resize((OUT, OUT), Image.LANCZOS)
    img.save(name)
    print("wrote", name)


if __name__ == "__main__":
    glyph("mouse-left.png", "left")
    glyph("mouse-right.png", "right")
    glyph("mouse-middle.png", "middle")
    glyph("mouse-extra.png", None)
