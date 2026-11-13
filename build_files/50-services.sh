#!/usr/bin/bash
# Services enabled by Bluefin (build_files/base/17-cleanup.sh), minus dconf-update (GNOME).
set -euox pipefail

systemctl enable \
    brew-setup.service \
    cosmic-blue-migrate-defaults.service \
    cosmic-blue-user-defaults.service \
    flatpak-nuke-fedora.service \
    flatpak-preinstall.service \
    input-remapper.service \
    rpm-ostree-countme.service \
    tailscaled.service \
    ublue-system-setup.service \
    uupd.timer

# Power management, already in base-main and enabled by Fedora's presets;
# enabled here too so a change in the base image cannot silently drop it.
# tuned-ppd is Fedora's power-profiles-daemon replacement: COSMIC's battery
# applet and Settings > Power use its D-Bus API to switch between power saver,
# balanced and performance, and on battery "balanced" uses tuned's
# balanced-battery profile (see /etc/tuned/ppd.conf). thermald (Intel CPUs
# only) keeps temperatures in check before the firmware throttles; it does not
# start in virtual machines.
systemctl enable \
    thermald.service \
    tuned.service \
    tuned-ppd.service

# podman.socket: rootless Docker-compatible API, used by the docker CLI through
# the "podman" context (user-setup hook 30-docker-podman.sh)
systemctl --global enable \
    podman-auto-update.timer \
    podman.socket \
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
