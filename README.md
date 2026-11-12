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
sudo bootc switch ghcr.io/cosmic-blue-os/cosmic-blue:latest
sudo systemctl reboot
```

## Updates and rollback

```bash
ujust update          # update now instead of waiting for the automatic update
sudo bootc rollback   # go back to the previous version on next boot
```

## Developer tools

```bash
ujust devmode   # Docker, VS Code, Podman Desktop and other developer tools
```

## Image signature

Images are signed with [cosign](https://github.com/sigstore/cosign) and
installed systems refuse unsigned updates. To check by hand with
[`cosign.pub`](cosign.pub):

```bash
cosign verify --key cosign.pub ghcr.io/cosmic-blue-os/cosmic-blue:latest
```

## Credits

Built on [Universal Blue](https://github.com/ublue-os),
[Bluefin](https://github.com/projectbluefin), [Fedora](https://fedoraproject.org/)
and [COSMIC](https://github.com/pop-os/cosmic-epoch), from the
[ublue-os/image-template](https://github.com/ublue-os/image-template) repository.
