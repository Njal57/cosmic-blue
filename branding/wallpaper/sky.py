#!/usr/bin/env python3
"""Background layer of the cosmic-blue wallpaper: sky gradient, a procedural
Milky Way (domain-warped fractal noise, ridged-noise dust lanes) and stars.
Writes sky.png (5120x2880). Needs numpy, pillow and scipy.
"""
import numpy as np, math, sys
from PIL import Image
from scipy.ndimage import map_coordinates, gaussian_filter
W, H = 5120, 2880
S = 2  # nebula computed at half res, then upscaled
w, h = W//S, H//S
rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 11)

def noise(scale, seed_rng):
    gw, gh = max(2, int(w/scale)+3), max(2, int(h/scale)+3)
    g = seed_rng.random((gh, gw)).astype(np.float32)
    im = Image.fromarray(g, mode="F").resize((int(gw*scale), int(gh*scale)), Image.BICUBIC)
    a = np.asarray(im)
    ox, oy = seed_rng.integers(0, int(scale)+1, 2)
    return a[oy:oy+h, ox:ox+w]

def fbm(base, octaves, gain=.5, lac=2.0):
    tot = np.zeros((h, w), np.float32); amp = 1; norm = 0; sc = base
    for _ in range(octaves):
        tot += amp*noise(sc, rng); norm += amp; amp *= gain; sc /= lac
        if sc < 2: break
    return tot/norm

yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
# domain warp
wx = (fbm(700/S, 6) - .5) * 520/S
wy = (fbm(700/S, 6) - .5) * 520/S
X = (xx + wx) * S; Y = (yy + wy) * S
# band centerline (lower-left to upper-right)
pts = np.array([(500, 2600), (1700, 1900), (3000, 1250), (4200, 700), (5300, 150)])
c = np.polyfit(pts[:,0], pts[:,1], 2)
yc = np.polyval(c, X); slope = np.polyval(np.polyder(c), X)
d = (Y - yc) / np.sqrt(1 + slope**2)           # perpendicular distance (px at full res)
along = np.clip(X / W, 0, 1)
width = 520 + 260*np.sin(along*math.pi)         # wider in the middle
band = np.exp(-(d/width)**2)
core = np.exp(-((d+40)/(width*.38))**2)

detail = fbm(260/S, 7, gain=.55)
clouds = band * np.clip((detail - .25) * 1.9, 0, 1)**1.4
clump = fbm(120/S, 6, gain=.6)
clouds = clouds * (.55 + .9*clump)
corel = core * np.clip((fbm(160/S, 6, gain=.6) - .3) * 2.2, 0, 1)**1.2

# dust lanes: ridged noise, near the core
r1 = 1 - np.abs(2*fbm(340/S, 6, gain=.55) - 1)
r2 = 1 - np.abs(2*fbm(180/S, 6, gain=.55) - 1)
dust = gaussian_filter(r1**5 * .9 + r2**10 * .25, 2.5) * np.exp(-((d-60)/(width*.55))**2)
dust += .55*np.exp(-((d-30)/60)**2) * np.clip(fbm(200/S, 6)*1.6-.3, 0, 1)
absorb = np.exp(-2.6*dust)

# colours (linear-ish RGB, 0..1)
blue   = np.array([.10, .30, .95], np.float32)
cyan   = np.array([.30, .80, 1.0], np.float32)
violet = np.array([.48, .32, 1.0], np.float32)
white  = np.array([.85, .95, 1.0], np.float32)
vmix = np.clip((fbm(600/S, 4) - .45) * 3, 0, 1)[..., None]
cmix = np.clip(core*1.3, 0, 1)[..., None]
col = blue*(1-cmix) + cyan*cmix
col = col*(1-vmix*.7) + violet*(vmix*.7)
em = clouds[..., None]*col*.75 + corel[..., None]*white*.55 + (band**2)[..., None]*blue*.12
em = em * absorb[..., None]
# faint unresolved star haze inside the band
em += (band*absorb*.06)[..., None]*white
def up(a): return np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize((W, H), Image.BICUBIC))
emF = np.stack([up(em[..., i]) for i in range(3)], -1)
bandF = up(band*absorb)

# sky gradient
Y2, X2 = np.mgrid[0:H, 0:W].astype(np.float32)
t = np.clip((X2/W*.35 + Y2/H) / 1.35, 0, 1)[..., None]
c0 = np.array([2, 6, 26], np.float32)/255; c1 = np.array([7, 20, 80], np.float32)/255; c2 = np.array([13, 42, 134], np.float32)/255
sky = np.where(t < .6, c0 + (c1-c0)*(t/.6), c1 + (c2-c1)*((t-.6)/.4))
img = 1 - (1-sky)*(1-emF)   # screen

# stars: many faint (denser in the band), few bright with glow
star = np.zeros((H, W), np.float32)
n = 70000
sx = rng.uniform(0, W, n); sy = rng.uniform(0, H, n)
keep = rng.random(n) < (.18 + .82*bandF[sy.astype(int), sx.astype(int)])
sx, sy = sx[keep], sy[keep]
mag = rng.pareto(2.6, sx.size) * .08 + .03
np.add.at(star, (sy.astype(int), sx.astype(int)), np.clip(mag, 0, 3))
starI = gaussian_filter(star, .9) * 6
big = np.zeros((H, W), np.float32)
for _ in range(30):
    x, y = rng.integers(60, W-60), rng.integers(60, int(H*.75))
    big[y, x] += rng.uniform(.6, 1.2)**3 * 3
glow = gaussian_filter(big, 2.2)*30 + gaussian_filter(big, 14)*60
tint = np.array([.85, .93, 1.0], np.float32)
img = img + ((starI + glow)[..., None] * tint)
img = np.clip(img, 0, 1)
Image.fromarray((img*255+.5).astype(np.uint8)).save("sky.png")
