# Iris

A Wayland compositor written in Ada, built on wlroots. Iris is a **floating window manager**:
tiling is an option, not the default, and it arrives as a second implementation of the layout
policy seam that v0 establishes.

The project exists to find out how much of a modern desktop compositor can honestly be written
in Ada, with selected logic formally verified in SPARK, without reimplementing anything wlroots
already does well. It is not a safety-critical system and does not pretend to be one.

## Status

**Pre-alpha. Nothing is implemented yet.** The repository currently holds the crate manifest,
the GPR project file, a four-line main, the licence, and this documentation. The staged plan
lives outside the repository on the maintainer's machine; the first commit is the licensing and
skeleton groundwork.

Do not run Iris expecting a desktop. When it does run, it will be documented here with the
commands and output that were actually observed.

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

Not yet possible. When the compositor runs, nested development will use the X11 backend from an
existing session and headless runs will use `WLR_BACKENDS=headless`.

## Licence

GPL-2.0-only. See `LICENSE`. Contributions are covered by `CONTRIBUTING.md`.
