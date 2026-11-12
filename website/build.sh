#!/usr/bin/env bash
# Assemble the website into the given directory (default: _site).
# The logo and the wallpaper come from the repository, so the site always
# shows the current branding. Needs ImageMagick.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-${root}/_site}"

rm -rf "${out}"
mkdir -p "${out}/img"

cp "${root}/website/index.html" "${root}/website/style.css" "${out}/"
cp "${root}/branding/logo/cosmic-blue-logo.svg" \
   "${root}/branding/logo/cosmic-blue-logo-horizontal-dark.svg" "${out}/img/"

wallpaper="${root}/system_files/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg"
for width in 1280 2560; do
  convert "${wallpaper}" -resize "${width}x" -strip -interlace Plane \
    -sampling-factor 4:2:0 -quality 82 "${out}/img/wallpaper-${width}.jpg"
done

# Stop GitHub Pages from running Jekyll on the files
touch "${out}/.nojekyll"
