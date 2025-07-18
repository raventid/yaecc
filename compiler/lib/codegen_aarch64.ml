open Printf
open Codegen

(* AArch64 assembly generation for Apple Silicon macOS *)

(* AArch64 operand generation *)
let generate_aarch64_operand = function
  | Imm i -> sprintf "#%d" i
  | Register "eax" -> "w0"  (* Map x86 eax to ARM64 w0 (32-bit) *)
  | Register reg -> sprintf "x%s" reg  (* Generic register mapping *)

(* AArch64 instruction generation *)
let generate_aarch64_instruction = function
  | Mov (src, dst) -> 
      sprintf "    mov %s, %s" 
        (generate_aarch64_operand dst) 
        (generate_aarch64_operand src)
  | Ret -> "    ret"

(* AArch64 function generation with proper Apple Silicon macOS format *)
let generate_aarch64_function func =
  let prologue = [
    ".section __TEXT,__text,regular,pure_instructions";
    sprintf "    .globl _%s                           ; -- Begin function %s" func.name func.name;
    "    .p2align 2";
    sprintf "_%s:                                  ; @%s" func.name func.name;
    "    .cfi_startproc";
    "; %bb.0:";
  ] in
  let instructions = List.map generate_aarch64_instruction func.instructions in
  let epilogue = [
    "    .cfi_endproc";
    sprintf "                                        ; -- End function %s" func.name;
    ".subsections_via_symbols";
  ] in
  String.concat "\n" (prologue @ instructions @ epilogue)

(* Generate complete AArch64 program *)
let generate_aarch64_program = function
  | Program func -> generate_aarch64_function func

(* Write AArch64 assembly to file *)
let write_aarch64_assembly_to_file assembly_code output_file =
  try
    let oc = open_out output_file in
    output_string oc assembly_code;
    output_string oc "\n";
    close_out oc;
    Ok ()
  with
  | exn -> Error (sprintf "Failed to write AArch64 assembly file: %s" (Printexc.to_string exn))

(* Complete AArch64 codegen pipeline *)
let codegen_aarch64_to_file ast output_file =
  match codegen ast with
  | Ok assembly_ir ->
      let assembly_code = generate_aarch64_program assembly_ir in
      (match write_aarch64_assembly_to_file assembly_code output_file with
       | Ok () -> Ok assembly_ir
       | Error msg -> Error msg)
  | Error msg -> Error msg
