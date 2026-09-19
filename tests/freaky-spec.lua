-- FreakyUI, exercised against the same mock Roblox environment as Onyx.
assert(pcall(function() Instance.new("Frame").Text = "" end) == false,
	"the mock must reject invalid properties")

local ok, Freaky = pcall(LoadFreaky)
assert(ok, "library failed to load: " .. tostring(Freaky))
print("loaded " .. Freaky.Name .. " v" .. Freaky.Version)

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
local Window = Freaky:CreateWindow({
	Title = "Freaky Demo", SubTitle = "v1", Theme = "Freak",
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
assert(Freaky.Flags.aimbot == false, "toggle did not register its flag")
toggle:Set(true)
assert(fired.aimbot == true and Freaky:GetFlag("aimbot") == true, "toggle Set failed")
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
assert(fired.fov == 125 and Freaky.Flags.fov == 125, "slider flag/callback wrong")

local drop = Combat:Dropdown({ Title = "Target", Values = { "Head", "Torso" },
	Default = "Head", Flag = "part", Callback = function(v) note("part", v) end })
assert(drop:Get() == "Head", "dropdown default wrong")
drop:Set("Torso")
assert(fired.part == "Torso" and Freaky.Flags.part == "Torso", "dropdown Set failed")
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
assert(input:Get() == "hello" and Freaky.Flags.name == "hello", "input Set failed")

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
-- every palette has to be complete and loud: two distinct accents, and
-- enough contrast between the text and what it sits on
local REQUIRED = {
	"Bg", "Panel", "Card", "Hover", "Line", "Text", "Sub", "Muted",
	"Accent", "Accent2", "OnAccent", "Error",
}

local function luminance(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function saturation(c)
	local _, sat = c:ToHSV()
	return sat
end

local function apart(a, b)
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

for _, name in ipairs(Freaky.ThemeOrder) do
	local palette = Freaky.Themes[name]
	assert(palette, "ThemeOrder names a theme that does not exist: " .. name)
	for _, token in ipairs(REQUIRED) do
		assert(palette[token], name .. " is missing " .. token)
	end
	-- Void is deliberately colourless; everything else has to be saturated
	if name ~= "Void" then
		assert(saturation(palette.Accent) > 0.45,
			name .. " has a washed-out accent")
		assert(apart(palette.Accent, palette.Accent2) > 0.25,
			name .. " has two accents that are nearly the same colour")
	end
	assert(math.abs(luminance(palette.Text) - luminance(palette.Bg)) > 0.4,
		name .. " does not have readable text on its background")
	assert(math.abs(luminance(palette.OnAccent) - luminance(palette.Accent)) > 0.25,
		name .. " does not have readable text on its accent")
end

local before = panel.BackgroundColor3
Freaky:SetTheme("Venom")
assert(Freaky.ThemeName == "Venom", "SetTheme did not take")
assert(panel.BackgroundColor3 ~= before, "switching theme did not repaint the panel")
assert(panel.BackgroundColor3 == Freaky.Themes.Venom.Bg, "panel painted the wrong token")

local next1 = Freaky:NextTheme()
assert(next1 == "Cyber", "NextTheme should follow ThemeOrder")
assert(panel.BackgroundColor3 == Freaky.Themes.Cyber.Bg, "NextTheme did not repaint")

Freaky:SetTheme("Nonexistent")
assert(Freaky.ThemeName == "Cyber", "an unknown theme must be ignored")
Freaky:SetTheme("Freak")

-- elements built after a switch use the new palette
local Late = Main:CreateSection("Late")
local lateButton = Late:Button({ Title = "Late" })
assert(lateButton.Instance.BackgroundColor3 == Freaky.Themes.Freak.Card,
	"an element built after a theme switch used a stale colour")

--------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------
local toastsBefore = #MOCK.allInstances
Freaky:Notify({ Title = "Hello", Content = "World", Duration = 1 })
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
	assert(themeDrop:Get() == Freaky.ThemeName, "theme dropdown started out of step")

	Freaky:SetTheme("Inferno")
	assert(themeDrop:Get() == "Inferno", "SetTheme did not move the theme dropdown")

	local menu = panel:FindFirstChild("ThemeMenu")
	assert(menu, "the header has no theme menu")
	assert(menu.Visible == false, "the theme menu should start closed")

	local swatch = panel:FindFirstChild("Header"):FindFirstChild("Theme")
	swatch.MouseButton1Click:Fire()
	assert(menu.Visible == true, "the swatch did not open the theme menu")

	menu:FindFirstChild("Cyber").MouseButton1Click:Fire()
	assert(Freaky.ThemeName == "Cyber", "the header picker did not set the theme")
	assert(menu.Visible == false, "picking a theme should close the menu")
	assert(themeDrop:Get() == "Cyber", "the header picker did not move the dropdown")

	-- and the other direction
	themeDrop:Set("Freak")
	assert(Freaky.ThemeName == "Freak", "the dropdown did not set the theme")

	-- navigating away closes the menu
	swatch.MouseButton1Click:Fire()
	assert(menu.Visible == true, "the swatch should toggle the menu open again")
	Main:Select()
	assert(menu.Visible == false, "switching tabs should close the theme menu")
	Looks:Select()

	local late = Palette:ThemeDropdown("Theme again")
	assert(late:Get() == "Freak", "a picker built later started out of step")
	Freaky:NextTheme()
	assert(late:Get() == Freaky.ThemeName, "NextTheme did not reach the pickers")
	Freaky:SetTheme("Freak")
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
	Freaky.MaxToasts = 5
	for i = 1, 6 do Freaky:Notify({ Title = "A" .. i, Duration = 0 }) end
	MOCK.step(0.6)
	assert(liveSlots() == 5, "expected 5 toasts, got " .. liveSlots())

	Freaky.MaxToasts = 3
	for i = 1, 6 do Freaky:Notify({ Title = "T" .. i, Duration = 0 }) end
	MOCK.step(0.6)
	assert(liveSlots() == 3, "expected the stack to cap at 3, got " .. liveSlots())

	-- a toast has a real height rather than one measured from its contents:
	-- the version that measured itself rendered nothing at all
	local short = Freaky:Notify({ Title = "Short", Duration = 0 })
	local shortSlot = short.Instance.Parent
	assert(shortSlot.Size.Y.Offset == 38, "a title-only toast should be 38 tall, got "
		.. shortSlot.Size.Y.Offset)
	assert(shortSlot.AutomaticSize == nil or shortSlot.AutomaticSize == Enum.AutomaticSize.None,
		"a toast slot must not measure itself")
	assert(short.Instance.Size.Y.Scale == 1, "the card should fill its slot")
	short.Close()

	-- and a long message does not make it any taller
	local long = Freaky:Notify({
		Title = "Long", Content = string.rep("word ", 120), Duration = 0,
	})
	MOCK.step(0.6)
	local longSlot = long.Instance.Parent
	assert(longSlot.Size.Y.Offset == 56, "a toast with content should be 56 tall, got "
		.. longSlot.Size.Y.Offset)

	local body = long.Instance:FindFirstChild("Content")
	assert(body, "long toast body missing")
	assert(body.Size.Y.Offset <= 24, "the body should be a fixed two lines")
	assert(body.TextTruncate == Enum.TextTruncate.AtEnd, "the body should truncate")
	assert(body:FindFirstChildOfClass("UISizeConstraint") == nil,
		"a fixed-size body does not need a size constraint")

	-- every part of a toast must be laid out by hand, not by a list
	assert(long.Instance:FindFirstChildOfClass("UIListLayout") == nil,
		"a toast must not be laid out by a list: its decoration is not a list item")

	-- a toast is dressed rather than a plain rectangle, and shows its clock
	local dressed = long.Instance
	assert(dressed:FindFirstChild("Wash"), "the toast has no wash")
	assert(dressed:FindFirstChild("Wash"):FindFirstChildOfClass("UIGradient"),
		"the wash should be a gradient, not a flat tint")
	assert(dressed:FindFirstChild("Edge"), "the toast has no accent edge")
	assert(dressed:FindFirstChild("Spark"), "the toast has no mark")

	local timed = Freaky:Notify({ Title = "Timed", Duration = 2 })
	local lane = timed.Instance:FindFirstChild("Timer")
	assert(lane, "a toast with a duration should show a timer")
	assert(lane:FindFirstChild("Fill").Size.X.Scale == 0, "the timer should drain to empty")
	timed.Close()

	-- closing collapses the slot so the stack closes the gap behind it
	local closing = Freaky:Notify({ Title = "Closing", Duration = 0 })
	local closingSlot = closing.Instance.Parent
	closing.Close()
	assert(closingSlot.Size.Y.Offset == 0, "a closing toast should collapse its slot")
	MOCK.step(0.5)
	assert(closingSlot.Parent == nil, "a closed toast should clean itself up")

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
	assert(#Freaky.Flags.parts == 1, "the flag did not follow")

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
	assert(Freaky.Flags.notes == "a\nb\nc", "textarea flag did not follow")

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
	assert(Freaky.Flags.tracer.B > 0.9, "colour picker flag did not follow")
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
	assert(Freaky.Flags.ping == "42ms", "stat flag did not follow")

	-- everything above survives a theme switch
	Freaky:SetTheme("Venom")
	Freaky:SetTheme("Freak")
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

	local sparks = 0
	for _, child in ipairs(backdrop:GetChildren()) do
		if child.Name == "Spark" then sparks = sparks + 1 end
	end
	assert(sparks >= 4, "expected sparks behind the content, found " .. sparks)

	-- the backdrop follows a theme switch like everything else
	local washColour = backdrop:FindFirstChild("Wash").BackgroundColor3
	Freaky:SetTheme("Venom")
	assert(backdrop:FindFirstChild("Wash").BackgroundColor3 ~= washColour,
		"the backdrop did not repaint with the theme")
	Freaky:SetTheme("Freak")

	-- and it can be turned off
	local plain = Freaky:CreateWindow({ Title = "Plain", Background = "plain" })
	local plainBack = plain.Instance:FindFirstChild("Panel"):FindFirstChild("Backdrop")
	assert(plainBack and #plainBack:GetChildren() == 0, "Background = plain should draw nothing")
	plain:Destroy()

	local glowOnly = Freaky:CreateWindow({ Title = "Glow", Background = "glow" })
	local glowBack = glowOnly.Instance:FindFirstChild("Panel"):FindFirstChild("Backdrop")
	local glowSparks = 0
	for _, child in ipairs(glowBack:GetChildren()) do
		if child.Name == "Spark" then glowSparks = glowSparks + 1 end
	end
	assert(glowSparks == 0, "Background = glow should skip the sparks")
	assert(glowBack:FindFirstChild("Wash"), "Background = glow still wants the wash")
	glowOnly:Destroy()
end

--------------------------------------------------------------------
-- the brand: two accents, gradients, a spark and some movement
--------------------------------------------------------------------
do
	local RS = game:GetService("RunService")

	local function gradientOf(inst)
		return inst and inst:FindFirstChildOfClass("UIGradient")
	end

	-- the mark is a four-blade spark, not a font glyph
	local spark = panel:FindFirstChild("Header"):FindFirstChild("Spark")
	assert(spark, "the header has no spark")
	local blades = 0
	for _, child in ipairs(spark:GetChildren()) do
		if child.ClassName == "Frame" then blades = blades + 1 end
	end
	assert(blades == 4, "expected 4 blades, found " .. blades)
	assert(spark:FindFirstChildOfClass("UIScale"), "the spark cannot pulse without a UIScale")

	-- the straight blades take Accent, the diagonals take Accent2
	local straight, diagonal = 0, 0
	for _, child in ipairs(spark:GetChildren()) do
		if child.ClassName == "Frame" then
			if child.BackgroundColor3 == Freaky.Themes.Freak.Accent then straight = straight + 1 end
			if child.BackgroundColor3 == Freaky.Themes.Freak.Accent2 then diagonal = diagonal + 1 end
		end
	end
	assert(straight == 2 and diagonal == 2,
		"the spark should carry both accents, got " .. straight .. "/" .. diagonal)

	-- the panel border, the handle and the title all run the accent pair
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	assert(gradientOf(stroke), "the panel border is not a gradient")
	assert(gradientOf(handle), "the handle is not a gradient")
	assert(gradientOf(panel:FindFirstChild("Header"):FindFirstChild("Title")),
		"the title does not carry the palette")

	-- gradients repaint with the theme, like painted properties do
	local strokeGradient = gradientOf(stroke)
	local before = strokeGradient.Color.Keypoints[1].Value
	Freaky:SetTheme("Cyber")
	assert(strokeGradient.Color.Keypoints[1].Value ~= before,
		"gradients did not repaint on a theme switch")
	assert(strokeGradient.Color.Keypoints[1].Value == Freaky.Themes.Cyber.Accent,
		"gradient took the wrong colour")
	assert(strokeGradient.Color.Keypoints[2].Value == Freaky.Themes.Cyber.Accent2,
		"gradient did not take the second accent")
	Freaky:SetTheme("Freak")

	-- and the loud ones turn, driven by one shared connection
	local spun = gradientOf(handle)
	local was = spun.Rotation
	for _ = 1, 30 do RS.RenderStepped:Fire(1 / 60) end
	assert(spun.Rotation ~= was, "the drifting gradients are not turning")
	assert(spun.Rotation >= 0 and spun.Rotation < 360, "rotation should stay in range")

	-- rows acknowledge a press with a ring and a hover bar
	local Feel = Main:CreateSection("Feel")
	local row = Feel:Button({ Title = "Press me" }).Instance
	local bar = row:FindFirstChild("Edge")
	assert(bar, "a row has no hover bar")
	assert(bar.Size.Y.Scale == 0, "the hover bar should start collapsed")
	row.MouseEnter:Fire()
	assert(bar.Size.Y.Scale > 0, "hovering should grow the bar")
	row.MouseLeave:Fire()
	assert(bar.Size.Y.Scale == 0, "leaving should retract it")

	-- pressing must not change any size: a row measures its own height, so
	-- an effect that grows inside it drags the row along with it
	local before = row.Size
	row.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(20, 0, 0) })
	local glow = row:FindFirstChild("Flash")
	assert(glow, "pressing a row should flash it")
	assert(glow.Size.X.Scale == 1 and glow.Size.Y.Scale == 1,
		"the flash must be sized from the row, not in pixels")
	assert(glow.Size.X.Offset == 0 and glow.Size.Y.Offset == 0,
		"the flash must not add any offset size")
	assert(row.Size.Y.Offset == before.Y.Offset, "pressing changed the row's height")
	MOCK.step(0.6)
	assert(glow.Parent == nil, "the flash should clean itself up")

	-- opening the sidebar sweeps a line down the panel
	Window:SetOpen(false)
	MOCK.step(0.8)
	Window:SetOpen(true)
	assert(panel:FindFirstChild("Sweep"), "opening should sweep the panel")
	MOCK.step(0.8)
	assert(panel:FindFirstChild("Sweep") == nil, "the sweep should clean itself up")

	-- a lit toggle runs the gradient; an unlit one does not
	local lit = Feel:Toggle({ Title = "Lit" })
	local trackGradient = gradientOf(lit.Instance:FindFirstChild("Slot"):FindFirstChild("Track"))
	assert(trackGradient, "the toggle track has no gradient")
	assert(trackGradient.Enabled == false, "an off toggle should not run the gradient")
	lit:Set(true)
	assert(trackGradient.Enabled == true, "an on toggle should run the gradient")
	lit:Set(false)
	assert(trackGradient.Enabled == false, "turning it off should stop the gradient")

	-- section headings are dealt in one after another when a tab opens
	local Deal = Player:CreateSection("Deal")
	Deal:Label("something")
	assert(#Player.Sections >= 1, "the tab does not track its sections")

	local head = Deal.Instance:FindFirstChild("Head")
	assert(head, "a section has no heading row")
	local tick = head:FindFirstChild("Tick")
	assert(tick, "a section heading has no accent tick")

	Player:Select()
	assert(tick.Size.X.Offset == 0, "the tick should start collapsed on select")
	assert(head:FindFirstChild("Title").TextTransparency == 1,
		"the heading should start faded on select")
	MOCK.step(0.6)
	assert(tick.Size.X.Offset == 10, "the tick should draw itself in")
	assert(head:FindFirstChild("Title").TextTransparency == 0,
		"the heading should fade up")

	-- the reveal must never touch anything that carries layout: a section
	-- measures its own height, so its parts stay the size they end up
	assert(Deal.Instance.ClassName == "Frame",
		"a section that measures itself should be a plain Frame")
	Main:Select()
	MOCK.step(0.6)
end

--------------------------------------------------------------------
-- layout rules, checked over the whole tree
--------------------------------------------------------------------
--
-- Roblox sizes an AutomaticSize parent from its children's offsets and
-- ignores their scales. Two ways to break that, both of which shipped:
--
--   * put a child sized from its container inside a list layout that is
--     sizing that container - the toast did this with its wash and edge
--     bar, and the circle resolved to a card with no height at all
--   * put a big offset-sized child inside a parent that measures its
--     children - the press ripple did this, and a pressed row grew to the
--     height of the ripple
--
-- Neither is visible in a unit test of behaviour, so they are checked
-- structurally instead, over everything the suite has built.
do
	local MAX_CHILD = 300

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

	local listBugs, sizeBugs = {}, {}

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
-- flags, destroy, unload
--------------------------------------------------------------------
Freaky:SetFlag("aimbot", true)
assert(toggle:Get() == true, "SetFlag did not reach the element")

toggle:Destroy()
assert(Freaky.Options.aimbot == nil, "Destroy did not release the flag")

local Second = Freaky:CreateWindow({ Title = "Second" })
assert(#Freaky.Windows == 2, "second window not tracked")
Second:Destroy()
assert(#Freaky.Windows == 1, "Destroy did not untrack the window")

Freaky:Unload()
assert(Freaky.Unloaded == true, "Unload did not mark the library")
assert(Freaky.Root.Parent == nil, "Unload did not remove the root")

-- a stray input after unloading must not throw
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
MOCK.step(1)

print("all FreakyUI checks passed")
