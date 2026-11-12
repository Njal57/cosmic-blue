#!/usr/bin/bash
# Build the "Bibata-Modern-cosmic-blue" cursor theme into /out: Bibata Modern
# (rounded) from upstream sources at a pinned release, recolored with the
# cosmic-blue colors. Fedora packages Bibata only in its upstream colors.
set -euxo pipefail

# Updated by Renovate (GitHub tags, see .github/renovate.json5)
BIBATA_REPO="https://github.com/ful1e5/Bibata_Cursor.git"
BIBATA_VERSION="v2.0.7"

dnf5 -y install git-core librsvg2-tools xcursorgen

SRC=/tmp/bibata
git init -q "${SRC}"
git -C "${SRC}" fetch -q --depth 1 "${BIBATA_REPO}" "refs/tags/${BIBATA_VERSION}"
git -C "${SRC}" checkout -q FETCH_HEAD

python3 "$(dirname "$0")/bibata.py" "${SRC}" /out/Bibata-Modern-cosmic-blue "${BIBATA_VERSION}"
