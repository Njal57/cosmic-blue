#!/usr/bin/bash
# Disable all third-party repos and clean up.
set -euox pipefail

shopt -s nullglob
for repo_file in \
    /etc/yum.repos.d/tailscale.repo \
    /etc/yum.repos.d/_copr:*.repo \
    /etc/yum.repos.d/rpmfusion-*.repo \
    /etc/yum.repos.d/negativo17-*.repo \
    /etc/yum.repos.d/fedora-cisco-openh264.repo \
    /usr/share/dnf5/repos.d/*.repo; do
    [[ -f "${repo_file}" ]] || continue
    case "$(basename "${repo_file}")" in
        fedora-cisco-openh264.repo) ;;
        fedora*.repo) continue ;;  # official Fedora repos: leave them as they are
    esac
    sed -i 's@enabled=1@enabled=0@g' "${repo_file}"
done

dnf5 clean all
rm -rf /var/lib/dnf /var/cache/* /tmp/* || true
