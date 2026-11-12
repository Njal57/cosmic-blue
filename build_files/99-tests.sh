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
# Per-theme defaults (used by COSMIC releases after 1.11): the dark wallpaper
# for the dark theme, the light one for the light theme
test -s /usr/share/backgrounds/cosmic-blue/cosmic-blue-light.jpg
grep -q 'Path("/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg")' \
    /usr/share/cosmic/com.system76.CosmicBackground.Dark/v1/all
grep -q 'Path("/usr/share/backgrounds/cosmic-blue/cosmic-blue-light.jpg")' \
    /usr/share/cosmic/com.system76.CosmicBackground.Light/v1/all
test -s /usr/share/icons/hicolor/scalable/apps/cosmic-blue-logo.svg
# Dark theme by default (COSMIC and GTK)
grep -qx true /usr/share/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark
test "$(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'"
# Dock: Firefox and Thunderbird are flatpaks (COSMIC's default lists the
# Firefox RPM id "firefox"); the other favorites are installed apps
APP_LIST=/usr/share/cosmic/com.system76.CosmicAppList/v1/favorites
for app in org.mozilla.firefox org.mozilla.thunderbird; do
    grep -q "\"${app}\"" "${APP_LIST}"
    grep -q "^\[Flatpak Preinstall ${app}\]" /usr/share/flatpak/preinstall.d/cosmic-blue.preinstall
done
for app in $(grep -o '"com\.system76\.[A-Za-z]*"' "${APP_LIST}" | tr -d '"'); do
    test -e "/usr/share/applications/${app}.desktop"
done
# Extra shortcuts (custom, so they show and can be changed in COSMIC Settings)
# next to COSMIC's own defaults, without taking one of their key combinations
SHORTCUTS=/usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1
test -s "${SHORTCUTS}/defaults"
grep -q 'System(Terminal)' "${SHORTCUTS}/custom"
for combo in '\[Ctrl, Alt\], key: "t"' '\[Super\], key: "e"' \
             '\[Super, Shift\], key: "s"' '\[Ctrl, Shift\], key: "Escape"'; do
    grep -q "${combo}" "${SHORTCUTS}/custom"
    if grep -q "${combo}" "${SHORTCUTS}/defaults"; then exit 1; fi
done
# Firefox defaults (policies), linked into the flatpak's systemconfig
# extension at boot; Bluefin's prefs and copy hook are gone
FIREFOX_POLICIES=/usr/share/cosmic-blue/firefox/policies/policies.json
jq -e '.policies.DisableTelemetry and .policies.DisableAppUpdate
    and .policies.ExtensionSettings."uBlock0@raymondhill.net".installation_mode == "normal_installed"' \
    "${FIREFOX_POLICIES}" >/dev/null
SYSTEMCONFIG=/var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable
SYSTEMD_LOG_LEVEL=warning systemd-tmpfiles --create --root=/tmp/tmpfiles-root - \
    </usr/lib/tmpfiles.d/cosmic-blue-firefox.conf
test "$(readlink "/tmp/tmpfiles-root${SYSTEMCONFIG}")" = /usr/share/cosmic-blue/firefox
rm -rf /tmp/tmpfiles-root
test ! -e /usr/share/ublue-os/firefox-config
test ! -e /usr/share/ublue-os/privileged-setup.hooks.d/99-flatpaks.sh
# Terminal: the cosmic-blue color schemes are the defaults, dark and light
TERM_CONFIG=/usr/share/cosmic/com.system76.CosmicTerm/v1
for kind in dark light; do
    grep -qx '"cosmic-blue"' "${TERM_CONFIG}/syntax_theme_${kind}"
    grep -q 'name: "cosmic-blue"' "${TERM_CONFIG}/color_schemes_${kind}"
done
# Shell prompt: the cosmic-blue Starship config is valid and renders a path
# segment (Starship prints a warning for each config error)
mkdir -p /tmp/starship-test
PROMPT_OUT="$(cd /tmp && HOME=/tmp/starship-test \
    STARSHIP_CONFIG=/usr/share/cosmic-blue/starship.toml starship prompt --status=1 2>&1)"
printf '%s\n' "${PROMPT_OUT}" | cat -v
if printf '%s' "${PROMPT_OUT}" | grep -qiE 'warn|error'; then exit 1; fi
printf '%s' "${PROMPT_OUT}" | grep -q '/tmp'
grep -q 'STARSHIP_CONFIG="${COSMIC_BLUE_STARSHIP}"' /etc/profile.d/90-starship.sh
grep -q 'io.missioncenter.MissionCenter' /usr/share/flatpak/preinstall.d/cosmic-blue.preinstall
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
jq -e '.transports.docker."ghcr.io/cosmic-blue-os"[0].keyPath == "/etc/pki/containers/cosmic-blue.pub"' \
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
# First-boot flatpaks and `ujust install-system-flatpaks` install the same apps
diff <(sed -n 's/^\[Flatpak Preinstall \(.*\)\]$/\1/p' /usr/share/flatpak/preinstall.d/cosmic-blue.preinstall | sort) \
     <(sed -n 's/^flatpak "\(.*\)"$/\1/p' /usr/share/ublue-os/homebrew/system-flatpaks.Brewfile | sort)
# No flatpak that duplicates a COSMIC app or needs GNOME
for app in io.github.flattool.Ignition org.gnome.FileRoller org.gnome.Showtime \
           org.gnome.Decibels page.tesk.Refine org.gnome.Calendar org.gnome.Contacts; do
    if grep -q "${app}" /usr/share/flatpak/preinstall.d/cosmic-blue.preinstall; then exit 1; fi
done
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

# Power profiles for laptops: tuned-ppd answers COSMIC's power profile
# requests, with battery detection; power-profiles-daemon conflicts with it
rpm -q tuned tuned-ppd thermald upower
if rpm -q power-profiles-daemon; then
    echo "power-profiles-daemon conflicts with tuned-ppd"; exit 1
fi
systemctl is-enabled tuned.service tuned-ppd.service thermald.service
test -f /usr/share/dbus-1/system-services/net.hadess.PowerProfiles.service
test -f /usr/share/dbus-1/system-services/org.freedesktop.UPower.PowerProfiles.service
grep -qx 'battery_detection=true' /etc/tuned/ppd.conf
grep -qx 'balanced=balanced-battery' /etc/tuned/ppd.conf
test -f /usr/lib/tuned/profiles/balanced-battery/tuned.conf ||
    test -f /usr/lib/tuned/balanced-battery/tuned.conf

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

# Icon theme: Tela circle dark (+ COSMIC symbolic icons it lacks), default for COSMIC and GTK
test -s /usr/share/icons/Tela-circle-4f8dff-dark/index.theme
test -s /usr/share/icons/Tela-circle-4f8dff/scalable/places/default-folder.svg
grep -q '4f8dff' /usr/share/icons/Tela-circle-4f8dff/scalable/places/default-folder.svg
test -s /usr/share/icons/cosmic-blue/index.theme
grep -qx 'Inherits=Tela-circle-4f8dff-dark,Cosmic,Pop,Adwaita,hicolor' /usr/share/icons/cosmic-blue/index.theme
grep -qx '"cosmic-blue"' /usr/share/cosmic/com.system76.CosmicTk/v1/icon_theme
test "$(GSETTINGS_BACKEND=memory gsettings get org.gnome.desktop.interface icon-theme)" = "'cosmic-blue'"
test -n "$(find /usr/share/icons/cosmic-blue/tela/symbolic -name 'audio-volume-high-symbolic.svg' -print -quit)"
test -n "$(find /usr/share/icons/cosmic-blue/cosmic -name '*-symbolic.svg' -print -quit)"
test -n "$(find /usr/share/icons/cosmic-blue/tela -name 'com.system76.CosmicFiles.svg' -print -quit)"
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

# Secure Boot: the Universal Blue akmods key (enrolled with
# `ujust enroll-secure-boot-key`) is in every image, so it can be enrolled
# before switching to cosmic-blue-nvidia
AKMODS_CERT=/etc/pki/akmods/certs/akmods-ublue.der
test -s "${AKMODS_CERT}"
grep -q '^enroll-secure-boot-key:' /usr/share/ublue-os/just/default.just
command -v mokutil

if [[ "${IMAGE_NAME}" == *-nvidia ]]; then
    jq -e '."image-flavor" == "nvidia-open"' /usr/share/ublue-os/image-info.json >/dev/null
    # Driver and modules of the same version, for the image's kernel
    rpm -q kmod-nvidia nvidia-driver egl-wayland libva-nvidia-driver nvidia-container-toolkit
    test "$(rpm -q --qf '%{VERSION}' kmod-nvidia)" = "$(rpm -q --qf '%{VERSION}' nvidia-driver)"
    modinfo -k "${KVER}" nvidia nvidia-drm nvidia-modeset nvidia-uvm >/dev/null
    # Open modules, signed with the akmods key: Secure Boot accepts them once
    # that key is enrolled
    modinfo -k "${KVER}" -F license nvidia | grep -q 'Dual MIT/GPL'
    # (PKCS#7 module signatures name the key by its certificate serial number)
    module_key="$(modinfo -k "${KVER}" -F sig_key nvidia | tr -d ': \n' | tr 'a-f' 'A-F')"
    cert_key="$(openssl x509 -inform der -in "${AKMODS_CERT}" -noout -serial \
        | cut -d = -f 2 | tr -d ': \n' | tr 'a-f' 'A-F')"
    [[ -n "${module_key}" && "${module_key}" == "${cert_key}" ]] \
        || { echo "nvidia.ko is signed by ${module_key:-nothing}, not the akmods key ${cert_key}"; exit 1; }
    # nvidia modules in the initramfs (black screen on boot otherwise), and
    # nouveau kept away
    grep -q 'nvidia-drm' /tmp/initramfs.txt
    grep -q 'nvidia-drm.modeset=1' /usr/lib/bootc/kargs.d/00-nvidia.toml
    grep -q 'modprobe.blacklist=nouveau' /usr/lib/bootc/kargs.d/00-nvidia.toml
    # The NVIDIA repositories used for the install are disabled again
    if dnf5 repolist --enabled | grep -i nvidia; then
        echo "NVIDIA repositories left enabled"; exit 1
    fi
elif rpm -q kmod-nvidia; then
    echo "kmod-nvidia in a non-NVIDIA image"; exit 1
fi
