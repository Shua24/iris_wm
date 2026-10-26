with Ada.Command_Line;
with Ada.Text_IO;

with Probe_Callbacks;

with Iris.Wlroots.Backend;
with Iris.Wlroots.C_Types;
with Iris.Wlroots.Display;
with Iris.Wlroots.Listeners;

procedure Binding_Probe is

   use Iris.Wlroots.C_Types;
   use Iris.Wlroots.Listeners;

   package Natural_IO is new Ada.Text_IO.Integer_IO (Natural);

   Failures : Natural := 0;

   ---------------------------------------------------------------------------
   --  Reporting
   ---------------------------------------------------------------------------

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
   --  Section 1: struct mirrors
   ---------------------------------------------------------------------------

   procedure Check_Layouts is
      List_Size      : constant Natural := Wl_List'Size / 8;
      Listener_Size  : constant Natural := Wl_Listener'Size / 8;
      Signal_Size    : constant Natural := Wl_Signal'Size / 8;
      Backend_Size   : constant Natural :=
        Iris.Wlroots.Backend.Backend'Size / 8;
      Listener_First : constant Boolean := Listener_Offset_Is_Zero;
   begin
      Ada.Text_IO.Put_Line
        ("--  struct mirrors, for diffing against the C ground truth");

      Show ("sizeof wl_list     ", List_Size);
      Show ("sizeof wl_listener ", Listener_Size);
      Show ("sizeof wl_signal   ", Signal_Size);
      Show ("sizeof wlr_backend ", Backend_Size);

      Expect ("wl_list size", List_Size = 16, "(C: 16)");
      Expect ("wl_listener size", Listener_Size = 24, "(C: 24)");
      Expect ("wl_signal size", Signal_Size = 16, "(C: 16)");
      Expect ("wlr_backend size", Backend_Size = 64, "(C: 64)");

      --  The container-of convention depends on this and nothing else. If it
      --  ever stops holding, every callback in the compositor is reading the
      --  wrong record, so it is checked rather than commented on.
      Expect ("listener is first in Registration", Listener_First,
              "(offset 0)");
   end Check_Layouts;

   ---------------------------------------------------------------------------
   --  Section 2: list primitives behave
   ---------------------------------------------------------------------------

   procedure Check_Lists is
      Signal_Value    : aliased Wl_Signal;
      First           : aliased Registration;
      Second          : aliased Registration;
      Empty_At_Start  : Boolean;
      Count_One       : Natural;
      Count_Two       : Natural;
      Count_After     : Natural;
      Count_After_All : Natural;
      First_Attached  : Boolean;
      First_After     : Boolean;
   begin
      Signal_Init (Signal_Value);

      Empty_At_Start := Listener_Count (Signal_Value) = 0;

      Prepare (First, null, No_Pointer);
      Attach (First, Signal_Value);
      Count_One := Listener_Count (Signal_Value);
      First_Attached := Is_Attached (First);

      Prepare (Second, null, No_Pointer);
      Attach (Second, Signal_Value);
      Count_Two := Listener_Count (Signal_Value);

      Detach (First);
      First_After := Is_Attached (First);
      Count_After := Listener_Count (Signal_Value);

      Expect ("signal starts empty", Empty_At_Start, "(count 0)");
      Expect ("one listener attached", Count_One = 1, "(count 1)");
      Expect ("registration reports attached", First_Attached, "");
      Expect ("two listeners attached", Count_Two = 2, "(count 2)");
      Expect ("detach clears attached", not First_After, "");
      Expect ("detach decrements", Count_After = 1, "(count 1)");

      --  Double detach must be a no-op. This is not cosmetic: measured C
      --  behaviour is that wl_list_remove nulls the links and a second remove
      --  segfaults, so without this guard teardown paths crash on exit.
      Detach (First);
      Expect ("double detach is safe",
              Listener_Count (Signal_Value) = 1, "(count 1)");

      --  Double attach must also be a no-op, for the mirror-image reason:
      --  inserting the same link twice corrupts the signal's list.
      Attach (First, Signal_Value);
      Expect ("re-attach is a no-op",
              Listener_Count (Signal_Value) = 2, "(count 2)");

      Detach (First);
      Detach (Second);
      Count_After_All := Listener_Count (Signal_Value);
      Expect ("detaching everything empties the signal",
              Count_After_All = 0, "(count 0)");
   end Check_Lists;

   ---------------------------------------------------------------------------
   --  Section 3: display and backend, through the binding
   ---------------------------------------------------------------------------

   procedure Check_Backend is
      Display_Value   : Opaque_Pointer := No_Pointer;
      Backend_Value   : Opaque_Pointer := No_Pointer;
      Event_Loop      : Opaque_Pointer;
      Backend_Signals : access Iris.Wlroots.Backend.Backend;
      Created         : Boolean;
      Loop_Ready      : Boolean;
      Backend_Ready   : Boolean;
      Started         : C_Boolean;
      Started_Boolean : Boolean;
      Own_Listeners   : Natural;
      After_Attach    : Natural;
   begin
      Display_Value := Iris.Wlroots.Display.Create;
      Created := not Is_Null (Display_Value);
      Expect ("wl_display_create", Created, "");

      if not Created then
         return;
      end if;

      Event_Loop := Iris.Wlroots.Display.Get_Event_Loop (Display_Value);
      Loop_Ready := not Is_Null (Event_Loop);
      Expect ("wl_display_get_event_loop", Loop_Ready, "");

      if not Loop_Ready then
         return;
      end if;

      Backend_Value := Iris.Wlroots.Backend.Autocreate
        (Event_Loop, No_Pointer);
      Backend_Ready := not Is_Null (Backend_Value);
      Expect ("wlr_backend_autocreate", Backend_Ready, "");

      if not Backend_Ready then
         return;
      end if;

      Backend_Signals := Iris.Wlroots.Backend.As_Backend (Backend_Value);

      --  wlroots registers its own listener during autocreate, so this signal
      --  is expected to hold exactly one entry. prev == next would mean one,
      --  not zero: an event signal is not self-referential after autocreate.
      Own_Listeners := Listener_Count (Backend_Signals.Events.Destroy);
      Show ("listeners on backend.events.destroy at autocreate ",
            Own_Listeners);

      Prepare (Probe_Callbacks.Backend_Destroy_Registration,
               Probe_Callbacks.On_Backend_Destroy'Access,
               Backend_Value);
      Attach (Probe_Callbacks.Backend_Destroy_Registration,
              Backend_Signals.Events.Destroy);

      After_Attach := Listener_Count (Backend_Signals.Events.Destroy);
      Expect ("destroy listener attached", After_Attach = Own_Listeners + 1,
              "(count grew by one)");

      Started := Iris.Wlroots.Backend.Start (Backend_Value);
      Started_Boolean := To_Boolean (Started);
      Expect ("wlr_backend_start", Started_Boolean, "");

      --  Destroying the backend raises events.destroy, which runs our handler.
      --  The handler removes itself, which is what allows wlr_backend_finish's
      --  assertion that the listener list is empty to hold.
      Iris.Wlroots.Backend.Destroy (Backend_Value);
      Backend_Value := No_Pointer;

      Expect ("destroy handler ran",
              Probe_Callbacks.Destroy_Callback_Count = 1, "(calls 1)");
      Expect ("destroy listener removed itself",
              not Probe_Callbacks.Self_Remove_Failed, "");

      Iris.Wlroots.Display.Destroy_Clients (Display_Value);
      Iris.Wlroots.Display.Destroy (Display_Value);
   end Check_Backend;

begin
   Ada.Text_IO.Put_Line ("iris_wm binding probe");

   Check_Layouts;
   Check_Lists;
   Check_Backend;

   if Failures = 0 then
      Ada.Text_IO.Put_Line ("RESULT: PASS");
   else
      Ada.Text_IO.Put ("RESULT: FAIL (");
      Natural_IO.Put (Failures, Width => 1);
      Ada.Text_IO.Put_Line (" failing checks)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Binding_Probe;
