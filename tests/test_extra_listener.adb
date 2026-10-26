package body Test_Extra_Listener is

   procedure On_Destroy
     (Listener : Opaque_Pointer; Data : Opaque_Pointer) is
      pragma Unreferenced (Listener);
      pragma Unreferenced (Data);
   begin
      Call_Count := Call_Count + 1;

      --  A listener that stays attached aborts wlr_backend_finish, so this
      --  handler removes itself exactly like the server's own handler does.
      Detach (Extra_Registration);
   end On_Destroy;

end Test_Extra_Listener;
