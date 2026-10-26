--  Lifetime regression test for Iris.Server.
--
--  Three cases:
--
--    1. Finish on an instance that never started. This is the path every
--       startup failure takes, and it must be a no-op rather than a crash.
--
--    2. Finish called twice. The second call must do nothing. If the server
--       did not clear its handles, the second call would destroy freed
--       objects.
--
--    3. Finish called with a second, foreign listener still attached to the
--       backend's destroy signal. This is the risk #3 regression: the handler
--       removes itself, wlr_backend_finish's "listener list must be empty"
--       assertion holds, and the process survives. Without the self-remove the
--       process aborts here.
--
--  Note on the destroy counter: Finish detaches the server's own registration
--  before destroying the backend, so a clean shutdown does NOT run the destroy
--  handler. That is the intended order, and the count of zero after a normal
--  finish is the evidence that the detach-before-destroy order is what
--  actually happens.
--
--  Run:
--    DISPLAY=:1 ./bin/lifetime_test
--    WLR_BACKENDS=headless ./bin/lifetime_test
--
--  Expected: "RESULT: PASS".

with Ada.Command_Line;
with Ada.Text_IO;

with Test_Extra_Listener;

with Iris.Server;
with Iris.Server_Callbacks;
with Iris.Wlroots.Backend;
with Iris.Wlroots.C_Types;
with Iris.Wlroots.Listeners;

procedure Lifetime_Test is

   use Iris.Wlroots.C_Types;
   use Iris.Wlroots.Listeners;
   use type Iris.Server.Startup_Result;

   package Natural_IO is new Ada.Text_IO.Integer_IO (Natural);

   Failures : Natural := 0;

   procedure Report (Name : String; Detail : String) is
   begin
      Ada.Text_IO.Put_Line ("ok:   " & Name & " " & Detail);
   end Report;

   procedure Fail (Name : String; Detail : String) is
   begin
      Failures := Failures + 1;
      Ada.Text_IO.Put_Line ("FAIL: " & Name & " " & Detail);
   end Fail;

   procedure Expect
     (Name      : String;
      Condition : Boolean;
      Detail    : String) is
   begin
      if Condition then
         Report (Name, Detail);
      else
         Fail (Name, Detail);
      end if;
   end Expect;

   procedure Show (Label : String; Value : Natural) is
   begin
      Ada.Text_IO.Put (Label);
      Natural_IO.Put (Value, Width => 1);
      Ada.Text_IO.New_Line;
   end Show;

   ---------------------------------------------------------------------------
   --  Case 1: finish without start
   ---------------------------------------------------------------------------

   procedure Check_Finish_Without_Start is
      Server : Iris.Server.Instance;
   begin
      --  No Start. This is the path a startup failure takes.
      Iris.Server.Finish (Server);
      Expect ("finish without start is a no-op", True, "");
      Expect ("instance still not running",
              not Iris.Server.Is_Running (Server), "");
   end Check_Finish_Without_Start;

   ---------------------------------------------------------------------------
   --  Case 2: finish twice
   ---------------------------------------------------------------------------

   procedure Check_Double_Finish is
      Server        : Iris.Server.Instance;
      Result        : Iris.Server.Startup_Result;
      Was_Running   : Boolean;
      Still_Running : Boolean;
      Destroy_Count : Natural;
   begin
      Result := Iris.Server.Start (Server);
      Expect ("start for double finish", Result = Iris.Server.Succeeded, "");

      Was_Running := Iris.Server.Is_Running (Server);
      Expect ("server reports running", Was_Running, "");

      Iris.Server.Finish (Server);
      Still_Running := Iris.Server.Is_Running (Server);
      Expect ("finish clears running", not Still_Running, "");

      Destroy_Count := Iris.Server_Callbacks.Backend_Destroy_Count;
      Show ("destroy handler calls after a clean finish ", Destroy_Count);
      Expect ("clean finish detaches before destroying", Destroy_Count = 0,
              "(handler not reached, as designed)");

      --  The second call is the regression: without cleared handles it would
      --  destroy the display and the backend a second time, and the process
      --  would die here rather than reporting.
      Iris.Server.Finish (Server);
      Expect ("second finish is a no-op", True, "(process survived)");

      Destroy_Count := Iris.Server_Callbacks.Backend_Destroy_Count;
      Expect ("no extra destroy callbacks", Destroy_Count = 0, "(still 0)");
   end Check_Double_Finish;

   ---------------------------------------------------------------------------
   --  Case 3: finish with a foreign listener still attached
   ---------------------------------------------------------------------------

   procedure Check_Finish_With_Listener is
      Server     : Iris.Server.Instance;
      Result     : Iris.Server.Startup_Result;
      Backend    : Opaque_Pointer;
      Signals    : access Iris.Wlroots.Backend.Backend;
      Attached   : Boolean;
      Still_On   : Boolean;
   begin
      Result := Iris.Server.Start (Server);
      Expect ("start for listener case", Result = Iris.Server.Succeeded, "");

      Backend := Iris.Server.Backend_Handle (Server);
      Signals := Iris.Wlroots.Backend.As_Backend (Backend);

      --  A second registration on the same destroy signal, attached the way
      --  any compositor component would attach one, with a real handler.
      Prepare (Test_Extra_Listener.Extra_Registration,
               Test_Extra_Listener.On_Destroy'Access,
               Backend);
      Attach (Test_Extra_Listener.Extra_Registration,
              Signals.Events.Destroy);
      Attached := Is_Attached (Test_Extra_Listener.Extra_Registration);
      Expect ("extra listener attached", Attached, "");

      --  Finish detaches the server's own registration but not this one: it
      --  belongs to its owner. wlroots emits destroy on the backend, the extra
      --  handler runs and removes itself, and the process must survive.
      Iris.Server.Finish (Server);

      Expect ("process survived finish with a live listener", True, "");
      Expect ("server registration detached",
              not Is_Attached
                (Iris.Server_Callbacks.Backend_Destroy_Registration),
              "");

      Still_On := Is_Attached (Test_Extra_Listener.Extra_Registration);
      Expect ("extra listener removed itself", not Still_On, "");
      Expect ("extra handler ran once",
              Test_Extra_Listener.Call_Count = 1, "(calls 1)");
   end Check_Finish_With_Listener;

begin
   Ada.Text_IO.Put_Line ("iris_wm lifetime test");

   Check_Finish_Without_Start;
   Check_Double_Finish;
   Check_Finish_With_Listener;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("RESULT: PASS");
   else
      Ada.Text_IO.Put ("RESULT: FAIL (");
      Natural_IO.Put (Failures, Width => 1);
      Ada.Text_IO.Put_Line (" failing checks)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Lifetime_Test;
