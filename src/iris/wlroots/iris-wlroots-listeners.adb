with System;

package body Iris.Wlroots.Listeners is

   use type System.Address;

   ----------------------------------------------------------------------------
   --  Address helpers
   ----------------------------------------------------------------------------

   --  `'Address` yields System.Address, which is exactly Opaque_Pointer. These
   --  wrappers exist so the intent at each call site is visible rather than
   --  implied by a bare attribute reference.
   function Address_Of (Item : aliased Wl_Listener) return Opaque_Pointer is
      Result : constant Opaque_Pointer := Item'Address;
   begin
      return Result;
   end Address_Of;

   ----------------------------------------------------------------------------
   --  Signal operations
   ----------------------------------------------------------------------------

   procedure Signal_Init (Signal : aliased in out Wl_Signal) is
      List_Address : constant Opaque_Pointer := Signal.Listener_List'Address;
   begin
      --  wl_list_init makes both links point at the list head itself.
      Wl_List_Init (List_Address);
   end Signal_Init;

   procedure Signal_Add
     (Signal   : aliased in Wl_Signal;
      Listener : aliased in out Wl_Listener) is
      Tail_Address : constant Opaque_Pointer := Signal.Listener_List.Prev;
      Link_Address : constant Opaque_Pointer := Address_Of (Listener);
   begin
      --  Exactly wl_signal_add's body: insert at the tail of the signal's
      --  listener list, using the listener's link, which is its first member
      --  and therefore its own address.
      Wl_List_Insert (Tail_Address, Link_Address);
   end Signal_Add;

   function Listener_Count (Signal : aliased Wl_Signal) return Natural is
      List_Address : constant Opaque_Pointer := Signal.Listener_List'Address;
      Count        : constant C_Size := Wl_List_Length (List_Address);
      Result       : constant Natural := Natural (Count);
   begin
      return Result;
   end Listener_Count;

   ----------------------------------------------------------------------------
   --  Registration
   ----------------------------------------------------------------------------

   function Listener_Offset_Is_Zero return Boolean is
      Item    : aliased Registration;
      At_Zero : constant Boolean :=
        Item.Listener'Address = Item'Address;
   begin
      return At_Zero;
   end Listener_Offset_Is_Zero;

   procedure Prepare
     (Item    : aliased in out Registration;
      Handler : Notify_Procedure;
      Owner   : Opaque_Pointer) is
   begin
      --  The listener's own links are left as they are. They are overwritten
      --  by the insertion in Attach, and nothing reads them before then.
      Item.Listener.Notify := Handler;
      Item.Owner := Owner;
      Item.Attached := False;
   end Prepare;

   procedure Attach
     (Item   : aliased in out Registration;
      Signal : aliased Wl_Signal) is
   begin
      if Item.Attached then
         --  Already on a signal. Re-inserting would splice the same link into
         --  the list twice and corrupt it, so this is deliberately a no-op
         --  rather than an error: both a callback and a teardown path are
         --  allowed to ask for the same thing.
         return;
      end if;

      Signal_Add (Signal, Item.Listener);
      Item.Attached := True;
   end Attach;

   procedure Detach (Item : aliased in out Registration) is
      Link_Address : constant Opaque_Pointer := Address_Of (Item.Listener);
   begin
      if not Item.Attached then
         --  Never attached, or already removed. wl_list_remove on an element
         --  whose links are null is a null dereference, so this guard is what
         --  makes teardown idempotent.
         return;
      end if;

      Wl_List_Remove (Link_Address);
      Item.Attached := False;
   end Detach;

   function Is_Attached (Item : Registration) return Boolean is
      Result : constant Boolean := Item.Attached;
   begin
      return Result;
   end Is_Attached;

   function Owner_Of (Item : Registration) return Opaque_Pointer is
      Result : constant Opaque_Pointer := Item.Owner;
   begin
      return Result;
   end Owner_Of;

end Iris.Wlroots.Listeners;
