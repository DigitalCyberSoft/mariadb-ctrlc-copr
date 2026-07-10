#!/bin/bash
# Rebuild a Fedora mariadb srpm with the restore-ctrlc-exit patch:
#  - adds Patch1000 (mariadb-restore-ctrlc-exit.patch) and applies it in %prep
#  - bumps Epoch 3 -> 4 so the patched build always beats distro packages
#  - suffixes Release with .dcs1
#  - loosens the client subpackage's mariadb-common dep to ">= 3:%{version}"
#    (distro epoch pinned literally; distro common/errmsg/server stay installed)
#  - adds a changelog entry
# Usage: make-patched-srpm.sh <input.src.rpm> <output-dir> <patchfile>
set -euo pipefail

SRPM=$(readlink -f "$1")
OUT=$(readlink -f "$2")
PATCHFILE=$(readlink -f "$3")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mariadb-ctrlc.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

rpm --define "_topdir $WORK" -i "$SRPM"
SPEC=$(ls "$WORK"/SPECS/*.spec)
cp "$PATCHFILE" "$WORK/SOURCES/mariadb-restore-ctrlc-exit.patch"

# 1. Patch1000 declaration after the last PatchN: line
LN=$(grep -n '^Patch[0-9]\+:' "$SPEC" | tail -1 | cut -d: -f1)
[ -n "$LN" ]
sed -i "${LN}a Patch1000:        mariadb-restore-ctrlc-exit.patch" "$SPEC"

# 2. application after the last %patch line in %prep
LN=$(grep -n '^%patch -P[0-9]\+' "$SPEC" | tail -1 | cut -d: -f1)
[ -n "$LN" ]
sed -i "${LN}a %patch -P1000 -p1" "$SPEC"

# 3. Epoch 3 -> 4 (abort if the distro epoch is no longer 3)
grep -q '^Epoch:[[:space:]]*3$' "$SPEC"
sed -i 's/^Epoch:\([[:space:]]*\)3$/Epoch:\14/' "$SPEC"

# 4. Release suffix
sed -i 's/^\(Release:[[:space:]]*.*\)$/\1.dcs1/' "$SPEC"

# 5. loosen ONLY the first (client subpackage) -common dep, epoch pinned to distro's 3
sed -i '0,/^Requires:\([[:space:]]*\)%{pkgname}-common = %{sameevr}$/s//Requires:\1%{pkgname}-common >= 3:%{version}/' "$SPEC"
grep -q 'common >= 3:%{version}' "$SPEC"

# 6. changelog
VER=$(grep -m1 -E '^%(define|global)[[:space:]]+package_version' "$SPEC" | awk '{print $3}')
REL=$(grep -m1 '^Release:' "$SPEC" | awk '{print $2}' | grep -o '^[0-9]\+')
sed -i "/^%changelog/a * $(LC_ALL=C date +'%a %b %d %Y') DigitalCyberSoft <claude@dcs.io> - 4:${VER}-${REL}.dcs1\n- Restore pre-MDEV-14448 Ctrl-C behavior: Ctrl-C at an idle prompt exits\n  the client, Ctrl-C during a query kills the query, repeated Ctrl-C exits\n- Bump Epoch to 4 so this build stays ahead of distro updates\n- Loosen client dep on mariadb-common so distro server packages coexist\n" "$SPEC"

rpmbuild --define "_topdir $WORK" -bs --nodeps "$SPEC" >/dev/null
cp "$WORK"/SRPMS/*.src.rpm "$OUT/"
ls "$OUT"/*.dcs1.src.rpm | tail -1
