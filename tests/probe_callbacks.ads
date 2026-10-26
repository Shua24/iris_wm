--  Library-level callback state for the binding probe.
--
--  This exists because Ada forbids taking `'Access` of a nested subprogram
--  against a library-level access type ("subprogram has wrong convention").
--  Every wlroots callback in Iris therefore lives at library level, and this
--  package is the probe's instance of that rule, not a workaround for it.

with Iris.Wlroots.C_Types;
with Iris.Wlroots.Listeners;

package Probe_Callbacks is

   use Iris.Wlroots.C_Types;
   use Iris.Wlroots.Listeners;

   Backend_Destroy_Registration : aliased Registration;

   Destroy_Callback_Count : Natural := 0;
   --  How many times the destroy handler ran. Expected: exactly one.

   Self_Remove_Failed : Boolean := False;
   --  Set when the handler could not detach itself. This is the check that
   --  matters: wlr_backend_finish asserts the destroy listener list is empty,
   --  so a handler that forgets aborts the process during teardown.

   procedure On_Backend_Destroy
     (Listener : Opaque_Pointer; Data : Opaque_Pointer);
   pragma Convention (C, On_Backend_Destroy);

end Probe_Callbacks;
