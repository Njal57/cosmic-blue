#!/usr/bin/env python3
"""Composite the sky and foreground.png, add a fine grain (prevents banding in
the gradients) and write the final JPEG.
Usage: compose.py dark|light OUT.jpg (reads sky.png or sky-light.png)."""
import sys
import numpy as np
from PIL import Image

mode, out = sys.argv[1], sys.argv[2]
sky = np.asarray(Image.open("sky-light.png" if mode == "light" else "sky.png").convert("RGB")).astype(np.float32) / 255
h, w = sky.shape[:2]
y, x = np.mgrid[0:h, 0:w]
spot = np.exp(-(((x - 3250) / 1900.0) ** 2 + ((y - 1500) / 1300.0) ** 2))[..., None]
dist = np.clip(np.sqrt(((x - w / 2) / w) ** 2 + ((y - h / 2) / h) ** 2) * 1.6, 0, 1)[..., None]
if mode == "light":
    # a white glow behind the planet, very soft vignette
    sky = (1 - (1 - sky) * (1 - spot * .18)) * (1 - 0.12 * dist)
else:
    # quieter sky: dimmed Milky Way, a blue glow behind the planet, soft vignette
    sky = (sky * 0.6 + spot * np.array([.05, .14, .42])) * (1 - 0.55 * dist)
sky = Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
img = Image.alpha_composite(sky, Image.open("foreground.png").convert("RGBA"))
a = np.asarray(img.convert("RGB")).astype(np.float32)
grain = np.random.default_rng(57).normal(0, 2.2, a.shape[:2]).astype(np.float32)[..., None]
Image.fromarray(np.clip(a + grain, 0, 255).astype(np.uint8)).save(out, quality=92, subsampling=0, optimize=True)
