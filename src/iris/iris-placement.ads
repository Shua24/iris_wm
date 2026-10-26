--  iris-placement.ads
--  This is used to govern window placements.

with Iris.Geometry;

package Iris.Placement with SPARK_Mode => On is
   pragma Pure;

   --  This constraint exists so that the number
   --  of windows are limited to around 512.
   --  This is because it is better to have a
   --  soft limit than relying on the hard
   --  limit for windows. It prevents
   --  the hardware itself from limiting
   --  the number of windows.
   MAXIMUM_NUMBER_OF_CLIENTS : constant := 512;

   subtype Client_Index is Positive range 1 .. MAXIMUM_NUMBER_OF_CLIENTS;

   --  Output_List is an array of windows.
   --  The constraint here is not applied anymore
   --  because if it's applied here, that will
   --  make it a fixed-length array.
   type Output_List is array (Client_Index range <>)
      of Iris.Geometry.Rectangle;

   --  Placement_Status represents
   --  the status tyoes a window can
   --  use.
   type Placement_Status is (
      Placed,
      No_Output,
      Request_Too_Small);

   --  This record tells what
   --  to do on windows
   --  based on the status.
   type Placement_Result (Status : Placement_Status := No_Output) is record
      case Status is
         when Placed =>
            Bounds : Iris.Geometry.Rectangle;
         when others => null;
      end case;
   end record;

   --  This function
   --  represents the
   --  floating window
   --  policy.
   function Place_Floating
      (Outputs : Output_List;
      Requested : Iris.Geometry.Rectangle) return Placement_Result
   with Post =>
      (if Place_Floating'Result.Status = Request_Too_Small
       then Requested.Width = 0 or else Requested.Height = 0)
      and then
      (if Requested.Width = 0 or else Requested.Height = 0
       then Place_Floating'Result.Status /= Placed)
      and then
      (if Place_Floating'Result.Status = Placed
       then (for some Index in Outputs'Range =>
               Place_Floating'Result.Bounds.Width <= Outputs (Index).Width
               and then
               Place_Floating'Result.Bounds.Height <= Outputs (Index).Height));
end Iris.Placement;
