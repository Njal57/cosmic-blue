#!/usr/bin/bash
# COSMIC desktop, from the official Fedora repositories only.
set -euox pipefail

# For the build log: COSMIC groups available in this Fedora release
dnf5 group list --hidden | grep -i cosmic || true

# Comps group used by Fedora COSMIC (spin and Atomic). No COPR is enabled here,
# so COSMIC packages necessarily come from Fedora (checked in 99-tests.sh).
# @cosmic-desktop-apps is skipped: on Fedora it pulls KDE/GNOME apps
# (Okular, Rhythmbox, Nheko...) that we replace with flatpaks, like Bluefin.
dnf5 -y install \
    @cosmic-desktop \
    cosmic-edit \
    cosmic-files \
    cosmic-player \
    cosmic-term

# (no power-profiles-daemon: base-main already ships tuned-ppd)
# Desktop pieces that Fedora's Atomic image brings and base-main may lack
dnf5 -y install --skip-unavailable \
    NetworkManager-wifi \
    NetworkManager-openvpn \
    NetworkManager-openconnect \
    bluez \
    gnome-keyring \
    gnome-keyring-pam \
    pipewire-pulseaudio \
    wireplumber \
    plymouth-system-theme \
    xdg-desktop-portal-gtk \
    xdg-user-dirs \
    adw-gtk3-theme

systemctl enable cosmic-greeter.service
systemctl set-default graphical.target

# Fedora's wallpapers for this release (default day/night + extras), offered
# in COSMIC Settings next to the cosmic-blue one.
dnf5 -y install --skip-unavailable \
    "f${FEDORA_MAJOR_VERSION}-backgrounds-base" \
    "f${FEDORA_MAJOR_VERSION}-backgrounds-extras-base"
rpm -q "f${FEDORA_MAJOR_VERSION}-backgrounds-extras-base" || echo "No Fedora extra wallpapers for this release"

# cosmic-blue defaults (wallpaper...) were copied before COSMIC was installed;
# apply them again so they win over the files shipped by the packages.
cp -a /ctx/system_files/cosmic-blue/usr/share/cosmic/. /usr/share/cosmic/
