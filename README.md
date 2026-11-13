<p align="center"><img src="branding/logo/cosmic-blue-logo-horizontal-dark.svg#gh-dark-mode-only" alt="cosmic-blue" width="420"><img src="branding/logo/cosmic-blue-logo-horizontal-light.svg#gh-light-mode-only" alt="cosmic-blue" width="420"></p>

# cosmic-blue

cosmic-blue is a Bluefin-like [Universal Blue](https://universal-blue.org/) image
based on Fedora 44, with the [COSMIC](https://system76.com/cosmic) desktop
instead of GNOME.

It is an atomic (bootc) system: updates are applied in the background, take
effect on the next reboot, and can be rolled back.

## Install

**New install:** download `cosmic-blue-live-amd64-iso` from the latest
successful
[Build live ISO](https://github.com/cosmic-blue-os/cosmic-blue/actions/workflows/build-live-iso.yml)
run (under *Artifacts*, signed in to GitHub), write the ISO to a USB stick
with [Fedora Media Writer](https://fedoraproject.org/workstation/download),
boot it and start the installer from the desktop icon.

**From another bootc system** (Bluefin, Aurora, Bazzite, Fedora Atomic...):

```bash
sudo bootc switch ghcr.io/cosmic-blue-os/cosmic-blue:stable
sudo systemctl reboot
```

`stable` moves once a week to a build that has spent a week on `latest`.
`latest` gets every daily build; use it instead of `stable` to get changes
sooner.

**NVIDIA graphics cards** (GTX 16xx, RTX 20xx and newer): use the
`cosmic-blue-nvidia` image, which ships NVIDIA's driver. For a new install,
take `cosmic-blue-nvidia-live-amd64-iso` instead. From an installed system:

```bash
ujust enroll-secure-boot-key   # only if Secure Boot is on
sudo bootc switch ghcr.io/cosmic-blue-os/cosmic-blue-nvidia:stable
sudo systemctl reboot
```

With Secure Boot on, a blue screen (MOK manager) shows up on the first reboot:
choose *Enroll MOK*, then *Continue*, and type the password `universalblue`
(QWERTY keyboard layout).

## Updates and rollback

```bash
ujust update          # update now instead of waiting for the automatic update
sudo bootc rollback   # go back to the previous version on next boot
```

What changed in each `stable` version (packages, COSMIC, cosmic-blue):
[Releases](https://github.com/cosmic-blue-os/cosmic-blue/releases).

## Developer tools

```bash
ujust devmode   # Docker, VS Code, Podman Desktop and other developer tools
```

## Image signature

Images are signed with [cosign](https://github.com/sigstore/cosign) and
installed systems refuse unsigned updates. To check by hand with
[`cosign.pub`](cosign.pub):

```bash
cosign verify --key cosign.pub ghcr.io/cosmic-blue-os/cosmic-blue:stable
```

## Credits

Built on [Universal Blue](https://github.com/ublue-os),
[Bluefin](https://github.com/projectbluefin), [Fedora](https://fedoraproject.org/)
and [COSMIC](https://github.com/pop-os/cosmic-epoch), from the
[ublue-os/image-template](https://github.com/ublue-os/image-template) repository.
The Milky Way wallpaper is a photo taken on the International Space Station,
courtesy of NASA.
