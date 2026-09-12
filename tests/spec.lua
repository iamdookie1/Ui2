-- exercised against the mock environment
-- The mock rejects properties a class does not have, the way Roblox does.
-- Without this a bug like assigning Text to a Frame passes every test here and
-- only fails in game, which is exactly what happened once.
assert(pcall(function() Instance.new("Frame").Text = "" end) == false,
	"the mock must reject invalid properties")
assert(pcall(function() Instance.new("TextButton").Text = "" end) == true,
	"but must still allow valid ones")

local ok, Onyx = pcall(LoadOnyx)
assert(ok, "library failed to load: " .. tostring(Onyx))
print("loaded " .. Onyx.Name .. " v" .. Onyx.Version)

local fired = {}
local function note(k, v) fired[k] = v end

local Window = Onyx:CreateWindow({
	Title = "Onyx Demo", SubTitle = "v1.0.0",
	Size = UDim2.fromOffset(640, 440), Keybind = Enum.KeyCode.RightShift,
})
assert(Window and Window.Frame, "no window frame")

local Main = Window:CreateTab({ Title = "Main", Icon = "rbxassetid://10723407389" })
local Visuals = Window:CreateTab({ Title = "Visuals", Icon = "\u{25C6}" })
local Settings = Window:CreateTab("Settings")
assert(#Window.Tabs == 3, "expected 3 tabs")
assert(Window.ActiveTab == Main, "first tab should auto-select")

local Combat = Main:CreateSection("Combat")
local Misc   = Main:CreateSection("Misc")

Combat:Label("A plain label")
Combat:Paragraph({ Title = "Heads up", Content = "Paragraphs wrap across lines." })
local capLine = Combat:Divider("or")
local plainLine = Combat:Divider()
capLine:SetVisible(false)
assert(capLine.Instance.Visible == false, "divider SetVisible failed")
capLine:SetVisible(true)
plainLine:SetVisible(true)
local para = Combat:Paragraph({ Title = "P", Content = "C" })
para:SetVisible(false)
assert(para.Instance.Visible == false, "paragraph SetVisible failed")
para:SetVisible(true)
para:SetTitle("P2")
para:SetContent("C2")

local btnHits = 0
local btn = Combat:Button({ Title = "Kill All", Description = "Removes every NPC",
	Callback = function() btnHits = btnHits + 1 end })
btn.Instance.MouseButton1Click:Fire()
assert(btnHits == 1, "button callback did not fire")
btn:SetTitle("Kill Everything")

local confirmBtn = Combat:Button({ Title = "Reset", Confirm = true, Callback = function() note("confirmed", true) end })
confirmBtn.Instance.MouseButton1Click:Fire()
assert(fired.confirmed == nil, "confirm should not fire immediately")
-- the dialog's primary button must run the callback
local confirmRow
for _, inst in ipairs(MOCK.allInstances) do
	if inst.ClassName == "TextButton" and inst.Text == "Confirm" then confirmRow = inst end
end
assert(confirmRow, "confirm dialog was not built")
confirmRow.MouseButton1Click:Fire()
assert(fired.confirmed == true, "confirm dialog did not run the callback")
MOCK.step(0.5)

local tog = Combat:Toggle({ Title = "Aimbot", Flag = "aimbot", Default = false,
	Callback = function(v) note("aimbot", v) end })
tog:Set(true)
assert(tog:Get() == true and Onyx.Flags.aimbot == true, "toggle flag not stored")
assert(fired.aimbot == true, "toggle callback missing")
tog.Instance.MouseButton1Click:Fire()
assert(tog:Get() == false, "row click should toggle")

local sld = Combat:Slider({ Title = "FOV", Min = 0, Max = 360, Default = 90, Increment = 1,
	Suffix = "\u{00B0}", Flag = "fov", Callback = function(v) note("fov", v) end })
assert(sld:Get() == 90, "slider default wrong")
sld:Set(400)
assert(sld:Get() == 360, "slider should clamp to max")
sld:Set(-10)
assert(sld:Get() == 0, "slider should clamp to min")
sld:SetRange(0, 100)
sld:Set(33.7)
assert(sld:Get() == 34, "slider increment rounding wrong: " .. tostring(sld:Get()))
assert(Onyx.Flags.fov == 34, "slider flag not synced")

local dec = Combat:Slider({ Title = "Smoothness", Min = 0, Max = 1, Default = 0.5, Increment = 0.05 })
dec:Set(0.37)
assert(math.abs(dec:Get() - 0.35) < 1e-6, "decimal slider rounding wrong: " .. tostring(dec:Get()))

local dd = Misc:Dropdown({ Title = "Target Part", Values = { "Head", "Torso", "Legs" },
	Default = "Head", Flag = "part", Search = true, Callback = function(v) note("part", v) end })
assert(dd:Get() == "Head", "dropdown default wrong")
dd:Set("Torso")
assert(dd:Get() == "Torso" and Onyx.Flags.part == "Torso", "dropdown set failed")
dd:SetValues({ "Head", "Legs" })
assert(dd:Get() == nil, "dropdown should clear a value that no longer exists")
dd:Set("Legs")
assert(dd:Get() == "Legs")

local md = Misc:Dropdown({ Title = "ESP Parts", Multi = true, Values = { "Box", "Name", "Health" },
	Default = { "Box", "Health" }, Flag = "esp" })
assert(#md:Get() == 2, "multi dropdown default wrong")
md:Set({ "Name" })
assert(#md:Get() == 1 and md:Get()[1] == "Name", "multi dropdown set failed")

local inp = Misc:Input({ Title = "Webhook", Placeholder = "https://", Default = "abc",
	Flag = "hook", Callback = function(v) note("hook", v) end })
assert(inp:Get() == "abc")
inp:Set("hello")
assert(inp:Get() == "hello" and Onyx.Flags.hook == "hello", "input flag not synced")

local kb = Misc:Keybind({ Title = "Panic", Default = Enum.KeyCode.P, Mode = "Toggle",
	Flag = "panic", Callback = function(v) note("panic", v) end })
assert(kb:Get() == Enum.KeyCode.P, "keybind default wrong")

local cp = Visuals:Colorpicker({ Title = "Box Colour", Default = Color3.fromRGB(255, 0, 0),
	Flag = "boxcolor", Callback = function(c) note("boxcolor", c) end })
assert(cp:Get().R == 1 and cp:Get().G == 0, "colorpicker default wrong")
cp:Set(Color3.fromRGB(0, 128, 255))
local c = cp:Get()
assert(math.abs(c.B - 1) < 0.01, "colorpicker set failed")
cp:Set("#00FF00")
assert(math.abs(cp:Get().G - 1) < 0.02, "hex set failed")

local cpa = Visuals:Colorpicker({ Title = "Fill", Default = Color3.new(1, 1, 1), Transparency = 0.5 })
assert(cpa.Transparency == 0.5, "alpha not stored")

-- popouts: open the dropdown and pick an option through the UI
dd.Instance.MouseButton1Click:Fire()
MOCK.step(0.5)
local optionRow
for _, inst in ipairs(MOCK.allInstances) do
	if inst.Name == "Legs" and inst.ClassName == "TextButton" then optionRow = inst end
end
assert(optionRow, "dropdown option row was not built")
optionRow.MouseButton1Click:Fire()
assert(dd:Get() == "Legs", "selecting an option through the UI failed")

-- keybind listening flow
kb.Instance.MouseButton1Click:Fire()
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }, false)
assert(kb:Get() == Enum.KeyCode.K, "keybind rebind failed")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }, false)
assert(fired.panic == true, "keybind toggle callback failed")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }, false)
assert(fired.panic == false, "keybind toggle should flip back")

-- tab switching
Visuals.Select()
assert(Window.ActiveTab == Visuals, "tab select failed")
Window:SelectTab(1)
assert(Window.ActiveTab == Main, "SelectTab by index failed")

-- window visibility + toggle key
Window:Toggle()
assert(Window.Visible == false, "toggle should hide")
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
assert(Window.Visible == true, "toggle keybind failed")

-- minimize
Window:Minimize(true)
assert(Window.Minimized == true)
Window:Minimize(false)
MOCK.step(0.5)
assert(Window.Minimized == false)

-- creating a window schedules the auto load pass, which runs once the calling
-- script has finished building its elements
MOCK.step(1)
assert(Onyx.Ready == true, "the deferred auto load pass should have run")

-- notifications
local toast = Onyx:Notify({ Title = "Loaded", Content = "Everything is fine.", Duration = 1, Type = "success" })
assert(toast and toast.Instance, "notification failed")
Onyx:Notify("Short form")
MOCK.step(2)

-- dialog
local dlg = Window:Dialog({ Title = "Confirm", Content = "Do it?", Buttons = {
	{ Title = "No" }, { Title = "Yes", Primary = true, Callback = function() note("dialog", true) end },
} })
assert(dlg and dlg.Close, "dialog failed")
dlg.Close()
MOCK.step(0.5)

-- watermark
local wm = Onyx:Watermark({ Text = "Onyx", ShowFPS = true })
RunService = game:GetService("RunService")
for _ = 1, 3 do RunService.RenderStepped:Fire() end
wm:SetText("Onyx | test")

-- config round trip
tog:Set(true)
sld:Set(72)
inp:Set("saved-value")
md:Set({ "Box", "Name" })
local savedOk, savedErr = Onyx:SaveConfig("test")
assert(savedOk, "SaveConfig failed: " .. tostring(savedErr))

tog:Set(false); sld:Set(1); inp:Set("wiped"); md:Set({})
local loadedOk, loadErr = Onyx:LoadConfig("test")
assert(loadedOk, "LoadConfig failed: " .. tostring(loadErr))
assert(tog:Get() == true, "config did not restore toggle")
assert(sld:Get() == 72, "config did not restore slider, got " .. tostring(sld:Get()))
assert(inp:Get() == "saved-value", "config did not restore input")
assert(#md:Get() == 2, "config did not restore multi dropdown")
assert(Onyx.Flags.panic == Enum.KeyCode.K, "config did not restore keybind")
assert(typeof(Onyx.Flags.boxcolor) == "Color3", "config did not restore colour")

local list = Onyx:ListConfigs()
assert(#list == 1 and list[1] == "test", "ListConfigs wrong")

-- configs are filed under the current game, not in one shared folder
assert(MOCK.files["OnyxUI/configs/place_1234567/test.json"],
	"a config should be written under its game key")

-- flag helpers
Onyx:SetFlag("aimbot", false)
assert(Onyx:GetFlag("aimbot") == false, "SetFlag/GetFlag failed")
assert(Onyx:GetOption("aimbot") == tog, "GetOption failed")

-- accent recolour
Onyx:SetAccent(Color3.fromRGB(120, 90, 255))
assert(Onyx.Theme.Accent.B > 0.9, "accent not applied")

-- element removal
local temp = Misc:Button({ Title = "temp" })
temp:Destroy()
local tempSlider = Misc:Slider({ Title = "temp", Flag = "tempflag" })
tempSlider:Destroy()
assert(Onyx.Options.tempflag == nil, "destroy did not unregister the flag")

-- dropdown search filtering
local searchBox
for _, inst in ipairs(MOCK.allInstances) do
	if inst.ClassName == "TextBox" and inst.PlaceholderText == "Search" then searchBox = inst end
end
assert(searchBox, "search box was not created")
local optionsFrame = searchBox.Parent.Parent:FindFirstChild("Options")
assert(optionsFrame, "options list missing from the search dropdown")
local function countRows()
	local n = 0
	for _, c in ipairs(optionsFrame:GetChildren()) do
		if c.ClassName == "TextButton" then n = n + 1 end
	end
	return n
end
assert(countRows() == 2, "unfiltered list should show both options, got " .. countRows())
searchBox.Text = "leg"
assert(countRows() == 1, "search filter should leave one row, got " .. countRows())
searchBox.Text = ""
assert(countRows() == 2, "clearing the search should restore both rows")

--------------------------------------------------------------------
-- interaction focus: one element owns the pointer at a time
--------------------------------------------------------------------
local function sliderHit(slider)
	return slider.Instance:FindFirstChild("Lane"):FindFirstChild("Hit")
end
local function press(x)
	return { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(x, 0, 0) }
end

local sliderA = Misc:Slider({ Title = "A", Min = 0, Max = 100, Default = 0 })
local sliderB = Misc:Slider({ Title = "B", Min = 0, Max = 100, Default = 0 })

-- track is 200 wide at x=0 in the mock, so x=100 is the midpoint
sliderHit(sliderA).InputBegan:Fire(press(100))
assert(Onyx.Focus == sliderA, "dragging a slider should take focus")
assert(sliderA:Get() == 50, "slider A should have moved, got " .. tostring(sliderA:Get()))

sliderHit(sliderB).InputBegan:Fire(press(150))
assert(sliderB:Get() == 0, "slider B must ignore input while slider A is captured")
assert(Onyx.Focus == sliderA, "focus should still belong to slider A")

MOCK.UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
assert(Onyx.Focus == nil, "releasing should clear focus")

sliderHit(sliderB).InputBegan:Fire(press(150))
assert(sliderB:Get() == 75, "slider B should work once focus is free, got " .. tostring(sliderB:Get()))
MOCK.UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })

-- a row behind an open popout must not light up on hover
local ddRow = dd.Instance
local idle = ddRow.BackgroundColor3
dd.Instance.MouseButton1Click:Fire()
MOCK.step(0.5)
assert(Onyx.Focus ~= nil, "an open popout should hold focus")
ddRow.MouseEnter:Fire()
assert(ddRow.BackgroundColor3 == idle, "the row behind an open dropdown must stay idle")
tog.Instance.MouseEnter:Fire()
assert(tog.Instance.BackgroundColor3 == idle, "other rows must stay idle while a popout is open")

-- but controls inside the thing that owns focus must still respond
local dialogIdle
local focusDialog = Window:Dialog({ Title = "Hover me", Buttons = { { Title = "Nope" }, { Title = "Yep", Primary = true } } })
local nopeBtn
for _, inst in ipairs(MOCK.allInstances) do
	if inst.ClassName == "TextButton" and inst.Text == "Nope" then nopeBtn = inst end
end
assert(nopeBtn, "dialog button not found")
dialogIdle = nopeBtn.BackgroundColor3
nopeBtn.MouseEnter:Fire()
assert(nopeBtn.BackgroundColor3 ~= dialogIdle, "a dialog's own buttons must still hover while it owns focus")
nopeBtn.MouseLeave:Fire()
focusDialog.Close()
MOCK.step(0.5)
dd.Instance.MouseButton1Click:Fire()
MOCK.step(0.5)

-- and it lights up again the moment the popout closes
dd.Instance.MouseButton1Click:Fire()
MOCK.step(0.5)
assert(Onyx.Focus == nil, "closing the popout should release focus")
assert(ddRow.BackgroundColor3 ~= idle, "the hovered row should light up once focus is free")
ddRow.MouseLeave:Fire()
tog.Instance.MouseLeave:Fire()

--------------------------------------------------------------------
-- a dialog has to expand a minimized window to be visible
--------------------------------------------------------------------
Window:Minimize(true)
assert(Window.Minimized == true, "window should be minimized")
local expandDialog = Window:Dialog({ Title = "Still visible?", Content = "yes" })
assert(Window.Minimized == false, "opening a dialog must expand a minimized window")
expandDialog.Close()
MOCK.step(0.5)

Window:SetVisible(false)
local hiddenDialog = Window:Dialog({ Title = "Shown", Content = "yes" })
assert(Window.Visible == true, "opening a dialog must show a hidden window")
hiddenDialog.Close()
MOCK.step(0.5)

--------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------
local toastB = Onyx:Notify({ Title = "Saved", Content = "config.json", Type = "success", Duration = 4 })
local toastCard = toastB.Instance
assert(toastCard:FindFirstChild("Badge"), "notification should have a status badge")
assert(toastCard.Badge:FindFirstChild("Glyph"), "status badge should have a drawn glyph")
assert(#toastCard.Badge.Glyph:GetChildren() == 2, "a check mark is drawn from two bars")
assert(toastCard:FindFirstChild("Timer"), "notification should have a countdown")
assert(toastCard:FindFirstChild("Body"), "notification should have a body")
toastB.Close()
MOCK.step(1)

for _, kind in ipairs({ "info", "warning", "error", "default" }) do
	local t = Onyx:Notify({ Title = kind, Content = "body", Type = kind, Duration = 0 })
	assert(t.Instance.Badge:FindFirstChild("Glyph"), kind .. " should draw a glyph")
	t.Close()
end
MOCK.step(1)

Onyx:SetNotificationCorner("top-left")
assert(Onyx.NotificationCorner == "top-left", "notification corner not stored")
Onyx:SetNotificationCorner("bottom-right")

--------------------------------------------------------------------
-- visibility control: unibar icon with a floating fallback
--------------------------------------------------------------------
-- the mock has no CoreGui.TopBarApp, so the icon cannot attach and the
-- fallback button should appear once the grace period elapses
MOCK.step(6)
assert(Window.Unibar ~= nil, "a unibar attach should have been attempted")
assert(Window.Unibar.Icon == nil, "no unibar exists in the mock, so no icon")
assert(Window.MobileButton ~= nil, "the floating fallback should exist after the grace period")
assert(Window.MobileButton:FindFirstChild("OnyxMark"), "the fallback button should use the Onyx mark")

Window:SetVisible(true)
local beforeToggle = Window.Visible
Window.MobileButton.MouseButton1Click:Fire()
assert(Window.Visible ~= beforeToggle, "the fallback button should toggle the window")
Window:SetVisible(true)

--------------------------------------------------------------------
-- live text: labels and paragraphs driven by a function
--------------------------------------------------------------------
local RS = game:GetService("RunService")
local tick = 0

local liveLabel = Misc:Label({ Title = function() return "count: " .. tick end })
RS.Heartbeat:Fire(0.2)
assert(liveLabel.Instance.Text == "count: 0", "live label did not take its first value")
tick = 7
RS.Heartbeat:Fire(0.2)
assert(liveLabel.Instance.Text == "count: 7", "live label did not follow the value")

liveLabel:Unbind()
tick = 9
RS.Heartbeat:Fire(0.2)
assert(liveLabel.Instance.Text == "count: 7", "unbind should stop updates")

liveLabel:SetText("static")
assert(liveLabel.Instance.Text == "static", "SetText should still work after unbind")
liveLabel:SetText(function() return "rebound " .. tick end)
RS.Heartbeat:Fire(0.2)
assert(liveLabel.Instance.Text == "rebound 9", "passing a function to SetText should rebind")

local livePara = Misc:Paragraph({ Title = "Live", Content = function() return "value " .. tick end })
RS.Heartbeat:Fire(0.2)
assert(livePara.Instance.Title.Text == "Live", "a static paragraph title should stay put")
assert(livePara.Instance.Content.Text == "value 9", "live paragraph body did not bind")
tick = 11
RS.Heartbeat:Fire(0.2)
assert(livePara.Instance.Content.Text == "value 11", "live paragraph body did not follow")
livePara:BindTitle(function() return "T" .. tick end)
RS.Heartbeat:Fire(0.2)
assert(livePara.Instance.Title.Text == "T11", "BindTitle did not take")
livePara:SetContent("frozen")
RS.Heartbeat:Fire(0.2)
assert(livePara.Instance.Content.Text == "frozen", "SetContent should unbind the body")

-- a destroyed live element must stop polling
livePara:Destroy()
liveLabel:Destroy()
RS.Heartbeat:Fire(0.2)

--------------------------------------------------------------------
-- console
--------------------------------------------------------------------
local console = Misc:Console({ Title = "Output", Height = 120, MaxLines = 3 })
local screen = console.Instance:FindFirstChild("Screen")
assert(screen, "console should have a screen")
local placeholder = screen.List:FindFirstChild("Placeholder")
assert(placeholder and placeholder.Visible == true, "an empty console shows its placeholder")

console:Log("hello", "world")
assert(#console.Lines == 1, "console should have one line")
assert(console.Lines[1].Text == "hello world", "console should join arguments with a space")
assert(placeholder.Visible == false, "placeholder hides once there is output")

console:Info("i")
console:Success("s")
console:Warn("w")
console:Error("e")
assert(#console.Lines == 3, "ring buffer should cap at MaxLines, got " .. #console.Lines)
assert(console.Lines[1].Text == "s", "the oldest lines should be dropped first")
assert(console.Lines[3].Level == "error", "last line should keep its level")
assert(console:GetText() == "s\nw\ne", "GetText should join the surviving lines")
assert(console:Copy() == false, "no clipboard exists in the mock")

console:SetHeight(90)
assert(screen.Size.Y.Offset == 90, "SetHeight did not resize the screen")

console:Clear()
assert(#console.Lines == 0, "clear should empty the buffer")
assert(placeholder.Visible == true, "clear should bring the placeholder back")

-- header actions are wired
local clearBtn
for _, c in ipairs(console.Instance.Head:GetDescendants()) do
	if c.ClassName == "TextButton" and c.Text == "CLEAR" then clearBtn = c end
end
assert(clearBtn, "console should have a CLEAR action")
console:Log("about to be cleared")
clearBtn.MouseButton1Click:Fire()
assert(#console.Lines == 0, "the CLEAR action should empty the console")

local seeded = Misc:Console({ Title = "Seeded", Lines = { "one", { Text = "two", Level = "warn" } } })
assert(#seeded.Lines == 2, "Lines config should seed the console")
assert(seeded.Lines[2].Level == "warn", "seeded line levels should be honoured")
seeded:Destroy()

--------------------------------------------------------------------
-- things placed below Roblox's topbar
--------------------------------------------------------------------
-- the mock reports TopbarInset 44 and GetGuiInset 36, so the larger wins
local placedMark = Onyx:Watermark({ Text = "inset" })
assert(placedMark.Instance.Position.Y.Offset == 54,
	"watermark should sit below the unibar, got " .. placedMark.Instance.Position.Y.Offset)
assert(Window.MobileButton.Position.Y.Offset == 54,
	"the fallback button should sit below the unibar too")

placedMark:SetPosition(UDim2.fromOffset(4, 4))
assert(placedMark.Instance.Position.Y.Offset == 4, "SetPosition should win")
placedMark:Destroy()

local fixedMark = Onyx:Watermark({ Text = "fixed", Position = UDim2.fromOffset(2, 3) })
assert(fixedMark.Instance.Position.Y.Offset == 3, "an explicit Position should be left alone")
fixedMark:Destroy()

--------------------------------------------------------------------
-- mini elements pair two to a row
--------------------------------------------------------------------
local Pairs = Visuals:CreateSection("Mini")

local miniA = Pairs:Button({ Title = "A", Mini = true })
local miniB = Pairs:Toggle({ Title = "B", Mini = true })
assert(miniA.Instance.Parent == miniB.Instance.Parent, "two minis should share a row")
assert(miniA.Instance.Parent.Name == "Pair", "minis should live in a Pair row")
assert(miniA.Instance.Size.X.Scale == 0.5 and miniA.Instance.Size.X.Offset == -3,
	"a mini should be half width minus half the gutter")
assert(miniA.Instance.LayoutOrder == 1 and miniB.Instance.LayoutOrder == 2,
	"minis should order left to right within their row")

-- a third opens a fresh row
local miniC = Pairs:Keybind({ Title = "C", Mini = true })
assert(miniC.Instance.Parent ~= miniA.Instance.Parent, "a third mini starts a new row")
assert(miniC.Instance.Parent.Name == "Pair", "the new row is still a Pair")

-- anything full width closes the open pair
local miniD = Pairs:Colorpicker({ Title = "D", Mini = true })
assert(miniD.Instance.Parent == miniC.Instance.Parent, "the second half should still be free")
local fullSlider = Pairs:Slider({ Title = "full", Min = 0, Max = 10 })
assert(fullSlider.Instance.Parent == Pairs.Container, "a slider is always full width")
assert(fullSlider.Instance.Size.X.Scale == 1, "a slider should span the row")
local miniE = Pairs:Button({ Title = "E", Mini = true })
assert(miniE.Instance.Parent ~= miniC.Instance.Parent, "a full-width element must break the pair")

-- Break() abandons a half-filled row on demand
local miniF = Pairs:Button({ Title = "F", Mini = true })
assert(miniF.Instance.Parent == miniE.Instance.Parent, "F should join E")
Pairs:Break()
local miniG = Pairs:Button({ Title = "G", Mini = true })
assert(miniG.Instance.Parent ~= miniE.Instance.Parent, "Break should start a new row")

-- Mini is ignored where it cannot work
local wideDrop = Pairs:Dropdown({ Title = "wide", Values = { "x" }, Mini = true })
assert(wideDrop.Instance.Size.X.Scale == 1, "a dropdown stays full width even when asked to be mini")

--------------------------------------------------------------------
-- settings page
--------------------------------------------------------------------
local function findRow(root, className, title)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst.Name == className then
			local col = inst:FindFirstChild("Text")
			local label = col and col:FindFirstChild("Title")
			if label and label.Text == title then return inst end
		end
	end
	return nil
end

assert(Window.SettingsPage, "the window should have a settings page")
assert(Window.SettingsPage.Visible == false, "settings should start closed")

Window:OpenSettings()
assert(Window.SettingsOpen == true, "OpenSettings should open it")
assert(Window.SettingsPage.Visible == true, "the page should be visible")
assert(Onyx.Focus == Window.SettingsPage, "the settings page should own the pointer")

-- the page's own controls must still respond while it holds focus
local autoSaveRow = findRow(Window.SettingsPage, "Toggle", "Auto save")
assert(autoSaveRow, "settings should offer an auto save toggle")
local settingsIdle = autoSaveRow.BackgroundColor3
autoSaveRow.MouseEnter:Fire()
assert(autoSaveRow.BackgroundColor3 ~= settingsIdle,
	"controls inside the settings page must hover while it owns focus")
autoSaveRow.MouseLeave:Fire()

-- the config actions are laid out as mini pairs
local saveRow = findRow(Window.SettingsPage, "Button", "Save")
local loadRow = findRow(Window.SettingsPage, "Button", "Load")
assert(saveRow and loadRow, "settings should offer save and load")
assert(saveRow.Parent == loadRow.Parent and saveRow.Parent.Name == "Pair",
	"save and load should sit side by side")

-- auto save / auto load persist to the settings file
autoSaveRow.MouseButton1Click:Fire()
assert(Onyx.Settings.AutoSave == true, "the toggle should update the stored setting")
assert(MOCK.files["OnyxUI/settings.json"], "settings should be written to disk")
autoSaveRow.MouseButton1Click:Fire()
assert(Onyx.Settings.AutoSave == false, "toggling back should clear it")

-- auto load is set and cleared by name, not toggled
local setAutoRow = findRow(Window.SettingsPage, "Button", "Auto load this")
local clearAutoRow = findRow(Window.SettingsPage, "Button", "No auto load")
assert(setAutoRow and clearAutoRow, "settings should offer set and clear auto load buttons")
assert(setAutoRow.Parent == clearAutoRow.Parent and setAutoRow.Parent.Name == "Pair",
	"the two auto load buttons should sit side by side")
assert(findRow(Window.SettingsPage, "Toggle", "Auto load") == nil,
	"the auto load toggle should be gone")

-- scripts can add their own settings sections
local custom = Window:SettingsSection("Script")
custom:Toggle({ Title = "Custom setting", Mini = true })
custom:Button({ Title = "Custom action", Mini = true })
assert(custom.Instance.Parent == Window.SettingsPage.Body,
	"a custom settings section should land on the settings page")
assert(findRow(Window.SettingsPage, "Toggle", "Custom setting"), "the custom toggle should exist")

Window:CloseSettings()
MOCK.step(0.5)
assert(Window.SettingsOpen == false, "CloseSettings should close it")
assert(Onyx.Focus == nil, "closing settings should release the pointer")

-- and the settings page expands a minimized window, like a dialog
Window:Minimize(true)
Window:ToggleSettings()
assert(Window.Minimized == false, "opening settings must expand a minimized window")
Window:CloseSettings()
MOCK.step(0.5)

--------------------------------------------------------------------
-- auto load points at one config, per game
--------------------------------------------------------------------
assert(Onyx:GetAutoLoad() == nil, "nothing should auto load by default")

-- it has to name a config that exists
local refused, refusedErr = Onyx:SetAutoLoad("never-saved")
assert(refused == false and tostring(refusedErr):find("first"),
	"setting auto load to an unsaved config should refuse")

assert(Onyx:SetAutoLoad("test") == true, "setting auto load to a saved config should work")
assert(Onyx:GetAutoLoad() == "test", "the pointer should stick")

tog:Set(false)
sld:Set(3)
Onyx.AutoLoaded = false
local applied = Onyx:ApplyAutoLoad()
assert(applied == true, "ApplyAutoLoad should report success")
assert(tog:Get() == true and sld:Get() == 72, "auto load should restore the named config")

-- and only once per session, so a second window cannot undo the user's edits
tog:Set(false)
assert(Onyx:ApplyAutoLoad() == false, "auto load should not run twice")
assert(tog:Get() == false, "a second call must not restore anything")
Onyx.AutoLoaded = false

--------------------------------------------------------------------
-- games do not share configs or auto load pointers
--------------------------------------------------------------------
local homePlace = game.PlaceId
game.PlaceId = 9999999          -- pretend we joined somewhere else

assert(Onyx:GameKey() == "place_9999999", "the game key should follow the place")
assert(#Onyx:ListConfigs() == 0, "another game should see none of our configs")
assert(Onyx:GetAutoLoad() == nil, "another game should have its own auto load pointer")

local missing, missingErr = Onyx:LoadConfig("test")
assert(missing == false, "a config from another game must not load")
assert(tostring(missingErr):find("this game"), "and should say why: " .. tostring(missingErr))

-- save one here and check the two stay apart
tog:Set(false)
assert(Onyx:SaveConfig("elsewhere") == true, "saving in another game should work")
assert(Onyx:SetAutoLoad("elsewhere") == true, "and it can be the auto load here")
assert(MOCK.files["OnyxUI/configs/place_9999999/elsewhere.json"], "written under the new game key")

game.PlaceId = homePlace
assert(Onyx:GetAutoLoad() == "test", "coming back should restore this game's pointer")
local elsewhereList = Onyx:ListConfigs()
assert(#elsewhereList == 1 and elsewhereList[1] == "test",
	"and this game should only see its own configs")

--------------------------------------------------------------------
-- a config carrying another game's stamp is refused
--------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local smuggled = HttpService:JSONDecode(MOCK.files["OnyxUI/configs/place_9999999/elsewhere.json"])
assert(smuggled.__onyx, "configs should be stamped with where they were saved")
assert(smuggled.__onyx.PlaceId == 9999999, "the stamp should record the place")

-- drop it into this game's folder by hand, the way copying a file would
MOCK.files["OnyxUI/configs/place_1234567/smuggled.json"] =
	HttpService:JSONEncode(smuggled)

local blocked, blockedErr = Onyx:LoadConfig("smuggled")
assert(blocked == false, "a config stamped for another game must not load")
assert(tostring(blockedErr):find("different game"), "and should say why")

-- an unstamped config (written by an older build) is still trusted
MOCK.files["OnyxUI/configs/place_1234567/legacy.json"] = HttpService:JSONEncode({ aimbot = true })
assert(Onyx:LoadConfig("legacy") == true, "an unstamped config should still load")

--------------------------------------------------------------------
-- deleting the auto load config clears the pointer
--------------------------------------------------------------------
Onyx:SaveConfig("temp")
assert(Onyx:SetAutoLoad("temp") == true)
Onyx:DeleteConfig("temp")
assert(Onyx:GetAutoLoad() == nil, "deleting the auto load config should clear the pointer")

Onyx:SetAutoLoad("test")
assert(Onyx:GetAutoLoad() == "test", "restore the pointer for the rest of the suite")
Onyx:ClearAutoLoad()
assert(Onyx:GetAutoLoad() == nil, "ClearAutoLoad should empty it")

-- the pointer survives a settings round trip
Onyx:SetAutoLoad("test")
Onyx:SaveSettings()
Onyx.Settings.AutoLoad = {}
Onyx:LoadSettings()
assert(Onyx:GetAutoLoad() == "test", "the pointer should persist to disk")

-- auto save writes to the config being worked in, not the startup pointer
Onyx:SaveConfig("working")
assert(Onyx:GetLastConfig() == "working", "saving should become the working config")
Onyx.Settings.AutoSave = true
tog:Set(false)
MOCK.step(3)
Onyx.Settings.AutoSave = false
assert(MOCK.files["OnyxUI/configs/place_1234567/working.json"], "auto save should write the working config")
local stillAuto = HttpService:JSONDecode(MOCK.files["OnyxUI/configs/place_1234567/test.json"])
assert(stillAuto.aimbot == true, "and must not overwrite the auto load config")
Onyx:DeleteConfig("working")

--------------------------------------------------------------------
-- Terminal: commands in, outcomes out
--------------------------------------------------------------------
local Cmds = Visuals:CreateSection("Terminal")
local term = Cmds:Terminal({ Title = "Commands", Height = 150, MaxLines = 50 })

local ran = {}
term:Register("echo", { Description = "repeat the arguments", Callback = function(args)
	ran.echo = args
	return table.concat(args, " ")
end })
term:Register("ok", function() return true end)
term:Register("quiet", function() return nil end)
term:Register("boom", function() error("exploded") end)
term:Register("refuse", function() return false, "not allowed" end)

term:Run("echo hello world")
assert(#term.Entries == 2, "a command should produce an echo and an outcome")
assert(term.Entries[1].Kind == "command" and term.Entries[1].Text == "echo hello world")
assert(term.Entries[2].Kind == "result" and term.Entries[2].Text == "hello world")
assert(ran.echo[1] == "hello" and ran.echo[2] == "world", "arguments should be split")

term:Run("ok")
assert(term.Entries[#term.Entries].Text == "ok", "returning true should read as ok")

term:Run("quiet")
assert(term.Entries[#term.Entries].Kind == "command",
	"returning nil should leave only the echoed command")

term:Run("boom")
local boom = term.Entries[#term.Entries]
assert(boom.Kind == "error" and boom.Text:find("exploded"), "an erroring command should be caught")

term:Run("refuse")
local refused = term.Entries[#term.Entries]
assert(refused.Kind == "error" and refused.Text == "not allowed", "false plus a message is an error")

term:Run("nonsense")
assert(term.Entries[#term.Entries].Kind == "error", "unknown commands should error")
assert(term.Entries[#term.Entries].Text:find("unknown command"), "and say so")

term:Run("help")
assert(#term.Entries > 0, "help should list something")

-- there is deliberately no Log/Info: chatter belongs in a Console
assert(term.Log == nil and term.Info == nil, "a terminal is not a log")

term:Run("clear")
assert(#term.Entries == 0, "the built-in clear should empty it")

-- the input line runs what you type and keeps history
term.Input.Text = "echo typed"
term.Input.FocusLost:Fire(true)
assert(term.Entries[1].Text == "echo typed", "the input line should run the command")
assert(term.History[#term.History] == "echo typed", "typed commands should enter history")
assert(term.Input.Text == "", "the input should clear after running")

--------------------------------------------------------------------
-- Table
--------------------------------------------------------------------
local Data = Visuals:CreateSection("Data")
local hits = {}
local tbl = Data:Table({
	Title = "Targets",
	Columns = { { Title = "Name", Width = 0.5 }, "Distance", "HP" },
	Height = 150,
	Actions = { { Title = "TP", Callback = function(data) hits.tp = data end } },
	OnSelect = function(data, index) hits.selected = index end,
})

tbl:SetRows({ { "Bob", "42", "100" }, { "Alice", "13", "88" } })
assert(#tbl.Rows == 2, "two rows expected")
assert(tbl.Rows[1].Labels[1].Text == "Bob", "first cell should render")
assert(tbl.Columns[1].Width == 0.5, "an explicit column width should be kept")
assert(math.abs(tbl.Columns[2].Width - 0.25) < 1e-6, "the rest should split what is left")

local added = tbl:AddRow({ "Carl", "7", "30" })
assert(#tbl.Rows == 3, "AddRow should append")
added.Update({ "Carl", "8", "30" })
assert(tbl.Rows[3].Labels[2].Text == "8", "Update should rewrite cells")

tbl:Select(2)
assert(hits.selected == 2, "selecting should fire OnSelect")
local selected = tbl:GetSelected()
assert(selected[1] == "Alice", "GetSelected should return the row data")

local tpButton
for _, inst in ipairs(tbl.Rows[1].Instance:GetChildren()) do
	if inst.ClassName == "TextButton" and inst.Text == "TP" then tpButton = inst end
end
assert(tpButton, "row actions should render")
tpButton.MouseButton1Click:Fire()
assert(hits.tp and hits.tp[1] == "Bob", "a row action should receive its row data")

added.Remove()
assert(#tbl.Rows == 2, "Remove should drop the row")
tbl:Clear()
assert(#tbl.Rows == 0, "Clear should empty the table")

--------------------------------------------------------------------
-- PlayerList
--------------------------------------------------------------------
local kicked
local plist = Data:PlayerList({
	Title = "Players", Height = 160,
	Actions = { { Title = "TP", Callback = function(player) kicked = player.Name end } },
})
assert(#plist.Rows == 1, "the roster starts with the local player")

local bob = MOCK.addPlayer("Bob", "Bobby")
assert(#plist.Rows == 2, "PlayerAdded should refresh the list")

local bobRow
for _, row in ipairs(plist.Rows) do
	if row.Player == bob then bobRow = row end
end
assert(bobRow, "the new player should have a row")
assert(bobRow.NameLabel.Text == "Bobby", "rows should show the display name")

plist:Select(bob)
assert(plist:GetSelected() == bob, "selecting a player should stick")

local tpBtn
for _, inst in ipairs(bobRow.Instance:GetChildren()) do
	if inst.ClassName == "TextButton" and inst.Text == "TP" then tpBtn = inst end
end
assert(tpBtn, "player rows should carry actions")
tpBtn.MouseButton1Click:Fire()
assert(kicked == "Bob", "a player action should receive the player")

MOCK.removePlayer(bob)
MOCK.step(0.1)
assert(#plist.Rows == 1, "PlayerRemoving should refresh the list")
assert(plist:GetSelected() == nil, "a selection that left the server should clear")

--------------------------------------------------------------------
-- Tags
--------------------------------------------------------------------
local tagged
local tags = Data:Tags({
	Title = "Blacklist", Default = { "bob" }, Flag = "Blacklist", Max = 3,
	Callback = function(list) tagged = list end,
})
assert(#tags:Get() == 1, "defaults should seed the tags")
assert(tags:Has("bob"), "Has should find a seeded tag")

tags:Add("alice")
assert(#tags:Get() == 2 and tagged[2] == "alice", "Add should append and fire")
assert(tags:Add("alice") == false, "duplicates should be refused")
assert(tags:Add("  ") == false, "blank tags should be refused")

tags:Add("carl")
assert(tags:Add("dave") == false, "Max should cap the list")

tags:Remove("alice")
assert(#tags:Get() == 2 and not tags:Has("alice"), "Remove should drop the tag")
assert(Onyx.Flags.Blacklist and #Onyx.Flags.Blacklist == 2, "tags should publish to their flag")

-- typing into the field adds one
tags.Input.Text = "typed"
tags.Input.FocusLost:Fire(true)
assert(tags:Has("typed"), "typing a tag and pressing enter should add it")
assert(tags.Input.Text == "", "the field should clear after adding")

tags:Set({ "x", "y" })
assert(#tags:Get() == 2 and tags:Has("x"), "Set should replace the whole list")
tags:Clear()
assert(#tags:Get() == 0, "Clear should empty it")

--------------------------------------------------------------------
-- Segmented
--------------------------------------------------------------------
local mode
local seg = Data:Segmented({
	Title = "Mode", Values = { "Legit", "Rage", "Silent" }, Default = "Legit",
	Flag = "Mode", Callback = function(value) mode = value end,
})
assert(seg:Get() == "Legit", "default should apply")
seg:Set("Rage")
local value, index = seg:Get()
assert(value == "Rage" and index == 2, "setting by name should work")
assert(mode == "Rage" and Onyx.Flags.Mode == "Rage", "segmented should fire and publish")
seg:Set(3)
assert(seg:Get() == "Silent", "setting by index should work")
seg:Set("nope")
assert(seg:Get() == "Silent", "an unknown value should be ignored")

local segTrack = seg.Instance:FindFirstChild("Track")
local legitBtn = segTrack:FindFirstChild("Legit")
assert(legitBtn, "each value should render a button")
legitBtn.MouseButton1Click:Fire()
assert(seg:Get() == "Legit", "clicking a segment should select it")

--------------------------------------------------------------------
-- RangeSlider
--------------------------------------------------------------------
local lowSeen, highSeen
local range = Data:RangeSlider({
	Title = "Level", Min = 0, Max = 100, DefaultMin = 20, DefaultMax = 60,
	Increment = 5, Flag = "LevelRange",
	Callback = function(low, high) lowSeen, highSeen = low, high end,
})
local low, high = range:Get()
assert(low == 20 and high == 60, "range defaults should apply")

range:Set(10, 90)
low, high = range:Get()
assert(low == 10 and high == 90, "Set should move both ends")
assert(lowSeen == 10 and highSeen == 90, "the callback should see both ends")

range:Set(80, 30)
low, high = range:Get()
assert(low == 30 and high == 80, "a reversed pair should be corrected")

range:Set(7, 93)
low, high = range:Get()
assert(low == 5 and high == 95, "values should snap to the increment")
assert(Onyx.Flags.LevelRange[1] == 5, "the range should publish as a pair")

-- one range slider at a time, like the plain slider
local rangeHit = range.Instance:FindFirstChild("Lane"):FindFirstChild("Hit")
rangeHit.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(100, 0, 0) })
assert(Onyx.Focus == range, "dragging a range slider should take focus")
MOCK.UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
assert(Onyx.Focus == nil, "releasing should clear it")

--------------------------------------------------------------------
-- Textarea
--------------------------------------------------------------------
local area = Data:Textarea({ Title = "Payload", Height = 90, Default = "a\nb\n", Flag = "Payload" })
assert(area:Get() == "a\nb\n", "the default should load")
assert(#area:GetLines() == 2, "GetLines should split and drop blanks")
area:Set("one\ntwo\nthree")
assert(#area:GetLines() == 3, "Set should replace the content")
assert(Onyx.Flags.Payload == "one\ntwo\nthree", "a textarea should publish to its flag")
assert(area.Instance.Screen.Scroll.Input.MultiLine == true, "the field should be multi-line")

--------------------------------------------------------------------
-- Stats, Progress, Graph
--------------------------------------------------------------------
local Feedback = Visuals:CreateSection("Feedback")
local liveKills = 3
local stats = Feedback:Stats({
	Columns = 3,
	Items = {
		{ Label = "Kills", Value = function() return liveKills end },
		{ Label = "Coins", Value = "120" },
		{ Label = "Time", Value = "0:42" },
	},
})
assert(#stats.Tiles >= 3, "three tiles expected")
RS.Heartbeat:Fire(0.2)
assert(stats.Tiles[1].ValueLabel.Text == "3", "a live stat should poll its value")
liveKills = 9
RS.Heartbeat:Fire(0.2)
assert(stats.Tiles[1].ValueLabel.Text == "9", "and follow it")
stats:Set("Coins", "500")
assert(stats.Tiles[2].ValueLabel.Text == "500", "Set by label should work")

local progress = Feedback:Progress({ Title = "Loading", Max = 100, Value = 0 })
progress:Set(50)
assert(progress:Get() == 50, "progress should store its value")
assert(progress.Instance:FindFirstChild("Track").Fill.Size.X.Scale == 0.5, "the fill should follow")
progress:Set(500)
assert(progress:Get() == 100, "progress should clamp to Max")
progress:SetIndeterminate(true)
assert(progress.Indeterminate == true, "indeterminate should latch")
progress:Set(10)
assert(progress.Indeterminate == false, "setting a value should leave indeterminate")

local graph = Feedback:Graph({ Title = "FPS", Points = 8, Max = 60 })
graph:Push(30)
graph:Push(60)
assert(#graph.Values == 2, "pushes should accumulate")
for _ = 1, 20 do graph:Push(10) end
assert(#graph.Values == 8, "the graph should keep only its sample window")
graph:SetValues({ 1, 2, 3 })
assert(#graph.Values == 3 and graph.Values[3] == 3, "SetValues should replace the window")

local autoGraph = Feedback:Graph({ Title = "Auto", Points = 6 })
autoGraph:SetValues({ 5, 10, 20 })
assert(autoGraph.Max == 20, "an auto-scaled graph should track its peak")

local feed = 0
autoGraph:Bind(function() feed = feed + 1; return feed end, 0.1)
RS.Heartbeat:Fire(0.2)
RS.Heartbeat:Fire(0.2)
assert(#autoGraph.Values > 3, "a bound graph should feed itself")
autoGraph:Unbind()
local frozen = #autoGraph.Values
RS.Heartbeat:Fire(0.2)
assert(#autoGraph.Values == frozen, "Unbind should stop the feed")
graph:Clear()
assert(#graph.Values == 0, "Clear should empty the graph")

--------------------------------------------------------------------
-- loading overlay
--------------------------------------------------------------------
local loader = Window:Loading({ Title = "Connecting", Content = "waiting for the server" })
assert(loader.Instance, "the loader should build")
assert(Onyx.Focus == loader.Instance, "the loader should hold the pointer")
loader:SetStatus("almost there")
loader:SetProgress(0.5)
loader:Close()
MOCK.step(0.5)
assert(Onyx.Focus == nil, "closing the loader should release the pointer")
assert(loader.Closed == true, "the loader should mark itself closed")

--------------------------------------------------------------------
-- collapsible sections
--------------------------------------------------------------------
local folded = {}
local fold = Visuals:CreateSection({
	Title = "Advanced", Collapsible = true,
	OnCollapse = function(state) folded.state = state end,
})
fold:Toggle({ Title = "inside" })
assert(fold.Collapsed == false, "a collapsible section starts open")
assert(fold.Container.Visible == true, "its contents start visible")

fold:SetCollapsed(true)
assert(fold.Collapsed == true and fold.Container.Visible == false, "collapsing should hide the contents")
assert(folded.state == true, "OnCollapse should fire")

fold.Instance.Head.MouseButton1Click:Fire()
assert(fold.Collapsed == false, "clicking the header should expand it again")

local startFolded = Visuals:CreateSection({ Title = "Closed", Collapsed = true })
assert(startFolded.Collapsed == true, "Collapsed should start it folded")
assert(startFolded.Container.Visible == false, "and hide its contents")

-- a plain section still has no header button
local plain = Visuals:CreateSection("Plain")
assert(plain.Instance.Head.ClassName == "Frame", "a non-collapsible header stays a frame")
-- under the property guard, building one at all proves its header is never
-- handed Text or AutoButtonColor, which a Frame does not have
assert(pcall(function() return Visuals:CreateSection("Guarded") end),
	"a plain section must build without touching button-only properties")
assert(plain.SetCollapsed == nil, "and gets no collapse methods")

Settings:Button({ Title = "Unload", Callback = function() end })

MOCK.step(3)

if MOCK.errors and #MOCK.errors > 0 then
	for _, e in ipairs(MOCK.errors) do print("RUNTIME ERROR: " .. e) end
	error(#MOCK.errors .. " runtime error(s) captured")
end

print("instances created: " .. #MOCK.allInstances)

-- teardown
Onyx:Unload()
assert(Onyx.Focus == nil, "unload should release focus")
assert(Onyx.Unloaded == true, "unload flag not set")
assert(#Onyx.Windows == 0, "windows not cleared")
assert(Onyx.Root.Destroyed == true, "root screengui not destroyed")
-- input events must no longer reach dead handlers
MOCK.UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.K }, false)
MOCK.step(1)
if MOCK.errors and #MOCK.errors > 0 then
	for _, e in ipairs(MOCK.errors) do print("POST-UNLOAD ERROR: " .. e) end
	error("errors after unload")
end

print("ALL TESTS PASSED")
