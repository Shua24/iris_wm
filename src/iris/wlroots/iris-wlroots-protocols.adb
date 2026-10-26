with Iris.Wlroots.Compositor;

package body Iris.Wlroots.Protocols is

   --  The raw imports live in the body because nothing outside this package
   --  should call them: they take a version argument, and the version is the
   --  one thing this package exists to fix in one place.

   function Xdg_Shell_Create
     (Display : Opaque_Pointer;
      Version : C_Unsigned) return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_xdg_shell_create";

   function Layer_Shell_Create
     (Display : Opaque_Pointer;
      Version : C_Unsigned) return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wlr_layer_shell_v1_create";

   function Data_Device_Create (Display : Opaque_Pointer)
                                return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wlr_data_device_manager_create";

   function Primary_Selection_Create (Display : Opaque_Pointer)
                                      return Opaque_Pointer
     with Import, Convention => C,
          External_Name =>
            "wlr_primary_selection_v1_device_manager_create";

   function Create_Compositor
     (Display  : Opaque_Pointer;
      Renderer : Opaque_Pointer) return Opaque_Pointer is
      Created : constant Opaque_Pointer :=
        Iris.Wlroots.Compositor.Create
          (Display, Compositor_Version, Renderer);
   begin
      return Created;
   end Create_Compositor;

   function Create_Subcompositor (Display : Opaque_Pointer)
                                  return Opaque_Pointer is
      Created : constant Opaque_Pointer :=
        Iris.Wlroots.Compositor.Create_Subcompositor (Display);
   begin
      return Created;
   end Create_Subcompositor;

   function Create_Xdg_Shell
     (Display : Opaque_Pointer) return Opaque_Pointer is
      Created : constant Opaque_Pointer :=
        Xdg_Shell_Create (Display, Xdg_Shell_Version);
   begin
      return Created;
   end Create_Xdg_Shell;

   function Create_Layer_Shell (Display : Opaque_Pointer)
                                return Opaque_Pointer is
      Created : constant Opaque_Pointer :=
        Layer_Shell_Create (Display, Layer_Shell_Version);
   begin
      return Created;
   end Create_Layer_Shell;

   function Create_Data_Device_Manager (Display : Opaque_Pointer)
                                        return Opaque_Pointer is
      Created : constant Opaque_Pointer := Data_Device_Create (Display);
   begin
      return Created;
   end Create_Data_Device_Manager;

   function Create_Primary_Selection (Display : Opaque_Pointer)
                                      return Opaque_Pointer is
      Created : constant Opaque_Pointer :=
        Primary_Selection_Create (Display);
   begin
      return Created;
   end Create_Primary_Selection;

end Iris.Wlroots.Protocols;
