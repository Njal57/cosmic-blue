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
        # Vertical bars one sub-pixel wide look like stray lines: skip them
        if k in (1, 7):
            continue
        left = [[x < k for x in range(CW)] for _ in range(CH)]
        out.append((LEFT[k], False, left))
        out.append((LEFT[k], True, [[not v for v in row] for row in left]))
    for char, (tl, tr, bl, br) in QUADRANTS.items():
        mask = [[bool((tl, tr, bl, br)[(y >= CH // 2) * 2 + (x >= CW // 2)])
                 for x in range(CW)] for y in range(CH)]
        out.append((char, False, mask))
    return out


# Every candidate: empty, full and the partial blocks
CANDIDATES = [(" ", False, np.zeros((CH, CW), bool)), ("█", False, np.ones((CH, CW), bool))] + [
    (char, reverse, np.array(mask)) for char, reverse, mask in shapes()]
MASKS = np.array([mask for _, _, mask in CANDIDATES], dtype=float)
# Width of the logo's viewBox (-50 -50 100 100)
VIEW = 100


def rasterize(svg: str, size: float, x0: float, y0: float) -> np.ndarray:
    """RGBA sub-pixels (float, alpha = coverage) of the logo drawn size
    sub-pixels wide with its top left corner at (x0, y0)."""
    w, h = COLS * CW, ROWS * CH
    unit = VIEW / size  # SVG units per sub-pixel
    view = f"{-VIEW / 2 - x0 * unit:.4f} {-VIEW / 2 - y0 * unit:.4f} {w * unit:.4f} {h * unit:.4f}"
    svg = re.sub(r'viewBox="[^"]*"', f'viewBox="{view}"', svg, count=1)
    with tempfile.TemporaryDirectory() as tmp:
        svg_file = pathlib.Path(tmp, "logo.svg")
        png_file = pathlib.Path(tmp, "logo.png")
        svg_file.write_text(svg)
        subprocess.run(["rsvg-convert", "-w", str(w * SUPERSAMPLE), "-h", str(h * SUPERSAMPLE),
                        str(svg_file), "-o", str(png_file)], check=True)
        image = np.asarray(Image.open(png_file).convert("RGBA"), dtype=float) / 255
    # Box filter down to sub-pixels
    return image.reshape(h, SUPERSAMPLE, w, SUPERSAMPLE, 4).mean(axis=(1, 3))


def cells(image: np.ndarray) -> np.ndarray:
    """Coverage of every cell: [row, col, y, x]."""
    cov = image[..., 3]
    return cov.reshape(ROWS, CH, COLS, CW).transpose(0, 2, 1, 3)


def choose(cov: np.ndarray):
    """Best shape index (into CANDIDATES) and its error, for every cell."""
    # err[shape, row, col] = sum of |coverage - mask|
    err = np.abs(cov[None] - MASKS[:, None, None]).sum(axis=(3, 4))
    best = err.argmin(axis=0)
    return best, np.take_along_axis(err, best[None], 0)[0]


def placement(svg: str):
    """Size and position of the logo with the smallest total error, i.e. the
    cleanest curves once drawn in cells."""
    best = None
    full = min(COLS * CW, ROWS * CH)
    for size in np.arange(full * 0.90, full + 0.1, full * 0.025):
        free = full - size
        for x0 in np.linspace(0, free, 5) if free else [0]:
            for y0 in np.linspace(0, free, 5) if free else [0]:
                _, err = choose(cells(rasterize(svg, size, x0, y0)))
                score = err.sum() / size  # per unit of outline
                if best is None or score < best[0]:
                    best = (score, size, x0, y0)
    return best[1:]


def render(svg: str, out: pathlib.Path, place) -> None:
    image = rasterize(svg, *place)
    cov = cells(image)
    best, _ = choose(cov)
    rgba = image.reshape(ROWS, CH, COLS, CW, 4).transpose(0, 2, 1, 3, 4)
    lines = []
    for cy in range(ROWS):
        line = ""
        for cx in range(COLS):
            char, reverse, mask = CANDIDATES[best[cy, cx]]
            if char == " ":
                line += " "
                continue
            # Mean color of the logo pixels inside the shape
            px = rgba[cy, cx]
            weight = px[..., 3] * (mask if mask.any() else 1)
            if weight.sum() == 0:
                weight = px[..., 3]
            r, g, b = (round(255 * (px[..., i] * weight).sum() / weight.sum()) for i in range(3))
            color = f"\x1b[38;2;{r};{g};{b}m"
            line += f"{color}\x1b[7m{char}\x1b[27m" if reverse else f"{color}{char}"
        # Reset the colors at the end of each line
        lines.append(f"{line.rstrip()}\x1b[0m")
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
