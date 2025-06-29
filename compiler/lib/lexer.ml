open Printf

type token =
  | Identifier of string
  | Constant of int
  | Int
  | Void
  | Return
  | OpenParen
  | CloseParen
  | OpenBrace
  | CloseBrace
  | Semicolon
  | EOF

let token_to_string = function
  | Identifier s -> sprintf "Identifier(%s)" s
  | Constant i -> sprintf "Constant(%d)" i
  | Int -> "Int"
  | Void -> "Void"
  | Return -> "Return"
  | OpenParen -> "OpenParen"
  | CloseParen -> "CloseParen"
  | OpenBrace -> "OpenBrace"
  | CloseBrace -> "CloseBrace"
  | Semicolon -> "Semicolon"
  | EOF -> "EOF"

let is_alpha c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'

let is_digit c = c >= '0' && c <= '9'

let is_alphanum c = is_alpha c || is_digit c

let is_whitespace c = c = ' ' || c = '\t' || c = '\n' || c = '\r'

let rec skip_whitespace input pos =
  if pos >= String.length input then pos
  else if is_whitespace input.[pos] then skip_whitespace input (pos + 1)
  else pos

let read_identifier input pos =
  let len = String.length input in
  let rec loop acc i =
    if i >= len then (acc, i)
    else if is_alphanum input.[i] then
      loop (acc ^ String.make 1 input.[i]) (i + 1)
    else (acc, i)
  in
  if pos >= len then ("", pos)
  else if is_alpha input.[pos] then
    loop (String.make 1 input.[pos]) (pos + 1)
  else ("", pos)

let read_constant input pos =
  let len = String.length input in
  let rec loop acc i =
    if i >= len then (acc, i)
    else if is_digit input.[i] then
      loop (acc ^ String.make 1 input.[i]) (i + 1)
    else (acc, i)
  in
  if pos >= len then ("", pos)
  else if is_digit input.[pos] then
    loop (String.make 1 input.[pos]) (pos + 1)
  else ("", pos)

let keyword_or_identifier s =
  match s with
  | "int" -> Int
  | "void" -> Void
  | "return" -> Return
  | _ -> Identifier s

let rec tokenize input pos acc =
  let pos = skip_whitespace input pos in
  if pos >= String.length input then List.rev (EOF :: acc)
  else
    match input.[pos] with
    | '(' -> tokenize input (pos + 1) (OpenParen :: acc)
    | ')' -> tokenize input (pos + 1) (CloseParen :: acc)
    | '{' -> tokenize input (pos + 1) (OpenBrace :: acc)
    | '}' -> tokenize input (pos + 1) (CloseBrace :: acc)
    | ';' -> tokenize input (pos + 1) (Semicolon :: acc)
    | c when is_digit c ->
        let (const_str, new_pos) = read_constant input pos in
        (* Check if there are alphabetic characters immediately following the constant *)
        if new_pos < String.length input && is_alpha input.[new_pos] then
          failwith (sprintf "Invalid token: numeric constant followed by alphabetic character at position %d" pos)
        else
          let const_val = int_of_string const_str in
          tokenize input new_pos (Constant const_val :: acc)
    | c when is_alpha c ->
        let (ident_str, new_pos) = read_identifier input pos in
        let token = keyword_or_identifier ident_str in
        tokenize input new_pos (token :: acc)
    | c -> failwith (sprintf "Unexpected character: %c at position %d" c pos)

let lex input =
  tokenize input 0 []

let print_tokens tokens =
  List.iter (fun token -> printf "%s\n" (token_to_string token)) tokens
