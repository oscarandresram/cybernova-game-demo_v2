#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

resolve_godot() {
	if [[ -n "${GODOT:-}" && -x "${GODOT}" ]]; then
		printf '%s\n' "$GODOT"
		return
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return
	fi
	if [[ -x "$HOME/.local/bin/godot" ]]; then
		printf '%s\n' "$HOME/.local/bin/godot"
		return
	fi
	echo "Godot 4.7 was not found. Install it, add it to PATH, or set GODOT to the executable." >&2
	exit 1
}

exec "$(resolve_godot)" --path "$ROOT" "$@"
