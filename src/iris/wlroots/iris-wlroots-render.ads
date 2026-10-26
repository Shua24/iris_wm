--  The renderer, the allocator, and the scene graph.
--
--  These three are the rendering path. The renderer turns pixels into
--  something the backend can put on an output; the allocator creates the
--  buffers that happens in; the scene graph owns render order, damage tracking
--  and surface hit-testing.
--
--  Iris does not write a renderer. `wlr_scene` is the whole reason this
--  project can be about window management rather than about rasterisation, and
--  the scene graph is delegated to completely.

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Render is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   ----------------------------------------------------------------------------
   --  Renderer
   ----------------------------------------------------------------------------

   --  Assumption: Backend is a live backend that has not been destroyed.
   --  Picks Pixman, GLES2 or Vulkan, or whatever WLR_RENDERER names. Returns
   --  null on failure, and every caller must treat null as fatal: a compositor
   --  with no renderer cannot present anything.
   function Renderer_Autocreate
     (Backend : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wlr_renderer_autocreate";

   --  Assumption: Renderer and Display are both live. Publishes the shared
   --  memory formats the renderer supports as wl_shm globals, which is what
   --  lets clients send buffers at all. Returns C false on failure.
   function Init_Shared_Memory
     (Renderer : Opaque_Pointer;
      Display  : Opaque_Pointer) return C_Boolean
     with Import, Convention => C, External_Name => "wlr_renderer_init_wl_shm";

   --  Assumption: Renderer came from Renderer_Autocreate and the scene and
   --  allocator built on it are already gone. Destroying it earlier leaves the
   --  scene holding a dangling pointer.
   procedure Renderer_Destroy (Renderer : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wlr_renderer_destroy";

   --  Assumption: Renderer is live. Returns -1 when there is no DRM node,
   --  which is the normal case for the X11 and headless backends.
   function Renderer_Drm_File_Descriptor
     (Renderer : Opaque_Pointer) return C_Int
     with Import, Convention => C, External_Name => "wlr_renderer_get_drm_fd";

   ----------------------------------------------------------------------------
   --  Allocator
   ----------------------------------------------------------------------------

   --  Assumption: Backend and Renderer are both live and belong to each other.
   --  Returns null on failure.
   function Allocator_Autocreate
     (Backend  : Opaque_Pointer;
      Renderer : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_allocator_autocreate";

   --  Assumption: Allocator came from Allocator_Autocreate and nothing holds
   --  buffers it created.
   procedure Allocator_Destroy (Allocator : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wlr_allocator_destroy";

   ----------------------------------------------------------------------------
   --  Scene
   ----------------------------------------------------------------------------

   --  Assumption: none. Returns null only if allocation fails.
   function Scene_Create return Opaque_Pointer
     with Import, Convention => C, External_Name => "wlr_scene_create";

   --  Assumption: Scene is live. Destroys the scene's root node and, with it,
   --  every node attached below. Outputs must be detached from the layout
   --  first, or their scene output nodes are destroyed underneath them.
   procedure Scene_Destroy (Scene : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wlr_scene_node_destroy";

   --  Assumption: Scene and Layout are both live. Associates the scene graph
   --  with the output layout so the scene knows which output each output node
   --  belongs to. Returns a handle used to add individual outputs.
   function Scene_Attach_Output_Layout
     (Scene  : Opaque_Pointer;
      Layout : Opaque_Pointer) return Opaque_Pointer
     with Import, Convention => C,
          External_Name => "wlr_scene_attach_output_layout";

end Iris.Wlroots.Render;
