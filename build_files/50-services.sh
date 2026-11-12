#!/usr/bin/bash
# Services enabled by Bluefin (build_files/base/17-cleanup.sh), minus dconf-update (GNOME).
set -euox pipefail

systemctl enable \
    brew-setup.service \
    cosmic-blue-user-defaults.service \
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

# Flathub and the COSMIC flatpak repository (COSMIC applets and apps from
# System76) instead of the Fedora flatpak remote, both shown in COSMIC Store.
# Files in /usr/share/flatpak/remotes.d are added by flatpak itself the first
# time it opens the system installation, so systems installed before this
# change get them too; the remotes are also added now for new installs.
mkdir -p /usr/share/flatpak/remotes.d
curl --fail --retry 3 -sSL -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo
curl --fail --retry 3 -sSL -o /usr/share/flatpak/remotes.d/cosmic.flatpakrepo \
    https://apt.pop-os.org/cosmic/cosmic.flatpakrepo
for remote in flathub cosmic; do
    flatpak remote-add --system --if-not-exists "${remote}" \
        "/usr/share/flatpak/remotes.d/${remote}.flatpakrepo"
done
systemctl disable flatpak-add-fedora-repos.service || true
rm -f /usr/lib/systemd/system/flatpak-add-fedora-repos.service

# Hide a few useless menu entries (like Bluefin)
for app in fish htop nvtop; do
    if [[ -f "/usr/share/applications/${app}.desktop" ]]; then
        sed -i 's@\[Desktop Entry\]@[Desktop Entry]\nHidden=true@g' "/usr/share/applications/${app}.desktop"
    fi
done
