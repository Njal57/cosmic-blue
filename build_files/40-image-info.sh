#!/usr/bin/bash
# Image identity: image-info.json (used by ujust, uupd...) and os-release.
set -euox pipefail

IMAGE_PRETTY_NAME="COSMIC-blue"
HOME_URL="https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}"
VERSION="${VERSION:-${FEDORA_MAJOR_VERSION}.$(date +%Y%m%d)}"

# Until the image is signed with a key (no cosign.pub in the repo), bootc cannot
# verify the signature, so the image is referenced as "unverified".
if [[ -f /etc/pki/containers/cosmic-blue.pub ]]; then
    IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
else
    IMAGE_REF="ostree-unverified-registry:ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
fi

mkdir -p /usr/share/ublue-os
cat > /usr/share/ublue-os/image-info.json <<JSON
{
  "image-name": "${IMAGE_NAME}",
  "image-flavor": "main",
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
sed -i "/^IMAGE_ID=/d; /^IMAGE_VERSION=/d" /usr/lib/os-release
echo "IMAGE_ID=\"${IMAGE_NAME}\"" >> /usr/lib/os-release
echo "IMAGE_VERSION=\"${VERSION}\"" >> /usr/lib/os-release
