with System.Address_To_Access_Conversions;

package body Iris.Wlroots.Backend is

   package Backend_Conversions is
     new System.Address_To_Access_Conversions (Backend);

   function As_Backend (Value : Opaque_Pointer) return access Backend is
      Converted : constant access Backend :=
        Backend_Conversions.To_Pointer (Value);
   begin
      return Converted;
   end As_Backend;

end Iris.Wlroots.Backend;
