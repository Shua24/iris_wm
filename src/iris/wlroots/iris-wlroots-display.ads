--  wl_display: the Wayland server object, its event loop, and the socket a
--  client connects to.
--
--  Iris does not create its own wl_event_loop. wl_display_create creates one
--  internally and wl_display_get_event_loop returns it; everything else in
--  wlroots takes that loop. Creating a second one produces a compositor that
--  accepts connections and never processes them.

with Interfaces.C.Strings;

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Display is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   --  Assumption: none. Returns null when the display cannot be allocated, in
   --  which case no other call in this package may be made.
   function Create return Opaque_Pointer
     with Import, Convention => C, External_Name => "wl_display_create";

   --  Assumption: Display came from Create and has not been destroyed. All
   --  clients must be destroyed first (Destroy_Clients) or the display's
   --  destroy asserts.
   procedure Destroy (Display : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_display_destroy";

   --  Assumption: Display is a live display. The returned loop is owned by the
   --  display and must not be destroyed separately.
   function Get_Event_Loop (Display : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wl_display_get_event_loop";

   --  Binds the next free Wayland socket in XDG_RUNTIME_DIR and returns its
   --  name. Assumption: XDG_RUNTIME_DIR is set and its path is short enough
   --  that the resulting socket path fits in sockaddr_un; Wayland fails above
   --  108 bytes for the whole path. Returns a null pointer on failure.
   function Add_Socket_Auto (Display : Opaque_Pointer)
                             return Interfaces.C.Strings.chars_ptr
     with Import, Convention => C,
          External_Name => "wl_display_add_socket_auto";

   --  Assumption: Display is live. Disconnects every client without waiting
   --  for them to leave. Must be called before Destroy, and only after the
   --  compositor has finished with client-owned objects.
   procedure Destroy_Clients (Display : Opaque_Pointer)
     with Import, Convention => C,
          External_Name => "wl_display_destroy_clients";

   --  Blocks in the display's event loop until Terminate is called from a
   --  callback or a signal handler.
   procedure Run (Display : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_display_run";

   procedure Terminate_Event_Loop (Display : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_display_terminate";

   --  Assumption: Display is live. Pushes pending events to clients.
   procedure Flush_Clients (Display : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_display_flush_clients";

end Iris.Wlroots.Display;
