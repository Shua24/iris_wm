# Bodies proposal: what `.adb` files would actually buy

**Status:** proposal, for the maintainer to author. This document writes no Ada that
ships. Under the ownership rule the bodies are yours; this is a report on what each
candidate body would and would not prove, measured on this machine.

**Scope:** `Iris.Geometry` and `Iris.Placement`, as they stand in
`src/iris/iris-geometry.ads` and `src/iris/iris-placement.ads`.

---

## 1. Headline: `Contains` and `Overlaps` prove nothing on their own

This is the most important thing in the document, and it contradicts what a naive
reading of "we have SPARK" suggests.

I wrote the obvious bodies and proved them **in isolation** — geometry package only, no
placement package in the project:

```
=== geometry alone: Contains + Overlaps, no postconditions ===
SPARK Analysis results    Total   Flow   Provers   Unproved
Run-time Checks               .      .         .          .
Functional Contracts          .      .         .          .
Termination                   2      2         .          .
Total                         2   2 (100%)      .          .
```

**Zero runtime checks. Zero functional contracts.** The only thing proved is that the
two functions terminate. That is not a meaningful safety claim about geometry, and if it
were reported as "SPARK green" it would be exactly the vacuous pass this project is
satirising.

The reason is not a tooling defect. It is arithmetic:

| Expression | Worst case | `Integer'Last` | Overflows? |
| --- | --- | --- | --- |
| `Coordinate + Coordinate` | 131 070 | 2 147 483 647 | no |
| `Dimension_Extent * Dimension_Extent` | 268 435 456 | 2 147 483 647 | no |
| `Coordinate * Coordinate` | 4 294 836 225 | 2 147 483 647 | **yes** |

Every expression in `Contains` and `Overlaps` is an addition or comparison of values
bounded by 65 535 and 16 384. **Nothing in them can overflow**, so the provers have
nothing to check. I confirmed this by deliberately adding `Width * Height` to the body:
it still produced zero runtime checks, because 16 384² fits in 32 bits.

**Consequence for the contract:** `Contains` and `Overlaps` carry no proof value until
they have postconditions. The proof value lives entirely in the *contract*, not in the
body. A body without a contract is flow analysis and a termination proof.

*(An earlier draft of this document claimed the whole project proved zero runtime
checks. That was wrong, and the error was mine: I had been reading the summary without
`--proof=per_check:all`, which hides checks that were generated. With that flag,
`Place_Floating`'s body does produce 4 run-time checks. The geometry-only figure above
is the correct isolation, and it is zero.)*

---

## 2. What postconditions are worth, measured

I added one postcondition to each function and re-proved:

```ada
   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean
   with Post =>
     (if Contains'Result then Inner.X >= Outer.X and then Inner.Y >= Outer.Y);

   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean
   with Post =>
     (if Overlaps'Result
      then Left.X < Right.X + Right.Width
        and then Left.Y < Right.Y + Right.Height);
```

```
Functional Contracts   2    .    2 (CVC5 67%, Trivial 33%)    .    .
Termination            2    2    .                            .    .
Total                  4    2 (50%)  2 (50%)                  .    .
```

Two real obligations, both proved by CVC5, no unproved checks. So the postconditions
**do** work — they are just not present today.

**Control:** I changed the `Contains` postcondition to claim strict `>` where the body
allows equality:

```
medium: postcondition might fail, cannot prove Inner.X > Outer.X
```

Caught. So the postconditions are load-bearing rather than decorative.

---

## 3. `Place_Floating`: the current contract has a hole

Your two postconditions prove cleanly with the obvious body:

```
Functional Contracts   3    .    3 (CVC5 60%, Trivial 40%)    .    .
Termination            3    3    .                            .    .
Total                  6    3 (50%)  3 (50%)                  .    .
```

But I ran a control that should have failed and **it passed**:

> **Control B:** replace `if Requested.Width <= Output.Width and then
> Requested.Height <= Output.Height then` with `if True then` — i.e. place the window on
> the first output regardless of whether it fits.
>
> ```
> Success: all checks proved (6 checks).
> ```

**That is a real gap.** A body that places a window on an output that cannot hold it
satisfies your current contract, because neither postcondition says anything about the
`Placed` case. Your contract currently constrains the *refusals* and says nothing about
the *successes*.

### The clause that closes it

```ada
      and then
      (if Place_Floating'Result.Status = Placed
       then (for some Index in Outputs'Range =>
               Place_Floating'Result.Bounds.Width <= Outputs (Index).Width
               and then
               Place_Floating'Result.Bounds.Height <= Outputs (Index).Height));
```

Measured both ways:

- Correct body: `Success: all checks proved (10 checks)` at `--level=4`. Up from 6, so
  the clause is generating real obligations.
- Control B again, with the clause in place:
  ```
  medium: postcondition might fail, cannot prove (for some Index in
  Outputs'Range => Place_Floating'Result.Bounds.Width <= Outputs (Index).Width ...)
  ```

Now the bad body is caught. **This is the single most valuable line in this document.**

A second control, for completeness: removing the degenerate-request check entirely
trips your existing completeness clause (`cannot prove Place_Floating'Result.Status /=
Placed`), so that half of your contract is already doing its job.

---

## 4. Traps found while doing this

**A function's own name inside its own postcondition is a recursive call, not
`'Result`.** Writing `Overlaps (Left, Right) = Overlaps (Right, Left)` produced:

```
medium: implicit aspect Always_Terminates on "Overlaps" could be incorrect,
        subprogram is recursive
warning: call to "Overlaps" within its postcondition will lead to infinite recursion
```

Always use `Function_Name'Result`. This is a genuine footgun and it looks like a
symmetry property.

**`--mode=all` does not force every runtime check.** To see the full check table I had
to add `--proof=per_check:all`. Without it, the summary reports only what the default
proof mode generated. If CI runs plain `--mode=all`, it will report "all checks proved"
for a body whose overflow checks were never generated. **The CI proof job must use
`--proof=per_check:all`** or the gate is weaker than it looks.

**A loop over `Outputs` cannot be unrolled:** `info: cannot unroll loop (too many loop
iterations)`. It still proves, but this is the first place a larger contract will
struggle, and it is worth knowing before the CI proof budget is set.

**`generation of data representation information failed`** appears on every run in a
scratch project with a spec-only package. Harmless here, but if it shows up in CI it
will look like a failure and is not one.

---

## 5. The bodies I would write, and what each is worth

### `Iris.Geometry.Contains` — worth writing, worth little without a contract

```ada
   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean is
   begin
      return Inner.X >= Outer.X
        and then Inner.Y >= Outer.Y
        and then Inner.X + Inner.Width <= Outer.X + Outer.Width
        and then Inner.Y + Inner.Height <= Outer.Y + Outer.Height;
   end Contains;
```

Overflow-free by construction (see §1). The proof value is entirely in the
postcondition you choose. Worth stating, at minimum:

- `Contains'Result` implies `Inner.X >= Outer.X` and `Inner.Y >= Outer.Y`
- **reflexivity:** `Contains (X, X)` is always true — provable and worth having
- **transitivity:** `Contains (A, B) and Contains (B, C)` implies `Contains (A, C)`

Reflexivity and transitivity are the properties that make `Contains` usable by later
proofs; without them, every caller re-derives them.

### `Iris.Geometry.Overlaps` — worth writing, with one caveat

```ada
   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean is
   begin
      return Left.X < Right.X + Right.Width
        and then Right.X < Left.X + Left.Width
        and then Left.Y < Right.Y + Right.Height
        and then Right.Y < Left.Y + Left.Height;
   end Overlaps;
```

The obvious property — symmetry — is the one that hits the `'Result` trap. Written
correctly it should be provable:

```ada
   with Post => (Overlaps'Result = (Right.X < Left.X + Left.Width
                                    and then Left.X < Right.X + Right.Width
                                    and then Right.Y < Left.Y + Left.Height
                                    and then Left.Y < Right.Y + Right.Height));
```

I have **not** proved that formulation; I proved the weaker one in §2. Symmetry is the
one to try first, because if it holds, every caller can reorder arguments freely.

### `Iris.Placement.Place_Floating` — worth writing, and worth the most

```ada
   function Place_Floating
     (Outputs   : Output_List;
      Requested : Iris.Geometry.Rectangle) return Placement_Result
   is
   begin
      if Requested.Width = 0 or else Requested.Height = 0 then
         return (Status => Request_Too_Small);
      end if;

      for Index in Outputs'Range loop
         declare
            Output : constant Iris.Geometry.Rectangle := Outputs (Index);
         begin
            if Requested.Width <= Output.Width
              and then Requested.Height <= Output.Height
            then
               return (Status => Placed,
                       Bounds => (X      => Output.X,
                                  Y      => Output.Y,
                                  Width  => Requested.Width,
                                  Height => Requested.Height));
            end if;
         end;
      end loop;

      return (Status => No_Output);
   end Place_Floating;
```

Proves at `--level=4` with the added clause: `Success: all checks proved (10 checks)`.

Note what this body *does* promise and what it does not:

- **Promises:** a placed window is no larger than some output, and carries that
  output's origin. A degenerate request is refused. `Request_Too_Small` is only
  returned for a degenerate request.
- **Does not promise:** that `Bounds` is *inside* the output (only that its dimensions
  fit and its origin is the output's). That stronger claim needs
  `Contains (Outputs (Index), Bounds)` and is the natural next step — it is provable
  with the same shape, but I did not test it.
- **Does not promise:** anything about overlap between windows, cascade position, or
  stacking. Those are policy choices, not arithmetic, and v0 does not have them.

---

## 6. What this means for the v0 gate

The gate says "v0 is done when gnatprove is green". After this investigation I would
put it more precisely, because **green is not enough**:

> v0 is done when gnatprove is green **and the check table shows non-zero Functional
> Contracts**, run with `--proof=per_check:all`.

Otherwise a body with no postconditions passes the gate while proving nothing, which is
precisely the failure mode the project is a satire of. The check table in
`obj/gnatprove/gnatprove.out` is the evidence, not the exit status.

Minimum bar I would hold CI to, per function:

| Function | Functional Contracts ≥ | Why |
| --- | --- | --- |
| `Contains` | 2 | reflexivity + one directional property |
| `Overlaps` | 1 | symmetry, or one directional property |
| `Place_Floating` | 4 | your 2, plus `Placed`-implies-fits, plus one more |

Those numbers are derived from what I actually measured, not invented.

---

## 7. What I am not proposing

- **No bodies for anything outside the two packages.** Stage B is separate work.
- **No changes to your specs from me.** Every clause above is a suggestion; the file
  stays yours.
- **No `pragma Assume`, no `pragma Annotate`, no suppression.** If a clause will not
  prove, the answer is to weaken the *claim* deliberately and record it, not to silence
  the prover.
- **No tiling arithmetic.** It is v0.1, behind the seam, and this document is about v0.

---

## 8. Reproduction

Scratch project at `/home/aulus/.hermes/cache/scratch/bodies`, containing copies of
your two specs plus the bodies above. Every figure in this document came from:

```
gnatprove -P p.gpr --mode=all --level=4 --proof=per_check:all
```

with `obj/` cleared between runs. The controls are described inline in §2 and §3; each
was run against the same tree with one line changed, and each produced the quoted
diagnostic.
