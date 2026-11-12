#!/usr/bin/bash
# Developer packages, from Bluefin DX (build_files/dx/00-dx.sh), without ROCm.
set -euox pipefail

FEDORA_PACKAGES=(
    android-tools
    bcc
    bpftop
    bpftrace
    cascadia-code-fonts
    cockpit-bridge
    cockpit-machines
    cockpit-networkmanager
    cockpit-ostree
    cockpit-podman
    cockpit-selinux
    cockpit-storaged
    cockpit-system
    dbus-x11
    edk2-ovmf
    flatpak-builder
    genisoimage
    git-subtree
    git-svn
    incus
    incus-agent
    iotop
    libvirt
    libvirt-nss
    lxc
    nicstat
    numactl
    osbuild-selinux
    p7zip
    p7zip-plugins
    podman-compose
    podman-machine
    podman-tui
    qemu
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt
    qemu-user-static
    sysprof
    tiptop
    trace-cmd
    udica
    util-linux-script
    virt-manager
    virt-v2v
    virt-viewer
    wtype
    ydotool
)
dnf5 -y install "${FEDORA_PACKAGES[@]}"

# Docker CE (official Docker repo, disabled after use). containerd.io replaces
# Fedora's containerd from the base image.
dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sed -i 's/enabled=.*/enabled=0/g' /etc/yum.repos.d/docker-ce.repo
dnf5 -y install --enablerepo=docker-ce-stable \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin

# Visual Studio Code (official Microsoft repo, disabled after use)
cat > /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=0
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
dnf5 -y install --enablerepo=code code

# A newer selinux-policy pulled in by these packages can undo rpm-ostree's
# /home -> /var/home equivalence; restore it (as Bluefin DX does).
sed -i 's|^/var/home[[:space:]]\+/home$|/home /var/home|' \
    /etc/selinux/targeted/contexts/files/file_contexts.subs_dist
