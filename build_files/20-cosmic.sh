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
