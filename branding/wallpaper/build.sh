#!/usr/bin/bash
# Rebuild the default wallpapers (dark and light) from their sources.
# Needs python3 with numpy, pillow and scipy, and node with playwright.
set -euo pipefail
cd "$(dirname "$0")"
out=../../system_files/usr/share/backgrounds/cosmic-blue
python3 sky.py
for mode in dark light; do
    python3 foreground.py "${mode}"
    node render.js
    suffix=""
    [[ "${mode}" == light ]] && suffix="-light"
    python3 compose.py "${mode}" "${out}/cosmic-blue${suffix}.jpg"
done
rm -f sky.png sky-light.png foreground.svg foreground.png
