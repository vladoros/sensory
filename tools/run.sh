#!/bin/sh
# usage: tools/run.sh [venu3]
cd "$(dirname "$0")/.." || exit 1
DEVICE=${1:-venu3}
. tools/env.sh
tools/build.sh "$DEVICE" || exit 1

start_simulator
exec "$SDK/bin/monkeydo" "build/sensory-$DEVICE.prg" "$DEVICE"
