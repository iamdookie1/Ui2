--!nonstrict
--[[
	================================================================
	  LOVE UI  ·  v1.1.0
	  A pink sidebar interface library for Roblox script executors.
	================================================================

	  Usage:
	      local Love = loadstring(game:HttpGet("<raw url to LoveUI.lua>"))()

	      local Window = Love:CreateWindow({
	          Title    = "My Script",
	          SubTitle = "v1.0",
	          Theme    = "Rose",
	      })

	      local Tab = Window:CreateTab("Main")
	      local Group = Tab:CreateSection("Combat")

	      Group:Toggle({ Title = "Aimbot", Callback = print })

	  The window is a sidebar, not a floating panel: it lives off the left
	  edge of the screen and slides in. A translucent handle rides its right
	  edge, so it is always reachable - drag it right to open, left to close.
	  That handle is the only way in besides the keybind, by design.
	================================================================
]]

local CloneRef = (typeof(cloneref) == "function" and cloneref) or function(o) return o end

local Players          = CloneRef(game:GetService("Players"))
local TweenService     = CloneRef(game:GetService("TweenService"))
local UserInputService  = CloneRef(game:GetService("UserInputService"))
local CoreGui          = CloneRef(game:GetService("CoreGui"))

local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  LIBRARY
-- ================================================================

local Love = {
	Name        = "LoveUI",
	Version     = "1.1.0",

	Windows     = {},
	Flags       = {},
	Options     = {},
	Connections = {},
	Unloaded    = false,
}

-- ================================================================
--  THEMES
-- ================================================================
--
--  Every theme carries pink somewhere, because that is the point of the
--  library. They differ in how loud it is and what it sits on: Rose and
--  Wine are muted and dark, Bubblegum and Midnight are neon, Blush and
--  Sakura are light.

local Themes = {
	Rose = {
		Bg = Color3.fromRGB(18, 16, 19),   Panel = Color3.fromRGB(24, 21, 26),
		Card = Color3.fromRGB(32, 28, 35), Hover = Color3.fromRGB(42, 37, 46),
		Line = Color3.fromRGB(48, 42, 52), Text = Color3.fromRGB(245, 240, 245),
		Sub = Color3.fromRGB(178, 166, 180), Muted = Color3.fromRGB(128, 118, 132),
		Accent = Color3.fromRGB(244, 114, 182), OnAccent = Color3.fromRGB(26, 10, 20),
		Error = Color3.fromRGB(255, 107, 107),
	},
	Bubblegum = {
		Bg = Color3.fromRGB(14, 12, 16),   Panel = Color3.fromRGB(22, 18, 26),
		Card = Color3.fromRGB(33, 26, 40), Hover = Color3.fromRGB(45, 35, 54),
		Line = Color3.fromRGB(56, 44, 66), Text = Color3.fromRGB(250, 245, 252),
		Sub = Color3.fromRGB(190, 175, 200), Muted = Color3.fromRGB(138, 125, 150),
		Accent = Color3.fromRGB(255, 77, 166), OnAccent = Color3.fromRGB(20, 5, 14),
		Error = Color3.fromRGB(255, 92, 92),
	},
	Wine = {
		Bg = Color3.fromRGB(26, 12, 18),   Panel = Color3.fromRGB(36, 16, 25),
		Card = Color3.fromRGB(48, 22, 34), Hover = Color3.fromRGB(62, 29, 44),
		Line = Color3.fromRGB(72, 34, 50), Text = Color3.fromRGB(248, 236, 242),
		Sub = Color3.fromRGB(196, 160, 176), Muted = Color3.fromRGB(146, 112, 128),
		Accent = Color3.fromRGB(236, 110, 158), OnAccent = Color3.fromRGB(30, 8, 16),
		Error = Color3.fromRGB(255, 124, 112),
	},
	Midnight = {
		Bg = Color3.fromRGB(10, 10, 14),   Panel = Color3.fromRGB(16, 16, 22),
		Card = Color3.fromRGB(24, 24, 32), Hover = Color3.fromRGB(34, 34, 44),
		Line = Color3.fromRGB(40, 40, 52), Text = Color3.fromRGB(240, 238, 245),
		Sub = Color3.fromRGB(164, 160, 176), Muted = Color3.fromRGB(118, 114, 130),
		Accent = Color3.fromRGB(255, 64, 152), OnAccent = Color3.fromRGB(12, 4, 10),
		Error = Color3.fromRGB(255, 88, 88),
	},
	Blush = {
		Bg = Color3.fromRGB(250, 244, 247), Panel = Color3.fromRGB(255, 251, 253),
		Card = Color3.fromRGB(248, 238, 243), Hover = Color3.fromRGB(243, 228, 236),
		Line = Color3.fromRGB(231, 213, 224), Text = Color3.fromRGB(45, 32, 40),
		Sub = Color3.fromRGB(110, 92, 104), Muted = Color3.fromRGB(150, 132, 144),
		Accent = Color3.fromRGB(219, 90, 146), OnAccent = Color3.fromRGB(255, 252, 254),
		Error = Color3.fromRGB(198, 42, 52),
	},
	Sakura = {
		Bg = Color3.fromRGB(253, 247, 250), Panel = Color3.fromRGB(255, 253, 254),
		Card = Color3.fromRGB(252, 240, 246), Hover = Color3.fromRGB(247, 230, 239),
		Line = Color3.fromRGB(240, 220, 232), Text = Color3.fromRGB(60, 44, 54),
		Sub = Color3.fromRGB(124, 104, 116), Muted = Color3.fromRGB(164, 144, 156),
		Accent = Color3.fromRGB(240, 148, 184), OnAccent = Color3.fromRGB(58, 28, 42),
		Error = Color3.fromRGB(206, 50, 60),
	},
}

local THEME_ORDER = { "Rose", "Bubblegum", "Wine", "Midnight", "Blush", "Sakura" }

Love.Themes = Themes
Love.ThemeOrder = THEME_ORDER
Love.ThemeName = "Rose"

local Theme = {}
for token, colour in pairs(Themes.Rose) do Theme[token] = colour end

-- every painted property, so switching theme repaints the whole interface
local Painted = {}

-- ================================================================
--  HELPERS
-- ================================================================

local function Font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback or Enum.Font.SourceSans
end

local FONT    = Font("Gotham")
local FONT_M  = Font("GothamMedium", FONT)
local FONT_SB = Font("GothamSemibold", FONT_M)
local FONT_B  = Font("GothamBold", FONT_SB)

local EASE_SNAP   = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_OUT    = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_SMOOTH = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function New(class, props, children)
	local obj = Instance.new(class)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else obj[k] = v end
		end
	end
	if children then
		for _, child in ipairs(children) do child.Parent = obj end
	end
	if parent then obj.Parent = parent end
	return obj
end

local function Tween(obj, props, info)
	if not obj or not obj.Parent then return end
	local t = TweenService:Create(obj, info or EASE_OUT, props)
	t:Play()
	return t
end

-- binds a property to a theme token, so SetTheme can repaint it later
local function Paint(obj, prop, token)
	obj[prop] = Theme[token]
	table.insert(Painted, { Instance = obj, Property = prop, Token = token })
	return obj
end

local function Corner(radius, parent)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function Stroke(parent, token, transparency, thickness)
	local stroke = New("UIStroke", {
		Transparency = transparency or 0, Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
	Paint(stroke, "Color", token or "Line")
	return stroke
end

local function Padding(parent, t, b, l, r)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
		Parent = parent,
	})
end

local function List(parent, gap, dir, align)
	return New("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

local function Text(props)
	local p = props or {}
	local token = p.Token
	p.Token = nil
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or FONT
	p.TextSize = p.TextSize or 13
	p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	p.TextYAlignment = p.TextYAlignment or Enum.TextYAlignment.Center
	local label = New("TextLabel", p)
	Paint(label, "TextColor3", token or "Text")
	return label
end

local function Clamp(v, min, max)
	if v < min then return min end
	if v > max then return max end
	return v
end

local function Round(v, step)
	if not step or step <= 0 then return v end
	return math.floor((v / step) + 0.5) * step
end

local function IsClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

function Love:Connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(Love.Connections, conn)
	return conn
end

local function Fire(callback, ...)
	if typeof(callback) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, args.n))
		if not ok then warn("[LoveUI] callback error: " .. tostring(err)) end
	end)
end

-- A heart, drawn from two rounded squares and a rotated one. Roblox's fonts
-- have no dependable heart glyph, so it is built rather than typed.
local function Heart(parent, size, zIndex)
	local holder = New("Frame", {
		Name = "Heart", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size), ZIndex = zIndex or 2, Parent = parent,
	})

	local parts = {}
	local lobe = math.floor(size * 0.52)

	for i = 1, 2 do
		local bump = New("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i == 1 and 0.31 or 0.69, 0.36),
			Size = UDim2.fromOffset(lobe, lobe), ZIndex = zIndex or 2, Parent = holder,
		})
		Corner(math.ceil(lobe / 2), bump)
		Paint(bump, "BackgroundColor3", "Accent")
		table.insert(parts, bump)
	end

	local body = New("Frame", {
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(math.floor(size * 0.62), math.floor(size * 0.62)),
		ZIndex = zIndex or 2, Parent = holder,
	})
	Corner(2, body)
	Paint(body, "BackgroundColor3", "Accent")
	table.insert(parts, body)

	return {
		Instance = holder,
		SetColour = function(colour, info)
			for _, part in ipairs(parts) do
				Tween(part, { BackgroundColor3 = colour }, info or EASE_SNAP)
			end
		end,
	}
end

-- A chevron from two bars, for the same reason the heart is drawn.
local function Chevron(props)
	local size = props.Size or 10
	local holder = New("Frame", {
		Name = "Chevron", BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint, Position = props.Position,
		Rotation = props.Rotation or 0, Size = UDim2.fromOffset(size, size),
		ZIndex = props.ZIndex or 2, Parent = props.Parent,
	})

	local bars = {}
	for i = 1, 2 do
		bars[i] = New("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i == 1 and 0.28 or 0.72, 0.53),
			Size = UDim2.fromOffset(math.floor(size * 0.6 + 0.5), 1.5),
			Rotation = i == 1 and 38 or -38,
			ZIndex = (props.ZIndex or 2) + 1, Parent = holder,
		})
		Corner(1, bars[i])
		Paint(bars[i], "BackgroundColor3", props.Token or "Muted")
	end

	return {
		Instance = holder,
		SetColour = function(colour, info)
			for _, bar in ipairs(bars) do
				Tween(bar, { BackgroundColor3 = colour }, info or EASE_SNAP)
			end
		end,
	}
end

-- ================================================================
--  ROOT
-- ================================================================

local function GuiParent()
	local target
	local ok = pcall(function()
		if typeof(gethui) == "function" then target = gethui() end
	end)

	if not ok or not target then
		local ok2 = pcall(function()
			local probe = Instance.new("ScreenGui")
			probe.Parent = CoreGui
			probe:Destroy()
			target = CoreGui
		end)
		if not ok2 then target = nil end
	end

	if not target and LocalPlayer then
		target = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			or LocalPlayer:WaitForChild("PlayerGui", 10)
	end
	return target
end

local Root = New("ScreenGui", {
	Name = "LoveUI_" .. tostring(math.random(1e5, 1e6 - 1)),
	ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 9998, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

pcall(function()
	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		syn.protect_gui(Root)
	elseif typeof(protect_gui) == "function" then
		protect_gui(Root)
	end
end)

Root.Parent = GuiParent()
Love.Root = Root

local ToastLayer = New("Frame", {
	Name = "Toasts", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 500, Parent = Root,
})

-- ================================================================
--  THEME SWITCHING
-- ================================================================

-- Every theme picker on screen - the one in the window header, and any
-- Theme dropdown a script puts on a page. Changing the theme from any of
-- them (or from code) updates all the others, so no picker can sit there
-- showing a palette you are no longer using.
local ThemePickers = {}

local function RegisterThemePicker(entry)
	table.insert(ThemePickers, entry)
	entry.Show(Love.ThemeName)
	return entry
end

local function SyncThemePickers(name)
	for i = #ThemePickers, 1, -1 do
		local picker = ThemePickers[i]
		if picker.Instance and picker.Instance.Parent then
			picker.Show(name)
		else
			table.remove(ThemePickers, i)
		end
	end
end

function Love.SetTheme(a, b)
	local name = b
	if a ~= Love then name = a end
	name = tostring(name or "Rose")

	local palette = Themes[name]
	if not palette then return false, "no theme named \"" .. name .. "\"" end

	for token, colour in pairs(palette) do Theme[token] = colour end
	Love.ThemeName = name

	-- repaint everything that was bound to a token, dropping anything gone
	for i = #Painted, 1, -1 do
		local entry = Painted[i]
		if entry.Instance and entry.Instance.Parent then
			Tween(entry.Instance, { [entry.Property] = Theme[entry.Token] }, EASE_OUT)
		else
			table.remove(Painted, i)
		end
	end

	SyncThemePickers(name)

	for _, window in ipairs(Love.Windows) do
		if window.OnTheme then Fire(window.OnTheme, name) end
	end
	return true
end

function Love.NextTheme()
	local index = 1
	for i, name in ipairs(THEME_ORDER) do
		if name == Love.ThemeName then index = i; break end
	end
	local nextName = THEME_ORDER[(index % #THEME_ORDER) + 1]
	Love.SetTheme(Love, nextName)
	return nextName
end

-- ================================================================
--  NOTIFICATIONS
-- ================================================================

-- Toasts are deliberately small and few: they sit in the corner of a game
-- you are trying to see past, so the stack is capped rather than allowed to
-- climb the screen.
local TOAST_WIDTH = 214
Love.MaxToasts = 3

local ToastStack = New("Frame", {
	Name = "Stack", BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14),
	Size = UDim2.fromOffset(TOAST_WIDTH, 0), AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 501, Parent = ToastLayer,
}, {
	New("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}),
})

local toastOrder = 0
local liveToasts = {}

function Love.Notify(a, b)
	local cfg = b
	if a ~= Love then cfg = a end
	if typeof(cfg) == "string" then cfg = { Title = cfg } end
	cfg = cfg or {}

	local duration = tonumber(cfg.Duration) or 4
	toastOrder = toastOrder + 1

	-- push the oldest out rather than letting the stack grow upwards
	local limit = math.max(1, tonumber(Love.MaxToasts) or 3)
	while #liveToasts >= limit do
		local oldest = table.remove(liveToasts, 1)
		if oldest then oldest() end
	end

	local slot = New("Frame", {
		Name = "Slot", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = toastOrder,
		ZIndex = 502, Parent = ToastStack,
	})

	local card = New("Frame", {
		Name = "Toast", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 502, Parent = slot,
	})
	Corner(8, card)
	Paint(card, "BackgroundColor3", "Panel")
	local cardStroke = Stroke(card, "Line", 1)
	Padding(card, 8, 9, 10, 10)
	List(card, 2)

	local heart = Heart(card, 11, 503)
	heart.Instance.AnchorPoint = Vector2.new(0, 0)
	heart.Instance.Position = UDim2.fromOffset(0, 1)
	heart.Instance.LayoutOrder = 0

	local titleLabel = Text({
		Parent = card, ZIndex = 503, Font = FONT_SB, TextSize = 12.5, LayoutOrder = 1,
		Text = tostring(cfg.Title or "LoveUI"), TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 14),
	})

	local bodyLabel
	if cfg.Content and cfg.Content ~= "" then
		-- capped at four lines so one long message cannot fill the screen;
		-- AutomaticSize would happily grow past the top of the display
		local content = tostring(cfg.Content)
		bodyLabel = Text({
			Parent = card, ZIndex = 503, Font = FONT, TextSize = 11.5, LayoutOrder = 2,
			Token = "Sub", Text = content, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
		New("UISizeConstraint", {
			MaxSize = Vector2.new(TOAST_WIDTH, 58), Parent = bodyLabel,
		})
	end

	Tween(card, { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) }, EASE_SMOOTH)
	Tween(cardStroke, { Transparency = 0 }, EASE_SMOOTH)
	Tween(titleLabel, { TextTransparency = 0 }, EASE_SMOOTH)
	if bodyLabel then Tween(bodyLabel, { TextTransparency = 0 }, EASE_SMOOTH) end

	local closed = false
	local function close()
		if closed then return end
		closed = true
		for i, fn in ipairs(liveToasts) do
			if fn == close then table.remove(liveToasts, i); break end
		end
		Tween(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0) }, EASE_OUT)
		Tween(cardStroke, { Transparency = 1 }, EASE_OUT)
		Tween(titleLabel, { TextTransparency = 1 }, EASE_OUT)
		if bodyLabel then Tween(bodyLabel, { TextTransparency = 1 }, EASE_OUT) end
		task.delay(0.25, function() if slot then slot:Destroy() end end)
	end

	local hit = New("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), ZIndex = 504, Parent = card,
	})
	hit.MouseButton1Click:Connect(close)

	table.insert(liveToasts, close)
	if duration > 0 then task.delay(duration, close) end
	return { Close = close, Instance = card }
end

-- ================================================================
--  ELEMENTS
-- ================================================================

local function RegisterFlag(element, flag)
	if not flag then return end
	element.Flag = flag
	Love.Options[flag] = element
	Love.Flags[flag] = element.Value
end

local function SetFlag(element, value)
	element.Value = value
	if element.Flag then Love.Flags[element.Flag] = value end
end

-- hover tinting shared by every pressable row
local function Hoverable(button, base, hover)
	local inside, down = false, false
	local function refresh()
		local token = base
		-- held counts as hovered, so a touch press tints even though a
		-- finger never produces a hover of its own
		if inside or down then token = hover end
		Tween(button, { BackgroundColor3 = Theme[token] }, EASE_SNAP)
		-- keep the binding current so a theme switch lands on the right token
		for _, entry in ipairs(Painted) do
			if entry.Instance == button and entry.Property == "BackgroundColor3" then
				entry.Token = token
			end
		end
	end
	button.MouseEnter:Connect(function() inside = true; refresh() end)
	button.MouseLeave:Connect(function() inside = false; down = false; refresh() end)
	button.InputBegan:Connect(function(i) if IsClick(i) then down = true; refresh() end end)
	button.InputEnded:Connect(function(i) if IsClick(i) then down = false; refresh() end end)
	return refresh
end

-- the card every row is built on: title and optional description on the
-- left, a slot on the right for whatever control the element needs
local function Row(parent, opts)
	opts = opts or {}
	local slotWidth = opts.SlotWidth or 0

	local row = New("TextButton", {
		Name = opts.Name or "Row", AutoButtonColor = false, Text = "",
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, opts.Height or 40),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = opts.LayoutOrder or 0,
		ZIndex = 6, Parent = parent,
	})
	Corner(8, row)
	Paint(row, "BackgroundColor3", "Card")
	local rowStroke = Stroke(row, "Line", 0.4)
	Padding(row, 9, 9, 13, 12)

	local column = New("Frame", {
		Name = "Text", BackgroundTransparency = 1,
		Size = UDim2.new(1, -(slotWidth + (slotWidth > 0 and 10 or 0)), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 7, Parent = row,
	})
	List(column, 2)

	local titleLabel = Text({
		Name = "Title", Parent = column, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
		Text = tostring(opts.Title or ""), Size = UDim2.new(1, 0, 0, 17),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	if opts.Description and opts.Description ~= "" then
		Text({
			Name = "Description", Parent = column, ZIndex = 7, Font = FONT, TextSize = 12.5,
			Token = "Muted", Text = tostring(opts.Description), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
	end

	local slot = New("Frame", {
		Name = "Slot", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(slotWidth, (opts.Height or 40) - 16),
		ZIndex = 7, Parent = row,
	})

	return { Row = row, Stroke = rowStroke, Slot = slot, Title = titleLabel }
end

local function ElementAPI(holder, parent)
	local function order() return #parent:GetChildren() end

	------------------------------------------------------------
	function holder.Label(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		if typeof(cfg) == "string" then cfg = { Title = cfg } end
		cfg = cfg or {}

		local label = Text({
			Name = "Label", Parent = parent, ZIndex = 6, Font = FONT_M, TextSize = 13.5,
			Token = "Sub", Text = tostring(cfg.Title or cfg.Text or ""),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order(),
		})

		local api = { Instance = label, Type = "Label" }
		function api.SetText(a, t) label.Text = tostring(a ~= api and a or t) end
		api.SetTitle = api.SetText
		function api.Destroy() label:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Paragraph(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local box = New("Frame", {
			Name = "Paragraph", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 6, Parent = parent,
		})
		Corner(8, box)
		Paint(box, "BackgroundColor3", "Card")
		Stroke(box, "Line", 0.4)
		Padding(box, 11, 12, 13, 13)
		List(box, 5)

		local head = Text({
			Name = "Title", Parent = box, ZIndex = 7, Font = FONT_SB, TextSize = 13.5,
			Text = tostring(cfg.Title or ""), Size = UDim2.new(1, 0, 0, 17),
		})
		local body = Text({
			Name = "Content", Parent = box, ZIndex = 7, Font = FONT, TextSize = 12.5,
			Token = "Sub", Text = tostring(cfg.Content or cfg.Text or ""),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})

		local api = { Instance = box, Type = "Paragraph" }
		function api.SetTitle(a, t) head.Text = tostring(a ~= api and a or t) end
		function api.SetContent(a, t) body.Text = tostring(a ~= api and a or t) end
		function api.Destroy() box:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Divider(p1)
		local wrap = New("Frame", {
			Name = "Divider", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 9),
			LayoutOrder = order(), ZIndex = 6, Parent = parent,
		})
		local line = New("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 6, Parent = wrap,
		})
		Paint(line, "BackgroundColor3", "Line")
		return { Instance = wrap, Type = "Divider", Destroy = function() wrap:Destroy() end }
	end

	------------------------------------------------------------
	function holder.Button(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = Row(parent, {
			Name = "Button", Title = cfg.Title or "Button",
			Description = cfg.Description, SlotWidth = 16, LayoutOrder = order(),
		})
		Hoverable(base.Row, "Card", "Hover")

		local chevron = Chevron({
			Parent = base.Slot, ZIndex = 8, Size = 10, Rotation = -90,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		})

		local api = { Instance = base.Row, Type = "Button", Callback = cfg.Callback }
		base.Row.MouseButton1Click:Connect(function()
			Tween(base.Stroke, { Color = Theme.Accent, Transparency = 0 }, EASE_SNAP)
			chevron.SetColour(Theme.Accent)
			task.delay(0.18, function()
				Tween(base.Stroke, { Color = Theme.Line, Transparency = 0.4 }, EASE_OUT)
				chevron.SetColour(Theme.Muted)
			end)
			Fire(api.Callback, nil)
		end)

		function api.SetTitle(a, t) base.Title.Text = tostring(a ~= api and a or t) end
		function api.Destroy() base.Row:Destroy() end
		return api
	end

	------------------------------------------------------------
	function holder.Toggle(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = Row(parent, {
			Name = "Toggle", Title = cfg.Title or "Toggle",
			Description = cfg.Description, SlotWidth = 40, LayoutOrder = order(),
		})
		Hoverable(base.Row, "Card", "Hover")

		local track = New("Frame", {
			Name = "Track", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(40, 21),
			ZIndex = 8, Parent = base.Slot,
		})
		Corner(11, track)
		Paint(track, "BackgroundColor3", "Line")

		local knob = New("Frame", {
			Name = "Knob", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(15, 15),
			ZIndex = 9, Parent = track,
		})
		Corner(8, knob)
		Paint(knob, "BackgroundColor3", "Muted")

		local api = { Instance = base.Row, Type = "Toggle", Value = false, Callback = cfg.Callback }

		local function render(animate)
			local info = animate and EASE_OUT or TweenInfo.new(0)
			local trackToken = api.Value and "Accent" or "Line"
			local knobToken  = api.Value and "OnAccent" or "Muted"

			Tween(track, { BackgroundColor3 = Theme[trackToken] }, info)
			Tween(knob, {
				BackgroundColor3 = Theme[knobToken],
				Position = api.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			}, info)

			for _, entry in ipairs(Painted) do
				if entry.Instance == track then entry.Token = trackToken end
				if entry.Instance == knob then entry.Token = knobToken end
			end
		end

		function api.Set(a, v)
			local value = v
			if a ~= api then value = a end
			SetFlag(api, value and true or false)
			render(true)
			Fire(api.Callback, api.Value)
			return api.Value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		base.Row.MouseButton1Click:Connect(function() api.Set(api, not api.Value) end)

		function api.SetTitle(a, t) base.Title.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, (cfg.Default or cfg.Value) and true or false)
		render(false)
		if api.Value then Fire(api.Callback, true) end
		return api
	end

	------------------------------------------------------------
	function holder.Slider(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local min = tonumber(cfg.Min) or 0
		local max = tonumber(cfg.Max) or 100
		local increment = tonumber(cfg.Increment) or 1
		local suffix = cfg.Suffix or ""
		local decimals = tonumber(cfg.Rounding) or ((increment % 1 == 0) and 0 or 2)

		local row = New("Frame", {
			Name = "Slider", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 56),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 6, Parent = parent,
		})
		Corner(8, row)
		Paint(row, "BackgroundColor3", "Card")
		Stroke(row, "Line", 0.4)
		Padding(row, 10, 11, 13, 13)
		List(row, 7)

		local head = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 17),
			ZIndex = 7, Parent = row,
		})
		local titleLabel = Text({
			Name = "Title", Parent = head, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
			Text = tostring(cfg.Title or "Slider"), Size = UDim2.new(1, -72, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local valueLabel = Text({
			Name = "Value", Parent = head, ZIndex = 7, Font = FONT_M, TextSize = 12.5,
			Token = "Accent", Text = "", TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 72, 1, 0),
		})

		local lane = New("Frame", {
			Name = "Lane", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 7, Parent = row,
		})
		local track = New("Frame", {
			Name = "Track", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 5),
			ZIndex = 7, Parent = lane,
		})
		Corner(3, track)
		Paint(track, "BackgroundColor3", "Line")

		local fill = New("Frame", {
			Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
			ZIndex = 8, Parent = track,
		})
		Corner(2, fill)
		Paint(fill, "BackgroundColor3", "Accent")

		local knob = New("Frame", {
			Name = "Knob", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(13, 13),
			ZIndex = 9, Parent = track,
		})
		Corner(7, knob)
		Paint(knob, "BackgroundColor3", "Accent")

		local api = { Instance = row, Type = "Slider", Value = min, Callback = cfg.Callback }

		local function format(v)
			if decimals <= 0 then return tostring(math.floor(v + 0.5)) end
			return string.format("%." .. decimals .. "f", v)
		end

		local function snap(v)
			v = Clamp(Round(v, increment), min, max)
			if decimals > 0 then v = tonumber(string.format("%." .. decimals .. "f", v)) end
			return v
		end

		local function render(animate)
			local alpha = (max - min) == 0 and 0 or (api.Value - min) / (max - min)
			local info = animate and EASE_SNAP or TweenInfo.new(0)
			Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, info)
			Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, info)
			valueLabel.Text = format(api.Value) .. suffix
		end

		function api.Set(a, v)
			local value = v
			if a ~= api then value = a end
			local snapped = snap(tonumber(value) or min)
			local changed = snapped ~= api.Value
			SetFlag(api, snapped)
			render(true)
			if changed then Fire(api.Callback, snapped) end
			return snapped
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		local dragging = false
		local function apply(x)
			local width = track.AbsoluteSize.X
			if width <= 0 then return end
			local alpha = Clamp((x - track.AbsolutePosition.X) / width, 0, 1)
			local value = snap(min + (max - min) * alpha)
			if value ~= api.Value then
				SetFlag(api, value)
				Fire(api.Callback, value)
			end
			render(false)
		end

		local hit = New("TextButton", {
			Name = "Hit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = lane,
		})
		hit.InputBegan:Connect(function(input)
			if not IsClick(input) then return end
			dragging = true
			Tween(knob, { Size = UDim2.fromOffset(17, 17) }, EASE_SNAP)
			apply(input.Position.X)
		end)
		Love:Connect(UserInputService.InputChanged, function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			apply(input.Position.X)
		end)
		Love:Connect(UserInputService.InputEnded, function(input)
			if not dragging or not IsClick(input) then return end
			dragging = false
			Tween(knob, { Size = UDim2.fromOffset(13, 13) }, EASE_SNAP)
		end)

		function api.SetTitle(a, t) titleLabel.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, snap(tonumber(cfg.Default) or min))
		render(false)
		return api
	end

	------------------------------------------------------------
	function holder.Dropdown(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local values = cfg.Values or cfg.Options or {}
		local placeholder = tostring(cfg.Placeholder or "Select...")
		local multi = cfg.Multi == true or cfg.MultiSelect == true

		local box = New("Frame", {
			Name = "Dropdown", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ClipsDescendants = true, ZIndex = 6, Parent = parent,
		})
		Corner(8, box)
		Paint(box, "BackgroundColor3", "Card")
		Stroke(box, "Line", 0.4)
		Padding(box, 9, 9, 13, 12)
		List(box, 7)

		local header = New("TextButton", {
			Name = "Header", BackgroundTransparency = 1, AutoButtonColor = false,
			Text = "", Size = UDim2.new(1, 0, 0, 22), ZIndex = 7, Parent = box,
		})
		local titleLabel = Text({
			Name = "Title", Parent = header, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
			Text = tostring(cfg.Title or "Dropdown"), Size = UDim2.new(1, -108, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local valueLabel = Text({
			Name = "Value", Parent = header, ZIndex = 7, Font = FONT, TextSize = 12.5,
			Token = "Accent", Text = placeholder, TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.new(0, 92, 1, 0),
		})
		local arrow = Chevron({
			Parent = header, ZIndex = 8, Size = 11,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		})

		-- the list lives inside the card and the sidebar scrolls, so there is
		-- no floating layer to get clipped or left behind
		local listHolder = New("Frame", {
			Name = "Options", BackgroundTransparency = 1, Visible = false,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 7, Parent = box,
		})
		List(listHolder, 4)

		local api = {
			Instance = box, Type = "Dropdown", Values = values,
			Value = multi and {} or nil, Multi = multi,
			Open = false, Callback = cfg.Callback,
		}
		local buttons = {}

		local function chosen(value)
			if not multi then return api.Value == value end
			for _, picked in ipairs(api.Value or {}) do
				if picked == value then return true end
			end
			return false
		end

		local function renderValue()
			if not multi then
				valueLabel.Text = api.Value == nil and placeholder or tostring(api.Value)
				return
			end
			local picked = api.Value or {}
			if #picked == 0 then
				valueLabel.Text = placeholder
			elseif #picked <= 2 then
				local parts = {}
				for _, value in ipairs(picked) do parts[#parts + 1] = tostring(value) end
				valueLabel.Text = table.concat(parts, ", ")
			else
				valueLabel.Text = #picked .. " selected"
			end
		end

		local function paintRows()
			for _, entry in pairs(buttons) do
				local on = chosen(entry.Value)
				Tween(entry.Button, {
					BackgroundColor3 = on and Theme.Accent or Theme.Hover,
				}, EASE_SNAP)
				Tween(entry.Label, {
					TextColor3 = on and Theme.OnAccent or Theme.Sub,
				}, EASE_SNAP)
				for _, painted in ipairs(Painted) do
					if painted.Instance == entry.Button then
						painted.Token = on and "Accent" or "Hover"
					elseif painted.Instance == entry.Label then
						painted.Token = on and "OnAccent" or "Sub"
					end
				end
			end
		end

		-- flips one value in a multi-select without disturbing the rest
		local function flip(value)
			local picked = {}
			local removed = false
			for _, existing in ipairs(api.Value or {}) do
				if existing == value then removed = true else picked[#picked + 1] = existing end
			end
			if not removed then picked[#picked + 1] = value end
			SetFlag(api, picked)
			renderValue()
			paintRows()
			Fire(api.Callback, picked, value, not removed)
			if cfg.KeepOpen == false then api.SetOpen(api, false) end
			return picked
		end

		local function build()
			for _, entry in pairs(buttons) do entry.Button:Destroy() end
			buttons = {}

			for index, value in ipairs(api.Values) do
				local btn = New("TextButton", {
					Name = tostring(value), AutoButtonColor = false, Text = "",
					BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = index, ZIndex = 8, Parent = listHolder,
				})
				Corner(6, btn)
				Paint(btn, "BackgroundColor3", "Hover")

				local label = Text({
					Parent = btn, ZIndex = 9, Font = FONT, TextSize = 12.5, Token = "Sub",
					Text = tostring(value), TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -22, 1, 0),
				})

				btn.MouseButton1Click:Connect(function()
					if multi then flip(value) else api.Set(api, value) end
				end)
				buttons[tostring(value)] = { Button = btn, Label = label, Value = value }
			end
			paintRows()
		end

		function api.SetOpen(a, state)
			local open = state
			if a ~= api then open = a end
			api.Open = open and true or false
			listHolder.Visible = api.Open
			Tween(arrow.Instance, { Rotation = api.Open and 180 or 0 }, EASE_OUT)
			arrow.SetColour(api.Open and Theme.Accent or Theme.Muted)
			return api.Open
		end
		function api.Toggle() return api.SetOpen(api, not api.Open) end

		-- set the value without running the callback: used when something
		-- else already acted and the dropdown only has to catch up
		function api.SetSilent(a, value)
			local target = value
			if a ~= api then target = a end
			if multi and typeof(target) ~= "table" then
				target = target == nil and {} or { target }
			end
			SetFlag(api, target)
			renderValue()
			paintRows()
			return target
		end

		function api.Set(a, value)
			local target = api.SetSilent(a, value)
			Fire(api.Callback, target)
			if cfg.KeepOpen ~= true and not multi then api.SetOpen(api, false) end
			return target
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set
		api.Select = function(a, value)
			local target = value
			if a ~= api then target = a end
			if multi then return flip(target) end
			return api.Set(api, target)
		end

		function api.SetValues(a, list)
			local values2 = list
			if a ~= api then values2 = a end
			api.Values = values2 or {}

			if multi then
				local kept = {}
				for _, picked in ipairs(api.Value or {}) do
					for _, value in ipairs(api.Values) do
						if value == picked then kept[#kept + 1] = picked; break end
					end
				end
				SetFlag(api, kept)
			else
				local stillThere = false
				for _, value in ipairs(api.Values) do
					if value == api.Value then stillThere = true; break end
				end
				if not stillThere then SetFlag(api, nil) end
			end

			build()
			renderValue()
			return api
		end
		api.Refresh = api.SetValues

		header.MouseButton1Click:Connect(api.Toggle)

		function api.SetTitle(a, t) titleLabel.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			box:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		if cfg.Default ~= nil then api.SetSilent(api, cfg.Default) end
		build()
		renderValue()
		return api
	end

	------------------------------------------------------------
	-- a dropdown wired to the library's palettes. Switching the theme
	-- anywhere else - the header picker, another dropdown, Love:SetTheme -
	-- moves this one too.
	function holder.ThemeDropdown(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		if typeof(cfg) == "string" then cfg = { Title = cfg } end
		cfg = cfg or {}

		local api = holder.Dropdown({
			Title = cfg.Title or "Theme",
			Values = Love.ThemeOrder,
			Default = Love.ThemeName,
			Flag = cfg.Flag,
			KeepOpen = cfg.KeepOpen,
			Callback = function(name)
				Love.SetTheme(Love, name)
				Fire(cfg.Callback, name)
			end,
		})
		api.Type = "ThemeDropdown"

		RegisterThemePicker({
			Instance = api.Instance,
			Show = function(name)
				if api.Value ~= name then api.SetSilent(api, name) end
			end,
		})
		return api
	end

	------------------------------------------------------------
	function holder.Input(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = Row(parent, {
			Name = "Input", Title = cfg.Title or "Input",
			Description = cfg.Description, SlotWidth = 128, LayoutOrder = order(),
		})

		local field = New("Frame", {
			Name = "Field", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(128, 30),
			ZIndex = 8, Parent = base.Slot,
		})
		Corner(7, field)
		Paint(field, "BackgroundColor3", "Hover")
		local fieldStroke = Stroke(field, "Line", 0.2)

		local box = New("TextBox", {
			Name = "Box", BackgroundTransparency = 1, Font = FONT, TextSize = 12.5,
			Text = tostring(cfg.Default or ""), PlaceholderText = tostring(cfg.Placeholder or "..."),
			ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
			ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = field,
		})
		Paint(box, "TextColor3", "Text")
		Paint(box, "PlaceholderColor3", "Muted")
		Padding(box, 0, 0, 9, 9)

		local api = { Instance = base.Row, Type = "Input", Value = box.Text, Callback = cfg.Callback }

		box.Focused:Connect(function()
			Tween(fieldStroke, { Color = Theme.Accent, Transparency = 0 }, EASE_SNAP)
		end)
		box.FocusLost:Connect(function(enter)
			Tween(fieldStroke, { Color = Theme.Line, Transparency = 0.2 }, EASE_SNAP)
			SetFlag(api, box.Text)
			Fire(api.Callback, box.Text, enter)
		end)
		base.Row.MouseButton1Click:Connect(function() box:CaptureFocus() end)

		function api.Set(a, text)
			local value = text
			if a ~= api then value = a end
			box.Text = tostring(value or "")
			SetFlag(api, box.Text)
			Fire(api.Callback, box.Text, false)
			return box.Text
		end
		function api.Get() return box.Text end
		api.SetValue = api.Set

		function api.SetTitle(a, t) base.Title.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, box.Text)
		return api
	end

	------------------------------------------------------------
	function holder.Keybind(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = Row(parent, {
			Name = "Keybind", Title = cfg.Title or "Keybind",
			Description = cfg.Description, SlotWidth = 82, LayoutOrder = order(),
		})
		Hoverable(base.Row, "Card", "Hover")

		local chip = New("TextButton", {
			Name = "Chip", AutoButtonColor = false, Text = "None", Font = FONT_M,
			TextSize = 12.5, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(82, 28),
			ZIndex = 8, Parent = base.Slot,
		})
		Corner(7, chip)
		Paint(chip, "BackgroundColor3", "Hover")
		Paint(chip, "TextColor3", "Sub")
		local chipStroke = Stroke(chip, "Line", 0.2)

		local api = {
			Instance = base.Row, Type = "Keybind", Value = cfg.Default,
			Callback = cfg.Callback, Changed = cfg.ChangedCallback,
		}
		local listening = false

		local function render()
			chip.Text = listening and "..." or (api.Value and api.Value.Name or "None")
			Tween(chipStroke, {
				Color = listening and Theme.Accent or Theme.Line,
				Transparency = listening and 0 or 0.2,
			}, EASE_SNAP)
		end

		local function listen() listening = true; render() end
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
			SetFlag(api, value)
			render()
			Fire(api.Changed, value)
			return value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		Love:Connect(UserInputService.InputBegan, function(input, processed)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape then api.Set(api, nil)
					else api.Set(api, input.KeyCode) end
				end
				return
			end
			if processed or api.Value == nil then return end
			if input.KeyCode == api.Value then Fire(api.Callback, api.Value) end
		end)

		function api.SetTitle(a, t) base.Title.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		render()
		return api
	end

	------------------------------------------------------------
	-- multi-line text. Input is one line in a row; this is a box you can
	-- paste a list into.
	function holder.Textarea(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local box = New("Frame", {
			Name = "Textarea", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 6, Parent = parent,
		})
		Corner(8, box)
		Paint(box, "BackgroundColor3", "Card")
		Stroke(box, "Line", 0.4)
		Padding(box, 9, 10, 13, 12)
		List(box, 7)

		if cfg.Title and cfg.Title ~= "" then
			Text({
				Name = "Title", Parent = box, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
				Text = tostring(cfg.Title), Size = UDim2.new(1, 0, 0, 17), LayoutOrder = 1,
			})
		end

		local field = New("Frame", {
			Name = "Field", BorderSizePixel = 0, LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, tonumber(cfg.Height) or 84),
			ZIndex = 7, Parent = box,
		})
		Corner(7, field)
		Paint(field, "BackgroundColor3", "Hover")
		local fieldStroke = Stroke(field, "Line", 0.2)

		local input = New("TextBox", {
			Name = "Box", BackgroundTransparency = 1, Font = FONT, TextSize = 12.5,
			Text = tostring(cfg.Default or ""), MultiLine = true, TextWrapped = true,
			PlaceholderText = tostring(cfg.Placeholder or "..."), ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = field,
		})
		Paint(input, "TextColor3", "Text")
		Paint(input, "PlaceholderColor3", "Muted")
		Padding(input, 7, 7, 9, 9)

		local api = {
			Instance = box, Type = "Textarea", Value = input.Text, Callback = cfg.Callback,
		}

		input.Focused:Connect(function()
			Tween(fieldStroke, { Color = Theme.Accent, Transparency = 0 }, EASE_SNAP)
		end)
		input.FocusLost:Connect(function(enter)
			Tween(fieldStroke, { Color = Theme.Line, Transparency = 0.2 }, EASE_SNAP)
			SetFlag(api, input.Text)
			Fire(api.Callback, input.Text, enter)
		end)

		function api.Set(a, text)
			local value = text
			if a ~= api then value = a end
			input.Text = tostring(value or "")
			SetFlag(api, input.Text)
			Fire(api.Callback, input.Text, false)
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
			if api.Flag then Love.Options[api.Flag] = nil end
			box:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, input.Text)
		return api
	end

	------------------------------------------------------------
	-- hue, saturation and value as three bars. A square gradient picker
	-- needs more room than a sidebar has, and bars read fine on a phone.
	function holder.ColorPicker(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local start = cfg.Default or cfg.Value or Color3.fromRGB(244, 114, 182)
		local h, sat, val = start:ToHSV()
		local hsv = { h, sat, val }

		local box = New("Frame", {
			Name = "ColorPicker", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ClipsDescendants = true, ZIndex = 6, Parent = parent,
		})
		Corner(8, box)
		Paint(box, "BackgroundColor3", "Card")
		Stroke(box, "Line", 0.4)
		Padding(box, 9, 9, 13, 12)
		List(box, 7)

		local head = New("TextButton", {
			Name = "Header", BackgroundTransparency = 1, AutoButtonColor = false,
			Text = "", Size = UDim2.new(1, 0, 0, 22), ZIndex = 7, Parent = box,
		})
		local titleLabel = Text({
			Name = "Title", Parent = head, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
			Text = tostring(cfg.Title or "Colour"), Size = UDim2.new(1, -60, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local swatch = New("Frame", {
			Name = "Swatch", BorderSizePixel = 0, BackgroundColor3 = start,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0),
			Size = UDim2.fromOffset(26, 16), ZIndex = 8, Parent = head,
		})
		Corner(5, swatch)
		Stroke(swatch, "Line", 0.3)
		local arrow = Chevron({
			Parent = head, ZIndex = 8, Size = 11,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		})

		local body = New("Frame", {
			Name = "Bars", BackgroundTransparency = 1, Visible = false,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 7, Parent = box,
		})
		List(body, 6)

		local api = {
			Instance = box, Type = "ColorPicker", Value = start,
			Open = false, Callback = cfg.Callback,
		}

		local bars = {}
		local function apply(fire)
			local colour = Color3.fromHSV(hsv[1], hsv[2], hsv[3])
			swatch.BackgroundColor3 = colour
			SetFlag(api, colour)
			for _, refresh in ipairs(bars) do refresh() end
			if fire then Fire(api.Callback, colour) end
			return colour
		end

		local function bar(name, index, order2)
			local wrap = New("Frame", {
				Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = order2, ZIndex = 7, Parent = body,
			})
			Text({
				Parent = wrap, ZIndex = 7, Font = FONT, TextSize = 12, Token = "Muted",
				Text = name, Size = UDim2.fromOffset(28, 18),
			})
			local track = New("Frame", {
				Name = "Track", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -36, 0, 5),
				ZIndex = 7, Parent = wrap,
			})
			Corner(3, track)
			Paint(track, "BackgroundColor3", "Line")

			local fill = New("Frame", {
				Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
				ZIndex = 8, Parent = track,
			})
			Corner(3, fill)

			local knob = New("Frame", {
				Name = "Knob", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12),
				ZIndex = 9, Parent = track,
			})
			Corner(6, knob)
			Stroke(knob, "Line", 0.4)

			local hit = New("TextButton", {
				Name = "Hit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = wrap,
			})

			local dragging = false
			local function grab(x)
				local width = track.AbsoluteSize.X
				if width <= 0 then return end
				hsv[index] = Clamp((x - track.AbsolutePosition.X) / width, 0, 1)
				apply(true)
			end

			hit.InputBegan:Connect(function(input)
				if not IsClick(input) then return end
				dragging = true
				grab(input.Position.X)
			end)
			Love:Connect(UserInputService.InputChanged, function(input)
				if not dragging then return end
				if input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch then return end
				grab(input.Position.X)
			end)
			Love:Connect(UserInputService.InputEnded, function(input)
				if dragging and IsClick(input) then dragging = false end
			end)

			table.insert(bars, function()
				local alpha = hsv[index]
				fill.Size = UDim2.fromScale(alpha, 1)
				knob.Position = UDim2.fromScale(alpha, 0.5)
				-- each bar shows what it controls: the hue bar runs the
				-- rainbow, the other two run from flat to the live colour
				if index == 1 then
					fill.BackgroundColor3 = Color3.fromHSV(alpha, 1, 1)
					knob.BackgroundColor3 = Color3.fromHSV(alpha, 1, 1)
				else
					local colour = Color3.fromHSV(hsv[1], hsv[2], hsv[3])
					fill.BackgroundColor3 = colour
					knob.BackgroundColor3 = colour
				end
			end)
		end

		bar("Hue", 1, 1)
		bar("Sat", 2, 2)
		bar("Val", 3, 3)

		function api.SetOpen(a, state)
			local open = state
			if a ~= api then open = a end
			api.Open = open and true or false
			body.Visible = api.Open
			Tween(arrow.Instance, { Rotation = api.Open and 180 or 0 }, EASE_OUT)
			arrow.SetColour(api.Open and Theme.Accent or Theme.Muted)
			return api.Open
		end
		function api.Toggle() return api.SetOpen(api, not api.Open) end
		head.MouseButton1Click:Connect(api.Toggle)

		function api.Set(a, colour)
			local value = colour
			if a ~= api then value = a end
			if typeof(value) ~= "Color3" then return api.Value end
			hsv[1], hsv[2], hsv[3] = value:ToHSV()
			return apply(true)
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		function api.SetTitle(a, t) titleLabel.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			box:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		apply(false)
		return api
	end

	------------------------------------------------------------
	-- a read-only bar for anything that runs for a while
	function holder.Progress(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local maximum = tonumber(cfg.Max) or 1

		local box = New("Frame", {
			Name = "Progress", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 6, Parent = parent,
		})
		Corner(8, box)
		Paint(box, "BackgroundColor3", "Card")
		Stroke(box, "Line", 0.4)
		Padding(box, 10, 11, 13, 13)
		List(box, 7)

		local head = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 17), ZIndex = 7, Parent = box,
		})
		local titleLabel = Text({
			Name = "Title", Parent = head, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
			Text = tostring(cfg.Title or "Progress"), Size = UDim2.new(1, -72, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local valueLabel = Text({
			Name = "Value", Parent = head, ZIndex = 7, Font = FONT_M, TextSize = 12.5,
			Token = "Accent", Text = "0%", TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 72, 1, 0),
		})

		local track = New("Frame", {
			Name = "Track", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 6),
			ZIndex = 7, Parent = box,
		})
		Corner(3, track)
		Paint(track, "BackgroundColor3", "Line")

		local fill = New("Frame", {
			Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1),
			ZIndex = 8, Parent = track,
		})
		Corner(3, fill)
		Paint(fill, "BackgroundColor3", "Accent")

		local api = { Instance = box, Type = "Progress", Value = 0, Callback = cfg.Callback }

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			target = Clamp(tonumber(target) or 0, 0, maximum)
			SetFlag(api, target)
			local alpha = maximum == 0 and 0 or target / maximum
			Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, EASE_OUT)
			if cfg.Text == false then
				valueLabel.Text = ""
			elseif cfg.Format then
				valueLabel.Text = tostring(cfg.Format(target, maximum))
			elseif maximum == 1 then
				valueLabel.Text = math.floor(alpha * 100 + 0.5) .. "%"
			else
				valueLabel.Text = math.floor(target + 0.5) .. " / " .. tostring(maximum)
			end
			Fire(api.Callback, target)
			return target
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set
		function api.SetText(a, t) valueLabel.Text = tostring(a ~= api and a or t) end

		function api.SetTitle(a, t) titleLabel.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			box:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		api.Set(api, tonumber(cfg.Default) or 0)
		return api
	end

	------------------------------------------------------------
	-- a scrolling log you can print into
	function holder.Console(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local maxLines = tonumber(cfg.MaxLines) or 80

		local box = New("Frame", {
			Name = "Console", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order(),
			ZIndex = 6, Parent = parent,
		})
		Corner(8, box)
		Paint(box, "BackgroundColor3", "Card")
		Stroke(box, "Line", 0.4)
		Padding(box, 9, 10, 13, 12)
		List(box, 7)

		if cfg.Title and cfg.Title ~= "" then
			Text({
				Name = "Title", Parent = box, ZIndex = 7, Font = FONT_M, TextSize = 13.5,
				Text = tostring(cfg.Title), Size = UDim2.new(1, 0, 0, 17), LayoutOrder = 1,
			})
		end

		local view = New("ScrollingFrame", {
			Name = "View", BorderSizePixel = 0, LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, tonumber(cfg.Height) or 110),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 7, Parent = box,
		})
		Corner(7, view)
		Paint(view, "BackgroundColor3", "Hover")
		Paint(view, "ScrollBarImageColor3", "Line")
		Padding(view, 8, 8, 9, 9)
		local layout = List(view, 3)

		local api = { Instance = box, Type = "Console", Lines = {} }

		function api.Append(a, text, colour)
			local line = text
			local tint = colour
			if a ~= api then line, tint = a, text end

			local label = Text({
				Parent = view, ZIndex = 8, Font = FONT, TextSize = 12,
				Token = tint or "Sub", Text = tostring(line), TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = #api.Lines + 1,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			})
			table.insert(api.Lines, label)

			while #api.Lines > maxLines do
				local oldest = table.remove(api.Lines, 1)
				if oldest then oldest:Destroy() end
			end

			-- the canvas size lags a frame behind, so scroll to the layout's
			-- own content size instead of reading it back off the frame
			task.defer(function()
				if view.Parent then
					view.CanvasPosition = Vector2.new(0, layout.AbsoluteContentSize.Y)
				end
			end)
			return label
		end
		api.Print = api.Append
		api.Add = api.Append

		function api.Success(a, text) return api.Append(api, a ~= api and a or text, "Accent") end
		function api.Error(a, text) return api.Append(api, a ~= api and a or text, "Error") end

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
	-- a label with a value pinned to the right, for anything you update
	-- on a loop: ping, fps, how many players are left
	function holder.Stat(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = Row(parent, {
			Name = "Stat", Title = cfg.Title or "Stat", Height = 34,
			Description = cfg.Description, SlotWidth = 110, LayoutOrder = order(),
		})

		local valueLabel = Text({
			Name = "Value", Parent = base.Slot, ZIndex = 8, Font = FONT_M, TextSize = 13,
			Token = "Accent", Text = tostring(cfg.Value or cfg.Default or "-"),
			TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.fromScale(1, 1),
		})

		local api = { Instance = base.Row, Type = "Stat", Value = valueLabel.Text }

		function api.Set(a, value)
			local target = value
			if a ~= api then target = a end
			valueLabel.Text = tostring(target)
			SetFlag(api, target)
			return target
		end
		api.SetValue = api.Set
		function api.Get() return api.Value end

		function api.SetTitle(a, t) base.Title.Text = tostring(a ~= api and a or t) end
		function api.Destroy()
			if api.Flag then Love.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		return api
	end

	return holder
end

-- ================================================================
--  WINDOW  (a sidebar, not a floating panel)
-- ================================================================

function Love.CreateWindow(a, b)
	local cfg = b
	if a ~= Love then cfg = a end
	cfg = cfg or {}

	if cfg.Theme and Themes[cfg.Theme] then Love.SetTheme(Love, cfg.Theme) end

	local width      = tonumber(cfg.Width) or 340
	local handleW    = tonumber(cfg.HandleWidth) or 8
	local handleH    = tonumber(cfg.HandleHeight) or 150
	local threshold  = tonumber(cfg.Threshold) or 60
	local toggleKey  = cfg.Keybind or Enum.KeyCode.RightShift

	local Window = {
		Tabs = {}, ActiveTab = nil, Open = cfg.StartOpen == true,
		ToggleKey = toggleKey, Title = tostring(cfg.Title or "LoveUI"),
		OnTheme = cfg.OnTheme,
	}

	----------------------------------------------------------------
	-- the drawer: panel plus the handle riding its right edge, moved
	-- together so the handle is reachable whether it is open or shut
	----------------------------------------------------------------
	local drawer = New("Frame", {
		Name = "Drawer", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -width, 0.5, 0),
		Size = UDim2.new(0, width + handleW, tonumber(cfg.Height) or 0.92, 0),
		ZIndex = 10, Parent = Root,
	})
	Window.Instance = drawer

	-- one knob for "everything is too small": UIScale multiplies the panel
	-- and everything in it. Touch devices start a little larger, since the
	-- same pixel is a smaller share of a phone screen and a fatter target.
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local scaleValue = tonumber(cfg.Scale) or (touchOnly and 1.15 or 1)
	local uiScale = New("UIScale", { Scale = scaleValue, Parent = drawer })
	Window.Scale = scaleValue

	local panel = New("Frame", {
		Name = "Panel", BorderSizePixel = 0, Size = UDim2.new(0, width, 1, 0),
		ClipsDescendants = true, ZIndex = 10, Parent = drawer,
	})
	Corner(12, panel)
	Paint(panel, "BackgroundColor3", "Bg")
	Stroke(panel, "Line", 0.25)

	local handle = New("TextButton", {
		Name = "Handle", AutoButtonColor = false, Text = "", BorderSizePixel = 0,
		BackgroundTransparency = 0.45, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, width + 4, 0.5, 0),
		Size = UDim2.fromOffset(handleW, handleH), ZIndex = 11, Parent = drawer,
	})
	Corner(4, handle)
	Paint(handle, "BackgroundColor3", "Accent")

	----------------------------------------------------------------
	-- header
	----------------------------------------------------------------
	local header = New("Frame", {
		Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60),
		ZIndex = 11, Parent = panel,
	})
	Padding(header, 0, 0, 16, 14)

	Heart(header, 18, 12).Instance.Position = UDim2.new(0, 9, 0.5, -1)

	local titleLabel = Text({
		Name = "Title", Parent = header, ZIndex = 12, Font = FONT_B, TextSize = 15.5,
		Text = Window.Title, Position = UDim2.new(0, 31, 0, 13),
		Size = UDim2.new(1, -72, 0, 18),
	})
	Text({
		Name = "SubTitle", Parent = header, ZIndex = 12, Font = FONT, TextSize = 12,
		Token = "Muted", Text = tostring(cfg.SubTitle or ""),
		Position = UDim2.new(0, 31, 0, 32), Size = UDim2.new(1, -72, 0, 14),
	})

	-- the theme control: a swatch that drops a list of every palette. It
	-- used to cycle blind on each click, which told you nothing about what
	-- was coming next. Picking here moves any Theme dropdown on a page too.
	local themeBtn = New("TextButton", {
		Name = "Theme", AutoButtonColor = false, Text = "", BorderSizePixel = 0,
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(28, 28),
		ZIndex = 12, Parent = header,
	})
	Corner(14, themeBtn)
	Paint(themeBtn, "BackgroundColor3", "Card")
	themeBtn.BackgroundTransparency = 0

	local themeDot = New("Frame", {
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 13),
		ZIndex = 13, Parent = themeBtn,
	})
	Corner(7, themeDot)
	Paint(themeDot, "BackgroundColor3", "Accent")

	local themeMenu = New("Frame", {
		Name = "ThemeMenu", BorderSizePixel = 0, Visible = false,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 58),
		Size = UDim2.new(0, 156, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 40, Parent = panel,
	})
	Corner(9, themeMenu)
	Paint(themeMenu, "BackgroundColor3", "Panel")
	Stroke(themeMenu, "Line", 0)
	Padding(themeMenu, 6, 6, 6, 6)
	List(themeMenu, 3)

	local themeRows = {}
	for index, name in ipairs(THEME_ORDER) do
		local rowBtn = New("TextButton", {
			Name = name, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 28), LayoutOrder = index,
			ZIndex = 41, Parent = themeMenu,
		})
		Corner(6, rowBtn)
		Paint(rowBtn, "BackgroundColor3", "Panel")

		local swatch = New("Frame", {
			Name = "Swatch", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Themes[name].Accent, ZIndex = 42, Parent = rowBtn,
		})
		Corner(6, swatch)

		local rowLabel = Text({
			Parent = rowBtn, ZIndex = 42, Font = FONT_M, TextSize = 12.5, Token = "Sub",
			Text = name, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -36, 1, 0),
		})

		rowBtn.MouseButton1Click:Connect(function()
			themeMenu.Visible = false
			Love.SetTheme(Love, name)
		end)
		themeRows[name] = { Button = rowBtn, Label = rowLabel }
	end

	local function paintThemeRows(active)
		for name, entry in pairs(themeRows) do
			local on = name == active
			local bg   = on and "Hover" or "Panel"
			local text = on and "Text" or "Sub"
			Tween(entry.Button, { BackgroundColor3 = Theme[bg] }, EASE_SNAP)
			Tween(entry.Label, { TextColor3 = Theme[text] }, EASE_SNAP)
			for _, painted in ipairs(Painted) do
				if painted.Instance == entry.Button then painted.Token = bg end
				if painted.Instance == entry.Label then painted.Token = text end
			end
		end
	end

	RegisterThemePicker({ Instance = themeMenu, Show = paintThemeRows })

	themeBtn.MouseButton1Click:Connect(function()
		themeMenu.Visible = not themeMenu.Visible
	end)

	New("Frame", {
		Name = "Rule", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 11, Parent = header,
	})
	Paint(header:FindFirstChild("Rule"), "BackgroundColor3", "Line")

	----------------------------------------------------------------
	-- tab strip
	----------------------------------------------------------------
	local tabStrip = New("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 44),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 11, Parent = panel,
	})
	Padding(tabStrip, 8, 8, 14, 14)
	List(tabStrip, 6, Enum.FillDirection.Horizontal)

	local content = New("Frame", {
		Name = "Content", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 1, -104),
		ClipsDescendants = true, ZIndex = 11, Parent = panel,
	})

	----------------------------------------------------------------
	-- open / close, by gesture or by key
	----------------------------------------------------------------
	-- the panel is `width` wide before UIScale, so how far it has to travel
	-- to be off-screen depends on the scale in force
	local function offsetFor(open)
		if open then return 0 end
		return -math.floor(width * scaleValue + 0.5)
	end

	function Window.SetOpen(p1, p2)
		local open = p2
		if p1 ~= Window then open = p1 end
		Window.Open = open and true or false

		themeMenu.Visible = false
		Tween(drawer, { Position = UDim2.new(0, offsetFor(Window.Open), 0.5, 0) }, EASE_SMOOTH)
		Tween(handle, { BackgroundTransparency = Window.Open and 0.7 or 0.45 }, EASE_OUT)
		return Window.Open
	end
	function Window.Toggle() return Window.SetOpen(Window, not Window.Open) end
	Window.SetVisible = Window.SetOpen

	local dragging, startX, startOffset, moved = false, 0, 0, false

	handle.InputBegan:Connect(function(input)
		if not IsClick(input) then return end
		dragging, moved = true, false
		startX = input.Position.X
		startOffset = drawer.Position.X.Offset
	end)

	Love:Connect(UserInputService.InputChanged, function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		local dx = input.Position.X - startX
		if math.abs(dx) > 5 then moved = true end
		drawer.Position = UDim2.new(0, Clamp(startOffset + dx, offsetFor(false), 0), 0.5, 0)
	end)

	Love:Connect(UserInputService.InputEnded, function(input)
		if not dragging or not IsClick(input) then return end
		dragging = false

		-- a tap toggles; a drag commits to whichever side it got closest to
		if not moved then
			Window.Toggle()
			return
		end

		local travelled = drawer.Position.X.Offset - offsetFor(Window.Open)
		if math.abs(travelled) >= threshold then
			Window.SetOpen(Window, not Window.Open)
		else
			Window.SetOpen(Window, Window.Open)
		end
	end)

	Love:Connect(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		if Window.ToggleKey and input.KeyCode == Window.ToggleKey then Window.Toggle() end
	end)

	function Window.SetTitle(p1, p2)
		local title = p2
		if p1 ~= Window then title = p1 end
		Window.Title = tostring(title)
		titleLabel.Text = Window.Title
		return Window.Title
	end

	function Window.SetScale(p1, p2)
		local value = p2
		if p1 ~= Window then value = p1 end
		scaleValue = Clamp(tonumber(value) or 1, 0.7, 2)
		uiScale.Scale = scaleValue
		Window.Scale = scaleValue
		Window.SetOpen(Window, Window.Open)
		return scaleValue
	end

	function Window.SetToggleKey(p1, p2)
		local key = p2
		if p1 ~= Window then key = p1 end
		Window.ToggleKey = key
	end

	function Window.Destroy()
		drawer:Destroy()
		for i, w in ipairs(Love.Windows) do
			if w == Window then table.remove(Love.Windows, i); break end
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
		local Tab = { Title = name, Window = Window }

		local pill = New("TextButton", {
			Name = name, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = tabOrder, ZIndex = 12, Parent = tabStrip,
		})
		Corner(14, pill)
		Paint(pill, "BackgroundColor3", "Card")
		Padding(pill, 0, 0, 14, 14)

		local pillLabel = Text({
			Parent = pill, ZIndex = 13, Font = FONT_M, TextSize = 13, Token = "Sub",
			Text = name, Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
		})

		local page = New("ScrollingFrame", {
			Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), Visible = false, CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
			ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 11, Parent = content,
		})
		Paint(page, "ScrollBarImageColor3", "Line")
		Padding(page, 14, 18, 14, 12)
		List(page, 9)

		Tab.Instance, Tab.Page, Tab.Container = pill, page, page

		local function paintPill(active)
			Tween(pill, { BackgroundColor3 = active and Theme.Accent or Theme.Card }, EASE_SNAP)
			Tween(pillLabel, { TextColor3 = active and Theme.OnAccent or Theme.Sub }, EASE_SNAP)
			for _, entry in ipairs(Painted) do
				if entry.Instance == pill then entry.Token = active and "Accent" or "Card" end
				if entry.Instance == pillLabel then entry.Token = active and "OnAccent" or "Sub" end
			end
		end

		function Tab.Select()
			themeMenu.Visible = false
			if Window.ActiveTab == Tab then return end
			if Window.ActiveTab then
				Window.ActiveTab.Page.Visible = false
				Window.ActiveTab.Paint(false)
			end
			Window.ActiveTab = Tab
			page.Visible = true
			page.CanvasPosition = Vector2.new(0, 0)
			paintPill(true)
		end
		Tab.Paint = paintPill

		pill.MouseButton1Click:Connect(Tab.Select)
		paintPill(false)

		ElementAPI(Tab, page)

		function Tab.CreateSection(q1, q2)
			local scfg = q2
			if q1 ~= Tab then scfg = q1 end
			if typeof(scfg) == "string" then scfg = { Title = scfg } end
			scfg = scfg or {}

			local holder = New("Frame", {
				Name = "Section", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = #page:GetChildren(),
				ZIndex = 11, Parent = page,
			})
			List(holder, 8)

			Text({
				Name = "Title", Parent = holder, ZIndex = 11, Font = FONT_B, TextSize = 12,
				Token = "Muted", Text = string.upper(tostring(scfg.Title or "Section")),
				Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1,
			})

			local inner = New("Frame", {
				Name = "Items", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 11,
				Parent = holder,
			})
			List(inner, 8)

			local Section = { Instance = holder, Container = inner, Window = Window }
			function Section.Destroy() holder:Destroy() end
			ElementAPI(Section, inner)
			return Section
		end
		Tab.AddSection = Tab.CreateSection

		table.insert(Window.Tabs, Tab)
		if #Window.Tabs == 1 or tcfg.Default then Tab.Select() end
		return Tab
	end
	Window.AddTab = Window.CreateTab

	function Window.Notify(p1, p2)
		return Love.Notify(p1 ~= Window and p1 or p2)
	end

	Window.SetOpen(Window, Window.Open)
	table.insert(Love.Windows, Window)
	return Window
end

-- ================================================================
--  LIFECYCLE
-- ================================================================

function Love.GetFlag(a, b)
	local flag = b
	if a ~= Love then flag = a end
	return Love.Flags[flag]
end

function Love.SetFlag(a, b, c)
	local flag, value = b, c
	if a ~= Love then flag, value = a, b end
	local element = Love.Options[flag]
	if element and element.Set then return element.Set(element, value) end
	Love.Flags[flag] = value
	return value
end

function Love.Unload()
	if Love.Unloaded then return end
	Love.Unloaded = true

	for _, conn in ipairs(Love.Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(Love.Connections)
	table.clear(Love.Windows)
	table.clear(Love.Options)
	table.clear(Painted)

	if Root then Root:Destroy() end
end
Love.Destroy = Love.Unload

return Love
