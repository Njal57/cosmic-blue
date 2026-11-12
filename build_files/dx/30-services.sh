#!/usr/bin/bash
# DX services, as in Bluefin DX.
set -euox pipefail

systemctl enable \
    cosmic-blue-dx-groups.service \
    docker.socket \
    libvirt-workaround.service \
    podman.socket
