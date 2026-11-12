#!/usr/bin/bash
# Point the docker CLI (from `ujust devmode` or Homebrew) at the user's rootless
# Podman socket, through a "podman" docker context, so that docker, docker
# compose and VS Code devcontainers work without a Docker daemon.
# An existing docker configuration is left alone; `docker context use default`
# switches back to a real Docker daemon.

source /usr/lib/ublue/setup-services/libsetup.sh

version-script-check docker-podman user 1 || exit 0

set -euxo pipefail

CONTEXT="podman"
DOCKER_DIR="${HOME}/.docker"
META_DIR="${DOCKER_DIR}/contexts/meta/$(printf '%s' "${CONTEXT}" | sha256sum | cut -d' ' -f1)"
SOCKET="unix:///run/user/$(id -u)/podman/podman.sock"

if [[ ! -e "${DOCKER_DIR}/config.json" ]] || ! jq -e '.currentContext' "${DOCKER_DIR}/config.json" >/dev/null; then
    mkdir -p "${META_DIR}"
    jq -n --arg name "${CONTEXT}" --arg host "${SOCKET}" '{
        Name: $name,
        Metadata: {Description: "Rootless Podman (cosmic-blue)"},
        Endpoints: {docker: {Host: $host, SkipTLSVerify: false}}
    }' > "${META_DIR}/meta.json"
    if [[ -e "${DOCKER_DIR}/config.json" ]]; then
        jq --arg name "${CONTEXT}" '.currentContext = $name' "${DOCKER_DIR}/config.json" > "${DOCKER_DIR}/config.json.new"
        mv "${DOCKER_DIR}/config.json.new" "${DOCKER_DIR}/config.json"
    else
        jq -n --arg name "${CONTEXT}" '{currentContext: $name}' > "${DOCKER_DIR}/config.json"
    fi
fi

version-script-commit docker-podman user 1
