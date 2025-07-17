open Printf

(* Assembly IR types *)
type operand =
  | Imm of int
  | Register of string

type instruction =
  | Mov of operand * operand  (* src, dst *)
  | Ret

type function_definition = {
  name: string;
  instructions: instruction list;
}

type program = Program of function_definition

(* Pretty-printing for assembly IR *)
let operand_to_string = function
  | Imm i -> sprintf "$%d" i
  | Register reg -> sprintf "%%%s" reg

let instruction_to_string = function
  | Mov (src, dst) -> sprintf "movl %s, %s" (operand_to_string src) (operand_to_string dst)
  | Ret -> "ret"

let print_function func =
  printf "Function: %s\n" func.name;
  List.iter (fun instr -> printf "  %s\n" (instruction_to_string instr)) func.instructions

let print_program = function
  | Program func -> print_function func

(* Pretty-printer for debugging *)
let pretty_print_operand indent operand =
  let spaces = String.make indent ' ' in
  match operand with
  | Imm i -> sprintf "%sImm(%d)" spaces i
  | Register reg -> sprintf "%sRegister(\"%s\")" spaces reg

let pretty_print_instruction indent instr =
  let spaces = String.make indent ' ' in
  match instr with
  | Mov (src, dst) -> 
      sprintf "%sMov(\n%s,\n%s\n%s)" 
        spaces 
        (pretty_print_operand (indent + 2) src)
        (pretty_print_operand (indent + 2) dst)
        spaces
  | Ret -> sprintf "%sRet" spaces

let pretty_print_function indent func =
  let spaces = String.make indent ' ' in
  let instructions_str = String.concat ",\n" 
    (List.map (pretty_print_instruction (indent + 2)) func.instructions) in
  sprintf "%sFunction(\n%s  name=\"%s\",\n%s  instructions=[\n%s\n%s  ]\n%s)" 
    spaces 
    spaces 
    func.name 
    spaces 
    instructions_str 
    spaces
    spaces

let pretty_print_program = function
  | Program func -> sprintf "Program(\n%s\n)" (pretty_print_function 2 func)

let print_pretty_program prog =
  printf "%s\n" (pretty_print_program prog)

(* Code generation from AST to assembly IR *)
let generate_expression = function
  | Parser.Constant value -> Imm value

let generate_statement = function
  | Parser.Return expr ->
      let operand = generate_expression expr in
      [Mov (operand, Register "eax"); Ret]

let generate_function func =
  let instructions = List.flatten (List.map generate_statement func.Parser.body) in
  {
    name = func.Parser.name;
    instructions = instructions;
  }

let generate_program prog =
  Program (generate_function prog)

(* Main codegen function *)
let codegen ast =
  try
    Ok (generate_program ast)
  with
  | exn -> Error (sprintf "Code generation error: %s" (Printexc.to_string exn))

(* x86 Linux assembly generation *)
let generate_x86_operand = function
  | Imm i -> sprintf "$%d" i
  | Register reg -> sprintf "%%%s" reg

let generate_x86_instruction = function
  | Mov (src, dst) -> sprintf "    movl %s, %s" (generate_x86_operand src) (generate_x86_operand dst)
  | Ret -> "    ret"

let generate_x86_function func =
  let prologue = [
    sprintf "  .globl %s" func.name;
    sprintf "%s:" func.name;
  ] in
  let instructions = List.map generate_x86_instruction func.instructions in
  String.concat "\n" (prologue @ instructions)

let generate_x86_program = function
  | Program func -> generate_x86_function func

(* Write assembly to file *)
let write_assembly_to_file assembly_code output_file =
  try
    let oc = open_out output_file in
    output_string oc assembly_code;
    output_string oc "\n";
    close_out oc;
    Ok ()
  with
  | exn -> Error (sprintf "Failed to write assembly file: %s" (Printexc.to_string exn))

(* Complete codegen pipeline *)
let codegen_to_file ast output_file =
  match codegen ast with
  | Ok assembly_ir ->
      let assembly_code = generate_x86_program assembly_ir in
      (match write_assembly_to_file assembly_code output_file with
       | Ok () -> Ok assembly_ir
       | Error msg -> Error msg)
  | Error msg -> Error msg
