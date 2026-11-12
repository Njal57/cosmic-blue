#!/usr/bin/bash
# Install the Tela circle icon theme into /out, from upstream at a pinned
# commit (Fedora doesn't package it), with the folders and the blue parts of
# the application icons recolored to the cosmic-blue accent.
#
# Result: /out/Tela-circle-4f8dff (full theme) and /out/Tela-circle-4f8dff-dark
# (light monochrome icons for dark themes, links to the first one for the rest).
set -euxo pipefail

TELA_REPO="https://github.com/vinceliuice/Tela-circle-icon-theme.git"
TELA_COMMIT="ee3cf47bcb05c3d99a0860b54254d2ff3d1d2c69" # 2026-08-16
# Dark accent of build_files/theme/src/main.rs, without '#'
ACCENT="4f8dff"

dnf5 -y install git-core /usr/bin/gtk-update-icon-cache

SRC=/tmp/tela
git init -q "${SRC}"
git -C "${SRC}" fetch -q --depth 1 "${TELA_REPO}" "${TELA_COMMIT}"
git -C "${SRC}" checkout -q FETCH_HEAD
test "$(git -C "${SRC}" rev-parse HEAD)" = "${TELA_COMMIT}"

mkdir -p /out
# -c: circular folders. A hex color replaces the default blue everywhere the
# upstream color variants do (folders, application and device icons).
"${SRC}/install.sh" -c -d /out "${ACCENT}"

# Only the full theme and its dark variant are used.
rm -rf "/out/Tela-circle-${ACCENT}-light"

# Readable names in the settings, instead of the color code
sed -i "s/^Name=Tela circle ${ACCENT}/Name=Tela circle cosmic-blue/" \
    "/out/Tela-circle-${ACCENT}/index.theme" "/out/Tela-circle-${ACCENT}-dark/index.theme"
grep -qx 'Name=Tela circle cosmic-blue' "/out/Tela-circle-${ACCENT}/index.theme"
grep -qx 'Name=Tela circle cosmic-blue dark' "/out/Tela-circle-${ACCENT}-dark/index.theme"

# The default blue must be gone from the folders
if grep -rlq '#5294e2' "/out/Tela-circle-${ACCENT}/scalable/places/"; then
    echo "Folders not recolored" >&2
    exit 1
fi
