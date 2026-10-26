with System;

package body Iris.Wlroots.C_Types is

   use type System.Address;

   function To_Boolean (Value : C_Boolean) return Boolean is
      Is_Nonzero : constant Boolean := Value /= 0;
   begin
      return Is_Nonzero;
   end To_Boolean;

   function To_C_Boolean (Value : Boolean) return C_Boolean is
      As_Byte : C_Boolean;
   begin
      if Value then
         As_Byte := 1;
      else
         As_Byte := 0;
      end if;
      return As_Byte;
   end To_C_Boolean;

   function No_Pointer return Opaque_Pointer is
      Absent : constant Opaque_Pointer := System.Null_Address;
   begin
      return Absent;
   end No_Pointer;

   function Is_Null (Value : Opaque_Pointer) return Boolean is
      Is_Absent : constant Boolean := Value = System.Null_Address;
   begin
      return Is_Absent;
   end Is_Null;

end Iris.Wlroots.C_Types;
