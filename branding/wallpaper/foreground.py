#!/usr/bin/env python3
"""Foreground layer of the cosmic-blue wallpaper, as a transparent SVG.

Horizon planet with a sunrise, ringed gas giant and moon. The sky, the
Milky Way and the stars are rendered separately by sky.py.
Writes foreground.svg (5120x2880).
"""
import math
W, H = 5120, 2880

# Palette
P = dict(surf=["#0a2a86", "#061a5a", "#020a26"], gas=["#cfeeff", "#5aa4ff", "#1d47c4", "#0a2272"],
         gshade="#020822", vig=0.5, haze="#2f7bff")

# horizon planet geometry
R = 7600; PCX, PCY = 2200, 2230 + 7600
SX = 3300; SY = PCY - math.sqrt(R*R - (SX-PCX)**2)

o = []
o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">')
o.append('<title>cosmic-blue</title><defs>')
o.append('<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="120"/></filter>')
o.append('<filter id="b40" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="40"/></filter>')
o.append('<filter id="b12" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="12"/></filter>')
o.append('<filter id="b4" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4"/></filter>')
# horizon planet
sf = P["surf"]
o.append(f'<radialGradient id="surf" cx="{SX}" cy="{SY}" r="2600" gradientUnits="userSpaceOnUse" gradientTransform="translate({SX} {SY}) scale(1.6 .5) translate({-SX} {-SY})">'
         f'<stop offset="0" stop-color="{sf[0]}"/><stop offset=".45" stop-color="{sf[1]}"/><stop offset="1" stop-color="{sf[2]}"/></radialGradient>')
o.append(f'<radialGradient id="rim" cx="{SX}" cy="{SY}" r="3300" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ffffff"/><stop offset=".2" stop-color="#c8f2ff"/><stop offset=".6" stop-color="#5fb8ff" stop-opacity=".55"/><stop offset="1" stop-color="#3f86ff" stop-opacity=".15"/></radialGradient>')
ra = R + 380
o.append(f'<radialGradient id="atmo" cx="{PCX}" cy="{PCY}" r="{ra}" gradientUnits="userSpaceOnUse"><stop offset="{(R-40)/ra:.5f}" stop-color="#58bcff" stop-opacity="0"/><stop offset="{R/ra:.5f}" stop-color="#9fe2ff" stop-opacity=".55"/><stop offset="{(R+90)/ra:.5f}" stop-color="#3f9bff" stop-opacity=".22"/><stop offset="1" stop-color="#2a6bff" stop-opacity="0"/></radialGradient>')
o.append(f'<radialGradient id="atmomask" cx="{SX}" cy="{SY}" r="3600" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity=".25"/></radialGradient>')
o.append(f'<mask id="am"><rect width="{W}" height="{H}" fill="url(#atmomask)"/></mask>')
o.append(f'<clipPath id="pclip"><circle cx="{PCX}" cy="{PCY}" r="{R}"/></clipPath>')
o.append('<radialGradient id="sun"><stop offset="0" stop-color="#ffffff"/><stop offset=".25" stop-color="#eafcff" stop-opacity=".85"/><stop offset=".6" stop-color="#8fe0ff" stop-opacity=".25"/><stop offset="1" stop-color="#5fb8ff" stop-opacity="0"/></radialGradient>')
o.append(f'<radialGradient id="bloom"><stop offset="0" stop-color="{P["haze"]}" stop-opacity=".55"/><stop offset=".5" stop-color="{P["haze"]}" stop-opacity=".15"/><stop offset="1" stop-color="{P["haze"]}" stop-opacity="0"/></radialGradient>')
# gas giant
GX, GY, GR = 3760, 900, 236
g = P["gas"]
o.append(f'<radialGradient id="gas" cx=".36" cy=".86" r="1"><stop offset="0" stop-color="{g[0]}"/><stop offset=".3" stop-color="{g[1]}"/><stop offset=".68" stop-color="{g[2]}"/><stop offset="1" stop-color="{g[3]}"/></radialGradient>')
o.append(f'<radialGradient id="gshade" cx=".3" cy=".95" r="1.15"><stop offset=".5" stop-color="{P["gshade"]}" stop-opacity="0"/><stop offset=".8" stop-color="{P["gshade"]}" stop-opacity=".6"/><stop offset="1" stop-color="{P["gshade"]}" stop-opacity=".92"/></radialGradient>')
o.append(f'<clipPath id="gclip"><circle cx="{GX}" cy="{GY}" r="{GR}"/></clipPath>')
o.append(f'<clipPath id="front"><rect x="{GX-2000}" y="{GY}" width="4000" height="2000"/></clipPath>')
rc = ["#ffffff", "#a8dcff", "#3f6fd8"]
o.append(f'<linearGradient id="ring" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="{rc[0]}"/><stop offset=".45" stop-color="{rc[1]}"/><stop offset="1" stop-color="{rc[2]}" stop-opacity=".5"/></linearGradient>')
o.append('<radialGradient id="moon" cx=".7" cy=".8" r=".9"><stop offset="0" stop-color="#f4fbff"/><stop offset=".5" stop-color="#9fbfff"/><stop offset="1" stop-color="#3a5fc0"/></radialGradient>')
o.append('<radialGradient id="glow"><stop offset="0" stop-color="#ffffff" stop-opacity=".9"/><stop offset=".15" stop-color="#cfeaff" stop-opacity=".45"/><stop offset="1" stop-color="#8fc8ff" stop-opacity="0"/></radialGradient>')
o.append(f'<radialGradient id="vig" cx=".5" cy=".45" r=".78"><stop offset=".55" stop-color="#01040f" stop-opacity="0"/><stop offset="1" stop-color="#01040f" stop-opacity="{P["vig"]}"/></radialGradient>')
o.append('</defs>')

# atmospheric haze rising from the horizon
o.append(f'<ellipse cx="{SX}" cy="{SY}" rx="3400" ry="1300" fill="url(#bloom)"/>')

# moon
MX, MY, MR = 1380, 980, 34
o.append(f'<circle cx="{MX}" cy="{MY}" r="{MR*4}" fill="url(#glow)" opacity=".25"/>')
o.append(f'<circle cx="{MX}" cy="{MY}" r="{MR}" fill="url(#moon)"/>')

# gas giant + rings
RA = -16
def rings(clip=None):
    out = [f'<g transform="rotate({RA} {GX} {GY})"' + (f' clip-path="url(#{clip})"' if clip else '') + '>']
    for rx, w, op in [(318, 8, .25), (340, 20, .55), (366, 14, .8), (386, 10, .9), (408, 3, .15), (430, 24, .55), (458, 8, .4), (498, 5, .22), (540, 2, .15)]:
        out.append(f'<ellipse cx="{GX}" cy="{GY}" rx="{rx}" ry="{rx*.27:.0f}" fill="none" stroke="url(#ring)" stroke-width="{w}" opacity="{op}"/>')
    out.append('</g>')
    return ''.join(out)
o.append(f'<circle cx="{GX}" cy="{GY}" r="{GR*2.6}" fill="url(#bloom)" opacity=".35"/>')
o.append(rings())
o.append(f'<circle cx="{GX}" cy="{GY}" r="{GR}" fill="url(#gas)"/>')
bands = [f'<g clip-path="url(#gclip)"><g transform="rotate({RA} {GX} {GY})" filter="url(#b12)">']
for dy, h, op, c in [(-150, 30, .18, "#0a1f6a"), (-95, 18, .2, "#dff4ff"), (-40, 44, .16, "#0a1f6a"), (20, 22, .22, "#dff4ff"), (70, 36, .18, "#0a1f6a"), (130, 20, .2, "#dff4ff"), (180, 30, .15, "#0a1f6a")]:
    bands.append(f'<ellipse cx="{GX}" cy="{GY+dy}" rx="{GR*1.3:.0f}" ry="{h}" fill="{c}" opacity="{op}"/>')
bands.append('</g>')
bands.append(f'<g transform="rotate({RA} {GX} {GY})"><ellipse cx="{GX}" cy="{GY-30}" rx="{GR*1.4:.0f}" ry="26" fill="#020822" opacity=".28" filter="url(#b12)"/></g>')
bands.append(f'<circle cx="{GX}" cy="{GY}" r="{GR}" fill="url(#gshade)"/></g>')
o.append(''.join(bands))
o.append(rings("front"))

# horizon planet
o.append(f'<circle cx="{PCX}" cy="{PCY}" r="{R+380}" fill="url(#atmo)" mask="url(#am)"/>')
o.append(f'<circle cx="{PCX}" cy="{PCY}" r="{R}" fill="url(#surf)"/>')
cl = ['<g clip-path="url(#pclip)" filter="url(#b40)">']
for i in range(1, 9):
    rr = R - 40 - i*i*9
    cl.append(f'<circle cx="{PCX}" cy="{PCY}" r="{rr}" fill="none" stroke="#9fd4ff" stroke-width="{10+i*4}" opacity="{.10 - i*.008:.3f}"/>')
cl.append('</g>')
o.append(''.join(cl))
o.append(f'<circle cx="{PCX}" cy="{PCY}" r="{R}" fill="none" stroke="url(#rim)" stroke-width="28" filter="url(#b12)" opacity=".7"/>')
o.append(f'<circle cx="{PCX}" cy="{PCY}" r="{R}" fill="none" stroke="url(#rim)" stroke-width="5"/>')
# sunrise
o.append(f'<g clip-path="url(#pclip)"><ellipse cx="{SX}" cy="{SY+110}" rx="1500" ry="150" fill="url(#sun)" opacity=".28" filter="url(#b40)"/></g>')
o.append(f'<ellipse cx="{SX}" cy="{SY}" rx="2600" ry="40" fill="url(#sun)" opacity=".5" filter="url(#b12)"/>')
o.append(f'<ellipse cx="{SX}" cy="{SY}" rx="1300" ry="160" fill="url(#sun)" opacity=".55" filter="url(#b12)"/>')
o.append(f'<ellipse cx="{SX}" cy="{SY}" rx="380" ry="60" fill="url(#sun)"/>')
o.append(f'<circle cx="{SX}" cy="{SY}" r="70" fill="url(#sun)"/>')
o.append(f'<rect width="{W}" height="{H}" fill="url(#vig)"/>')
o.append('</svg>')
open("foreground.svg", "w").write("\n".join(o))
