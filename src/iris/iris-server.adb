with Iris.Server_Callbacks;

with Iris.Wlroots.Backend;

with Iris.Wlroots.Display;
with Iris.Wlroots.Listeners;

package body Iris.Server is

   use Iris.Wlroots.Listeners;

   ----------------------------------------------------------------------------
   --  Construction
   ----------------------------------------------------------------------------

   function Start (Server : in out Instance) return Startup_Result is
      Already_Running : constant Boolean := Server.Running;
      Display_Value   : Opaque_Pointer;
      Loop_Value      : Opaque_Pointer;
      Backend_Value   : Opaque_Pointer;
      Signals         : access Iris.Wlroots.Backend.Backend;
      Created         : Boolean;
      Loop_Ready      : Boolean;
      Backend_Ready   : Boolean;
   begin
      if Already_Running then
         return Succeeded;
      end if;

      Iris.Server_Callbacks.Reset;

      Display_Value := Iris.Wlroots.Display.Create;
      Created := not Is_Null (Display_Value);
      if not Created then
         return Display_Unavailable;
      end if;

      Loop_Value := Iris.Wlroots.Display.Get_Event_Loop (Display_Value);
      Loop_Ready := not Is_Null (Loop_Value);
      if not Loop_Ready then
         --  Nothing has been autocreated yet, so the display is the only thing
         --  to release. A failed Start must not leak.
         Iris.Wlroots.Display.Destroy (Display_Value);
         return Event_Loop_Unavailable;
      end if;

      Backend_Value := Iris.Wlroots.Backend.Autocreate
        (Loop_Value, No_Pointer);
      Backend_Ready := not Is_Null (Backend_Value);
      if not Backend_Ready then
         Iris.Wlroots.Display.Destroy (Display_Value);
         return Backend_Unavailable;
      end if;

      Server.Display := Display_Value;
      Server.Event_Loop := Loop_Value;
      Server.Backend := Backend_Value;
      Server.Running := True;

      --  The destroy handler is registered immediately, before anything else
      --  is built on top of the backend. If the compositor fails to come up
      --  after this point, Finish still has a listener to remove, and the
      --  backend is still destroyed through the same path as a normal exit.
      Signals := Iris.Wlroots.Backend.As_Backend (Backend_Value);
      Prepare (Iris.Server_Callbacks.Backend_Destroy_Registration,
               Iris.Server_Callbacks.On_Backend_Destroy'Access,
               Backend_Value);
      Attach (Iris.Server_Callbacks.Backend_Destroy_Registration,
              Signals.Events.Destroy);

      return Succeeded;
   end Start;

   ----------------------------------------------------------------------------
   --  Queries
   ----------------------------------------------------------------------------

   function Is_Running (Server : Instance) return Boolean is
      Result : constant Boolean := Server.Running;
   begin
      return Result;
   end Is_Running;

   function Backend_Handle (Server : Instance) return Opaque_Pointer is
      Result : constant Opaque_Pointer := Server.Backend;
   begin
      return Result;
   end Backend_Handle;

   function Display_Handle (Server : Instance) return Opaque_Pointer is
      Result : constant Opaque_Pointer := Server.Display;
   begin
      return Result;
   end Display_Handle;

   ----------------------------------------------------------------------------
   --  Running
   ----------------------------------------------------------------------------

   procedure Run (Server : in out Instance) is
      Display_Value : constant Opaque_Pointer := Server.Display;
      Is_Ready      : constant Boolean := Server.Running;
   begin
      if not Is_Ready then
         return;
      end if;
      Iris.Wlroots.Display.Run (Display_Value);
   end Run;

   procedure Request_Shutdown (Server : in out Instance) is
      Display_Value : constant Opaque_Pointer := Server.Display;
      Is_Ready      : constant Boolean := Server.Running;
   begin
      if not Is_Ready then
         return;
      end if;
      Iris.Wlroots.Display.Terminate_Event_Loop (Display_Value);
   end Request_Shutdown;

   ----------------------------------------------------------------------------
   --  Teardown
   ----------------------------------------------------------------------------

   procedure Finish (Server : in out Instance) is
      Was_Running : constant Boolean := Server.Running;
      Display_Value : constant Opaque_Pointer := Server.Display;
      Backend_Value : constant Opaque_Pointer := Server.Backend;
   begin
      if not Was_Running then
         --  A failure path and a normal path both end here, so this has to be
         --  a no-op rather than an error.
         return;
      end if;

      --  Step 1: every listener this package registered removes itself before
      --  the object it listens to is destroyed. Doing it here as well as in
      --  the handler is not redundant: it covers the case where teardown runs
      --  before the backend ever raised its own destroy signal.
      Detach (Iris.Server_Callbacks.Backend_Destroy_Registration);

      --  Step 2: clients before the display. wl_display_destroy asserts that
      --  no client remains, so this is not optional.
      Iris.Wlroots.Display.Destroy_Clients (Display_Value);

      --  Step 3: the backend, now that nothing is listening to it.
      Iris.Wlroots.Backend.Destroy (Backend_Value);

      --  Step 4: the display itself.
      Iris.Wlroots.Display.Destroy (Display_Value);

      Server.Display := No_Pointer;
      Server.Event_Loop := No_Pointer;
      Server.Backend := No_Pointer;
      Server.Running := False;
   end Finish;

end Iris.Server;
