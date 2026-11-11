#!/usr/bin/env python3
"""Composite sky.png + foreground.png, add a fine grain (prevents banding in
the dark gradients) and write the final JPEG."""
import sys
import numpy as np
from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else "cosmic-blue.jpg"
img = Image.alpha_composite(Image.open("sky.png").convert("RGBA"), Image.open("foreground.png").convert("RGBA"))
a = np.asarray(img.convert("RGB")).astype(np.float32)
grain = np.random.default_rng(57).normal(0, 2.2, a.shape[:2]).astype(np.float32)[..., None]
Image.fromarray(np.clip(a + grain, 0, 255).astype(np.uint8)).save(out, quality=92, subsampling=0, optimize=True)
