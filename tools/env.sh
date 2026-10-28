export JAVA_HOME=${JAVA_HOME:-/Library/Java/JavaVirtualMachines/microsoft-11.jdk/Contents/Home}
export PATH="$JAVA_HOME/bin:$PATH"
SDK=${CIQ_SDK:-$(ls -d "$HOME"/Work/connectiq-sdk/connectiq-sdk-mac-* 2>/dev/null | tail -1)}
[ -x "$SDK/bin/monkeyc" ] || { echo "Connect IQ SDK not found under ~/Work/connectiq-sdk (set CIQ_SDK)" >&2; exit 1; }
OPTS="-Djava.net.preferIPv4Stack=true -Djava.awt.headless=true"
# A sandboxed shell cannot read ~/Library, so there it builds against a copy of the Garmin data folder
if [ ! -r "$HOME/Library/Application Support/Garmin/ConnectIQ/Devices" ] && [ -d "$HOME/Work/garmin-home" ]; then
  OPTS="$OPTS -Duser.home=$HOME/Work/garmin-home -Djava.io.tmpdir=${TMPDIR:-/tmp}"
fi
export JAVA_TOOL_OPTIONS="$OPTS"

start_simulator() {
  if ! nc -z 127.0.0.1 1234 2>/dev/null; then
    env -u JAVA_TOOL_OPTIONS "$SDK/bin/connectiq" >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
      nc -z 127.0.0.1 1234 2>/dev/null && break
      sleep 0.5
    done
  fi
}
