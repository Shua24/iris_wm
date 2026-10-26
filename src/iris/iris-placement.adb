--  iris-placement.adb
--  An implementation of iris-placement.ads

package body Iris.Placement with SPARK_Mode => On is
   function Place_Floating
      (Outputs : Output_List;
       Requested : Iris.Geometry.Rectangle) return Placement_Result
   is
   begin
      if Requested.Width = 0 or else Requested.Height = 0 then
         return (Status => Request_Too_Small);
      end if;

      for Index in Outputs'Range loop
         declare
            Output: constant Iris.Geometry.Rectangle := Outputs (Index);
         begin
            if Requested.Width <= Output.Width
               and then Requested.Height <= Output.Height
            then
               return (Status => Placed,
                       Bounds => (X      => Output.X,
                                  Y      => Output.Y,
                                  Width  => Requested.Width,
                                  Height => Requested.Height));
            end if;
         end;
      end loop;
      
      return (Status => No_Output);
   end Place_Floating;
end Iris.Placement;
