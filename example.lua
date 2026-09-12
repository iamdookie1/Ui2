--[[
	Onyx UI — feature demo
	Run this after loading the library:

		loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/example.lua"))()
]]

local Onyx = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/Ui.lua"))()

local Window = Onyx:CreateWindow({
	Title    = "Onyx",
	SubTitle = "demo build",
	Size     = UDim2.fromOffset(660, 450),
	Keybind  = Enum.KeyCode.RightShift,
})

Onyx:Watermark({ Text = "Onyx", ShowFPS = true })

--------------------------------------------------------------------
-- Main
--------------------------------------------------------------------
-- Icon accepts an asset id ("rbxassetid://123", or the number), or any single
-- character to draw as text. Left off here so the demo has nothing to load.
local Main    = Window:CreateTab({ Title = "Main" })
local Visuals = Window:CreateTab({ Title = "Visuals" })
local Player  = Window:CreateTab({ Title = "Player" })
local Advanced = Window:CreateTab({ Title = "Advanced" })
local Debug   = Window:CreateTab({ Title = "Debug" })

local Combat = Main:CreateSection("Combat")

Combat:Toggle({
	Title       = "Silent Aim",
	Description = "Redirects shots toward the closest valid target.",
	Flag        = "SilentAim",
	Default     = false,
	Callback    = function(state)
		Onyx:Notify({ Title = "Silent Aim", Content = state and "Enabled" or "Disabled", Duration = 2 })
	end,
})

Combat:Slider({
	Title     = "Field of View",
	Min       = 0,
	Max       = 360,
	Default   = 120,
	Increment = 5,
	Suffix    = "\u{00B0}",
	Flag      = "AimFOV",
})

Combat:Slider({
	Title     = "Smoothing",
	Min       = 0,
	Max       = 1,
	Default   = 0.25,
	Increment = 0.05,
	Flag      = "AimSmoothing",
})

Combat:Dropdown({
	Title   = "Hit Part",
	Values  = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" },
	Default = "Head",
	Search  = true,
	Flag    = "HitPart",
})

Combat:Keybind({
	Title    = "Aim Key",
	Default  = Enum.KeyCode.E,
	Mode     = "Hold",
	Flag     = "AimKey",
	Callback = function(held) print("aim key held:", held) end,
})

local Targeting = Main:CreateSection("Targeting")

Targeting:Dropdown({
	Title  = "Ignore",
	Multi  = true,
	Values = { "Teammates", "Friends", "Downed", "Invisible" },
	Default = { "Teammates", "Friends" },
	Flag   = "IgnoreList",
})

Targeting:Paragraph({
	Title   = "How targeting works",
	Content = "Targets are scored by distance to your crosshair first and world distance second. Anything in the ignore list is skipped before scoring.",
})

-- text that keeps itself current: pass a function instead of a string
Targeting:Label({
	Title = function()
		return "Players in server: " .. #game:GetService("Players"):GetPlayers()
	end,
})

Targeting:Paragraph({
	Title    = "Live status",
	Content  = function()
		return string.format("Aim FOV %d\u{00B0}  ·  hit part %s  ·  smoothing %.2f",
			Onyx.Flags.AimFOV or 0,
			tostring(Onyx.Flags.HitPart),
			Onyx.Flags.AimSmoothing or 0)
	end,
	Interval = 0.2,
})

Targeting:Button({
	Title       = "Rebuild target cache",
	Description = "Rescans every player in the server.",
	Callback    = function()
		Onyx:Notify({ Title = "Cache rebuilt", Content = "42 targets indexed.", Type = "success" })
	end,
})

-- Mini elements take half a row, so two sit side by side. Buttons, toggles,
-- keybinds and colour pickers can be mini; sliders, dropdowns and inputs
-- need the full width and ignore it.
Targeting:Toggle({ Title = "Visible only", Mini = true, Flag = "VisibleOnly" })
Targeting:Toggle({ Title = "Walls",        Mini = true, Flag = "ThroughWalls" })

Targeting:Button({ Title = "Freeze",  Mini = true, Callback = function() end })
Targeting:Button({ Title = "Release", Mini = true, Callback = function() end })

Targeting:Keybind({ Title = "Lock",  Mini = true, Default = Enum.KeyCode.Q })
Targeting:Colorpicker({ Title = "Tag", Mini = true, Default = Color3.fromRGB(120, 90, 255) })

--------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------
local Esp = Visuals:CreateSection("ESP")

Esp:Toggle({ Title = "Enabled", Flag = "EspEnabled", Default = true })
Esp:Dropdown({
	Title   = "Elements",
	Multi   = true,
	Values  = { "Box", "Name", "Health Bar", "Distance", "Tracer" },
	Default = { "Box", "Name" },
	Flag    = "EspElements",
})
Esp:Colorpicker({ Title = "Box Colour",   Default = Color3.fromRGB(235, 235, 245), Flag = "EspBox" })
Esp:Colorpicker({ Title = "Fill Colour",  Default = Color3.fromRGB(120, 90, 255), Transparency = 0.75, Flag = "EspFill" })
Esp:Slider({ Title = "Max Distance", Min = 50, Max = 5000, Default = 1500, Increment = 50, Suffix = " studs", Flag = "EspDistance" })

local World = Visuals:CreateSection("World")
World:Toggle({ Title = "Fullbright", Flag = "Fullbright" })
World:Slider({ Title = "Ambient", Min = 0, Max = 1, Default = 0.5, Increment = 0.05, Flag = "Ambient" })
World:Divider()
World:Label("Changes apply immediately and reset on rejoin.")

--------------------------------------------------------------------
-- Player
--------------------------------------------------------------------
local Movement = Player:CreateSection("Movement")
Movement:Slider({ Title = "Walk Speed", Min = 16, Max = 250, Default = 16, Flag = "WalkSpeed" })
Movement:Slider({ Title = "Jump Power", Min = 50, Max = 350, Default = 50, Flag = "JumpPower" })
Movement:Toggle({ Title = "Infinite Jump", Flag = "InfJump" })
Movement:Keybind({ Title = "Fly", Default = Enum.KeyCode.F, Flag = "FlyKey" })

local Danger = Player:CreateSection("Danger zone")
Danger:Button({
	Title       = "Reset Character",
	Description = "Kills your character.",
	Confirm     = true,
	Callback    = function()
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = 0 end
	end,
})

--------------------------------------------------------------------
-- Advanced
--------------------------------------------------------------------
local People = Advanced:CreateSection("Server")

People:PlayerList({
	Title   = "Players",
	Height  = 170,
	Actions = {
		{ Title = "TP", Callback = function(player)
			local character = player.Character
			local target = character and character:FindFirstChild("HumanoidRootPart")
			local me = game:GetService("Players").LocalPlayer.Character
			local root = me and me:FindFirstChild("HumanoidRootPart")
			if target and root then root.CFrame = target.CFrame end
		end },
		{ Title = "Watch", Callback = function(player)
			workspace.CurrentCamera.CameraSubject = player.Character
		end },
	},
	OnSelect = function(player)
		Onyx:Notify({ Title = "Selected", Content = player.DisplayName, Duration = 2 })
	end,
})

local Filters = Advanced:CreateSection("Filters")

Filters:Segmented({
	Title    = "Mode",
	Values   = { "Legit", "Semi", "Rage" },
	Default  = "Legit",
	Flag     = "AimMode",
})

Filters:RangeSlider({
	Title      = "Target distance",
	Min        = 0,
	Max        = 1000,
	DefaultMin = 50,
	DefaultMax = 600,
	Increment  = 10,
	Suffix     = "m",
	Flag       = "TargetRange",
})

Filters:Tags({
	Title       = "Ignore names",
	Placeholder = "add and press enter",
	Default     = { "friend1" },
	Flag        = "IgnoreNames",
})

local Scores = Advanced:CreateSection({ Title = "Session", Collapsible = true })

local kills, started = 0, os.clock()

Scores:Stats({
	Columns = 3,
	Items = {
		{ Label = "Kills",   Value = function() return kills end },
		{ Label = "Uptime",  Value = function()
			return string.format("%d:%02d", math.floor((os.clock() - started) / 60), math.floor((os.clock() - started) % 60))
		end },
		{ Label = "Players", Value = function()
			return #game:GetService("Players"):GetPlayers()
		end },
	},
})

Scores:Graph({
	Title    = "Frames per second",
	Height   = 80,
	Points   = 48,
	Source   = function() return 1 / math.max(game:GetService("RunService").Heartbeat:Wait(), 1 / 240) end,
	Interval = 0.5,
	Suffix   = " fps",
})

local loadBar = Scores:Progress({ Title = "Farm cycle", Max = 100, Value = 0 })

Scores:Button({ Title = "Run a cycle", Callback = function()
	for step = 0, 100, 10 do
		loadBar:Set(step)
		task.wait(0.08)
	end
end })

local Payload = Advanced:CreateSection({ Title = "Payload", Collapsible = true, Collapsed = true })

Payload:Textarea({
	Title       = "Webhook body",
	Height      = 100,
	Placeholder = "one entry per line",
	Flag        = "WebhookBody",
})

local drops = Payload:Table({
	Title   = "Recent drops",
	Columns = { { Title = "Item", Width = 0.5 }, "Rarity", "Value" },
	Height  = 140,
	Empty   = "No drops yet.",
	Actions = { { Title = "Sell", Callback = function(row)
		Onyx:Notify({ Title = "Sold", Content = tostring(row[1]), Type = "success", Duration = 2 })
	end } },
})

drops:SetRows({
	{ "Blade of Dawn", "Legendary", "12,400" },
	{ "Iron Shield",   "Common",    "80" },
	{ "Void Shard",    "Rare",      "3,150" },
})

--------------------------------------------------------------------
-- Debug
--
-- Config saving, the accent, the toggle key and the notification corner all
-- live behind the settings icon in the topbar now, so this tab does not
-- repeat them. Add your own settings with Window:SettingsSection().
--------------------------------------------------------------------
local Log = Debug:CreateSection("Console")

local console = Log:Console({
	Title       = "Output",
	Height      = 150,
	MaxLines    = 100,
	Placeholder = "Nothing logged yet.",
	Lines       = { "Onyx " .. Onyx.Version .. " ready." },
})

Log:Button({ Title = "Log a line",  Callback = function() console:Log("plain line at", os.date("%X")) end })
Log:Button({ Title = "Log a batch", Callback = function()
	console:Info("scanning players")
	console:Success("3 targets resolved")
	console:Warn("2 ignored by filter")
	console:Error("1 failed to resolve")
end })

-- every element callback can report into the console
Onyx:GetOption("SilentAim").Callback = function(state)
	console:Info("silent aim " .. (state and "on" or "off"))
end

local Cmd = Debug:CreateSection("Commands")

local term = Cmd:Terminal({
	Title  = "Console",
	Height = 150,
})

term:Register("speed", {
	Description = "set walk speed",
	Usage       = "speed <n>",
	Callback    = function(args)
		local value = tonumber(args[1])
		if not value then return false, "speed needs a number" end
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return false, "no character" end
		humanoid.WalkSpeed = value
		return "walk speed is now " .. value
	end,
})

term:Register("count", {
	Description = "count players in the server",
	Callback    = function()
		return #game:GetService("Players"):GetPlayers() .. " players"
	end,
})

term:Register("notify", {
	Description = "send a test notification",
	Usage       = "notify <text>",
	Callback    = function(args)
		Onyx:Notify({ Title = "Terminal", Content = table.concat(args, " ") })
		return true
	end,
})

local Toasts = Debug:CreateSection("Notifications")

for _, kind in ipairs({ "default", "info", "success", "warning", "error" }) do
	Toasts:Button({
		Title    = "Show " .. kind,
		Callback = function()
			Onyx:Notify({
				Title    = kind:sub(1, 1):upper() .. kind:sub(2),
				Content  = "Hover to hold the countdown, click to dismiss.",
				Type     = kind,
				Duration = 5,
			})
		end,
	})
end

--------------------------------------------------------------------
-- Settings page additions
--------------------------------------------------------------------
local Script = Window:SettingsSection("Script")

Script:Toggle({ Title = "Verbose log", Mini = true, Callback = function(state)
	console:Info("verbose logging " .. (state and "on" or "off"))
end })
Script:Toggle({ Title = "Silent mode", Mini = true })

Script:Button({ Title = "Rejoin",  Mini = true, Callback = function() end })
Script:Button({ Title = "Servers", Mini = true, Callback = function() end })

Script:Label({ Title = function()
	return "Auto save is " .. (Onyx.Settings.AutoSave and "on" or "off")
end })

-- a loading overlay, closed once the script is ready
local loader = Window:Loading({ Title = "Onyx", Content = "Setting things up" })
task.delay(1.2, function() loader:Close() end)

Onyx:Notify({
	Title    = "Onyx loaded",
	Content  = "Right Shift or the topbar diamond hides it. Config lives behind the settings icon.",
	Duration = 5,
	Type     = "success",
})
