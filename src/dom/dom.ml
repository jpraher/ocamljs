type interval_id
type timeout_id

class type window =
object
  method _set_onload : (unit -> unit) Ocamljs.jsfun -> unit

  method setInterval : (unit -> unit) Ocamljs.jsfun -> float -> interval_id
  method clearInterval : interval_id -> unit

  method setTimeout : (unit -> unit) Ocamljs.jsfun -> float -> timeout_id
  method clearTimeout : timeout_id -> unit
end

class type document =
object
  method getElementById : string -> < ..>
end

class type element =
object
  method _set_innerHTML : string -> unit
end

class type span =
object
  inherit element
end

class type button =
object
  inherit element
  method _set_onclick : (unit -> unit) Ocamljs.jsfun -> unit
end

(* FireBug console *)
class type console =
object
  method log : string -> unit
end

let window = (Ocamljs.var "window" : window)
let document = (Ocamljs.var "document" : document)
let console = (Ocamljs.var "console" : console)