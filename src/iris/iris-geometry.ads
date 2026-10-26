--  iris-geometry.ads
--  Used to specify the window geometry.
--  It's SPARK code, so no agents
--  shall touch it. Suggestions by
--  agents are fine.

--  The numbers here are based on the
--  16-bit integers.

package Iris.Geometry with SPARK_Mode => On is
   pragma Pure;

   MAXIMUM_COORDINATE : constant := 65_535;
   MAXIMUM_DIMENSION  : constant := 16_384;
  
   --  Coordinates are based on
   --  the cartesian coordinates
   --  therefore it can be
   --  negative or positive,
   --  as it describes positions.
   subtype Coordinate is Integer
      range -MAXIMUM_COORDINATE .. MAXIMUM_COORDINATE;

   --  Dimensions cannot be
   --  negative, therefore
   --  `Positive` is used
   --  here. This subtype
   --  defines windows
   --  that may appear.
   subtype Dimension is Positive range 1 .. MAXIMUM_DIMENSION;

   --  Dimensions can be 0 in the windowing
   --  domain because of the properties
   --  of a stacking window manager
   subtype Dimension_Extent is Integer range 0 .. MAXIMUM_DIMENSION;

   --  Windows shall have its coordinate
   --  positions along with its width and height.
   type Rectangle is record
      X      : Coordinate;
      Y      : Coordinate;
      Width  : Dimension_Extent;
      Height : Dimension_Extent;
   end record;

   --  This function returns true when Inner
   --  window is within Outer window
   --  Edges are included.
   function Contains (Outer : Rectangle; Inner : Rectangle) return Boolean
   with Post =>
   (Contains'Result =
        (Inner.X >= Outer.X
         and then Inner.Y >= Outer.Y
         and then Inner.X + Inner.Width <= Outer.X + Outer.Width
         and then Inner.Y + Inner.Height <= Outer.Y + Outer.Height));

   --  This function returns `true` if
   --  the window is overlapping for
   --  both the left and/or right
   --  side.
   function Overlaps (Left : Rectangle; Right : Rectangle) return Boolean
   with Post =>
     (Overlaps'Result =
        (Left.X < Right.X + Right.Width
         and then Right.X < Left.X + Left.Width
         and then Left.Y < Right.Y + Right.Height
         and then Right.Y < Left.Y + Left.Height));
end Iris.Geometry;
