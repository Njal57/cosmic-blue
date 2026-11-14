#!/usr/bin/bash
# Packages added by Bluefin (build_files/base/04-packages.sh), minus GNOME-specific ones.
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
    mokutil  # ujust enroll-secure-boot-key (Secure Boot keys)
    mozc
    oddjob-mkhomedir
    opendyslexic-fonts
    openssh-askpass
    openssl
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

# Everyday pieces that Fedora Workstation (and so Bluefin) has but our
# base-main + COSMIC image lacks. Codecs, CUPS, SANE, Liberation and the
# default Fedora fonts already come with base-main and the COSMIC group.
EVERYDAY_PACKAGES=(
    # Printing: rootless printer setup through polkit (system-config-printer),
    # and the PPD drivers Fedora Workstation ships for older printers
    cups-pk-helper
    foomatic
    foomatic-db-ppds
    # Fonts metric-compatible with Calibri and Cambria, so Office documents
    # keep their layout (Liberation already covers Arial, Times and Courier)
    google-carlito-fonts
    google-crosextra-caladea-fonts
    # Disks: format USB drives, partitions, disk images, SMART data.
    # COSMIC has no disk tool and GNOME Disks is not on Flathub.
    gnome-disk-utility
    # PDF and e-book previews in COSMIC Files (videos already have
    # ffmpegthumbnailer)
    papers-thumbnailer
    gnome-epub-thumbnailer
    # Extracts the Microsoft core fonts for `ujust install-microsoft-fonts`
    cabextract
)
dnf5 -y install "${EVERYDAY_PACKAGES[@]}"

# Tailscale (official Tailscale repo, disabled after use)
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 config-manager setopt tailscale-stable.enabled=0
dnf5 -y install --enablerepo=tailscale-stable tailscale

# uupd (Universal Blue's update tool) from the ublue-os/packages COPR,
# enabled only during the install, as in Bluefin.
dnf5 -y copr enable ublue-os/packages
dnf5 -y install --repo="copr:copr.fedorainfracloud.org:ublue-os:packages" uupd
dnf5 -y copr disable ublue-os/packages

# Nerd Font symbols (icons of fastfetch and Starship), from the che/nerd-fonts
# COPR as in Bluefin, enabled only during the install
dnf5 -y copr enable che/nerd-fonts
dnf5 -y install --repo="copr:copr.fedorainfracloud.org:che:nerd-fonts" nerd-fonts
dnf5 -y copr disable che/nerd-fonts

# Starship (shell prompt), official binary
curl -fsSL --retry 3 -o /tmp/starship.tar.gz \
    https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
tar -xzf /tmp/starship.tar.gz -C /tmp
install -m 0755 /tmp/starship /usr/bin/starship

# Removed packages, as in Bluefin (Firefox comes as a flatpak)
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
