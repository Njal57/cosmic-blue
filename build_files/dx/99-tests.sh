#!/usr/bin/bash
# DX checks: if one fails, the build fails.
set -euox pipefail

IMPORTANT_PACKAGES=(
    bpftrace
    code
    cockpit-bridge
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-compose-plugin
    flatpak-builder
    incus
    libvirt
    podman-compose
    qemu
    virt-manager
    # still the cosmic-blue desktop underneath
    cosmic-session
    uupd
)
for package in "${IMPORTANT_PACKAGES[@]}"; do
    rpm -q "${package}" >/dev/null || { echo "Missing package: ${package}"; exit 1; }
done

for unit in cosmic-blue-dx-groups.service docker.socket libvirt-workaround.service podman.socket; do
    systemctl is-enabled "${unit}"
done
test -x /usr/bin/cosmic-blue-dx-groups

# Third-party repos are disabled in the final image
for repo in /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/vscode.repo; do
    if grep -q '^enabled=1' "${repo}"; then
        echo "Repo left enabled: ${repo}"; exit 1
    fi
done

# Identity: cosmic-blue-dx, signed with the cosmic-blue key
jq -e '."image-name" == "cosmic-blue-dx" and ."image-flavor" == "dx"' /usr/share/ublue-os/image-info.json >/dev/null
jq -e '."image-ref" == "ostree-image-signed:docker://ghcr.io/cosmic-blue-os/cosmic-blue-dx"' \
    /usr/share/ublue-os/image-info.json >/dev/null
grep -q '^IMAGE_ID="cosmic-blue-dx"$' /usr/lib/os-release
grep -q '^VARIANT_ID=cosmic-blue-dx$' /usr/lib/os-release
for image in cosmic-blue cosmic-blue-dx; do
    jq -e --arg image "ghcr.io/cosmic-blue-os/${image}" \
        '.transports.docker[$image][0].keyPath == "/etc/pki/containers/cosmic-blue.pub"' \
        /etc/containers/policy.json >/dev/null
done
grep -q '^  ghcr.io/cosmic-blue-os/cosmic-blue-dx:$' /etc/containers/registries.d/cosmic-blue.yaml
test ! -e /etc/containers/registries.d/cosmic-blue-dx.yaml

# rpm-ostree's /home equivalence survived the selinux-policy update
if grep -qE '^/var/home[[:space:]]+/home$' /etc/selinux/targeted/contexts/files/file_contexts.subs_dist; then
    echo "SELinux /home equivalence was reverted"; exit 1
fi

test -f /usr/share/flatpak/preinstall.d/cosmic-blue-dx.preinstall
test -s /etc/skel/.config/Code/User/settings.json
