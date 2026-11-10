#!/usr/bin/bash
# Copie les fichiers de Bluefin (projectbluefin/common + ublue-os/brew) puis les nôtres,
# en retirant tout ce qui ne concerne que GNOME.
set -euox pipefail

# Ces paquets de base-main sont remplacés par les fichiers de projectbluefin/common
# (même choix que Bluefin, cf. ublue-os/bluefin build_files/shared/build.sh).
readarray -t UBLUE_PKGS < <(rpm -qa --qf '%{NAME}\n' ublue-os-luks ublue-os-just ublue-os-udev-rules ublue-os-signing ublue-os-update-services)
if [[ "${#UBLUE_PKGS[@]}" -gt 0 ]]; then
    dnf5 -y remove "${UBLUE_PKGS[@]}"
fi

STAGE=/tmp/system_files
mkdir -p "${STAGE}"
cp -a /ctx/system_files/common/. "${STAGE}/"
cp -a /ctx/system_files/common-bluefin/. "${STAGE}/"
cp -a /ctx/system_files/brew/. "${STAGE}/"

# Fichiers spécifiques à GNOME (ou à des outils GNOME) qu'on ne veut pas dans une image COSMIC.
GNOME_ONLY=(
    etc/dconf
    etc/gnome-initial-setup
    etc/environment                                    # GNOME_SHELL_SLOWDOWN_FACTOR
    etc/skel/.local/share/org.gnome.Ptyxis
    usr/lib/systemd/system/dconf-update.service
    usr/lib/systemd/user/bluefin-dynamic-wallpaper.service
    usr/lib/systemd/user/bluefin-dynamic-wallpaper.timer
    usr/libexec/bluefin-dynamic-wallpaper
    usr/lib/systemd/user/damask.service
    usr/lib/tmpfiles.d/damask-flatpak.conf
    usr/share/ublue-os/flatpak-overrides/app.drey.Damask
    usr/lib/systemd/user/compass.service
    usr/lib/systemd/user-preset/01-compass.preset
    usr/share/ublue-os/homebrew/preinstall.d/compass.Brewfile
    usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override
    usr/share/xdg-terminal-exec/gnome-xdg-terminals.list
    usr/share/ublue-os/user-setup.hooks.d/10-theming.sh
    usr/share/ublue-os/user-setup.hooks.d/20-dynamic-wallpaper.sh
    usr/share/ublue-os/user-setup.hooks.d/25-damask-setup.sh
)
for path in "${GNOME_ONLY[@]}"; do
    rm -rf "${STAGE:?}/${path}"
done

cp -a "${STAGE}/." /
cp -a /ctx/system_files/cosmic-blue/. /

# Les visages (avatars) Bluefin sont rangés dans un sous-dossier, comme dans Bluefin
if [[ -d /usr/share/pixmaps/faces/bluefin ]]; then
    rm -f /usr/share/pixmaps/faces/*.{png,jpg,svg} || true
    mv /usr/share/pixmaps/faces/bluefin/* /usr/share/pixmaps/faces/
    rmdir /usr/share/pixmaps/faces/bluefin
fi
