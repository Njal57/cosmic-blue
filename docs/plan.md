# COSMIC-blue : choix de la base et inventaire Bluefin (étape 1)

Objectif : une image Universal Blue « à la Bluefin », avec COSMIC à la place de
GNOME, COSMIC venant des **paquets officiels Fedora** (pas de COPR).

## 1. Image de base recommandée

**`ghcr.io/ublue-os/base-main:latest`** (actuellement Fedora 45), puis
installation de COSMIC depuis les dépôts Fedora.

### Comment Bluefin est construit

```
quay.io/fedora-ostree-desktops/silverblue   (Fedora, GNOME)
  └─ ghcr.io/ublue-os/silverblue-main        (couche "main" Universal Blue)
       └─ Bluefin  (+ ghcr.io/projectbluefin/common + ghcr.io/ublue-os/brew)
```

`ublue-os/main` ne publie que trois variantes : `base-main`, `silverblue-main`
et `kinoite-main`. Il n'existe pas de `cosmic-main`.

### Options comparées

| Option | Pour | Contre |
|---|---|---|
| **A. `ublue-os/base-main` + COSMIC Fedora** (recommandé) | Garde toute la couche *main* (codecs negativo17, clés de signature ublue, `ublue-os-just`, udev, noyau/akmods, Flathub) sans GNOME. C'est l'équivalent exact de « silverblue-main », mais pour COSMIC. | Il faut installer le groupe COSMIC nous-mêmes et activer `cosmic-greeter`. |
| B. `quay.io/fedora-ostree-desktops/cosmic-atomic` | COSMIC Atomic officiel Fedora (depuis F42), déjà intégré. | Perd la couche *main* : il faudrait refaire codecs, signature, akmods, etc. à la main. |
| C. `bluefin` en retirant GNOME | Tout Bluefin d'office. | Désinstaller GNOME proprement est fragile (gschemas, dconf, extensions, gdm), image lourde. À éviter. |

Le choix A revient à reproduire `cosmic-atomic` (qui est lui-même `base-atomic`
plus le groupe comps COSMIC), mais par-dessus la couche *main* d'Universal Blue.

### Esquisse pour l'étape 2

```dockerfile
FROM ghcr.io/ublue-os/base-main:latest
# build.sh :
#   dnf5 -y group install cosmic-desktop cosmic-desktop-apps   (dépôts Fedora)
#   systemctl enable cosmic-greeter.service
#   systemctl set-default graphical.target
```

Les noms exacts des groupes/paquets (`cosmic-desktop`, `cosmic-session`,
`cosmic-greeter`…) seront vérifiés au premier build (`dnf5 group list` dans
l'image). Je n'ai pas pu interroger les dépôts Fedora depuis mon environnement.

## 2. Ce que Bluefin ajoute au-delà de GNOME

Sources lues : `ublue-os/bluefin` (`build_files/`), `projectbluefin/common`
(`system_files/`), `ublue-os/main`.

### Déjà fourni par `base-main` (rien à faire)

Codecs et multimédia (ffmpeg, libavcodec, fdk-aac, intel-vaapi-driver, via
negativo17), `distrobox`, `just`, `fzf`, `htop`, `nvtop`, `vim`, `tmux`,
`wireguard-tools`, `wl-clipboard`, YubiKey (`pam-u2f`, `yubikey-manager`),
`smartmontools`, polices Noto CJK, clés de signature ublue, dépôt Flathub.

### À reproduire

**a) Couche `projectbluefin/common` (réutilisable presque telle quelle)**

Bluefin copie `ghcr.io/projectbluefin/common` (`/system_files/shared` et
`/system_files/bluefin`) et `ghcr.io/ublue-os/brew` dans son image. On peut faire
de même avec un `COPY --from=` :

- `ujust` + recettes (`00-entry`, `apps`, `default`, `shared`, `update`,
  `system`) : `update`, `toggle-updates`, `devmode`/`toggle-devmode`,
  `install-system-flatpaks`, `bluefin-cli`, `setup-vms`, `enroll-secure-boot-key`,
  `powerwash`, `changelogs`, `report`, `device-info`, `benchmark`, `toggle-tpm2`,
  `install-jetbrains-toolbox`, `install-ai-tools`, `cncf`…
- **Homebrew** (`ghcr.io/ublue-os/brew`) : `brew-setup.service`,
  `brew-preinstall`, Brewfiles (`cli`, `fonts`, `ide`, `k8s-tools`, `ai-tools`…).
- **Mises à jour** : `uupd` + `uupd.timer`, `uupd-on-ac`, `bootc-update-stage`
  (remplace `rpm-ostreed-automatic.timer`).
- **Setup** : `ublue-system-setup`, `ublue-user-setup` (+ hooks), `ublue-bling`
  (bling.sh/fish, starship), fastfetch, `uwelcome`.
- **Flatpak** : `flatpak-preinstall.service`, filtre « flatpark »,
  `flatpak-appstream-refresh`, `flatpak-nuke-fedora`.
- `/etc/containers/policy.json` + clés (vérification des images ublue),
  règles udev matériel (Framework, ZSA, Wooting, Titan key…), profils ICC
  Framework, polkit, sudoers bootc, `luks-tpm2-autounlock`.

À **ne pas** reprendre (spécifique GNOME) : `/etc/dconf/db/distro.d/*`,
`zz0-bluefin-modifications.gschema.override`, `gnome-initial-setup/vendor.conf`,
palettes Ptyxis, `gnome-xdg-terminals.list`, fond d'écran dynamique GNOME.

**b) Paquets RPM (Fedora) ajoutés par Bluefin** (`04-packages.sh`)

- Outils : `fish`, `zsh`, `fastfetch`, `glow`, `gum`, `bash-color-prompt`,
  `gcc`, `gcc-c++`, `make`, `python3-pip`, `rclone`, `restic`, `borgbackup`,
  `waypipe`, `xdg-terminal-exec`, `lm_sensors`, `powertop`, `powerstat`, `usbip`.
- Réseau/entreprise : `samba` + winbind/sssd, `adcli`, `krb5-workstation`,
  `oddjob-mkhomedir`, `autofs`, `davfs2`, `iwd`, `firewall-config`.
- Matériel : `hplip`, `foo2zjs`, `printer-driver-brlaser`, `input-remapper`,
  `libratbag-ratbagd`, `ddcutil`, `evtest`, `switcheroo-control`,
  `libimobiledevice`, `ifuse`, `usbmuxd`, `igt-gpu-tools`.
- Chiffrement/stockage : `cryfs`, `fuse-encfs`, `bcache-tools`,
  `gnupg2-scdaemon`, `git-credential-libsecret`, `openssh-askpass`.
- Polices / saisie : `jetbrains-mono-fonts-all`, `adwaita-fonts-all`,
  `opendyslexic-fonts`, `mozc`, `ibus-mozc`.
- Hors Fedora : `tailscale` (dépôt officiel Tailscale), `uupd` (COPR
  ublue-os/packages), `nerd-fonts` (COPR che/nerd-fonts), `starship` (binaire
  GitHub).
- Retirés : `firefox` (remplacé par la flatpak), `podman-docker`, `fedora-bookmarks`.
- Spécifiques GNOME, à ignorer : `gnome-tweaks`, `nautilus-gsconnect`,
  `gnome-rounded-blur`, `adw-gtk3-theme`, extensions GNOME.

**c) Noyau / modules** (`03-install-kernel-akmods.sh`)

Bluefin remplace le noyau par celui `coreos-stable` avec ZFS et
`v4l2loopback`. Proposition : garder le noyau de `base-main` au début (plus
simple), et voir plus tard si ZFS/v4l2loopback est voulu.

**d) Services activés** (`17-cleanup.sh`)

`uupd.timer`, `brew-setup`, `flatpak-preinstall`, `tailscaled`,
`input-remapper`, `ublue-system-setup`, `rpm-ostree-countme`, et côté
utilisateur `podman-auto-update.timer` et `ublue-user-setup`.
(`dconf-update.service` est GNOME : inutile.)

**e) Flatpaks par défaut** (`system-flatpaks.Brewfile`)

Neutres, à garder : Firefox, Thunderbird, Flatseal, Bazaar (boutique),
Mission Center, DistroShelf, Ignition, Impression, Pinta, Gradia, Refine,
Déjà Dup, Firmware.

Applis GNOME : à remplacer par leurs équivalents COSMIC quand ils existent
(Fichiers, Éditeur, Terminal, Lecteur, Paramètres sont fournis en RPM par
COSMIC), ou à garder en flatpak (Calculatrice, Calendrier, Météo, Cartes,
Papers, Loupe, Snapshot…). `ExtensionManager` et `NautilusPreviewer` sont à
retirer.

**f) Variante DX** (`00-dx.sh`, optionnelle, plus tard)

Docker CE, VS Code (dépôt Microsoft), libvirt/QEMU/virt-manager, incus/lxc,
cockpit, podman-compose/machine/tui, bpftrace/bcc, ROCm, flatpaks Podman Desktop,
DevToolbox, Builder.

**g) Identité**

`os-release` et `image-info.json` (nom, ID, URL) réécrits par `00-image-info.sh`.
À adapter pour « COSMIC-blue ».

## 3. Étape 2 : ce qui est en place

Base validée : `base-main` + COSMIC Fedora.

- `Containerfile` : `FROM ghcr.io/ublue-os/base-main`, avec les fichiers de
  `projectbluefin/common` et `ublue-os/brew` passés par le contexte de build.
- `build_files/` (un script par étape) :
  - `10-system-files.sh` : copie common + brew sans les fichiers GNOME, puis `system_files/` ;
  - `20-cosmic.sh` : groupes `@cosmic-desktop` + les applis COSMIC (Edit, Files, Player, Term), `cosmic-greeter` ;
  - `30-packages.sh` : paquets de la section 2b, Tailscale, uupd, Starship ;
  - `40-image-info.sh` : `image-info.json` et `os-release` « COSMIC-blue » ;
  - `50-services.sh` : services de la section 2d, Flathub ;
  - `60-initramfs.sh`, `90-cleanup.sh` (dépôts tiers désactivés), `99-tests.sh`
    (vérifie entre autres que COSMIC vient bien de Fedora et qu'il n'y a pas de GNOME Shell).
- `system_files/` : quelques fichiers repris de `ublue-os/bluefin`
  (`flatpak-nuke-fedora`, hooks de setup, starship), la liste de flatpaks
  installés au premier démarrage (`cosmic-blue.preinstall`) et le Brewfile
  `system-flatpaks` adapté à COSMIC.

Pas encore fait : variante DX, noyau ZFS, ISO (étape 3).
