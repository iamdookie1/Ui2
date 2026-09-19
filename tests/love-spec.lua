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
	Width = 290, Keybind = Enum.KeyCode.RightShift,
})
assert(Window and Window.Instance, "no drawer")

local drawer = Window.Instance
local panel = drawer:FindFirstChild("Panel")
local handle = drawer:FindFirstChild("Handle")
assert(panel and handle, "drawer is missing its panel or handle")
assert(drawer.Position.X.Offset == -290, "sidebar should start off-screen")
assert(handle.Position.X.Offset > 290 - 1, "handle must ride the panel's right edge")
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
assert(Main.Page.Visible == false, "the old page should hide")
Main:Select()

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
drop:SetValues({ "A", "B", "C" })
drop:Set("B")
assert(drop:Get() == "B", "dropdown SetValues did not rebuild the list")
drop:SetOpen(false)

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
assert(drawer.Position.X.Offset == -290, "drawer must clamp at the closed edge")
MOCK.UIS.InputEnded:Fire(press(-900))
assert(Window.Open == false, "dragging fully left should close it")

Window:SetOpen(true)
assert(Window.Open == true, "SetOpen failed")

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
