# Geometry and placement: proposal for the SPARK-owned core

**Status:** proposal, for the maintainer to author. This document writes no Ada that
ships — the concrete signatures in §5 are a starting point to paste, edit, or replace.
Under the ownership rule (INSTRUCTIONS §40), the `.ads`, the body and the proof
configuration are yours; this file is prose plus a sketch.

**Scope:** v0 is floating-only. Tiling arithmetic is deliberately excluded so it does
not enlarge the v0 proof gate, but the shape below admits a second policy without
re-proving the first.

---

## 1. What has to be true before you write a line of it

These are measured facts about this machine and this wlroots, not assumptions. Each one
constrains the contract.

| Fact | Evidence | Consequence for the contract |
| --- | --- | --- |
| `struct wlr_box` is **integer**: `int x, y, width, height` | `/usr/include/wlroots-0.20/wlr/util/box.h`; Ada mirror proven at size 16, x 0, y 4, width 8, height 12 (`tests/c_layout_ground_truth.c` vs `bin/binding_probe`) | Geometry can be plain integer arithmetic. This matters because `gappa` is absent from the bundled provers, so **floating-point goals are unprovable here**. |
| Outputs sit at **arbitrary integer coordinates**, negatives included | `wlr_output_layout_add(layout, output, int lx, int ly)` — `wlr/types/wlr_output_layout.h:90-91` | Do not assume a top-left origin, and do not assume the output list is sorted or non-overlapping. |
| A layout can hold **several outputs**, each with its own origin | same, plus `wlr_output_layout_add_auto` at :102 | The placement input is a list of boxes, not one box. v0 is multi-output (task B10), so a single-output contract would have to be widened later — which is the re-proof this shape is meant to avoid. |
| Pointer coordinates are `double` | `wlr_output_layout_output_at(layout, double lx, double ly)` | If placement ever consumes a pointer position it arrives as a float. Convert at the binding boundary and keep SPARK on integers. Nothing in v0's placement path needs it. |
| Screen size is bounded in practice but **not** by any wlroots constant | `wlr_output` reports whatever the driver accepts; `wlr-randr` lists it | The contract needs explicit bounds, chosen by you, rather than a promise that inputs are sane. |

## 2. The v0 contract, in words

Given a list of output rectangles and a requested window size, produce a rectangle that:

1. **fits entirely inside one output**, or is explicitly reported as not placeable;
2. **is not smaller than a declared minimum**;
3. **is never larger than the output it is on**;
4. **is expressed in layout coordinates**, i.e. offset by that output's origin, so a
   window on a monitor at `(-1920, 0)` gets negative `x` and that is correct;
5. **is deterministic**: the same inputs always give the same output rectangle.

That is the whole v0 obligation. There is no tiling, no splitting, no gap arithmetic,
no stacking order, and no interaction with other windows — the placement of one window
against the output set is the entire verified surface.

**What is deliberately not proved in v0,** and should be said out loud in the body's
comments rather than implied by silence:

- that windows do not overlap each other (floating windows may, by design);
- anything about focus order, which needs the event model;
- anything about what wlroots, the GPU driver or the kernel does with the rectangle.

## 3. Why this shape survives v0.1

v0.1 adds exactly one tiling layout. A tiling layout answers the same question — *given
this output set, where does this window go* — with a different rule. If the seam is
"outputs and a request in, a rectangle and a status out", then tiling is a second
implementation of the same signature and none of the v0 proofs are invalidated,
because they were about the floating policy, not about the interface.

What would break that: putting the placement *rule* in the interface (e.g. a
`Cascade` parameter, or a gap width the interface promises to honour), or letting the
caller pass a list of already-placed windows so the policy can avoid them. Either one
makes the interface floating-specific. Neither is needed in v0.

## 4. The two types worth arguing about

**A rectangle type of its own, not `wlr_box`.** The SPARK package must not `with` the
binding: `System.Address` is not in the SPARK subset, and a proof about an Ada-side
model says nothing about wlroots anyway. So the contract defines its own `Rectangle`
with integer fields, and the policy layer converts to and from the binding's `Box` at
the seam. The conversion is total and trivial, which is the point.

**Bounds as named constants, not magic numbers.** A contract that says "x is in
`Integer'Range`" proves almost nothing, because `Integer'Last` is not a screen
coordinate. Declare the maximum coordinate and maximum dimension you are willing to
reason about, and make the precondition refer to them. Pick them; I have no business
choosing your bounds.

## 5. A concrete sketch, to paste or replace

Signatures only. No bodies, no contracts beyond a sketch of the postconditions — the
proof obligations are yours to state, and a proposal that pretends to be the final
`.ads` would be the one thing this document is not allowed to be.

```ada
package Iris.Geometry is
   pragma Pure;

   --  Chosen by the maintainer. These are placeholders that are large enough for
   --  any real display arrangement and small enough to keep arithmetic away from
   --  overflow in the obvious places.
   Maximum_Coordinate : constant := 65_536;
   Maximum_Dimension  : constant := 16_384;
   Minimum_Dimension  : constant := 1;

   subtype Coordinate is Integer range -Maximum_Coordinate .. Maximum_Coordinate;
   subtype Dimension  is Integer range Minimum_Dimension .. Maximum_Dimension;

   type Rectangle is record
      X      : Coordinate;
      Y      : Coordinate;
      Width  : Dimension;
      Height : Dimension;
   end record;

   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean;
   --  True when Inner lies entirely within Outer, edges included.

   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean;

end Iris.Geometry;
```

```ada
package Iris.Placement is
   pragma Pure;

   with Iris.Geometry;

   --  One entry per output, in layout coordinates. The array may be empty,
   --  unsorted, and may contain overlapping entries; the contract must say what
   --  happens in each case rather than requiring callers to normalise it.
   type Output_List is array (Positive range <>) of Iris.Geometry.Rectangle;

   type Placement_Status is (Placed, No_Output, Request_Too_Small,
                             Request_Too_Large);

   type Placement_Result (Status : Placement_Status := No_Output) is record
      case Status is
         when Placed =>
            Bounds : Iris.Geometry.Rectangle;
         when others =>
            null;
      end case;
   end record;

   --  The floating policy: place a window of the requested size on the first
   --  output that can hold it, at a deterministic position within that output.
   --  Postconditions to state (yours to prove):
   --    - Placed implies Contains (Output, Bounds) for that output
   --    - Placed implies Bounds.Width >= Requested.Width, similarly Height
   --    - No_Output implies no output could hold the request
   --    - the same inputs always yield the same result
   function Place_Floating
     (Outputs   : Output_List;
      Requested : Iris.Geometry.Rectangle) return Placement_Result;
```

Two notes on the sketch:

- The discriminated result record is what makes "not placed" impossible to read as a
  rectangle. A bare `Rectangle` plus a `Boolean` out-parameter is the shape that lets
  a caller use a garbage rectangle after a failure, and the proof would then be about
  a value nobody reads.
- `Outputs` is a discriminated array parameter, so the empty case is a real case the
  contract has to state rather than a caller mistake to document away.

## 6. House style, so this compiles first time

Iris's Alire-generated switch set is aggressive. Two rules bite Ada that looks
perfectly idiomatic, and both are enforced on every build:

```
-gnatyI   explicit `in` modes are FORBIDDEN   ->  write `X : Integer`, not `X : in Integer`
-gnaty3   3-space indentation
-gnatyM   maximum line length 79
-gnatwa   all warnings enabled
-gnatVa   all validity checks
-gnatyO   overriding subprograms must be marked `overriding`
-gnatyA   array index numbers only in array attributes
-gnatyS   no statements after THEN/ELSE
-gnatyx   no extra parentheses
-gnatW8   UTF-8 source encoding
```

Both of the first two were confirmed by compiling a control file: with `-gnatyI`,
`Value : in Integer` produces `(style) "in" should be omitted`; without it, the same
file compiles clean.

Project conventions on top of that:

- **full words, no abbreviations** — `Width`, not `W`; `Placement`, not `Plcmnt`;
- **every function result assigned to a named local before use**;
- files small and split by concern;
- no `pragma Annotate`, no suppression, no weakened proof level — the proof job is a
  required check and a failing proof blocks a merge.

## 7. What I need back, and what happens then

Two files: `src/iris/geometry.ads` + `.adb` and `src/iris/placement.ads` + `.adb`, or
whatever names you prefer — the seam is the signature, not the filenames. Then:

1. I wire the caller side (`Iris.Server` and the layout-policy seam in task C3) to
   whatever you deliver, without touching your files.
2. `gnatprove -P iris_wm.gpr` runs in CI as a required job. It is **not** in
   `alire.toml`: gnatprove is verification-only tooling and is never linked into the
   compositor.
3. **v0 is not done until that job is green on your package.** That is the gate, and it
   is deliberately not "the compositor runs".

If the sketch above is wrong in some way I cannot see from the wlroots side — a
subtype that makes a proof harder than it needs to be, a postcondition that is not
provable with the available provers — say so and I will adjust the caller side to
match whatever you write. The caller is mine to change; the contract is yours.
