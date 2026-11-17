# Iris

A Wayland compositor written in Ada, built on wlroots. Iris is a **floating window manager**:
tiling is an option, not the default, and it arrives as a second implementation of the layout
policy seam that v0 establishes.

The project exists to find out how much of a modern desktop compositor can honestly be written
in Ada, with selected logic formally verified in SPARK, without reimplementing anything wlroots
already does well. It is not a safety-critical system and does not pretend to be one.

## Status

**Pre-alpha. There is no picture yet.** The compositor builds, starts on the X11 (nested) and
headless backends, publishes its protocol globals, answers a real client, and exits cleanly on
`SIGTERM`. It draws nothing: the renderer and scene are not wired yet, so a client's buffer is
accepted and then dropped on the floor. The surface is not up, and `wlr_scene` is untouched.

What exists, and is exercised by CI on every push:

- The wlroots 0.20 binding, hand-written against the installed headers. Every mirrored struct
  layout is diffed against a C `offsetof` ground truth, and every listener registration is
  asserted to remove itself before the object it hangs from is destroyed.
- Object-graph and teardown ownership in `Iris.Server`, with a regression test for the listener
  lifetime rule and a control arm that aborts without it.
- The SPARK-owned core: window geometry and the floating placement policy. The proof gate
  discharges every check, and asserts on the check table rather than the exit status, because a
  vacuous `gnatprove` run exits 0.
- The init sequence and its advertised protocol versions, checked by driving a real
  `wayland-info` client at a running compositor.

The staged plan lives outside the repository on the maintainer's machine, so the task list here
will always be behind the tree. Where the two disagree, the tree wins.

Do not run Iris expecting a desktop.

## What v0 targets

- X11 (nested) and headless backends for development, DRM with `libseat` on real hardware
- `wlr_scene` for rendering, damage tracking and hit-testing
- `xdg-shell` toplevels and popups, `wlr_compositor`, `wlr_subcompositor`
- `wlr_data_device_manager` plus primary selection
- `xdg-decoration` server-side, `wlr_layer_shell_v1`, `wlr_output_management_v1`
- Multi-output, with real and virtual outputs coexisting
- Floating placement behind a layout-policy seam, click-to-focus, focus cycling
- Alt+drag move and resize, `Super+Return` spawn, `Super+q` close, `Super+arrow` focus
- A TOML-subset configuration file at `$XDG_CONFIG_HOME/iris_wm/config`, with built-in defaults
  when the file is absent

Explicitly not in v0: session lock, idle inhibit, foreign toplevel, XWayland, gamma control,
screencopy, fractional scale, tablet and gesture input, IME, workspaces, window rules, tiling.

## Requirements

Verified on openSUSE Tumbleweed with the versions in the right-hand column.

| Dependency | Package | Verified version |
|---|---|---|
| wlroots headers and library | `wlroots-devel` (runtime: `libwlroots-0_20`) | 0.20.2 |
| Ada compiler | provided by Alire's `gnat_native` toolchain | GNAT 16.1.0 |
| Build driver | provided by Alire's `gprbuild` toolchain | gprbuild 26.0.1 |
| Alire | `alr` | 2.1.1 |

wlroots 0.20 is the baseline: `>=0.20.1`, `<0.21.0`. Iris links the **shared** system library;
it does not vendor wlroots and needs no `wayland-scanner` step, because wlroots 0.20 already
exports the layer-shell and output-management entry points.

`gnatprove` is **not** a dependency of the crate. It is verification-only tooling, installed and
pinned by CI, and it is never linked into the compositor.

## Building

```
alr toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
alr build
```

The first build generates `config/`, which is ignored by git and must never be edited by hand.

## Running

`bin/iris_wm` is still a `null` main, so running it produces a compositor that does nothing and
returns. What actually comes up today is the init probe, and `scripts/init-check.sh` is the way
in: it starts that probe on a scratch runtime dir, drives a real `wayland-info` client at it,
asserts the protocol versions it sees, then sends `SIGTERM` and requires a clean exit with no
coredump.

```
alr exec -- gprbuild -P tests/binding_probe.gpr    # builds the probe and test mains
WLR_BACKENDS=headless ./scripts/init-check.sh      # headless, the CI path
DISPLAY=:1 ./scripts/init-check.sh                 # nested in an X11 session
```

Nested runs must not have `WAYLAND_DISPLAY` set: `wlr_backend_autocreate` prefers the Wayland
backend whenever it is, and fails rather than falling back to X11. The script clears it itself
for the nested path. Never `pkill -x` an Iris binary — the script captures its own PID and kills
only that, because the developer is normally logged into a live session.

Headless needs no GPU and runs in a container. DRM and multi-output need a VT takeover, so they
are verified by hand on real hardware and are not covered by CI.

## Licence

GPL-2.0-only. See `LICENSE`. Contributions are covered by `CONTRIBUTING.md`.
