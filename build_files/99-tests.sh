#!/usr/bin/bash
# Vérifications simples : si l'une échoue, le build échoue.
set -euox pipefail

# Clés de signature ublue présentes (sinon impossible de mettre à jour depuis ghcr.io/ublue-os)
jq -e '.transports.docker."ghcr.io/ublue-os"' /etc/containers/policy.json >/dev/null

# ujust et ses recettes
for f in bin/ujust share/ublue-os/just/00-entry.just share/ublue-os/just/apps.just \
         share/ublue-os/just/default.just share/ublue-os/just/update.just; do
    test -e "/usr/${f}"
done

test -f /usr/share/flatpak/preinstall.d/bazaar.preinstall
test -f /usr/share/flatpak/preinstall.d/cosmic-blue.preinstall
test ! -e /usr/lib/systemd/system/flatpak-add-fedora-repos.service
# Aucun réglage dconf GNOME de Bluefin (le dossier lui-même peut venir de Fedora)
if compgen -G '/etc/dconf/db/distro.d/*bluefin*' >/dev/null; then
    echo "Réglages dconf Bluefin (GNOME) présents"; exit 1
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
    rpm -q "${package}" >/dev/null || { echo "Paquet manquant : ${package}"; exit 1; }
done

# Aucun paquet GNOME Shell ne doit se retrouver dans l'image
for package in gnome-shell gdm mutter; do
    if rpm -q "${package}" >/dev/null; then
        echo "Paquet GNOME inattendu : ${package}"; exit 1
    fi
done

# COSMIC doit venir des paquets Fedora (pas d'un COPR)
for package in cosmic-session cosmic-comp; do
    vendor="$(rpm -q --qf '%{VENDOR}' "${package}")"
    [[ "${vendor}" == "Fedora Project" ]] || { echo "${package} ne vient pas de Fedora (${vendor})"; exit 1; }
done

systemctl is-enabled cosmic-greeter.service
test "$(systemctl get-default)" = graphical.target
