#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Both sides must match exactly; generated bindings belong in version control.
flutter pub get
if [[ "$("${CARGO_HOME:-$HOME/.cargo}/bin/flutter_rust_bridge_codegen" --version 2>/dev/null || true)" != 'flutter_rust_bridge_codegen 2.13.0' ]]; then
  cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
fi
if [[ "$("${CARGO_HOME:-$HOME/.cargo}/bin/cargo-expand" --version 2>/dev/null || true)" != 'cargo-expand 1.0.127' ]]; then
  cargo install cargo-expand --version 1.0.127 --locked
fi
"${CARGO_HOME:-$HOME/.cargo}/bin/flutter_rust_bridge_codegen" generate
