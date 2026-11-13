#!/usr/bin/bash
# Checks cosmic-blue-migrate-defaults on a made-up account and image defaults.
# Run by 99-tests.sh; also runs outside the image:
#   build_files/migrate-defaults-test.sh system_files/usr/libexec/cosmic-blue-migrate-defaults
set -euo pipefail

SCRIPT="$(realpath "${1:-/usr/libexec/cosmic-blue-migrate-defaults}")"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export COSMIC_BLUE_DEFAULTS_DIR="${WORK}/defaults"
export COSMIC_BLUE_MANIFEST="${WORK}/defaults.list"
export COSMIC_BLUE_PREVIOUS="${WORK}/previous.list"
export HOME="${WORK}/home"
unset XDG_CONFIG_HOME XDG_STATE_HOME
CONFIG="${HOME}/.config/cosmic"
# GSettings keys are not part of this test
mkdir -p "${WORK}/bin"
printf '#!/bin/sh\necho "\x27default\x27"\n' >"${WORK}/bin/gsettings"
chmod +x "${WORK}/bin/gsettings"
export PATH="${WORK}/bin:${PATH}"

fail() { echo "migrate-defaults-test: $*" >&2; exit 1; }
put() { # file value
    mkdir -p "$(dirname "$1")"
    printf '%s' "$2" >"$1"
}
image() { # path value: an image default
    put "${COSMIC_BLUE_DEFAULTS_DIR}/$1" "$2"
}
account() { # path value: the account's own copy
    put "${CONFIG}/$1" "$2"
}
manifest() {
    "${SCRIPT}" --manifest >"${COSMIC_BLUE_MANIFEST}"
}
migrate() { "${SCRIPT}" --user; }
kept() { [[ "$(cat "${CONFIG}/$1")" == "$2" ]] || fail "$1 should be kept as $2"; }
gone() { [[ ! -e "${CONFIG}/$1" ]] || fail "$1 should follow the image default"; }

ICONS=com.system76.CosmicTk/v1/icon_theme
FONT=com.system76.CosmicTk/v1/interface_font
DOCK=com.system76.CosmicAppList/v1/favorites
ACCENT=com.system76.CosmicTheme.Dark.Builder/v2/accent
BG=com.system76.CosmicTheme.Dark.Builder/v2/bg_color
LACCENT=com.system76.CosmicTheme.Light.Builder/v2/accent
LBG=com.system76.CosmicTheme.Light.Builder/v2/bg_color
XKB=com.system76.CosmicComp/v1/xkb_config

# An image from before: COSMIC's default icons, teal theme, a dock
image "${ICONS}" '"cosmic-blue"'
image "${FONT}" '"Open Sans"'
image "${DOCK}" '["firefox"]'
image "${ACCENT}" 'Some("#63D0DF")'
image "${BG}" 'None'
image "${LACCENT}" 'Some("#00525A")'
image "${LBG}" 'None'
image "${XKB}" '(layout: "us")'
# Fedora's packaged icon theme default, and a built-in one
mkdir -p "${WORK}/previous/com.system76.CosmicTk/v1"
printf '"Cosmic"' >"${WORK}/previous/${ICONS}"
"${SCRIPT}" --hash-tree "${WORK}/previous" >"${COSMIC_BLUE_PREVIOUS}"
manifest

# The account: icons from the old built-in default (no choice), a font of the
# user's own, a dock equal to the default written in another format, the
# dark theme copied by the first-run assistant, a light theme with the
# user's own accent, and the installer keyboard layout
account "${ICONS}" '"Cosmic"'
account "${FONT}" '"Fira Sans"'
account "${DOCK}" $'[\n    "firefox",\n]'
account "${ACCENT}" 'Some("#63D0DF")'
account "${BG}" 'None'
account "${LACCENT}" 'Some("#FF00FF")'
account "${LBG}" 'None'
account "${XKB}" '(layout: "us")'

migrate
gone "${ICONS}"      # previous default
kept "${FONT}" '"Fira Sans"'
gone "${DOCK}"       # current default, other format
gone "${ACCENT}"     # whole dark theme was a default
gone "${BG}"
[[ ! -d "${CONFIG}/com.system76.CosmicTheme.Dark.Builder" ]] || fail "empty theme directory left"
kept "${LACCENT}" 'Some("#FF00FF")'  # light theme: user's own accent, kept as a whole
kept "${LBG}" 'None'
kept "${XKB}" '(layout: "us")'       # set from the installer, never touched
grep -q '^manifest ' "${HOME}/.local/state/cosmic-blue/defaults.list" || fail "no state written"

# The user then picks values equal to defaults again: with no image change,
# nothing is looked at
account "${ICONS}" '"Cosmic"'
account "${DOCK}" '["firefox"]'
migrate
kept "${ICONS}" '"Cosmic"'
kept "${DOCK}" '["firefox"]'

# An update changes the dock and the dark accent: the dock copy equal to the
# default the account had is reset, the icons (default unchanged) are kept
image "${DOCK}" '["org.mozilla.firefox"]'
image "${ACCENT}" 'Some("#4F8DFF")'
manifest
account "${ACCENT}" 'Some("#63D0DF")'
account "${BG}" 'None'
migrate
gone "${DOCK}"
kept "${ICONS}" '"Cosmic"'
gone "${ACCENT}"
gone "${BG}"

# A dock of the user's own survives the next change
account "${DOCK}" '["org.mozilla.firefox", "org.gnome.Calculator"]'
image "${DOCK}" '["org.mozilla.firefox", "com.system76.CosmicTerm"]'
manifest
migrate
kept "${DOCK}" '["org.mozilla.firefox", "org.gnome.Calculator"]'

echo "migrate-defaults-test: OK"
