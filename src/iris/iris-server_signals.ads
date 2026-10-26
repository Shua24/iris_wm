--  Library-level signal handler state for Iris.Server.
--
--  The handler needs the display handle to call wl_display_terminate, and a
--  callback cannot be nested, so the handle lives here. It is set by
--  Server.Start and cleared by Server.Finish.

with Iris.Wlroots.C_Types;

package Iris.Server_Signals is

   use Iris.Wlroots.C_Types;

   Display_For_Shutdown : Opaque_Pointer := No_Pointer;

   Shutdown_Requested : Boolean := False;
   --  Set by the handler, so a test can tell "the signal arrived and was
   --  handled" from "the process died of the default action".

   procedure Reset;

   function On_Shutdown_Signal
     (Signal_Number : C_Int;
      Data          : Opaque_Pointer) return C_Int;
   pragma Convention (C, On_Shutdown_Signal);

end Iris.Server_Signals;
