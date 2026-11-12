#!/usr/bin/bash
# cosmic-blue-dx build entry point, run on top of the cosmic-blue image.
# Reuses the base image steps that depend on the image name (identity,
# initramfs, cleanup).
set -euox pipefail

: "${IMAGE_NAME:=cosmic-blue-dx}"
: "${IMAGE_VENDOR:=cosmic-blue-os}"
: "${UBLUE_IMAGE_TAG:=latest}"
: "${VERSION:=}"
IMAGE_FLAVOR="dx"
FEDORA_MAJOR_VERSION="$(rpm -E %fedora)"
export IMAGE_NAME IMAGE_VENDOR UBLUE_IMAGE_TAG VERSION IMAGE_FLAVOR FEDORA_MAJOR_VERSION

for step in \
    dx/10-system-files.sh \
    dx/20-packages.sh \
    dx/30-services.sh \
    40-image-info.sh \
    60-initramfs.sh \
    90-cleanup.sh \
    dx/99-tests.sh; do
    echo "::group:: ===${step}==="
    "/ctx/build_files/${step}"
    echo "::endgroup::"
done
