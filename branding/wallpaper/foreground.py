#!/usr/bin/env python3
"""Foreground layer of the cosmic-blue wallpaper, as a transparent SVG.

The logo, as a scene: a planet inside a glowing open orbit, with a moon in
the gap. The sky, the Milky Way and the stars are rendered by sky.py.
Usage: foreground.py [dark|light]. Writes foreground.svg (5120x2880). The light
variant has deeper blues, a softer shadow, a white halo and an outlined moon,
so the scene stays readable on a pale sky.
"""
import math
import sys

LIGHT = len(sys.argv) > 1 and sys.argv[1] == "light"

W, H = 5120, 2880
CX, CY, PR = 3300, 1440, 430     # planet centre and radius
R = 1180                         # orbit radius
GAP = 40                         # half-angle of the orbit gap, at the right (degrees)


def pt(a):
    a = math.radians(a)
    return CX + R * math.cos(a), CY + R * math.sin(a)


def arc(a0, a1, n=200):
    ps = [pt(a0 + (a1 - a0) * i / n) for i in range(n + 1)]
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in ps)


orbit = arc(GAP, 360 - GAP)
mx, my = pt(0)
mx -= R * 0.05                   # moon sits just inside the gap, as in the logo

# colours: (dark, light)
C = {k: v[LIGHT] for k, v in {
    "orb": (("#7fe0ff", "#4f8dff", "#2f6bff"), ("#3fa9f5", "#2a63e8", "#1d47c4")),
    "shadow": (("#020822", ".6", ".92"), ("#0a1f66", ".45", ".8")),
    "halo": (("#3f86ff", ".45", "#2a5cff", ".12"), ("#ffffff", ".7", "#e8f0ff", ".25")),
    "moon_edge": ("#8fb6ff", "#6f9cf5"),
    "mglow": (("#e6f3ff", ".8", "#9fd0ff", ".3", "#5f9cff"), ("#ffffff", ".9", "#ffffff", ".35", "#ffffff")),
    "orbit_glow": (".45", ".3"),
}.items()}

o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
     '<title>cosmic-blue</title><defs>',
     '<linearGradient id="orb" gradientUnits="userSpaceOnUse" x1="1400" y1="2200" x2="4800" y2="900">'
     '<stop offset="0" stop-color="{0}"/><stop offset=".55" stop-color="{1}"/><stop offset="1" stop-color="{2}"/></linearGradient>'.format(*C["orb"]),
     '<radialGradient id="pl" cx=".32" cy=".78" r="1"><stop offset="0" stop-color="#d6f2ff"/><stop offset=".28" stop-color="#5aa4ff"/>'
     '<stop offset=".65" stop-color="#1d47c4"/><stop offset="1" stop-color="#0a1f66"/></radialGradient>',
     '<radialGradient id="sh" cx=".28" cy=".85" r="1.2"><stop offset=".35" stop-color="{0}" stop-opacity="0"/>'
     '<stop offset=".75" stop-color="{0}" stop-opacity="{1}"/><stop offset="1" stop-color="{0}" stop-opacity="{2}"/></radialGradient>'.format(*C["shadow"]),
     '<radialGradient id="halo"><stop offset="0" stop-color="{0}" stop-opacity="{1}"/><stop offset=".45" stop-color="{2}" stop-opacity="{3}"/>'
     '<stop offset="1" stop-color="{2}" stop-opacity="0"/></radialGradient>'.format(*C["halo"]),
     '<radialGradient id="moon" cx=".35" cy=".7" r=".9"><stop offset="0" stop-color="#ffffff"/><stop offset=".6" stop-color="#d8ecff"/>'
     '<stop offset="1" stop-color="{0}"/></radialGradient>'.format(C["moon_edge"]),
     '<radialGradient id="mglow"><stop offset="0" stop-color="{0}" stop-opacity="{1}"/><stop offset=".2" stop-color="{2}" stop-opacity="{3}"/>'
     '<stop offset="1" stop-color="{4}" stop-opacity="0"/></radialGradient>'.format(*C["mglow"]),
     '<filter id="b60" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="60"/></filter>',
     '<filter id="b18" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="18"/></filter>',
     '</defs>']
o.append(f'<circle cx="{CX}" cy="{CY}" r="{PR * 3.2}" fill="url(#halo)"/>')
o.append(f'<circle cx="{CX}" cy="{CY}" r="{PR}" fill="url(#pl)"/><circle cx="{CX}" cy="{CY}" r="{PR}" fill="url(#sh)"/>')
o.append(f'<circle cx="{CX}" cy="{CY}" r="{PR}" fill="none" stroke="#cfeeff" stroke-width="10" opacity=".35" filter="url(#b18)"/>')
# orbit: wide glow, body, and a thin highlight
o.append(f'<path d="{orbit}" fill="none" stroke="url(#orb)" stroke-width="260" stroke-linecap="round" opacity="{C["orbit_glow"]}" filter="url(#b60)"/>')
o.append(f'<path d="{orbit}" fill="none" stroke="url(#orb)" stroke-width="120" stroke-linecap="round"/>')
o.append(f'<path d="{orbit}" fill="none" stroke="#e8fbff" stroke-width="14" stroke-linecap="round" opacity=".35" filter="url(#b18)"/>')
o.append(f'<circle cx="{mx:.0f}" cy="{my:.0f}" r="380" fill="url(#mglow)"/><circle cx="{mx:.0f}" cy="{my:.0f}" r="80" fill="url(#moon)"/>')
if LIGHT:  # the white moon needs an edge on a pale sky
    o.append(f'<circle cx="{mx:.0f}" cy="{my:.0f}" r="80" fill="none" stroke="#2a63e8" stroke-width="6" opacity=".55"/>')
o.append('</svg>')
open("foreground.svg", "w").write("".join(o))
