with System.Address_To_Access_Conversions;

package body Iris.Wlroots.Scene_Output is

   package Scene_Output_Conversions is
     new System.Address_To_Access_Conversions (Scene_Output);

   function As_Scene_Output
     (Value : Opaque_Pointer) return access Scene_Output is
      Converted : constant access Scene_Output :=
        Scene_Output_Conversions.To_Pointer (Value);
   begin
      return Converted;
   end As_Scene_Output;

end Iris.Wlroots.Scene_Output;
