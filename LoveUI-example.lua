--!nonstrict
--[[
	LoveUI · example script

	Paste this into your executor. It loads the library straight from
	GitHub, builds a sidebar with three tabs and shows every element the
	library ships with.

	The window starts closed. Drag the pink handle on the left edge of your
	screen to the right to open it, or press Right Shift.
]]

local Love = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/LoveUI.lua"))()

-- ================================================================
--  WINDOW
-- ================================================================

local Window = Love:CreateWindow({
	Title     = "Love Example",
	SubTitle  = "v" .. Love.Version,
	Theme     = "Rose",          -- Rose · Bubblegum · Wine · Midnight · Blush · Sakura
	Width     = 290,             -- how far the sidebar slides in
	Keybind   = Enum.KeyCode.RightShift,
	StartOpen = false,           -- true to have it already open on load
})

-- ================================================================
--  MAIN
-- ================================================================

local Main = Window:CreateTab("Main")

do
	local Info = Main:CreateSection("Welcome")

	Info:Label("Drag the handle, or press Right Shift.")
	Info:Paragraph({
		Title   = "About",
		Content = "LoveUI is a sidebar, not a floating panel. It lives off the "
			.. "left edge of the screen so it never covers the middle of your "
			.. "game, and every theme it ships with is some shade of pink.",
	})

	local Combat = Main:CreateSection("Combat")

	Combat:Toggle({
		Title       = "Aimbot",
		Description = "Locks onto the closest player in view.",
		Default     = false,
		Flag        = "Aimbot",
		Callback    = function(on)
			print("aimbot:", on)
		end,
	})

	Combat:Slider({
		Title     = "FOV",
		Min       = 20,
		Max       = 400,
		Default   = 120,
		Increment = 5,
		Suffix    = "px",
		Flag      = "AimFov",
		Callback  = function(value)
			print("fov:", value)
		end,
	})

	Combat:Dropdown({
		Title    = "Target part",
		Values   = { "Head", "HumanoidRootPart", "Torso" },
		Default  = "Head",
		Flag     = "AimPart",
		Callback = function(part)
			print("target:", part)
		end,
	})

	-- Multi = true keeps a list instead of a single pick
	Combat:Dropdown({
		Title    = "Ignore",
		Values   = { "Friends", "Team", "Downed", "Behind walls" },
		Multi    = true,
		Flag     = "AimIgnore",
		Callback = function(list)
			print("ignoring " .. #list .. " things")
		end,
	})

	Combat:ColorPicker({
		Title    = "Tracer colour",
		Default  = Color3.fromRGB(244, 114, 182),
		Flag     = "TracerColour",
		Callback = function(colour)
			print("tracer:", colour)
		end,
	})

	Combat:Button({
		Title       = "Fire once",
		Description = "Runs the callback a single time.",
		Callback    = function()
			Window:Notify({
				Title    = "Fired",
				Content  = "Targeting " .. tostring(Love:GetFlag("AimPart")),
				Duration = 3,
			})
		end,
	})
end

-- ================================================================
--  PLAYER
-- ================================================================

local Player = Window:CreateTab("Player")

do
	local Movement = Player:CreateSection("Movement")

	local humanoid
	local function Humanoid()
		local character = game:GetService("Players").LocalPlayer.Character
		humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		return humanoid
	end

	Movement:Slider({
		Title     = "Walk speed",
		Min       = 16,
		Max       = 200,
		Default   = 16,
		Increment = 1,
		Flag      = "WalkSpeed",
		Callback  = function(value)
			local h = Humanoid()
			if h then h.WalkSpeed = value end
		end,
	})

	Movement:Slider({
		Title     = "Jump power",
		Min       = 50,
		Max       = 350,
		Default   = 50,
		Increment = 5,
		Flag      = "JumpPower",
		Callback  = function(value)
			local h = Humanoid()
			if h then h.JumpPower = value end
		end,
	})

	Movement:Divider()

	Movement:Button({
		Title    = "Reset character",
		Callback = function()
			local h = Humanoid()
			if h then h.Health = 0 end
		end,
	})

	local Misc = Player:CreateSection("Misc")

	Misc:Input({
		Title       = "Nickname",
		Placeholder = "type here",
		Default     = "",
		Flag        = "Nickname",
		Callback    = function(text)
			print("nickname:", text)
		end,
	})

	Misc:Keybind({
		Title    = "Panic key",
		Default  = Enum.KeyCode.P,
		Flag     = "PanicKey",
		Callback = function()
			Love:Notify({ Title = "Panic", Content = "Everything off.", Duration = 2 })
		end,
	})

	Misc:Textarea({
		Title       = "Target list",
		Placeholder = "one name per line",
		Height      = 84,
		Flag        = "Targets",
		Callback    = function(text)
			print("targets:", text)
		end,
	})
end

-- ================================================================
--  STATUS
-- ================================================================

local Status = Window:CreateTab("Status")

do
	local Live = Status:CreateSection("Live")

	local ping = Live:Stat({ Title = "Ping", Value = "-" })
	local fps  = Live:Stat({ Title = "FPS", Value = "-" })
	local players = Live:Stat({ Title = "Players", Value = "-" })

	local Work = Status:CreateSection("Work")

	local bar = Work:Progress({ Title = "Scan", Default = 0 })
	local log = Work:Console({ Title = "Output", Height = 110, MaxLines = 60 })

	Work:Button({
		Title       = "Run a scan",
		Description = "Fills the bar and writes to the console.",
		Callback    = function()
			log:Append("scan started")
			task.spawn(function()
				for i = 1, 10 do
					task.wait(0.15)
					bar:Set(i / 10)
					log:Append("checked batch " .. i)
				end
				log:Success("scan finished")
			end)
		end,
	})

	Work:Button({
		Title    = "Clear output",
		Callback = function()
			log:Clear()
			bar:Set(0)
		end,
	})

	-- keep the stat rows current
	task.spawn(function()
		local Stats = game:GetService("Stats")
		local RunService = game:GetService("RunService")
		local Players = game:GetService("Players")
		while task.wait(1) do
			if Love.Unloaded then break end
			local ok, ms = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			ping:Set(ok and (math.floor(ms) .. "ms") or "-")
			fps:Set(math.floor(1 / RunService.Heartbeat:Wait()))
			players:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
		end
	end)
end

-- ================================================================
--  THEMES
-- ================================================================

local Looks = Window:CreateTab("Themes")

do
	local Palette = Looks:CreateSection("Palette")

	Palette:Label("Every palette has pink in it somewhere.")

	-- ThemeDropdown is wired to the library rather than to you: pick a
	-- theme in the header, or call Love:SetTheme anywhere, and this row
	-- moves with it.
	Palette:ThemeDropdown({ Title = "Theme" })

	Palette:Button({
		Title       = "Next theme",
		Description = "Cycles; watch the dropdown above follow.",
		Callback    = function()
			Love:NextTheme()
		end,
	})

	local Control = Looks:CreateSection("Window")

	Control:Keybind({
		Title = "Toggle key",
		Default = Enum.KeyCode.RightShift,
		-- Callback fires when the key is pressed; ChangedCallback fires
		-- when it is rebound, which is what we want here.
		ChangedCallback = function(key)
			Window:SetToggleKey(key)
		end,
	})

	Control:Slider({
		Title     = "Scale",
		Description = "Makes the whole sidebar bigger or smaller.",
		Min       = 0.8,
		Max       = 1.6,
		Default   = 1,
		Increment = 0.05,
		Rounding  = 2,
		Callback  = function(value)
			Window:SetScale(value)
		end,
	})

	Control:Button({
		Title    = "Close sidebar",
		Callback = function()
			Window:SetOpen(false)
		end,
	})

	Control:Button({
		Title       = "Unload",
		Description = "Removes the interface and every connection.",
		Callback    = function()
			Love:Unload()
		end,
	})
end

-- ================================================================

Main:Select()

Love:Notify({
	Title    = "LoveUI",
	Content  = "Loaded. Drag the handle or press Right Shift.",
	Duration = 5,
})
