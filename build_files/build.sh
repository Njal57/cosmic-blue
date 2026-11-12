#!/usr/bin/bash
# cosmic-blue build entry point. Each step is a separate script.
set -euox pipefail

: "${IMAGE_NAME:=cosmic-blue}"
: "${IMAGE_VENDOR:=cosmic-blue-os}"
: "${UBLUE_IMAGE_TAG:=latest}"
: "${VERSION:=}"
export IMAGE_NAME IMAGE_VENDOR UBLUE_IMAGE_TAG VERSION
FEDORA_MAJOR_VERSION="$(rpm -E %fedora)"
export FEDORA_MAJOR_VERSION

for step in \
    10-system-files.sh \
    20-cosmic.sh \
    22-initial-setup.sh \
    23-greeter.sh \
    25-icon-theme.sh \
    30-packages.sh \
    35-nvidia.sh \
    40-image-info.sh \
    50-services.sh \
    60-initramfs.sh \
    90-cleanup.sh \
    99-tests.sh; do
    echo "::group:: ===${step}==="
    "/ctx/build_files/${step}"
    echo "::endgroup::"
done
