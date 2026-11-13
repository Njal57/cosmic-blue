# cosmic-blue: base image choice and Bluefin inventory

Goal: a Bluefin-like Universal Blue image with COSMIC instead of GNOME, with
COSMIC coming from the **official Fedora packages** (no COPR).

## 1. Base image

**`ghcr.io/ublue-os/base-main:44`** (Fedora 44, like Bluefin), with COSMIC
installed from the Fedora repositories. It was `latest` (Fedora 45) at first,
but the live ISO installer failed on Fedora 45 (`systemd-tmpfiles` exit code 73
while Anaconda prepares /var). Move to the next release when Bluefin does.

### How Bluefin is built

```
quay.io/fedora-ostree-desktops/silverblue   (Fedora, GNOME)
  └─ ghcr.io/ublue-os/silverblue-main        (Universal Blue "main" layer)
       └─ Bluefin  (+ ghcr.io/projectbluefin/common + ghcr.io/ublue-os/brew)
```

`ublue-os/main` only publishes three variants: `base-main`, `silverblue-main`
and `kinoite-main`. There is no `cosmic-main`.

### Options compared

| Option | Pros | Cons |
|---|---|---|
| **A. `ublue-os/base-main` + Fedora COSMIC** (chosen) | Keeps the whole *main* layer (negativo17 codecs, ublue signing keys, `ublue-os-just`, udev, kernel/akmods, Flathub) without GNOME. The exact equivalent of `silverblue-main`, for COSMIC. | We install the COSMIC group ourselves and enable `cosmic-greeter`. |
| B. `quay.io/fedora-ostree-desktops/cosmic-atomic` | Official Fedora COSMIC Atomic (since F42), already integrated. | Loses the *main* layer: codecs, signing, akmods, etc. would have to be redone by hand. |
| C. `bluefin` with GNOME removed | All of Bluefin out of the box. | Removing GNOME cleanly is fragile (gschemas, dconf, extensions, gdm) and the image is heavy. Avoid. |

Option A amounts to reproducing `cosmic-atomic` (itself `base-atomic` plus the
COSMIC comps group) on top of Universal Blue's *main* layer.

## 2. What Bluefin adds beyond GNOME

Sources read: `ublue-os/bluefin` (`build_files/`), `projectbluefin/common`
(`system_files/`), `ublue-os/main`.

### Already provided by `base-main`

Codecs and multimedia (ffmpeg, libavcodec, fdk-aac, intel-vaapi-driver, via
negativo17), `distrobox`, `just`, `fzf`, `htop`, `nvtop`, `vim`, `tmux`,
`wireguard-tools`, `wl-clipboard`, YubiKey (`pam-u2f`, `yubikey-manager`),
`smartmontools`, Noto CJK fonts, ublue signing keys, Flathub remote.

### To reproduce

**a) `projectbluefin/common` layer (reusable almost as-is)**

Bluefin copies `ghcr.io/projectbluefin/common` (`/system_files/shared` and
`/system_files/bluefin`) and `ghcr.io/ublue-os/brew` into its image. We do the
same through the build context:

- `ujust` + recipes (`00-entry`, `apps`, `default`, `shared`, `update`,
  `system`): `update`, `toggle-updates`, `devmode`/`toggle-devmode`,
  `install-system-flatpaks`, `bluefin-cli`, `setup-vms`, `enroll-secure-boot-key`,
  `powerwash`, `device-info`, `benchmark`, `toggle-tpm2`,
  `install-jetbrains-toolbox`, `install-ai-tools`, `cncf`… Bluefin-only recipes
  are dropped in `build_files/10-system-files.sh`.
- **Homebrew** (`ghcr.io/ublue-os/brew`): `brew-setup.service`,
  `brew-preinstall`, Brewfiles (`cli`, `fonts`, `ide`, `k8s-tools`, `ai-tools`…).
- **Updates**: `uupd` + `uupd.timer`, `uupd-on-ac`, `bootc-update-stage`
  (replaces `rpm-ostreed-automatic.timer`).
- **Setup**: `ublue-system-setup`, `ublue-user-setup` (+ hooks), `ublue-bling`
  (bling.sh/fish, starship), fastfetch, `uwelcome`.
- **Flatpak**: `flatpak-preinstall.service`, `flatpak-appstream-refresh`,
  `flatpak-nuke-fedora` (not Bluefin's FlatPark remote).
- `/etc/containers/policy.json` + keys (ublue image verification), hardware
  udev rules (Framework, ZSA, Wooting, Titan key…), Framework ICC profiles,
  polkit, bootc sudoers, `luks-tpm2-autounlock`.

**Not** reused (GNOME-specific): `/etc/dconf/db/distro.d/*`,
`zz0-bluefin-modifications.gschema.override`, `gnome-initial-setup/vendor.conf`,
Ptyxis palettes, `gnome-xdg-terminals.list`, GNOME dynamic wallpaper.

**b) RPM packages (Fedora) added by Bluefin** (`04-packages.sh`)

- Tools: `fish`, `zsh`, `fastfetch`, `glow`, `gum`, `bash-color-prompt`,
  `gcc`, `gcc-c++`, `make`, `python3-pip`, `rclone`, `restic`, `borgbackup`,
  `waypipe`, `xdg-terminal-exec`, `lm_sensors`, `powertop`, `powerstat`, `usbip`.
- Network/enterprise: `samba` + winbind/sssd, `adcli`, `krb5-workstation`,
  `oddjob-mkhomedir`, `autofs`, `davfs2`, `iwd`, `firewall-config`.
- Hardware: `hplip`, `foo2zjs`, `printer-driver-brlaser`, `input-remapper`,
  `libratbag-ratbagd`, `ddcutil`, `evtest`, `switcheroo-control`,
  `libimobiledevice`, `ifuse`, `usbmuxd`, `igt-gpu-tools`.
- Encryption/storage: `cryfs`, `fuse-encfs`, `bcache-tools`,
  `gnupg2-scdaemon`, `git-credential-libsecret`, `openssh-askpass`.
- Fonts / input: `jetbrains-mono-fonts-all`, `adwaita-fonts-all`,
  `opendyslexic-fonts`, `mozc`, `ibus-mozc`.
- Outside Fedora: `tailscale` (official Tailscale repo), `uupd` (COPR
  ublue-os/packages), `nerd-fonts` (COPR che/nerd-fonts), `starship` (GitHub
  binary).
- Removed: `firefox` (replaced by the flatpak), `podman-docker`, `fedora-bookmarks`.
- GNOME-specific, ignored: `gnome-tweaks`, `nautilus-gsconnect`,
  `gnome-rounded-blur`, GNOME extensions.

**c) Kernel / modules** (`03-install-kernel-akmods.sh`)

Bluefin swaps in the `coreos-stable` kernel with ZFS and `v4l2loopback`. We
keep the `base-main` kernel for now and may add ZFS/v4l2loopback later.

**d) Enabled services** (`17-cleanup.sh`)

`uupd.timer`, `brew-setup`, `flatpak-preinstall`, `tailscaled`,
`input-remapper`, `ublue-system-setup`, `rpm-ostree-countme`, and for users
`podman-auto-update.timer` and `ublue-user-setup`.
(`dconf-update.service` is GNOME-only: not needed.)

**e) Default flatpaks** (`system-flatpaks.Brewfile`)

Desktop-neutral, kept: Firefox, Thunderbird, Flatseal, Bazaar (store),
Mission Center, DistroShelf, Ignition, Impression, Refine, Déjà Dup, Firmware.

GNOME apps: replaced by COSMIC equivalents when they exist (Files, Edit,
Terminal, Player and Settings ship as COSMIC RPMs), otherwise kept as flatpaks
(Calculator, Calendar, Weather, Maps, Papers, Loupe, Snapshot…).
`ExtensionManager` and `NautilusPreviewer` are dropped.

**f) DX variant** (`00-dx.sh`, optional, later)

Docker CE, VS Code (Microsoft repo), libvirt/QEMU/virt-manager, incus/lxc,
cockpit, podman-compose/machine/tui, bpftrace/bcc, ROCm, Podman Desktop,
DevToolbox and Builder flatpaks.

**g) Identity**

`os-release` and `image-info.json` (name, ID, URLs) are rewritten by
`00-image-info.sh`; adapted for "cosmic-blue".

## 3. Current state of the build

- `Containerfile`: `FROM ghcr.io/ublue-os/base-main`, with the
  `projectbluefin/common` and `ublue-os/brew` files passed through the build context.
- `build_files/` (one script per step):
  - `10-system-files.sh`: copies common + brew minus GNOME files, then `system_files/`;
  - `20-cosmic.sh`: `@cosmic-desktop` group + COSMIC apps (Edit, Files, Player, Term), `cosmic-greeter`;
  - `30-packages.sh`: packages from section 2b, Tailscale, uupd, Starship;
  - `40-image-info.sh`: `image-info.json` and "cosmic-blue" `os-release`;
  - `50-services.sh`: services from section 2d, Flathub;
  - `60-initramfs.sh`, `90-cleanup.sh` (third-party repos disabled), `99-tests.sh`
    (checks, among other things, that COSMIC comes from Fedora and that GNOME Shell is absent).
- `system_files/`: a few files taken from `ublue-os/bluefin`
  (`flatpak-nuke-fedora`, setup hooks, starship), the first-boot flatpak list
  (`cosmic-blue.preinstall`) and a COSMIC-adapted `system-flatpaks` Brewfile.
- Signing: `build.yml` signs each image pushed from `main` with the cosign key in
  the `SIGNING_SECRET` secret. The public key (`cosign.pub`) ships as
  `/etc/pki/containers/cosmic-blue.pub`, with a `policy.json` entry and a
  `registries.d` file, so the image is referenced as `ostree-image-signed` and
  bootc verifies updates.

- Disk images (bootc-image-builder): a qcow2 VM disk and an Anaconda installer
  ISO, built locally only (`just build-qcow2`, `just build-iso`). The CI workflow
  was removed: the live ISO replaces the installer ISO and the boot test in
  `build.yml` replaces the qcow2.
- Live ISO (`build-live-iso.yml`, ublue-os/titanoboa as in projectbluefin/iso):
  boots into a COSMIC live session with a shortcut to Anaconda, which installs
  the image embedded in the ISO. Live-only changes are in
  `iso_files/configure_live_iso.sh`.

Not done yet: DX variant, ZFS kernel.
