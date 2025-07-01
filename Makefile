.PHONY: build clean test install run arch-info spec check-setup run_assembly clean-target

# Default target
all: build

# Build the project using dune
build:
	cd compiler && opam exec -- dune build

# Clean build artifacts
clean:
	cd compiler && opam exec -- dune clean

# Clean target directory
clean-target:
	rm -rf compiler/_target
	@echo "Target directory cleaned"

# Run tests (TODO: should be external tests package with C samples)
test:
	cd compiler && opam exec -- dune runtest

# Check setup with external test framework
check-setup:
	cd writing-a-c-compiler-tests && ./test_compiler --check-setup

# Install the project
install:
	cd compiler && opam exec -- dune install

raw_assembly:
	@mkdir -p sample_programs/_build/$$(uname -m)
	gcc -S -O -fno-asynchronous-unwind-tables -fcf-protection=none sample_programs/$(f) -o sample_programs/_build/$$(uname -m)/$$(basename $(f) .c).s
	@echo "Assembly generated: sample_programs/_build/$$(uname -m)/$$(basename $(f) .c).s"

# Run x86_64 shell on MacOS
x86_shell:
	arch -x86_64 zsh

# Run the compiled binary
run: build clean-target
	cd compiler && opam exec -- dune exec -- compiler $(f)

lex: build clean-target
	cd compiler && opam exec -- dune exec -- compiler $(f) --lex

# Run spec tests
spec: build
	./writing-a-c-compiler-tests/test_compiler $$(pwd)/compiler/_build/default/bin/main.exe --chapter 1 --stage lex

# Show current architecture info
arch-info:
	@echo "════════════════════════════════════════════════════════════════"
	@echo "Current Architecture Information"
	@echo "════════════════════════════════════════════════════════════════"
	@echo "System architecture: $$(uname -m)"
	@echo "OCaml compiler: $$(file $$(which ocamlopt) | cut -d: -f2-)"
	@echo "Dune build tool: $$(file $$(which dune) | cut -d: -f2-)"
	@echo ""
	@echo "Current build state:"
	@cd compiler && dune build >/dev/null 2>&1 && \
		(echo "Compiled executable: $$(file _build/default/bin/main.exe | cut -d: -f2-)")
	@echo "════════════════════════════════════════════════════════════════"