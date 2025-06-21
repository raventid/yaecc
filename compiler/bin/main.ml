open Printf

let create_target_dir () =
  let target_dir = "_target" in
  if not (Sys.file_exists target_dir) then
    Sys.mkdir target_dir 0o755;
  target_dir

let run_command cmd =
  printf "Running: %s\n" cmd;
  let exit_code = Sys.command cmd in
  if exit_code <> 0 then
    failwith (sprintf "Command failed with exit code %d: %s" exit_code cmd)

let preprocess_file input_file target_dir =
  let preprocessed_file = Filename.concat target_dir "preprocessed.i" in
  let cmd = sprintf "gcc -E -P %s -o %s" input_file preprocessed_file in
  run_command cmd;
  preprocessed_file

let compile_to_assembly preprocessed_file target_dir =
  let assembly_file = Filename.concat target_dir "output.s" in
  let cmd = sprintf "gcc -S -O -fno-asynchronous-unwind-tables -fcf-protection=none %s -o %s" 
    preprocessed_file assembly_file in
  run_command cmd;
  assembly_file

let compile_to_executable assembly_file target_dir =
  let executable_file = Filename.concat target_dir "output" in
  let cmd = sprintf "gcc %s -o %s" assembly_file executable_file in
  run_command cmd;
  executable_file

let main () =
  if Array.length Sys.argv < 2 then begin
    printf "Usage: %s <input_file.c>\n" Sys.argv.(0);
    exit 1
  end;
  
  let input_file = Sys.argv.(1) in
  printf "Compiling: %s\n" input_file;
  
  (* Create target directory *)
  let target_dir = create_target_dir () in
  printf "Created target directory: %s\n" target_dir;
  
  (* Step 1: Preprocess *)
  printf "\n=== Step 1: Preprocessing ===\n";
  let preprocessed_file = preprocess_file input_file target_dir in
  printf "Preprocessed file: %s\n" preprocessed_file;
  
  (* Step 2: Compile to assembly *)
  printf "\n=== Step 2: Compile to Assembly ===\n";
  let assembly_file = compile_to_assembly preprocessed_file target_dir in
  printf "Assembly file: %s\n" assembly_file;
  
  (* Step 3: Compile to executable *)
  printf "\n=== Step 3: Link to Executable ===\n";
  let executable_file = compile_to_executable assembly_file target_dir in
  printf "Executable file: %s\n" executable_file;
  
  printf "\n=== Compilation Complete ===\n";
  printf "You can run the executable with: ./%s\n" executable_file

let () = main ()