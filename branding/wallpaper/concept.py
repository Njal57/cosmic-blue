#!/usr/bin/env python3
"""The waves wallpaper, as SVG (5120x2880): layered ribbons of light.
Usage: concept.py waves OUT.svg. Render with render.js, then finish with
compose.py concept.
"""
import math
import sys

out = sys.argv[2]
W, H = 5120, 2880
o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}"><defs>',
     '<radialGradient id="bg" cx=".66" cy=".55" r=".9"><stop offset="0" stop-color="#0d2a7a"/>'
     '<stop offset=".45" stop-color="#06123d"/><stop offset="1" stop-color="#020617"/></radialGradient>',
     '<filter id="g2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter>',
     '</defs>', f'<rect width="{W}" height="{H}" fill="url(#bg)"/>']
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
