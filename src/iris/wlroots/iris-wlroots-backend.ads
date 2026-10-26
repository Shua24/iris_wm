--  wlr_backend: the object that owns outputs and input devices.
--
--  `wlr_backend_autocreate` picks the most suitable backend from the
--  environment: X11 when DISPLAY is set, DRM when a session and a GPU are
--  available, headless when WLR_BACKENDS=headless. It always returns a
--  multi-backend, already created but not started.
--
--  One struct is mirrored here, and only its event signals are read. The
--  layout was proven against C `offsetof` (tests/c_layout_ground_truth.c)
--  before use: size 64, impl 0, buffer_caps 8, features.timeline 12,
--  events.destroy 16, events.new_input 32, events.new_output 48.

with Iris.Wlroots.C_Types;
with Iris.Wlroots.Listeners;

package Iris.Wlroots.Backend is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   ----------------------------------------------------------------------------
   --  struct wlr_backend mirror - event signals only
   ----------------------------------------------------------------------------

   type Backend_Features is record
      Timeline : C_Boolean;
   end record;
   pragma Convention (C, Backend_Features);

   type Backend_Events is record
      Destroy    : aliased Iris.Wlroots.Listeners.Wl_Signal;
      New_Input  : aliased Iris.Wlroots.Listeners.Wl_Signal;
      New_Output : aliased Iris.Wlroots.Listeners.Wl_Signal;
   end record;
   pragma Convention (C, Backend_Events);

   --  The leading fields are named even though Iris never reads them, because
   --  a mirror has to be complete up to the member it needs.
   type Backend is record
      Implementation : Opaque_Pointer;
      Buffer_Caps    : C_Unsigned;
      Features       : Backend_Features;
      Events         : Backend_Events;
   end record;
   pragma Convention (C, Backend);

   function As_Backend (Value : Opaque_Pointer) return access Backend;
   --  Assumption: Value is a non-null struct wlr_backend returned by
   --  Autocreate and not yet destroyed. Reading a freed backend is undefined.

   ----------------------------------------------------------------------------
   --  Calls
   ----------------------------------------------------------------------------

   --  Assumption: Event_Loop came from Display.Get_Event_Loop. Session_Pointer
   --  may be null, in which case the session (if any) is not reported back.
   --  Returns null on failure; the caller must not proceed with a null
   --  backend.
   function Autocreate
     (Event_Loop      : Opaque_Pointer;
      Session_Pointer : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_backend_autocreate";

   --  Assumption: Backend is not null and has not been started. May raise
   --  new_input and new_output immediately, or later from the event loop.
   --  Returns C false on failure.
   function Start (Backend : Opaque_Pointer) return C_Boolean
     with Import, Convention => C, External_Name => "wlr_backend_start";

   --  Assumption: Backend is not null. Asserts that the backend's destroy
   --  listener list is empty, which means every listener registered on
   --  Events.Destroy must have removed itself by the time this is called.
   --  The listener registered here is removed by its own handler for exactly
   --  that reason.
   procedure Destroy (Backend : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wlr_backend_destroy";

   --  Assumption: Backend is a live backend whose platform has a DRM node.
   --  Returns -1 when it does not. The descriptor is owned by the backend and
   --  must not be closed by the caller.
   function Get_Drm_File_Descriptor (Backend : Opaque_Pointer) return C_Int
     with Import, Convention => C, External_Name => "wlr_backend_get_drm_fd";

end Iris.Wlroots.Backend;
