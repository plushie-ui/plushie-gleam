# plushie-gleam - Development Tasks
#
# Run `just` to see available recipes.
# Run `just preflight` before pushing to catch CI failures locally.

set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Fetch dependencies
deps:
    gleam deps download

# Run all CI checks locally (same as CI pipeline).
# Auto-detects ../plushie-rust as PLUSHIE_RUST_SOURCE_PATH when not set.
# Set PLUSHIE_RUST_SOURCE_PATH="" to force non-local (skip auto-detect).
preflight: deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${PLUSHIE_RUST_SOURCE_PATH+x}" ]] && [[ -d "../plushie-rust" ]]; then
        export PLUSHIE_RUST_SOURCE_PATH="$(cd ../plushie-rust && pwd)"
        echo "==> auto: PLUSHIE_RUST_SOURCE_PATH=$PLUSHIE_RUST_SOURCE_PATH"
    fi
    ./bin/preflight

# Run tests (mock backend, default)
test:
    gleam test

# Check code formatting
fmt-check:
    gleam format --check

# Apply code formatting
fmt:
    gleam format

# Build documentation
docs:
    gleam docs build

# Remove gitignored build artifacts
clean:
    git clean -fdX
