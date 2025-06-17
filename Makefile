.PHONY: build clean test install run

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

# Install the project
install:
	cd compiler && dune install

# Run the compiled binary
run: build
	cd compiler && dune exec -- compiler