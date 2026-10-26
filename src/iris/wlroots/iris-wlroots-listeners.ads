--  wl_list, wl_signal, wl_listener, and the one function that cannot be
--  imported.
--
--  This package exists because `wl_signal_add` is `static inline` in
--  wayland-server-core.h and therefore has no symbol to link against. It is
--  three lines of C that insert the listener's link at the tail of the
--  signal's listener list, and it is reimplemented here on top of
--  `wl_list_insert`, which *is* exported.
--
--  Everything else in this package is a struct mirror or a direct import.
--
--  The mirrors are layout-critical. Their sizes and offsets were proven
--  against C `offsetof` output (tests/c_layout_ground_truth.c) before any of
--  this was trusted: wl_list is 16 bytes, wl_listener is 24 with link at 0 and
--  notify at 16, wl_signal is 16 with listener_list at 0.
--
--  ---------------------------------------------------------------------------
--  Why removal state is tracked in Ada rather than read back from the list
--  ---------------------------------------------------------------------------
--
--  `wl_list_remove` NULLS the element's links; it does not leave the element
--  pointing at itself. Measured, not assumed: see tests/c_list_semantics.c,
--  which prints
--
--     first.link after remove      prev=NULL next=NULL empty=0
--     ...and then segfaults on a second remove.
--
--  Two consequences, both of which shape this package:
--
--    * `wl_list_empty` cannot be used to ask whether an element is attached.
--      It compares next against the element's own address, and NULL is not
--      that address, so a removed element reports "not empty".
--
--    * Removing an element twice is a null dereference, so an unconditional
--      Detach would turn a harmless double teardown into a crash during
--      shutdown.
--
--  Iris therefore keeps the attachment state in the Registration record and
--  calls `wl_list_remove` exactly once per successful Attach. The state is
--  never inferred from the C links, because after removal there is nothing
--  left in them to infer from.

with Iris.Wlroots.C_Types;

package Iris.Wlroots.Listeners is
   pragma Preelaborate;

   use Iris.Wlroots.C_Types;

   ----------------------------------------------------------------------------
   --  Struct mirrors
   ----------------------------------------------------------------------------

   --  struct wl_list { struct wl_list *prev; struct wl_list *next; };
   type Wl_List is record
      Prev : Opaque_Pointer;
      Next : Opaque_Pointer;
   end record;
   pragma Convention (C, Wl_List);

   --  The callback signature wlroots uses: the listener that fired, and the
   --  event-specific payload.
   type Notify_Procedure is
     access procedure (Listener : Opaque_Pointer; Data : Opaque_Pointer);
   pragma Convention (C, Notify_Procedure);

   --  struct wl_listener { struct wl_list link; wl_notify_func_t notify; };
   --
   --  `link` is the first member, and that fact is load bearing: see the
   --  container-of rule in the registration section below.
   type Wl_Listener is record
      Link   : aliased Wl_List;
      Notify : Notify_Procedure;
   end record;
   pragma Convention (C, Wl_Listener);

   --  struct wl_signal { struct wl_list listener_list; };
   type Wl_Signal is record
      Listener_List : aliased Wl_List;
   end record;
   pragma Convention (C, Wl_Signal);

   ----------------------------------------------------------------------------
   --  Exported list primitives
   ----------------------------------------------------------------------------

   --  Assumption: List is a valid, initialised struct wl_list. Initialise with
   --  Wl_List_Init before first use; wlroots does not define behaviour for an
   --  uninitialised list.
   procedure Wl_List_Init (List : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_list_init";

   --  Assumption: List is initialised and Element is not already a member of
   --  any list. Inserting a linked element corrupts both lists.
   procedure Wl_List_Insert (List : Opaque_Pointer; Element : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_list_insert";

   --  Assumption: Element is a member of a list. Removing it twice is a null
   --  dereference, because removal nulls the links; that is why this procedure
   --  is not called directly from outside this package.
   procedure Wl_List_Remove (Element : Opaque_Pointer)
     with Import, Convention => C, External_Name => "wl_list_remove";

   function Wl_List_Length (List : Opaque_Pointer) return C_Size
     with Import, Convention => C, External_Name => "wl_list_length";

   function Wl_List_Empty (List : Opaque_Pointer) return C_Boolean
     with Import, Convention => C, External_Name => "wl_list_empty";

   ----------------------------------------------------------------------------
   --  The reimplemented signal operations
   ----------------------------------------------------------------------------

   procedure Signal_Init (Signal : aliased in out Wl_Signal);
   --  Equivalent to wl_signal_init: an empty signal points at itself.

   procedure Signal_Add
     (Signal   : aliased in out Wl_Signal;
      Listener : aliased in out Wl_Listener);
   --  Equivalent to wl_signal_add, which cannot be linked:
   --     wl_list_insert (Signal.Listener_List.Prev, &Listener.Link);
   --  Assumption: Listener is not already attached to any signal. The caller
   --  keeps ownership of both objects; nothing is allocated. Prefer the
   --  Registration interface below, which enforces that assumption.

   function Listener_Count (Signal : aliased Wl_Signal) return Natural;
   --  Number of listeners currently attached. Note that an event signal on a
   --  freshly autocreated wlroots object is NOT empty: wlroots registers its
   --  own listeners during autocreate, so a count of one means "exactly one",
   --  never "none".

   ----------------------------------------------------------------------------
   --  Registration: the container-of convention, made mechanical
   ----------------------------------------------------------------------------

   --  Every callback target in Iris is a record whose FIRST component is the
   --  Wl_Listener it registers. C's wl_container_of subtracts a field offset
   --  to recover the enclosing struct; Ada has no such operator. With the
   --  listener first, the offset is zero and the pointer C passes as the first
   --  callback argument IS the record address, so no arithmetic is performed
   --  at run time.
   --
   --  A record that needs two listeners therefore holds two Registration
   --  values, never one listener plus offset arithmetic.
   --
   --  `Attached` is Iris's own bookkeeping and is the only trustworthy answer
   --  to "is this registration live", for the reason given in the header.
   type Registration is record
      Listener : aliased Wl_Listener;
      Owner    : Opaque_Pointer;
      Attached : Boolean;
   end record;

   --  The layout is pinned rather than left to the compiler, because the whole
   --  convention depends on Listener sitting at offset zero.
   for Registration use record
      Listener at 0 range 0 .. 191;
      Owner    at 24 range 0 .. 63;
      Attached at 32 range 0 .. 7;
   end record;

   function Listener_Offset_Is_Zero return Boolean;
   --  Runtime proof of the representation clause above. The binding probe
   --  asserts on it, so a future edit that breaks the convention fails a test
   --  instead of corrupting callbacks silently.

   procedure Prepare
     (Item    : aliased in out Registration;
      Handler : Notify_Procedure;
      Owner   : Opaque_Pointer);
   --  Fills in the callback and the owner tag, and puts the registration into
   --  the detached state. Does not attach.

   procedure Attach
     (Item   : aliased in out Registration;
      Signal : aliased in out Wl_Signal);
   --  Attaches if and only if the registration is currently detached. Calling
   --  it twice is a no-op rather than a list corruption, so a signal handler
   --  and a teardown path can both call it without coordinating.

   procedure Detach (Item : aliased in out Registration);
   --  Removes if and only if the registration is currently attached. Safe to
   --  call any number of times, including on a registration that was never
   --  attached. This is the call that a destroy handler must make on itself:
   --  wlroots asserts that a backend's destroy listener list is empty before
   --  it frees the backend, so a listener that stays registered turns a clean
   --  shutdown into an abort.

   function Is_Attached (Item : Registration) return Boolean;
   --  Whether this registration is currently on a signal.

   function Owner_Of (Item : Registration) return Opaque_Pointer;
   --  The owner tag, for callbacks that need to reach compositor state.

end Iris.Wlroots.Listeners;
