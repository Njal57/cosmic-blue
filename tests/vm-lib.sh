#!/usr/bin/bash
# Shared helpers of the virtual machine tests (vm-boot-test.sh,
# vm-update-test.sh): install an image to a virtual disk with `bootc install`,
# boot it in QEMU (UEFI, KVM), run commands over SSH, check the system,
# reboot, take screenshots and log in to the desktop.
#
# Source it after setting OUT (output directory); it sets WORK (scratch
# directory, removed on exit).
# Needs: podman, qemu-system-x86_64, OVMF, socat, openssh-client, jq, KVM.

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

# Installs an image to a raw disk, as a user would with a bootc installer.
# Usage: vm_install <image in the root podman storage> <target image ref>
# console=ttyS0: boot messages go to the serial log.
# systemd.wants=sshd.service: SSH for the checks, only in these tests (bootc
# keeps the kernel arguments across updates).
vm_install() {
    local image="$1" target="$2"
    ssh-keygen -q -t ed25519 -N '' -f "${WORK}/id_ed25519"
    truncate -s 40G "${WORK}/disk.raw"
    log "Installing ${image} to a virtual disk"
    sudo podman run --rm --privileged --pid=host \
        --security-opt label=type:unconfined_t \
        -v /var/lib/containers:/var/lib/containers \
        -v /dev:/dev \
        -v "${WORK}:/output" \
        "${image}" \
        bootc install to-disk --via-loopback --generic-image --wipe \
            --target-imgref "${target}" \
            --root-ssh-authorized-keys /output/id_ed25519.pub \
            --karg console=tty0 --karg console=ttyS0,115200 \
            --karg systemd.wants=sshd.service \
            /output/disk.raw
    sudo chown "$(id -u):$(id -g)" "${WORK}/disk.raw"
}

# Boots the disk (UEFI, like most PCs and GNOME Boxes)
vm_start() {
    local f ovmf_code="" ovmf_vars=""
    for f in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd \
            /usr/share/edk2/ovmf/OVMF_CODE.fd; do
        if [[ -f "${f}" ]]; then ovmf_code="${f}"; break; fi
    done
    for f in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd \
            /usr/share/edk2/ovmf/OVMF_VARS.fd; do
        if [[ -f "${f}" ]]; then ovmf_vars="${f}"; break; fi
    done
    [[ -n "${ovmf_code}" && -n "${ovmf_vars}" ]] || fail "OVMF firmware not found"
    cp "${ovmf_vars}" "${WORK}/vars.fd"

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
}

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

# Waits for SSH (a boot can take a few minutes)
# Usage: vm_wait_ssh [name of the screenshot taken on timeout]
vm_wait_ssh() {
    local deadline=$((SECONDS + 600))
    until vm true 2>/dev/null; do
        if (( SECONDS > deadline )); then
            screenshot "${1:-no-ssh}"
            tail -n 50 "${OUT}/serial.log" || true
            fail "The virtual machine did not answer over SSH within 10 minutes"
        fi
        sleep 10
    done
    log "The virtual machine is up"
}

# Reboots and waits for the new boot to answer over SSH
vm_reboot() {
    local old new deadline=$((SECONDS + 600))
    old="$(vm cat /proc/sys/kernel/random/boot_id)"
    log "Rebooting the virtual machine"
    vm 'systemctl reboot' || true
    until new="$(vm cat /proc/sys/kernel/random/boot_id 2>/dev/null)" && [[ "${new}" != "${old}" ]]; do
        if (( SECONDS > deadline )); then
            screenshot "no-reboot"
            tail -n 50 "${OUT}/serial.log" || true
            fail "The virtual machine did not come back within 10 minutes of the reboot"
        fi
        sleep 10
    done
    log "The virtual machine is back"
}

# Digest of the image the system booted
vm_booted_digest() {
    vm 'bootc status --json' | jq -r '.status.booted.image.imageDigest'
}

# Checks that the system started cleanly and the login screen is up.
# Usage: vm_check_system <label>
#   Logs go to OUT with the label in their name. Returns 1 if a check failed;
#   prints the problems as GitHub errors, or as warnings when
#   CHECK_LEVEL=warning.
vm_check_system() {
    local label="$1" level="${CHECK_LEVEL:-error}" errors=0
    local state all_failed failed unit deadline

    state="$(vm 'timeout 300 systemctl is-system-running --wait' || true)"
    vm 'journalctl -b --no-pager' > "${OUT}/journal-${label}.log" || true
    vm 'bootc status' > "${OUT}/bootc-status-${label}.txt" || true
    cat "${OUT}/bootc-status-${label}.txt"

    # Units that fail because of the CI machine, not the image:
    # - mcelog: "AMD Processor family 26: mcelog does not support this processor"
    # - EXTRA_IGNORED_UNITS (e.g. "nvidia-persistenced|nvidia-cdi-refresh"):
    #   units that need hardware the virtual machine lacks, such as an NVIDIA
    #   GPU (nvidia-cdi-refresh.path fails with its service)
    local ignored="^(mcelog${EXTRA_IGNORED_UNITS:+|${EXTRA_IGNORED_UNITS}})\\.(service|path) "
    all_failed="$(vm 'systemctl --failed --no-legend --plain' || true)"
    failed="$(grep -vE "${ignored}" <<< "${all_failed}" | grep -v '^$' || true)"
    if [[ -n "${all_failed}" ]]; then
        echo "Failed units (including the ignored ones):"
        echo "${all_failed}"
    fi
    if [[ "${state}" != running && "${state}" != degraded ]] || [[ -n "${failed}" ]]; then
        echo "::${level}::${label}: system state is '${state}'. Failed units: $(awk '{print $1}' <<< "${failed}" | xargs)"
        for unit in $(awk '{print $1}' <<< "${failed}"); do
            vm "journalctl -b -u ${unit} --no-pager -n 30" || true
        done
        errors=1
    fi

    # NVIDIA image: bootc applied its kernel arguments (usr/lib/bootc/kargs.d)
    if vm 'bootc status --json' | jq -e '.status.booted.image.image.image | test("-nvidia[:@]")' >/dev/null; then
        vm 'grep -q nvidia-drm.modeset=1 /proc/cmdline && grep -q modprobe.blacklist=nouveau /proc/cmdline' \
            || { echo "::${level}::${label}: the NVIDIA kernel arguments are missing"; vm 'cat /proc/cmdline' || true; errors=1; }
    fi

    vm 'systemctl is-active cosmic-greeter.service' \
        || { echo "::${level}::${label}: cosmic-greeter.service is not active"; errors=1; }

    # The login screen runs its own compositor
    deadline=$((SECONDS + 120))
    until vm 'pgrep -x cosmic-comp' >/dev/null; do
        if (( SECONDS > deadline )); then
            echo "::${level}::${label}: the login screen compositor (cosmic-comp) is not running"
            vm 'journalctl -b -u cosmic-greeter.service --no-pager -n 80' || true
            errors=1
            break
        fi
        sleep 5
    done
    vm 'journalctl -b -p warning --no-pager' > "${OUT}/journal-warnings-${label}.log" || true
    return "${errors}"
}

# Desktop screenshots, to check the look without a PC: logs a test user in
# through the login screen, then opens a few views and apps. Problems here are
# warnings, not failures: they don't keep a working image from shipping.
# Files are numbered in the order they are taken (tests/screenshot-sheet.py).
DEMO_USER=demo
DEMO_PASSWORD=cosmicblue  # letters only: typed as US QWERTY key codes below
SHOTS=screenshots

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

# Creates the test user if needed and shows it on the login screen (the
# login screen reads the accounts when it starts)
demo_user() {
    if ! vm "id ${DEMO_USER}" >/dev/null 2>&1; then
        vm "useradd -m -c cosmic-blue ${DEMO_USER} && echo ${DEMO_USER}:${DEMO_PASSWORD} | chpasswd" \
            || { warn "could not create the test user"; return 1; }
    fi
    vm 'systemctl restart cosmic-greeter.service' \
        || { warn "could not restart the login screen"; return 1; }
    wait_for 120 'pgrep -x cosmic-greeter' || { warn "the login screen did not come back"; return 1; }
    sleep 20
}

# Logs the test user in with the keyboard, as a person would, and sets
# DEMO_ENV to the environment of its session.
# Usage: demo_login <name of the screenshot taken if it fails>
demo_login() {
    mkdir -p "${OUT}/${SHOTS}"
    type_text "${DEMO_PASSWORD}"
    monitor "sendkey ret"
    if ! wait_for 120 "pgrep -u ${DEMO_USER} -x cosmic-panel"; then
        screenshot "${SHOTS}/$1"
        warn "the test user did not get a COSMIC session"
        vm 'journalctl -b -u cosmic-greeter.service --no-pager -n 60' || true
        return 1
    fi
    local uid run_dir wayland
    uid="$(vm "id -u ${DEMO_USER}")"
    run_dir="/run/user/${uid}"
    wayland="$(vm "ls ${run_dir} | grep -E '^wayland-[0-9]+\$' | head -n 1")"
    [[ -n "${wayland}" ]] || { warn "no Wayland socket in ${run_dir}"; return 1; }
    DEMO_ENV="XDG_RUNTIME_DIR=${run_dir} WAYLAND_DISPLAY=${wayland} DBUS_SESSION_BUS_ADDRESS=unix:path=${run_dir}/bus"
}

# The whole tour: login screen, first login, desktop, App Library, a few apps
# and the lock screen
desktop_tour() {
    mkdir -p "${OUT}/${SHOTS}"
    demo_user || return 1
    screenshot "${SHOTS}/01-login-screen"
    demo_login 02-login-failed || return 1

    # First login: COSMIC's first-run assistant (cosmic-initial-setup).
    # Closed without finishing it, so the desktop keeps the image defaults.
    # (It does not start again for a user who already logged in.)
    sleep 30
    if vm "pgrep -u ${DEMO_USER} -f cosmic-initial-setup" >/dev/null; then
        screenshot "${SHOTS}/02-first-run"
        vm "pkill -u ${DEMO_USER} -f cosmic-initial-setup" || true
        sleep 8
    fi
    screenshot "${SHOTS}/03-desktop"

    # App Library (Super+A): the application icons
    monitor "sendkey meta_l-a"
    sleep 5
    screenshot "${SHOTS}/04-app-library"
    monitor "sendkey esc"
    sleep 3

    # Files (folder icons), Settings (accent, theme), Terminal (fastfetch)
    local entry name cmd
    for entry in "05-files|cosmic-files" "06-settings|cosmic-settings appearance" \
            "07-terminal|cosmic-term"; do
        name="${entry%%|*}"
        cmd="${entry#*|}"
        if ! vm "runuser -u ${DEMO_USER} -- env ${DEMO_ENV} \
                setsid -f ${cmd} >/dev/null 2>&1 </dev/null"; then
            warn "could not start ${cmd}"
            continue
        fi
        sleep 12
        if [[ "${name}" == 07-terminal ]]; then
            # fastfetch, to check the logo as COSMIC Terminal really draws it
            type_text ff
            monitor "sendkey ret"
            sleep 6
        fi
        screenshot "${SHOTS}/${name}"
        vm "pkill -u ${DEMO_USER} -f '^(/usr/bin/)?${cmd%% *}'" || true
        sleep 3
    done

    # Lock screen
    vm 'loginctl lock-sessions' || { warn "could not lock the session"; return 1; }
    sleep 8
    screenshot "${SHOTS}/08-lock-screen"
}

# Saves the journal of the test user's session
demo_journal() {
    vm "journalctl -b _UID=\$(id -u ${DEMO_USER}) --no-pager" > "${OUT}/journal-${DEMO_USER}${1:+-$1}.log" 2>/dev/null || true
}
