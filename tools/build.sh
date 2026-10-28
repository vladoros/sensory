#!/bin/sh
# usage: [RELEASE=1] tools/build.sh [device ...]  (default: Venu 3). Exits 1 if any build fails.
# RELEASE=1 strips debug info and optimizes, for sideloading onto a watch.
cd "$(dirname "$0")/.." || exit 1
. tools/env.sh
KEY=${CIQ_KEY:-$HOME/.garmin/dev.der}
[ -r "$KEY" ] || { echo "signing key not found: $KEY (set CIQ_KEY to override)" >&2; exit 1; }
[ $# -eq 0 ] && set -- venu3
mkdir -p build
status=0
for d in "$@"; do
  echo "== $d"
  out=$("$SDK/bin/monkeyc" -d "$d" -f monkey.jungle -o "build/sensory-$d.prg" -y "$KEY" -w ${RELEASE:+-r -O 2} 2>&1)
  echo "$out" | grep -v 'Picked up'
  echo "$out" | grep -q 'BUILD SUCCESSFUL' || status=1
done
exit $status
