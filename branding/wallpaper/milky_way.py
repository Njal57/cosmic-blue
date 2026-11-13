#!/usr/bin/env python3
"""The Milky Way above the Earth, from a photo taken on the International
Space Station (NASA, ISS064-E-55946, public domain), graded with the
cosmic-blue palette and cropped to 16:9 at 5120x2880.
Usage: milky_way.py IN.jpg OUT.jpg (the original is downloaded by build.sh).
Needs numpy and pillow.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

Image.MAX_IMAGE_PIXELS = None
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
w, h = im.size
ch = int(w * 9 / 16)
top = int((h - ch) * .2)
im = im.crop((0, top, w, top + ch)).filter(ImageFilter.GaussianBlur(1.4))  # soften sensor noise
im = im.resize((5120, 2880), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255
a = np.clip((a - .05) / .95, 0, 1) ** 1.25            # deeper black point
lum = np.clip((a * [.2126, .7152, .0722]).sum(-1), 0, 1)
# gradient map: black, deep navy, the logo blues, ice white
stops = np.array([[0, 0, 0], [5, 12, 42], [29, 71, 196], [79, 141, 255], [232, 244, 255]], np.float32) / 255
pos = [0, .08, .3, .6, 1.0]
g = np.stack([np.interp(lum, pos, stops[:, i]) for i in range(3)], -1)
img = np.clip(a * .55 + g * .45, 0, 1) * 255
img += np.random.default_rng(1).normal(0, 1.2, img.shape[:2])[..., None]
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out, quality=88, subsampling=0, optimize=True)
