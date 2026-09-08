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
local Config  = Window:CreateTab({ Title = "Config" })

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

Targeting:Button({
	Title       = "Rebuild target cache",
	Description = "Rescans every player in the server.",
	Callback    = function()
		Onyx:Notify({ Title = "Cache rebuilt", Content = "42 targets indexed.", Type = "success" })
	end,
})

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
-- Config
--------------------------------------------------------------------
local Saves = Config:CreateSection("Configuration")

local configName = Saves:Input({
	Title       = "Config name",
	Placeholder = "default",
	Default     = "default",
	Flag        = "ConfigName",
})

local configList = Saves:Dropdown({
	Title  = "Saved configs",
	Values = Onyx:ListConfigs(),
	Search = true,
})

Saves:Button({ Title = "Save", Callback = function()
	local ok, err = Onyx:SaveConfig(configName:Get())
	Onyx:Notify({
		Title   = ok and "Config saved" or "Save failed",
		Content = ok and configName:Get() or tostring(err),
		Type    = ok and "success" or "error",
	})
	configList:SetValues(Onyx:ListConfigs())
end })

Saves:Button({ Title = "Load", Callback = function()
	local target = configList:Get() or configName:Get()
	local ok, err = Onyx:LoadConfig(target)
	Onyx:Notify({
		Title   = ok and "Config loaded" or "Load failed",
		Content = ok and tostring(target) or tostring(err),
		Type    = ok and "success" or "error",
	})
end })

Saves:Button({ Title = "Delete", Confirm = true, Callback = function()
	local target = configList:Get() or configName:Get()
	Onyx:DeleteConfig(target)
	configList:SetValues(Onyx:ListConfigs())
end })

local Interface = Config:CreateSection("Interface")

Interface:Colorpicker({
	Title    = "Accent",
	Default  = Color3.fromRGB(232, 232, 240),
	Callback = function(color) Onyx:SetAccent(color) end,
})

Interface:Keybind({
	Title    = "Toggle UI",
	Default  = Enum.KeyCode.RightShift,
	Callback = function() Window:Toggle() end,
})

Interface:Button({ Title = "Unload", Confirm = true, Callback = function() Onyx:Unload() end })

Onyx:Notify({
	Title    = "Onyx loaded",
	Content  = "Press Right Shift to hide the interface.",
	Duration = 5,
	Type     = "success",
})
