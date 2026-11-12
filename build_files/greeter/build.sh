#!/usr/bin/bash
# Rebuilds Fedora's cosmic-greeter package with the cosmic-blue wallpaper as
# its built-in background, from the same source package and build flags as
# Fedora. Runs in a Fedora container of the same release as the image; the
# binary is written to /out and installed by build_files/23-greeter.sh.
#
# Why: the login screen shows the wallpaper that cosmic-bg last saved for the
# selected user and for each screen (~/.local/state/cosmic/
# com.system76.CosmicBackground). Until a user has opened a session once, and
# on any screen that user never used, cosmic-greeter falls back to the image
# compiled into it (res/background.jpg, the upstream COSMIC wallpaper). The
# lock screen is the same program and uses the same fallback.
# Usage: build.sh <wallpaper.jpg>
set -euox pipefail

WALLPAPER="$1"
TOPDIR=/rpmbuild
SPEC="${TOPDIR}/SPECS/cosmic-greeter.spec"

dnf5 -y install rpm-build dnf5-plugins python3
mkdir -p /srpm "${TOPDIR}"
dnf5 -y download --srpm --destdir /srpm \
    --enablerepo=fedora-source --enablerepo=updates-source \
    cosmic-greeter
dnf5 -y builddep /srpm/cosmic-greeter-*.src.rpm
rpm -i --define "_topdir ${TOPDIR}" /srpm/cosmic-greeter-*.src.rpm

# Unpack the sources (vendored crates included) and apply Fedora's patches
rpmbuild --define "_topdir ${TOPDIR}" -bp "${SPEC}"

src=""
while IFS= read -r manifest; do
    if grep -q '^name = "cosmic-greeter"' "${manifest}"; then
        src="$(dirname "${manifest}")"
        break
    fi
done < <(find "${TOPDIR}/BUILD" -name Cargo.toml -not -path '*/vendor/*')
test -n "${src}"

# The fallback must still be this file, or the replacement would do nothing
grep -q 'include_bytes!("../res/background.jpg")' "${src}/src/common.rs"
install -m 0644 "${WALLPAPER}" "${src}/res/background.jpg"

# Build only (no new %prep, which would undo the replacement)
rpmbuild --define "_topdir ${TOPDIR}" -bc --short-circuit "${SPEC}"

bin="$(find "${src}/target" -type f -name cosmic-greeter -perm -u+x | head -n1)"
test -n "${bin}"
# The wallpaper really is inside the binary
python3 - "${bin}" "${WALLPAPER}" <<'PY'
import sys
binary = open(sys.argv[1], "rb").read()
image = open(sys.argv[2], "rb").read()
if image not in binary:
    sys.exit("the cosmic-blue wallpaper is not embedded in cosmic-greeter")
PY
mkdir -p /out
install -m 0755 "${bin}" /out/cosmic-greeter
# The version the binary was built from, checked against the image's package
rpm -qp --qf '%{VERSION}-%{RELEASE}\n' /srpm/cosmic-greeter-*.src.rpm > /out/version
cat /out/version
