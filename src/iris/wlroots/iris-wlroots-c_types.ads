--  C scalar and pointer types used at the wlroots boundary.
--
--  Everything here is deliberately dull. Iris does not model C types, it names
--  them exactly once so that every binding package agrees on what a C int, a C
--  boolean and an opaque pointer are.

with Interfaces.C;
with System;

package Iris.Wlroots.C_Types is
   pragma Preelaborate;

   subtype C_Int is Interfaces.C.int;
   subtype C_Unsigned is Interfaces.C.unsigned;
   subtype C_Size is Interfaces.C.size_t;

   --  C99 `bool` is one byte wide. Reading it through a wider type would read
   --  bytes above it that the ABI does not define, so it gets its own one byte
   --  type and an explicit conversion.
   type C_Boolean is new Interfaces.C.unsigned_char;

   function To_Boolean (Value : C_Boolean) return Boolean;
   --  C defines any non-zero value as true.

   function To_C_Boolean (Value : Boolean) return C_Boolean;

   --  An opaque C pointer. Iris never dereferences one of these in Ada; it is
   --  handed straight back to the library that produced it. Where a struct
   --  genuinely has to be read, a package declares its own mirror type and
   --  converts explicitly, with the layout proven against C `offsetof`.
   subtype Opaque_Pointer is System.Address;

   function No_Pointer return Opaque_Pointer;
   --  System.Null_Address is not a static expression, so it cannot be a
   --  constant in a preelaborated unit. A function is the portable spelling.

   function Is_Null (Value : Opaque_Pointer) return Boolean;
   --  Every autocreate call in wlroots returns null on failure rather than
   --  raising, so this is the only failure signal the boundary gets.

end Iris.Wlroots.C_Types;
