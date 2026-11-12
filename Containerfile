# cosmic-blue: a Bluefin-like Universal Blue image with COSMIC instead of GNOME.
# See docs/plan.md for the choice of base image and the inventory.

# Fedora release: the one of Bluefin's stable tag. check-cosmic-version.yml
# opens the pull request that moves BASE_TAG and BASE_IMAGE together when
# Bluefin stable moves to a new release (in 2026-11, Fedora 45 still broke the
# live ISO installer: systemd-tmpfiles exited with code 73).
# Renovate only pins and updates the image digests (see .github/renovate.json5).
ARG BASE_TAG="44"
ARG BASE_IMAGE="ghcr.io/ublue-os/base-main:44"
ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"

# Bluefin shared files (ujust, uupd, setup, signing, udev...) and Homebrew
FROM ${COMMON_IMAGE} AS common
FROM ${BREW_IMAGE} AS brew

# Default COSMIC themes with frosted glass (see build_files/theme/src/main.rs)
FROM docker.io/library/rust:1 AS theme
COPY build_files/theme /theme
RUN cd /theme && cargo build --release \
    && XDG_CONFIG_HOME=/out /theme/target/release/cosmic-blue-theme

# COSMIC's first-run assistant, rebuilt from Fedora's source package with the
# cosmic-blue patches (see build_files/initial_setup/patch.py)
FROM registry.fedoraproject.org/fedora:${BASE_TAG} AS initial_setup
COPY build_files/initial_setup /initial_setup
RUN /initial_setup/build.sh

# Login and lock screens, rebuilt from Fedora's source package with the
# cosmic-blue wallpaper as their built-in background
# (see build_files/greeter/build.sh)
FROM registry.fedoraproject.org/fedora:${BASE_TAG} AS greeter
COPY build_files/greeter /greeter
COPY system_files/usr/share/backgrounds/cosmic-blue/cosmic-blue.jpg /greeter/background.jpg
RUN /greeter/build.sh /greeter/background.jpg

# Boot screen spinner frames, tinted with the logo blue
# (see build_files/plymouth/tint.py)
FROM registry.fedoraproject.org/fedora:${BASE_TAG} AS plymouth
COPY build_files/plymouth /plymouth
RUN dnf5 -y install plymouth-theme-spinner python3-pillow \
    && python3 /plymouth/tint.py /usr/share/plymouth/themes/spinner /out

# Tela circle icons, recolored with the logo blue
# (see build_files/icon_theme/tela.sh)
FROM registry.fedoraproject.org/fedora:${BASE_TAG} AS icons
COPY build_files/icon_theme/tela.sh /tela.sh
RUN /tela.sh

# Bibata Modern cursors, recolored with the cosmic-blue colors
# (see build_files/cursor_theme/bibata.py)
FROM registry.fedoraproject.org/fedora:${BASE_TAG} AS cursors
COPY build_files/cursor_theme /cursor_theme
RUN /cursor_theme/bibata.sh

# Build context: scripts + system files, never copied as-is into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY --from=common /system_files/shared /system_files/common
COPY --from=common /system_files/bluefin /system_files/common-bluefin
COPY --from=brew /system_files /system_files/brew
# Our own files, applied last so they take precedence
COPY system_files /system_files/cosmic-blue
COPY --from=theme /out/cosmic /system_files/cosmic-blue/usr/share/cosmic
COPY --from=initial_setup /out /initial_setup
COPY --from=greeter /out /greeter
COPY --from=plymouth /out /system_files/cosmic-blue/usr/share/plymouth/themes/cosmic-blue
COPY --from=icons /out /icons
COPY --from=cursors /out /system_files/cosmic-blue/usr/share/icons
# Public key used to verify the image signature on update
COPY cosign.pub /system_files/cosmic-blue/etc/pki/containers/cosmic-blue.pub

FROM ${BASE_IMAGE}

ARG IMAGE_NAME="cosmic-blue"
ARG IMAGE_VENDOR="cosmic-blue-os"
ARG UBLUE_IMAGE_TAG="latest"
ARG VERSION=""

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" IMAGE_VENDOR="${IMAGE_VENDOR}" \
    UBLUE_IMAGE_TAG="${UBLUE_IMAGE_TAG}" VERSION="${VERSION}" \
    /ctx/build_files/build.sh

RUN bootc container lint
