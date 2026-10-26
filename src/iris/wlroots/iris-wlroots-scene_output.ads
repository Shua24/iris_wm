--  wlr_scene_output: one output's place in the scene graph.
--
--  Only two members are mirrored: the output handle and the x/y position the
--  scene output reports. Everything after `events` is WLR_PRIVATE, which is a
--  compile-time-private tail member with no layout guarantee across versions.
--  Reading it from Ada would be ABI-fragile for no benefit, so Iris does not.
--
--  The layout below was proven against C `offsetof` before use; the probe
--  prints the Ada-side numbers so they can be diffed against the C ground
--  truth in tests/c_layout_ground_truth.c.

with Iris.Wlroots.C_Types;
with Iris.Wlroots.Listeners;

package Iris.Wlroots.Scene_Output is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   type Scene_Output is record
      Output : Opaque_Pointer;
      Link   : Iris.Wlroots.Listeners.Wl_List;
      Scene  : Opaque_Pointer;
      Addon  : Opaque_Pointer;
      X      : C_Int;
      Y      : C_Int;
   end record;
   pragma Convention (C, Scene_Output);
   --  Assumption: the mirrored prefix above matches struct wlr_scene_output.
   --  wlr_damage_ring is not mirrored because nothing in v0 reads it, and a
   --  partial mirror that stops before the members it needs is safe; one that
   --  skips a member in the middle is not.

   function As_Scene_Output
     (Value : Opaque_Pointer) return access Scene_Output;

   --  Assumption: Scene came from Scene_Create and Output is a live output
   --  belonging to the attached layout. Returns the scene output handle, or
   --  null if the output is already in the scene.
   function Add_Output
     (Scene          : Opaque_Pointer;
      Scene_Layout   : Opaque_Pointer;
      Output         : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wlr_scene_output_layout_add_output";

   --  Assumption: Scene_Output_Value came from Add_Output and has not been
   --  removed. Commits a frame for that output: this is the call that turns
   --  scene damage into an actual buffer swap.
   function Commit (Scene_Output_Value : Opaque_Pointer) return C_Boolean
     with Import, Convention => C,
          External_Name => "wlr_scene_output_commit";

   --  Assumption: Scene_Output_Value came from Add_Output. Schedules a frame
   --  for the next refresh.
   function Schedule_Frame
     (Scene_Output_Value : Opaque_Pointer) return C_Boolean
     with Import, Convention => C,
          External_Name => "wlr_scene_output_schedule_frame";

end Iris.Wlroots.Scene_Output;
