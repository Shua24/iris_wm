--  Iris: a Wayland compositor written in Ada on top of wlroots.
--
--  This package exists to hold the layering, not to be called. The child
--  packages are arranged so that dependencies point in one direction only:
--
--    Iris.Wlroots.*   the thin binding. Opaque C pointers, struct mirrors,
--                     callbacks, and nothing else. Depends on wlroots and on
--                     nothing in Iris except Iris.Wlroots.C_Types.
--
--    Iris.*           compositor policy in ordinary Ada. Owns its own state,
--                     mirrors no wlroots struct, and stores no raw C pointer
--                     beyond the handles it passes straight back to the
--                     binding.
--
--    Iris.Geometry,
--    Iris.Placement   the verified seam. Plain Ada scalars and arrays in,
--                     plain Ada values out. No pointers, no C types. This is
--                     the boundary at which a proof about Iris stops meaning
--                     anything about wlroots, the GPU driver or the kernel.
--
--  The rule that keeps the layers apart is simple: a package may not `with` a
--  package from a layer above it, and Iris.Wlroots never `with`s policy.

package Iris is
   pragma Pure;

end Iris;
