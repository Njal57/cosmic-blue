#!/usr/bin/env bash
# Assemble the website into the given directory (default: _site).
# The logo and the wallpaper come from the repository, so the site always
# shows the current branding. Needs ImageMagick.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-${root}/_site}"

rm -rf "${out}"
mkdir -p "${out}/img"

# Live ISO download: ISO_BASE_URL is the public URL of the R2 bucket. Until
# it is set, link to the live ISO workflow runs (needs a GitHub login).
# One ISO per image: cosmic-blue, and cosmic-blue-nvidia for NVIDIA cards.
iso_name="cosmic-blue-live-amd64.iso"
iso_nvidia_name="cosmic-blue-nvidia-live-amd64.iso"
if [[ -n "${ISO_BASE_URL:-}" ]]; then
  sed -e "s|@ISO_NVIDIA_URL@|${ISO_BASE_URL%/}/${iso_nvidia_name}|g" \
      -e "s|@ISO_URL@|${ISO_BASE_URL%/}/${iso_name}|g" \
    "${root}/website/index.html" > "${out}/index.html"
else
  runs="https://github.com/cosmic-blue-os/cosmic-blue/actions/workflows/build-live-iso.yml?query=branch%3Amain+is%3Asuccess"
  sed -e 's|<!-- checksum -->.*<!-- /checksum -->||' \
      -e "s|@ISO_NVIDIA_URL@|${runs}|g" -e "s|@ISO_URL@|${runs}|g" \
    "${root}/website/index.html" > "${out}/index.html"
fi
cp "${root}/website/style.css" "${out}/"
cp "${root}/branding/logo/cosmic-blue-logo.svg" \
   "${root}/branding/logo/cosmic-blue-logo-horizontal-dark.svg" "${out}/img/"

wallpaper="${root}/system_files/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg"
for width in 1280 2560; do
  convert "${wallpaper}" -resize "${width}x" -strip -interlace Plane \
    -sampling-factor 4:2:0 -quality 82 "${out}/img/wallpaper-${width}.jpg"
done

# Stop GitHub Pages from running Jekyll on the files
touch "${out}/.nojekyll"
