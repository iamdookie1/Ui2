--!nonstrict
--[[
	================================================================
	  VOID  ·  v1.0.0
	  A monochrome interface library for Roblox script executors.
	================================================================

	      local Void = loadstring(game:HttpGet("<raw url to VoidUI.lua>"))()

	      local Window = Void:CreateWindow({ Title = "My Script", SubTitle = "v1.0" })
	      local Tab    = Window:CreateTab("Main")
	      local Group  = Tab:CreateSection("Combat")

	      Group:Toggle({ Title = "Aimbot", Flag = "Aimbot", Callback = print })

	  No colour. True black, hairline borders, one white accent that marks
	  every piece of state there is - the selected tab, a lit toggle, a
	  filled slider, a focused field. Values are set in mono so a column of
	  numbers lines up. Corners are 2px, which is to say almost square.

	  It is a floating window: drag the title bar, toggle it with a key,
	  collapse it to its title bar, or send it away entirely.
	================================================================
]]

local CloneRef = (typeof(cloneref) == "function" and cloneref) or function(o) return o end

local Players          = CloneRef(game:GetService("Players"))
local TweenService     = CloneRef(game:GetService("TweenService"))
local UserInputService = CloneRef(game:GetService("UserInputService"))
local CoreGui          = CloneRef(game:GetService("CoreGui"))
local HttpService      = CloneRef(game:GetService("HttpService"))

local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  LIBRARY
-- ================================================================

local Void = {
	Name        = "Void",
	Version     = "1.0.0",

	Windows     = {},
	Flags       = {},
	Options     = {},
	Connections = {},
	Unloaded    = false,
}

-- ================================================================
--  PALETTE
-- ================================================================
--
--  One palette, no themes. The whole point of this library is what it
--  looks like, and what it looks like is nothing: black, four greys, and
--  white. Accent is swappable at runtime for anyone who cannot live
--  without a colour, and everything painted with it follows.

local Ink = {
	Void  = Color3.fromRGB(8, 8, 9),       -- the backdrop
	Panel = Color3.fromRGB(14, 14, 16),    -- window body
	Card  = Color3.fromRGB(22, 22, 25),    -- a row
	Lift  = Color3.fromRGB(32, 32, 36),    -- a row under the cursor
	Line  = Color3.fromRGB(44, 44, 49),    -- every border in the place
	Text  = Color3.fromRGB(245, 245, 247),
	Sub   = Color3.fromRGB(168, 168, 176),
	Mute  = Color3.fromRGB(116, 116, 124),
	Edge  = Color3.fromRGB(255, 255, 255), -- the accent
	OnEdge = Color3.fromRGB(10, 10, 12),   -- text on the accent
	Warn  = Color3.fromRGB(255, 96, 96),
}

Void.Ink = Ink

-- every property bound to a palette entry, so the accent can be changed
-- without rebuilding anything
local Bound = {}

-- ================================================================
--  HELPERS
-- ================================================================

local Ease = {
	Tap    = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Out    = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Glide  = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Settle = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	None   = TweenInfo.new(0),
}

local function Face(name, fallback)
	local ok, font = pcall(function() return Enum.Font[name] end)
	if ok and font then return font end
	return Enum.Font[fallback] or Enum.Font.SourceSans
end

local FONT   = Face("Gotham", "SourceSans")
local FONT_M = Face("GothamMedium", "SourceSansSemibold")
local FONT_B = Face("GothamBold", "SourceSansBold")
local MONO   = Face("Code", "SourceSans")

local function New(class, props, kids)
	local obj = Instance.new(class)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then parent = value else obj[key] = value end
		end
	end
	if kids then
		for _, kid in ipairs(kids) do kid.Parent = obj end
	end
	if parent then obj.Parent = parent end
	return obj
end

local function Move(obj, props, info)
	if not obj or not obj.Parent then return end
	local tween = TweenService:Create(obj, info or Ease.Out, props)
	tween:Play()
	return tween
end

-- binds a property to a palette entry so SetAccent can repaint it later
local function Wash(obj, prop, key)
	obj[prop] = Ink[key]
	table.insert(Bound, { Instance = obj, Property = prop, Key = key })
	return obj
end

local function Sharp(radius, parent)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 3), Parent = parent })
end

local function Hair(parent, key, transparency, thickness)
	local stroke = New("UIStroke", {
		Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
	Wash(stroke, "Color", key or "Line")
	return stroke
end

local function Inset(parent, top, bottom, left, right)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or top or 0),
		PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or left or 0),
		Parent = parent,
	})
end

local function Stack(parent, gap, direction, align)
	return New("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

local function Say(props)
	local p = props or {}
	local key = p.Key
	p.Key = nil
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or FONT
	p.TextSize = p.TextSize or 13
	p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	p.TextYAlignment = p.TextYAlignment or Enum.TextYAlignment.Center
	local label = New("TextLabel", p)
	Wash(label, "TextColor3", key or "Text")
	return label
end

local function Clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

local function Step(value, increment)
	if not increment or increment <= 0 then return value end
	return math.floor(value / increment + 0.5) * increment
end

local function IsClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function Void:Connect(signal, fn)
	local connection = signal:Connect(fn)
	table.insert(Void.Connections, connection)
	return connection
end

local function Run(callback, ...)
	if typeof(callback) ~= "function" then return end
	local ok, err = pcall(callback, ...)
	if not ok then warn("[Void] callback error: " .. tostring(err)) end
end

function Void.SetAccent(a, b)
	local colour = b
	if a ~= Void then colour = a end
	if typeof(colour) ~= "Color3" then return false end

	Ink.Edge = colour
	-- pick readable text for whatever was handed over
	local _, _, value = colour:ToHSV()
	Ink.OnEdge = value > 0.6 and Color3.fromRGB(10, 10, 12) or Color3.fromRGB(245, 245, 247)

	for index = #Bound, 1, -1 do
		local entry = Bound[index]
		if entry.Instance and entry.Instance.Parent then
			if entry.Key == "Edge" or entry.Key == "OnEdge" then
				Move(entry.Instance, { [entry.Property] = Ink[entry.Key] }, Ease.Out)
			end
		else
			table.remove(Bound, index)
		end
	end
	return true
end

-- ================================================================
--  MARKS
-- ================================================================
--
--  Drawn, not typed. Roblox's fonts cannot be relied on for a chevron or
--  a cross, so every mark here is built out of frames.

-- the library's mark: a hollow square with a gap in it, which is as close
-- to drawing nothing as a logo gets
local function Glyph(parent, size, zIndex)
	local holder = New("Frame", {
		Name = "Mark", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = zIndex or 2, Parent = parent,
	})

	local ring = New("Frame", {
		Name = "Ring", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex or 2, Parent = holder,
	})
	Sharp(2, ring)
	local edge = Hair(ring, "Edge", 0, 1.5)

	-- the gap: a slab of the background across the ring's lower right
	local gap = New("Frame", {
		Name = "Gap", BorderSizePixel = 0, Rotation = 45,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.78),
		Size = UDim2.fromOffset(math.ceil(size * 0.6), math.ceil(size * 0.34)),
		ZIndex = (zIndex or 2) + 1, Parent = holder,
	})
	Wash(gap, "BackgroundColor3", "Panel")

	local core = New("Frame", {
		Name = "Core", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.max(2, math.floor(size * 0.22)),
			math.max(2, math.floor(size * 0.22))),
		ZIndex = (zIndex or 2) + 2, Parent = holder,
	})
	Sharp(1, core)
	Wash(core, "BackgroundColor3", "Edge")

	return {
		Instance = holder,
		SetGapColour = function(key) Wash(gap, "BackgroundColor3", key) end,
		Flicker = function()
			Move(edge, { Transparency = 0.7 }, Ease.Tap)
			Move(core, { Size = UDim2.fromOffset(2, 2) }, Ease.Tap)
			task.delay(0.09, function()
				if not holder.Parent then return end
				Move(edge, { Transparency = 0 }, Ease.Out)
				Move(core, {
					Size = UDim2.fromOffset(math.max(2, math.floor(size * 0.22)),
						math.max(2, math.floor(size * 0.22))),
				}, Ease.Out)
			end)
		end,
	}
end

-- a caret: two bars in a V, used for anything that opens
local function Caret(props)
	local size = props.Size or 10
	local holder = New("Frame", {
		Name = "Caret", BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint, Position = props.Position,
		Rotation = props.Rotation or 0, Size = UDim2.fromOffset(size, size),
		ZIndex = props.ZIndex or 2, Parent = props.Parent,
	})

	local bars = {}
	for index = 1, 2 do
		bars[index] = New("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(index == 1 and 0.3 or 0.7, 0.5),
			Size = UDim2.fromOffset(math.floor(size * 0.58), 1),
			Rotation = index == 1 and 40 or -40,
			ZIndex = (props.ZIndex or 2) + 1, Parent = holder,
		})
		Wash(bars[index], "BackgroundColor3", props.Key or "Mute")
	end

	return {
		Instance = holder,
		SetColour = function(colour, info)
			for _, bar in ipairs(bars) do
				Move(bar, { BackgroundColor3 = colour }, info or Ease.Tap)
			end
		end,
	}
end

-- a cross, for closing things
local function Cross(props)
	local size = props.Size or 10
	local holder = New("Frame", {
		Name = "Cross", BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint, Position = props.Position,
		Size = UDim2.fromOffset(size, size), ZIndex = props.ZIndex or 2,
		Parent = props.Parent,
	})

	local bars = {}
	for index = 1, 2 do
		bars[index] = New("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Rotation = index == 1 and 45 or -45,
			Size = UDim2.fromOffset(size, 1),
			ZIndex = (props.ZIndex or 2) + 1, Parent = holder,
		})
		Wash(bars[index], "BackgroundColor3", props.Key or "Mute")
	end

	return {
		Instance = holder,
		SetColour = function(colour, info)
			for _, bar in ipairs(bars) do
				Move(bar, { BackgroundColor3 = colour }, info or Ease.Tap)
			end
		end,
	}
end

-- a single bar, for collapsing things
local function Dash(props)
	local size = props.Size or 10
	local holder = New("Frame", {
		Name = "Dash", BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint, Position = props.Position,
		Size = UDim2.fromOffset(size, size), ZIndex = props.ZIndex or 2,
		Parent = props.Parent,
	})
	local bar = New("Frame", {
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, 1),
		ZIndex = (props.ZIndex or 2) + 1, Parent = holder,
	})
	Wash(bar, "BackgroundColor3", props.Key or "Mute")
	return {
		Instance = holder,
		SetColour = function(colour, info)
			Move(bar, { BackgroundColor3 = colour }, info or Ease.Tap)
		end,
	}
end

-- ================================================================
--  ROOT
-- ================================================================

local function Host()
	local target
	local ok = pcall(function()
		if typeof(gethui) == "function" then target = gethui() end
	end)

	if not ok or not target then
		local safe = pcall(function()
			local probe = Instance.new("ScreenGui")
			probe.Parent = CoreGui
			probe:Destroy()
			target = CoreGui
		end)
		if not safe then target = nil end
	end

	if not target and LocalPlayer then
		target = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			or LocalPlayer:WaitForChild("PlayerGui", 10)
	end
	return target
end

local Screen = New("ScreenGui", {
	Name = "Void_" .. tostring(math.random(1e5, 1e6 - 1)),
	ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 9997,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

pcall(function()
	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		syn.protect_gui(Screen)
	elseif typeof(protect_gui) == "function" then
		protect_gui(Screen)
	end
end)

Screen.Parent = Host()
Void.Screen = Screen

-- three layers, so a popout is always over a window and a toast is always
-- over both, without anybody having to think about ZIndex
local WindowLayer = New("Frame", {
	Name = "Windows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 10, Parent = Screen,
})
local PopLayer = New("Frame", {
	Name = "Popouts", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 200, Parent = Screen,
})
local ToastLayer = New("Frame", {
	Name = "Toasts", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 400, Parent = Screen,
})

-- ================================================================
--  POPOUTS
-- ================================================================
--
--  Dropdowns and pickers open as floating panels rather than pushing the
--  page around. One at a time, positioned under whatever opened it,
--  closed by anything you click that is not it.

local Popout = { Current = nil }

function Popout.Close()
	local open = Popout.Current
	if not open then return end
	Popout.Current = nil

	-- the outgoing panel fades, but it must stop taking input the moment it
	-- is closed: a dead shade on top of a live one swallows the first click
	-- of whatever opened next
	open.Shade.Active = false
	open.Shade.Name = "Closing"
	open.Panel.Name = "ClosingPopout"

	Move(open.Panel, { BackgroundTransparency = 1 }, Ease.Out)
	Move(open.Panel:FindFirstChildOfClass("UIStroke"), { Transparency = 1 }, Ease.Out)
	Move(open.Panel, { Size = UDim2.fromOffset(open.Width, 0) }, Ease.Out)
	task.delay(0.2, function()
		if open.Shade then open.Shade:Destroy() end
	end)
	Run(open.OnClose)
end

-- `anchor` is the row that opened it; the panel lands directly under it
-- and is nudged back on screen if that would put it off the bottom
function Popout.Open(anchor, width, height, build, onClose)
	Popout.Close()

	local shade = New("TextButton", {
		Name = "Shade", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), ZIndex = 200, Parent = PopLayer,
	})

	local panel = New("Frame", {
		Name = "Popout", BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 0), ZIndex = 201, Parent = shade,
	})
	Sharp(4, panel)
	Wash(panel, "BackgroundColor3", "Panel")
	local stroke = Hair(panel, "Line", 1)
	New("UIListLayout", {
		Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel,
	})
	Inset(panel, 5, 5, 5, 5)

	local spot = anchor.AbsolutePosition
	local span = anchor.AbsoluteSize
	local view = Screen.AbsoluteSize
	local x = spot.X + span.X - width
	local y = spot.Y + span.Y + 4
	if view.Y > 0 and y + height > view.Y - 8 then y = spot.Y - height - 4 end
	if view.X > 0 then x = Clamp(x, 8, math.max(8, view.X - width - 8)) end
	panel.Position = UDim2.fromOffset(math.floor(x), math.floor(math.max(y, 8)))

	Run(build, panel)

	Move(panel, { BackgroundTransparency = 0, Size = UDim2.fromOffset(width, height) }, Ease.Glide)
	Move(stroke, { Transparency = 0 }, Ease.Glide)

	shade.MouseButton1Click:Connect(Popout.Close)
	Popout.Current = { Panel = panel, Shade = shade, Width = width, OnClose = onClose }
	return Popout.Current
end

-- ================================================================
--  NOTIFICATIONS
-- ================================================================
--
--  Fixed heights, laid out by hand. A card that measures itself while
--  holding something sized from the card measures nothing.

local TOAST_WIDTH = 246
local TOAST_TALL  = 60
local TOAST_SHORT = 40

Void.MaxToasts = 4

local ToastStack = New("Frame", {
	Name = "Stack", BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(TOAST_WIDTH, 0), AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 401, Parent = ToastLayer,
}, {
	New("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}),
})

local toastOrder = 0
local liveToasts = {}

function Void.Notify(a, b)
	local cfg = b
	if a ~= Void then cfg = a end
	if typeof(cfg) == "string" then cfg = { Title = cfg } end
	cfg = cfg or {}

	local body = cfg.Content
	if body == "" then body = nil end
	local height = body and TOAST_TALL or TOAST_SHORT
	local duration = tonumber(cfg.Duration) or 4
	local urgent = cfg.Warn == true or cfg.Error == true

	toastOrder = toastOrder + 1
	local limit = math.max(1, tonumber(Void.MaxToasts) or 4)
	while #liveToasts >= limit do
		local oldest = table.remove(liveToasts, 1)
		if oldest then oldest() end
	end

	local slot = New("Frame", {
		Name = "Slot", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = toastOrder, ZIndex = 402, Parent = ToastStack,
	})

	local card = New("Frame", {
		Name = "Toast", BorderSizePixel = 0, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 402, Parent = slot,
	})
	Sharp(4, card)
	Wash(card, "BackgroundColor3", "Panel")
	local stroke = Hair(card, "Line", 1)

	-- one white bar down the left edge. That is the entire decoration.
	local rail = New("Frame", {
		Name = "Rail", BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.new(0, 2, 1, 0), ZIndex = 403, Parent = card,
	})
	Wash(rail, "BackgroundColor3", urgent and "Warn" or "Edge")

	local titleLabel = Say({
		Name = "Title", Parent = card, ZIndex = 403, Font = FONT_M, TextSize = 12.5,
		Text = tostring(cfg.Title or "Void"), TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 14, 0, body and 10 or 0),
		Size = UDim2.new(1, -26, 0, body and 15 or height),
	})
	if urgent then Wash(titleLabel, "TextColor3", "Warn") end

	local bodyLabel
	if body then
		bodyLabel = Say({
			Name = "Content", Parent = card, ZIndex = 403, Font = FONT, TextSize = 11.5,
			Key = "Sub", Text = tostring(body), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -26, 0, 26),
		})
	end

	-- the clock: a hairline under the card that empties as the toast ages
	local clock
	if duration > 0 then
		local lane = New("Frame", {
			Name = "Clock", BackgroundTransparency = 1, ClipsDescendants = true,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 1), ZIndex = 403, Parent = card,
		})
		clock = New("Frame", {
			Name = "Left", BorderSizePixel = 0, BackgroundTransparency = 0.4,
			Size = UDim2.fromScale(1, 1), ZIndex = 403, Parent = lane,
		})
		Wash(clock, "BackgroundColor3", "Edge")
	end

	local hit = New("TextButton", {
		Name = "Hit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), ZIndex = 404, Parent = card,
	})

	Move(card, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Ease.Glide)
	Move(stroke, { Transparency = 0.2 }, Ease.Glide)
	Move(rail, { BackgroundTransparency = 0 }, Ease.Glide)
	Move(titleLabel, { TextTransparency = 0 }, Ease.Glide)
	if bodyLabel then Move(bodyLabel, { TextTransparency = 0.05 }, Ease.Glide) end
	if clock then
		Move(clock, { Size = UDim2.fromScale(0, 1) },
			TweenInfo.new(duration, Enum.EasingStyle.Linear))
	end

	local closed = false
	local function close()
		if closed then return end
		closed = true
		for index, fn in ipairs(liveToasts) do
			if fn == close then table.remove(liveToasts, index); break end
		end

		Move(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0) }, Ease.Out)
		Move(stroke, { Transparency = 1 }, Ease.Out)
		Move(rail, { BackgroundTransparency = 1 }, Ease.Out)
		Move(titleLabel, { TextTransparency = 1 }, Ease.Out)
		if bodyLabel then Move(bodyLabel, { TextTransparency = 1 }, Ease.Out) end
		if clock then Move(clock, { BackgroundTransparency = 1 }, Ease.Out) end
		Move(slot, { Size = UDim2.new(1, 0, 0, 0) }, Ease.Out)
		task.delay(0.28, function() if slot then slot:Destroy() end end)
	end

	hit.MouseButton1Click:Connect(close)
	table.insert(liveToasts, close)
	if duration > 0 then task.delay(duration, close) end
	return { Close = close, Instance = card }
end

-- ================================================================
--  DIALOG
-- ================================================================

function Void.Dialog(a, b)
	local cfg = b
	if a ~= Void then cfg = a end
	cfg = cfg or {}

	local shade = New("TextButton", {
		Name = "Dialog", BackgroundTransparency = 0.5, Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), ZIndex = 300, Parent = PopLayer,
	})
	Wash(shade, "BackgroundColor3", "Void")

	local box = New("Frame", {
		Name = "Box", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(300, 132),
		ZIndex = 301, Parent = shade,
	})
	Sharp(4, box)
	Wash(box, "BackgroundColor3", "Panel")
	Hair(box, "Line", 0)

	Say({
		Name = "Title", Parent = box, ZIndex = 302, Font = FONT_M, TextSize = 13.5,
		Text = tostring(cfg.Title or "Are you sure?"),
		Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 16),
	})
	Say({
		Name = "Content", Parent = box, ZIndex = 302, Font = FONT, TextSize = 12,
		Key = "Sub", Text = tostring(cfg.Content or ""), TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -32, 0, 40),
	})

	local function close()
		Move(box, { Position = UDim2.fromScale(0.5, 0.52) }, Ease.Out)
		Move(shade, { BackgroundTransparency = 1 }, Ease.Out)
		task.delay(0.2, function() if shade then shade:Destroy() end end)
	end

	local buttons = cfg.Buttons or {
		{ Title = cfg.Confirm or "Confirm", Callback = cfg.Callback, Primary = true },
		{ Title = cfg.Cancel or "Cancel" },
	}

	local strip = New("Frame", {
		Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(1, -32, 0, 30),
		ZIndex = 302, Parent = box,
	})
	Stack(strip, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right)

	for index, entry in ipairs(buttons) do
		local button = New("TextButton", {
			Name = tostring(entry.Title), AutoButtonColor = false, Text = "",
			BorderSizePixel = 0, Size = UDim2.fromOffset(96, 30),
			LayoutOrder = index, ZIndex = 302, Parent = strip,
		})
		Sharp(3, button)
		Wash(button, "BackgroundColor3", entry.Primary and "Edge" or "Card")
		if not entry.Primary then Hair(button, "Line", 0.3) end

		Say({
			Parent = button, ZIndex = 303, Font = FONT_M, TextSize = 12,
			Key = entry.Primary and "OnEdge" or "Sub", Text = tostring(entry.Title),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
		})

		button.MouseButton1Click:Connect(function()
			close()
			Run(entry.Callback)
		end)
	end

	Move(box, { Position = UDim2.fromScale(0.5, 0.5) }, Ease.Glide)
	shade.MouseButton1Click:Connect(function()
		if cfg.Dismissable ~= false then close() end
	end)
	return { Close = close, Instance = box }
end

-- ================================================================
--  ELEMENTS
-- ================================================================

local function Register(element, flag)
	if not flag then return end
	element.Flag = flag
	Void.Options[flag] = element
	Void.Flags[flag] = element.Value
end

local function Store(element, value)
	element.Value = value
	if element.Flag then Void.Flags[element.Flag] = value end
end

-- hover and press tinting, shared by everything you can click
local function Reactive(button, rest, lift)
	local inside, held = false, false
	local function settle()
		local key = rest
		if inside or held then key = lift end
		Move(button, { BackgroundColor3 = Ink[key] }, Ease.Tap)
		for _, entry in ipairs(Bound) do
			if entry.Instance == button and entry.Property == "BackgroundColor3" then
				entry.Key = key
			end
		end
	end
	button.MouseEnter:Connect(function() inside = true; settle() end)
	button.MouseLeave:Connect(function() inside = false; held = false; settle() end)
	button.InputBegan:Connect(function(input) if IsClick(input) then held = true; settle() end end)
	button.InputEnded:Connect(function(input) if IsClick(input) then held = false; settle() end end)
	return settle
end

-- The card every element is built on. Title and description on the left, a
-- slot on the right for whatever the element needs, and a marker down the
-- left edge that fills in when the cursor is over it.
local function Plate(parent, opts)
	opts = opts or {}
	local tall = opts.Height or 38

	local plate = New("TextButton", {
		Name = opts.Name or "Row", AutoButtonColor = false, Text = "",
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, tall),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = 12, Parent = parent,
	})
	Sharp(3, plate)
	Wash(plate, "BackgroundColor3", "Card")
	local stroke = Hair(plate, "Line", 0.45)
	Inset(plate, 8, 8, 12, 10)

	-- the marker: 2px wide, scale height, so it can never be measured into
	-- the plate's own height
	local marker = New("Frame", {
		Name = "Marker", BorderSizePixel = 0, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -12, 0.5, 0),
		Size = UDim2.new(0, 2, 0.55, 0), ZIndex = 13, Parent = plate,
	})
	Wash(marker, "BackgroundColor3", "Edge")

	plate.MouseEnter:Connect(function()
		Move(marker, { BackgroundTransparency = 0 }, Ease.Out)
	end)
	plate.MouseLeave:Connect(function()
		Move(marker, { BackgroundTransparency = 1 }, Ease.Out)
	end)

	local column = New("Frame", {
		Name = "Text", BackgroundTransparency = 1,
		Size = UDim2.new(1, -((opts.SlotWidth or 0) + (opts.SlotWidth and 12 or 0)), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 13, Parent = plate,
	})
	Stack(column, 2)

	local title = Say({
		Name = "Title", Parent = column, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
		Text = tostring(opts.Title or ""), Size = UDim2.new(1, 0, 0, 15),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	if opts.Description and opts.Description ~= "" then
		Say({
			Name = "Note", Parent = column, ZIndex = 13, Font = FONT, TextSize = 11.5,
			Key = "Mute", Text = tostring(opts.Description), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
	end

	local slot = New("Frame", {
		Name = "Slot", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(opts.SlotWidth or 0, tall - 16),
		ZIndex = 13, Parent = plate,
	})

	return { Row = plate, Stroke = stroke, Slot = slot, Title = title, Marker = marker }
end

-- Half-width elements pair up: the first one opens a bay, the second one
-- fills it, and anything full width closes it.
local function Bays(parent)
	local bay, taken = nil, 0

	local function place(half)
		if not half then
			bay, taken = nil, 0
			return parent
		end
		if not bay or taken >= 2 then
			bay = New("Frame", {
				Name = "Bay", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = #parent:GetChildren(), ZIndex = 12, Parent = parent,
			})
			Stack(bay, 7, Enum.FillDirection.Horizontal)
			taken = 0
		end
		taken = taken + 1

		local cell = New("Frame", {
			Name = "Half", BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = taken, ZIndex = 12, Parent = bay,
		})
		return cell
	end

	return place
end

-- Every section and tab carries the element constructors directly, so
-- `Group:Toggle{...}` works. That means a constructor name and a method
-- name can collide, and the constructor would win silently - which is
-- exactly what happened to a section's Toggle. Anything already on the
-- holder is a mistake, so say so rather than overwrite it.
local RESERVED = {
	"Label", "Paragraph", "Divider", "Button", "Toggle", "Slider", "Dropdown",
	"Input", "Keybind", "ColorPicker", "Textarea", "Progress", "Console",
	"Stat", "Segmented",
}

local function Elements(holder, parent)
	for _, name in ipairs(RESERVED) do
		if holder[name] ~= nil then
			error("[Void] " .. name .. " is an element constructor and cannot also be a method", 2)
		end
	end

	local place = Bays(parent)
	local function order() return #parent:GetChildren() end

	local function read(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		return cfg or {}
	end

	------------------------------------------------------------
	function holder.Label(p1, p2)
		local cfg = read(p1, p2)
		if typeof(cfg) == "string" then cfg = { Title = cfg } end

		local label = Say({
			Name = "Label", Parent = place(cfg.Half), ZIndex = 12,
			Font = FONT, TextSize = 12.5, Key = "Sub",
			Text = tostring(cfg.Title or cfg.Text or ""), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = order(),
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})

		local api = { Instance = label, Type = "Label" }
		function api.SetText(a, text) label.Text = tostring(a ~= api and a or text) end
		api.Set = api.SetText
		function api.Destroy() label:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Paragraph(p1, p2)
		local cfg = read(p1, p2)

		local box = New("Frame", {
			Name = "Paragraph", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 12, Parent = place(cfg.Half),
		})
		Sharp(3, box)
		Wash(box, "BackgroundColor3", "Card")
		Hair(box, "Line", 0.45)
		Inset(box, 10, 11, 12, 12)
		Stack(box, 5)

		local head = Say({
			Name = "Title", Parent = box, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
			Text = tostring(cfg.Title or ""), Size = UDim2.new(1, 0, 0, 15),
		})
		local body = Say({
			Name = "Content", Parent = box, ZIndex = 13, Font = FONT, TextSize = 12,
			Key = "Sub", Text = tostring(cfg.Content or cfg.Text or ""),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})

		local api = { Instance = box, Type = "Paragraph" }
		function api.SetTitle(a, text) head.Text = tostring(a ~= api and a or text) end
		function api.SetContent(a, text) body.Text = tostring(a ~= api and a or text) end
		api.Set = api.SetContent
		function api.Destroy() box:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Divider(p1, p2)
		local cfg = read(p1, p2)
		if typeof(cfg) == "string" then cfg = { Title = cfg } end

		local wrap = New("Frame", {
			Name = "Divider", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 11),
			LayoutOrder = order(), ZIndex = 12, Parent = place(false),
		})

		local caption = cfg.Title or cfg.Text
		if caption and caption ~= "" then
			local text = Say({
				Parent = wrap, ZIndex = 13, Font = FONT_M, TextSize = 10, Key = "Mute",
				Text = string.upper(tostring(caption)),
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
			})
			for _, side in ipairs({ -1, 1 }) do
				local line = New("Frame", {
					BorderSizePixel = 0, AnchorPoint = Vector2.new(side < 0 and 0 or 1, 0.5),
					Position = UDim2.new(side < 0 and 0 or 1, 0, 0.5, 0),
					Size = UDim2.new(0.5, -34, 0, 1), ZIndex = 12, Parent = wrap,
				})
				Wash(line, "BackgroundColor3", "Line")
			end
			local api = { Instance = wrap, Type = "Divider" }
			function api.SetText(a, t) text.Text = string.upper(tostring(a ~= api and a or t)) end
			function api.Destroy() wrap:Destroy() end
			return api
		end

		local line = New("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 12, Parent = wrap,
		})
		Wash(line, "BackgroundColor3", "Line")

		local api = { Instance = wrap, Type = "Divider" }
		function api.Destroy() wrap:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Button(p1, p2)
		local cfg = read(p1, p2)

		local base = Plate(place(cfg.Half), {
			Name = "Button", Title = cfg.Title or "Button", Description = cfg.Description,
			SlotWidth = 14, LayoutOrder = order(),
		})
		Reactive(base.Row, "Card", "Lift")

		local caret = Caret({
			Parent = base.Slot, ZIndex = 14, Size = 10, Rotation = -90,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		})

		local api = { Instance = base.Row, Type = "Button", Callback = cfg.Callback }

		local function fire()
			Move(base.Stroke, { Color = Ink.Edge, Transparency = 0 }, Ease.Tap)
			caret.SetColour(Ink.Edge)
			Move(caret.Instance, { Position = UDim2.new(1, 4, 0.5, 0) }, Ease.Tap)
			task.delay(0.16, function()
				if not base.Row.Parent then return end
				Move(base.Stroke, { Color = Ink.Line, Transparency = 0.45 }, Ease.Out)
				caret.SetColour(Ink.Mute)
				Move(caret.Instance, { Position = UDim2.new(1, 0, 0.5, 0) }, Ease.Glide)
			end)
			Run(api.Callback)
		end

		base.Row.MouseButton1Click:Connect(function()
			if cfg.Confirm then
				Void.Dialog({
					Title = cfg.ConfirmTitle or tostring(cfg.Title or "Button"),
					Content = cfg.ConfirmText or "This cannot be undone.",
					Confirm = "Run it", Callback = fire,
				})
				return
			end
			fire()
		end)

		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy() base.Row:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Toggle(p1, p2)
		local cfg = read(p1, p2)

		local base = Plate(place(cfg.Half), {
			Name = "Toggle", Title = cfg.Title or "Toggle", Description = cfg.Description,
			SlotWidth = 36, LayoutOrder = order(),
		})
		Reactive(base.Row, "Card", "Lift")

		local track = New("Frame", {
			Name = "Track", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(36, 18),
			ZIndex = 14, Parent = base.Slot,
		})
		Sharp(3, track)
		Wash(track, "BackgroundColor3", "Void")
		local trackEdge = Hair(track, "Line", 0)

		local knob = New("Frame", {
			Name = "Knob", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(12, 12),
			ZIndex = 15, Parent = track,
		})
		Sharp(2, knob)
		Wash(knob, "BackgroundColor3", "Mute")

		local api = { Instance = base.Row, Type = "Toggle", Value = false, Callback = cfg.Callback }

		local function draw(animate)
			local info = animate and Ease.Out or Ease.None
			local knobKey = api.Value and "Edge" or "Mute"
			Move(knob, {
				BackgroundColor3 = Ink[knobKey],
				Position = api.Value and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				Size = api.Value and UDim2.fromOffset(12, 12) or UDim2.fromOffset(10, 10),
			}, info)
			Move(trackEdge, {
				Color = api.Value and Ink.Edge or Ink.Line,
				Transparency = api.Value and 0 or 0.2,
			}, info)
			for _, entry in ipairs(Bound) do
				if entry.Instance == knob then entry.Key = knobKey end
			end
		end

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			Store(api, target and true or false)
			draw(true)
			Run(api.Callback, api.Value)
			return api.Value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set
		function api.Toggle() return api.Set(api, not api.Value) end

		base.Row.MouseButton1Click:Connect(api.Toggle)

		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Register(api, cfg.Flag)
		Store(api, (cfg.Default or cfg.Value) and true or false)
		draw(false)
		if api.Value then Run(api.Callback, true) end
		return api
	end

	------------------------------------------------------------
	function holder.Slider(p1, p2)
		local cfg = read(p1, p2)

		local low = tonumber(cfg.Min) or 0
		local high = tonumber(cfg.Max) or 100
		local step = tonumber(cfg.Increment) or 1
		local suffix = cfg.Suffix or ""
		local places = tonumber(cfg.Rounding) or ((step % 1 == 0) and 0 or 2)

		local box = New("Frame", {
			Name = "Slider", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 12, Parent = place(false),
		})
		Sharp(3, box)
		Wash(box, "BackgroundColor3", "Card")
		Hair(box, "Line", 0.45)
		Inset(box, 9, 11, 12, 12)
		Stack(box, 7)

		local head = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15),
			ZIndex = 13, Parent = box,
		})
		local title = Say({
			Name = "Title", Parent = head, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
			Text = tostring(cfg.Title or "Slider"), Size = UDim2.new(1, -78, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		-- values are set in mono so a column of numbers lines up
		local readout = Say({
			Name = "Value", Parent = head, ZIndex = 13, Font = MONO, TextSize = 12,
			Text = "", TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 78, 1, 0),
		})

		local lane = New("Frame", {
			Name = "Lane", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
			ZIndex = 13, Parent = box,
		})
		local rail = New("Frame", {
			Name = "Rail", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 2),
			ZIndex = 13, Parent = lane,
		})
		Wash(rail, "BackgroundColor3", "Line")

		local fill = New("Frame", {
			Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
			ZIndex = 14, Parent = rail,
		})
		Wash(fill, "BackgroundColor3", "Edge")

		local grip = New("Frame", {
			Name = "Grip", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(3, 12),
			ZIndex = 15, Parent = rail,
		})
		Sharp(1, grip)
		Wash(grip, "BackgroundColor3", "Edge")
		-- the grip glows by growing its stroke: a stroke draws outside the
		-- object, so it can never be measured into the row's height
		local glow = Hair(grip, "Edge", 0.5, 0)

		local api = { Instance = box, Type = "Slider", Value = low, Callback = cfg.Callback }

		local function show(value)
			if places <= 0 then return tostring(math.floor(value + 0.5)) end
			return string.format("%." .. places .. "f", value)
		end

		local function snap(value)
			value = Clamp(Step(value, step), low, high)
			if places > 0 then value = tonumber(string.format("%." .. places .. "f", value)) end
			return value
		end

		local function draw(animate)
			local alpha = (high - low) == 0 and 0 or (api.Value - low) / (high - low)
			local info = animate and Ease.Tap or Ease.None
			Move(fill, { Size = UDim2.fromScale(alpha, 1) }, info)
			Move(grip, { Position = UDim2.fromScale(alpha, 0.5) }, info)
			readout.Text = show(api.Value) .. suffix
		end

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			local snapped = snap(tonumber(target) or low)
			local changed = snapped ~= api.Value
			Store(api, snapped)
			draw(true)
			if changed then Run(api.Callback, snapped) end
			return snapped
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		local dragging = false
		local function apply(x)
			local width = rail.AbsoluteSize.X
			if width <= 0 then return end
			local alpha = Clamp((x - rail.AbsolutePosition.X) / width, 0, 1)
			local value = snap(low + (high - low) * alpha)
			if value ~= api.Value then
				Store(api, value)
				Run(api.Callback, value)
			end
			draw(false)
		end

		local hit = New("TextButton", {
			Name = "Hit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1), ZIndex = 16, Parent = lane,
		})
		hit.InputBegan:Connect(function(input)
			if not IsClick(input) then return end
			dragging = true
			Move(glow, { Thickness = 4, Transparency = 0.4 }, Ease.Out)
			Move(grip, { Size = UDim2.fromOffset(3, 16) }, Ease.Out)
			apply(input.Position.X)
		end)
		Void:Connect(UserInputService.InputChanged, function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			apply(input.Position.X)
		end)
		Void:Connect(UserInputService.InputEnded, function(input)
			if not dragging or not IsClick(input) then return end
			dragging = false
			Move(glow, { Thickness = 0, Transparency = 0.5 }, Ease.Out)
			Move(grip, { Size = UDim2.fromOffset(3, 12) }, Ease.Out)
		end)

		function api.SetTitle(a, text) title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			box:Destroy()
		end

		Register(api, cfg.Flag)
		Store(api, snap(tonumber(cfg.Default) or low))
		draw(false)
		return api
	end

	------------------------------------------------------------
	function holder.Dropdown(p1, p2)
		local cfg = read(p1, p2)

		local multi = cfg.Multi == true or cfg.MultiSelect == true
		local values = cfg.Values or cfg.Options or {}
		local empty = tostring(cfg.Placeholder or "none")

		local base = Plate(place(cfg.Half), {
			Name = "Dropdown", Title = cfg.Title or "Dropdown", Description = cfg.Description,
			SlotWidth = 132, LayoutOrder = order(),
		})
		Reactive(base.Row, "Card", "Lift")

		local field = New("Frame", {
			Name = "Field", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(132, 24),
			ZIndex = 14, Parent = base.Slot,
		})
		Sharp(3, field)
		Wash(field, "BackgroundColor3", "Void")
		local fieldEdge = Hair(field, "Line", 0.2)

		local readout = Say({
			Name = "Value", Parent = field, ZIndex = 15, Font = MONO, TextSize = 11.5,
			Key = "Sub", Text = empty, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -26, 1, 0),
		})
		local caret = Caret({
			Parent = field, ZIndex = 15, Size = 9,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
		})

		local api = {
			Instance = base.Row, Type = "Dropdown", Values = values, Multi = multi,
			Value = multi and {} or nil, Open = false, Callback = cfg.Callback,
		}

		local function chosen(value)
			if not multi then return api.Value == value end
			for _, picked in ipairs(api.Value or {}) do
				if picked == value then return true end
			end
			return false
		end

		local function draw()
			if not multi then
				readout.Text = api.Value == nil and empty or tostring(api.Value)
				return
			end
			local picked = api.Value or {}
			if #picked == 0 then
				readout.Text = empty
			elseif #picked == 1 then
				readout.Text = tostring(picked[1])
			else
				readout.Text = #picked .. " picked"
			end
		end

		local rebuild

		function api.SetSilent(a, value)
			local target = value
			if a ~= api then target = a end
			if multi and typeof(target) ~= "table" then
				target = target == nil and {} or { target }
			end
			Store(api, target)
			draw()
			if api.Open then rebuild() end
			return target
		end

		function api.Set(a, value)
			local target = api.SetSilent(a, value)
			Run(api.Callback, target)
			if not multi then Popout.Close() end
			return target
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		local function flip(value)
			local picked = {}
			local removed = false
			for _, existing in ipairs(api.Value or {}) do
				if existing == value then removed = true else picked[#picked + 1] = existing end
			end
			if not removed then picked[#picked + 1] = value end
			Store(api, picked)
			draw()
			rebuild()
			Run(api.Callback, picked, value, not removed)
			return picked
		end

		function api.Select(a, value)
			local target = value
			if a ~= api then target = a end
			if multi then return flip(target) end
			return api.Set(api, target)
		end

		-- the list is a popout: it floats over the window instead of
		-- pushing every row below it down the page
		local function rows(panel)
			for _, child in ipairs(panel:GetChildren()) do
				if child:IsA("GuiObject") then child:Destroy() end
			end

			for index, value in ipairs(api.Values) do
				local option = New("TextButton", {
					Name = tostring(value), AutoButtonColor = false, Text = "",
					BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26),
					LayoutOrder = index, ZIndex = 202, Parent = panel,
				})
				Sharp(2, option)
				Wash(option, "BackgroundColor3", chosen(value) and "Lift" or "Panel")
				Reactive(option, chosen(value) and "Lift" or "Panel", "Lift")

				Say({
					Parent = option, ZIndex = 203, Font = FONT, TextSize = 12,
					Key = chosen(value) and "Text" or "Sub", Text = tostring(value),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -28, 1, 0),
				})

				if chosen(value) then
					local tick = New("Frame", {
						Name = "Tick", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(6, 6),
						ZIndex = 203, Parent = option,
					})
					Sharp(1, tick)
					Wash(tick, "BackgroundColor3", "Edge")
				end

				option.MouseButton1Click:Connect(function()
					if multi then flip(value) else api.Set(api, value) end
				end)
			end
		end

		rebuild = function()
			local open = Popout.Current
			if open then rows(open.Panel) end
		end

		local function height()
			local count = math.min(#api.Values, 7)
			if count == 0 then return 40 end
			return count * 26 + (count - 1) * 3 + 10
		end

		function api.SetOpen(a, state)
			local wanted = state
			if a ~= api then wanted = a end
			wanted = wanted and true or false

			if not wanted then
				Popout.Close()
				return false
			end

			api.Open = true
			Move(caret.Instance, { Rotation = 180 }, Ease.Out)
			caret.SetColour(Ink.Edge)
			Move(fieldEdge, { Color = Ink.Edge, Transparency = 0 }, Ease.Out)

			Popout.Open(base.Row, 176, height(), rows, function()
				api.Open = false
				Move(caret.Instance, { Rotation = 0 }, Ease.Out)
				caret.SetColour(Ink.Mute)
				Move(fieldEdge, { Color = Ink.Line, Transparency = 0.2 }, Ease.Out)
			end)
			return true
		end
		function api.Toggle() return api.SetOpen(api, not api.Open) end

		base.Row.MouseButton1Click:Connect(api.Toggle)

		function api.SetValues(a, list)
			local next2 = list
			if a ~= api then next2 = a end
			api.Values = next2 or {}

			if multi then
				local kept = {}
				for _, picked in ipairs(api.Value or {}) do
					for _, value in ipairs(api.Values) do
						if value == picked then kept[#kept + 1] = picked; break end
					end
				end
				Store(api, kept)
			else
				local present = false
				for _, value in ipairs(api.Values) do
					if value == api.Value then present = true; break end
				end
				if not present then Store(api, nil) end
			end

			draw()
			if api.Open then rebuild() end
			return api
		end
		api.Refresh = api.SetValues

		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Register(api, cfg.Flag)
		if cfg.Default ~= nil then api.SetSilent(api, cfg.Default) end
		draw()
		return api
	end

	------------------------------------------------------------
	function holder.Input(p1, p2)
		local cfg = read(p1, p2)

		local base = Plate(place(cfg.Half), {
			Name = "Input", Title = cfg.Title or "Input", Description = cfg.Description,
			SlotWidth = 132, LayoutOrder = order(),
		})

		local field = New("Frame", {
			Name = "Field", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(132, 24),
			ZIndex = 14, Parent = base.Slot,
		})
		Sharp(3, field)
		Wash(field, "BackgroundColor3", "Void")
		local fieldEdge = Hair(field, "Line", 0.2)

		local box = New("TextBox", {
			Name = "Box", BackgroundTransparency = 1, Font = MONO, TextSize = 11.5,
			Text = tostring(cfg.Default or ""), ClearTextOnFocus = false,
			PlaceholderText = tostring(cfg.Placeholder or "..."),
			TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = field,
		})
		Wash(box, "TextColor3", "Text")
		Wash(box, "PlaceholderColor3", "Mute")
		Inset(box, 0, 0, 8, 8)

		-- a caret block that blinks while the field has focus
		local beam = New("Frame", {
			Name = "Beam", BorderSizePixel = 0, BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(2, 12), ZIndex = 16, Parent = field,
		})
		Wash(beam, "BackgroundColor3", "Edge")

		local api = { Instance = base.Row, Type = "Input", Value = box.Text, Callback = cfg.Callback }
		local blinking = false

		box.Focused:Connect(function()
			Move(fieldEdge, { Color = Ink.Edge, Transparency = 0 }, Ease.Tap)
			blinking = true
			task.spawn(function()
				while blinking and beam.Parent do
					Move(beam, { BackgroundTransparency = 0 }, Ease.Tap)
					task.wait(0.5)
					if not blinking then break end
					Move(beam, { BackgroundTransparency = 1 }, Ease.Tap)
					task.wait(0.5)
				end
			end)
		end)
		box.FocusLost:Connect(function(enter)
			blinking = false
			beam.BackgroundTransparency = 1
			Move(fieldEdge, { Color = Ink.Line, Transparency = 0.2 }, Ease.Tap)
			Store(api, box.Text)
			Run(api.Callback, box.Text, enter)
		end)
		base.Row.MouseButton1Click:Connect(function() box:CaptureFocus() end)

		function api.Set(a, text)
			local value = text
			if a ~= api then value = a end
			box.Text = tostring(value or "")
			Store(api, box.Text)
			Run(api.Callback, box.Text, false)
			return box.Text
		end
		function api.Get() return box.Text end
		api.SetValue = api.Set

		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			blinking = false
			if api.Flag then Void.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Register(api, cfg.Flag)
		Store(api, box.Text)
		return api
	end

	------------------------------------------------------------
	function holder.Keybind(p1, p2)
		local cfg = read(p1, p2)

		local base = Plate(place(cfg.Half), {
			Name = "Keybind", Title = cfg.Title or "Keybind", Description = cfg.Description,
			SlotWidth = 86, LayoutOrder = order(),
		})
		Reactive(base.Row, "Card", "Lift")

		local chip = New("TextButton", {
			Name = "Chip", AutoButtonColor = false, Text = "NONE", Font = MONO,
			TextSize = 11, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(86, 24),
			ZIndex = 14, Parent = base.Slot,
		})
		Sharp(3, chip)
		Wash(chip, "BackgroundColor3", "Void")
		Wash(chip, "TextColor3", "Sub")
		local chipEdge = Hair(chip, "Line", 0.2)

		local api = {
			Instance = base.Row, Type = "Keybind", Value = cfg.Default,
			Callback = cfg.Callback, Changed = cfg.ChangedCallback,
		}
		local listening = false

		local function draw()
			chip.Text = listening and "..." or string.upper(api.Value and api.Value.Name or "none")
			Move(chipEdge, {
				Color = listening and Ink.Edge or Ink.Line,
				Transparency = listening and 0 or 0.2,
			}, Ease.Tap)
		end

		local function listen() listening = true; draw() end
		chip.MouseButton1Click:Connect(listen)
		base.Row.MouseButton1Click:Connect(listen)

		function api.Set(a, key)
			local value = key
			if a ~= api then value = a end
			if typeof(value) == "string" then
				local ok, item = pcall(function() return Enum.KeyCode[value] end)
				value = ok and item or nil
			end
			listening = false
			Store(api, value)
			draw()
			Run(api.Changed, value)
			return value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		Void:Connect(UserInputService.InputBegan, function(input, processed)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape then api.Set(api, nil)
					else api.Set(api, input.KeyCode) end
				end
				return
			end
			if processed or api.Value == nil then return end
			if input.KeyCode == api.Value then Run(api.Callback, api.Value) end
		end)

		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Register(api, cfg.Flag)
		draw()
		return api
	end

	------------------------------------------------------------
	function holder.ColorPicker(p1, p2)
		local cfg = read(p1, p2)

		local start = cfg.Default or cfg.Value or Ink.Edge
		local hue, sat, val = start:ToHSV()
		local hsv = { hue, sat, val }

		local base = Plate(place(cfg.Half), {
			Name = "ColorPicker", Title = cfg.Title or "Colour",
			Description = cfg.Description, SlotWidth = 44, LayoutOrder = order(),
		})
		Reactive(base.Row, "Card", "Lift")

		local chip = New("Frame", {
			Name = "Swatch", BorderSizePixel = 0, BackgroundColor3 = start,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(44, 20), ZIndex = 14, Parent = base.Slot,
		})
		Sharp(3, chip)
		Hair(chip, "Line", 0.2)

		local api = {
			Instance = base.Row, Type = "ColorPicker", Value = start,
			Open = false, Callback = cfg.Callback,
		}

		local function settle(fire)
			local colour = Color3.fromHSV(hsv[1], hsv[2], hsv[3])
			chip.BackgroundColor3 = colour
			Store(api, colour)
			if fire then Run(api.Callback, colour) end
			return colour
		end

		-- three bars in a popout. A gradient square needs a drag surface
		-- twice this size and reads worse on a phone.
		local function build(panel)
			local names = { "H", "S", "V" }
			for index = 1, 3 do
				local row = New("Frame", {
					Name = names[index], BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22), LayoutOrder = index,
					ZIndex = 202, Parent = panel,
				})
				Say({
					Parent = row, ZIndex = 202, Font = MONO, TextSize = 11, Key = "Mute",
					Text = names[index], Size = UDim2.fromOffset(14, 22),
				})

				local rail = New("Frame", {
					Name = "Rail", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -22, 0, 3),
					ZIndex = 202, Parent = row,
				})
				Wash(rail, "BackgroundColor3", "Line")

				local fill = New("Frame", {
					Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(hsv[index], 1),
					ZIndex = 203, Parent = rail,
				})
				local grip = New("Frame", {
					Name = "Grip", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(hsv[index], 0.5), Size = UDim2.fromOffset(3, 11),
					ZIndex = 204, Parent = rail,
				})
				Sharp(1, grip)

				local function paint()
					local shade = index == 1 and Color3.fromHSV(hsv[1], 1, 1)
						or Color3.fromHSV(hsv[1], hsv[2], hsv[3])
					fill.BackgroundColor3 = shade
					grip.BackgroundColor3 = shade
					fill.Size = UDim2.fromScale(hsv[index], 1)
					grip.Position = UDim2.fromScale(hsv[index], 0.5)
				end
				paint()

				local hit = New("TextButton", {
					BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
					Size = UDim2.fromScale(1, 1), ZIndex = 205, Parent = row,
				})

				local dragging = false
				local function grab(x)
					local width = rail.AbsoluteSize.X
					if width <= 0 then return end
					hsv[index] = Clamp((x - rail.AbsolutePosition.X) / width, 0, 1)
					settle(true)
					for _, sibling in ipairs(panel:GetChildren()) do
						if sibling:IsA("GuiObject") and sibling:FindFirstChild("Rail") then
							local bar = sibling.Rail
							local at = hsv[table.find(names, sibling.Name) or index]
							bar.Fill.Size = UDim2.fromScale(at, 1)
							bar.Grip.Position = UDim2.fromScale(at, 0.5)
							local shade = sibling.Name == "H" and Color3.fromHSV(hsv[1], 1, 1)
								or Color3.fromHSV(hsv[1], hsv[2], hsv[3])
							bar.Fill.BackgroundColor3 = shade
							bar.Grip.BackgroundColor3 = shade
						end
					end
				end

				hit.InputBegan:Connect(function(input)
					if not IsClick(input) then return end
					dragging = true
					grab(input.Position.X)
				end)
				Void:Connect(UserInputService.InputChanged, function(input)
					if not dragging or not rail.Parent then return end
					if input.UserInputType ~= Enum.UserInputType.MouseMovement
						and input.UserInputType ~= Enum.UserInputType.Touch then return end
					grab(input.Position.X)
				end)
				Void:Connect(UserInputService.InputEnded, function(input)
					if dragging and IsClick(input) then dragging = false end
				end)
			end
		end

		function api.SetOpen(a, state)
			local wanted = state
			if a ~= api then wanted = a end
			if not wanted then Popout.Close(); return false end

			api.Open = true
			Popout.Open(base.Row, 176, 86, build, function() api.Open = false end)
			return true
		end
		function api.Toggle() return api.SetOpen(api, not api.Open) end
		base.Row.MouseButton1Click:Connect(api.Toggle)

		function api.Set(a, colour)
			local value = colour
			if a ~= api then value = a end
			if typeof(value) ~= "Color3" then return api.Value end
			hsv[1], hsv[2], hsv[3] = value:ToHSV()
			return settle(true)
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Register(api, cfg.Flag)
		settle(false)
		return api
	end

	------------------------------------------------------------
	function holder.Textarea(p1, p2)
		local cfg = read(p1, p2)

		local box = New("Frame", {
			Name = "Textarea", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 12, Parent = place(false),
		})
		Sharp(3, box)
		Wash(box, "BackgroundColor3", "Card")
		Hair(box, "Line", 0.45)
		Inset(box, 9, 10, 12, 12)
		Stack(box, 7)

		if cfg.Title and cfg.Title ~= "" then
			Say({
				Name = "Title", Parent = box, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
				Text = tostring(cfg.Title), Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1,
			})
		end

		local field = New("Frame", {
			Name = "Field", BorderSizePixel = 0, LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, tonumber(cfg.Height) or 78),
			ZIndex = 13, Parent = box,
		})
		Sharp(3, field)
		Wash(field, "BackgroundColor3", "Void")
		local fieldEdge = Hair(field, "Line", 0.2)

		local input = New("TextBox", {
			Name = "Box", BackgroundTransparency = 1, Font = MONO, TextSize = 11.5,
			Text = tostring(cfg.Default or ""), MultiLine = true, TextWrapped = true,
			ClearTextOnFocus = false, PlaceholderText = tostring(cfg.Placeholder or "..."),
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 14, Parent = field,
		})
		Wash(input, "TextColor3", "Text")
		Wash(input, "PlaceholderColor3", "Mute")
		Inset(input, 7, 7, 9, 9)

		local api = { Instance = box, Type = "Textarea", Value = input.Text, Callback = cfg.Callback }

		input.Focused:Connect(function()
			Move(fieldEdge, { Color = Ink.Edge, Transparency = 0 }, Ease.Tap)
		end)
		input.FocusLost:Connect(function(enter)
			Move(fieldEdge, { Color = Ink.Line, Transparency = 0.2 }, Ease.Tap)
			Store(api, input.Text)
			Run(api.Callback, input.Text, enter)
		end)

		function api.Set(a, text)
			local value = text
			if a ~= api then value = a end
			input.Text = tostring(value or "")
			Store(api, input.Text)
			Run(api.Callback, input.Text, false)
			return input.Text
		end
		function api.Get() return input.Text end
		api.SetValue = api.Set
		function api.Lines()
			local lines = {}
			for line in string.gmatch(input.Text, "[^\r\n]+") do lines[#lines + 1] = line end
			return lines
		end

		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			box:Destroy()
		end

		Register(api, cfg.Flag)
		Store(api, input.Text)
		return api
	end

	------------------------------------------------------------
	function holder.Progress(p1, p2)
		local cfg = read(p1, p2)
		local ceiling = tonumber(cfg.Max) or 1

		local box = New("Frame", {
			Name = "Progress", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = order(), ZIndex = 12, Parent = place(cfg.Half),
		})
		Sharp(3, box)
		Wash(box, "BackgroundColor3", "Card")
		Hair(box, "Line", 0.45)
		Inset(box, 9, 10, 12, 12)
		Stack(box, 7)

		local head = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), ZIndex = 13, Parent = box,
		})
		local title = Say({
			Name = "Title", Parent = head, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
			Text = tostring(cfg.Title or "Progress"), Size = UDim2.new(1, -72, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local readout = Say({
			Name = "Value", Parent = head, ZIndex = 13, Font = MONO, TextSize = 11.5,
			Key = "Sub", Text = "0%", TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 72, 1, 0),
		})

		local rail = New("Frame", {
			Name = "Rail", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 13, Parent = box,
		})
		Wash(rail, "BackgroundColor3", "Line")
		local fill = New("Frame", {
			Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
			ZIndex = 14, Parent = rail,
		})
		Wash(fill, "BackgroundColor3", "Edge")

		local api = { Instance = box, Type = "Progress", Value = 0, Callback = cfg.Callback }

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			target = Clamp(tonumber(target) or 0, 0, ceiling)
			Store(api, target)
			local alpha = ceiling == 0 and 0 or target / ceiling
			Move(fill, { Size = UDim2.fromScale(alpha, 1) }, Ease.Out)
			if cfg.Text == false then
				readout.Text = ""
			elseif ceiling == 1 then
				readout.Text = math.floor(alpha * 100 + 0.5) .. "%"
			else
				readout.Text = math.floor(target + 0.5) .. "/" .. tostring(ceiling)
			end
			Run(api.Callback, target)
			return target
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set
		function api.SetText(a, text) readout.Text = tostring(a ~= api and a or text) end
		function api.SetTitle(a, text) title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			box:Destroy()
		end

		Register(api, cfg.Flag)
		api.Set(api, tonumber(cfg.Default) or 0)
		return api
	end

	------------------------------------------------------------
	function holder.Console(p1, p2)
		local cfg = read(p1, p2)
		local keep = tonumber(cfg.MaxLines) or 90

		local box = New("Frame", {
			Name = "Console", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 12, Parent = place(false),
		})
		Sharp(3, box)
		Wash(box, "BackgroundColor3", "Card")
		Hair(box, "Line", 0.45)
		Inset(box, 9, 10, 12, 12)
		Stack(box, 7)

		if cfg.Title and cfg.Title ~= "" then
			Say({
				Name = "Title", Parent = box, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
				Text = tostring(cfg.Title), Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1,
			})
		end

		local view = New("ScrollingFrame", {
			Name = "View", BorderSizePixel = 0, LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, tonumber(cfg.Height) or 104),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 1, ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 13, Parent = box,
		})
		Sharp(3, view)
		Wash(view, "BackgroundColor3", "Void")
		Wash(view, "ScrollBarImageColor3", "Line")
		Hair(view, "Line", 0.4)
		Inset(view, 7, 7, 9, 9)
		local layout = Stack(view, 2)

		local api = { Instance = box, Type = "Console", Lines = {} }

		function api.Append(a, text, key)
			local line = text
			local tint = key
			if a ~= api then line, tint = a, text end

			local label = Say({
				Parent = view, ZIndex = 14, Font = MONO, TextSize = 11,
				Key = tint or "Sub", Text = tostring(line), TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = #api.Lines + 1,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			})
			table.insert(api.Lines, label)

			while #api.Lines > keep do
				local oldest = table.remove(api.Lines, 1)
				if oldest then oldest:Destroy() end
			end

			-- the canvas lags a frame, so scroll to the layout's own content
			task.defer(function()
				if view.Parent then
					view.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
				end
			end)
			return label
		end
		api.Print = api.Append
		api.Add = api.Append

		function api.Good(a, text) return api.Append(api, a ~= api and a or text, "Text") end
		function api.Bad(a, text) return api.Append(api, a ~= api and a or text, "Warn") end
		api.Success, api.Error = api.Good, api.Bad

		function api.Clear()
			for _, label in ipairs(api.Lines) do label:Destroy() end
			api.Lines = {}
			view.CanvasPosition = Vector2.new(0, 0)
		end
		function api.Destroy() box:Destroy() end

		for _, line in ipairs(cfg.Lines or {}) do api.Append(api, line) end
		return api
	end

	------------------------------------------------------------
	function holder.Stat(p1, p2)
		local cfg = read(p1, p2)

		local base = Plate(place(cfg.Half), {
			Name = "Stat", Title = cfg.Title or "Stat", Description = cfg.Description,
			SlotWidth = 92, Height = 32, LayoutOrder = order(),
		})

		local readout = Say({
			Name = "Value", Parent = base.Slot, ZIndex = 14, Font = MONO, TextSize = 12,
			Text = tostring(cfg.Value or cfg.Default or "-"),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromScale(1, 1),
		})

		local api = { Instance = base.Row, Type = "Stat", Value = readout.Text }

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			readout.Text = tostring(target)
			Store(api, target)
			return target
		end
		api.SetValue = api.Set
		function api.Get() return api.Value end
		function api.SetTitle(a, text) base.Title.Text = tostring(a ~= api and a or text) end
		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Register(api, cfg.Flag)
		return api
	end

	------------------------------------------------------------
	-- a row of options where exactly one is picked. Fewer clicks than a
	-- dropdown when there are three of something.
	function holder.Segmented(p1, p2)
		local cfg = read(p1, p2)
		local values = cfg.Values or cfg.Options or {}

		local box = New("Frame", {
			Name = "Segmented", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 12, Parent = place(false),
		})
		Sharp(3, box)
		Wash(box, "BackgroundColor3", "Card")
		Hair(box, "Line", 0.45)
		Inset(box, 9, 10, 12, 12)
		Stack(box, 7)

		Say({
			Name = "Title", Parent = box, ZIndex = 13, Font = FONT_M, TextSize = 12.5,
			Text = tostring(cfg.Title or "Mode"), Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1,
		})

		local strip = New("Frame", {
			Name = "Options", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 2, ZIndex = 13, Parent = box,
		})
		Stack(strip, 6, Enum.FillDirection.Horizontal)

		local api = { Instance = box, Type = "Segmented", Values = values, Callback = cfg.Callback }
		local cells = {}

		local function draw()
			for _, cell in ipairs(cells) do
				local on = cell.Value == api.Value
				Move(cell.Button, { BackgroundColor3 = on and Ink.Edge or Ink.Void }, Ease.Tap)
				Move(cell.Label, { TextColor3 = on and Ink.OnEdge or Ink.Sub }, Ease.Tap)
				for _, entry in ipairs(Bound) do
					if entry.Instance == cell.Button then entry.Key = on and "Edge" or "Void" end
					if entry.Instance == cell.Label then entry.Key = on and "OnEdge" or "Sub" end
				end
			end
		end

		local function build()
			for _, cell in ipairs(cells) do cell.Button:Destroy() end
			cells = {}

			local count = math.max(#api.Values, 1)
			for index, value in ipairs(api.Values) do
				local button = New("TextButton", {
					Name = tostring(value), AutoButtonColor = false, Text = "",
					BorderSizePixel = 0, LayoutOrder = index, ZIndex = 13, Parent = strip,
					Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0),
				})
				Sharp(2, button)
				Wash(button, "BackgroundColor3", "Void")
				Hair(button, "Line", 0.3)

				local label = Say({
					Parent = button, ZIndex = 14, Font = FONT_M, TextSize = 11.5, Key = "Sub",
					Text = tostring(value), TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromScale(1, 1),
				})

				button.MouseButton1Click:Connect(function() api.Set(api, value) end)
				table.insert(cells, { Button = button, Label = label, Value = value })
			end
			draw()
		end

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			Store(api, target)
			draw()
			Run(api.Callback, target)
			return target
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		function api.SetValues(a, list)
			local next2 = list
			if a ~= api then next2 = a end
			api.Values = next2 or {}
			build()
			return api
		end

		function api.Destroy()
			if api.Flag then Void.Options[api.Flag] = nil end
			box:Destroy()
		end

		Register(api, cfg.Flag)
		if cfg.Default ~= nil then Store(api, cfg.Default) end
		build()
		return api
	end

	return holder
end

-- ================================================================
--  CONFIGURATION
-- ================================================================
--
--  Flags go to a file so a setup survives a rejoin. Configs are filed per
--  game by default, because a walkspeed that suits one game is nonsense
--  in another; pass Scope = "universal" on the window to share them.

local FS = {
	write = typeof(writefile) == "function" and writefile,
	read = typeof(readfile) == "function" and readfile,
	exists = typeof(isfile) == "function" and isfile,
	remove = typeof(delfile) == "function" and delfile,
	folder = typeof(makefolder) == "function" and makefolder,
	isFolder = typeof(isfolder) == "function" and isfolder,
	list = typeof(listfiles) == "function" and listfiles,
}

Void.CanSave = (FS.write and FS.read and FS.exists) and true or false

local ROOT_DIR = "Void"

local function scopeDir()
	local window = Void.Windows[1]
	local scope = window and window.Scope or "game"
	if scope == "universal" then return ROOT_DIR .. "/universal" end
	return ROOT_DIR .. "/" .. tostring(game.PlaceId)
end

local function ensure(path)
	if not FS.folder or not FS.isFolder then return end
	if not FS.isFolder(path) then pcall(FS.folder, path) end
end

local function configPath(name)
	return scopeDir() .. "/" .. tostring(name) .. ".json"
end

-- values that survive a round trip through JSON
local function pack(value)
	if typeof(value) == "Color3" then
		return { __void = "Color3", R = value.R, G = value.G, B = value.B }
	end
	if typeof(value) == "EnumItem" then
		return { __void = "KeyCode", Name = value.Name }
	end
	return value
end

local function unpack(value)
	if typeof(value) == "table" and value.__void then
		if value.__void == "Color3" then
			return Color3.new(value.R, value.G, value.B)
		end
		if value.__void == "KeyCode" then
			local ok, key = pcall(function() return Enum.KeyCode[value.Name] end)
			return ok and key or nil
		end
	end
	return value
end

function Void.SaveConfig(a, b)
	local name = b
	if a ~= Void then name = a end
	name = tostring(name or "default")
	if not Void.CanSave then return false, "this executor cannot write files" end

	local blob = {}
	for flag, element in pairs(Void.Options) do
		if element.Value ~= nil then blob[flag] = pack(element.Value) end
	end

	ensure(ROOT_DIR)
	ensure(scopeDir())

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode({
			Name = name, Place = game.PlaceId, Saved = os.time(), Flags = blob,
		})
	end)
	if not ok then return false, "could not encode: " .. tostring(encoded) end

	local wrote = pcall(FS.write, configPath(name), encoded)
	if not wrote then return false, "could not write the file" end
	return true
end

function Void.LoadConfig(a, b)
	local name = b
	if a ~= Void then name = a end
	name = tostring(name or "default")
	if not Void.CanSave then return false, "this executor cannot read files" end

	local path = configPath(name)
	if not FS.exists(path) then return false, "no config called " .. name end

	local ok, raw = pcall(FS.read, path)
	if not ok then return false, "could not read the file" end

	local decoded
	ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or typeof(decoded) ~= "table" then return false, "that config is not readable" end

	for flag, value in pairs(decoded.Flags or {}) do
		local element = Void.Options[flag]
		if element and element.Set then
			pcall(element.Set, element, unpack(value))
		end
	end
	return true
end

function Void.ListConfigs()
	local names = {}
	if not FS.list or not FS.isFolder then return names end
	if not FS.isFolder(scopeDir()) then return names end

	local ok, files = pcall(FS.list, scopeDir())
	if not ok then return names end

	for _, path in ipairs(files) do
		local name = tostring(path):match("([^/\\]+)%.json$")
		if name then table.insert(names, name) end
	end
	table.sort(names)
	return names
end

function Void.DeleteConfig(a, b)
	local name = b
	if a ~= Void then name = a end
	if not FS.remove or not FS.exists then return false end
	local path = configPath(tostring(name))
	if not FS.exists(path) then return false end
	return pcall(FS.remove, path)
end

-- ================================================================
--  WINDOW
-- ================================================================

function Void.CreateWindow(a, b)
	local cfg = b
	if a ~= Void then cfg = a end
	cfg = cfg or {}

	local size = cfg.Size or UDim2.fromOffset(560, 400)
	local railWidth = tonumber(cfg.RailWidth) or 120

	local Window = {
		Tabs = {}, ActiveTab = nil, Open = cfg.StartOpen ~= false,
		Title = tostring(cfg.Title or "Void"),
		ToggleKey = cfg.Keybind or Enum.KeyCode.RightShift,
		Scope = tostring(cfg.Scope or cfg.SaveType or "game"):lower(),
		Minimised = false,
	}
	if Window.Scope == "uni" then Window.Scope = "universal" end
	if Window.Scope == "per" then Window.Scope = "game" end

	local frame = New("Frame", {
		Name = "Window", BorderSizePixel = 0, ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = size, ZIndex = 11, Parent = WindowLayer,
	})
	Sharp(5, frame)
	Wash(frame, "BackgroundColor3", "Panel")
	local frameEdge = Hair(frame, "Line", 0)
	Window.Instance = frame
	Window.Frame = frame

	----------------------------------------------------------------
	-- title bar
	----------------------------------------------------------------
	local bar = New("TextButton", {
		Name = "Bar", AutoButtonColor = false, Text = "", BorderSizePixel = 0,
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), ZIndex = 12, Parent = frame,
	})
	Inset(bar, 0, 0, 14, 12)

	local mark = Glyph(bar, 13, 13)
	mark.Instance.AnchorPoint = Vector2.new(0, 0.5)
	mark.Instance.Position = UDim2.new(0, 0, 0.5, 0)

	local titleLabel = Say({
		Name = "Title", Parent = bar, ZIndex = 13, Font = FONT_M, TextSize = 13,
		Text = Window.Title, Position = UDim2.new(0, 24, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local subLabel = Say({
		Name = "SubTitle", Parent = bar, ZIndex = 13, Font = MONO, TextSize = 11,
		Key = "Mute", Text = tostring(cfg.SubTitle or ""),
		Position = UDim2.new(0, 24 + 8, 0, 0), Size = UDim2.new(0.5, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- push the subtitle past the title's text width, measured once it exists
	task.defer(function()
		if titleLabel.Parent then
			subLabel.Position = UDim2.new(0, 24 + math.ceil(titleLabel.TextBounds.X) + 10, 0, 0)
		end
	end)

	local rule = New("Frame", {
		Name = "Rule", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 26, 0, 1),
		ZIndex = 12, Parent = bar,
	})
	Wash(rule, "BackgroundColor3", "Line")

	local function barButton(name, order2, draw)
		local button = New("TextButton", {
			Name = name, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(order2 - 1) * 26, 0.5, 0),
			Size = UDim2.fromOffset(24, 24), ZIndex = 13, Parent = bar,
		})
		Sharp(3, button)
		Wash(button, "BackgroundColor3", "Card")
		button.BackgroundTransparency = 1

		local glyph = draw(button)
		button.MouseEnter:Connect(function()
			Move(button, { BackgroundTransparency = 0 }, Ease.Tap)
			glyph.SetColour(Ink.Text)
		end)
		button.MouseLeave:Connect(function()
			Move(button, { BackgroundTransparency = 1 }, Ease.Tap)
			glyph.SetColour(Ink.Mute)
		end)
		return button
	end

	local closeButton = barButton("Close", 1, function(parent)
		return Cross({
			Parent = parent, ZIndex = 14, Size = 9,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		})
	end)
	local foldButton = barButton("Fold", 2, function(parent)
		return Dash({
			Parent = parent, ZIndex = 14, Size = 9,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		})
	end)

	----------------------------------------------------------------
	-- body: rail on the left, pages on the right
	----------------------------------------------------------------
	local body = New("Frame", {
		Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -60), ClipsDescendants = true, ZIndex = 12, Parent = frame,
	})

	local rail = New("ScrollingFrame", {
		Name = "Rail", BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(0, railWidth, 1, 0), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 12, Parent = body,
	})
	Inset(rail, 12, 12, 12, 10)
	Stack(rail, 4)

	local railRule = New("Frame", {
		Name = "Rule", BorderSizePixel = 0, Position = UDim2.fromOffset(railWidth, 0),
		Size = UDim2.new(0, 1, 1, 0), ZIndex = 12, Parent = body,
	})
	Wash(railRule, "BackgroundColor3", "Line")

	-- the marker slides between tabs. Rail buttons are a fixed height, so
	-- where it belongs is arithmetic rather than a measurement.
	local TAB_HEIGHT, TAB_GAP = 30, 4
	local marker = New("Frame", {
		Name = "Marker", BorderSizePixel = 0, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(2, TAB_HEIGHT),
		ZIndex = 13, Parent = body,
	})
	Wash(marker, "BackgroundColor3", "Edge")

	local pages = New("Frame", {
		Name = "Pages", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(railWidth + 1, 0), Size = UDim2.new(1, -railWidth - 1, 1, 0),
		ClipsDescendants = true, ZIndex = 12, Parent = body,
	})

	----------------------------------------------------------------
	-- status strip
	----------------------------------------------------------------
	local strip = New("Frame", {
		Name = "Status", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 12, Parent = frame,
	})
	Inset(strip, 0, 0, 14, 12)

	local stripRule = New("Frame", {
		Name = "Rule", BorderSizePixel = 0, Size = UDim2.new(1, 26, 0, 1),
		ZIndex = 12, Parent = strip,
	})
	Wash(stripRule, "BackgroundColor3", "Line")

	local statusLabel = Say({
		Name = "Text", Parent = strip, ZIndex = 13, Font = MONO, TextSize = 10.5,
		Key = "Mute", Text = tostring(cfg.Status or "ready"), Size = UDim2.new(0.6, 0, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local hintLabel = Say({
		Name = "Hint", Parent = strip, ZIndex = 13, Font = MONO, TextSize = 10.5,
		Key = "Mute", Text = "", TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
	})

	function Window.SetStatus(p1, p2)
		local text = p2
		if p1 ~= Window then text = p1 end
		statusLabel.Text = tostring(text)
		return statusLabel.Text
	end

	local function drawHint()
		hintLabel.Text = Window.ToggleKey and string.upper(Window.ToggleKey.Name) or ""
	end
	drawHint()

	----------------------------------------------------------------
	-- showing, hiding, folding, dragging
	----------------------------------------------------------------
	function Window.SetOpen(p1, p2)
		local open = p2
		if p1 ~= Window then open = p1 end
		Window.Open = open and true or false

		if not Window.Open then Popout.Close() end

		-- the window shrinks slightly as it goes and comes back to size,
		-- which reads as a panel arriving rather than one blinking on
		local resting = Window.Minimised
			and UDim2.new(size.X.Scale, size.X.Offset, 0, 38) or size
		local away = UDim2.new(resting.X.Scale, math.floor(resting.X.Offset * 0.96),
			resting.Y.Scale, math.floor(resting.Y.Offset * 0.96))

		if Window.Open then
			frame.Size = away
			frame.Visible = true
			Move(frame, { BackgroundTransparency = 0, Size = resting }, Ease.Glide)
			Move(frameEdge, { Transparency = 0 }, Ease.Glide)
			mark.Flicker()
		else
			Move(frame, { BackgroundTransparency = 1, Size = away }, Ease.Out)
			Move(frameEdge, { Transparency = 1 }, Ease.Out)
			task.delay(0.2, function()
				if not Window.Open and frame.Parent then frame.Visible = false end
			end)
		end
		return Window.Open
	end
	function Window.Toggle() return Window.SetOpen(Window, not Window.Open) end
	Window.SetVisible = Window.SetOpen

	function Window.Fold(p1, p2)
		local folded = p2
		if p1 ~= Window then folded = p1 end
		if folded == nil then folded = not Window.Minimised end
		Window.Minimised = folded and true or false

		if Window.Minimised then Popout.Close() end
		Move(frame, {
			Size = Window.Minimised and UDim2.new(size.X.Scale, size.X.Offset, 0, 38) or size,
		}, Ease.Glide)
		return Window.Minimised
	end

	foldButton.MouseButton1Click:Connect(function() Window.Fold(Window) end)
	closeButton.MouseButton1Click:Connect(function() Window.SetOpen(Window, false) end)

	-- drag by the title bar
	local dragging, grabX, grabY, startPos = false, 0, 0, nil
	bar.InputBegan:Connect(function(input)
		if not IsClick(input) then return end
		dragging = true
		grabX, grabY = input.Position.X, input.Position.Y
		startPos = frame.Position
		Move(frameEdge, { Color = Ink.Edge, Transparency = 0.4 }, Ease.Tap)
	end)
	Void:Connect(UserInputService.InputChanged, function(input)
		if not dragging or not startPos then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + (input.Position.X - grabX),
			startPos.Y.Scale, startPos.Y.Offset + (input.Position.Y - grabY))
	end)
	Void:Connect(UserInputService.InputEnded, function(input)
		if not dragging or not IsClick(input) then return end
		dragging = false
		Move(frameEdge, { Color = Ink.Line, Transparency = 0 }, Ease.Out)
	end)

	Void:Connect(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		if Window.ToggleKey and input.KeyCode == Window.ToggleKey then Window.Toggle() end
	end)

	function Window.SetToggleKey(p1, p2)
		local key = p2
		if p1 ~= Window then key = p1 end
		Window.ToggleKey = key
		drawHint()
		return key
	end

	function Window.SetTitle(p1, p2)
		local text = p2
		if p1 ~= Window then text = p1 end
		Window.Title = tostring(text)
		titleLabel.Text = Window.Title
		return Window.Title
	end

	function Window.Destroy()
		Popout.Close()
		frame:Destroy()
		for index, entry in ipairs(Void.Windows) do
			if entry == Window then table.remove(Void.Windows, index); break end
		end
	end

	----------------------------------------------------------------
	-- tabs
	----------------------------------------------------------------
	local tabOrder = 0

	function Window.CreateTab(p1, p2)
		local tcfg = p2
		if p1 ~= Window then tcfg = p1 end
		if typeof(tcfg) == "string" then tcfg = { Title = tcfg } end
		tcfg = tcfg or {}

		tabOrder = tabOrder + 1
		local name = tostring(tcfg.Title or ("Tab " .. tabOrder))
		local index = tabOrder
		local Tab = { Title = name, Window = Window, Sections = {} }

		local button = New("TextButton", {
			Name = name, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
			LayoutOrder = index, ZIndex = 13, Parent = rail,
		})
		Sharp(3, button)
		Wash(button, "BackgroundColor3", "Card")

		local label = Say({
			Parent = button, ZIndex = 14, Font = FONT_M, TextSize = 11.5, Key = "Mute",
			Text = string.upper(name), Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -16, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
		})

		local page = New("ScrollingFrame", {
			Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), Visible = false, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 1,
			ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 12, Parent = pages,
		})
		Wash(page, "ScrollBarImageColor3", "Line")
		Inset(page, 14, 16, 16, 14)
		Stack(page, 10)

		Tab.Instance, Tab.Page, Tab.Container = button, page, page

		local function paint(active)
			Move(button, { BackgroundTransparency = active and 0 or 1 }, Ease.Out)
			Move(label, { TextColor3 = active and Ink.Text or Ink.Mute }, Ease.Out)
			for _, entry in ipairs(Bound) do
				if entry.Instance == label then entry.Key = active and "Text" or "Mute" end
			end
		end
		Tab.Paint = paint

		button.MouseEnter:Connect(function()
			if Window.ActiveTab ~= Tab then
				Move(label, { TextColor3 = Ink.Sub }, Ease.Tap)
			end
		end)
		button.MouseLeave:Connect(function()
			if Window.ActiveTab ~= Tab then
				Move(label, { TextColor3 = Ink.Mute }, Ease.Tap)
			end
		end)

		function Tab.Select()
			if Window.ActiveTab == Tab then return end
			Popout.Close()

			local leaving = Window.ActiveTab
			if leaving then
				leaving.Paint(false)
				leaving.Page.Visible = false
			end

			Window.ActiveTab = Tab
			page.Visible = true
			page.CanvasPosition = Vector2.new(0, 0)
			paint(true)

			Move(marker, {
				Position = UDim2.fromOffset(0, 12 + (index - 1) * (TAB_HEIGHT + TAB_GAP)),
				BackgroundTransparency = 0,
			}, Ease.Glide)

			-- the page arrives from the right, once, as one piece
			page.Position = UDim2.fromOffset(14, 0)
			Move(page, { Position = UDim2.fromOffset(0, 0) }, Ease.Glide)

			for order2, section in ipairs(Tab.Sections) do
				if section.Reveal then section.Reveal(0.03 * order2) end
			end
		end

		button.MouseButton1Click:Connect(Tab.Select)
		paint(false)

		Elements(Tab, page)

		------------------------------------------------------------
		function Tab.CreateSection(q1, q2)
			local scfg = q2
			if q1 ~= Tab then scfg = q1 end
			if typeof(scfg) == "string" then scfg = { Title = scfg } end
			scfg = scfg or {}

			local shell = New("Frame", {
				Name = "Section", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = #page:GetChildren(),
				ZIndex = 12, Parent = page,
			})
			Stack(shell, 8)

			local head = New("TextButton", {
				Name = "Head", AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, ZIndex = 12, Parent = shell,
			})

			local tick = New("Frame", {
				Name = "Tick", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(6, 1),
				ZIndex = 12, Parent = head,
			})
			Wash(tick, "BackgroundColor3", "Edge")

			local heading = Say({
				Name = "Title", Parent = head, ZIndex = 12, Font = FONT_B, TextSize = 10.5,
				Key = "Mute", Text = string.upper(tostring(scfg.Title or "Section")),
				Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -30, 1, 0),
			})

			local items = New("Frame", {
				Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 12, Parent = shell,
			})
			Stack(items, 7)

			local Section = { Instance = shell, Container = items, Window = Window, Open = true }

			if scfg.Collapsible then
				local caret = Caret({
					Parent = head, ZIndex = 13, Size = 9,
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
				})

				function Section.SetOpen(r1, r2)
					local open = r2
					if r1 ~= Section then open = r1 end
					Section.Open = open and true or false
					items.Visible = Section.Open
					Move(caret.Instance, { Rotation = Section.Open and 0 or -90 }, Ease.Out)
					return Section.Open
				end
				-- deliberately not called Toggle: every section also carries
				-- the element constructors, and Section:Toggle{...} builds a
				-- toggle. Collapsing is Collapse, Expand and SetOpen.
				function Section.Collapse() return Section.SetOpen(Section, false) end
				function Section.Expand() return Section.SetOpen(Section, true) end
				head.MouseButton1Click:Connect(function()
					Section.SetOpen(Section, not Section.Open)
				end)
				if scfg.Open == false then Section.SetOpen(Section, false) end
			end

			-- the heading draws itself in when the tab opens. Both parts are
			-- already the size they end up, so a staggered reveal cannot
			-- shove the page around.
			function Section.Reveal(delaySeconds)
				if not shell.Parent then return end
				tick.Size = UDim2.fromOffset(0, 1)
				heading.TextTransparency = 1
				task.delay(delaySeconds or 0, function()
					if not shell.Parent then return end
					Move(tick, { Size = UDim2.fromOffset(6, 1) }, Ease.Glide)
					Move(heading, { TextTransparency = 0 }, Ease.Glide)
				end)
			end

			function Section.SetTitle(r1, r2)
				local text = r2
				if r1 ~= Section then text = r1 end
				heading.Text = string.upper(tostring(text))
			end

			function Section.Destroy()
				for position, entry in ipairs(Tab.Sections) do
					if entry == Section then table.remove(Tab.Sections, position); break end
				end
				shell:Destroy()
			end

			table.insert(Tab.Sections, Section)
			Elements(Section, items)
			return Section
		end
		Tab.AddSection = Tab.CreateSection

		table.insert(Window.Tabs, Tab)
		if #Window.Tabs == 1 or tcfg.Default then Tab.Select() end
		return Tab
	end
	Window.AddTab = Window.CreateTab

	function Window.Notify(p1, p2)
		return Void.Notify(p1 ~= Window and p1 or p2)
	end

	----------------------------------------------------------------
	-- a button for phones, where there is no Right Shift
	----------------------------------------------------------------
	if cfg.MobileButton ~= false then
		local fob = New("TextButton", {
			Name = "Fob", AutoButtonColor = false, Text = "", BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(14, 82),
			Size = UDim2.fromOffset(34, 34), ZIndex = 20, Parent = WindowLayer,
		})
		Sharp(4, fob)
		Wash(fob, "BackgroundColor3", "Panel")
		Hair(fob, "Line", 0)
		Glyph(fob, 13, 21)
		fob.MouseButton1Click:Connect(function() Window.Toggle() end)
		Window.Fob = fob
	end

	if cfg.Watermark ~= false then
		local stampWidth = 168
		local stamp = New("Frame", {
			Name = "Watermark", BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(stampWidth, 26),
			ZIndex = 20, Parent = WindowLayer,
		})
		Sharp(4, stamp)
		Wash(stamp, "BackgroundColor3", "Panel")
		Hair(stamp, "Line", 0)

		local stampText = Say({
			Parent = stamp, ZIndex = 21, Font = MONO, TextSize = 10.5, Key = "Sub",
			Text = tostring(cfg.WatermarkText or (Window.Title .. " · void")),
			Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})

		Window.Watermark = {
			Instance = stamp,
			SetText = function(text) stampText.Text = tostring(text) end,
			SetVisible = function(state) stamp.Visible = state and true or false end,
		}
	end

	Window.SetOpen(Window, Window.Open)
	table.insert(Void.Windows, Window)
	return Window
end

-- ================================================================
--  FLAGS AND LIFECYCLE
-- ================================================================

function Void.GetFlag(a, b)
	local flag = b
	if a ~= Void then flag = a end
	return Void.Flags[flag]
end

function Void.SetFlag(a, b, c)
	local flag, value = b, c
	if a ~= Void then flag, value = a, b end
	local element = Void.Options[flag]
	if element and element.Set then return element.Set(element, value) end
	Void.Flags[flag] = value
	return value
end

function Void.Unload()
	if Void.Unloaded then return end
	Void.Unloaded = true

	Popout.Close()
	for _, connection in ipairs(Void.Connections) do
		pcall(function() connection:Disconnect() end)
	end
	Void.Connections = {}

	for index = #Void.Windows, 1, -1 do
		local window = Void.Windows[index]
		if window.Fob then window.Fob:Destroy() end
		if window.Watermark then window.Watermark.Instance:Destroy() end
	end
	Void.Windows = {}

	if Screen then Screen:Destroy() end
	Void.Flags, Void.Options = {}, {}
end
Void.Destroy = Void.Unload

return Void
