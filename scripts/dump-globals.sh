#!/usr/bin/env bash
# Dump what a client actually sees, for debugging the init check.
set -u -o pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$(mktemp -d /tmp/iris-dump-XXXXXX)"
RUNTIME="$SCRATCH/r"
mkdir -p "$RUNTIME"; chmod 700 "$RUNTIME"
LOG="$SCRATCH/probe.log"

cleanup() {
	if [ -n "${PROBE_PID:-}" ] && kill -0 "$PROBE_PID" 2>/dev/null; then
		kill -TERM "$PROBE_PID" 2>/dev/null; wait "$PROBE_PID" 2>/dev/null
	fi
	rm -rf "$SCRATCH"
}
trap cleanup EXIT

XDG_RUNTIME_DIR="$RUNTIME" "$REPO/bin/init_probe" >"$LOG" 2>&1 &
PROBE_PID=$!
SOCKET=""
for _ in $(seq 1 50); do
	SOCKET=$(sed -n 's/^WAYLAND_DISPLAY=//p' "$LOG" 2>/dev/null | head -1)
	[ -n "$SOCKET" ] && break
	sleep 0.1
done
echo "socket: $SOCKET"
echo "=== full wayland-info ==="
XDG_RUNTIME_DIR="$RUNTIME" WAYLAND_DISPLAY="$SOCKET" timeout 15 wayland-info 2>&1 | grep -E "interface|version" | head -40
