# cosmic-blue

cosmic-blue is a Bluefin-like [Universal Blue](https://universal-blue.org/) image
with the [COSMIC](https://system76.com/cosmic) desktop instead of GNOME.

- Image: `ghcr.io/cosmic-blue-os/cosmic-blue:latest`
- Source: https://github.com/cosmic-blue-os/cosmic-blue

It is an atomic (bootc) Fedora system: the whole OS is a container image, updates
are applied in the background and take effect on the next reboot, and you can
always roll back to the previous version.

## What's inside

- **Base:** `ghcr.io/ublue-os/base-main:latest`, the Universal Blue "main" layer
  without any desktop: Fedora, multimedia codecs, ublue signing keys, `ujust`,
  udev rules and Flathub.
- **Desktop:** COSMIC from the official Fedora repositories (no COPR), with
  `cosmic-greeter` as the login screen and the COSMIC Files, Edit, Terminal and
  Player apps.
- **The Bluefin experience, minus GNOME:** the
  [projectbluefin/common](https://github.com/projectbluefin/common) layer
  (`ujust` recipes, automatic updates with `uupd`, first-boot setup, `bling`
  shell prompt) and [Homebrew](https://github.com/ublue-os/brew), without the
  GNOME settings and the Bluefin branding.
- **Packages:** the extra Fedora packages Bluefin adds (shells, backup tools,
  printer drivers, Samba and enterprise login, fonts, hardware tools), plus
  Tailscale.
- **Flatpaks:** Firefox and a set of apps from Bluefin's list are installed
  from Flathub on first boot.
- Fedora and COSMIC defaults for wallpaper, boot splash and logos.

## Install

### Live ISO (new installs)

A live ISO boots straight into a COSMIC desktop. Start the installer from the
desktop or dock icon. The installed system then follows
`ghcr.io/cosmic-blue-os/cosmic-blue:latest` and checks its signature on every
update.

The ISO is built every Monday and can be downloaded (when signed in to GitHub)
from the latest successful
[Build live ISO](https://github.com/cosmic-blue-os/cosmic-blue/actions/workflows/build-live-iso.yml)
run, under *Artifacts*.

### Switching an existing system

From any bootc-based Fedora system (Bluefin, Aurora, Bazzite, Fedora Atomic...):

```bash
sudo bootc switch ghcr.io/cosmic-blue-os/cosmic-blue:latest
sudo systemctl reboot
```

Systems installed before the move to the `cosmic-blue-os` organization still
track `ghcr.io/njal57/cosmic-blue`, which no longer receives updates. Run the
same command to move them to the new image.

## Image signature

Every image is signed with [cosign](https://github.com/sigstore/cosign). The
public key is [`cosign.pub`](cosign.pub) and is also shipped in the image
(`/etc/pki/containers/cosmic-blue.pub`), with a container policy that only
accepts cosmic-blue images signed with it. To check an image by hand:

```bash
cosign verify --key cosign.pub ghcr.io/cosmic-blue-os/cosmic-blue:latest
```

## Builds

- The image is rebuilt every day at 10:30 UTC, and on every push to `main`.
- The live ISO is rebuilt every Monday at 11:30 UTC.
- An Anaconda installer ISO and a qcow2 VM disk can be built on demand with the
  [Build disk images](https://github.com/cosmic-blue-os/cosmic-blue/actions/workflows/build-disk.yml)
  workflow.

To build locally, with [just](https://just.systems/) and podman:

```bash
just build        # container image
just build-qcow2  # VM disk
just run-vm       # boot it
```

## Repository layout

- `Containerfile`: image definition.
- `build_files/`: build steps, run in order by `build.sh`.
- `system_files/`: files copied into the image.
- `disk_config/`: bootc-image-builder settings for the installer ISO and VM disks.
- `iso_files/`: live ISO setup.
- `.github/workflows/`: image, disk image and live ISO builds.

## Credits

cosmic-blue is built on the work of [Universal Blue](https://github.com/ublue-os),
[Bluefin](https://github.com/projectbluefin), [Fedora](https://fedoraproject.org/)
and [System76](https://github.com/pop-os/cosmic-epoch). It started from the
[ublue-os/image-template](https://github.com/ublue-os/image-template) repository.
