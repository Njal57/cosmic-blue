#!/usr/bin/env python3
"""Tint Fedora's boot spinner frames with the cosmic-blue logo blue.

The frames of the spinner Plymouth theme are grey or white on transparency.
Each pixel keeps its alpha and its brightness, and takes the hue of the logo:
dark pixels go to the deep orbit blue, bright ones to the light orbit blue.
Usage: tint.py SPINNER_DIR OUT_DIR
"""
import sys
from pathlib import Path

from PIL import Image

DEEP = (0x2F, 0x6B, 0xFF)   # logo orbit gradient, end
LIGHT = (0x7F, 0xE0, 0xFF)  # logo orbit gradient, start

src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
lut = [[round(d + (l - d) * v / 255) for v in range(256)] for d, l in zip(DEEP, LIGHT)]

frames = sorted(src.glob("throbber-*.png")) + sorted(src.glob("animation-*.png"))
if not frames:
    sys.exit(f"no spinner frames in {src}")
for frame in frames:
    image = Image.open(frame).convert("RGBA")
    grey = image.convert("L")
    rgb = [grey.point(channel) for channel in lut]
    Image.merge("RGBA", (*rgb, image.getchannel("A"))).save(out / frame.name, optimize=True)
    print(f"tinted {frame.name}")
