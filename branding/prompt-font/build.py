#!/usr/bin/env python3
"""Generate cosmic-blue-prompt.ttf, the few symbols of the shell prompt.

COSMIC Terminal spaces lines at 1.4 times the font size, while powerline
arrows from Nerd Fonts are drawn at the font's own height (about 1.2 em), so
filled arrows end up shorter than the colored backgrounds around them. These
glyphs are sized for COSMIC Terminal's cell with its default font, Noto Sans
Mono (advance 600, ascent 1069, descent 293 per 1000 units): the arrow spans
the whole 1.4 em line. The font also holds the cosmic-blue logo mark and the
other prompt icons, so a prompt line only uses these two fonts and keeps the
same baseline.

The glyphs sit in plane 16 private use code points, which Nerd Fonts and
other fonts leave free, so terminals always fall back to this font for them:
  U+10CB00 logo mark   U+10CB01 arrow   U+10CB02 git branch
  U+10CB03 cross       U+10CB04 lock

Needs fontTools. Usage: python3 build.py OUTPUT.ttf
"""
import math
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

UPM, ADVANCE, ASCENT, DESCENT = 1000, 600, 1069, 293
LINE = 1.4 * UPM
# Cell edges around the baseline: the text is centered in the line (top), or
# hangs from its top (bottom), whichever reaches further; plus 15 units so no
# seam shows when the line height is rounded to whole pixels
CELL_TOP = ASCENT + (LINE - ASCENT - DESCENT) / 2 + 15
CELL_BOTTOM = ASCENT - LINE - 15
ICON_Y = 360  # vertical center of the icons: the middle of capital letters


def polygon(pen, points):
    """One contour, clockwise in font coordinates (y up), as TrueType wants."""
    area = sum(x0 * y1 - x1 * y0
               for (x0, y0), (x1, y1) in zip(points, points[1:] + points[:1]))
    if area > 0:
        points = points[::-1]
    pen.moveTo(points[0])
    for p in points[1:]:
        pen.lineTo(p)
    pen.closePath()


def arc(cx, cy, r, a0, a1, steps=48):
    return [(round(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps))),
             round(cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))))
            for i in range(steps + 1)]


def circle(pen, cx, cy, r):
    polygon(pen, arc(cx, cy, r, 0, 360)[:-1])


def stroke(pen, x0, y0, x1, y1, width):
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy)
    ox, oy = -dy / n * width / 2, dx / n * width / 2
    polygon(pen, [(round(x0 + ox), round(y0 + oy)), (round(x1 + ox), round(y1 + oy)),
                  (round(x1 - ox), round(y1 - oy)), (round(x0 - ox), round(y0 - oy))])


def logo(pen):
    """The logo's "orbit c" (branding/logo/build.py), in one color."""
    scale, cx, cy = 8.5, ADVANCE / 2, ICON_Y

    def pt(x, y):  # logo units (y down, -50..50) to font units
        return (cx + x * scale, cy - y * scale)

    # Orbit: from -40 degrees the long way round to +40 degrees (y down),
    # stroke width 13 around radius 40, with round caps
    outer = arc(0, 0, 46.5, -40, -320)
    inner = arc(0, 0, 33.5, -320, -40)
    end = (40 * math.cos(math.radians(-320)), 40 * math.sin(math.radians(-320)))
    start = (40 * math.cos(math.radians(-40)), 40 * math.sin(math.radians(-40)))
    cap_end = arc(end[0], end[1], 6.5, -320, -320 - 180, 16)
    cap_start = arc(start[0], start[1], 6.5, -40 + 180, -40, 16)
    ring = outer + cap_end[1:-1] + inner + cap_start[1:-1]
    polygon(pen, [tuple(round(v) for v in pt(x, y)) for x, y in ring])
    for x, y, r in ((-2, 0, 13), (38, 0, 6.5)):  # planet and moon
        px, py = pt(x, y)
        circle(pen, px, py, r * scale)


# The arrow is wider than its cell, like powerline arrows in terminals with
# tighter lines: its tip reaches into the next cell, which the prompt always
# fills with a space (COSMIC Terminal draws all cell backgrounds first)
ARROW_TIP = 1000


def arrow(pen):
    polygon(pen, [(-15, round(CELL_TOP)), (ARROW_TIP, round((CELL_TOP + CELL_BOTTOM) / 2)),
                  (-15, round(CELL_BOTTOM))])


def branch(pen):
    w = 80
    stroke(pen, 170, 60, 170, 660, w)
    stroke(pen, 450, 600, 450, 450, w)
    stroke(pen, 450, 450, 170, 260, w)
    for x, y in ((170, 40), (170, 680), (450, 640)):
        circle(pen, x, y, 95)


def cross(pen):
    d = 240
    stroke(pen, 300 - d, ICON_Y - d, 300 + d, ICON_Y + d, 110)
    stroke(pen, 300 - d, ICON_Y + d, 300 + d, ICON_Y - d, 110)


def lock(pen):
    polygon(pen, [(110, 20), (110, 400), (490, 400), (490, 20)])
    polygon(pen, arc(300, 400, 160, 0, 180) + [(140, 380), (200, 380)]
            + arc(300, 400, 100, 180, 0) + [(400, 380), (460, 380)])


GLYPHS = {
    ".notdef": (None, None),
    "space": (0x20, None),
    "logo": (0x10CB00, logo),
    "arrow": (0x10CB01, arrow),
    "branch": (0x10CB02, branch),
    "cross": (0x10CB03, cross),
    "lock": (0x10CB04, lock),
}


def main(out):
    fb = FontBuilder(UPM, isTTF=True)
    order = list(GLYPHS)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cp: name for name, (cp, _) in GLYPHS.items() if cp})
    glyphs = {}
    for name, (_, draw) in GLYPHS.items():
        pen = TTGlyphPen(None)
        if draw:
            draw(pen)
        glyphs[name] = pen.glyph()
    fb.setupGlyf(glyphs)
    glyf = fb.font["glyf"]
    for name in order:
        glyf[name].recalcBounds(glyf)
    fb.setupHorizontalMetrics({name: (ADVANCE, getattr(glyf[name], "xMin", 0))
                               for name in order})
    fb.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT)
    fb.setupNameTable({"familyName": "cosmic-blue Prompt", "styleName": "Regular",
                       "uniqueFontIdentifier": "cosmic-blue Prompt Regular",
                       "fullName": "cosmic-blue Prompt Regular",
                       "psName": "cosmic-blue-Prompt-Regular",
                       "copyright": "cosmic-blue contributors, Apache-2.0"})
    fb.setupOS2(version=4, sTypoAscender=ASCENT, sTypoDescender=-DESCENT, sTypoLineGap=0,
                usWinAscent=ASCENT, usWinDescent=DESCENT, fsSelection=0x40 | 0x80,
                xAvgCharWidth=ADVANCE)
    fb.font["OS/2"].panose.bProportion = 9  # monospaced
    fb.setupPost(isFixedPitch=1)
    fb.save(out)


if __name__ == "__main__":
    main(sys.argv[1])
