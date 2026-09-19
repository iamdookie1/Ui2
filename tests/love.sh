#!/usr/bin/env bash
# Runs the LoveUI smoke suite against the mock Roblox environment.
#
#   tests/love.sh
#
# Same harness as run.sh, pointed at LoveUI.lua instead of Ui.lua.
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

{
	sed '$ d' "$root/tests/mock.lua" | sed 's/^return M$//'
	echo "MOCK = M"
	echo
	echo "function LoadLove()"
	cat "$root/LoveUI.lua"
	echo "end"
	echo
	cat "$root/tests/love-spec.lua"
} > "$out/run.lua"

"$luau_bin" "$out/run.lua"
