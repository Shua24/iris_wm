--  Init probe: brings up a real compositor, publishes the protocol globals,
--  and lets a real client connect and report what it sees.
--
--  This is the A1b acceptance test. A comment cannot verify a protocol
--  version; a client can. The probe therefore does not print its own opinion
--  of the versions — it prints what wayland-info says after connecting.
--
--  Two modes:
--
--    ./bin/init_probe                 run until SIGTERM, printing the socket
--    ./bin/init_probe --exit-after N  run for N seconds, then shut down
--
--  The second mode exists so the test is scriptable. scripts/init-check.sh
--  drives it: start the probe, connect wayland-info, assert the versions,
--  terminate, and check the process exited cleanly with no coredump.
--
--  Run nested (DISPLAY set) or headless (WLR_BACKENDS=headless). Both paths
--  exercise the same init sequence; only the backend differs.

with Ada.Command_Line;
with Ada.Text_IO;

with Interfaces.C.Strings;

with Iris.Server;
with Iris.Wlroots.C_Types;
with Iris.Wlroots.Display;
with Iris.Wlroots.Protocols;
with Iris.Wlroots.Render;

procedure Init_Probe is

   use Iris.Wlroots.C_Types;
   use type Iris.Server.Startup_Result;


   Server  : Iris.Server.Instance;
   Result  : Iris.Server.Startup_Result;
   Display : Opaque_Pointer;
   Backend : Opaque_Pointer;
   Renderer : Opaque_Pointer;
   Allocator : Opaque_Pointer;
   Shm_Ready : Boolean;
   Socket    : Interfaces.C.Strings.chars_ptr;
   Socket_Ok : Boolean;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line ("init_probe: " & Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Fail;

begin
   Result := Iris.Server.Start (Server);
   if Result /= Iris.Server.Succeeded then
      Fail ("server start failed");
      return;
   end if;

   Display := Iris.Server.Display_Handle (Server);
   Backend := Iris.Server.Backend_Handle (Server);

   --  The renderer must exist before the compositor global is created, because
   --  wlr_compositor_create takes it to build textures from client buffers.
   Renderer := Iris.Wlroots.Render.Renderer_Autocreate (Backend);
   if Is_Null (Renderer) then
      Fail ("no renderer");
      Iris.Server.Finish (Server);
      return;
   end if;

   Allocator := Iris.Wlroots.Render.Allocator_Autocreate (Backend, Renderer);
   if Is_Null (Allocator) then
      Fail ("no allocator");
      Iris.Server.Finish (Server);
      return;
   end if;

   --  wl_shm before any client connects: without it clients cannot send
   --  buffers at all, and the connection would look successful while nothing
   --  could be drawn.
   Shm_Ready := To_Boolean
     (Iris.Wlroots.Render.Init_Shared_Memory (Renderer, Display));
   if not Shm_Ready then
      Fail ("wl_shm initialisation failed");
      Iris.Server.Finish (Server);
      return;
   end if;

   --  The globals, at the versions Iris advertises.
   declare
      Compositor : constant Opaque_Pointer :=
        Iris.Wlroots.Protocols.Create_Compositor (Display, Renderer);
      Subcompositor : constant Opaque_Pointer :=
        Iris.Wlroots.Protocols.Create_Subcompositor (Display);
      Xdg : constant Opaque_Pointer :=
        Iris.Wlroots.Protocols.Create_Xdg_Shell (Display);
      Layer : constant Opaque_Pointer :=
        Iris.Wlroots.Protocols.Create_Layer_Shell (Display);
      Data_Device : constant Opaque_Pointer :=
        Iris.Wlroots.Protocols.Create_Data_Device_Manager (Display);
      Primary : constant Opaque_Pointer :=
        Iris.Wlroots.Protocols.Create_Primary_Selection (Display);
   begin
      if Is_Null (Compositor) or else Is_Null (Subcompositor)
        or else Is_Null (Xdg) or else Is_Null (Layer)
        or else Is_Null (Data_Device) or else Is_Null (Primary)
      then
         Fail ("a protocol global failed to create");
         Iris.Server.Finish (Server);
         return;
      end if;
   end;

   Socket := Iris.Wlroots.Display.Add_Socket_Auto (Display);
   Socket_Ok := Interfaces.C.Strings.Value (Socket) /= "";
   if not Socket_Ok then
      Fail ("could not add a wayland socket");
      Iris.Server.Finish (Server);
      return;
   end if;

   Ada.Text_IO.Put_Line
     ("WAYLAND_DISPLAY=" & Interfaces.C.Strings.Value (Socket));

   --  Flush so the parent script sees the socket name before blocking.
   Ada.Text_IO.Flush;

   Iris.Server.Run (Server);
   Iris.Server.Finish (Server);

   Ada.Text_IO.Put_Line ("init_probe: clean shutdown");
end Init_Probe;
