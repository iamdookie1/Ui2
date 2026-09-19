-- LoveUI, exercised against the same mock Roblox environment as Onyx.
assert(pcall(function() Instance.new("Frame").Text = "" end) == false,
	"the mock must reject invalid properties")

local ok, Love = pcall(LoadLove)
assert(ok, "library failed to load: " .. tostring(Love))
print("loaded " .. Love.Name .. " v" .. Love.Version)

local fired = {}
local function note(k, v) fired[k] = v end

local function find(pred)
	for _, inst in ipairs(MOCK.allInstances) do
		if pred(inst) then return inst end
	end
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
local Window = Love:CreateWindow({
	Title = "Love Demo", SubTitle = "v1", Theme = "Rose",
	Width = 340, Keybind = Enum.KeyCode.RightShift,
})
assert(Window and Window.Instance, "no drawer")

local drawer = Window.Instance
local panel = drawer:FindFirstChild("Panel")
local handle = drawer:FindFirstChild("Handle")
assert(panel and handle, "drawer is missing its panel or handle")
assert(drawer.Position.X.Offset == -340, "sidebar should start off-screen")
assert(handle.Position.X.Offset > 340 - 1, "handle must ride the panel's right edge")
assert(handle.BackgroundTransparency > 0, "handle must be translucent")

--------------------------------------------------------------------
-- tabs and sections
--------------------------------------------------------------------
local Main = Window:CreateTab("Main")
local Player = Window:CreateTab({ Title = "Player" })
assert(#Window.Tabs == 2, "expected 2 tabs")
assert(Window.ActiveTab == Main, "first tab should auto-select")

Player:Select()
assert(Window.ActiveTab == Player, "Select did not switch tabs")
assert(Main.Wrap.GroupTransparency == 1, "the old page should fade out")
assert(Player.Wrap.GroupTransparency == 0, "the new page should fade in")
MOCK.step(0.4)
assert(Main.Page.Visible == false, "the old page should hide once it has faded")
Main:Select()
MOCK.step(0.4)
assert(Main.Page.Visible == true, "the selected page must be visible")

local Combat = Main:CreateSection("Combat")
assert(Combat, "no section")

--------------------------------------------------------------------
-- elements
--------------------------------------------------------------------
local label = Combat:Label("Plain text")
label:SetText("Changed")
assert(label.Instance.Text == "Changed", "label SetText failed")

local para = Combat:Paragraph({ Title = "Heads up", Content = "Wraps across lines." })
para:SetTitle("New title")
para:SetContent("New body")

Combat:Divider()

local hits = 0
local button = Combat:Button({ Title = "Kill all", Description = "Removes NPCs",
	Callback = function() hits = hits + 1 end })
button.Instance.MouseButton1Click:Fire()
assert(hits == 1, "button callback did not fire")
button:SetTitle("Kill everything")

local toggle = Combat:Toggle({ Title = "Aimbot", Flag = "aimbot", Default = false,
	Callback = function(v) note("aimbot", v) end })
assert(Love.Flags.aimbot == false, "toggle did not register its flag")
toggle:Set(true)
assert(fired.aimbot == true and Love:GetFlag("aimbot") == true, "toggle Set failed")
toggle.Instance.MouseButton1Click:Fire()
assert(toggle:Get() == false, "clicking the row should flip the toggle")

local slider = Combat:Slider({ Title = "FOV", Min = 20, Max = 400, Default = 120,
	Increment = 5, Suffix = "px", Flag = "fov", Callback = function(v) note("fov", v) end })
assert(slider:Get() == 120, "slider default wrong")
slider:Set(999)
assert(slider:Get() == 400, "slider must clamp to Max")
slider:Set(0)
assert(slider:Get() == 20, "slider must clamp to Min")
slider:Set(123)
assert(slider:Get() == 125, "slider must snap to Increment")
assert(fired.fov == 125 and Love.Flags.fov == 125, "slider flag/callback wrong")

local drop = Combat:Dropdown({ Title = "Target", Values = { "Head", "Torso" },
	Default = "Head", Flag = "part", Callback = function(v) note("part", v) end })
assert(drop:Get() == "Head", "dropdown default wrong")
drop:Set("Torso")
assert(fired.part == "Torso" and Love.Flags.part == "Torso", "dropdown Set failed")
drop:SetOpen(true)
assert(drop.Open == true, "dropdown did not open")
-- the list expands to a height rather than snapping open
assert(drop.Instance:FindFirstChild("Options").Size.Y.Offset > 0,
	"an open dropdown should have height")
drop:SetValues({ "A", "B", "C" })
drop:Set("B")
assert(drop:Get() == "B", "dropdown SetValues did not rebuild the list")
drop:SetOpen(false)
assert(drop.Instance:FindFirstChild("Options").Size.Y.Offset == 0,
	"a closed dropdown should collapse to nothing")
MOCK.step(0.4)
assert(drop.Instance:FindFirstChild("Options").Visible == false,
	"a collapsed dropdown should end up hidden")

local input = Combat:Input({ Title = "Name", Placeholder = "type here", Default = "",
	Flag = "name", Callback = function(v) note("name", v) end })
input:Set("hello")
assert(input:Get() == "hello" and Love.Flags.name == "hello", "input Set failed")

local bindHits = 0
local bind = Combat:Keybind({ Title = "Panic", Default = Enum.KeyCode.P, Flag = "panic",
	Callback = function() bindHits = bindHits + 1 end,
	ChangedCallback = function(k) note("rebound", k) end })
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, false)
assert(bindHits == 1, "keybind callback did not fire")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.P }, true)
assert(bindHits == 1, "a processed input must not fire the keybind")
bind:Set(Enum.KeyCode.Q)
assert(fired.rebound == Enum.KeyCode.Q, "ChangedCallback did not fire on rebind")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q }, false)
assert(bindHits == 2, "keybind did not follow the rebind")

-- listening: the chip captures the next key instead of running the callback
local chip = bind.Instance:FindFirstChild("Slot"):FindFirstChild("Chip")
assert(chip, "keybind chip missing")
chip.MouseButton1Click:Fire()
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Z }, false)
assert(bind:Get() == Enum.KeyCode.Z, "listening keybind did not capture the key")
assert(bindHits == 2, "capturing a key must not also run the callback")

--------------------------------------------------------------------
-- opening: keybind, tap, drag
--------------------------------------------------------------------
local function press(x)
	return { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(x, 0, 0) }
end

MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
assert(Window.Open == true, "keybind did not open the sidebar")
assert(drawer.Position.X.Offset == 0, "an open sidebar sits flush with the edge")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
assert(Window.Open == false, "keybind did not close the sidebar")

-- a tap on the handle toggles
handle.InputBegan:Fire(press(300))
MOCK.UIS.InputEnded:Fire(press(300))
assert(Window.Open == true, "tapping the handle should open it")
handle.InputBegan:Fire(press(300))
MOCK.UIS.InputEnded:Fire(press(300))
assert(Window.Open == false, "tapping again should close it")

-- a drag past the threshold commits
handle.InputBegan:Fire(press(10))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(200, 0, 0) })
MOCK.UIS.InputEnded:Fire(press(200))
assert(Window.Open == true, "a long drag right should open it")

-- a short drag snaps back
handle.InputBegan:Fire(press(200))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(180, 0, 0) })
MOCK.UIS.InputEnded:Fire(press(180))
assert(Window.Open == true, "a short drag should snap back open")
assert(drawer.Position.X.Offset == 0, "snapping back should restore the offset")

-- the drawer never travels past its own edges
handle.InputBegan:Fire(press(200))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(900, 0, 0) })
assert(drawer.Position.X.Offset == 0, "drawer must clamp at the open edge")
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(-900, 0, 0) })
assert(drawer.Position.X.Offset == -340, "drawer must clamp at the closed edge")
MOCK.UIS.InputEnded:Fire(press(-900))
assert(Window.Open == false, "dragging fully left should close it")

-- dragging the handle right past flush widens the panel
Window:SetOpen(true)
Window:Collapse()
handle.InputBegan:Fire(press(400))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(520, 0, 0) })
assert(Window.Width == 460, "dragging right should widen the panel, got " .. Window.Width)
assert(drawer.Position.X.Offset == 0, "widening must not move the panel off the edge")
MOCK.UIS.InputEnded:Fire(press(520))
assert(Window.Open == true, "widening should leave it open")
assert(Window.Width == 460, "the width should stick after the drag")

-- dragging back left narrows it before it starts to close
handle.InputBegan:Fire(press(520))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(420, 0, 0) })
assert(Window.Width == 360, "dragging left should narrow it first")
MOCK.UIS.InputEnded:Fire(press(420))
Window:Collapse()

-- and from shut, one long drag opens it and keeps going into widening
Window:SetOpen(false)
handle.InputBegan:Fire(press(0))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(420, 0, 0) })
assert(drawer.Position.X.Offset == 0, "the drag should have carried it fully open")
assert(Window.Width == 420, "and then widened it, got " .. Window.Width)
MOCK.UIS.InputEnded:Fire(press(420))
assert(Window.Open == true, "a drag through to widening should leave it open")
Window:Collapse()

-- a barely-there widen snaps back rather than leaving a ragged edge
handle.InputBegan:Fire(press(400))
MOCK.UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector3.new(410, 0, 0) })
MOCK.UIS.InputEnded:Fire(press(410))
assert(Window.Width == 340, "a 10px widen should snap back to base")

Window:SetOpen(true)
assert(Window.Open == true, "SetOpen failed")

-- widening: the panel grows sideways, it does not get taller
assert(Window.Width == 340, "width should start at the configured width")
local startHeight = drawer.Size.Y.Scale

Window:Expand()
assert(Window.Width == Window.MaxWidth, "Expand did not reach MaxWidth")
assert(panel.Size.X.Offset == Window.MaxWidth, "the panel did not widen")
assert(handle.Position.X.Offset == Window.MaxWidth + 4, "the handle did not follow")
assert(drawer.Size.Y.Scale == startHeight, "widening must not change the height")

Window:Collapse()
assert(Window.Width == 340, "Collapse did not return to the base width")

Window:SetWidth(5000)
assert(Window.Width == Window.MaxWidth, "SetWidth must clamp to MaxWidth")
Window:SetWidth(10)
assert(Window.Width == 340, "SetWidth must clamp to the base width")

-- a wide panel still hides completely
Window:Expand()
Window:SetOpen(false)
assert(drawer.Position.X.Offset == -Window.MaxWidth, "a widened sidebar must hide fully")
Window:SetOpen(true)
Window:Collapse()

-- the header control widens and narrows it too
local widenBtn = panel:FindFirstChild("Header"):FindFirstChild("Widen")
assert(widenBtn, "no widen control in the header")
widenBtn.MouseButton1Click:Fire()
assert(Window.Width == Window.MaxWidth, "the widen control did not expand the panel")
widenBtn.MouseButton1Click:Fire()
assert(Window.Width == 340, "the widen control did not collapse the panel")

Window:SetTitle("Renamed")
assert(panel:FindFirstChild("Header"):FindFirstChild("Title").Text == "Renamed",
	"SetTitle did not reach the header")

--------------------------------------------------------------------
-- themes: every palette carries pink, and switching repaints live
--------------------------------------------------------------------
local function isPink(c)
	local h, s, v = c:ToHSV()
	local deg = h * 360
	return s > 0.25 and v > 0.35 and (deg >= 290 or deg <= 20)
end

for _, name in ipairs(Love.ThemeOrder) do
	assert(isPink(Love.Themes[name].Accent),
		"theme " .. name .. " has no pink in its accent")
end

local before = panel.BackgroundColor3
Love:SetTheme("Midnight")
assert(Love.ThemeName == "Midnight", "SetTheme did not take")
assert(panel.BackgroundColor3 ~= before, "switching theme did not repaint the panel")
assert(panel.BackgroundColor3 == Love.Themes.Midnight.Bg, "panel painted the wrong token")

local next1 = Love:NextTheme()
assert(next1 == "Blush", "NextTheme should follow ThemeOrder")
assert(panel.BackgroundColor3 == Love.Themes.Blush.Bg, "NextTheme did not repaint")

Love:SetTheme("Nonexistent")
assert(Love.ThemeName == "Blush", "an unknown theme must be ignored")
Love:SetTheme("Rose")

-- elements built after a switch use the new palette
local Late = Main:CreateSection("Late")
local lateButton = Late:Button({ Title = "Late" })
assert(lateButton.Instance.BackgroundColor3 == Love.Themes.Rose.Card,
	"an element built after a theme switch used a stale colour")

--------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------
local toastsBefore = #MOCK.allInstances
Love:Notify({ Title = "Hello", Content = "World", Duration = 1 })
local toast = find(function(i) return i.Name == "Toast" end)
assert(toast, "notification did not build a toast")
assert(#MOCK.allInstances > toastsBefore, "notification built nothing")
MOCK.step(0.4)
assert(toast.Position.X.Offset == 0, "the toast should slide into place")
MOCK.step(3)

Window:Notify("string form")
MOCK.step(6)

--------------------------------------------------------------------
-- theme pickers stay in step with each other
--------------------------------------------------------------------
do
	local Looks = Window:CreateTab("Looks")
	local Palette = Looks:CreateSection("Palette")
	local themeDrop = Palette:ThemeDropdown({ Title = "Theme" })
	assert(themeDrop:Get() == Love.ThemeName, "theme dropdown started out of step")

	Love:SetTheme("Wine")
	assert(themeDrop:Get() == "Wine", "SetTheme did not move the theme dropdown")

	local menu = panel:FindFirstChild("ThemeMenu")
	assert(menu, "the header has no theme menu")
	assert(menu.Visible == false, "the theme menu should start closed")

	local swatch = panel:FindFirstChild("Header"):FindFirstChild("Theme")
	swatch.MouseButton1Click:Fire()
	assert(menu.Visible == true, "the swatch did not open the theme menu")

	menu:FindFirstChild("Sakura").MouseButton1Click:Fire()
	assert(Love.ThemeName == "Sakura", "the header picker did not set the theme")
	assert(menu.Visible == false, "picking a theme should close the menu")
	assert(themeDrop:Get() == "Sakura", "the header picker did not move the dropdown")

	-- and the other direction
	themeDrop:Set("Rose")
	assert(Love.ThemeName == "Rose", "the dropdown did not set the theme")

	-- navigating away closes the menu
	swatch.MouseButton1Click:Fire()
	assert(menu.Visible == true, "the swatch should toggle the menu open again")
	Main:Select()
	assert(menu.Visible == false, "switching tabs should close the theme menu")
	Looks:Select()

	local late = Palette:ThemeDropdown("Theme again")
	assert(late:Get() == "Rose", "a picker built later started out of step")
	Love:NextTheme()
	assert(late:Get() == Love.ThemeName, "NextTheme did not reach the pickers")
	Love:SetTheme("Rose")
	Main:Select()
end

--------------------------------------------------------------------
-- notifications stay small and few
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

	local stack = find(function(i) return i.Name == "Stack" end)
	assert(stack.Size.X.Offset <= 180, "the toast stack is too wide")

	-- the cap is the thing being tested, so prove the count tracks it
	Love.MaxToasts = 5
	for i = 1, 6 do Love:Notify({ Title = "A" .. i, Duration = 0 }) end
	MOCK.step(0.6)
	assert(liveSlots() == 5, "expected 5 toasts, got " .. liveSlots())

	Love.MaxToasts = 3
	for i = 1, 6 do Love:Notify({ Title = "T" .. i, Duration = 0 }) end
	MOCK.step(0.6)
	assert(liveSlots() == 3, "expected the stack to cap at 3, got " .. liveSlots())

	-- a long message is height-capped rather than allowed to climb
	Love:Notify({ Title = "Long", Content = string.rep("word ", 120), Duration = 0 })
	MOCK.step(0.6)
	local body
	for _, inst in ipairs(MOCK.allInstances) do
		if inst.ClassName == "TextLabel" and inst.Parent and inst.Parent.Name == "Toast"
			and string.find(inst.Text, "word", 1, true) then body = inst end
	end
	assert(body, "long toast body missing")
	local cap = body:FindFirstChildOfClass("UISizeConstraint")
	assert(cap and cap.MaxSize.Y <= 30, "toast body is not height-capped")

	-- a toast is dressed rather than a plain rectangle, and shows its clock
	local dressed = body.Parent
	assert(dressed:FindFirstChild("Wash"), "the toast has no wash")
	assert(dressed:FindFirstChild("Wash"):FindFirstChildOfClass("UIGradient"),
		"the wash should be a gradient, not a flat tint")
	assert(dressed:FindFirstChild("Edge"), "the toast has no accent edge")
	local timed = Love:Notify({ Title = "Timed", Duration = 2 })
	local lane = timed.Instance:FindFirstChild("Timer")
	assert(lane, "a toast with a duration should show a timer")
	assert(lane:GetChildren()[1].Size.X.Scale == 0, "the timer should drain to empty")
	timed.Close()

	for _, inst in ipairs(MOCK.allInstances) do
		if inst.Name == "Slot" and inst.Parent and inst.Parent.Name == "Stack" then
			inst:Destroy()
		end
	end
end

--------------------------------------------------------------------
-- the elements added in 1.1
--------------------------------------------------------------------
do
	local More = Window:CreateTab("More")
	local Bits = More:CreateSection("Bits")

	-- multi-select dropdown
	local picked
	local multi = Bits:Dropdown({
		Title = "Parts", Values = { "A", "B", "C" }, Multi = true, Flag = "parts",
		Callback = function(list) picked = list end,
	})
	assert(typeof(multi:Get()) == "table", "a multi dropdown holds a list")
	multi:Select("A")
	multi:Select("B")
	assert(#multi:Get() == 2, "multi select did not accumulate")
	assert(picked and #picked == 2, "multi callback did not carry the list")
	multi:Select("A")
	assert(#multi:Get() == 1 and multi:Get()[1] == "B", "picking again should unpick")
	multi:Set({ "A", "C" })
	assert(#multi:Get() == 2, "Set did not replace the selection")
	multi:SetValues({ "C" })
	assert(#multi:Get() == 1 and multi:Get()[1] == "C", "SetValues did not prune the selection")
	assert(#Love.Flags.parts == 1, "the flag did not follow")

	-- a single dropdown still behaves
	local single = Bits:Dropdown({ Title = "One", Values = { "X", "Y" }, Default = "X" })
	assert(single:Get() == "X", "single dropdown broke")
	single:Select("Y")
	assert(single:Get() == "Y", "Select should work on a single dropdown too")

	-- textarea
	local area = Bits:Textarea({ Title = "Notes", Default = "one\ntwo", Flag = "notes" })
	assert(#area.Lines() == 2, "textarea did not split its lines")
	area:Set("a\nb\nc")
	assert(#area.Lines() == 3, "textarea Set failed")
	assert(Love.Flags.notes == "a\nb\nc", "textarea flag did not follow")

	-- colour picker
	local seen
	local pick = Bits:ColorPicker({
		Title = "Tracer", Default = Color3.fromRGB(255, 0, 0), Flag = "tracer",
		Callback = function(c) seen = c end,
	})
	assert(typeof(pick:Get()) == "Color3", "colour picker holds a Color3")
	assert(pick:Get().R > 0.9 and pick:Get().B < 0.1, "colour picker lost its default")
	pick:Set(Color3.fromRGB(0, 0, 255))
	assert(seen and seen.B > 0.9 and seen.R < 0.1, "colour picker callback wrong")
	assert(Love.Flags.tracer.B > 0.9, "colour picker flag did not follow")
	pick:SetOpen(true)
	assert(pick.Open == true, "colour picker did not open")
	local bars = pick.Instance:FindFirstChild("Bars")
	assert(bars and bars.Visible == true and #bars:GetChildren() >= 3,
		"colour picker should show three bars")
	pick:SetOpen(false)

	-- progress
	local bar = Bits:Progress({ Title = "Loading", Default = 0, Flag = "loading" })
	assert(bar:Get() == 0, "progress default wrong")
	bar:Set(0.5)
	assert(bar:Get() == 0.5, "progress Set failed")
	bar:Set(5)
	assert(bar:Get() == 1, "progress must clamp to Max")
	local counted = Bits:Progress({ Title = "Items", Max = 50, Default = 10 })
	assert(counted:Get() == 10, "progress with a Max wrong")

	-- console
	local log = Bits:Console({ Title = "Log", MaxLines = 3 })
	log:Append("one")
	log:Append("two")
	log:Append("three")
	log:Append("four")
	assert(#log.Lines == 3, "console did not trim to MaxLines")
	assert(log.Lines[3].Text == "four", "console dropped the wrong end")
	log:Error("bad")
	assert(#log.Lines == 3, "console error line did not count")
	log:Clear()
	assert(#log.Lines == 0, "console Clear failed")
	MOCK.step(0.2)

	-- stat
	local stat = Bits:Stat({ Title = "Ping", Value = "0ms", Flag = "ping" })
	stat:Set("42ms")
	assert(stat:Get() == "42ms", "stat Set failed")
	assert(Love.Flags.ping == "42ms", "stat flag did not follow")

	-- everything above survives a theme switch
	Love:SetTheme("Midnight")
	Love:SetTheme("Rose")
	Main:Select()
end

--------------------------------------------------------------------
-- the panel has a backdrop rather than a flat fill
--------------------------------------------------------------------
do
	local backdrop = panel:FindFirstChild("Backdrop")
	assert(backdrop, "no backdrop layer")
	assert(backdrop:FindFirstChild("Wash"), "no accent wash")
	assert(backdrop:FindFirstChild("Glow1") and backdrop:FindFirstChild("Glow2"),
		"expected two corner glows")

	local hearts = 0
	for _, child in ipairs(backdrop:GetChildren()) do
		if child.Name == "Heart" then hearts = hearts + 1 end
	end
	assert(hearts >= 3, "expected hearts behind the content, found " .. hearts)

	-- the backdrop follows a theme switch like everything else
	local washColour = backdrop:FindFirstChild("Wash").BackgroundColor3
	Love:SetTheme("Midnight")
	assert(backdrop:FindFirstChild("Wash").BackgroundColor3 ~= washColour,
		"the backdrop did not repaint with the theme")
	Love:SetTheme("Rose")

	-- and it can be turned off
	local plain = Love:CreateWindow({ Title = "Plain", Background = "plain" })
	local plainBack = plain.Instance:FindFirstChild("Panel"):FindFirstChild("Backdrop")
	assert(plainBack and #plainBack:GetChildren() == 0, "Background = plain should draw nothing")
	plain:Destroy()

	local glowOnly = Love:CreateWindow({ Title = "Glow", Background = "glow" })
	local glowBack = glowOnly.Instance:FindFirstChild("Panel"):FindFirstChild("Backdrop")
	local glowHearts = 0
	for _, child in ipairs(glowBack:GetChildren()) do
		if child.Name == "Heart" then glowHearts = glowHearts + 1 end
	end
	assert(glowHearts == 0, "Background = glow should skip the hearts")
	assert(glowBack:FindFirstChild("Wash"), "Background = glow still wants the wash")
	glowOnly:Destroy()
end

--------------------------------------------------------------------
-- flags, destroy, unload
--------------------------------------------------------------------
Love:SetFlag("aimbot", true)
assert(toggle:Get() == true, "SetFlag did not reach the element")

toggle:Destroy()
assert(Love.Options.aimbot == nil, "Destroy did not release the flag")

local Second = Love:CreateWindow({ Title = "Second" })
assert(#Love.Windows == 2, "second window not tracked")
Second:Destroy()
assert(#Love.Windows == 1, "Destroy did not untrack the window")

Love:Unload()
assert(Love.Unloaded == true, "Unload did not mark the library")
assert(Love.Root.Parent == nil, "Unload did not remove the root")

-- a stray input after unloading must not throw
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
MOCK.step(1)

print("all LoveUI checks passed")
