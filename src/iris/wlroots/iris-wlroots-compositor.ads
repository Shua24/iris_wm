--  wlr_compositor and wlr_subcompositor: the surfaces clients draw on.
--
--  Both take a version, and the version Iris advertises is fixed in
--  Iris.Wlroots.Protocols rather than here, so there is exactly one place a
--  version number appears.

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Compositor is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   --  Assumption: Display is live and Renderer is a live renderer created from
   --  the same backend. Passing a null renderer is legal in wlroots but makes
   --  the compositor unable to create textures from client buffers, which for
   --  Iris means nothing renders; treat null as a programming error here.
   function Create
     (Display  : Opaque_Pointer;
      Version  : C_Unsigned;
      Renderer : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_compositor_create";

   --  Assumption: Display is live. Has no destroy of its own; it goes with the
   --  display.
   function Create_Subcompositor (Display : Opaque_Pointer)
                                  return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wlr_subcompositor_create";

end Iris.Wlroots.Compositor;
