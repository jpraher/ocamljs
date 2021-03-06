(*
 * This file is part of ocamljs, OCaml to Javascript compiler
 * Copyright (C) 2007-9 Skydeck, Inc
 * Copyright (C) 2010 Jake Donham
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
 * MA 02111-1307, USA
 *)

module Gram = Camlp4.Struct.Grammar.Static.Make(Jslib_lexer)

open Jslib_lexer
open Jslib_ast

(* let mk_anti ?(c = "") n s = let x = "\\$"^n^c^":"^s in prerr_endline ("mk_anti " ^ x); x *)
let mk_anti ?(c = "") n s = "\\$"^n^c^":"^s

let test_lookahead_not_brace_function =
  Gram.Entry.of_parser "test_lookahead_not_brace_function"
    (fun strm ->
      match Stream.peek strm with
        | Some (KEYWORD "{", _)
        | Some (KEYWORD "function", _) -> raise Stream.Failure
        | _ -> ())

let non_exp_antiquots = ref true

let antiquot ns =
  Gram.Entry.of_parser "antiquot"
    (fun strm ->
       match Stream.peek strm with
         | Some (ANTIQUOT (n, s), _) when List.mem n ns && !non_exp_antiquots->
             Stream.junk strm;
             (n, s)
         | _ -> raise Stream.Failure)

(* annoying but there is no way to pass args to entries in rules *)
let antiquot_id = antiquot [""; "id"]
let antiquot_str = antiquot [""; "str"; "`str"]
let antiquot_int = antiquot [""; "int"; "`int"]
let antiquot_flo = antiquot [""; "flo"; "`flo"]
let antiquot_list = antiquot ["list"]
let antiquot_stmt = antiquot ["stmt"; ""; "anti"]

let expression = Gram.Entry.mk "expression"
let statementList = Gram.Entry.mk "statementList"
let program = Gram.Entry.mk "program"

let maybe_stmt_cons _loc s1 s2 =
  match s2 with
    | Jstmt_nil _ -> s1
    | _ -> Jstmt_cons (_loc, s1, s2)

;;

EXTEND Gram
  GLOBAL: expression statementList program;

a_IDENT: [[
  (n, s) = antiquot_id -> mk_anti n s (* not ' ? *)
| s = IDENT -> s
]];

a_STRING: [[
  (n, s) = antiquot_str -> mk_anti n s
| s = STRING -> s (* XXX ignores double-quote flag *)
]];

a_NUM: [[
  (n, s) = antiquot_int -> mk_anti n s
| (n, s) = antiquot_flo -> mk_anti n s
| s = INT -> s
| s = FLOAT -> s
| s = HEX -> string_of_int (int_of_string s) (* parse 0x etc.; XXX maybe should preserve hex? *)
]];

comma_expr: [[
  e1 = SELF; ","; e2 = SELF -> Jexp_cons (_loc, e1, e2)
| (n, s) = antiquot_list -> Jexp_Ant (_loc, mk_anti ~c:"exp" n s)
| e = expression LEVEL "AssignmentExpression" -> e
| -> Jexp_nil _loc
]];

(* A.3 Expressions *)
expression: [
  "Expression" LEFTA
    [ e1 = expression; ","; e2 = expression -> Jbinop (_loc, Jcomma, e1, e2) ]
| "AssignmentExpression" RIGHTA [
    e1 = expression;
    op = [
      "=" -> Jassign
    | "*=" -> Jmul_assign
    | "/=" -> Jdiv_assign
    | "%=" -> Jmod_assign
    | "+=" -> Jadd_assign
    | "-=" -> Jsub_assign
    | "<<=" -> Jlsl_assign
    | ">>=" -> Jlsr_assign
    | ">>>=" -> Jasr_assign
    | "&=" -> Jand_assign
    | "^=" -> Jxor_assign
    | "|=" -> Jor_assign
    ];
    e2 = expression -> Jbinop (_loc, op, e1, e2)
]
| "ConditionalExpression" RIGHTA
    [ e1 = expression; "?"; e2 = expression; ":"; e3 = expression -> Jite (_loc, e1, e2, e3) ]
| "LogicalORExpression" LEFTA
    [ e1 = expression; "||"; e2 = expression -> Jbinop (_loc, Jlor, e1, e2) ]
| "LogicalANDExpression" LEFTA
    [ e1 = expression; "&&"; e2 = expression -> Jbinop (_loc, Jland, e1, e2) ]
| "BitwiseORExpression" LEFTA
    [ e1 = expression; "|"; e2 = expression -> Jbinop (_loc, Jor, e1, e2) ]
| "BitwiseXORExpression" LEFTA
    [ e1 = expression; "^"; e2 = expression -> Jbinop (_loc, Jxor, e1, e2) ]
| "BitwiseANDExpression" LEFTA
    [ e1 = expression; "&"; e2 = expression -> Jbinop (_loc, Jand, e1, e2) ]
| "EqualityExpression" LEFTA [
    e1 = expression;
    op = [
      "==" -> Jeq
    | "!=" -> Jneq
    | "===" -> Jseq
    | "!==" -> Jsneq
    ];
    e2 = expression -> Jbinop (_loc, op, e1, e2)
  ]
| "RelationalExpression" LEFTA [
    e1 = expression;
    op = [
      "<" -> Jlt
    | ">" -> Jgt
    | "<=" -> Jleq
    | ">=" -> Jgeq
    | "instanceof" -> Jinstanceof
    ];
    e2 = expression -> Jbinop (_loc, op, e1, e2)
  ]
| "ShiftExpression" LEFTA [
    e1 = expression;
    op = [
      "<<" -> Jlsl
    | ">>" -> Jlsr
    | ">>>" -> Jasr
    ];
    e2 = expression -> Jbinop (_loc, op, e1, e2)
  ]
| "AdditiveExpression" LEFTA [
    e1 = expression;
    op = [
      "+" -> Jadd
    | "-" -> Jsub
    ];
    e2 = expression -> Jbinop (_loc, op, e1, e2)
  ]
| "MultiplicativeExpression" LEFTA [
    e1 = expression;
    op = [
      "*" -> Jmul
    | "/" -> Jdiv
    | "%" -> Jmod
    ];
    e2 = expression -> Jbinop (_loc, op, e1, e2)
  ]
| "UnaryExpression" [
    op = [
      "delete" -> Jdelete
    | "void" -> Jvoid
    | "typeof" -> Jtypeof
    | "++" -> Jadd2_pre
    | "--" -> Jsub2_pre
    | "+" -> Jadd_pre
    | "-" -> Jsub_pre
    | "~" -> Jtilde
    | "!" -> Jnot
    ];
    e = expression -> Junop (_loc, op, e)
  ]
| "PostfixExpression" [
    e = expression;
    op = [
      "++" -> Jadd2_post
    | "--" -> Jsub2_post
    ] -> Junop (_loc, op, e)
  ]
| "CallExpression" LEFTA [
    e1 = expression; "["; e2 = expression; "]" -> Jbinop (_loc, Jhashref, e1, e2)
  | e = expression; "."; i = a_IDENT -> Jfieldref (_loc, e, i)
  | e = expression (* LEVEL "MemberExpression" ?? *); "("; args = comma_expr; ")" -> Jcall (_loc, e, args)
  ]
| "MemberExpression" LEFTA [
    e1 = expression; "["; e2 = expression; "]" -> Jbinop (_loc, Jhashref, e1, e2)
  | e = expression; "."; i = a_IDENT -> Jfieldref (_loc, e, i)
  | "new"; e = expression LEVEL "MemberExpression"; args = OPT [ "("; args = comma_expr; ")" -> args ] -> Jnew (_loc, e, args)
  | "function"; i = OPT a_IDENT;
    "("; args = LIST0 a_IDENT SEP ","; ")";
    "{"; ss = sourceElements; "}" -> Jfun (_loc, i, args, ss)
  ]
| "PrimaryExpression" NONA [
    `ANTIQUOT ("exp"|""|"anti" as n, s) -> Jexp_Ant (_loc, mk_anti ~c:"exp" n s)
  | i = a_NUM -> Jnum (_loc, i)
  | s = a_STRING -> Jstring (_loc, s, true)
  | v = a_IDENT -> Jvar (_loc, v)
  | r = REGEXP -> Jregexp (_loc, r, "")
  | "this" -> Jthis (_loc)
  | "null" -> Jnull (_loc)
  | "true" -> Jbool (_loc, true)
  | "false" -> Jbool (_loc, false)
  | "["; es = comma_expr; "]" -> Jarray (_loc, es)
  | "{"; kvs = LIST0 [ k = expression; ":"; v = expression LEVEL "AssignmentExpression" -> (k, v) ] SEP ","; "}" -> Jobject (_loc, kvs)
  | "("; e = expression; ")" -> e
  ]
];

variableDeclarationList: [[
  LIST1
    [ i = a_IDENT; e = OPT [ "="; e = expression LEVEL "AssignmentExpression" -> e ] -> (i, e) ]
    SEP ","
]];

(* A.4 Statements *)
statement: [[
  (n, s) = antiquot_stmt -> Jstmt_Ant (_loc, mk_anti ~c:"stmt" n s)
| ss = block -> Jblock (_loc, ss)
| "var"; vars = variableDeclarationList; ";" -> Jvars (_loc, vars)
| ";" -> Jstmt_nil (_loc)
| test_lookahead_not_brace_function; e = expression; ";" -> Jexps (_loc, e)
| "if"; "("; e = expression; ")"; s1 = statement; "else"; s2 = statement -> Jites(_loc, e, s1, Some s2)
| "if"; "("; e = expression; ")"; s1 = statement -> Jites(_loc, e, s1, None)
| "do"; s = statement; "while"; "("; e = expression; ")"; ";" -> Jdowhile (_loc, s, e)
| "while"; "("; e = expression; ")"; s = statement -> Jwhile (_loc, e, s)
| "for"; "("; "var"; vars = variableDeclarationList; ";"; e2 = OPT expression; ";"; e3 = OPT expression; ")"; s = statement ->
    Jfor (_loc, vars, None, e2, e3, s)
| "for"; "("; e1 = OPT expression; ";"; e2 = OPT expression; ";"; e3 = OPT expression; ")"; s = statement ->
    Jfor (_loc, [], e1, e2, e3, s)
| "continue"; i = OPT a_IDENT; ";" -> Jcontinue (_loc, i)
| "break"; i = OPT a_IDENT; ";" -> Jbreak (_loc, i)
| "return"; e = OPT expression; ";" -> Jreturn (_loc, e)
| "with"; "("; e = expression; ")"; s = statement -> Jwith(_loc, e, s)
| "switch"; "("; e = expression; ")"; "{";
    (cs, d) = [
      cs = LIST0 caseClause -> (cs, Jstmt_nil _loc)
    | cs1 = LIST0 caseClause; "default"; ":"; ss = statementList; cs2 = LIST0 caseClause -> (cs1 @ cs2, ss)
    ];
    "}" -> Jswitch(_loc, e, cs, d)
| i = a_IDENT; ":"; s = statement -> Jlabel(_loc, i, s)
| "throw"; e = expression; ";" -> Jthrow(_loc, e)
| "try"; ss = block; "catch"; "("; ci = a_IDENT; ")"; css = block ->
    Jtrycatch(_loc, ss, Some (ci, css), Jstmt_nil _loc)
| "try"; ss = block; "finally"; fss = block ->
    Jtrycatch(_loc, ss, None, fss)
| "try"; ss = block; "catch"; "("; ci = a_IDENT; ")"; css = block; "finally"; fss = block ->
    Jtrycatch(_loc, ss, Some (ci, css), fss)
]];

statementList: [[
  (n, s) = antiquot_list; s2 = SELF ->
    maybe_stmt_cons _loc (Jstmt_Ant (_loc, mk_anti ~c:"stmt" n s)) s2
| s1 = statement; s2 = SELF -> maybe_stmt_cons _loc s1 s2
| -> Jstmt_nil _loc
]];

block: [[ "{"; ss = statementList; "}" -> ss ]];
caseClause: [[ "case"; e = expression; ":"; ss = statementList -> (e, ss) ]];

(* A.5 Functions and Programs *)
program: [[ p = sourceElements -> p ]];

sourceElement: [[
  "function"; i = a_IDENT;
  "("; args = LIST0 a_IDENT SEP ","; ")";
  "{"; ss = sourceElements; "}" -> Jfuns(_loc, i, args, ss)
| s = statement -> s
]];

sourceElements: [[
  (n, s) = antiquot_list; s2 = SELF ->
    maybe_stmt_cons _loc (Jstmt_Ant (_loc, mk_anti ~c:"stmt" n s)) s2
| s1 = sourceElement; s2 = SELF -> maybe_stmt_cons _loc s1 s2
| -> Jstmt_nil _loc
]];

END

let parse_file fn =
  let ch = open_in fn in
  Gram.parse program (Loc.mk fn) (Stream.of_channel ch)

let parse_stdin () =
  Gram.parse program (Loc.mk "<stdin>") (Stream.of_channel stdin)

let parse_string s =
  Gram.parse_string program (Loc.mk "<string>") s
