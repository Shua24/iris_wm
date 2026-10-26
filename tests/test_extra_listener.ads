--  A foreign listener used by the lifetime test.
--
--  Library level, like every wlroots callback in Iris, and with a real handler
--  rather than a null one: passing null here makes wlroots call a null
--  function pointer when it emits destroy, which is a segfault that looks like
--  a lifetime bug and is not one.

with Iris.Wlroots.C_Types;
with Iris.Wlroots.Listeners;

package Test_Extra_Listener is

   use Iris.Wlroots.C_Types;
   use Iris.Wlroots.Listeners;

   Extra_Registration : aliased Registration;

   Call_Count : Natural := 0;

   procedure On_Destroy
     (Listener : Opaque_Pointer; Data : Opaque_Pointer);
   pragma Convention (C, On_Destroy);

end Test_Extra_Listener;
