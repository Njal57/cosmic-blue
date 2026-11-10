#!/usr/bin/bash
# Régénère l'initramfs pour prendre en compte les confs dracut ajoutées (ex. TPM/passkeys).
set -euox pipefail

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | head -n1)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KVER}" --reproducible -v --add ostree -f "/usr/lib/modules/${KVER}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
