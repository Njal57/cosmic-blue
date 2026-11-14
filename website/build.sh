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
runs="https://github.com/cosmic-blue-os/cosmic-blue/actions/workflows/build-live-iso.yml?query=branch%3Amain+is%3Asuccess"

# Desktop screenshots for the screenshots page and the home page preview,
# from SCREENSHOTS_DIR (filled by website/fetch-screenshots.sh in CI). Files
# are named like 03-desktop.png; the pages show a screenshot only if it is
# there (blocks between <!-- shot:NAME --> and <!-- /shot -->).
shots_dir="${SCREENSHOTS_DIR:-}"
shots=""
if [[ -n "${shots_dir}" && -f "${shots_dir}/info.env" ]]; then
  mkdir -p "${out}/img/screenshots"
  for file in "${shots_dir}"/*.png "${shots_dir}"/*.ppm; do
    [[ -e "${file}" ]] || continue
    name="$(basename "${file%.*}")"
    name="${name#[0-9][0-9]-}"
    [[ " ${shots} " == *" ${name} "* ]] && continue
    convert "${file}" -strip -quality 90 -define webp:method=6 "${out}/img/screenshots/${name}.webp"
    convert "${file}" -resize 960x -strip -quality 85 -define webp:method=6 "${out}/img/screenshots/${name}-960.webp"
    shots+=" ${name}"
  done
  # shellcheck source=/dev/null
  source "${shots_dir}/info.env"
fi
[[ -n "${shots}" ]] && shots+=" shots-info" || shots="no-shots"

# One page per language: index.html (English, default) and fr/index.html,
# and the same for the documentation (docs/) and the screenshots.
for page in index.html fr/index.html docs/index.html fr/docs/index.html \
            screenshots/index.html fr/screenshots/index.html; do
  mkdir -p "$(dirname "${out}/${page}")"
  if [[ -n "${ISO_BASE_URL:-}" ]]; then
    sed -e "s|@ISO_NVIDIA_URL@|${ISO_BASE_URL%/}/${iso_nvidia_name}|g" \
        -e "s|@ISO_URL@|${ISO_BASE_URL%/}/${iso_name}|g" \
      "${root}/website/${page}" > "${out}/${page}"
  else
    sed -e 's|<!-- checksum -->.*<!-- /checksum -->||' \
        -e "s|@ISO_NVIDIA_URL@|${runs}|g" -e "s|@ISO_URL@|${runs}|g" \
      "${root}/website/${page}" > "${out}/${page}"
  fi
  SHOTS="${shots}" perl -0pi -e '
    my %have = map { $_ => 1 } split " ", $ENV{SHOTS};
    s{^[ \t]*<!-- (?:shot:([\w-]+)|(shots-info|no-shots)) -->.*?<!-- /(?:shot|shots-info|no-shots) -->\n}
     {$have{$1 // $2} ? $& : ""}gmse;
    s{<!-- /?(shot(:[\w-]+)?|shots-info|no-shots) -->}{}g;' "${out}/${page}"
  sed -i -e "s|@SHOTS_DATE@|${SHOTS_DATE:-}|g" -e "s|@SHOTS_COMMIT@|${SHOTS_COMMIT:-}|g" \
    -e "s|@SHOTS_RUN@|${SHOTS_RUN:-}|g" "${out}/${page}"
done
cp "${root}/website/style.css" "${root}/website/site.js" "${out}/"
cp "${root}/branding/logo/cosmic-blue-logo.svg" \
   "${root}/branding/logo/cosmic-blue-logo-horizontal-dark.svg" "${out}/img/"

wallpaper="${root}/system_files/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg"
for width in 1280 2560; do
  convert "${wallpaper}" -resize "${width}x" -strip -interlace Plane \
    -sampling-factor 4:2:0 -quality 82 "${out}/img/wallpaper-${width}.jpg"
done

# Stop GitHub Pages from running Jekyll on the files
touch "${out}/.nojekyll"
