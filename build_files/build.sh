#!/usr/bin/bash
# Point d'entrée du build de COSMIC-blue. Chaque étape est un script séparé.
set -euox pipefail

: "${IMAGE_NAME:=cosmic-blue}"
: "${IMAGE_VENDOR:=njal57}"
: "${UBLUE_IMAGE_TAG:=latest}"
: "${VERSION:=}"
export IMAGE_NAME IMAGE_VENDOR UBLUE_IMAGE_TAG VERSION
FEDORA_MAJOR_VERSION="$(rpm -E %fedora)"
export FEDORA_MAJOR_VERSION

for step in \
    10-system-files.sh \
    20-cosmic.sh \
    30-packages.sh \
    40-image-info.sh \
    50-services.sh \
    60-initramfs.sh \
    90-cleanup.sh \
    99-tests.sh; do
    echo "::group:: ===${step}==="
    "/ctx/build_files/${step}"
    echo "::endgroup::"
done
