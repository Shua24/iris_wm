--  wl_event_loop: the loop that wl_display creates internally.
--
--  Iris adds two things to it: signal handlers for the shutdown signals, and
--  the remove call needed to take them off again during teardown.
--
--  A SIGTERM handler is not a nicety. Without one the default action kills the
--  process, which on real hardware means the DRM backend never releases the VT
--  and the machine is left with a dead display. The handler here only asks the
--  event loop to stop; all teardown happens in the normal path afterwards.

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Event_Loop is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   --  The signature libwayland expects for a signal handler on the loop.
   --  Return C 0 for "nothing more to do".
   type Signal_Procedure is
     access function
       (Signal_Number : C_Int; Data : Opaque_Pointer) return C_Int;
   pragma Convention (C, Signal_Procedure);

   --  Assumption: Event_Loop came from Display.Get_Event_Loop. Signal_Number
   --  is a real signal; the handler runs from inside the event loop, not from
   --  async signal context, so it may call wl_display_terminate.
   --  Returns an event source, or null if the signal could not be added.
   function Add_Signal
     (Event_Loop    : Opaque_Pointer;
      Signal_Number : C_Int;
      Handler       : Signal_Procedure;
      Data          : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wl_event_loop_add_signal";

   --  Assumption: Source came from Add_Signal or another wl_event_loop_add_*.
   --  Must be called before the loop is destroyed.
   procedure Remove_Source (Source : Opaque_Pointer)
     with Import, Convention => C,
          External_Name => "wl_event_source_remove";

end Iris.Wlroots.Event_Loop;
