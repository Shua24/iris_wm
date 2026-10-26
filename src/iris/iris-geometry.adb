--  iris-geometry.adb
--  An implementation for iris-geometry.ads

package body Iris.Geometry with SPARK_Mode => On is

   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean is
   begin
      return Inner.X >= Outer.X
         and then Inner.Y >= Outer.Y
         and then Inner.X + Inner.Width <= Outer.X + Outer.Width
         and then Inner.Y + Inner.Height <= Outer.Y + Outer.Height;
   end Contains;

   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean is
   begin
      return Left.X < Right.X + Right.Width
         and then Right.X < Left.X + Left.Width
         and then Left.Y < Right.Y + Right.Height
         and then Right.Y < Left.Y + Left.Height;
   end Overlaps;
end Iris.Geometry;
