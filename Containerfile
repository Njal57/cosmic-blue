# COSMIC-blue : une image Universal Blue façon Bluefin, avec COSMIC à la place de GNOME.
# Voir docs/plan.md pour le choix de la base et l'inventaire.

ARG BASE_IMAGE="ghcr.io/ublue-os/base-main"
ARG BASE_TAG="latest"
ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"

# Fichiers partagés de Bluefin (ujust, uupd, setup, signature, udev...) et Homebrew
FROM ${COMMON_IMAGE} AS common
FROM ${BREW_IMAGE} AS brew

# Contexte de build : scripts + fichiers système, jamais copiés tels quels dans l'image finale
FROM scratch AS ctx
COPY build_files /build_files
COPY --from=common /system_files/shared /system_files/common
COPY --from=common /system_files/bluefin /system_files/common-bluefin
COPY --from=brew /system_files /system_files/brew
# Nos propres fichiers, appliqués en dernier pour avoir la priorité
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
