#!/usr/bin/env python3
"""The default cosmic-blue wallpaper: a planetary system seen from above its
plane. A bright star, six orbits, shaded planets (one ringed giant), an
asteroid belt, over the Milky Way of sky.py.
Usage: orbits.py dark|light OUT.jpg (reads sky.png or sky-light.png).
Needs numpy, pillow and scipy.
"""
import math, sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
mode, out = sys.argv[1], sys.argv[2]
LIGHT = mode == "light"
W, H = 5120, 2880
rng = np.random.default_rng(7)
SX, SY = 3300, 1420           # star
TILT = math.radians(-12); RY = .30
sky = np.asarray(Image.open("sky-light.png" if LIGHT else "sky.png").convert("RGB")).astype(np.float32) / 255
y, x = np.mgrid[0:H, 0:W].astype(np.float32)
rs = np.hypot(x - SX, y - SY)
vig = np.clip(np.hypot((x - W / 2) / W, (y - H / 2) / H) * 1.6, 0, 1)[..., None]


def screen(a, b): return 1 - (1 - a) * (1 - np.clip(b, 0, 1))


def ink(a, b, colour):
    """Light mode: darken towards colour where b > 0 (lines on a pale sky)."""
    b = np.clip(b, 0, 1)
    return a * (1 - b) + a * np.array(colour) * b


if LIGHT:   # pale sky, a white glow around the star
    img = screen(sky * (1 - .12 * vig), (np.exp(-(rs / 1100) ** 2) * .5)[..., None])
else:       # dimmed Milky Way, blue light around the star
    img = sky * .42 * (1 - .5 * vig)
    img += (np.exp(-(rs / 1500) ** 2) * .30)[..., None] * np.array([.10, .25, .75])
    img += (np.exp(-(rs / 600) ** 2) * .35)[..., None] * np.array([.25, .45, 1.0])
def ell(r, t):
    ex, ey = r * np.cos(t), r * RY * np.sin(t)
    return SX + ex * math.cos(TILT) - ey * math.sin(TILT), SY + ex * math.sin(TILT) + ey * math.cos(TILT)

# orbits: thin lines, brighter on the near (lower) half
radii = [430, 720, 1080, 1520, 2050, 2700]
lines = np.zeros((H, W), np.float32)
for i, r in enumerate(radii):
    t = np.linspace(0, 2 * np.pi, int(r * 14))
    px, py = ell(r, t)
    near = .3 + .7 * (np.sin(t) * .5 + .5) ** 1.5
    ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
    np.add.at(lines, (py[ok].astype(int), px[ok].astype(int)), near[ok] * (1 - .08 * i) * 14 / (r * 14 / 1000))
lines = gaussian_filter(lines, 1.1) * 1.2 + gaussian_filter(lines, 8) * 3
if LIGHT:
    img = ink(img, lines[..., None] * .5, (.16, .39, .91))
else:
    img = screen(img, lines[..., None] * np.array([.45, .7, 1.0]) * .55)

# asteroid belt between the 3rd and 4th orbits
n = 9000
t = rng.uniform(0, 2 * np.pi, n); rr = rng.normal(1290, 70, n)
px, py = ell(rr, t); py = py + rng.normal(0, 14, n)
near = .25 + .75 * (np.sin(t) * .5 + .5) ** 1.5
belt = np.zeros((H, W), np.float32)
ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
np.add.at(belt, (py[ok].astype(int), px[ok].astype(int)), near[ok] * rng.uniform(.3, 1, n)[ok] ** 2)
belt = gaussian_filter(belt, .9) * 5 + gaussian_filter(belt, 18) * 14
if LIGHT:
    img = ink(img, belt[..., None] * .4, (.16, .39, .91))
else:
    img = screen(img, belt[..., None] * np.array([.6, .78, 1.0]) * .5)

def noise1d(seed, n=64):
    return np.random.default_rng(seed).random(n)

def planet(img, cx, cy, R, base, light, seed, bands=0, atmo=(.4, .65, 1.0), ring=None, lz=-.35):
    x0, x1 = int(max(cx - R * 2.6, 0)), int(min(cx + R * 2.6, W)); y0, y1 = int(max(cy - R * 2.6, 0)), int(min(cy + R * 2.6, H))
    if x0 >= x1 or y0 >= y1: return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = (xx - cx) / R, (yy - cy) / R; d2 = dx * dx + dy * dy
    inside = np.clip((1 - np.sqrt(d2)) * R / 1.5, 0, 1)
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    L = np.array([SX - cx, SY - cy, lz * math.hypot(SX - cx, SY - cy)]) if light else np.array([1, -1, -.6])
    L = L / np.linalg.norm(L)
    diff = np.clip(dx * L[0] + dy * L[1] - nz * L[2], 0, 1)
    shade = .04 + .96 * diff ** .8
    col = np.array(base, np.float32)
    if bands:
        b = noise1d(seed)
        stripe = np.interp((dy * .5 + .5) * 63 + np.sin(dx * 3) * .6, np.arange(64), b)
        col = col[None, None, :] * (.75 + .5 * stripe[..., None])
    else:
        col = np.broadcast_to(col, dy.shape + (3,))
    surf = col * shade[..., None]
    # limb: lit rim and atmosphere glow outside
    dist = np.sqrt(d2)
    rim = np.exp(-((dist - 1) * R / 3.5) ** 2) * (diff + .05)
    glow = np.exp(-np.clip(dist - 1, 0, None) * R / (R * .12 + 6)) * (dist > .98) * (.15 + .85 * np.clip(dx * L[0] + dy * L[1], 0, 1))
    patch = img[y0:y1, x0:x1]
    if ring:
        rin, rout, rtilt = ring
        ca, sa = math.cos(rtilt), math.sin(rtilt)
        ux = (dx * ca + dy * sa); uy = (-dx * sa + dy * ca) / .28
        rd = np.sqrt(ux * ux + uy * uy)
        rband = np.clip((rd - rin) * 40, 0, 1) * np.clip((rout - rd) * 40, 0, 1)
        rtex = .6 + .4 * np.interp(rd, np.linspace(rin, rout, 32), noise1d(seed + 9, 32))
        back = uy < 0
        ringc = (rband * rtex * (.35 + .5 * np.clip(diff.max(), 0, 1)))[..., None] * np.array([.7, .82, 1.0])
        patch = screen(patch, ringc * back[..., None] * .75)
    patch = patch * (1 - inside[..., None]) + surf * inside[..., None]
    patch = screen(patch, (rim * .9)[..., None] * np.array(atmo))
    patch = screen(patch, (glow * .5)[..., None] * np.array(atmo))
    if ring:
        front = ~back
        patch = screen(patch, ringc * front[..., None] * .9)
    img[y0:y1, x0:x1] = patch

ps = [  # (orbit index, angle deg, radius, colour, bands, ring)
    (0, 205, 24, (.75, .80, .90), 0, None),
    (1, 35, 40, (.35, .60, 1.0), 0, None),
    (2, 300, 34, (.55, .78, 1.0), 0, None),
    (3, 150, 120, (.45, .62, .95), 1, (1.35, 2.25, math.radians(-18))),
    (4, 252, 70, (.25, .45, .95), 1, None),
    (5, 22, 46, (.62, .85, 1.0), 0, None),
]
for k, (oi, ang, R, col, bands, ring) in enumerate(ps):
    px, py = ell(radii[oi], math.radians(ang))
    planet(img, float(px), float(py), R, col, True, 30 + k, bands, ring=ring)

# the star: white core, corona, faint anamorphic streak and four soft spikes
core = np.exp(-(rs / 70) ** 2) * 1.6 + np.exp(-(rs / 220) ** 2) * .55 + np.exp(-(rs / 700) ** 2) * .18
streak = np.exp(-((y - SY) / 6) ** 2) * np.exp(-np.abs(x - SX) / 380) * .3
ang = np.arctan2(y - SY, x - SX)
spikes = (np.abs(np.cos(2 * (ang - math.radians(8)))) ** 400) * np.exp(-rs / 300) * .3
if LIGHT:   # a blue halo, so the white star stands out on the pale sky
    img = ink(img, (np.exp(-(rs / 260) ** 2) * .45 - np.exp(-(rs / 90) ** 2) * .45)[..., None].clip(0), (.31, .55, 1.0))
img = screen(img, (core + streak + spikes)[..., None] * np.array([.88, .94, 1.0]))
img = np.clip(img, 0, 1) * 255
img += np.random.default_rng(57).normal(0, 2.0, img.shape[:2])[..., None]
Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out, quality=92, subsampling=0, optimize=True)
