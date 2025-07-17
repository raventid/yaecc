(* 
  --lex Directs it to run the lexer, but stop before parsing
  --parse Directs it to run the lexer and parser, but stop before assembly generation
  --codegen Directs it to perform lexing, parsing, and assembly generation, but stop before code emission 
*)

open Printf
open Compiler.Lexer

module Parser = Compiler.Parser
module Codegen = Compiler.Codegen

type compilation_stage = 
  | Lex
  | Parse
  | Codegen
  | Full

(* Flag to use GCC for compilation instead of our compiler *)
let use_gcc = ref false

let create_target_dir input_file =
  let base_target_dir = "_target" in
  let filename = Filename.basename input_file in
  let filename_without_ext = Filename.remove_extension filename in
  let target_dir = Filename.concat base_target_dir filename_without_ext in
  
  (* Create base _target directory if it doesn't exist *)
  if not (Sys.file_exists base_target_dir) then
    Sys.mkdir base_target_dir 0o755;
  
  (* Create subdirectory for this specific file *)
  if not (Sys.file_exists target_dir) then
    Sys.mkdir target_dir 0o755;
  
  target_dir

let run_command cmd =
  printf "Running: %s\n" cmd;
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith (sprintf "Command failed with exit code %d: %s" exit_code cmd)

(* The -E option tells GCC to run only the preprocessor, *)
(* not the later steps of the compilation process     *)
(* The -P option tells the preprocessor *)
(* not to emit linemarkers; our lexer and parser won’t be able to process them *)
let preprocess_file input_file target_dir =
  let preprocessed_file = Filename.concat target_dir "preprocessed.i" in
  let cmd = sprintf "gcc -E -P %s -o %s" input_file preprocessed_file in
  run_command cmd;
  preprocessed_file

(* GCC compilation functions - commented out but kept for future --gcc flag implementation *)
(*
let compile_to_assembly preprocessed_file target_dir =
  let assembly_file = Filename.concat target_dir "output.s" in
  let cmd = sprintf "gcc -S -O -fno-asynchronous-unwind-tables -fcf-protection=none %s -o %s" 
    preprocessed_file assembly_file in
  run_command cmd;
  assembly_file
*)

let compile_to_executable assembly_file target_dir =
  let executable_file = Filename.concat target_dir "output" in
  let cmd = sprintf "gcc %s -o %s" assembly_file executable_file in
  run_command cmd;
  executable_file

let parse_args () =
  let stage = ref Full in
  let input_file = ref "" in
  let args = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
  
  Array.iter (fun arg ->
    match arg with
    | "--lex" -> stage := Lex
    | "--parse" -> stage := Parse
    | "--codegen" -> stage := Codegen
    | "--gcc" -> use_gcc := true
    | _ when !input_file = "" -> input_file := arg
    | _ -> failwith (sprintf "Unknown argument: %s" arg)
  ) args;
  
  if !input_file = "" then begin
    printf "Usage: %s [--lex|--parse|--codegen] [--gcc] <input_file.c>\n" Sys.argv.(0);
    exit 1
  end;
  
  (!stage, !input_file)

let main () =
  let (stage, input_file_arg) = parse_args () in
  (* Convert relative path to absolute path from compiler directory *)
  let input_file = if Filename.is_relative input_file_arg then
    Filename.concat ".." input_file_arg
  else
    input_file_arg
  in
  printf "Compiling: %s\n" input_file;
  
  (* Create target directory *)
  let target_dir = create_target_dir input_file_arg in
  printf "Created target directory: %s\n" target_dir;
  
  (* Step 1: Preprocess *)
  printf "\n=== Step 1: Preprocessing ===\n";
  let preprocessed_file = preprocess_file input_file target_dir in
  printf "Preprocessed file: %s\n" preprocessed_file;
  
  (* For --lex, we would stop here and run lexer *)
  if stage = Lex then begin
    printf "Lexer flag --lex is set, stopping after lexing\n";
    let content = 
      let ic = open_in preprocessed_file in
      let content = really_input_string ic (in_channel_length ic) in
      close_in ic;
      content
    in
    let tokens = lex content in
    printf "Tokens:\n";
    print_tokens tokens;
    exit 0
  end;
  
  (* For --parse, we would stop here and run parser *)
  if stage = Parse then begin
    printf "\n=== Parsing Complete ===\n";
    let content = 
      let ic = open_in preprocessed_file in
      let content = really_input_string ic (in_channel_length ic) in
      close_in ic;
      content
    in
    let tokens = lex content in
    printf "Tokens:\n";
    print_tokens tokens;
    printf "\nParsing tokens...\n";
    (match Parser.parse tokens with
     | Ok ast -> 
         printf "Parse successful!\n";
         printf "AST:\n";
         Parser.print_program ast;
         printf "\nPretty-printed AST:\n";
         Parser.print_pretty_program ast
     | Error msg -> 
         printf "Parse error: %s\n" msg;
         exit 1);
    exit 0
  end;
  
  (* Step 2: Compile to assembly *)
  printf "\n=== Step 2: Compile to Assembly ===\n";
  let content = 
    let ic = open_in preprocessed_file in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    content
  in
  let tokens = lex content in
  printf "Tokens:\n";
  print_tokens tokens;
  printf "\nParsing tokens...\n";
  (match Parser.parse tokens with
   | Ok ast -> 
       printf "Parse successful!\n";
       printf "Generating assembly...\n";
       let assembly_file = Filename.concat target_dir "output.s" in
       (match Codegen.codegen_to_file ast assembly_file with
        | Ok assembly_ir -> 
            printf "Assembly IR:\n";
            Codegen.print_program assembly_ir;
            printf "\nPretty-printed Assembly IR:\n";
            Codegen.print_pretty_program assembly_ir;
            printf "\nAssembly file generated: %s\n" assembly_file;
            
            (* For --codegen, we stop here *)
            if stage = Codegen then begin
              printf "\n=== Code Generation Complete ===\n";
              printf "Assembly generation complete, stopping before linking\n";
              exit 0
            end
        | Error msg -> 
            printf "Codegen error: %s\n" msg;
            exit 1)
   | Error msg -> 
       printf "Parse error: %s\n" msg;
       exit 1);
  
  (* If we reach here, we're in Full stage *)
  (* Use our generated assembly file or GCC depending on --gcc flag *)
  let assembly_file = 
    if !use_gcc then begin
      (* Comment: Future implementation for --gcc flag *)
      (* let assembly_file = compile_to_assembly preprocessed_file target_dir in *)
      printf "GCC compilation not yet implemented in this version\n";
      exit 1
    end else begin
      (* Use our generated assembly file *)
      let assembly_file = Filename.concat target_dir "output.s" in
      printf "Using generated assembly file: %s\n" assembly_file;
      assembly_file
    end
  in
  
  (* Step 3: Link to Executable *)
  printf "\n=== Step 3: Link to Executable ===\n";
  let executable_file = compile_to_executable assembly_file target_dir in
  printf "Executable file: %s\n" executable_file;
  
  printf "\n=== Compilation Complete ===\n";
  printf "You can run the executable with: ./%s\n" executable_file

let () = main ()