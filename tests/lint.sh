#!/usr/bin/env bash
# Lints the library with luau-analyze, keeping only findings that matter here.
#
# Roblox globals are unknown to plain luau, so they are filtered by name. An
# unknown global that is NOT a Roblox or executor name is a real bug - usually
# a local used before the line that declares it, which Lua resolves to nil.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/tests/.bin"

if command -v luau-analyze >/dev/null 2>&1; then
	analyze="$(command -v luau-analyze)"
elif [ -x "$bin/luau-analyze" ]; then
	analyze="$bin/luau-analyze"
else
	echo "luau-analyze not found; run tests/run.sh once to download it" >&2
	exit 1
fi

known='game|workspace|task|typeof|warn|Enum|Instance|Color3|UDim2|UDim|Vector2|Vector3'
known="$known"'|NumberSequence|NumberSequenceKeypoint|ColorSequence|ColorSequenceKeypoint'
known="$known"'|TweenInfo|Rect|Font|os|string|table|math|utf8|coroutine|bit32'
known="$known"'|ipairs|pairs|next|select|pcall|xpcall|unpack|rawget|rawset|rawequal|rawlen'
known="$known"'|tostring|tonumber|type|print|error|assert|setmetatable|getmetatable'
known="$known"'|require|newproxy|loadstring|getfenv|setfenv|script|shared|_G'
# executor globals, all guarded with typeof() checks before use
known="$known"'|gethui|get_hidden_gui|syn|protect_gui|cloneref|setclipboard|toclipboard'
known="$known"'|writefile|readfile|isfile|delfile|appendfile|isfolder|makefolder|listfiles|delfolder'
known="$known"'|getgenv|getrenv|hookfunction|identifyexecutor|queue_on_teleport'

status=0
for file in "$@"; do
	# Of the TypeErrors only "Unknown global" is worth keeping: the library
	# carries no type annotations, so the rest is inference noise about values
	# the dual call style (Lib:Fn(cfg) and Lib.Fn(cfg)) makes hard to narrow.
	out="$("$analyze" --formatter=plain "$file" 2>&1 |
		grep -v -E "Unknown require|UnknownType" |
		grep -v -E "\(W0\) TypeError: (the function|Type |Expected|Cannot|Key |'.*' could)" |
		grep -v -E "Unknown global '($known)'" || true)"
	if [ -n "$out" ]; then
		echo "$out"
		status=1
	fi
done

[ "$status" -eq 0 ] && echo "lint clean"
exit "$status"
