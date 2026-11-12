<p align="center"><img src="branding/logo/cosmic-blue-logo-horizontal-dark.svg#gh-dark-mode-only" alt="cosmic-blue" width="420"><img src="branding/logo/cosmic-blue-logo-horizontal-light.svg#gh-light-mode-only" alt="cosmic-blue" width="420"></p>

# cosmic-blue

cosmic-blue is a Bluefin-like [Universal Blue](https://universal-blue.org/) image
with the [COSMIC](https://system76.com/cosmic) desktop instead of GNOME.

- Image: `ghcr.io/cosmic-blue-os/cosmic-blue:latest`
- Source: https://github.com/cosmic-blue-os/cosmic-blue

It is an atomic (bootc) Fedora system: the whole OS is a container image, updates
are applied in the background and take effect on the next reboot, and you can
always roll back to the previous version.

<p align="center"><img src="docs/screenshots/wallpaper.jpg" alt="The default cosmic-blue wallpaper: a planet inside the glowing orbit of the logo, over the Milky Way" width="800"></p>

## What's inside

- **Base:** `ghcr.io/ublue-os/base-main:44` (Fedora 44, like Bluefin), the Universal Blue "main" layer
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
- Dark theme by default (COSMIC and GTK apps), with frosted glass and colors
  built around the blue of the logo and wallpaper: a blue accent (#4f8dff
  dark, #1d47c4 light) that also colors the outline of the active window,
  night blue window backgrounds and slightly blue controls.
- Icon theme "cosmic-blue": COSMIC's own symbolic icons with Papirus-Dark
  icons (blue folders) for apps and files, both from Fedora. Other themes
  can be picked in COSMIC Settings.
- Its own wallpaper and logo, also on the boot screen (sources in
  [`branding/`](branding/)); Fedora's wallpaper stays available in COSMIC
  Settings.

## Install

### Requirements

- A 64-bit x86 PC (amd64). ARM images are not built yet.
- At least 4 GB of RAM (8 GB recommended) and about 50 GB of disk.
- There is no image with the proprietary Nvidia driver yet: Nvidia GPUs use
  the open-source nouveau driver.

### Live ISO (new installs)

The live ISO boots straight into a COSMIC desktop, so you can try cosmic-blue
before installing it.

1. **Download.** The ISO is rebuilt every Monday. Open the latest successful
   [Build live ISO](https://github.com/cosmic-blue-os/cosmic-blue/actions/workflows/build-live-iso.yml)
   run and download `cosmic-blue-live-amd64-iso` under *Artifacts* (you must be
   signed in to GitHub). It is a zip file that holds
   `cosmic-blue-live-amd64.iso`.
2. **Write it to a USB stick** (8 GB or more, it will be erased) with
   [Fedora Media Writer](https://fedoraproject.org/workstation/download) or
   any tool that writes raw images, for example:

   ```bash
   sudo dd if=cosmic-blue-live-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

   Replace `/dev/sdX` with your USB stick (check with `lsblk`).
   To try it in a virtual machine instead, open the ISO in GNOME Boxes or
   virt-manager.
3. **Boot it.** Pick the USB stick in your firmware's boot menu.
4. **Install.** Start the installer from the desktop or dock icon, then pick
   your language, keyboard, disk and user account. A short welcome tour
   explains the live session.
5. **Reboot** into the installed system. On first boot, cosmic-blue sets up
   Flathub and installs the default apps in the background, then
   COSMIC's first-run assistant offers to set the appearance.

The installed system follows `ghcr.io/cosmic-blue-os/cosmic-blue:latest` and
checks the signature of every update.

### Switching an existing system

From any bootc-based Fedora system (Bluefin, Aurora, Bazzite, Fedora Atomic...):

```bash
sudo bootc switch ghcr.io/cosmic-blue-os/cosmic-blue:latest
sudo systemctl reboot
```

Your home folder, Flatpaks, Homebrew packages and changes in `/etc` are kept.
The desktop settings already saved in your account are kept too:
cosmic-blue's defaults (theme, icons, wallpaper) only apply to the settings
you never changed. See [Troubleshooting](#troubleshooting) to reset them.

To go back, switch to your previous image the same way, for example
`sudo bootc switch ghcr.io/ublue-os/bluefin:stable`.

Systems installed before the move to the `cosmic-blue-os` organization still
track `ghcr.io/njal57/cosmic-blue`, which no longer receives updates. Run the
same command to move them to the new image.

## Updates and rollback

Updates are downloaded automatically in the background (by `uupd`, which also
updates Flatpaks and Homebrew) and applied on the next reboot. To update by
hand, or to see what is running:

```bash
ujust update          # update the system, Flatpaks and Homebrew now
sudo bootc status     # show the booted image and the one staged for next boot
```

If an update breaks something, boot the previous version, either by picking
it in the boot menu or with:

```bash
sudo bootc rollback
sudo systemctl reboot
```

Run `ujust` alone to list the other maintenance recipes.

## Image signature

Every image is signed with [cosign](https://github.com/sigstore/cosign). The
public key is [`cosign.pub`](cosign.pub) and is also shipped in the image
(`/etc/pki/containers/cosmic-blue.pub`), with a container policy that only
accepts cosmic-blue images signed with it. To check an image by hand:

```bash
curl -LO https://raw.githubusercontent.com/cosmic-blue-os/cosmic-blue/main/cosign.pub
cosign verify --key cosign.pub ghcr.io/cosmic-blue-os/cosmic-blue:latest
```

On an installed system, `rpm-ostree` and `bootc` refuse an update whose
signature does not match, so you do not need to check anything by hand.

## Troubleshooting

**The theme is still teal, or the icons or wallpaper are not cosmic-blue's.**
COSMIC keeps the settings saved in your account (for example after a
`bootc switch` from another COSMIC system). To return to cosmic-blue's
defaults, log out, switch to a text console (Ctrl+Alt+F3), log in and run:

```bash
rm -rf ~/.config/cosmic/com.system76.CosmicTheme.{Dark,Light}{,.Builder}
rm -rf ~/.config/cosmic/com.system76.CosmicTk ~/.config/cosmic/com.system76.CosmicBackground
```

The login screen uses the theme of the selected user, so it follows too.

**Something else is wrong.** Please open an
[issue](https://github.com/cosmic-blue-os/cosmic-blue/issues) with the output
of `sudo bootc status`.

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
