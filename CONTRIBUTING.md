# Contributing to Iris

Iris is a Wayland compositor written in Ada on top of wlroots. Contributions are welcome, and
the bar for them is behavioural: a change must build, must not break clients, and must not
weaken a verified guarantee.

## Ground rules

- **Ada-first.** All of Iris's own logic is written in Ada. wlroots is reused, not rewritten.
  Do not port, vendor or copy C compositor implementations into this repository.
- **labwc is a behavioural reference, never a source.** Reading it to learn *that* a trap exists
  and what the correct behaviour is, then writing our own implementation, is the intended
  workflow. Copying its code is not.
- **wlroots is linked as the shared system library.** No vendoring, no static subproject, and no
  `wayland-scanner` code generation for protocols wlroots already exports.
- **Keep changes small enough to review.** One concern per pull request.
- **Do not break userspace.** Preserve supported Wayland protocol behaviour, and treat existing
  configuration keys and keybindings as a compatibility surface. An intentional break needs
  documentation and a migration note.

## Ada conventions

The project's generated switch set is aggressive, and two of its rules surprise people writing
otherwise idiomatic Ada:

- `-gnatyI` **forbids explicit `in` modes.** Write `Value : Integer`, never `Value : in Integer`.
- `-gnaty3` is 3-space indentation, and `-gnatyS` forbids a statement on the same line as
  `then` or `else`.

The rest of the set is `-gnatwa`, `-gnatVa`, `-gnatyO` (overriding subprograms must be marked
`overriding`), `-gnatyA`, `-gnatyx` (no redundant parentheses) and `-gnatW8`.

House conventions on top of that:

- **Full words, no abbreviations** in identifiers. `Width`, not `W`. `Placement`, not `Plcmnt`.
- **Assign every function result to a named local before use** rather than nesting calls inside
  expressions.
- **Keep files small** and split by concern.
- **Every foreign call carries a documented assumption** in the binding's specification: what
  the pointer must be, what state it must be in, and what wlroots does not define.
- **Every Ada record that embeds a `Wl_Listener` puts that listener first**, so the pointer the
  C callback receives *is* the record address. Two listeners means two wrapper records. Never
  compute struct offsets at runtime. A deviation is a review blocker.

## Drop doctrine

If the compositor cannot carry a feature, delete it — the configuration key, the parser branch,
the enumeration member, the dead code and the documentation. There are no stubs and no
"recognised but not implemented" lists. Every configuration key must be read by code that
actually runs.

Never advertise a capability whose handler does nothing. When a request handler becomes or stops
being a stub, re-audit the advertised capability mask in the same change.

## Build

```
alr toolchain --select gnat_native=16.1.0 gprbuild=26.0.1
alr build
```

The build requires wlroots 0.20 development headers (`wlroots-devel`, providing
`wlroots-0.20.pc`). `-DWLR_USE_UNSTABLE` is mandatory and is **not** carried by the `.pc` file,
so it is passed by the project file along with the pkg-config include directories.

The first build generates `config/`. That directory is ignored by git and is regenerated on
every build; never edit it by hand.

Builds must stay reproducible: no network access at build time, no generated sources committed,
and no dependency that is not documented in the README's requirements table.

## Tests

Tests are required for observable behaviour and for userspace compatibility. Two layers:

1. **AUnit unit tests** over the pure Ada core — geometry, placement, focus ordering,
   configuration parsing and validation. No Wayland connection, no FFI.
2. **A headless integration smoke test** that starts the compositor with
   `WLR_BACKENDS=headless` in a throwaway `XDG_RUNTIME_DIR` and connects a real client to assert
   that the compositor answers.

A pull request that changes behaviour without a test that would have caught the old behaviour is
incomplete.

## SPARK

Selected components are formally verified: window geometry, placement arithmetic, configuration
validation, and — once the event model exists — focus transitions and resource-state tracking.
Not everything is SPARK, and nothing is forced into it for its own sake.

**SPARK-owned components and their contracts are maintainer-controlled.** That covers the `.ads`
specifications, the bodies, and the proof configuration. You may read them, explain them, and
propose changes; you may not modify them or adjust their verification requirements. Proposals go
in as prose, for the maintainer to author.

Specifically:

- **Do not weaken a proof setting**, suppress a proof failure, add `pragma Annotate`, or replace
  a verified guarantee with an assumption.
- **Applicable proof checks must pass in CI.** The proof job is a required check, and a failing
  proof blocks the merge.
- **`gnatprove` is verification-only tooling and is never linked into Iris.** It is not a
  dependency of the crate manifest; CI installs it at a pinned version. Do not add it to
  `alire.toml`.
- Proofs about Ada-side models do not prove anything about wlroots, GPU drivers or the kernel.
  State assumptions at the foreign-function boundary rather than implying coverage that does not
  exist.
- Floating-point goals are not provable with the provers available here (Gappa is absent). Keep
  verifiable arithmetic on integers, and convert at the boundary.

## Licensing

Iris is **GPL-2.0-only**. By contributing you agree that your contribution is licensed under the
same terms. There is no contributor licence agreement.
