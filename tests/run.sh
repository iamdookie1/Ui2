#!/usr/bin/env bash
# Runs the Onyx test suite against a mock Roblox environment.
#
#   tests/run.sh
#
# Needs the `luau` CLI. If it is not on PATH the script downloads the latest
# Linux release into tests/.bin.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/tests/.bin"

if command -v luau >/dev/null 2>&1; then
	luau_bin="$(command -v luau)"
elif [ -x "$bin/luau" ]; then
	luau_bin="$bin/luau"
else
	echo "downloading luau..."
	mkdir -p "$bin"
	curl -sSL -o "$bin/luau.zip" \
		"https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip"
	unzip -o -q "$bin/luau.zip" -d "$bin"
	chmod +x "$bin/luau" "$bin/luau-compile" "$bin/luau-analyze"
	luau_bin="$bin/luau"
fi

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# mock.lua ends in `return M`; splice it into one file with the library and spec
{
	sed '$ d' "$root/tests/mock.lua" | sed 's/^return M$//'
	echo "MOCK = M"
	echo
	echo "function LoadOnyx()"
	cat "$root/Ui.lua"
	echo "end"
	echo
	cat "$root/tests/spec.lua"
} > "$out/run.lua"

"$luau_bin" "$out/run.lua"
