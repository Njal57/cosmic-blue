# COSMIC-blue: a Bluefin-like Universal Blue image with COSMIC instead of GNOME.
# See docs/plan.md for the choice of base image and the inventory.

ARG BASE_IMAGE="ghcr.io/ublue-os/base-main"
ARG BASE_TAG="latest"
ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"

# Bluefin shared files (ujust, uupd, setup, signing, udev...) and Homebrew
FROM ${COMMON_IMAGE} AS common
FROM ${BREW_IMAGE} AS brew

# Build context: scripts + system files, never copied as-is into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY --from=common /system_files/shared /system_files/common
COPY --from=common /system_files/bluefin /system_files/common-bluefin
COPY --from=brew /system_files /system_files/brew
# Our own files, applied last so they take precedence
COPY system_files /system_files/cosmic-blue

FROM ${BASE_IMAGE}:${BASE_TAG}

ARG IMAGE_NAME="cosmic-blue"
ARG IMAGE_VENDOR="njal57"
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
