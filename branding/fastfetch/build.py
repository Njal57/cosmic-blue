#!/usr/bin/python3
"""Render the cosmic-blue logo as terminal art for fastfetch.

Writes system_files/usr/share/ublue-os/fastfetch/cosmic-blue-{dark,light}.txt
(24-bit color art, shown by `fastfetch` through ublue-fastfetch). The light
version darkens the moon and the planet highlight, which would vanish on a
light terminal background.

The logo is drawn on a grid of pixels, two per terminal cell (top and bottom
half), with as many columns as needed for a round logo in COSMIC Terminal. Terminals such as COSMIC Terminal draw block glyphs
shorter than the cell (the line spacing stays empty below the glyph), so
glyphs stacked on top of each other leave dark lines between rows. A cell
background, on the other hand, always fills the whole cell. So every cell is
drawn with its background color, and with the only glyph that never needs to
reach the cell bottom, the upper half block:

- both halves set: upper half block in the top color on the bottom color
  (a space on the background color when both are the same)
- top half only: upper half block on the terminal background
- bottom half only: upper half block in reverse video, i.e. the glyph in
  the terminal background color on the bottom color

Needs rsvg-convert (librsvg), python3-numpy and python3-pillow:
    python3 branding/fastfetch/build.py
"""

import pathlib
import re
import subprocess
import tempfile

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOGO = ROOT / "branding/logo/cosmic-blue-logo.svg"
OUT = ROOT / "system_files/usr/share/ublue-os/fastfetch"
# Height / width of a COSMIC Terminal cell with its default font and line
# height (measured on a screenshot: 19.3 x 7.9 px). Each pixel is half a
# cell, so pixels are CELL_ASPECT / 2 times higher than wide.
CELL_ASPECT = 2.43
ROWS = 20
PX_ROWS = ROWS * 2
# As many columns as needed for a round logo
COLS = round(ROWS * CELL_ASPECT)
# Sub-pixels per pixel, to measure the logo coverage of each pixel
SUB = 8
# Width of the logo's viewBox (-50 -50 100 100)
VIEW = 100
# Colors of the mark that are too pale for a light background
LIGHT_SWAPS = {"#e6f3ff": "#1d47c4", "#cfeeff": "#4f98f5"}
# Pixels at least half covered by the logo get its color, the others stay
# empty. They are not blended with a background color: the cosmic-blue
# terminal is translucent, so any blend shows as darker squares on the edges.
MIN_COVERAGE = 0.5
# Two halves closer than this (per channel) are drawn as one color
SAME_COLOR = 10

UPPER_HALF = "▀"


def rasterize(svg: str, size: float, x0: float, y0: float) -> np.ndarray:
    """RGBA sub-pixels (float, alpha = coverage) of the logo drawn size
    sub-pixels wide with its top left corner at (x0, y0)."""
    # Drawn with square sub-pixels, then squeezed vertically to the pixel
    # grid, whose pixels are higher than wide
    w, h = COLS * SUB, round(PX_ROWS * SUB * CELL_ASPECT / 2)
    unit = VIEW / size  # SVG units per sub-pixel
    view = f"{-VIEW / 2 - x0 * unit:.4f} {-VIEW / 2 - y0 * unit:.4f} {w * unit:.4f} {h * unit:.4f}"
    svg = re.sub(r'viewBox="[^"]*"', f'viewBox="{view}"', svg, count=1)
    with tempfile.TemporaryDirectory() as tmp:
        svg_file = pathlib.Path(tmp, "logo.svg")
        png_file = pathlib.Path(tmp, "logo.png")
        svg_file.write_text(svg)
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h),
                        str(svg_file), "-o", str(png_file)], check=True)
        image = Image.open(png_file).convert("RGBA").resize((w, PX_ROWS * SUB), Image.BOX)
        return np.asarray(image, dtype=float) / 255


def pixels(image: np.ndarray):
    """Coverage [y, x] and mean color [y, x, rgb] of every pixel."""
    blocks = image.reshape(PX_ROWS, SUB, COLS, SUB, 4)
    alpha = blocks[..., 3]
    coverage = alpha.mean(axis=(1, 3))
    weight = alpha.sum(axis=(1, 3))[..., None]
    color = (blocks[..., :3] * alpha[..., None]).sum(axis=(1, 3)) / np.maximum(weight, 1e-9)
    return coverage, color


def placement(svg: str):
    """Size and position of the logo whose pixels are the least ambiguous
    (coverage closest to 0 or 1), i.e. the cleanest curves once drawn."""
    best = None
    full = min(COLS * SUB, round(PX_ROWS * SUB * CELL_ASPECT / 2))
    for size in np.arange(full * 0.90, full + 0.1, full * 0.025):
        free = full - size
        for x0 in np.linspace(0, free, 5) if free else [0]:
            for y0 in np.linspace(0, free, 5) if free else [0]:
                coverage, _ = pixels(rasterize(svg, size, x0, y0))
                error = np.minimum(coverage, 1 - coverage).sum() / size
                if best is None or error < best[0]:
                    best = (error, size, x0, y0)
    return best[1:]


def sgr(kind: int, rgb) -> str:
    r, g, b = (round(255 * c) for c in rgb)
    return f"\x1b[{kind};2;{r};{g};{b}m"


def cell(top, bottom) -> str:
    """One terminal cell; top and bottom are an RGB color or None (empty)."""
    if top is None and bottom is None:
        return "\x1b[0m "
    if top is None:
        # Reverse video: the glyph in the terminal background, the cell in
        # the bottom color
        return f"\x1b[0m{sgr(38, bottom)}\x1b[7m{UPPER_HALF}"
    if bottom is None:
        return f"\x1b[0m{sgr(38, top)}{UPPER_HALF}"
    if np.abs(np.asarray(top) - np.asarray(bottom)).max() * 255 < SAME_COLOR:
        return f"\x1b[0m{sgr(48, (np.asarray(top) + np.asarray(bottom)) / 2)} "
    return f"\x1b[0m{sgr(38, top)}{sgr(48, bottom)}{UPPER_HALF}"


def render(svg: str, out: pathlib.Path, place) -> None:
    coverage, color = pixels(rasterize(svg, *place))
    on = coverage >= MIN_COVERAGE
    lines = []
    for row in range(ROWS):
        cells = []
        for col in range(COLS):
            top, bottom = (color[y, col] if on[y, col] else None
                           for y in (2 * row, 2 * row + 1))
            cells.append(cell(top, bottom))
        # Trailing empty cells are left out; reset the colors at line end
        while cells and cells[-1] == "\x1b[0m ":
            cells.pop()
        lines.append("".join(cells) + "\x1b[0m")
    out.write_text("".join(f"{line}\n" for line in lines))
    print(f"{out.relative_to(ROOT)}: {len(lines)} lines")


def main() -> None:
    svg = LOGO.read_text()
    OUT.mkdir(parents=True, exist_ok=True)
    place = placement(svg)
    print("logo size {:.1f}, position {:.1f} {:.1f} (sub-pixels)".format(*place))
    render(svg, OUT / "cosmic-blue-dark.txt", place)
    for old, new in LIGHT_SWAPS.items():
        assert old in svg, old
        svg = svg.replace(old, new)
    render(svg, OUT / "cosmic-blue-light.txt", place)


if __name__ == "__main__":
    main()
