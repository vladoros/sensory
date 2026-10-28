#!/bin/sh
# usage: tools/package.sh  Builds the optimised release .iq package for the Connect IQ store.
cd "$(dirname "$0")/.." || exit 1
. tools/env.sh
KEY=${CIQ_KEY:-$HOME/.garmin/dev.der}
[ -r "$KEY" ] || { echo "signing key not found: $KEY (set CIQ_KEY to override)" >&2; exit 1; }
mkdir -p build
out=$("$SDK/bin/monkeyc" -e -r -O 2z -w -f monkey.jungle -o build/sensory.iq -y "$KEY" 2>&1)
echo "$out" | grep -v 'Picked up'
echo "$out" | grep -q 'BUILD SUCCESSFUL' || exit 1
ls -l build/sensory.iq
