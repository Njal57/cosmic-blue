#!/usr/bin/bash
# NVIDIA proprietary driver, only for the cosmic-blue-nvidia image.
#
# Same method as Bluefin (ublue-os/bluefin build_files/base/03-install-kernel-akmods.sh):
# the open kernel modules (Turing / GTX 16xx and newer) come prebuilt from
# ghcr.io/ublue-os/akmods-nvidia-open, built for the exact kernel of
# base-main and signed with the Universal Blue akmods key. The kernel itself
# stays Fedora's, signed by Fedora, so Secure Boot works once that key is
# enrolled as a Machine Owner Key: `ujust enroll-secure-boot-key`, which
# imports /etc/pki/akmods/certs/akmods-ublue.der (from base-main).
set -euox pipefail

if [[ "${IMAGE_NAME}" != *-nvidia ]]; then
    echo "Not an NVIDIA image, nothing to do"
    exit 0
fi

# The modules must match the kernel of the image: pick the akmods build for it
# rather than the latest one, so a newer kernel in akmods cannot break the build.
KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | head -n1)"
AKMODS_IMAGE="ghcr.io/ublue-os/akmods-nvidia-open:main-${FEDORA_MAJOR_VERSION}-${KVER}"

command -v skopeo >/dev/null || dnf5 -y install skopeo
skopeo copy --retry-times 3 "docker://${AKMODS_IMAGE}" dir:/tmp/akmods-nvidia
# The image holds a single layer with rpms/{kmods,nvidia,ublue-os}
NVIDIA_TARGZ="$(jq -r '.layers[].digest' </tmp/akmods-nvidia/manifest.json | cut -d : -f 2)"
mkdir -p /tmp/akmods-nvidia-layer
tar -xzf "/tmp/akmods-nvidia/${NVIDIA_TARGZ}" -C /tmp/akmods-nvidia-layer
AKMODNV_PATH=/tmp/akmods-nvidia-layer/rpms
find "${AKMODNV_PATH}"

# Fedora's Go build of the container toolkit conflicts with NVIDIA's own
# (same exclusion as Bluefin)
dnf5 config-manager setopt excludepkgs=golang-github-nvidia-container-toolkit

# Universal Blue's install script, shipped with the modules: installs the
# driver, the modules, egl-wayland, libva-nvidia-driver and the container
# toolkit, checks the module and driver versions match, forces the nvidia
# modules into the initramfs and enables the CDI and persistenced services.
# No 32-bit libraries (MULTILIB=0): Steam and games come as flatpaks.
# IMAGE_NAME=base: no GNOME/KDE-specific extras.
IMAGE_NAME=base AKMODNV_PATH="${AKMODNV_PATH}" MULTILIB=0 \
    "${AKMODNV_PATH}/ublue-os/nvidia-install.sh"

# Vulkan: only the NVIDIA driver, not nouveau's (as in Bluefin)
rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json
# Some CUDA/NVML tools look for the unversioned library
ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so

# Kernel arguments applied by bootc on install and on switch: keep nouveau
# away, enable kernel modesetting (needed by Wayland compositors such as
# cosmic-comp) and skip the firmware framebuffer driver so it does not linger
# as a second, unaccelerated display.
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "initcall_blacklist=simpledrm_platform_driver_init"]
EOF

rm -rf /tmp/akmods-nvidia /tmp/akmods-nvidia-layer
