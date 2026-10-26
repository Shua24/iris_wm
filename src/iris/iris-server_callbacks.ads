--  Library-level callback state for the server object graph.
--
--  Every wlroots callback in Iris lives at library level, because Ada forbids
--  `'Access` of a nested subprogram against a library-level access type. This
--  package holds the backend's destroy registration and the state the handler
--  needs to report what it did.

with Iris.Wlroots.C_Types;
with Iris.Wlroots.Listeners;

package Iris.Server_Callbacks is

   use Iris.Wlroots.C_Types;
   use Iris.Wlroots.Listeners;

   Backend_Destroy_Registration : aliased Registration;

   Backend_Destroy_Count : Natural := 0;
   --  Times the backend destroy handler ran. Expected: exactly one per
   --  backend, which is the regression check for risk #3.

   Self_Remove_Failed : Boolean := False;
   --  Set if the handler could not detach itself. wlr_backend_finish asserts
   --  the destroy listener list is empty, so this failing is a teardown abort.

   procedure Reset;
   --  Clears the state above. Called by Server.Start so that a second Start on
   --  a reused instance does not inherit the first run's counters.

   procedure On_Backend_Destroy
     (Listener : Opaque_Pointer; Data : Opaque_Pointer);
   pragma Convention (C, On_Backend_Destroy);

end Iris.Server_Callbacks;
