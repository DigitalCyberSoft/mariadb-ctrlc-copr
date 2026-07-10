#!/bin/bash
# Compare a Fedora release's default mariadb source package against the newest
# build in the COPR project; when the distro is newer, produce a patched srpm
# (make-patched-srpm.sh) and submit it to the given COPR chroots.
# Runs inside a Fedora container (GitHub Actions) with copr-cli configured.
# Usage: check-and-build.sh <releasever> <chroot> [<chroot>...]
set -euo pipefail

REL=$1; shift
PROJECT=reversejames/mariadb-ctrlc-exit
PATCH=$(readlink -f mariadb-restore-ctrlc-exit.patch)

# rawhide repo definitions ship separately and are disabled by default
if [ "$REL" = rawhide ]; then
  dnf -y install fedora-repos-rawhide >/dev/null
  REPO_ARGS=(--releasever=rawhide --disablerepo='*' --enablerepo=rawhide --enablerepo=rawhide-source)
else
  REPO_ARGS=(--releasever="$REL")
fi

SRCRPM=$(dnf repoquery "${REPO_ARGS[@]}" --latest-limit=1 --qf '%{sourcerpm}\n' mariadb | tail -1)
[ -n "$SRCRPM" ] || { echo "no mariadb binary package found for releasever=$REL"; exit 1; }

# mariadb10.11-10.11.18-2.fc43.src.rpm -> NAME=mariadb10.11 VPART=10.11.18 RPART=2.fc43
BASE=${SRCRPM%.src.rpm}
RPART=${BASE##*-}
VPART=${BASE%-*}; VPART=${VPART##*-}
NAME=${BASE%-"$VPART"-"$RPART"}
DISTRO_CMP=$(echo "$VPART-$RPART" | sed 's/\.fc[0-9]*//')
echo "releasever=$REL: source package $NAME, distro version $VPART-$RPART"

# Skip when COPR already has this version (or newer) built or in flight.
# A new source package name (stream change, e.g. mariadb12) yields no package
# info and falls through to an unconditional build.
INFO=$(copr-cli get-package "$PROJECT" --name "$NAME" --with-latest-build 2>/dev/null || true)
if [ -n "$INFO" ]; then
  COPR_VR=$(jq -r '.latest_build.source_package.version // empty' <<<"$INFO")
  STATE=$(jq -r '.latest_build.state // empty' <<<"$INFO")
  if [ -n "$COPR_VR" ] && [ "$STATE" != failed ]; then
    CMP=$(echo "${COPR_VR#*:}" | sed -e 's/\.dcs[0-9]*$//' -e 's/\.fc[0-9]*//')
    # rpmdev-vercmp exit codes: 11 = first arg newer, 0 = equal, 12 = second arg newer
    rc=0; rpmdev-vercmp "$DISTRO_CMP" "$CMP" >/dev/null || rc=$?
    if [ "$rc" != 11 ]; then
      echo "COPR already has $NAME $COPR_VR (state: $STATE); nothing to do"
      exit 0
    fi
  fi
fi

echo "distro is newer; building patched $NAME for: $*"
rm -rf work out; mkdir -p work out
( cd work && dnf download --source "${REPO_ARGS[@]}" mariadb )
./make-patched-srpm.sh work/*.src.rpm out "$PATCH"
ARGS=(); for c in "$@"; do ARGS+=(-r "$c"); done
copr-cli build "${ARGS[@]}" "$PROJECT" out/*.src.rpm
