package body Probe_Callbacks is

   procedure On_Backend_Destroy
     (Listener : Opaque_Pointer; Data : Opaque_Pointer) is
      pragma Unreferenced (Listener);
      pragma Unreferenced (Data);
      Still_Attached : Boolean;
   begin
      Destroy_Callback_Count := Destroy_Callback_Count + 1;

      --  The listener pointer C passes is the address of the Wl_Listener,
      --  which is the first member of the Registration, so it is also the
      --  Registration's address. No offset arithmetic: that is the entire
      --  reason the listener-first convention exists.
      Detach (Backend_Destroy_Registration);

      Still_Attached := Is_Attached (Backend_Destroy_Registration);
      if Still_Attached then
         Self_Remove_Failed := True;
      end if;
   end On_Backend_Destroy;

end Probe_Callbacks;
