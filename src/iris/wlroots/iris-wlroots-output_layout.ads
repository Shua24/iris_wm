--  wlr_output_layout: where outputs sit in the global coordinate space.
--
--  This is the geometry Iris's placement policy reasons about, so its
--  properties matter beyond the binding:
--
--    * Output positions are arbitrary integers, negative ones included.
--      wlr_output_layout_add places an output at an explicit (x, y); there is
--      no requirement that anything sits at the origin.
--    * Output boxes are therefore not anchored at (0, 0), and they may
--      overlap. The placement contract handed to SPARK must not assume
--      otherwise.
--
--  wlr_output_layout_output_at takes double coordinates. It is deliberately
--  NOT bound yet: nothing in v0 asks which output a pointer is over, and a
--  binding with a stub body would be a capability with a no-op handler. It
--  arrives with the seat in B8, at the point where a real double is converted
--  to an integer exactly once.

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Output_Layout is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   --  A rectangle, mirroring struct wlr_box. Integer, not floating point:
   --  wlr/util/box.h declares `int x, y, width, height`, and the probe proves
   --  the mirror (size 16, x 0, y 4, width 8, height 12).
   type Box is record
      X      : C_Int;
      Y      : C_Int;
      Width  : C_Int;
      Height : C_Int;
   end record;
   pragma Convention (C, Box);

   --  Assumption: Display is live. Returns null on allocation failure.
   function Create (Display : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_output_layout_create";

   --  Assumption: Layout is live and every output has been detached from it.
   procedure Destroy (Layout : Opaque_Pointer)
     with Import, Convention => C,
          External_Name => "wlr_output_layout_destroy";

   --  Assumption: Layout and Output are live. Places Output at an explicit
   --  position in the layout's coordinate space. Returns null if the output is
   --  already present.
   function Add
     (Layout : Opaque_Pointer;
      Output : Opaque_Pointer;
      X      : C_Int;
      Y      : C_Int) return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_output_layout_add";

end Iris.Wlroots.Output_Layout;
