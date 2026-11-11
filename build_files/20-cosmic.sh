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
    adw-gtk3-theme \
    spice-vdagent

# spice-vdagent: in a VM (GNOME Boxes, virt-manager), clipboard sharing and
# following the window size. It only starts when a SPICE channel is present.

systemctl enable cosmic-greeter.service

# COSMIC's first-run assistant (cosmic-initial-setup) asks again for the
# language, keyboard layout and time zone, which Anaconda has already set.
# When ~/.config/gnome-initial-setup-done exists it skips those pages (and the
# Wi-Fi and account ones) and keeps accessibility, appearance, panel layout and
# the COSMIC introduction. New accounts get that file from /etc/skel.
mkdir -p /etc/skel/.config
touch /etc/skel/.config/gnome-initial-setup-done

systemctl set-default graphical.target

# Fedora's default wallpaper for this release (day/night), offered in COSMIC
# Settings next to the cosmic-blue one. (Fedora 44 has no extras package.)
dnf5 -y install "f${FEDORA_MAJOR_VERSION}-backgrounds-base"

# cosmic-blue defaults (wallpaper, theme) and boot logo (Plymouth watermark)
# were copied before these packages were installed; apply them again so they
# win over the packaged files.
cp -a /ctx/system_files/cosmic-blue/usr/share/cosmic/. /usr/share/cosmic/
cp -a /ctx/system_files/cosmic-blue/usr/share/plymouth/. /usr/share/plymouth/
# Dark GTK defaults (zz1-cosmic-blue.gschema.override)
glib-compile-schemas /usr/share/glib-2.0/schemas
