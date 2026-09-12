--!nocheck
-- Minimal Roblox API mock, enough to execute a UI library end to end.

local M = {}

--------------------------------------------------------------------
-- typeof
--------------------------------------------------------------------
local TypeTags = setmetatable({}, { __mode = "k" })
local function tag(v, name) TypeTags[v] = name; return v end

function typeof(v)
	local t = type(v)
	if t == "table" then
		local name = TypeTags[v]
		if name then return name end
		if getmetatable(v) and getmetatable(v).__instance then return "Instance" end
		return "table"
	end
	return t
end

--------------------------------------------------------------------
-- signals
--------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return tag(setmetatable({ handlers = {} }, Signal), "RBXScriptSignal")
end
function Signal:Connect(fn)
	local entry = { fn = fn, alive = true }
	table.insert(self.handlers, entry)
	return tag({
		Disconnect = function() entry.alive = false end,
		Connected = true,
	}, "RBXScriptConnection")
end
Signal.connect = Signal.Connect
function Signal:Fire(...)
	for _, entry in ipairs(table.clone(self.handlers)) do
		if entry.alive then
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				M.errors = M.errors or {}
				table.insert(M.errors, tostring(err))
				print("[signal error] " .. tostring(err))
			end
		end
	end
end

--------------------------------------------------------------------
-- data types
--------------------------------------------------------------------
local function vec2(x, y)
	local v
	v = tag(setmetatable({ X = x or 0, Y = y or 0 }, {
		__add = function(a, b) return vec2(a.X + b.X, a.Y + b.Y) end,
		__sub = function(a, b) return vec2(a.X - b.X, a.Y - b.Y) end,
		__tostring = function(s) return ("%g, %g"):format(s.X, s.Y) end,
	}), "Vector2")
	return v
end
Vector2 = { new = vec2, zero = vec2(0, 0) }

local function vec3(x, y, z) return tag({ X = x or 0, Y = y or 0, Z = z or 0 }, "Vector3") end
Vector3 = { new = vec3 }

UDim = { new = function(s, o) return tag({ Scale = s or 0, Offset = o or 0 }, "UDim") end }

local function udim2(xs, xo, ys, yo)
	return tag({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, "UDim2")
end
UDim2 = {
	new = udim2,
	fromOffset = function(x, y) return udim2(0, x or 0, 0, y or 0) end,
	fromScale  = function(x, y) return udim2(x or 0, 0, y or 0, 0) end,
}

local Color3mt = {}
local function color3(r, g, b)
	local c = setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3mt)
	return tag(c, "Color3")
end
Color3mt.__index = {
	ToHSV = function(self)
		local r, g, b = self.R, self.G, self.B
		local max, min = math.max(r, g, b), math.min(r, g, b)
		local h, s, v = 0, 0, max
		local d = max - min
		s = max == 0 and 0 or d / max
		if d ~= 0 then
			if max == r then h = ((g - b) / d) % 6
			elseif max == g then h = (b - r) / d + 2
			else h = (r - g) / d + 4 end
			h = h / 6
		end
		return h, s, v
	end,
}
Color3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = color3,
	fromRGB = function(r, g, b) return color3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		local m = i % 6
		if m == 0 then return color3(v, t, p)
		elseif m == 1 then return color3(q, v, p)
		elseif m == 2 then return color3(p, v, t)
		elseif m == 3 then return color3(p, q, v)
		elseif m == 4 then return color3(t, p, v)
		else return color3(v, p, q) end
	end,
}

NumberSequenceKeypoint = { new = function(t, v) return tag({ Time = t, Value = v }, "NumberSequenceKeypoint") end }
NumberSequence = { new = function(a) return tag({ Keypoints = a }, "NumberSequence") end }
ColorSequenceKeypoint = { new = function(t, v) return tag({ Time = t, Value = v }, "ColorSequenceKeypoint") end }
ColorSequence = { new = function(a) return tag({ Keypoints = a }, "ColorSequence") end }
TweenInfo = { new = function(...) return tag({ ... }, "TweenInfo") end }
Rect = { new = function(x0, y0, x1, y1)
	return tag({
		Min = vec2(x0, y0), Max = vec2(x1, y1),
		Width = (x1 or 0) - (x0 or 0), Height = (y1 or 0) - (y0 or 0),
	}, "Rect")
end }

--------------------------------------------------------------------
-- Enum (auto-vivifying)
--------------------------------------------------------------------
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		if enumCache[enumName] then return enumCache[enumName] end
		local items = {}
		local enumType = tag(setmetatable({ Name = enumName }, {
			__tostring = function() return "Enum." .. enumName end,
		}), "Enum")
		local e = setmetatable({}, {
			__index = function(_, itemName)
				if not items[itemName] then
					items[itemName] = tag(setmetatable({
						Name = itemName, Value = 0, EnumType = enumType,
					}, { __tostring = function(s) return "Enum." .. enumName .. "." .. s.Name end }), "EnumItem")
				end
				return items[itemName]
			end,
			__tostring = function() return "Enum." .. enumName end,
		})
		enumCache[enumName] = e
		return e
	end,
})

--------------------------------------------------------------------
-- Instance
--------------------------------------------------------------------
local EVENTS = {
	"MouseEnter", "MouseLeave", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up",
	"InputBegan", "InputChanged", "InputEnded", "Changed", "Destroying",
	"Focused", "FocusLost", "Activated", "ChildAdded", "ChildRemoved",
}

local Instance_mt = {}
Instance_mt.__instance = true

local DEFAULTS = {
	AbsolutePosition = function() return vec2(0, 0) end,
	AbsoluteSize     = function() return vec2(200, 200) end,
	TextBounds       = function() return vec2(40, 12) end,
	AbsoluteCanvasSize = function() return vec2(0, 0) end,
	AbsoluteContentSize = function() return vec2(0, 0) end,
	AbsoluteWindowSize = function() return vec2(200, 200) end,
	CanvasPosition     = function() return vec2(0, 0) end,
	Text             = function() return "" end,
	Name             = function() return "Instance" end,
	Visible          = function() return true end,
	ClassName        = function() return "Instance" end,
}

local allInstances = {}

function Instance_mt.__index(self, key)
	local raw = rawget(self, "_props")[key]
	if raw ~= nil then return raw end

	local ev = rawget(self, "_events")[key]
	if ev then return ev end

	local methods = rawget(self, "_methods")
	if methods[key] then return methods[key] end

	-- child lookup
	for _, c in ipairs(rawget(self, "_children")) do
		if c.Name == key then return c end
	end

	local d = DEFAULTS[key]
	if d then
		local value = d()
		rawget(self, "_props")[key] = value
		return value
	end
	return nil
end

function Instance_mt.__newindex(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			for i, c in ipairs(rawget(old, "_children")) do
				if c == self then table.remove(rawget(old, "_children"), i); break end
			end
		end
		props.Parent = value
		if value then table.insert(rawget(value, "_children"), self) end
		return
	end
	props[key] = value
	local sigs = rawget(self, "_propSignals")[key]
	if sigs then sigs:Fire() end
	rawget(self, "_events").Changed:Fire(key)
end

Instance_mt.__tostring = function(self) return rawget(self, "_props").Name or "Instance" end

Instance = {}
function Instance.new(className, parent)
	local self = setmetatable({
		_props = { ClassName = className, Name = className },
		_attrs = {},
		_children = {},
		_events = {},
		_propSignals = {},
		_methods = {},
	}, Instance_mt)

	for _, name in ipairs(EVENTS) do
		rawget(self, "_events")[name] = newSignal()
	end

	local methods = rawget(self, "_methods")
	methods.Destroy = function(s)
		rawget(s, "_events").Destroying:Fire()
		for _, c in ipairs(table.clone(rawget(s, "_children"))) do c:Destroy() end
		s.Parent = nil
		rawget(s, "_props").Destroyed = true
	end
	methods.GetChildren = function(s) return table.clone(rawget(s, "_children")) end
	methods.GetDescendants = function(s)
		local out = {}
		local function walk(node)
			for _, c in ipairs(rawget(node, "_children")) do
				table.insert(out, c); walk(c)
			end
		end
		walk(s)
		return out
	end
	methods.FindFirstChild = function(s, name)
		for _, c in ipairs(rawget(s, "_children")) do if c.Name == name then return c end end
		return nil
	end
	methods.FindFirstChildOfClass = function(s, cls)
		for _, c in ipairs(rawget(s, "_children")) do if c.ClassName == cls then return c end end
		return nil
	end
	methods.WaitForChild = function(s, name) return methods.FindFirstChild(s, name) end
	methods.GetPropertyChangedSignal = function(s, prop)
		local sigs = rawget(s, "_propSignals")
		if not sigs[prop] then sigs[prop] = newSignal() end
		return sigs[prop]
	end
	methods.IsA = function(s, cls) return rawget(s, "_props").ClassName == cls end
	methods.SetAttribute = function(s, name, value) rawget(s, "_attrs")[name] = value end
	methods.GetAttribute = function(s, name) return rawget(s, "_attrs")[name] end
	methods.IsDescendantOf = function(s, ancestor)
		local node = rawget(s, "_props").Parent
		while node do
			if node == ancestor then return true end
			node = rawget(node, "_props").Parent
		end
		return false
	end
	methods.Clone = function(s) return Instance.new(rawget(s, "_props").ClassName) end
	methods.CaptureFocus = function(s) rawget(s, "_events").Focused:Fire() end
	methods.ReleaseFocus = function(s) rawget(s, "_events").FocusLost:Fire(false) end
	methods.IsFocused = function() return false end

	if parent then self.Parent = parent end
	table.insert(allInstances, self)
	return self
end

M.allInstances = allInstances

--------------------------------------------------------------------
-- task scheduler
--------------------------------------------------------------------
local queue = {}
M.clock = 0
-- There are no coroutines here, so a yield is modelled as unwinding the
-- current "thread": task.wait throws a sentinel that task.spawn swallows. A
-- polling loop therefore runs exactly one iteration instead of hanging.
local YIELD = "__mock_yield__"

local function runThread(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and tostring(err):find(YIELD, 1, true) == nil then
		M.errors = M.errors or {}
		table.insert(M.errors, tostring(err))
		print("[task error] " .. tostring(err))
	end
	return ok
end

task = {
	spawn = runThread,
	defer = function(fn, ...) table.insert(queue, { at = M.clock, fn = fn, args = table.pack(...) }) end,
	delay = function(t, fn, ...) table.insert(queue, { at = M.clock + t, fn = fn, args = table.pack(...) }) end,
	wait  = function() error(YIELD, 0) end,
}
function M.step(seconds)
	M.clock = M.clock + (seconds or 0)
	local pending = queue
	queue = {}
	local carry = {}
	for _, job in ipairs(pending) do
		if job.at <= M.clock then
			runThread(job.fn, table.unpack(job.args, 1, job.args.n))
		else
			table.insert(carry, job)
		end
	end
	for _, job in ipairs(carry) do table.insert(queue, job) end
end

function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	local message = table.concat(parts, " ")
	-- a callback that yields is normal in Roblox; here it unwinds as the
	-- sentinel, so do not report it as a failure
	if message:find(YIELD, 1, true) then return end
	print("[warn] " .. message)
	M.warnings = M.warnings or {}
	table.insert(M.warnings, message)
end

--------------------------------------------------------------------
-- services
--------------------------------------------------------------------
local services = {}

local function service(name, build)
	local s = Instance.new(name)
	if build then build(s) end
	services[name] = s
	return s
end

local TweenService = service("TweenService")
TweenService._methods.Create = function(_, obj, info, props)
	local tween
	tween = {
		Play = function()
			for k, v in pairs(props) do obj[k] = v end
		end,
		Pause = function() end,
		Cancel = function() end,
		Completed = newSignal(),
		Finish = function() tween.Completed:Fire(Enum.PlaybackState.Completed) end,
	}
	M.tweens = M.tweens or {}
	table.insert(M.tweens, tween)
	return tween
end

local UIS = service("UserInputService", function(s)
	s.TouchEnabled = false
	s.KeyboardEnabled = true
end)
UIS.InputBegan   = newSignal()
UIS.InputChanged = newSignal()
UIS.InputEnded   = newSignal()
M.UIS = UIS

local RunService = service("RunService")
RunService.RenderStepped = newSignal()
RunService.Heartbeat = newSignal()
RunService._methods.IsStudio = function() return false end

local Players = service("Players")
local LocalPlayer = Instance.new("Player")
LocalPlayer.Name = "TestPlayer"
LocalPlayer.DisplayName = "Test Player"
LocalPlayer.UserId = 1
Instance.new("PlayerGui", LocalPlayer)
Players.LocalPlayer = LocalPlayer
Players._methods.GetUserThumbnailAsync = function() return "rbxassetid://0" end

-- a small roster the PlayerList tests can add to and remove from
local roster = { LocalPlayer }
Players._methods.GetPlayers = function() return table.clone(roster) end
Players.PlayerAdded = newSignal()
Players.PlayerRemoving = newSignal()

function M.addPlayer(name, displayName)
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = displayName or name
	player.UserId = #roster + 1
	table.insert(roster, player)
	Players.PlayerAdded:Fire(player)
	return player
end

function M.removePlayer(player)
	for i, entry in ipairs(roster) do
		if entry == player then table.remove(roster, i); break end
	end
	Players.PlayerRemoving:Fire(player)
end

M.roster = roster

-- tiny JSON codec
local function jsonEncode(value)
	local t = type(value)
	if t == "nil" then return "null"
	elseif t == "boolean" then return tostring(value)
	elseif t == "number" then return tostring(value)
	elseif t == "string" then return '"' .. value:gsub('[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' })[c]
				or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	elseif t == "table" then
		local isArray = #value > 0
		local parts = {}
		if isArray then
			for _, v in ipairs(value) do table.insert(parts, jsonEncode(v)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(value) do table.insert(keys, tostring(k)) end
		table.sort(keys)
		for _, k in ipairs(keys) do
			table.insert(parts, jsonEncode(k) .. ":" .. jsonEncode(value[k] ~= nil and value[k] or value[tonumber(k)]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("cannot encode " .. t)
end

local function jsonDecode(str)
	local pos = 1
	local function skip() while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end end
	local parseValue
	local function parseString()
		pos = pos + 1
		local out = {}
		while true do
			local c = str:sub(pos, pos)
			if c == '"' then pos = pos + 1; break end
			if c == "\\" then
				local n = str:sub(pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if map[n] then out[#out + 1] = map[n]; pos = pos + 2
				elseif n == "u" then
					out[#out + 1] = string.char(tonumber(str:sub(pos + 2, pos + 5), 16) % 256); pos = pos + 6
				else pos = pos + 2 end
			else
				out[#out + 1] = c; pos = pos + 1
			end
		end
		return table.concat(out)
	end
	parseValue = function()
		skip()
		local c = str:sub(pos, pos)
		if c == "{" then
			pos = pos + 1
			local obj = {}
			skip()
			if str:sub(pos, pos) == "}" then pos = pos + 1; return obj end
			while true do
				skip()
				local k = parseString()
				skip(); pos = pos + 1 -- colon
				obj[k] = parseValue()
				skip()
				local d = str:sub(pos, pos); pos = pos + 1
				if d == "}" then break end
			end
			return obj
		elseif c == "[" then
			pos = pos + 1
			local arr = {}
			skip()
			if str:sub(pos, pos) == "]" then pos = pos + 1; return arr end
			while true do
				table.insert(arr, parseValue())
				skip()
				local d = str:sub(pos, pos); pos = pos + 1
				if d == "]" then break end
			end
			return arr
		elseif c == '"' then return parseString()
		elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
		elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
		elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
		else
			local s2, e2 = str:find("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			local num = tonumber(str:sub(s2, e2))
			pos = e2 + 1
			return num
		end
	end
	return parseValue()
end

local HttpService = service("HttpService")
HttpService._methods.JSONEncode = function(_, v) return jsonEncode(v) end
HttpService._methods.JSONDecode = function(_, v) return jsonDecode(v) end

service("CoreGui")

local Gui = service("GuiService")
Gui.TopbarInset = Rect.new(0, 0, 0, 44)
Gui._methods.GetGuiInset = function() return vec2(0, 36), vec2(0, 0) end
service("TextService")

game = Instance.new("DataModel")
game._methods.GetService = function(_, name)
	if not services[name] then services[name] = Instance.new(name) end
	return services[name]
end
game._methods.HttpGet = function() return "" end
workspace = Instance.new("Workspace")

--------------------------------------------------------------------
-- fake executor file IO (in memory)
--------------------------------------------------------------------
local files, folders = {}, {}
function writefile(path, contents) files[path] = contents end
function readfile(path) return files[path] or error("no file " .. path) end
function isfile(path) return files[path] ~= nil end
function delfile(path) files[path] = nil end
function isfolder(path) return folders[path] == true end
function makefolder(path) folders[path] = true end
function listfiles(dir)
	local out = {}
	for path in pairs(files) do
		if path:sub(1, #dir + 1) == dir .. "/" then table.insert(out, path) end
	end
	return out
end
M.files = files

return M
