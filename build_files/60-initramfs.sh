#!/usr/bin/bash
# Regenerate the initramfs so added dracut configs (e.g. TPM/passkeys) take effect.
set -euox pipefail

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | head -n1)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KVER}" --reproducible -v --add ostree -f "/usr/lib/modules/${KVER}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
