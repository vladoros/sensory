#!/bin/sh
# usage: tools/test.sh [device]  Builds with unit tests and runs them in the simulator, starting it if needed.
cd "$(dirname "$0")/.." || exit 1
. tools/env.sh
DEVICE=${1:-venu3}
KEY=${CIQ_KEY:-$HOME/.garmin/dev.der}
[ -r "$KEY" ] || { echo "signing key not found: $KEY (set CIQ_KEY to override)" >&2; exit 1; }
mkdir -p build
PRG="build/test-$DEVICE.prg"
# a failed compile must not fall through to an older binary
rm -f "$PRG"
built=$("$SDK/bin/monkeyc" -t -d "$DEVICE" -f monkey.jungle -o "$PRG" -y "$KEY" -w 2>&1)
echo "$built" | grep -v 'Picked up'
echo "$built" | grep -q 'BUILD SUCCESSFUL' || exit 1
start_simulator
out=$("$SDK/bin/monkeydo" "$PRG" "$DEVICE" -t 2>&1)
echo "$out" | grep -v 'Picked up'
echo "$out" | grep -q '^PASSED' && ! echo "$out" | grep -q 'passed=0' || exit 1
