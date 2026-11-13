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
# Bluefin's fastfetch logos (dinosaurs and a chicken), its global config and
# its Bluefin and Bazaar user counters: cosmic-blue ships its own fastfetch
# (system_files/usr/bin/ublue-fastfetch and usr/share/ublue-os/fastfetch*).
GNOME_ONLY+=(
    etc/ublue-os/fastfetch.json
    usr/share/ublue-os/bluefin-logos
    usr/share/ublue-os/fastfetch-user-count
    usr/share/ublue-os/bazaar-install-count
)
# Bazaar, Bluefin's Flathub store: COSMIC Store already covers it (Flathub and
# the COSMIC repository), and one store is enough.
GNOME_ONLY+=(
    usr/share/flatpak/preinstall.d/bazaar.preinstall
    usr/share/ublue-os/bazaar
)
# Bluefin's Firefox prefs force hardware video decoding past Firefox's GPU
# blocklist: Firefox's own defaults are safer. Our Firefox defaults are
# policies (usr/lib/tmpfiles.d/cosmic-blue-firefox.conf).
GNOME_ONLY+=(
    usr/share/ublue-os/firefox-config
)
# More Bluefin leftovers that have no use on cosmic-blue:
# - the rest of Bazaar (background service, config, flatpak override);
# - projectbluefin-countme, a usage counter for other Bluefin images that
#   exits at once on cosmic-blue;
# - the AI agent notes about Bluefin's repositories;
# - get-geoclue-latitude, used only by Bluefin's GNOME dynamic wallpaper;
# - `ujust changelogs`, which shows Bluefin's release notes (cosmic-blue's
#   are on its GitHub releases page);
# - opt-in Brewfiles for GNOME apps and Bluefin wallpapers, offered by
#   ChairLift only: Bluefin's "full desktop" GNOME Circle list, Hidamari and
#   Damask (video wallpaper and wallpaper slideshow, GNOME only).
GNOME_ONLY+=(
    etc/bazaar
    usr/lib/systemd/user/bazaar.service
    usr/lib/tmpfiles.d/bazaar-flatpak.conf
    usr/share/ublue-os/flatpak-overrides/io.github.kolunmi.Bazaar
    usr/libexec/projectbluefin-countme
    usr/lib/systemd/system/projectbluefin-countme.service
    usr/lib/systemd/system/projectbluefin-countme.timer
    usr/lib/systemd/system/timers.target.wants/projectbluefin-countme.timer
    usr/lib/systemd/system-preset/03-projectbluefin-countme.preset
    usr/share/ublue-os/agent
    usr/libexec/get-geoclue-latitude
    usr/share/ublue-os/just/changelog.just
    usr/share/ublue-os/homebrew/full-desktop.Brewfile
    usr/share/ublue-os/homebrew/video-wallpaper.Brewfile
    usr/share/ublue-os/homebrew/wallpaper-slideshow.Brewfile
    usr/share/ublue-os/homebrew/artwork.Brewfile
)
# Bluefin's community and help launchers, and its Report a Problem app, which
# files issues in Bluefin's repositories. cosmic-blue's own Documentation
# launcher (system_files) opens the cosmic-blue guide instead.
GNOME_ONLY+=(
    usr/share/applications/discourse.desktop
    usr/share/applications/bluefin-help.desktop
    usr/share/applications/io.projectbluefin.Report.desktop
    usr/share/icons/hicolor/scalable/apps/io.projectbluefin.Report.svg
    usr/share/ublue-os/just/60-report.just
    usr/share/ublue-os/homebrew/preinstall.d/bluefin-report.Brewfile
)
for path in "${GNOME_ONLY[@]}"; do
    rm -rf "${STAGE:?}/${path}"
done

# Bluefin-only ujust recipes: `contribute` (runs a worker for Bluefin's
# build hive), `bluespeed` (Bluefin's AI stack, `install-ai-tools` remains),
# `bluefin-apps` (alias of install-system-flatpaks), `bazaar-preview`, and
# `toggle-testing`, which switches to a "testing" tag that cosmic-blue does
# not publish.
python3 -I /ctx/build_files/drop-just-recipes.py \
    "${STAGE}/usr/share/ublue-os/just/shared.just" contribute
python3 -I /ctx/build_files/drop-just-recipes.py \
    "${STAGE}/usr/share/ublue-os/just/system.just" \
    bluespeed bluefin-apps bazaar-preview toggle-testing

# Bluefin's zsh profile forces every LC_* variable (and LC_ALL) to en_US for
# zsh login shells, which overrides the language chosen at install time.
sed -i '/^export LC_[A-Z_]*=en_US/d' "${STAGE}/etc/zsh/zprofile"

# `ujust` with no recipe prints a link to Bluefin's documentation first:
# point it to the cosmic-blue guide.
sed -i 's|https://docs.projectbluefin.io/[^"]*|https://cosmic-blue-os.github.io/cosmic-blue/docs/|' \
    "${STAGE}/usr/share/ublue-os/just/00-entry.just"

# `ujust toggle-tpm2` (projectbluefin/common) runs /usr/bin/luks-tpm2-autounlock:
# common's script moves aside, and ours (system_files/usr/bin) runs extra
# checks (no TPM2 chip, Secure Boot off) before calling it.
install -d "${STAGE}/usr/libexec"
mv "${STAGE}/usr/bin/luks-tpm2-autounlock" "${STAGE}/usr/libexec/ublue-luks-tpm2-autounlock"

cp -a "${STAGE}/." /
cp -a /ctx/system_files/cosmic-blue/. /

# Only accept key-signed cosmic-blue images (cosign.pub, signed by build.yml).
# The scope is the whole namespace, so that switching between cosmic-blue and
# cosmic-blue-nvidia is verified too.
IMAGE="ghcr.io/${IMAGE_VENDOR}"
jq --arg image "$IMAGE" 'del(.transports.docker[$image + "/cosmic-blue"])
    | .transports.docker[$image] = [{
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
EOF

# Bluefin faces (avatars) ship in a subfolder; move them up, as Bluefin does
if [[ -d /usr/share/pixmaps/faces/bluefin ]]; then
    rm -f /usr/share/pixmaps/faces/*.{png,jpg,svg} || true
    mv /usr/share/pixmaps/faces/bluefin/* /usr/share/pixmaps/faces/
    rmdir /usr/share/pixmaps/faces/bluefin
fi
