#!/usr/bin/bash
# Copy Bluefin's files (projectbluefin/common + ublue-os/brew), then ours,
# dropping everything that only matters for GNOME.
set -euox pipefail

# These base-main packages are replaced by projectbluefin/common files
# (same choice as Bluefin, see ublue-os/bluefin build_files/shared/build.sh).
readarray -t UBLUE_PKGS < <(rpm -qa --qf '%{NAME}\n' ublue-os-luks ublue-os-just ublue-os-udev-rules ublue-os-signing ublue-os-update-services)
if [[ "${#UBLUE_PKGS[@]}" -gt 0 ]]; then
    dnf5 -y remove "${UBLUE_PKGS[@]}"
fi

STAGE=/tmp/system_files
mkdir -p "${STAGE}"
cp -a /ctx/system_files/common/. "${STAGE}/"
cp -a /ctx/system_files/common-bluefin/. "${STAGE}/"
cp -a /ctx/system_files/brew/. "${STAGE}/"

# GNOME-specific files (or files for GNOME tools) and Bluefin branding we
# don't want in a COSMIC image.
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
# Bluefin branding: wallpapers, the dinosaur boot (Plymouth) watermark and the
# Bluefin logos that replace Fedora's. Fedora's own files are kept instead.
GNOME_ONLY+=(
    usr/share/backgrounds/bluefin
    usr/share/gnome-background-properties
    usr/share/plymouth
    usr/share/pixmaps/fedora-gdm-logo.png
    usr/share/pixmaps/fedora-logo-icon.png
    usr/share/pixmaps/fedora-logo-small.png
    usr/share/pixmaps/fedora-logo-sprite.png
    usr/share/pixmaps/fedora-logo.png
    usr/share/pixmaps/fedora_logo_med.png
    usr/share/pixmaps/fedora_whitelogo_med.png
    usr/share/pixmaps/system-logo-white.png
)
for path in "${GNOME_ONLY[@]}"; do
    rm -rf "${STAGE:?}/${path}"
done

cp -a "${STAGE}/." /
cp -a /ctx/system_files/cosmic-blue/. /

# Only accept key-signed cosmic-blue images (cosign.pub, signed by build.yml),
# including the developer variant, so that switching to it is verified too.
IMAGE="ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
jq --arg image "$IMAGE" '.transports.docker[$image, $image + "-dx"] = [{
    "type": "sigstoreSigned",
    "keyPath": "/etc/pki/containers/cosmic-blue.pub",
    "signedIdentity": {"type": "matchRepository"}
}]' /etc/containers/policy.json > /tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json
mkdir -p /etc/containers/registries.d
cat > /etc/containers/registries.d/cosmic-blue.yaml <<EOF
docker:
  ${IMAGE}:
    use-sigstore-attachments: true
  ${IMAGE}-dx:
    use-sigstore-attachments: true
EOF

# Bluefin faces (avatars) ship in a subfolder; move them up, as Bluefin does
if [[ -d /usr/share/pixmaps/faces/bluefin ]]; then
    rm -f /usr/share/pixmaps/faces/*.{png,jpg,svg} || true
    mv /usr/share/pixmaps/faces/bluefin/* /usr/share/pixmaps/faces/
    rmdir /usr/share/pixmaps/faces/bluefin
fi
