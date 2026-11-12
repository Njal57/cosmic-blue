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
# Boot screen (Plymouth): cosmic-blue theme by default, with our logo images,
# the blue spinner and Fedora's other images, and included in the initramfs
test "$(plymouth-set-default-theme)" = cosmic-blue
PLYMOUTH_THEME=/usr/share/plymouth/themes/cosmic-blue
grep -qx "ImageDir=${PLYMOUTH_THEME}" "${PLYMOUTH_THEME}/cosmic-blue.plymouth"
grep -qx 'ModuleName=two-step' "${PLYMOUTH_THEME}/cosmic-blue.plymouth"
grep -qx 'UseFirmwareBackground=true' "${PLYMOUTH_THEME}/cosmic-blue.plymouth"
for image in watermark.png bgrt-fallback.png; do
    cmp "/ctx/system_files/cosmic-blue/usr/share/plymouth/themes/cosmic-blue/${image}" "${PLYMOUTH_THEME}/${image}"
done
compgen -G "${PLYMOUTH_THEME}/throbber-*.png" >/dev/null
test -e "${PLYMOUTH_THEME}/lock.png"
test -e "${PLYMOUTH_THEME}/entry.png"
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | head -n1)"
lsinitrd "/usr/lib/modules/${KVER}/initramfs.img" > /tmp/initramfs.txt
grep -q 'plymouth/themes/cosmic-blue/bgrt-fallback.png' /tmp/initramfs.txt
grep -q 'plymouth/themes/cosmic-blue/cosmic-blue.plymouth' /tmp/initramfs.txt

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
# cosmic-blue recipes (60-custom.just) parse and are listed by ujust
recipes="$(just --justfile /usr/share/ublue-os/just/00-entry.just --summary)"
for recipe in toggle-dark-mode reset-cosmic-theme reset-cosmic-config; do
    grep -qw -- "${recipe}" <<<"${recipes}"
done

test ! -e /usr/share/flatpak/preinstall.d/bazaar.preinstall
! grep -q Bazaar /usr/share/ublue-os/homebrew/system-flatpaks.Brewfile
for remote in flathub cosmic; do
    grep -q '^\[Flatpak Repo\]' "/usr/share/flatpak/remotes.d/${remote}.flatpakrepo"
    flatpak remotes --system --columns=name | grep -qx "${remote}"
done
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
    cosmic-store
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
# docker CLI works through the rootless Podman socket (ujust devmode installs docker)
systemctl --global is-enabled podman.socket
test -x /usr/share/ublue-os/user-setup.hooks.d/30-docker-podman.sh
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
