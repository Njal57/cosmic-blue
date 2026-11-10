#!/usr/bin/bash
# Paquets ajoutés par Bluefin (build_files/base/04-packages.sh), sans ceux propres à GNOME.
set -euox pipefail

FEDORA_PACKAGES=(
    adcli
    adwaita-fonts-all
    autofs
    bash-color-prompt
    bcache-tools
    borgbackup
    containerd
    cryfs
    davfs2
    ddcutil
    evtest
    fastfetch
    firewall-config
    fish
    foo2zjs
    fuse-encfs
    gcc
    gcc-c++
    git-credential-libsecret
    glow
    gnupg2-scdaemon
    gum
    hplip
    ibus-mozc
    ifuse
    igt-gpu-tools
    input-remapper
    iwd
    jetbrains-mono-fonts-all
    just
    krb5-workstation
    libappindicator-gtk3
    libayatana-appindicator-gtk3
    libimobiledevice
    libratbag-ratbagd
    libxcrypt-compat
    lm_sensors
    make
    mesa-libGLU
    mozc
    oddjob-mkhomedir
    opendyslexic-fonts
    openssh-askpass
    powerstat
    powertop
    printer-driver-brlaser
    pulseaudio-utils
    python3-pip
    python3-pygit2
    rclone
    restic
    rsync
    samba
    samba-dcerpc
    samba-ldb-ldap-modules
    samba-winbind-clients
    samba-winbind-modules
    setools-console
    sssd-nfs-idmap
    switcheroo-control
    tmux
    usbip
    usbmuxd
    waypipe
    wireguard-tools
    wl-clipboard
    xdg-terminal-exec
    xprop
    zenity
    zsh
)
dnf5 -y install "${FEDORA_PACKAGES[@]}"

# Tailscale (dépôt officiel Tailscale, désactivé après usage)
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 config-manager setopt tailscale-stable.enabled=0
dnf5 -y install --enablerepo=tailscale-stable tailscale

# uupd (outil de mise à jour d'Universal Blue) depuis le COPR ublue-os/packages,
# activé seulement le temps de l'installation, comme dans Bluefin.
dnf5 -y copr enable ublue-os/packages
dnf5 -y install --repo="copr:copr.fedorainfracloud.org:ublue-os:packages" uupd
dnf5 -y copr disable ublue-os/packages

# Starship (invite de shell), binaire officiel
curl -fsSL --retry 3 -o /tmp/starship.tar.gz \
    https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
tar -xzf /tmp/starship.tar.gz -C /tmp
install -m 0755 /tmp/starship /usr/bin/starship

# Paquets retirés, comme dans Bluefin (Firefox passe en flatpak)
EXCLUDED_PACKAGES=(
    fedora-bookmarks
    fedora-chromium-config
    firefox
    firefox-langpacks
    podman-docker
)
readarray -t INSTALLED < <(rpm -qa --qf '%{NAME}\n' "${EXCLUDED_PACKAGES[@]}")
if [[ "${#INSTALLED[@]}" -gt 0 ]]; then
    dnf5 -y remove "${INSTALLED[@]}"
fi
