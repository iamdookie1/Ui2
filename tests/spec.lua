-- exercised against the mock environment
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
local placeholder = screen.Lines:FindFirstChild("Placeholder")
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
