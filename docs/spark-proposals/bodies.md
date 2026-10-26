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

## 2. What postconditions are worth, measured — and why the obvious ones are wrong

This section was rewritten after I tested my own first recommendation and found it
insufficient. The correction is recorded rather than quietly patched, because the
difference is exactly the kind of thing that makes a contract look proved while proving
nothing.

### 2.1 The three candidate formulations

I built three versions of `Contains`'s contract and ran each against both a correct body
and a deliberately wrong one (a body that checks only the origin and ignores width and
height entirely).

| Formulation | Functional Contracts | Wrong body rejected? |
| --- | --- | --- |
| **A.** no postcondition | 0 | no |
| **B.** `if Contains'Result then Inner.X >= Outer.X and then Inner.Y >= Outer.Y` | 2 | **no** |
| **C.** `Contains'Result = (<full expression>)` | 2 | **yes** |

Formulation B is what I recommended first. It is **too weak**: it pins down only one
direction, so a body that returns true for "origin is inside" and ignores the
dimensions satisfies it completely.

```
=== B (directional) with a body that ignores width and height ===
Success: all checks proved (4 checks).          <-- wrong body accepted

=== C (characterisation) with the same wrong body ===
medium: postcondition might fail                <-- wrong body rejected
```

Both produce two functional contracts. **The check count does not distinguish them.** Only
a wrong body does.

### 2.2 The clauses to use (done)

```ada
   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean
   with Post =>
     (Contains'Result =
        (Inner.X >= Outer.X
         and then Inner.Y >= Outer.Y
         and then Inner.X + Inner.Width <= Outer.X + Outer.Width
         and then Inner.Y + Inner.Height <= Outer.Y + Outer.Height));

   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean
   with Post =>
     (Overlaps'Result =
        (Left.X < Right.X + Right.Width
         and then Right.X < Left.X + Left.Width
         and then Left.Y < Right.Y + Right.Height
         and then Right.Y < Left.Y + Left.Height));
```

Both prove at `--level=4` with CVC5, no unproved checks.

**Controls, against the real spec file:**

```
=== Contains ignores width and height ===
medium: postcondition might fail

=== Overlaps uses <= instead of <, so edge-touching counts as overlapping ===
medium: postcondition might fail
```

The second control is the one that justifies the whole exercise. `<=` for `<` in a
four-term conjunction is an off-by-one that reads correctly to a human and is caught here
immediately.

### 2.3 This is a functional specification, not an independent one

The postcondition restates the body's own expression. It proves the body matches the
contract; it does **not** prove the contract is the right definition of "contains". The
meaning is fixed by the maintainer in the spec, and the proof pins the implementation to
it. That is normal and is what these clauses are for.

### 2.4 Reflexivity and symmetry: provable, but dead weight

I tested the independent properties — reflexivity of `Contains`, symmetry of `Overlaps` —
because they are what would let a *caller* reason without unfolding the definition.

**They are provable, but only if written without calling the function.** The natural
formulations both fail:

```ada
   --  Overlaps'Result = Overlaps (Right, Left)
   medium: implicit aspect Always_Terminates on "Overlaps" could be incorrect,
           subprogram is recursive
   warning: call to "Overlaps" within its postcondition will lead to infinite recursion

   --  Post => Contains (Outer, Outer)
   medium: postcondition might fail
           provers reached time limit before completing the proof
```

Any call to the function inside its own postcondition is a **recursive call**, not
`'Result`. Written instead by unfolding both sides, symmetry proves
(`Success: all checks proved (3 checks)`), as does reflexivity expressed as
`(if Inner = Outer then Contains'Result)`.

**But they add nothing.** Three caller tests:

| Spec has | Caller can prove `Contains (X, X)`? |
| --- | --- |
| `=` characterisation only | yes |
| `=` **+** reflexivity property | yes |
| reflexivity property **only** | yes |

And the decisive test — does the property-only spec catch the wrong body?

```
=== reflexivity property only, body ignores width and height ===
Success: all checks proved (4 checks).
```

**No.** A redundant clause that catches nothing is exactly what the drop doctrine says to
delete. The `=` characterisation already gives callers everything the properties would,
because it lets them unfold the definition directly.

**Recommendation: add the two `=` clauses, and nothing else.**

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

## 5. The bodies, aligned with the specs as they now stand

The maintainer has already added the `=` clauses to `iris-geometry.ads` and the
`Placed`-implies-fits clause to `iris-placement.ads`. So this section is now "what body
satisfies the spec as written", not "what contract to consider".

Full-project result with the bodies below:

```
Run-time Checks        4     .    4 (CVC5)                      .    .
Functional Contracts   3     .    3 (CVC5 81%, Trivial 19%)    .    .
Termination            3     3    .                            .    .
Total                 10    3 (30%)  7 (70%)                   .    .
Success: all checks proved (10 checks).
```

### `Iris.Geometry.Contains`

```ada
   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean is
   begin
      return Inner.X >= Outer.X
        and then Inner.Y >= Outer.Y
        and then Inner.X + Inner.Width <= Outer.X + Outer.Width
        and then Inner.Y + Inner.Height <= Outer.Y + Outer.Height;
   end Contains;
```

Overflow-free by construction (§1). Against the `=` clause this body is fully pinned: any
deviation in any of the four terms is rejected, verified by a control that dropped the
width and height terms entirely (`medium: postcondition might fail`).

**Note on the spec as it stands:** the `=` clause *is* the specification, so the body
must match it term for term. If you later decide `Contains` should ignore edges, the
clause changes first and the body follows — not the other way round.

### `Iris.Geometry.Overlaps`

```ada
   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean is
   begin
      return Left.X < Right.X + Right.Width
        and then Right.X < Left.X + Left.Width
        and then Left.Y < Right.Y + Right.Height
        and then Right.Y < Left.Y + Left.Height;
   end Overlaps;
```

Same shape. The strict `<` is load-bearing: a control using `<=` (so edge-touching
rectangles count as overlapping) is rejected by the `=` clause. This is the highest-value
single check in the geometry package, because `<=` versus `<` is invisible to review.

### `Iris.Placement.Place_Floating`

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

### The bar, per function, measured against the specs as they now stand

| Function | Functional Contracts | Status |
| --- | --- | --- |
| `Contains` | 1 | the `=` clause; proved |
| `Overlaps` | 1 | the `=` clause; proved |
| `Place_Floating` | 1 of 3 | the `Placed`-implies-fits clause proves; the other two are vacuously satisfied by the current body |

Total across the project: **3 functional contracts, 4 run-time checks, all proved, none
unproved** — `Success: all checks proved (10 checks)` at `--level=4`.

The `Place_Floating` row deserves a note, because "1 of 3" looks worse than it is. The
two clauses that do not generate obligations are satisfied *vacuously* by the current
body: it returns `Request_Too_Small` only in the degenerate branch, so both implications
hold trivially. They are still worth having, and I measured why — removing the
degenerate-request early return makes the completeness clause fire immediately
(`cannot prove Place_Floating'Result.Status /= Placed`). **A vacuous postcondition is a
constraint on future bodies, not dead weight.**

### What CI should assert

Exit status alone is not enough. The job should fail unless:

1. `gnatprove` exits 0, **and**
2. the summary contains `Functional Contracts` with a non-zero count, **and**
3. `Unproved` is zero.

`--proof=per_check:all` is mandatory for that second condition to mean anything — without
it the summary omits checks that were generated, and I was briefly fooled by exactly that
during this investigation.

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

Scratch projects under `/home/aulus/.hermes/cache/scratch/`:

| Directory | What it holds |
| --- | --- |
| `bodies/` | the original investigation: bodies, the placement loophole, controls |
| `bodies/geo_only/` | geometry package **in isolation** — the zero-checks figure |
| `verify2/` | the current specs plus the bodies in §5 — the 10-check result |
| `postcond_matrix/` | weak vs `=` vs none, with the wrong-body control |
| `props/` | reflexivity and symmetry, including the recursion trap and the caller tests |

Every figure in this document came from:

```
gnatprove -P p.gpr --mode=all --level=4 --proof=per_check:all
```

with `obj/` cleared between runs. Each control was run against the same tree with one
line changed, and each produced the quoted diagnostic. Summary of the controls, all of
which now fail as required:

| Control | Expected | Result |
| --- | --- | --- |
| `Place_Floating` places without a fit check | rejected | `medium: postcondition might fail` |
| `Place_Floating` never returns `Request_Too_Small` | rejected | `cannot prove ... Status /= Placed` |
| `Contains` ignores width and height | rejected | `medium: postcondition might fail` |
| `Overlaps` uses `<=` for `<` | rejected | `medium: postcondition might fail` |
| reflexivity property **alone**, same wrong `Contains` | **not** rejected | `Success` — this is why properties are not recommended |
