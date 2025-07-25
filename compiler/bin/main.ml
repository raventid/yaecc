(*
  --lex Directs it to run the lexer, but stop before parsing
  --parse Directs it to run the lexer and parser, but stop before assembly generation
  --codegen Directs it to perform lexing, parsing, and assembly generation, but stop before code emission 
*)

open Printf
open Compiler.Lexer

module Parser = Compiler.Parser
module Codegen = Compiler.Codegen
module Codegen_aarch64 = Compiler.Codegen_aarch64

type compilation_stage = 
  | Lex
  | Parse
  | Codegen
  | Full

(* Flag to use GCC for compilation instead of our compiler *)
let use_gcc = ref false

(* Target directory for executable output *)
let target_dir_flag = ref None

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

(* Get the expected output executable path from input file *)
let get_executable_path input_file custom_target_dir =
  let basename = Filename.basename input_file in
  let name_without_ext = Filename.remove_extension basename in
  match custom_target_dir with
  | Some target_dir -> Filename.concat target_dir name_without_ext
  | None -> 
      let dir = Filename.dirname input_file in
      Filename.concat dir name_without_ext

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

let compile_to_executable assembly_file output_executable =
  let cmd = sprintf "gcc %s -o %s" assembly_file output_executable in
  run_command cmd;
  output_executable

let parse_args () =
  let stage = ref Full in
  let input_file = ref "" in
  let args = Array.sub Sys.argv 1 (Array.length Sys.argv - 1) in
  let i = ref 0 in
  
  while !i < Array.length args do
    let arg = args.(!i) in
    match arg with
    | "--lex" -> stage := Lex; incr i
    | "--parse" -> stage := Parse; incr i
    | "--codegen" -> stage := Codegen; incr i
    | "--gcc" -> use_gcc := true; incr i
    | arg when String.length arg >= 12 && String.sub arg 0 12 = "--target-dir" -> (*TODO: @raventid, this is ugly, should simplify*)
        if String.length arg > 12 && arg.[12] = '=' then
          (* Format: --target-dir=path *)
          let target_path = String.sub arg 13 (String.length arg - 13) in
          target_dir_flag := Some target_path;
          incr i
        else if String.length arg = 12 then
          (* Format: --target-dir path *)
          if !i + 1 < Array.length args then (
            target_dir_flag := Some args.(!i + 1);
            i := !i + 2
          ) else
            failwith "Missing argument for --target-dir"
        else
          failwith (sprintf "Invalid --target-dir format: %s" arg)
    | _ when !input_file = "" -> input_file := arg; incr i
    | _ -> failwith (sprintf "Unknown argument: %s" arg)
  done;
  
  if !input_file = "" then begin
    printf "Usage: %s [--lex|--parse|--codegen] [--gcc] [--target-dir=path] <input_file.c>\n" Sys.argv.(0);
    exit 1
  end;
  
  (!stage, !input_file)

let main () =
  Random.self_init ();
  let (stage, input_file_arg) = parse_args () in
  (* Convert relative path to absolute path from compiler directory *)
  let input_file = if Filename.is_relative input_file_arg then
    Filename.concat ".." input_file_arg
  else
    input_file_arg
  in
  printf "Compiling: %s\n" input_file;
  
  (* Detect and display architecture *)
  let arch = Codegen.detect_architecture () in
  printf "Detected architecture: %s\n" (Codegen.architecture_to_string arch);
  
  (* Create target directory if specified and ensure it exists *)
  (match !target_dir_flag with
   | Some target_dir ->
       if not (Sys.file_exists target_dir) then (
         printf "Creating target directory: %s\n" target_dir;
         let rec create_dirs path =
           let parent = Filename.dirname path in
           if parent <> path && not (Sys.file_exists parent) then
             create_dirs parent;
           if not (Sys.file_exists path) then
             Sys.mkdir path 0o755
         in
         create_dirs target_dir
       )
   | None -> ());
  
  (* Create target directory only for full compilation *)
  let target_dir = if stage = Full then begin
    let target_dir = create_target_dir input_file_arg in
    printf "Created target directory: %s\n" target_dir;
    target_dir
  end else begin
    (* For intermediate stages, use a temporary directory *)
    let temp_dir = Filename.get_temp_dir_name () in
    let temp_subdir = Filename.concat temp_dir (sprintf "compiler_temp_%d" (Random.int 10000)) in
    if not (Sys.file_exists temp_subdir) then
      Sys.mkdir temp_subdir 0o755;
    temp_subdir
  end in
  
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
       (* Choose codegen based on detected architecture *)
       let codegen_result = match arch with
         | Codegen.Apple_Silicon_MacOS -> 
             printf "Using AArch64 codegen for Apple Silicon\n";
             Codegen_aarch64.codegen_aarch64_to_file ast assembly_file
         | Codegen.X86_Linux | Codegen.X86_MacOS -> 
             printf "Using x86 codegen\n";
             Codegen.codegen_to_file ast assembly_file
       in
       (match codegen_result with
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
  let expected_executable = get_executable_path input_file !target_dir_flag in
  let executable_file = compile_to_executable assembly_file expected_executable in
  printf "Executable file: %s\n" executable_file;
  
  printf "\n=== Compilation Complete ===\n";
  printf "You can run the executable with: %s\n" executable_file

let () = main ()