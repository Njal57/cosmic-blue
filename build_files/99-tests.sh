#!/usr/bin/bash
# Simple checks: if one fails, the build fails.
set -euox pipefail

# ublue signing keys present (otherwise updates from ghcr.io/ublue-os are impossible)
jq -e '.transports.docker."ghcr.io/ublue-os"' /etc/containers/policy.json >/dev/null
# No Bluefin wallpapers or boot watermark
test ! -e /usr/share/backgrounds/bluefin
# cosmic-blue wallpaper is the COSMIC default, and the logo is installed
test -s /usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg
grep -q 'Path("/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg")' \
    /usr/share/cosmic/com.system76.CosmicBackground/v1/all
test -s /usr/share/icons/hicolor/scalable/apps/cosmic-blue-logo.svg
grep -q '^LOGO=cosmic-blue-logo$' /usr/lib/os-release
if rpm -q plymouth-theme-spinner; then
    rpm -V --nomode --nouser --nogroup --nomtime plymouth-theme-spinner
fi

# cosmic-blue signing key and policy, and the signed image reference
test -s /etc/pki/containers/cosmic-blue.pub
jq -e '.transports.docker."ghcr.io/cosmic-blue-os/cosmic-blue"[0].keyPath == "/etc/pki/containers/cosmic-blue.pub"' \
    /etc/containers/policy.json >/dev/null
grep -q 'use-sigstore-attachments: true' /etc/containers/registries.d/cosmic-blue.yaml
jq -e '."image-ref" | startswith("ostree-image-signed:")' /usr/share/ublue-os/image-info.json >/dev/null

# ujust and its recipes
for f in bin/ujust share/ublue-os/just/00-entry.just share/ublue-os/just/apps.just \
         share/ublue-os/just/default.just share/ublue-os/just/update.just; do
    test -e "/usr/${f}"
done

test -f /usr/share/flatpak/preinstall.d/bazaar.preinstall
test -f /usr/share/flatpak/preinstall.d/cosmic-blue.preinstall
test ! -e /usr/lib/systemd/system/flatpak-add-fedora-repos.service
# No Bluefin GNOME dconf settings (the folder itself may come from Fedora)
if compgen -G '/etc/dconf/db/distro.d/*bluefin*' >/dev/null; then
    echo "Bluefin (GNOME) dconf settings present"; exit 1
fi

IMPORTANT_PACKAGES=(
    cosmic-session
    cosmic-greeter
    cosmic-comp
    cosmic-files
    cosmic-term
    distrobox
    fish
    flatpak
    pipewire
    systemd
    tailscale
    uupd
    wireplumber
    zsh
)
for package in "${IMPORTANT_PACKAGES[@]}"; do
    rpm -q "${package}" >/dev/null || { echo "Missing package: ${package}"; exit 1; }
done

# No GNOME Shell package may end up in the image
for package in gnome-shell gdm mutter; do
    if rpm -q "${package}" >/dev/null; then
        echo "Unexpected GNOME package: ${package}"; exit 1
    fi
done

# COSMIC must come from Fedora packages (not a COPR)
for package in cosmic-session cosmic-comp; do
    vendor="$(rpm -q --qf '%{VENDOR}' "${package}")"
    [[ "${vendor}" == "Fedora Project" ]] || { echo "${package} does not come from Fedora (${vendor})"; exit 1; }
done

systemctl is-enabled cosmic-greeter.service
test "$(systemctl get-default)" = graphical.target
