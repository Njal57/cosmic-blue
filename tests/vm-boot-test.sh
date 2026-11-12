#!/usr/bin/bash
# Boot smoke test: installs the image to a virtual disk with `bootc install`,
# boots it in QEMU (UEFI, KVM) and checks over SSH that the system starts
# cleanly and that the COSMIC login screen is up. Then logs in a test user
# and takes screenshots of the desktop (see desktop_tour below).
#
# Usage: tests/vm-boot-test.sh <image> <output dir>
#   <image> must be in the root (sudo) podman storage.
# Needs: podman, qemu-system-x86_64, OVMF, socat, openssh-client, KVM.
set -euo pipefail
trap 'echo "::error::Command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

IMAGE="$1"
OUT="$(realpath -m "$2")"
TARGET_IMGREF="${TARGET_IMGREF:-ghcr.io/cosmic-blue-os/cosmic-blue:latest}"
WORK="$(mktemp -d -p "${RUNNER_TEMP:-/var/tmp}" cosmic-blue-vm.XXXXXX)"
SSH_PORT=2222
mkdir -p "${OUT}"

log() { echo "::notice::$*"; }
fail() { echo "::error::$*"; exit 1; }

cleanup() {
    if [[ -f "${WORK}/qemu.pid" ]]; then
        sudo kill "$(cat "${WORK}/qemu.pid")" 2>/dev/null || true
    fi
    sudo rm -rf "${WORK}"
}
trap cleanup EXIT

# 1. Install the image to a raw disk, as a user would with a bootc installer
ssh-keygen -q -t ed25519 -N '' -f "${WORK}/id_ed25519"
truncate -s 40G "${WORK}/disk.raw"
log "Installing ${IMAGE} to a virtual disk"
# console=ttyS0: boot messages go to the serial log.
# systemd.wants=sshd.service: SSH for the checks below, only in this test.
sudo podman run --rm --privileged --pid=host \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers:/var/lib/containers \
    -v /dev:/dev \
    -v "${WORK}:/output" \
    "${IMAGE}" \
    bootc install to-disk --via-loopback --generic-image --wipe \
        --target-imgref "${TARGET_IMGREF}" \
        --root-ssh-authorized-keys /output/id_ed25519.pub \
        --karg console=tty0 --karg console=ttyS0,115200 \
        --karg systemd.wants=sshd.service \
        /output/disk.raw

# 2. Boot it (UEFI, like most PCs and GNOME Boxes)
first_file() {
    local f
    for f in "$@"; do
        if [[ -f "${f}" ]]; then echo "${f}"; return; fi
    done
}
ovmf_code="$(first_file /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd)"
ovmf_vars="$(first_file /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/edk2/ovmf/OVMF_VARS.fd)"
[[ -n "${ovmf_code}" && -n "${ovmf_vars}" ]] || fail "OVMF firmware not found"
cp "${ovmf_vars}" "${WORK}/vars.fd"
sudo chown "$(id -u):$(id -g)" "${WORK}/disk.raw"

log "Booting the virtual machine"
qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -smp 2 -m 4096 \
    -drive if=pflash,format=raw,readonly=on,file="${ovmf_code}" \
    -drive if=pflash,format=raw,file="${WORK}/vars.fd" \
    -drive file="${WORK}/disk.raw",format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-vga,xres=1920,yres=1080 \
    -display none \
    -serial file:"${OUT}/serial.log" \
    -monitor unix:"${WORK}/monitor.sock",server,nowait \
    -pidfile "${WORK}/qemu.pid" -daemonize

vm() {
    ssh -q -i "${WORK}/id_ed25519" -p "${SSH_PORT}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o BatchMode=yes root@127.0.0.1 "$@"
}
monitor() {
    echo "$*" | socat - UNIX-CONNECT:"${WORK}/monitor.sock" >/dev/null
}
screenshot() {
    local name="$1"
    echo "screendump ${OUT}/${name}.png -f png" | socat - UNIX-CONNECT:"${WORK}/monitor.sock" >/dev/null || true
    sleep 2
    if [[ ! -s "${OUT}/${name}.png" ]]; then
        echo "screendump ${OUT}/${name}.ppm" | socat - UNIX-CONNECT:"${WORK}/monitor.sock" >/dev/null || true
    fi
}

# 3. Wait for SSH (first boot can take a few minutes)
deadline=$((SECONDS + 600))
until vm true 2>/dev/null; do
    if (( SECONDS > deadline )); then
        screenshot no-ssh
        tail -n 50 "${OUT}/serial.log" || true
        fail "The virtual machine did not answer over SSH within 10 minutes"
    fi
    sleep 10
done
log "The virtual machine is up (after ${SECONDS}s)"

# 4. Checks
state="$(vm 'timeout 300 systemctl is-system-running --wait' || true)"
vm 'journalctl -b --no-pager' > "${OUT}/journal.log" || true
vm 'bootc status' > "${OUT}/bootc-status.txt" || true
cat "${OUT}/bootc-status.txt"
errors=0

# Units that fail because of the CI machine, not the image:
# - mcelog: "AMD Processor family 26: mcelog does not support this processor"
# - EXTRA_IGNORED_UNITS (e.g. "nvidia-persistenced|nvidia-cdi-refresh"):
#   units that need hardware the virtual machine lacks, such as an NVIDIA GPU
#   (nvidia-cdi-refresh.path fails with its service)
IGNORED_UNITS="^(mcelog${EXTRA_IGNORED_UNITS:+|${EXTRA_IGNORED_UNITS}})\\.(service|path) "
all_failed="$(vm 'systemctl --failed --no-legend --plain' || true)"
failed="$(grep -vE "${IGNORED_UNITS}" <<< "${all_failed}" | grep -v '^$' || true)"
if [[ -n "${all_failed}" ]]; then
    echo "Failed units (including the ignored ones):"
    echo "${all_failed}"
fi
if [[ "${state}" != running && "${state}" != degraded ]] || [[ -n "${failed}" ]]; then
    echo "::error::System state is '${state}'. Failed units:"
    echo "${failed}"
    for unit in $(awk '{print $1}' <<< "${failed}"); do
        vm "journalctl -b -u ${unit} --no-pager -n 30" || true
    done
    errors=1
fi

vm "bootc status --json" | jq -e --arg ref "${TARGET_IMGREF}" \
    '.status.booted.image.image.image == $ref' >/dev/null \
    || { echo "::error::The booted image is not ${TARGET_IMGREF}"; errors=1; }

# NVIDIA image: bootc applied its kernel arguments (usr/lib/bootc/kargs.d)
if [[ "${TARGET_IMGREF}" == *-nvidia:* ]]; then
    vm 'grep -q nvidia-drm.modeset=1 /proc/cmdline && grep -q modprobe.blacklist=nouveau /proc/cmdline' \
        || { echo "::error::The NVIDIA kernel arguments are missing"; vm 'cat /proc/cmdline' || true; errors=1; }
fi

vm 'systemctl is-active cosmic-greeter.service' \
    || { echo "::error::cosmic-greeter.service is not active"; errors=1; }

# The login screen runs its own compositor
deadline=$((SECONDS + 120))
until vm 'pgrep -x cosmic-comp' >/dev/null; do
    if (( SECONDS > deadline )); then
        echo "::error::The login screen compositor (cosmic-comp) is not running"
        vm 'journalctl -b -u cosmic-greeter.service --no-pager -n 80' || true
        errors=1
        break
    fi
    sleep 5
done

# Let the login screen draw, then take a picture of it
sleep 20
screenshot login-screen
vm 'journalctl -b -p warning --no-pager' > "${OUT}/journal-warnings.log" || true

# 5. Desktop screenshots, to check the look without a PC: logs a test user
# in through the login screen, then opens a few views and apps. Problems here
# are warnings, not failures: they don't keep a working image from shipping.
# Files are numbered in the order they are taken (tests/screenshot-sheet.py).
DEMO_USER=demo
DEMO_PASSWORD=cosmicblue  # letters only: typed as US QWERTY key codes below

type_text() {
    local i
    for (( i = 0; i < ${#1}; i++ )); do
        monitor "sendkey ${1:i:1}"
        sleep 0.15
    done
}
wait_for() {
    local seconds="$1"; shift
    local deadline=$((SECONDS + seconds))
    until vm "$@" >/dev/null 2>&1; do
        (( SECONDS > deadline )) && return 1
        sleep 3
    done
}
warn() { echo "::warning::Desktop screenshots: $*"; }

desktop_tour() {
    local shots=screenshots
    mkdir -p "${OUT}/${shots}"

    # A user for the login screen to show (it reads the accounts when it starts)
    vm "useradd -m -c cosmic-blue ${DEMO_USER} && echo ${DEMO_USER}:${DEMO_PASSWORD} | chpasswd" \
        || { warn "could not create the test user"; return 1; }
    vm 'systemctl restart cosmic-greeter.service' \
        || { warn "could not restart the login screen"; return 1; }
    wait_for 120 'pgrep -x cosmic-greeter' || { warn "the login screen did not come back"; return 1; }
    sleep 20
    screenshot "${shots}/01-login-screen"

    # Log in with the keyboard, as a person would
    type_text "${DEMO_PASSWORD}"
    monitor "sendkey ret"
    if ! wait_for 120 "pgrep -u ${DEMO_USER} -x cosmic-panel"; then
        screenshot "${shots}/02-login-failed"
        warn "the test user did not get a COSMIC session"
        vm 'journalctl -b -u cosmic-greeter.service --no-pager -n 60' || true
        return 1
    fi
    local uid run_dir wayland
    uid="$(vm "id -u ${DEMO_USER}")"
    run_dir="/run/user/${uid}"
    wayland="$(vm "ls ${run_dir} | grep -E '^wayland-[0-9]+\$' | head -n 1")"
    [[ -n "${wayland}" ]] || { warn "no Wayland socket in ${run_dir}"; return 1; }

    # First login: COSMIC's first-run assistant (cosmic-initial-setup).
    # Closed without finishing it, so the desktop keeps the image defaults.
    sleep 30
    screenshot "${shots}/02-first-run"
    vm "pkill -u ${DEMO_USER} -f cosmic-initial-setup" || true
    sleep 8
    screenshot "${shots}/03-desktop"

    # App Library (Super+A): the application icons
    monitor "sendkey meta_l-a"
    sleep 5
    screenshot "${shots}/04-app-library"
    monitor "sendkey esc"
    sleep 3

    # Files (folder icons), Settings (accent, theme), Terminal
    local entry name cmd
    for entry in "05-files|cosmic-files" "06-settings|cosmic-settings appearance" \
            "07-terminal|cosmic-term"; do
        name="${entry%%|*}"
        cmd="${entry#*|}"
        if ! vm "runuser -u ${DEMO_USER} -- env XDG_RUNTIME_DIR=${run_dir} WAYLAND_DISPLAY=${wayland} \
                DBUS_SESSION_BUS_ADDRESS=unix:path=${run_dir}/bus \
                setsid -f ${cmd} >/dev/null 2>&1 </dev/null"; then
            warn "could not start ${cmd}"
            continue
        fi
        sleep 12
        screenshot "${shots}/${name}"
        vm "pkill -u ${DEMO_USER} -f '^(/usr/bin/)?${cmd%% *}'" || true
        sleep 3
    done

    # Lock screen
    vm 'loginctl lock-sessions' || { warn "could not lock the session"; return 1; }
    sleep 8
    screenshot "${shots}/08-lock-screen"
}

if (( errors == 0 )); then
    desktop_tour || true
    vm "journalctl -b _UID=\$(id -u ${DEMO_USER}) --no-pager" > "${OUT}/journal-${DEMO_USER}.log" 2>/dev/null || true
fi

(( errors == 0 )) || fail "Boot test failed (see the logs and screenshot in the artifacts)"
log "Boot test passed"
