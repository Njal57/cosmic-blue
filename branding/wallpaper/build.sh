#!/usr/bin/bash
# Rebuild the cosmic-blue wallpapers from their sources.
# Needs python3 with numpy, pillow and scipy, node with playwright, and curl.
set -euo pipefail
cd "$(dirname "$0")"
out=../../system_files/usr/share/backgrounds/cosmic-blue

# The logo scene (dark and light)
python3 sky.py
for mode in dark light; do
    python3 foreground.py "${mode}"
    node render.js
    suffix=""
    [[ "${mode}" == light ]] && suffix="-light"
    python3 compose.py "${mode}" "${out}/cosmic-blue${suffix}.jpg"
done

# Conceptual wallpapers: orbits (the default, dark and light) and waves
for kind in orbits-dark orbits-light waves; do
    python3 concept.py "${kind}" concept.svg
    node render.js concept.svg concept.png
    name="cosmic-blue-${kind%-dark}"
    python3 compose.py concept "${out}/${name}.jpg" concept.png
done

# The Milky Way above the Earth (NASA photo)
curl -fsSL -o milky-way-orig.jpg \
    https://images-assets.nasa.gov/image/iss064e055946/iss064e055946~orig.jpg
python3 milky_way.py milky-way-orig.jpg "${out}/cosmic-blue-milky-way.jpg"

rm -f sky.png sky-light.png foreground.svg foreground.png concept.svg concept.png milky-way-orig.jpg
