.PHONY: build build-debug clean test

# Build the native Rust library in release mode.
build:
	@cd native && cargo build --release

# Build the native Rust library in debug mode.
build-debug:
	@cd native && cargo build

# Clean native build artifacts.
clean:
	@cd native && cargo clean

# Run Dart analysis.
analyze:
	@dart analyze

# Run Dart tests (requires the native library to be built first).
test: build
	@dart test

# Copy the built library to the project root for easy Dart access.
install: build
	@OS=$$(uname -s); \
	case "$$OS" in \
		Darwin) cp native/target/release/libdnsolve_native.dylib . ;; \
		Linux)  cp native/target/release/libdnsolve_native.so . ;; \
		*)      echo "Unsupported OS: $$OS"; exit 1 ;; \
	esac
	@echo "Library copied to project root."
