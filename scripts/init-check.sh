#!/usr/bin/env bash
# A1b acceptance check: bring up the compositor, let a real client report the
# protocol versions it sees, then shut down and verify the shutdown was clean.
#
# This is the script the task's "expected delta" describes. It asserts on
# wayland-info's output, not on anything the compositor says about itself.
#
# Usage:
#   scripts/init-check.sh              # headless backend (the CI path)
#   DISPLAY=:1 scripts/init-check.sh   # nested in an X11 session
#
# Exit status: 0 only if every assertion passed.

set -u -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PROBE="$REPO/bin/init_probe"

COMPOSITOR_VERSION=6
XDG_SHELL_VERSION=6
LAYER_SHELL_VERSION=4

failures=0

pass() { printf 'ok:   %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failures=$((failures + 1)); }

if [ ! -x "$PROBE" ]; then
	echo "FAIL: $PROBE not built (run: alr exec -- gprbuild -P tests/binding_probe.gpr)"
	exit 1
fi

# Scratch runtime dir. Wayland refuses socket paths longer than 108 bytes, so
# this is deliberately short, and it is never the developer's real one.
SCRATCH="$(mktemp -d /tmp/iris-init-XXXXXX)"
RUNTIME="$SCRATCH/r"
mkdir -p "$RUNTIME"
chmod 700 "$RUNTIME"
LOG="$SCRATCH/probe.log"

COREDUMPS_BEFORE=$(coredumpctl list --no-pager 2>/dev/null | grep -c init_probe)

cleanup() {
	if [ -n "${PROBE_PID:-}" ] && kill -0 "$PROBE_PID" 2>/dev/null; then
		kill -TERM "$PROBE_PID" 2>/dev/null
		wait "$PROBE_PID" 2>/dev/null
	fi
	rm -rf "$SCRATCH"
}
trap cleanup EXIT

# wlr_backend_autocreate prefers the Wayland backend whenever WAYLAND_DISPLAY
# is set, and tries to connect to that compositor over the socket named in
# XDG_RUNTIME_DIR — which here is a scratch dir with no such socket. The result
# is "Could not connect to remote display" and a failed start, not an X11
# backend. Nested X11 development therefore has to clear WAYLAND_DISPLAY.
# Measured, not guessed: this is exactly how the first nested run failed.
if [ -z "${WLR_BACKENDS:-}" ] && [ -n "${DISPLAY:-}" ]; then
	unset WAYLAND_DISPLAY
fi

XDG_RUNTIME_DIR="$RUNTIME" "$PROBE" >"$LOG" 2>&1 &
PROBE_PID=$!

# Wait for the socket name rather than sleeping a fixed time.
SOCKET=""
for _ in $(seq 1 50); do
	SOCKET=$(sed -n 's/^WAYLAND_DISPLAY=//p' "$LOG" 2>/dev/null | head -1)
	[ -n "$SOCKET" ] && break
	if ! kill -0 "$PROBE_PID" 2>/dev/null; then
		break
	fi
	sleep 0.1
done

if [ -z "$SOCKET" ]; then
	fail "compositor published a wayland socket"
	echo "--- probe output ---"
	cat "$LOG"
	exit 1
fi
pass "compositor published socket $SOCKET"

INFO=$(XDG_RUNTIME_DIR="$RUNTIME" WAYLAND_DISPLAY="$SOCKET" \
	timeout 15 wayland-info 2>&1)
INFO_STATUS=$?

if [ $INFO_STATUS -ne 0 ]; then
	fail "a client connected and was answered (wayland-info exit $INFO_STATUS)"
	echo "$INFO" | head -20
else
	pass "a client connected and was answered"
fi

# wayland-info prints one block per interface. Pull the version out of the
# interface's own line rather than assuming a field position.
# wayland-info pads the interface name with spaces before "version:", so the
# match has to tolerate arbitrary whitespace rather than assume one space.
version_of() {
	printf '%s\n' "$INFO" | sed -n "s/.*interface: *'$1', *version: *\([0-9]*\).*/\1/p" | head -1
}

COMP=$(version_of wl_compositor)
XDG=$(version_of xdg_wm_base)
LAYER=$(version_of zwlr_layer_shell_v1)

if [ "$COMP" = "$COMPOSITOR_VERSION" ]; then
	pass "wl_compositor is v$COMP"
else
	fail "wl_compositor is v${COMP:-absent}, expected v$COMPOSITOR_VERSION"
fi

if [ "$XDG" = "$XDG_SHELL_VERSION" ]; then
	pass "xdg_wm_base is v$XDG"
else
	fail "xdg_wm_base is v${XDG:-absent}, expected v$XDG_SHELL_VERSION"
fi

if [ "$LAYER" = "$LAYER_SHELL_VERSION" ]; then
	pass "zwlr_layer_shell_v1 is v$LAYER"
else
	fail "zwlr_layer_shell_v1 is v${LAYER:-absent}, expected v$LAYER_SHELL_VERSION"
fi

for iface in wl_subcompositor wl_data_device_manager zwp_primary_selection_device_manager_v1; do
	if printf '%s\n' "$INFO" | grep -q "interface: '$iface'"; then
		pass "$iface present"
	else
		fail "$iface missing"
	fi
done

# Shutdown. SIGTERM is the normal path; the compositor must exit 0 and leave no
# coredump, because on real hardware an unclean exit is a VT that never comes
# back.
kill -TERM "$PROBE_PID" 2>/dev/null
wait "$PROBE_PID"
EXIT_STATUS=$?
PROBE_PID=""

if [ $EXIT_STATUS -eq 0 ]; then
	pass "clean shutdown on SIGTERM (exit 0)"
else
	fail "shutdown exit status $EXIT_STATUS"
fi

sleep 0.5
COREDUMPS_AFTER=$(coredumpctl list --no-pager 2>/dev/null | grep -c init_probe)
if [ "$COREDUMPS_AFTER" = "$COREDUMPS_BEFORE" ]; then
	pass "no coredump produced"
else
	fail "coredump count went from $COREDUMPS_BEFORE to $COREDUMPS_AFTER"
fi

echo
if [ $failures -eq 0 ]; then
	echo "RESULT: PASS"
	exit 0
fi
echo "RESULT: FAIL ($failures failing checks)"
echo "--- probe output ---"
cat "$LOG"
exit 1
