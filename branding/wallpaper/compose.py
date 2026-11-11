#!/usr/bin/env python3
"""Composite sky.png + foreground.png, add a fine grain (prevents banding in
the dark gradients) and write the final JPEG."""
import sys
import numpy as np
from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else "cosmic-blue.jpg"
# Quieter sky: dimmed Milky Way, a blue glow behind the planet, soft vignette
sky = np.asarray(Image.open("sky.png").convert("RGB")).astype(np.float32) / 255
h, w = sky.shape[:2]
y, x = np.mgrid[0:h, 0:w]
glow = np.exp(-(((x - 3250) / 1900.0) ** 2 + ((y - 1500) / 1300.0) ** 2))[..., None] * np.array([.05, .14, .42])
vignette = 1 - 0.55 * np.clip(np.sqrt(((x - w / 2) / w) ** 2 + ((y - h / 2) / h) ** 2) * 1.6, 0, 1)[..., None]
sky = Image.fromarray((np.clip((sky * 0.6 + glow) * vignette, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
img = Image.alpha_composite(sky, Image.open("foreground.png").convert("RGBA"))
a = np.asarray(img.convert("RGB")).astype(np.float32)
grain = np.random.default_rng(57).normal(0, 2.2, a.shape[:2]).astype(np.float32)[..., None]
Image.fromarray(np.clip(a + grain, 0, 255).astype(np.uint8)).save(out, quality=92, subsampling=0, optimize=True)
