open OUnit

class virtual abstract_point x_init =
object (self)
  method virtual get_x : int
  method get_offset = self#get_x - x_init
  method virtual move : int -> unit
end

class point x_init =
object
  inherit abstract_point x_init
  val mutable x = x_init
  method get_x = x
  method move d = x <- x + d
end

class virtual abstract_point2 =
object
  val mutable virtual x : int
  method move d = x <- x + d
end

class point2 x_init =
object
  inherit abstract_point2
  val mutable x = x_init
  method get_offset = x - x_init
end

let tests = "Oo_virtual" >:: begin fun () ->
  let p = new point 7 in
  assert_equal p#get_offset 0;
  p#move 10;
  assert_equal p#get_offset 10;

  let p2 = new point2 7 in
  assert_equal p2#get_offset 0;
  p2#move 10;
  assert_equal p2#get_offset 10;
end
