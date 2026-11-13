#!/usr/bin/bash
# Boot smoke test: installs the image to a virtual disk with `bootc install`,
# boots it in QEMU (UEFI, KVM) and checks over SSH that the system starts
# cleanly and that the COSMIC login screen is up. Then logs in a test user
# and takes screenshots of the desktop (desktop_tour in vm-lib.sh).
#
# Usage: tests/vm-boot-test.sh <image> <output dir>
#   <image> must be in the root (sudo) podman storage.
# Needs: podman, qemu-system-x86_64, OVMF, socat, openssh-client, jq, KVM.
set -euo pipefail
trap 'echo "::error::Command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

IMAGE="$1"
OUT="$(realpath -m "$2")"
TARGET_IMGREF="${TARGET_IMGREF:-ghcr.io/cosmic-blue-os/cosmic-blue:latest}"
# shellcheck source=tests/vm-lib.sh
source "$(dirname "$0")/vm-lib.sh"

vm_install "${IMAGE}" "${TARGET_IMGREF}"
vm_start
vm_wait_ssh

errors=0
vm_check_system boot || errors=1
vm "bootc status --json" | jq -e --arg ref "${TARGET_IMGREF}" \
    '.status.booted.image.image.image == $ref' >/dev/null \
    || { echo "::error::The booted image is not ${TARGET_IMGREF}"; errors=1; }

# Let the login screen draw, then take a picture of it
sleep 20
screenshot login-screen

if (( errors == 0 )); then
    desktop_tour || true
    demo_journal
fi

(( errors == 0 )) || fail "Boot test failed (see the logs and screenshot in the artifacts)"
log "Boot test passed"
