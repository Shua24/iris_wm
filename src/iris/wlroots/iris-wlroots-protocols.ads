--  The protocol globals Iris advertises, and their versions.
--
--  ---------------------------------------------------------------------------
--  Why these numbers are not guesses
--  ---------------------------------------------------------------------------
--
--  Advertising a stale protocol version is a real compatibility bug, not a
--  conservative choice: clients gate features on the version the compositor
--  advertises, so a compositor claiming wl_compositor v5 silently withholds
--  every v6 surface role. tinywl advertises wl_compositor v5 and xdg_wm_base
--  v3, which is why copying it produces clients that behave oddly.
--
--  Iris advertises what labwc advertises:
--
--     wl_compositor          6   (labwc LAB_WLR_COMPOSITOR_VERSION)
--     xdg_wm_base            6   (labwc LAB_XDG_SHELL_VERSION)
--     zwlr_layer_shell_v1    4   (labwc LAB_LAYERSHELL_VERSION)
--
--  The numbers are protocol facts. Reading them out of a reference
--  implementation is not copying code, which is why this is allowed under the
--  ada-first rule while the implementation below is written fresh.
--
--  These are asserted end to end by the init probe, which runs a real
--  compositor and asks wayland-info what it sees. A comment cannot verify a
--  version number; a client can.

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Protocols is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   Compositor_Version    : constant C_Unsigned := 6;
   Xdg_Shell_Version     : constant C_Unsigned := 6;
   Layer_Shell_Version   : constant C_Unsigned := 4;

   ----------------------------------------------------------------------------
   --  Creation
   ----------------------------------------------------------------------------

   --  Assumption: Display is live and Renderer is the live renderer built for
   --  the same backend. Returns null on allocation failure.
   function Create_Compositor
     (Display  : Opaque_Pointer;
      Renderer : Opaque_Pointer) return Opaque_Pointer;

   --  Assumption: Display is live.
   function Create_Subcompositor (Display : Opaque_Pointer)
                                  return Opaque_Pointer;

   --  Assumption: Display is live. Creates the xdg_wm_base global at the
   --  version given above.
   function Create_Xdg_Shell (Display : Opaque_Pointer) return Opaque_Pointer;

   --  Assumption: Display is live. Creates zwlr_layer_shell_v1 at the version
   --  given above.
   function Create_Layer_Shell
     (Display : Opaque_Pointer) return Opaque_Pointer;

   --  Assumption: Display is live. Creates wl_data_device_manager, which is
   --  what makes clipboard and drag-and-drop exist at all.
   function Create_Data_Device_Manager (Display : Opaque_Pointer)
                                        return Opaque_Pointer;

   --  Assumption: Display is live. Creates the primary-selection global, which
   --  is middle-click paste.
   function Create_Primary_Selection (Display : Opaque_Pointer)
                                      return Opaque_Pointer;

end Iris.Wlroots.Protocols;
