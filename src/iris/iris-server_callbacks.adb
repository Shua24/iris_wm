package body Iris.Server_Callbacks is

   procedure Reset is
   begin
      Backend_Destroy_Count := 0;
      Self_Remove_Failed := False;
   end Reset;

   procedure On_Backend_Destroy
     (Listener : Opaque_Pointer; Data : Opaque_Pointer) is
      pragma Unreferenced (Listener);
      pragma Unreferenced (Data);
      Still_Attached : Boolean;
   begin
      Backend_Destroy_Count := Backend_Destroy_Count + 1;

      --  The pointer C passes is the address of the Wl_Listener, which is the
      --  first component of the Registration, so it is also the Registration's
      --  address. No offset arithmetic is performed anywhere.
      Detach (Backend_Destroy_Registration);

      Still_Attached := Is_Attached (Backend_Destroy_Registration);
      if Still_Attached then
         Self_Remove_Failed := True;
      end if;
   end On_Backend_Destroy;

end Iris.Server_Callbacks;
