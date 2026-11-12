#!/usr/bin/bash
# Simple checks: if one fails, the build fails.
set -euox pipefail

# ublue signing keys present (otherwise updates from ghcr.io/ublue-os are impossible)
jq -e '.transports.docker."ghcr.io/ublue-os"' /etc/containers/policy.json >/dev/null
# No Bluefin wallpapers
test ! -e /usr/share/backgrounds/bluefin
# cosmic-blue wallpaper is the COSMIC default, and the logo is installed
test -s /usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg
grep -q 'Path("/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg")' \
    /usr/share/cosmic/com.system76.CosmicBackground/v1/all
test -s /usr/share/icons/hicolor/scalable/apps/cosmic-blue-logo.svg
# Dark theme by default (COSMIC and GTK)
grep -qx true /usr/share/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark
test "$(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'"
# Fedora's own wallpapers stay available
rpm -q "f${FEDORA_MAJOR_VERSION}-backgrounds-base"
# Each wallpaper is listed once in COSMIC Settings: no aliases, no copies
test -z "$(find /usr/share/backgrounds -type l)"
test -z "$(find /usr/share/backgrounds -type f -exec sha256sum {} + | cut -d' ' -f1 | sort | uniq -d)"
grep -q '^LOGO=cosmic-blue-logo$' /usr/lib/os-release
# Boot (Plymouth) watermark is the cosmic-blue logo, not Fedora's or Bluefin's
cmp /ctx/system_files/cosmic-blue/usr/share/plymouth/themes/spinner/watermark.png \
    /usr/share/plymouth/themes/spinner/watermark.png

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

# Installer keyboard layout and clock format copied to COSMIC user settings
test -x /usr/libexec/cosmic-blue-user-defaults
systemctl is-enabled cosmic-blue-user-defaults.service

# First-run assistant: no second language/keyboard/time zone prompt; VM agent
test -f /etc/skel/.config/gnome-initial-setup-done
# First-run assistant: our patched build (keeps the theme, no screen reader at start)
cmp /ctx/initial_setup/cosmic-initial-setup /usr/bin/cosmic-initial-setup
rpm -q spice-vdagent

# Frosted glass on by default, in the theme apps read and in the builder
for theme in Dark Light; do
    grep -qx true "/usr/share/cosmic/com.system76.CosmicTheme.${theme}/v2/frosted_windows"
    grep -qx true "/usr/share/cosmic/com.system76.CosmicTheme.${theme}.Builder/v2/frosted_panel"
done

# Icon theme: COSMIC symbolic icons + Papirus-Dark, default for COSMIC and GTK
rpm -q papirus-icon-theme papirus-icon-theme-dark
test -s /usr/share/icons/cosmic-blue/index.theme
grep -qx 'Inherits=Papirus-Dark,Cosmic,Pop,Adwaita,hicolor' /usr/share/icons/cosmic-blue/index.theme
grep -qx '"cosmic-blue"' /usr/share/cosmic/com.system76.CosmicTk/v1/icon_theme
test "$(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface icon-theme)" = "'cosmic-blue'"
test -n "$(find /usr/share/icons/cosmic-blue/cosmic -name '*-symbolic.svg' -print -quit)"
test -n "$(find /usr/share/icons/cosmic-blue/papirus -name 'com.system76.CosmicFiles.svg' -print -quit)"
# Every link of the theme points to an existing icon
broken="$(find /usr/share/icons/cosmic-blue -xtype l)"
[[ -z "${broken}" ]] || { echo "Broken icon links:"; echo "${broken}"; exit 1; }

# Theme colors built around the logo blue (see build_files/theme/src/main.rs).
# Prints the first color of a COSMIC config file as #rrggbb
# (colors are stored as hex strings, e.g. Some("#4F8DFFFF")).
first_color() {
    grep -oiE '#[0-9a-f]{6}' "$1" | head -n 1 | tr 'A-F' 'a-f'
}
check_color() {
    local file="$1" expected="$2" actual
    cat "${file}"
    actual="$(first_color "${file}")"
    [[ "${actual}" == "${expected}" ]] || { echo "${file}: ${actual}, expected ${expected}"; exit 1; }
}
builder=/usr/share/cosmic/com.system76.CosmicTheme
check_color "${builder}.Dark.Builder/v2/accent" '#4f8dff'
check_color "${builder}.Light.Builder/v2/accent" '#1d47c4'
check_color "${builder}.Dark.Builder/v2/bg_color" '#141c2a'
check_color "${builder}.Light.Builder/v2/bg_color" '#d3d8e0'
# The active window outline follows the accent
grep -qx None "${builder}.Dark.Builder/v2/window_hint"
grep -qx None "${builder}.Light.Builder/v2/window_hint"
