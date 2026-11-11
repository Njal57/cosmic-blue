#!/usr/bin/bash
# Rebuilds Fedora's cosmic-initial-setup package with the cosmic-blue patches
# (see patch.py), from the same source package and build flags as Fedora.
# Runs in a Fedora container of the same release as the image; the binary is
# written to /out and installed by build_files/22-initial-setup.sh.
set -euox pipefail

TOPDIR=/rpmbuild
SPEC="${TOPDIR}/SPECS/cosmic-initial-setup.spec"

dnf5 -y install rpm-build dnf5-plugins python3
mkdir -p /srpm "${TOPDIR}"
dnf5 -y download --srpm --destdir /srpm \
    --enablerepo=fedora-source --enablerepo=updates-source \
    cosmic-initial-setup
dnf5 -y builddep /srpm/cosmic-initial-setup-*.src.rpm
rpm -i --define "_topdir ${TOPDIR}" /srpm/cosmic-initial-setup-*.src.rpm

# Unpack the sources (vendored crates included) and apply Fedora's patches
rpmbuild --define "_topdir ${TOPDIR}" -bp "${SPEC}"

src=""
while IFS= read -r manifest; do
    if grep -q '^name = "cosmic-initial-setup"' "${manifest}"; then
        src="$(dirname "${manifest}")"
        break
    fi
done < <(find "${TOPDIR}/BUILD" -name Cargo.toml -not -path '*/vendor/*')
test -n "${src}"

python3 /initial_setup/patch.py "${src}"

# Build only (no new %prep, which would undo the patches)
rpmbuild --define "_topdir ${TOPDIR}" -bc --short-circuit "${SPEC}"

bin="$(find "${src}/target" -type f -name cosmic-initial-setup -perm -u+x | head -n1)"
test -n "${bin}"
mkdir -p /out
install -m 0755 "${bin}" /out/cosmic-initial-setup
# The version the binary was built from, checked against the image's package
rpm -qp --qf '%{VERSION}-%{RELEASE}\n' /srpm/cosmic-initial-setup-*.src.rpm > /out/version
cat /out/version
