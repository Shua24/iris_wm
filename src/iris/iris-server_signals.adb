with Iris.Wlroots.Display;

package body Iris.Server_Signals is

   procedure Reset is
   begin
      Display_For_Shutdown := No_Pointer;
      Shutdown_Requested := False;
   end Reset;

   function On_Shutdown_Signal
     (Signal_Number : C_Int;
      Data          : Opaque_Pointer) return C_Int is
      pragma Unreferenced (Signal_Number);
      pragma Unreferenced (Data);
      Display_Value : constant Opaque_Pointer := Display_For_Shutdown;
      Absent        : constant Boolean := Is_Null (Display_Value);
      Done          : constant C_Int := 0;
   begin
      Shutdown_Requested := True;

      --  Ask the event loop to return. Teardown happens in Server.Finish, on
      --  the normal path, rather than here: doing it from inside a signal
      --  callback would destroy objects the loop is still iterating over.
      if not Absent then
         Iris.Wlroots.Display.Terminate_Event_Loop (Display_Value);
      end if;

      return Done;
   end On_Shutdown_Signal;

end Iris.Server_Signals;
