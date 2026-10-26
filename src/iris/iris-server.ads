--  The compositor object graph: who owns what, and in what order it dies.
--
--  ---------------------------------------------------------------------------
--  The single-owner rule
--  ---------------------------------------------------------------------------
--
--  Every wlroots object Iris holds is owned by exactly one Ada record. That
--  record is responsible for destroying it, exactly once, and for detaching
--  every listener registered on it before it goes. Nothing else may call a
--  destroy function on that object, and nothing may keep a copy of the handle
--  after the owner has finished.
--
--  The rule exists because wlroots destroys objects from inside its own
--  callbacks. When a client disconnects, wlroots frees the surface and raises
--  its destroy signal; any Ada record still holding the old handle now points
--  at freed memory. The compiler cannot see that, so the discipline is stated
--  here and enforced by the shape of this package: handles are only reachable
--  through the owner, and the owner clears them as part of teardown.
--
--  ---------------------------------------------------------------------------
--  Teardown order, and why it is not negotiable
--  ---------------------------------------------------------------------------
--
--  Shutdown runs in the reverse of construction, with two constraints that
--  come from wlroots rather than from taste:
--
--    1. Clients are destroyed before the display. wl_display_destroy asserts
--       that no client remains, and wl_display_destroy_clients is the call
--       that disconnects them.
--
--    2. The backend is destroyed after everything that listens to it, and
--       every listener on its destroy signal must have removed itself. The
--       destroy handler in this package does exactly that, because
--       wlr_backend_finish asserts the listener list is empty.
--
--  A crash during teardown on real hardware means a VT that never comes back,
--  which is why this package is written before the compositor rather than
--  after it.
--
--  ---------------------------------------------------------------------------
--  Signal handling
--  ---------------------------------------------------------------------------
--
--  Start installs handlers for SIGINT and SIGTERM on the event loop. They do
--  one thing: ask the loop to return. Teardown then happens in Finish, on the
--  normal path, because destroying objects from inside a signal callback means
--  destroying them while the loop is still iterating over them.
--
--  This is not a nicety. Without it, SIGTERM kills the process by default
--  action, and on real hardware that means the DRM backend never releases the
--  VT: the machine is left on a dead console with no way back to the session.
--
--  ---------------------------------------------------------------------------
--  What this package does not do yet
--  ---------------------------------------------------------------------------
--
--  It owns the display and the backend. The renderer, allocator and scene are
--  not here yet, and neither are their destroy calls: the drop doctrine
--  applies to lifetime code too, and a destroy call with nothing to destroy is
--  a stub with extra steps.

with Iris.Wlroots.C_Types;

package Iris.Server is

   use Iris.Wlroots.C_Types;

   type Instance is tagged limited private;
   --  Limited, not controlled: teardown is an explicit call with a defined
   --  order, not an implicit one that runs at the end of an arbitrary scope.
   --  A controlled type would run its finalisation at a point chosen by the
   --  compiler, and the order above cannot survive that.

   type Startup_Result is (Succeeded, Display_Unavailable,
                           Event_Loop_Unavailable, Backend_Unavailable,
                           Signal_Handler_Unavailable);

   function Start (Server : in out Instance) return Startup_Result;
   --  Creates the display and autocreates the backend. Returns the first thing
   --  that failed rather than a bare boolean, so the caller can say which one.
   --  On any failure, no object is left allocated: a failed Start leaves the
   --  instance in the same state as before it was called. Calling Start on an
   --  instance that is already running returns Succeeded and does nothing.

   function Is_Running (Server : Instance) return Boolean;

   function Backend_Handle (Server : Instance) return Opaque_Pointer;
   --  Assumption: Is_Running (Server). Returns the handle without transferring
   --  ownership; the caller must not destroy it.

   function Display_Handle (Server : Instance) return Opaque_Pointer;
   --  Assumption: Is_Running (Server). Same ownership rule.

   procedure Run (Server : in out Instance);
   --  Blocks in the Wayland event loop until something terminates it. Returns
   --  with the object graph intact; the caller still has to call Finish.

   procedure Request_Shutdown (Server : in out Instance);
   --  Asks the event loop to return. Safe to call from a callback and safe to
   --  call when the loop is not running.

   procedure Finish (Server : in out Instance);
   --  Destroys everything in the order described above, then marks the
   --  instance as not running. Idempotent: calling it twice, or calling it on
   --  an instance that never started, does nothing. The second case is the one
   --  that matters in practice, because a failure path and a normal path both
   --  end here.

private

   type Instance is tagged limited record
      Display      : Opaque_Pointer := No_Pointer;
      Event_Loop   : Opaque_Pointer := No_Pointer;
      Backend      : Opaque_Pointer := No_Pointer;
      Sigint_Source  : Opaque_Pointer := No_Pointer;
      Sigterm_Source : Opaque_Pointer := No_Pointer;
      Running      : Boolean := False;
   end record;

end Iris.Server;
