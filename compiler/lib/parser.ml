open Printf
open Lexer

type expression =
  | Constant of int

type statement =
  | Return of expression

type function_definition = {
  return_type: string;
  name: string;
  parameters: string list;
  body: statement list;
}

type program = function_definition

exception ParseError of string

let parse_error msg = raise (ParseError msg)

let expect_token expected_token tokens =
  match tokens with
  | [] -> parse_error (sprintf "Expected %s but reached end of input" (token_to_string expected_token))
  | token :: rest when token = expected_token -> rest
  | token :: _ -> parse_error (sprintf "Expected %s but got %s" (token_to_string expected_token) (token_to_string token))

let parse_expression tokens =
  match tokens with
  | Lexer.Constant value :: rest -> (Constant value, rest)
  | token :: _ -> parse_error (sprintf "Expected expression but got %s" (token_to_string token))
  | [] -> parse_error "Expected expression but reached end of input"

let parse_statement tokens =
  match tokens with
  | Lexer.Return :: rest ->
      let (expr, rest') = parse_expression rest in
      let rest'' = expect_token Lexer.Semicolon rest' in
      (Return expr, rest'')
  | token :: _ -> parse_error (sprintf "Expected statement but got %s" (token_to_string token))
  | [] -> parse_error "Expected statement but reached end of input"

let parse_parameter_list tokens =
  match tokens with
  | Lexer.Void :: rest -> ([], rest)
  | _ -> parse_error "Only void parameter lists are supported for now"

let parse_function tokens =
  match tokens with
  | Lexer.Int :: Lexer.Identifier name :: Lexer.OpenParen :: rest ->
      let (params, rest') = parse_parameter_list rest in
      let rest'' = expect_token Lexer.CloseParen rest' in
      let rest''' = expect_token Lexer.OpenBrace rest'' in
      let (stmt, rest'''') = parse_statement rest''' in
      let rest''''' = expect_token Lexer.CloseBrace rest'''' in
      let _ = expect_token Lexer.EOF rest''''' in
      {
        return_type = "int";
        name = name;
        parameters = params;
        body = [stmt];
      }
  | token :: _ -> parse_error (sprintf "Expected function definition but got %s" (token_to_string token))
  | [] -> parse_error "Expected function definition but reached end of input"

let parse tokens =
  try
    Ok (parse_function tokens)
  with
  | ParseError msg -> Error msg

let print_expression = function
  | Constant value -> sprintf "Constant(%d)" value

let print_statement = function
  | Return expr -> sprintf "Return(%s)" (print_expression expr)

let print_function func =
  printf "Function: %s %s(%s) {\n" 
    func.return_type 
    func.name 
    (String.concat ", " func.parameters);
  List.iter (fun stmt -> printf "  %s\n" (print_statement stmt)) func.body;
  printf "}\n"

let print_program prog =
  print_function prog

(* Pretty-printer functions for debugging *)
let pretty_print_expression indent expr =
  let spaces = String.make indent ' ' in
  match expr with
  | Constant value -> sprintf "%sConstant(%d)" spaces value

let pretty_print_statement indent stmt =
  let spaces = String.make indent ' ' in
  match stmt with
  | Return expr -> 
      sprintf "%sReturn(\n%s\n%s)" 
        spaces 
        (pretty_print_expression (indent + 2) expr) 
        spaces

let pretty_print_function indent func =
  let spaces = String.make indent ' ' in
  let body_str = String.concat ",\n" 
    (List.map (pretty_print_statement (indent + 2)) func.body) in
  sprintf "%sFunction(\n%s  name=\"%s\",\n%s  body=%s\n%s)" 
    spaces 
    spaces 
    func.name 
    spaces 
    body_str 
    spaces

let pretty_print_program prog =
  sprintf "Program(\n%s\n)" (pretty_print_function 2 prog)

let print_pretty_program prog =
  printf "%s\n" (pretty_print_program prog)
