--!nonstrict
--[[
	Void · example script

	Paste this into your executor. It loads the library from GitHub and
	builds a window with four tabs, covering every element that ships.

	Right Shift shows and hides it. Drag the title bar to move it, press
	the dash to fold it to its title bar, the cross to send it away.
]]

local Void = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/VoidUI.lua"))()

local Window = Void:CreateWindow({
	Title    = "Void Example",
	SubTitle = "v" .. Void.Version,
	Size     = UDim2.fromOffset(580, 420),
	Keybind  = Enum.KeyCode.RightShift,
	Status   = "idle",
	Scope    = "game",          -- "game" files configs per place, "universal" shares them
})

-- ================================================================
--  MAIN
-- ================================================================

local Main = Window:CreateTab("Main")

do
	local About = Main:CreateSection("About")

	About:Paragraph({
		Title   = "Void",
		Content = "No colour, no gradients, no rounded corners to speak of. "
			.. "Black, four greys and one white accent that marks every piece "
			.. "of state there is. Values are set in mono so a column of "
			.. "numbers lines up.",
	})

	local Combat = Main:CreateSection("Combat")

	Combat:Toggle({
		Title       = "Aimbot",
		Description = "Locks onto the closest player in view.",
		Default     = false,
		Flag        = "Aimbot",
		Callback    = function(on)
			Window:SetStatus(on and "aimbot on" or "idle")
		end,
	})

	Combat:Slider({
		Title     = "Field of view",
		Min       = 20,
		Max       = 400,
		Default   = 120,
		Increment = 5,
		Suffix    = "px",
		Flag      = "AimFov",
	})

	Combat:Dropdown({
		Title    = "Target part",
		Values   = { "Head", "HumanoidRootPart", "Torso" },
		Default  = "Head",
		Flag     = "AimPart",
	})

	Combat:Dropdown({
		Title    = "Ignore",
		Values   = { "Friends", "Team", "Downed", "Behind walls" },
		Multi    = true,
		Flag     = "AimIgnore",
		Callback = function(list)
			Window:SetStatus("ignoring " .. #list)
		end,
	})

	Combat:Segmented({
		Title    = "Smoothing",
		Values   = { "Off", "Soft", "Hard" },
		Default  = "Soft",
		Flag     = "AimSmooth",
	})

	Combat:ColorPicker({
		Title   = "Tracer colour",
		Default = Color3.fromRGB(255, 255, 255),
		Flag    = "TracerColour",
	})

	-- Half = true puts two elements on one line
	local Quick = Main:CreateSection("Quick")
	Quick:Toggle({ Title = "Tracers", Half = true, Flag = "Tracers" })
	Quick:Toggle({ Title = "Boxes", Half = true, Flag = "Boxes" })
	Quick:Button({ Title = "Refresh", Half = true, Callback = function() end })
	Quick:Button({
		Title    = "Panic",
		Half     = true,
		Confirm  = true,
		Callback = function()
			Void:Notify({ Title = "Panic", Content = "Everything off.", Warn = true })
		end,
	})
end

-- ================================================================
--  PLAYER
-- ================================================================

local Player = Window:CreateTab("Player")

do
	local Movement = Player:CreateSection("Movement")

	local function humanoid()
		local character = game:GetService("Players").LocalPlayer.Character
		return character and character:FindFirstChildWhichIsA("Humanoid")
	end

	Movement:Slider({
		Title    = "Walk speed",
		Min      = 16,
		Max      = 200,
		Default  = 16,
		Flag     = "WalkSpeed",
		Callback = function(value)
			local human = humanoid()
			if human then human.WalkSpeed = value end
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
			local human = humanoid()
			if human then human.JumpPower = value end
		end,
	})

	Movement:Divider()

	Movement:Keybind({
		Title    = "Reset key",
		Default  = Enum.KeyCode.P,
		Flag     = "ResetKey",
		Callback = function()
			local human = humanoid()
			if human then human.Health = 0 end
		end,
	})

	local Notes = Player:CreateSection({ Title = "Notes", Collapsible = true })

	Notes:Input({ Title = "Nickname", Placeholder = "type here", Flag = "Nickname" })
	Notes:Textarea({
		Title       = "Target list",
		Placeholder = "one name per line",
		Height      = 76,
		Flag        = "Targets",
	})
end

-- ================================================================
--  STATUS
-- ================================================================

local Status = Window:CreateTab("Status")

do
	local Live = Status:CreateSection("Live")

	local ping = Live:Stat({ Title = "Ping", Value = "-" })
	local fps = Live:Stat({ Title = "FPS", Value = "-" })
	local people = Live:Stat({ Title = "Players", Value = "-" })

	local Work = Status:CreateSection("Work")

	local bar = Work:Progress({ Title = "Scan", Default = 0 })
	local log = Work:Console({ Title = "Output", Height = 108, MaxLines = 60 })

	Work:Button({
		Title       = "Run a scan",
		Description = "Fills the bar and writes to the console.",
		Callback    = function()
			log:Append("scan started")
			task.spawn(function()
				for step = 1, 10 do
					task.wait(0.12)
					bar:Set(step / 10)
					log:Append("batch " .. step .. " clear")
				end
				log:Good("scan finished")
				Void:Notify({ Title = "Scan", Content = "Nothing found.", Duration = 3 })
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

	task.spawn(function()
		local Stats = game:GetService("Stats")
		local RunService = game:GetService("RunService")
		local Players = game:GetService("Players")
		while task.wait(1) do
			if Void.Unloaded then break end
			local ok, ms = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			ping:Set(ok and (math.floor(ms) .. "ms") or "-")
			fps:Set(math.floor(1 / RunService.Heartbeat:Wait()))
			people:Set(#Players:GetPlayers() .. "/" .. Players.MaxPlayers)
		end
	end)
end

-- ================================================================
--  CONFIG
-- ================================================================

local Config = Window:CreateTab("Config")

do
	local Files = Config:CreateSection("Files")

	local name = Files:Input({ Title = "Config name", Placeholder = "default" })
	local list = Files:Dropdown({ Title = "Saved", Values = Void:ListConfigs() })

	local function refresh()
		list:SetValues(Void:ListConfigs())
	end

	Files:Button({
		Title    = "Save",
		Half     = true,
		Callback = function()
			local ok, why = Void:SaveConfig(name:Get() ~= "" and name:Get() or "default")
			Void:Notify({
				Title = ok and "Saved" or "Could not save",
				Content = (not ok) and tostring(why) or nil,
				Warn = not ok,
			})
			refresh()
		end,
	})

	Files:Button({
		Title    = "Load",
		Half     = true,
		Callback = function()
			local picked = list:Get()
			if not picked then
				Void:Notify({ Title = "Pick a config first", Warn = true })
				return
			end
			local ok, why = Void:LoadConfig(picked)
			Void:Notify({
				Title = ok and "Loaded" or "Could not load",
				Content = ok and picked or tostring(why),
				Warn = not ok,
			})
		end,
	})

	Files:Button({
		Title    = "Delete",
		Confirm  = true,
		Callback = function()
			local picked = list:Get()
			if picked then
				Void:DeleteConfig(picked)
				refresh()
			end
		end,
	})

	local Look = Config:CreateSection("Look")

	Look:Label("The accent is white. It does not have to be.")
	Look:ColorPicker({
		Title    = "Accent",
		Default  = Void.Ink.Edge,
		Callback = function(colour) Void:SetAccent(colour) end,
	})

	local Window2 = Config:CreateSection("Window")

	Window2:Keybind({
		Title           = "Toggle key",
		Default         = Enum.KeyCode.RightShift,
		ChangedCallback = function(key) Window:SetToggleKey(key) end,
	})

	Window2:Button({
		Title    = "Fold",
		Half     = true,
		Callback = function() Window:Fold() end,
	})

	Window2:Button({
		Title    = "Unload",
		Half     = true,
		Confirm  = true,
		Callback = function() Void:Unload() end,
	})
end

-- ================================================================

Main:Select()

Void:Notify({
	Title    = "Void",
	Content  = "Loaded. Right Shift to hide.",
	Duration = 4,
})
