.PHONY: build clean test install run arch-info spec run_assembly

# Default target
all: build

# Build the project using dune
build:
	cd compiler && dune build

# Clean build artifacts
clean:
	cd compiler && dune clean

# Run tests (TODO: should be external tests package with C samples)
test:
	cd compiler && dune runtest

spec:
	cd writing-a-c-compiler-tests && ./test_compiler --check-setup

# Install the project
install:
	cd compiler && dune install

raw_assembly:
	@mkdir -p sample_programs/_build/$$(uname -m)
	gcc -S -O -fno-asynchronous-unwind-tables -fcf-protection=none sample_programs/$(f) -o sample_programs/_build/$$(uname -m)/$$(basename $(f) .c).s
	@echo "Assembly generated: sample_programs/_build/$$(uname -m)/$$(basename $(f) .c).s"

# Run x86_64 shell on MacOS
x86_shell:
	arch -x86_64 zsh

# Run the compiled binary
run: build
	cd compiler && dune exec -- compiler

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