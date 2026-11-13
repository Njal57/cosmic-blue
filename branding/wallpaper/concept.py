#!/usr/bin/env python3
"""Conceptual cosmic-blue wallpapers, as SVG (5120x2880).
Usage: concept.py orbits-dark|orbits-light|waves OUT.svg
- orbits: planets on tilted orbits around a bright star (the default wallpaper)
- waves: layered ribbons of light
Render with render.js, then finish with compose.py concept.
"""
import math
import sys

kind, out = sys.argv[1], sys.argv[2]
W, H = 5120, 2880
LIGHT = kind == "orbits-light"

if LIGHT:
    bg = ("#e3ecff", "#f1f5ff", "#fbfcff")
    sun = ("#ffffff", "#ffffff", "#9fc4ff", ".45", "#4f8dff")
    line = ("#4f8dff", "#2a63e8", "#1d47c4")
    planets = ["#7fb2ff", "#2a63e8", "#1d47c4", "#4f8dff", "#0f2f99", "#3fa9f5"]
    halo, core = "#4f8dff", "#ffffff"
else:
    bg = ("#0d2a7a", "#06123d", "#020617")
    sun = ("#e8f4ff", "#9fc4ff", "#4f8dff", ".35", "#1d47c4")
    line = ("#7fe0ff", "#4f8dff", "#1d47c4")
    planets = ["#cfe6ff", "#7fb2ff", "#4f8dff", "#9fd0ff", "#2f6bff", "#7fe0ff"]
    halo, core = "#4f8dff", "#f2f8ff"

o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}"><defs>',
     '<radialGradient id="bg" cx=".66" cy=".55" r=".9"><stop offset="0" stop-color="{}"/>'
     '<stop offset=".45" stop-color="{}"/><stop offset="1" stop-color="{}"/></radialGradient>'.format(*bg),
     '<radialGradient id="sun"><stop offset="0" stop-color="{}"/><stop offset=".08" stop-color="{}"/>'
     '<stop offset=".3" stop-color="{}" stop-opacity="{}"/><stop offset="1" stop-color="{}" stop-opacity="0"/></radialGradient>'.format(*sun),
     '<linearGradient id="ln" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{}"/><stop offset=".5" stop-color="{}"/>'
     '<stop offset="1" stop-color="{}" stop-opacity=".4"/></linearGradient>'.format(*line),
     '<filter id="g" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>',
     '<filter id="g2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter>',
     '</defs>', f'<rect width="{W}" height="{H}" fill="url(#bg)"/>']

if kind.startswith("orbits"):
    cx, cy, tilt = 3400, 1500, -14
    o.append(f'<circle cx="{cx}" cy="{cy}" r="900" fill="url(#sun)"/>')
    o.append(f'<g transform="rotate({tilt} {cx} {cy})">')
    radii = [420, 700, 1050, 1480, 2000, 2650]
    phases = [200, 30, 300, 140, 250, 20]
    sizes = [22, 34, 28, 52, 40, 30]
    for i, (r, ph, pr) in enumerate(zip(radii, phases, sizes)):
        ry = r * .34
        op = (.75 - .07 * i) if LIGHT else (.55 - .06 * i)
        o.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{ry}" fill="none" stroke="url(#ln)" '
                 f'stroke-width="{5 - 0.4 * i:.1f}" opacity="{op:.2f}"/>')
        a = math.radians(ph)
        px, py = cx + r * math.cos(a), cy + ry * math.sin(a)
        o.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{pr * 3}" fill="{halo}" opacity="{.25 if LIGHT else .35}" filter="url(#g)"/>')
        o.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{pr}" fill="{planets[i]}"/>')
    o.append('</g>')
    if LIGHT:
        o.append(f'<circle cx="{cx}" cy="{cy}" r="260" fill="{halo}" opacity=".35" filter="url(#g2)"/>')
    o.append(f'<circle cx="{cx}" cy="{cy}" r="95" fill="{core}"/>')
    if LIGHT:
        o.append(f'<circle cx="{cx}" cy="{cy}" r="95" fill="none" stroke="#2a63e8" stroke-width="6" opacity=".5"/>')
else:
    for j in range(46):
        t = j / 45
        y0 = 2300 - t * 900
        amp = 380 + t * 260
        ph = t * 2.2
        pts = []
        for x in range(0, W + 81, 80):
            y = y0 + amp * math.sin(x / W * 2.4 * math.pi + ph) * (.6 + .4 * math.sin(x / W * math.pi)) - t * 0.12 * x
            pts.append(f"{x} {y:.1f}")
        col = ["#1d47c4", "#2f6bff", "#4f8dff", "#7fe0ff"][int(t * 3.99)]
        s = math.sin(t * math.pi)
        o.append(f'<path d="M{" L".join(pts)}" fill="none" stroke="{col}" stroke-width="{3 + 6 * s:.2f}" opacity="{.15 + .45 * s:.2f}"/>')
    o.append('<ellipse cx="3000" cy="1500" rx="1700" ry="600" fill="#4f8dff" opacity=".18" filter="url(#g2)"/>')
o.append('</svg>')
open(out, "w").write("".join(o))
