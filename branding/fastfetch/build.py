#!/usr/bin/python3
"""Render the cosmic-blue logo as terminal art for fastfetch.

Writes system_files/usr/share/ublue-os/fastfetch/cosmic-blue-{dark,light}.txt
(24-bit color block characters, shown by `fastfetch` through ublue-fastfetch).
The light version darkens the moon and the planet highlight, which would
vanish on a light terminal background.

Each terminal cell gets the block character whose shape best matches the
logo's coverage of the cell, in the mean color of the covered pixels. Unicode
has "lower" and "left" eighth blocks but no "upper" or "right" ones: those
are drawn as a lower/left block in reverse video (the glyph in the terminal
background, the cell in the logo color), so bottom and right edges are as
smooth as top and left ones. Edges are hard, so the art shows no dark fringe
on any terminal background.

Needs rsvg-convert (librsvg) and python3-pillow:
    python3 branding/fastfetch/build.py
"""

import pathlib
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOGO = ROOT / "branding/logo/cosmic-blue-logo.svg"
OUT = ROOT / "system_files/usr/share/ublue-os/fastfetch"
# Terminal cells are about twice as high as wide: 40x20 cells is a square.
COLS, ROWS = 40, 20
# Sub-pixels per cell (8 wide, 16 high: square pixels)
CW, CH = 8, 16
SUPERSAMPLE = 4
# Colors of the mark that are too pale for a light background
LIGHT_SWAPS = {"#e6f3ff": "#1d47c4", "#cfeeff": "#4f98f5"}

LOWER = " ▁▂▃▄▅▆▇█"  # LOWER[k]: bottom k/8 filled
LEFT = " ▏▎▍▌▋▊▉█"  # LEFT[k]: left k/8 filled
QUADRANTS = {  # (top-left, top-right, bottom-left, bottom-right)
    "▘": (1, 0, 0, 0), "▝": (0, 1, 0, 0), "▖": (0, 0, 1, 0), "▗": (0, 0, 0, 1),
    "▀": (1, 1, 0, 0), "▄": (0, 0, 1, 1), "▌": (1, 0, 1, 0), "▐": (0, 1, 0, 1),
    "▚": (1, 0, 0, 1), "▞": (0, 1, 1, 0),
    "▛": (1, 1, 1, 0), "▜": (1, 1, 0, 1), "▙": (1, 0, 1, 1), "▟": (0, 1, 1, 1),
}


def shapes():
    """(character, reverse video, mask) for every candidate, mask[y][x]."""
    out = []
    for k in range(1, 8):
        rows = round(k * CH / 8)
        lower = [[y >= CH - rows] * CW for y in range(CH)]
        out.append((LOWER[k], False, lower))
        # Upper (8-k)/8: lower k/8 block in reverse video
        out.append((LOWER[k], True, [[not v for v in row] for row in lower]))
        left = [[x < k for x in range(CW)] for _ in range(CH)]
        out.append((LEFT[k], False, left))
        out.append((LEFT[k], True, [[not v for v in row] for row in left]))
    for char, (tl, tr, bl, br) in QUADRANTS.items():
        mask = [[bool((tl, tr, bl, br)[(y >= CH // 2) * 2 + (x >= CW // 2)])
                 for x in range(CW)] for y in range(CH)]
        out.append((char, False, mask))
    return out


SHAPES = shapes()


def rasterize(svg: str) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        svg_file = pathlib.Path(tmp, "logo.svg")
        png_file = pathlib.Path(tmp, "logo.png")
        svg_file.write_text(svg)
        w, h = COLS * CW * SUPERSAMPLE, ROWS * CH * SUPERSAMPLE
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h),
                        str(svg_file), "-o", str(png_file)], check=True)
        image = Image.open(png_file).convert("RGBA")
        image.load()
    # Box filter down to sub-pixels: alpha is the coverage
    return image.resize((COLS * CW, ROWS * CH), Image.BOX)


def cell(image: Image.Image, cx: int, cy: int) -> str:
    px = image.load()
    pixels = [[px[cx * CW + x, cy * CH + y] for x in range(CW)] for y in range(CH)]
    covered = [[p[3] >= 128 for p in row] for row in pixels]
    count = sum(map(sum, covered))
    # Slivers under 1/8 of the cell are left out, cells over 7/8 are full
    if count < CW * CH / 8:
        return " "
    if count > CW * CH * 7 / 8:
        char, reverse, mask = "█", False, [[True] * CW for _ in range(CH)]
    else:
        best = None
        for char_, reverse_, mask_ in SHAPES:
            err = sum(mask_[y][x] != covered[y][x] for y in range(CH) for x in range(CW))
            if best is None or err < best[0]:
                best = (err, char_, reverse_, mask_)
        _, char, reverse, mask = best
        # Nearly empty cells: leave them empty rather than draw a speck
        if best[0] >= count:
            return " "
    # Mean color of the covered pixels inside the chosen shape
    sel = [pixels[y][x] for y in range(CH) for x in range(CW)
           if mask[y][x] and pixels[y][x][3] > 0] or \
          [pixels[y][x] for y in range(CH) for x in range(CW) if pixels[y][x][3] > 0]
    weight = sum(p[3] for p in sel)
    r, g, b = (round(sum(p[i] * p[3] for p in sel) / weight) for i in range(3))
    color = f"\x1b[38;2;{r};{g};{b}m"
    if reverse:
        return f"{color}\x1b[7m{char}\x1b[27m"
    return f"{color}{char}"


def render(svg: str, out: pathlib.Path) -> None:
    image = rasterize(svg)
    lines = []
    for cy in range(ROWS):
        line = "".join(cell(image, cx, cy) for cx in range(COLS)).rstrip()
        # Reset the colors at the end of each line
        lines.append(f"{line}\x1b[0m")
    out.write_text("".join(f"{line}\n" for line in lines))
    print(f"{out.relative_to(ROOT)}: {len(lines)} lines")


def main() -> None:
    svg = LOGO.read_text()
    OUT.mkdir(parents=True, exist_ok=True)
    render(svg, OUT / "cosmic-blue-dark.txt")
    for old, new in LIGHT_SWAPS.items():
        assert old in svg, old
        svg = svg.replace(old, new)
    render(svg, OUT / "cosmic-blue-light.txt")


if __name__ == "__main__":
    main()
