#!/usr/bin/bash
# Bureau COSMIC, uniquement depuis les dépôts officiels Fedora.
set -euox pipefail

# Pour le journal de build : groupes COSMIC disponibles dans cette version de Fedora
dnf5 group list --hidden | grep -i cosmic || true

# Groupes comps utilisés par Fedora COSMIC (spin et Atomic). Aucun COPR n'est activé ici :
# les paquets COSMIC viennent forcément des dépôts Fedora (vérifié dans 99-tests.sh).
# On ne prend pas @cosmic-desktop-apps : sur Fedora il tire des applis KDE/GNOME
# (Okular, Rhythmbox, Nheko...) qu'on remplace par des flatpaks, comme Bluefin.
dnf5 -y install \
    @cosmic-desktop \
    cosmic-edit \
    cosmic-files \
    cosmic-player \
    cosmic-term

# (pas de power-profiles-daemon : base-main fournit déjà tuned-ppd)
# Briques de bureau que l'image Atomic de Fedora apporte et que base-main n'a pas forcément
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
