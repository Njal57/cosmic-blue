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

# Fedora's default wallpaper for this release (day/night), offered in COSMIC
# Settings next to the cosmic-blue one. (Fedora 44 has no extras package.)
dnf5 -y install "f${FEDORA_MAJOR_VERSION}-backgrounds-base"

# COSMIC Settings lists every image under /usr/share/backgrounds, following
# symlinks, so aliases (desktop-backgrounds-compat's default.png...) and
# copies show the same Fedora wallpaper many times. Keep one file per image.
echo "Wallpapers before removing duplicates:"
find /usr/share/backgrounds -printf '%y %p %l\n' | sort
while IFS= read -r -d '' link; do
    target="$(readlink -f "${link}" || true)"
    if [[ -z "${target}" || ! -e "${target}" || "${target}" == /usr/share/backgrounds/* ]]; then
        echo "Removing alias ${link} -> ${target}"
        rm -f "${link}"
    fi
done < <(find /usr/share/backgrounds -type l -print0)
declare -A seen_wallpapers=()
while IFS= read -r -d '' file; do
    hash="$(sha256sum "${file}" | cut -d' ' -f1)"
    if [[ -n "${seen_wallpapers[${hash}]:-}" ]]; then
        echo "Removing ${file}, same image as ${seen_wallpapers[${hash}]}"
        rm -f "${file}"
    else
        seen_wallpapers[${hash}]="${file}"
    fi
done < <(find /usr/share/backgrounds -type f -regextype egrep \
    -iregex '.*\.(png|jpe?g|jxl|webp|svg)' -print0 | sort -z)
find /usr/share/backgrounds -mindepth 1 -type d -empty -delete
echo "Wallpapers kept:"
find /usr/share/backgrounds -printf '%y %p %l\n' | sort

# cosmic-blue defaults (wallpaper, theme) and boot logo (Plymouth watermark)
# were copied before these packages were installed; apply them again so they
# win over the packaged files.
cp -a /ctx/system_files/cosmic-blue/usr/share/cosmic/. /usr/share/cosmic/
cp -a /ctx/system_files/cosmic-blue/usr/share/plymouth/. /usr/share/plymouth/
# Dark GTK defaults (zz1-cosmic-blue.gschema.override)
glib-compile-schemas /usr/share/glib-2.0/schemas
