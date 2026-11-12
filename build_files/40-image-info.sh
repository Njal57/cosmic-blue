#!/usr/bin/bash
# Image identity: image-info.json (used by ujust, uupd...) and os-release.
set -euox pipefail

# "cosmic-blue", or "cosmic-blue-dx" for the developer variant
IMAGE_PRETTY_NAME="${IMAGE_NAME}"
HOME_URL="https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}"
VERSION="${VERSION:-${FEDORA_MAJOR_VERSION}.$(date +%Y%m%d)}"

# The image is verified with cosign.pub (see 10-system-files.sh); without it,
# bootc cannot verify the signature and the image is referenced as "unverified".
if [[ -f /etc/pki/containers/cosmic-blue.pub ]]; then
    IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
else
    IMAGE_REF="ostree-unverified-registry:ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
fi

mkdir -p /usr/share/ublue-os
cat > /usr/share/ublue-os/image-info.json <<JSON
{
  "image-name": "${IMAGE_NAME}",
  "image-flavor": "${IMAGE_FLAVOR:-main}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "${UBLUE_IMAGE_TAG}",
  "base-image-name": "base",
  "fedora-version": "${FEDORA_MAJOR_VERSION}"
}
JSON

# Keep ID=fedora (avoids EFI/GRUB path issues); only change the displayed name.
sed -i "s|^NAME=.*|NAME=\"${IMAGE_PRETTY_NAME}\"|" /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${IMAGE_PRETTY_NAME} ${VERSION}\"|" /usr/lib/os-release
sed -i "s|^VARIANT_ID=.*|VARIANT_ID=${IMAGE_NAME}|" /usr/lib/os-release
sed -i "s|^HOME_URL=.*|HOME_URL=\"${HOME_URL}\"|" /usr/lib/os-release
sed -i "s|^SUPPORT_URL=.*|SUPPORT_URL=\"${HOME_URL}/issues\"|" /usr/lib/os-release
sed -i "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${HOME_URL}/issues\"|" /usr/lib/os-release
# Logo shown by COSMIC Settings (About) and fetch tools: an icon name
sed -i "/^LOGO=/d" /usr/lib/os-release
echo "LOGO=cosmic-blue-logo" >> /usr/lib/os-release
sed -i "/^IMAGE_ID=/d; /^IMAGE_VERSION=/d" /usr/lib/os-release
echo "IMAGE_ID=\"${IMAGE_NAME}\"" >> /usr/lib/os-release
echo "IMAGE_VERSION=\"${VERSION}\"" >> /usr/lib/os-release
