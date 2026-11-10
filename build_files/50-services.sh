#!/usr/bin/bash
# Services enabled by Bluefin (build_files/base/17-cleanup.sh), minus dconf-update (GNOME).
set -euox pipefail

systemctl enable \
    brew-setup.service \
    flatpak-nuke-fedora.service \
    flatpak-preinstall.service \
    input-remapper.service \
    rpm-ostree-countme.service \
    tailscaled.service \
    ublue-system-setup.service \
    uupd.timer

systemctl --global enable \
    podman-auto-update.timer \
    ublue-user-setup.service

# uupd replaces rpm-ostree automatic updates
systemctl disable rpm-ostreed-automatic.timer || true

# Flathub instead of the Fedora flatpak remote
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
systemctl disable flatpak-add-fedora-repos.service || true
rm -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service

# Hide a few useless menu entries (like Bluefin)
for app in fish htop nvtop; do
    if [[ -f "/usr/share/applications/${app}.desktop" ]]; then
        sed -i 's@\[Desktop Entry\]@[Desktop Entry]\nHidden=true@g' "/usr/share/applications/${app}.desktop"
    fi
done
