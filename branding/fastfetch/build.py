#!/usr/bin/python3
"""Render the cosmic-blue logo as terminal art for fastfetch.

Writes system_files/usr/share/ublue-os/fastfetch/cosmic-blue-{dark,light}.txt
(24-bit color block characters, shown by `fastfetch` through ublue-fastfetch).
The light version darkens the moon and the planet highlight, which would
vanish on a light terminal background.

Needs rsvg-convert (librsvg), chafa and python3-pillow:
    python3 branding/fastfetch/build.py
"""

import pathlib
import re
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOGO = ROOT / "branding/logo/cosmic-blue-logo.svg"
OUT = ROOT / "system_files/usr/share/ublue-os/fastfetch"
# Terminal cells are about twice as high as wide: 40x20 cells is a square.
SIZE = "40x20"
# Colors of the mark that are too pale for a light background
LIGHT_SWAPS = {"#e6f3ff": "#1d47c4", "#cfeeff": "#4f98f5"}

# Escape sequences chafa adds around the art (hide/show the cursor)
CURSOR = re.compile(r"\x1b\[\?25[hl]")


def render(svg: str, out: pathlib.Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        svg_file = pathlib.Path(tmp, "logo.svg")
        png_file = pathlib.Path(tmp, "logo.png")
        svg_file.write_text(svg)
        subprocess.run(
            ["rsvg-convert", "-w", "640", "-h", "640", str(svg_file), "-o", str(png_file)],
            check=True,
        )
        # Hard edges: chafa blends half-transparent pixels with black, which
        # gives dark fringes on any background other than black.
        image = Image.open(png_file).convert("RGBA")
        alpha = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
        image.putalpha(alpha)
        image.save(png_file)
        art = subprocess.run(
            [
                "chafa", "--format", "symbols", "--symbols", "block+border+space",
                "--fg-only", "--colors", "full", "--size", SIZE,
                "--threshold", "0.5", "--polite", "on", str(png_file),
            ],
            check=True, capture_output=True, text=True,
        ).stdout
    lines = [CURSOR.sub("", line).rstrip() for line in art.splitlines()]
    # Reset the colors at the end of each line
    out.write_text("".join(f"{line}\x1b[0m\n" for line in lines))
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
