#!/usr/bin/bash
# Rebuild the default wallpaper from its sources.
# Needs python3 with numpy, pillow and scipy, and node with playwright.
set -euo pipefail
cd "$(dirname "$0")"
python3 sky.py
python3 foreground.py
node render.js
python3 compose.py ../../system_files/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg
rm -f sky.png foreground.svg foreground.png
