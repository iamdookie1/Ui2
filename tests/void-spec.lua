-- Void, exercised against the mock Roblox environment.
assert(pcall(function() Instance.new("Frame").Text = "" end) == false,
	"the mock must reject invalid properties")

local ok, Void = pcall(LoadVoid)
assert(ok, "library failed to load: " .. tostring(Void))
print("loaded " .. Void.Name .. " v" .. Void.Version)

local fired = {}
local function note(key, value) fired[key] = value end

local function find(pred)
	for _, inst in ipairs(MOCK.allInstances) do
		if inst.Parent and pred(inst) then return inst end
	end
end

--------------------------------------------------------------------
-- window chrome
--------------------------------------------------------------------
local Window = Void:CreateWindow({
	Title = "Void Demo", SubTitle = "v1", Size = UDim2.fromOffset(560, 400),
	Keybind = Enum.KeyCode.RightShift, Status = "ready",
})
assert(Window and Window.Frame, "no window frame")

local frame = Window.Frame
local bar = frame:FindFirstChild("Bar")
local body = frame:FindFirstChild("Body")
local strip = frame:FindFirstChild("Status")
assert(bar and body and strip, "the window is missing its chrome")
assert(bar:FindFirstChild("Mark"), "no library mark in the title bar")
assert(bar:FindFirstChild("Title").Text == "Void Demo", "wrong title")
assert(body:FindFirstChild("Rail"), "no tab rail")
assert(body:FindFirstChild("Marker"), "no rail marker")
assert(strip:FindFirstChild("Hint").Text == "RIGHTSHIFT", "the strip should name the keybind")

-- monochrome: the accent is white, and nothing in the palette has colour
do
	local edge = Void.Ink.Edge
	assert(edge.R == 1 and edge.G == 1 and edge.B == 1, "the accent should be white")
	for _, key in ipairs({ "Void", "Panel", "Card", "Lift", "Line", "Text", "Sub", "Mute" }) do
		local shade = Void.Ink[key]
		local _, saturation = shade:ToHSV()
		-- the darks are a touch cool rather than dead neutral, which at
		-- these values is a couple of points of saturation, not a colour
		assert(saturation < 0.2, key .. " has colour in it; this library does not")
	end
end

--------------------------------------------------------------------
-- tabs and sections
--------------------------------------------------------------------
local Main = Window:CreateTab("Main")
local Player = Window:CreateTab({ Title = "Player" })
local Config = Window:CreateTab("Config")
assert(#Window.Tabs == 3, "expected 3 tabs")
assert(Window.ActiveTab == Main, "the first tab should select itself")

local marker = body:FindFirstChild("Marker")
local firstY = marker.Position.Y.Offset
Player:Select()
assert(Window.ActiveTab == Player, "Select did not switch tabs")
assert(Main.Page.Visible == false, "the old page should hide")
assert(marker.Position.Y.Offset > firstY, "the marker should slide to the new tab")
Main:Select()
assert(marker.Position.Y.Offset == firstY, "the marker should slide back")

local Combat = Main:CreateSection("Combat")
local Folded = Main:CreateSection({ Title = "Advanced", Collapsible = true, Open = false })
assert(Folded.Open == false, "a collapsible section should honour Open = false")
Folded:Expand()
assert(Folded.Open == true, "Expand did not open it")
assert(Folded.Container.Visible == true, "an open section should show its items")
Folded:Collapse()
assert(Folded.Open == false and Folded.Container.Visible == false, "Collapse failed")
Folded:SetOpen(true)
assert(Folded.Open == true, "SetOpen failed")

-- a section's own methods must not collide with the element constructors
-- it also carries: Section:Toggle{...} builds a toggle, so collapsing is
-- Collapse and Expand
local built = Folded:Toggle({ Title = "Still a toggle" })
assert(built.Type == "Toggle", "Section:Toggle should build a toggle element")
built:Destroy()
assert(Folded.Open == true, "building a toggle must not have collapsed the section")

--------------------------------------------------------------------
-- elements
--------------------------------------------------------------------
local label = Combat:Label("A plain line")
label:SetText("Changed")
assert(label.Instance.Text == "Changed", "label SetText failed")

local para = Combat:Paragraph({ Title = "Heads up", Content = "Wraps." })
para:SetTitle("New")
para:SetContent("Body")

Combat:Divider()
Combat:Divider("or")

local hits = 0
local button = Combat:Button({ Title = "Kill all", Description = "Removes NPCs",
	Callback = function() hits = hits + 1 end })
button.Instance.MouseButton1Click:Fire()
assert(hits == 1, "button callback did not fire")

-- a confirming button routes through a dialog first
local confirmed = 0
local guarded = Combat:Button({ Title = "Reset", Confirm = true,
	Callback = function() confirmed = confirmed + 1 end })
guarded.Instance.MouseButton1Click:Fire()
assert(confirmed == 0, "a confirm button must not fire straight away")
local runIt = find(function(i) return i.ClassName == "TextButton" and i.Name == "Run it" end)
assert(runIt, "the confirm dialog did not open")
runIt.MouseButton1Click:Fire()
assert(confirmed == 1, "the dialog did not run the callback")
MOCK.step(0.5)

local toggle = Combat:Toggle({ Title = "Aimbot", Flag = "aimbot", Default = false,
	Callback = function(v) note("aimbot", v) end })
assert(Void.Flags.aimbot == false, "toggle did not register its flag")
toggle:Set(true)
assert(fired.aimbot == true and Void:GetFlag("aimbot") == true, "toggle Set failed")
toggle.Instance.MouseButton1Click:Fire()
assert(toggle:Get() == false, "clicking the row should flip it")

local slider = Combat:Slider({ Title = "FOV", Min = 20, Max = 400, Default = 120,
	Increment = 5, Suffix = "px", Flag = "fov", Callback = function(v) note("fov", v) end })
assert(slider:Get() == 120, "slider default wrong")
slider:Set(999)
assert(slider:Get() == 400, "slider must clamp to Max")
slider:Set(0)
assert(slider:Get() == 20, "slider must clamp to Min")
slider:Set(123)
assert(slider:Get() == 125, "slider must snap to Increment")
assert(fired.fov == 125 and Void.Flags.fov == 125, "slider flag or callback wrong")

local drop = Combat:Dropdown({ Title = "Target", Values = { "Head", "Torso" },
	Default = "Head", Flag = "part", Callback = function(v) note("part", v) end })
assert(drop:Get() == "Head", "dropdown default wrong")
drop:Set("Torso")
assert(fired.part == "Torso" and Void.Flags.part == "Torso", "dropdown Set failed")

local input = Combat:Input({ Title = "Name", Placeholder = "type", Flag = "name",
	Callback = function(v) note("name", v) end })
input:Set("hello")
assert(input:Get() == "hello" and Void.Flags.name == "hello", "input Set failed")

local bindHits = 0
local bind = Combat:Keybind({ Title = "Panic", Default = Enum.KeyCode.P, Flag = "panic",
	Callback = function() bindHits = bindHits + 1 end,
	ChangedCallback = function(k) note("rebound", k) end })
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, false)
assert(bindHits == 1, "keybind callback did not fire")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, true)
assert(bindHits == 1, "a processed input must not fire the keybind")
bind:Set(Enum.KeyCode.Q)
assert(fired.rebound == Enum.KeyCode.Q, "ChangedCallback did not fire")

local picker = Combat:ColorPicker({ Title = "Tracer", Default = Color3.fromRGB(255, 0, 0),
	Flag = "tracer", Callback = function(c) note("colour", c) end })
assert(typeof(picker:Get()) == "Color3", "colour picker holds a Color3")
assert(picker:Get().R > 0.9 and picker:Get().B < 0.1, "colour picker lost its default")
picker:Set(Color3.fromRGB(0, 0, 255))
assert(fired.colour and fired.colour.B > 0.9, "colour picker callback wrong")

local area = Player:Textarea({ Title = "Targets", Default = "one\ntwo", Flag = "targets" })
assert(#area.Lines() == 2, "textarea did not split its lines")
area:Set("a\nb\nc")
assert(#area.Lines() == 3 and Void.Flags.targets == "a\nb\nc", "textarea Set failed")

local progress = Player:Progress({ Title = "Scan", Default = 0 })
progress:Set(0.5)
assert(progress:Get() == 0.5, "progress Set failed")
progress:Set(9)
assert(progress:Get() == 1, "progress must clamp")

local log = Player:Console({ Title = "Output", MaxLines = 3 })
log:Append("one")
log:Append("two")
log:Append("three")
log:Append("four")
assert(#log.Lines == 3, "console did not trim to MaxLines")
assert(log.Lines[3].Text == "four", "console dropped the wrong end")
log:Bad("broken")
log:Clear()
assert(#log.Lines == 0, "console Clear failed")
MOCK.step(0.2)

local stat = Player:Stat({ Title = "Ping", Value = "-", Flag = "ping" })
stat:Set("42ms")
assert(stat:Get() == "42ms" and Void.Flags.ping == "42ms", "stat Set failed")

local mode = Player:Segmented({ Title = "Mode", Values = { "Off", "Soft", "Hard" },
	Default = "Off", Flag = "mode", Callback = function(v) note("mode", v) end })
assert(mode:Get() == "Off", "segmented default wrong")
mode:Set("Hard")
assert(fired.mode == "Hard" and Void.Flags.mode == "Hard", "segmented Set failed")

--------------------------------------------------------------------
-- half-width elements pair up
--------------------------------------------------------------------
do
	local Pairs = Player:CreateSection("Pairs")
	local left = Pairs:Toggle({ Title = "Left", Half = true })
	local right = Pairs:Button({ Title = "Right", Half = true })

	local leftCell = left.Instance.Parent
	local rightCell = right.Instance.Parent
	assert(leftCell.Name == "Half" and rightCell.Name == "Half",
		"half elements should sit in half cells")
	assert(leftCell.Parent == rightCell.Parent, "two halves should share one bay")
	assert(leftCell.Size.X.Scale == 0.5, "a half cell should be half the width")

	-- a third half opens a new bay, and a full-width element closes it
	local third = Pairs:Toggle({ Title = "Third", Half = true })
	assert(third.Instance.Parent.Parent ~= leftCell.Parent, "a third half needs a new bay")
	local wide = Pairs:Slider({ Title = "Wide", Min = 0, Max = 10 })
	assert(wide.Instance.Parent.Name ~= "Half", "a full-width element must not go in a bay")
	local after = Pairs:Toggle({ Title = "After", Half = true })
	assert(after.Instance.Parent.Parent ~= third.Instance.Parent.Parent,
		"a full-width element should close the open bay")
end

--------------------------------------------------------------------
-- dropdowns open as popouts, over the window
--------------------------------------------------------------------
do
	drop:SetOpen(true)
	assert(drop.Open == true, "dropdown did not open")

	local panel = find(function(i) return i.Name == "Popout" end)
	assert(panel, "no popout panel")
	assert(panel:FindFirstChild("Head") and panel:FindFirstChild("Torso"),
		"the popout should list every value")
	-- it belongs to the popout layer, not the window, so nothing clips it
	local layer = panel.Parent.Parent
	assert(layer.Name == "Popouts", "a popout must live in the popout layer, not " .. layer.Name)

	panel:FindFirstChild("Head").MouseButton1Click:Fire()
	assert(drop:Get() == "Head", "picking from the popout failed")
	MOCK.step(0.4)
	assert(drop.Open == false, "picking should close a single-select popout")

	-- multi-select keeps the list up and accumulates
	local multi = Combat:Dropdown({ Title = "Ignore", Values = { "A", "B", "C" },
		Multi = true, Flag = "ignore" })
	assert(typeof(multi:Get()) == "table", "a multi dropdown holds a list")
	multi:Select("A")
	multi:Select("B")
	assert(#multi:Get() == 2, "multi select did not accumulate")
	multi:Select("A")
	assert(#multi:Get() == 1 and multi:Get()[1] == "B", "picking again should unpick")
	multi:SetValues({ "B" })
	assert(#multi:Get() == 1, "SetValues should keep what still exists")
	multi:SetValues({ "Z" })
	assert(#multi:Get() == 0, "SetValues should drop what is gone")

	-- only one popout at a time
	drop:SetOpen(true)
	picker:SetOpen(true)
	local panels = 0
	for _, inst in ipairs(MOCK.allInstances) do
		if inst.Name == "Popout" and inst.Parent then panels = panels + 1 end
	end
	assert(panels == 1, "expected one popout, found " .. panels)
	MOCK.step(0.4)
	picker:SetOpen(false)
	MOCK.step(0.4)
end

--------------------------------------------------------------------
-- window behaviour
--------------------------------------------------------------------
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
assert(Window.Open == false, "the keybind did not close the window")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
assert(Window.Open == true, "the keybind did not reopen it")

Window:Fold()
assert(Window.Minimised == true, "folding failed")
assert(frame.Size.Y.Offset == 38, "a folded window should be its title bar")
Window:Fold()
assert(Window.Minimised == false, "unfolding failed")
assert(frame.Size.Y.Offset == 400, "unfolding should restore the height")

bar:FindFirstChild("Close").MouseButton1Click:Fire()
assert(Window.Open == false, "the close button should hide the window")
MOCK.step(0.4)
assert(frame.Visible == false, "a closed window should end up hidden")
Window:SetOpen(true)
assert(frame.Visible == true, "reopening should show it again")
MOCK.step(0.4)
assert(frame.Size.Y.Offset == 400, "reopening should come back to full size")

-- folding survives being hidden and shown
Window:Fold(true)
Window:SetOpen(false)
MOCK.step(0.4)
Window:SetOpen(true)
MOCK.step(0.4)
assert(frame.Size.Y.Offset == 38, "a folded window should reopen folded")
Window:Fold(false)

-- dragging the title bar moves the window
local before = frame.Position.X.Offset
bar.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(100, 100, 0) })
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(160, 130, 0) })
assert(frame.Position.X.Offset == before + 60, "dragging did not move the window")
MOCK.UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })

Window:SetTitle("Renamed")
assert(bar:FindFirstChild("Title").Text == "Renamed", "SetTitle failed")
Window:SetStatus("busy")
assert(strip:FindFirstChild("Text").Text == "busy", "SetStatus failed")
Window:SetToggleKey(Enum.KeyCode.K)
assert(strip:FindFirstChild("Hint").Text == "K", "the strip should follow the keybind")
Window:SetToggleKey(Enum.KeyCode.RightShift)

--------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------
do
	local function liveSlots()
		local n = 0
		for _, inst in ipairs(MOCK.allInstances) do
			if inst.Name == "Slot" and inst.Parent and inst.Parent.Name == "Stack" then
				n = n + 1
			end
		end
		return n
	end

	local short = Void:Notify({ Title = "Short", Duration = 0 })
	assert(short.Instance.Parent.Size.Y.Offset == 40,
		"a title-only toast should be 40 tall, got " .. short.Instance.Parent.Size.Y.Offset)
	assert(short.Instance:FindFirstChildOfClass("UIListLayout") == nil,
		"a toast must be laid out by hand, not by a list")
	assert(short.Instance:FindFirstChild("Rail"), "a toast has no accent rail")
	short.Close()

	local long = Void:Notify({ Title = "Long", Content = string.rep("word ", 90), Duration = 0 })
	assert(long.Instance.Parent.Size.Y.Offset == 60, "a toast with content should be 60 tall")
	assert(long.Instance:FindFirstChild("Content").Size.Y.Offset <= 26,
		"the body should be a fixed two lines")

	local timed = Void:Notify({ Title = "Timed", Duration = 2 })
	local clock = timed.Instance:FindFirstChild("Clock")
	assert(clock and clock:FindFirstChild("Left").Size.X.Scale == 0, "the clock should drain")
	timed.Close()

	local urgent = Void:Notify({ Title = "Broken", Warn = true, Duration = 0 })
	assert(urgent.Instance:FindFirstChild("Rail").BackgroundColor3 == Void.Ink.Warn,
		"a warning toast should use the warning colour")
	urgent.Close()

	Void.MaxToasts = 2
	for i = 1, 5 do Void:Notify({ Title = "T" .. i, Duration = 0 }) end
	MOCK.step(0.6)
	assert(liveSlots() == 2, "expected the stack to cap at 2, got " .. liveSlots())
	Void.MaxToasts = 4

	for _, inst in ipairs(MOCK.allInstances) do
		if inst.Name == "Slot" and inst.Parent and inst.Parent.Name == "Stack" then
			inst:Destroy()
		end
	end
end

--------------------------------------------------------------------
-- the accent is swappable, and everything bound to it follows
--------------------------------------------------------------------
do
	local knob = toggle.Instance:FindFirstChild("Slot"):FindFirstChild("Track"):FindFirstChild("Knob")
	toggle:Set(true)
	assert(knob.BackgroundColor3 == Void.Ink.Edge, "a lit toggle should wear the accent")

	Void:SetAccent(Color3.fromRGB(0, 255, 120))
	assert(Void.Ink.Edge.G > 0.9, "SetAccent did not take")
	assert(knob.BackgroundColor3 == Void.Ink.Edge, "the accent did not reach a live element")
	assert(marker.BackgroundColor3 == Void.Ink.Edge, "the rail marker did not follow")

	-- text on the accent has to stay readable
	Void:SetAccent(Color3.fromRGB(255, 255, 255))
	assert(Void.Ink.OnEdge.R < 0.2, "text on a bright accent should be dark")
	Void:SetAccent(Color3.fromRGB(20, 20, 30))
	assert(Void.Ink.OnEdge.R > 0.8, "text on a dark accent should be light")
	Void:SetAccent(Color3.fromRGB(255, 255, 255))
	toggle:Set(false)
end

--------------------------------------------------------------------
-- configs
--------------------------------------------------------------------
do
	assert(Void.CanSave == true, "the mock provides file IO, so saving should be available")

	slider:Set(200)
	toggle:Set(true)
	input:Set("saved")
	picker:Set(Color3.fromRGB(10, 200, 30))
	bind:Set(Enum.KeyCode.J)

	local saved, why = Void:SaveConfig("main")
	assert(saved, "saving failed: " .. tostring(why))

	local names = Void:ListConfigs()
	assert(#names == 1 and names[1] == "main", "the config did not show up in the listing")

	-- move everything, then put it back from the file
	slider:Set(20)
	toggle:Set(false)
	input:Set("changed")
	assert(Void:LoadConfig("main"), "loading failed")
	assert(slider:Get() == 200, "the slider did not come back")
	assert(toggle:Get() == true, "the toggle did not come back")
	assert(input:Get() == "saved", "the input did not come back")
	assert(math.abs(picker:Get().G - 200 / 255) < 0.02, "the colour did not come back")
	assert(bind:Get() == Enum.KeyCode.J, "the keybind did not come back")

	-- configs are filed per game unless told otherwise
	local path
	for name in pairs(MOCK.files) do path = name end
	assert(path and string.find(path, tostring(game.PlaceId), 1, true),
		"a per-game config should be filed under the place id, got " .. tostring(path))

	assert(Void:DeleteConfig("main"), "deleting failed")
	assert(#Void:ListConfigs() == 0, "the config should be gone")
	assert(Void:LoadConfig("nothing") == false, "loading a missing config should fail cleanly")
end

--------------------------------------------------------------------
-- layout rules, checked over the whole tree
--------------------------------------------------------------------
--
-- Roblox sizes an AutomaticSize parent from its children's offsets and
-- ignores their scales. Two ways to break that: a child sized from the
-- container a list is sizing, or a big offset child inside a parent that
-- measures it. Both have shipped before in this repository.
do
	local MAX_CHILD = 300
	local listBugs, sizeBugs = {}, {}

	local function listOf(inst)
		for _, child in ipairs(inst:GetChildren()) do
			if child.ClassName == "UIListLayout" then return child end
		end
	end

	local function autoY(inst)
		return inst.AutomaticSize == Enum.AutomaticSize.Y
			or inst.AutomaticSize == Enum.AutomaticSize.XY
	end
	local function autoX(inst)
		return inst.AutomaticSize == Enum.AutomaticSize.X
			or inst.AutomaticSize == Enum.AutomaticSize.XY
	end

	local function where(inst)
		local trail, walk = inst.Name, inst.Parent
		for _ = 1, 4 do
			if not walk then break end
			trail = walk.Name .. "/" .. trail
			walk = walk.Parent
		end
		return trail
	end

	for _, inst in ipairs(MOCK.allInstances) do
		if inst.Parent and inst:IsA("GuiObject") then
			local layout = listOf(inst)
			local vertical = layout and layout.FillDirection ~= Enum.FillDirection.Horizontal

			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("GuiObject") then
					if layout and vertical and autoY(inst) and child.Size.Y.Scale > 0 then
						table.insert(listBugs, where(child) .. " is "
							.. child.Size.Y.Scale .. " of the height it helps measure")
					end
					if layout and not vertical and autoX(inst) and child.Size.X.Scale > 0 then
						table.insert(listBugs, where(child) .. " is "
							.. child.Size.X.Scale .. " of the width it helps measure")
					end
					if autoY(inst) and child.Size.Y.Offset > MAX_CHILD then
						table.insert(sizeBugs, where(child) .. " is "
							.. child.Size.Y.Offset .. "px tall inside a parent that measures it")
					end
					if autoX(inst) and child.Size.X.Offset > MAX_CHILD then
						table.insert(sizeBugs, where(child) .. " is "
							.. child.Size.X.Offset .. "px wide inside a parent that measures it")
					end
				end
			end
		end
	end

	assert(#listBugs == 0, "list layout sizing itself from its own children:\n  "
		.. table.concat(listBugs, "\n  "))
	assert(#sizeBugs == 0, "oversized child of a self-measuring parent:\n  "
		.. table.concat(sizeBugs, "\n  "))
end

--------------------------------------------------------------------
-- teardown
--------------------------------------------------------------------
Void:SetFlag("aimbot", true)
assert(toggle:Get() == true, "SetFlag did not reach the element")

toggle:Destroy()
assert(Void.Options.aimbot == nil, "Destroy did not release the flag")

local Second = Void:CreateWindow({ Title = "Second" })
assert(#Void.Windows == 2, "second window not tracked")
Second:Destroy()
assert(#Void.Windows == 1, "Destroy did not untrack the window")

Void:Unload()
assert(Void.Unloaded == true, "Unload did not mark the library")
assert(Void.Screen.Parent == nil, "Unload did not remove the root")

MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
MOCK.step(1)

print("all Void checks passed")
