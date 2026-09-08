--!nonstrict
--[[
	================================================================
	  ONYX UI  ·  v1.0.0
	  A black-theme interface library for Roblox script executors.
	================================================================

	  Usage:
	      local Onyx = loadstring(game:HttpGet("<raw url to Ui.lua>"))()

	      local Window = Onyx:CreateWindow({
	          Title    = "My Script",
	          SubTitle = "v1.0",
	          Size     = UDim2.fromOffset(620, 430),
	          Keybind  = Enum.KeyCode.RightShift,
	      })

	      local Tab = Window:CreateTab({ Title = "Main", Icon = "rbxassetid://..." })
	      local Section = Tab:CreateSection("Combat")

	      Section:Button({ Title = "Kill All", Callback = function() end })

	  Every public function accepts both `Lib:Fn(cfg)` and `Lib.Fn(cfg)`.
	================================================================
]]

local CloneRef = (typeof(cloneref) == "function" and cloneref) or function(o) return o end

local Players          = CloneRef(game:GetService("Players"))
local TweenService     = CloneRef(game:GetService("TweenService"))
local UserInputService  = CloneRef(game:GetService("UserInputService"))
local RunService       = CloneRef(game:GetService("RunService"))
local HttpService      = CloneRef(game:GetService("HttpService"))
local CoreGui          = CloneRef(game:GetService("CoreGui"))

local LocalPlayer = Players.LocalPlayer

-- ================================================================
--  LIBRARY TABLE
-- ================================================================

local Onyx = {
	Name        = "Onyx",
	Version     = "1.0.0",

	Windows     = {},          -- all created windows
	Flags       = {},          -- flag -> current value
	Options     = {},          -- flag -> element object
	Connections = {},          -- tracked RBXScriptConnections
	AccentBound = {},          -- { {Instance, propertyName}, ... }

	Folder      = "OnyxUI",    -- config folder used by SaveConfig/LoadConfig
	Unloaded    = false,
	MinimizeKey = nil,
}

-- ================================================================
--  THEME  (black / obsidian — the only theme for now)
-- ================================================================

local Theme = {
	Backdrop     = Color3.fromRGB(8, 8, 10),
	Rail         = Color3.fromRGB(11, 11, 14),
	Surface      = Color3.fromRGB(16, 16, 19),
	SurfaceAlt   = Color3.fromRGB(21, 21, 25),
	Hover        = Color3.fromRGB(28, 28, 33),
	Active       = Color3.fromRGB(34, 34, 40),

	Line         = Color3.fromRGB(30, 30, 36),
	LineBright   = Color3.fromRGB(48, 48, 57),

	Text         = Color3.fromRGB(236, 236, 242),
	SubText      = Color3.fromRGB(140, 140, 152),
	Muted        = Color3.fromRGB(92, 92, 103),

	Accent       = Color3.fromRGB(232, 232, 240),
	OnAccent     = Color3.fromRGB(9, 9, 11),

	Success      = Color3.fromRGB(88, 214, 141),
	Warning      = Color3.fromRGB(240, 190, 90),
	Danger       = Color3.fromRGB(238, 100, 100),
	Info         = Color3.fromRGB(120, 170, 250),
}

Onyx.Theme = Theme

-- ================================================================
--  SMALL HELPERS
-- ================================================================

local function Font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback or Enum.Font.SourceSans
end

local FONT      = Font("Gotham")
local FONT_M    = Font("GothamMedium", FONT)
local FONT_SB   = Font("GothamSemibold", FONT_M)
local FONT_B    = Font("GothamBold", FONT_SB)
local FONT_MONO = Font("Code", FONT)

local EASE_OUT   = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local EASE_SNAP  = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local EASE_SMOOTH= TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function New(class, props, children)
	local obj = Instance.new(class)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				obj[k] = v
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = obj
		end
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

local function Corner(radius, parent)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function Stroke(parent, color, transparency, thickness)
	return New("UIStroke", {
		Color            = color or Theme.Line,
		Transparency     = transparency or 0,
		Thickness        = thickness or 1,
		ApplyStrokeMode  = Enum.ApplyStrokeMode.Border,
		Parent           = parent,
	})
end

local function Padding(parent, t, b, l, r)
	return New("UIPadding", {
		PaddingTop    = UDim.new(0, t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft   = UDim.new(0, l or 0),
		PaddingRight  = UDim.new(0, r or l or 0),
		Parent        = parent,
	})
end

local function List(parent, gap, dir, align)
	return New("UIListLayout", {
		Padding              = UDim.new(0, gap or 6),
		FillDirection        = dir or Enum.FillDirection.Vertical,
		SortOrder            = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment  = align or Enum.HorizontalAlignment.Left,
		Parent               = parent,
	})
end

local function Text(props)
	local p = props or {}
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font                   = p.Font or FONT
	p.TextSize               = p.TextSize or 13
	p.TextColor3             = p.TextColor3 or Theme.Text
	p.TextXAlignment         = p.TextXAlignment or Enum.TextXAlignment.Left
	p.TextYAlignment         = p.TextYAlignment or Enum.TextYAlignment.Center
	return New("TextLabel", p)
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

-- keeps a connection so :Unload() can clean it up
function Onyx:Connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(Onyx.Connections, conn)
	return conn
end

-- marks an instance property as "accent coloured" so SetAccent can update it
local function BindAccent(obj, prop)
	table.insert(Onyx.AccentBound, { obj, prop })
	return obj
end

-- resolves an icon config value into an image asset string (or nil)
local function ResolveIcon(icon)
	if icon == nil then return nil end
	if typeof(icon) == "number" then return "rbxassetid://" .. tostring(icon) end
	if typeof(icon) == "string" then
		if icon == "" then return nil end
		if icon:match("^rbxassetid://") or icon:match("^rbxasset://") or icon:match("^http") then
			return icon
		end
		if icon:match("^%d+$") then return "rbxassetid://" .. icon end
	end
	return nil -- not an asset: caller may render it as text
end

-- ================================================================
--  ROOT SCREENGUI
-- ================================================================

local function GetGuiParent()
	local target

	local ok = pcall(function()
		if typeof(gethui) == "function" then
			target = gethui()
		elseif typeof(get_hidden_gui) == "function" then
			target = get_hidden_gui()
		end
	end)

	if not ok or not target then
		local ok2 = pcall(function()
			-- CoreGui is only writable in an exploit / plugin context
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
	Name             = "Onyx_" .. tostring(math.random(1e5, 1e6 - 1)),
	ResetOnSpawn     = false,
	IgnoreGuiInset   = true,
	DisplayOrder     = 9999,
	ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
})

pcall(function()
	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		syn.protect_gui(Root)
	elseif typeof(protect_gui) == "function" then
		protect_gui(Root)
	end
end)

Root.Parent = GetGuiParent()
Onyx.Root = Root

-- layer 1: windows | layer 2: popouts (dropdowns, pickers) | layer 3: toasts
local WindowLayer = New("Frame", {
	Name = "Windows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 1, Parent = Root,
})
local PopLayer = New("Frame", {
	Name = "Popouts", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 400, Parent = Root,
})
local ToastLayer = New("Frame", {
	Name = "Toasts", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
	ZIndex = 800, Parent = Root,
})

-- ================================================================
--  INTERACTION HELPERS
-- ================================================================

-- hover / press tinting for any BackgroundColor3 driven button
local function Interact(button, base, hover, press)
	base  = base  or Theme.Surface
	hover = hover or Theme.Hover
	press = press or Theme.Active

	local down = false
	local inside = false

	local function refresh()
		local target = base
		if down and inside then target = press
		elseif inside then target = hover end
		Tween(button, { BackgroundColor3 = target }, EASE_SNAP)
	end

	button.MouseEnter:Connect(function() inside = true;  refresh() end)
	button.MouseLeave:Connect(function() inside = false; down = false; refresh() end)
	button.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			down = true; refresh()
		end
	end)
	button.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			down = false; refresh()
		end
	end)

	return {
		SetBase = function(c) base = c; refresh() end,
		Refresh = refresh,
	}
end

-- drags `frame` while `handle` is held
local function Draggable(frame, handle, onStart, onEnd)
	local dragging, startPos, startInput = false, nil, nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		dragging   = true
		startInput = input.Position
		startPos   = frame.Position
		if onStart then onStart() end

		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if onEnd then onEnd() end
				conn:Disconnect()
			end
		end)
	end)

	Onyx:Connect(UserInputService.InputChanged, function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end

		local delta = input.Position - startInput
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end)
end

-- ================================================================
--  TOOLTIP
-- ================================================================

local Tooltip do
	local holder = New("Frame", {
		Name = "Tooltip", Visible = false, ZIndex = 500,
		BackgroundColor3 = Theme.SurfaceAlt, AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0), Parent = PopLayer,
	})
	Corner(5, holder)
	Stroke(holder, Theme.LineBright)
	Padding(holder, 6, 6, 9, 9)

	local label = Text({
		Name = "Body", Parent = holder, ZIndex = 501,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
		TextSize = 12, TextColor3 = Theme.SubText, Font = FONT,
	})

	local current = nil

	Onyx:Connect(UserInputService.InputChanged, function(input)
		if not holder.Visible then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local x, y = input.Position.X, input.Position.Y
		holder.Position = UDim2.fromOffset(x + 16, y + 18)
	end)

	Tooltip = {
		Show = function(text, owner)
			if not text or text == "" then return end
			current = owner
			label.Text = text
			holder.Visible = true
		end,
		Hide = function(owner)
			if owner and current ~= owner then return end
			holder.Visible = false
			current = nil
		end,
	}
end

-- attaches a hover tooltip to any GuiObject
local function AttachTooltip(gui, text)
	if not text or text == "" then return end
	gui.MouseEnter:Connect(function() Tooltip.Show(text, gui) end)
	gui.MouseLeave:Connect(function() Tooltip.Hide(gui) end)
	gui.Destroying:Connect(function() Tooltip.Hide(gui) end)
end

-- ================================================================
--  NOTIFICATIONS
-- ================================================================

local ToastHolder = New("Frame", {
	Name                   = "Stack",
	BackgroundTransparency = 1,
	AnchorPoint            = Vector2.new(1, 1),
	Position               = UDim2.new(1, -18, 1, -18),
	Size                   = UDim2.fromOffset(288, 0),
	AutomaticSize          = Enum.AutomaticSize.Y,
	ZIndex                 = 801,
	Parent                 = ToastLayer,
}, {
	New("UIListLayout", {
		Padding             = UDim.new(0, 8),
		SortOrder           = Enum.SortOrder.LayoutOrder,
		VerticalAlignment   = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}),
})

local ToastOrder = 0

local TOAST_COLORS = {
	default = Theme.Accent,
	info    = Theme.Info,
	success = Theme.Success,
	warning = Theme.Warning,
	warn    = Theme.Warning,
	error   = Theme.Danger,
	danger  = Theme.Danger,
}

function Onyx.Notify(a, b)
	local cfg = b
	if a ~= Onyx then cfg = a end
	if typeof(cfg) == "string" then cfg = { Title = cfg } end
	cfg = cfg or {}

	local title    = tostring(cfg.Title or cfg.Name or "Notification")
	local content  = cfg.Content or cfg.Description or cfg.Text
	local duration = tonumber(cfg.Duration or cfg.Time) or 4
	local kind     = tostring(cfg.Type or cfg.Kind or "default"):lower()
	local accent   = TOAST_COLORS[kind] or Theme.Accent

	ToastOrder = ToastOrder + 1

	local slot = New("Frame", {
		Name                   = "Slot",
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		LayoutOrder            = ToastOrder,
		ZIndex                 = 802,
		Parent                 = ToastHolder,
	})

	local card = New("Frame", {
		Name                   = "Toast",
		BackgroundColor3       = Theme.Surface,
		BackgroundTransparency = 1,
		Size                   = UDim2.new(1, 0, 0, 0),
		AutomaticSize          = Enum.AutomaticSize.Y,
		ClipsDescendants       = true,
		ZIndex                 = 802,
		Parent                 = slot,
	})
	Corner(7, card)
	local cardStroke = Stroke(card, Theme.Line, 1)

	-- accent stripe down the left edge
	local stripe = New("Frame", {
		Name = "Stripe", BackgroundColor3 = accent, BackgroundTransparency = 1,
		BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, -16),
		Position = UDim2.fromOffset(0, 8), ZIndex = 804, Parent = card,
	})
	Corner(2, stripe)

	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 803, Parent = card,
	})
	Padding(body, 11, 12, 14, 12)
	List(body, 3)

	local titleLabel = Text({
		Parent = body, ZIndex = 803, Font = FONT_SB, TextSize = 13, LayoutOrder = 1,
		Text = title, Size = UDim2.new(1, 0, 0, 15), TextTransparency = 1,
	})

	local bodyLabel
	if content and content ~= "" then
		bodyLabel = Text({
			Parent = body, ZIndex = 803, Font = FONT, TextSize = 12, LayoutOrder = 2,
			Text = tostring(content), TextColor3 = Theme.SubText,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextTransparency = 1,
		})
	end

	-- countdown line along the bottom
	local timerTrack = New("Frame", {
		BackgroundColor3 = Theme.LineBright, BackgroundTransparency = 1,
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 804, Parent = card,
	})
	local timerFill = New("Frame", {
		BackgroundColor3 = accent, BackgroundTransparency = 1,
		BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 805, Parent = timerTrack,
	})

	card.Position = UDim2.fromOffset(28, 0)
	Tween(card,        { BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0) }, EASE_SMOOTH)
	Tween(cardStroke,  { Transparency = 0 }, EASE_SMOOTH)
	Tween(stripe,      { BackgroundTransparency = 0 }, EASE_SMOOTH)
	Tween(titleLabel,  { TextTransparency = 0 }, EASE_SMOOTH)
	Tween(timerTrack,  { BackgroundTransparency = 0.55 }, EASE_SMOOTH)
	Tween(timerFill,   { BackgroundTransparency = 0.15 }, EASE_SMOOTH)
	if bodyLabel then Tween(bodyLabel, { TextTransparency = 0 }, EASE_SMOOTH) end

	local closed = false
	local function close()
		if closed then return end
		closed = true
		Tween(card,       { BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0) }, EASE_OUT)
		Tween(cardStroke, { Transparency = 1 }, EASE_OUT)
		Tween(stripe,     { BackgroundTransparency = 1 }, EASE_OUT)
		Tween(titleLabel, { TextTransparency = 1 }, EASE_OUT)
		Tween(timerTrack, { BackgroundTransparency = 1 }, EASE_OUT)
		Tween(timerFill,  { BackgroundTransparency = 1 }, EASE_OUT)
		if bodyLabel then Tween(bodyLabel, { TextTransparency = 1 }, EASE_OUT) end
		task.delay(0.24, function()
			if slot then slot:Destroy() end
		end)
	end

	-- click to dismiss early
	local hit = New("TextButton", {
		BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1),
		ZIndex = 806, Parent = card, AutoButtonColor = false,
	})
	hit.MouseButton1Click:Connect(close)

	if duration > 0 then
		Tween(timerFill, { Size = UDim2.fromScale(0, 1) }, TweenInfo.new(duration, Enum.EasingStyle.Linear))
		task.delay(duration, close)
	end

	return { Close = close, Instance = card }
end

Onyx.Notification = Onyx.Notify

-- ================================================================
--  WINDOW
-- ================================================================

local ElementAPI  -- forward declaration (defined further down)

function Onyx.CreateWindow(a, b)
	local cfg = b
	if a ~= Onyx then cfg = a end
	cfg = cfg or {}

	local title    = tostring(cfg.Title or cfg.Name or "Onyx")
	local subTitle = cfg.SubTitle or cfg.Subtitle or cfg.Description
	local size     = cfg.Size or UDim2.fromOffset(640, 440)
	local minSize  = cfg.MinSize or Vector2.new(480, 320)
	local toggleKey= cfg.Keybind or cfg.ToggleKey or Enum.KeyCode.RightShift
	local resizable= cfg.Resizable ~= false
	local showUser = cfg.ShowUserInfo ~= false

	if cfg.Accent then Theme.Accent = cfg.Accent end
	if cfg.Folder then Onyx.Folder = cfg.Folder end

	local Window = {
		Tabs        = {},
		ActiveTab   = nil,
		Minimized   = false,
		Visible     = true,
		ToggleKey   = toggleKey,
		Title       = title,
	}

	----------------------------------------------------------------
	-- shell
	----------------------------------------------------------------
	local Shell = New("Frame", {
		Name             = "Window",
		BackgroundColor3 = Theme.Backdrop,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0.5, 0.5),
		Position         = cfg.Position or UDim2.fromScale(0.5, 0.5),
		Size             = size,
		ClipsDescendants = true,
		ZIndex           = 2,
		Parent           = WindowLayer,
	})
	Corner(9, Shell)
	Stroke(Shell, Theme.LineBright, 0.35)
	Window.Frame = Shell

	-- faint top-edge highlight: gives the black surface a sense of light
	local topGloss = New("Frame", {
		Name = "Gloss", BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.94, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 90), ZIndex = 2, Parent = Shell,
	})
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = topGloss,
	})

	----------------------------------------------------------------
	-- topbar
	----------------------------------------------------------------
	local TopBar = New("Frame", {
		Name = "TopBar", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38), ZIndex = 4, Parent = Shell,
	})

	New("Frame", {
		Name = "Hairline", BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1), ZIndex = 5, Parent = TopBar,
	})

	local dot = New("Frame", {
		Name = "Dot", BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 15, 0.5, 0),
		Size = UDim2.fromOffset(6, 6), ZIndex = 5, Parent = TopBar,
	})
	Corner(3, dot)
	BindAccent(dot, "BackgroundColor3")

	local titleLabel = Text({
		Name = "Title", Parent = TopBar, ZIndex = 5, Font = FONT_B, TextSize = 13,
		Text = title, Position = UDim2.new(0, 29, 0, 0), Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
	})

	local subLabel
	if subTitle and subTitle ~= "" then
		local sep = New("Frame", {
			BackgroundColor3 = Theme.LineBright, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(1, 12),
			ZIndex = 5, Parent = TopBar,
		})
		subLabel = Text({
			Name = "SubTitle", Parent = TopBar, ZIndex = 5, Font = FONT, TextSize = 12,
			Text = tostring(subTitle), TextColor3 = Theme.Muted,
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		})
		-- keep the separator/subtitle glued to the end of the title
		local function layout()
			local x = 29 + titleLabel.AbsoluteSize.X + 10
			sep.Position      = UDim2.new(0, x, 0.5, 0)
			subLabel.Position = UDim2.new(0, x + 10, 0, 0)
		end
		titleLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		task.defer(layout)
	end

	-- topbar action buttons ------------------------------------------------
	local actions = New("Frame", {
		Name = "Actions", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 5, Parent = TopBar,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = actions,
	})

	local function TopButton(glyph, order, tip)
		local btn = New("TextButton", {
			BackgroundColor3 = Theme.Backdrop, BackgroundTransparency = 1,
			AutoButtonColor = false, Text = glyph, Font = FONT_M, TextSize = 14,
			TextColor3 = Theme.Muted, Size = UDim2.fromOffset(24, 22),
			LayoutOrder = order, ZIndex = 6, Parent = actions,
		})
		Corner(5, btn)
		btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Hover, TextColor3 = Theme.Text }, EASE_SNAP)
		end)
		btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 1, TextColor3 = Theme.Muted }, EASE_SNAP)
		end)
		if tip then AttachTooltip(btn, tip) end
		return btn
	end

	local minimizeBtn = TopButton("\u{2013}", 1, "Minimize")
	local closeBtn    = TopButton("\u{2715}", 2, "Unload interface")

	----------------------------------------------------------------
	-- body : rail + content
	----------------------------------------------------------------
	local Body = New("Frame", {
		Name = "Body", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38),
		ZIndex = 3, Parent = Shell,
	})

	local RAIL_W = tonumber(cfg.RailWidth) or 158

	local Rail = New("Frame", {
		Name = "Rail", BackgroundColor3 = Theme.Rail, BorderSizePixel = 0,
		Size = UDim2.new(0, RAIL_W, 1, 0), ZIndex = 3, Parent = Body,
	})
	New("Frame", { -- hairline divider between rail and content
		BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0), ZIndex = 4, Parent = Rail,
	})

	local TabList = New("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 1, showUser and -74 or -20),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 4, Parent = Rail,
	})
	Padding(TabList, 0, 8, 8, 8)
	List(TabList, 3)

	-- user card pinned to the bottom of the rail
	if showUser and LocalPlayer then
		local card = New("Frame", {
			Name = "User", BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -10),
			Size = UDim2.new(1, -1, 0, 44), ZIndex = 4, Parent = Rail,
		})
		New("Frame", {
			BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
			Size = UDim2.new(1, -20, 0, 1), Position = UDim2.fromOffset(10, 0),
			ZIndex = 5, Parent = card,
		})

		local avatar = New("ImageLabel", {
			BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 2),
			Size = UDim2.fromOffset(26, 26), ZIndex = 5, Parent = card,
		})
		Corner(13, avatar)
		Stroke(avatar, Theme.Line)

		Text({
			Parent = card, ZIndex = 5, Font = FONT_M, TextSize = 12,
			Text = LocalPlayer.DisplayName, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 45, 0.5, -6), Size = UDim2.new(1, -55, 0, 13),
		})
		Text({
			Parent = card, ZIndex = 5, Font = FONT, TextSize = 11,
			Text = "@" .. LocalPlayer.Name, TextColor3 = Theme.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 45, 0.5, 7), Size = UDim2.new(1, -55, 0, 12),
		})

		task.spawn(function()
			local ok, img = pcall(function()
				return Players:GetUserThumbnailAsync(
					LocalPlayer.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
			end)
			if ok and img then avatar.Image = img end
		end)
	end

	local Content = New("Frame", {
		Name = "Content", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(RAIL_W, 0), Size = UDim2.new(1, -RAIL_W, 1, 0),
		ClipsDescendants = true, ZIndex = 3, Parent = Body,
	})

	----------------------------------------------------------------
	-- resize grip
	----------------------------------------------------------------
	if resizable then
		local grip = New("TextButton", {
			Name = "Resize", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.fromOffset(18, 18), ZIndex = 20, Parent = Shell,
		})
		for i = 1, 2 do
			New("Frame", {
				BackgroundColor3 = Theme.LineBright, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 1), Rotation = -45,
				Position = UDim2.new(1, -3, 1, -3 - (i - 1) * 4),
				Size = UDim2.fromOffset(1, 5 + (i - 1) * 4),
				ZIndex = 21, Parent = grip,
			})
		end

		local sizing, startSize, startPos = false, nil, nil
		grip.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			sizing    = true
			startSize = Shell.AbsoluteSize
			startPos  = input.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					sizing = false
					conn:Disconnect()
				end
			end)
		end)
		Onyx:Connect(UserInputService.InputChanged, function(input)
			if not sizing then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local delta = input.Position - startPos
			Shell.Size = UDim2.fromOffset(
				math.max(minSize.X, startSize.X + delta.X),
				math.max(minSize.Y, startSize.Y + delta.Y)
			)
		end)
	end

	----------------------------------------------------------------
	-- drag / minimize / close
	----------------------------------------------------------------
	-- popouts (dropdown lists, colour panels) register a closer here so that
	-- dragging the window or switching tabs dismisses them
	Window.Popouts = {}
	function Window.RegisterPopout(close)
		table.insert(Window.Popouts, close)
		return function()
			for i, fn in ipairs(Window.Popouts) do
				if fn == close then table.remove(Window.Popouts, i); break end
			end
		end
	end
	function Window.CloseAllPopouts(except)
		for _, fn in ipairs(Window.Popouts) do
			if fn ~= except then pcall(fn) end
		end
	end

	Draggable(Shell, TopBar, function() Window.CloseAllPopouts() end)

	local restoreSize = size
	local function setMinimized(state)
		Window.Minimized = state
		if state then
			restoreSize = Shell.Size
			Body.Visible = false
			minimizeBtn.Text = "\u{25A1}"
			Tween(Shell, { Size = UDim2.new(restoreSize.X.Scale, restoreSize.X.Offset, 0, 38) }, EASE_SMOOTH)
		else
			minimizeBtn.Text = "\u{2013}"
			Tween(Shell, { Size = restoreSize }, EASE_SMOOTH)
			task.delay(0.18, function() Body.Visible = true end)
		end
	end

	minimizeBtn.MouseButton1Click:Connect(function() setMinimized(not Window.Minimized) end)
	Window.Minimize = function(_, state)
		if state == nil then state = not Window.Minimized end
		setMinimized(state and true or false)
	end

	function Window.SetVisible(p1, p2)
		local state = p2
		if p1 ~= Window then state = p1 end
		Window.Visible = state and true or false
		if Window.Visible then
			Shell.Visible = true
			Shell.BackgroundTransparency = 1
			Tween(Shell, { BackgroundTransparency = 0 }, EASE_OUT)
		else
			Window.CloseAllPopouts()
			Shell.Visible = false
		end
	end

	function Window.Toggle()
		Window.SetVisible(not Window.Visible)
	end

	function Window.Destroy()
		Window.CloseAllPopouts()
		Shell:Destroy()
		for i, w in ipairs(Onyx.Windows) do
			if w == Window then table.remove(Onyx.Windows, i); break end
		end
	end
	Window.Unload = Window.Destroy

	----------------------------------------------------------------
	-- modal dialog
	----------------------------------------------------------------
	function Window:Dialog(dcfg)
		dcfg = dcfg or {}
		local buttons = dcfg.Buttons or dcfg.Options or { { Title = "Okay" } }

		local scrim = New("Frame", {
			Name = "Dialog", BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 300, Parent = Shell,
		})
		local block = New("TextButton", { -- swallows clicks behind the modal
			BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1), ZIndex = 301, Parent = scrim,
		})

		local card = New("Frame", {
			BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 320, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, ZIndex = 302, Parent = scrim,
		})
		Corner(9, card)
		local cardStroke = Stroke(card, Theme.LineBright, 1)
		Padding(card, 16, 14, 16, 16)
		List(card, 10)

		local dTitle = Text({
			Parent = card, ZIndex = 303, Font = FONT_B, TextSize = 14, LayoutOrder = 1,
			Text = tostring(dcfg.Title or "Confirm"), TextTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
		})

		local dBody
		if dcfg.Content or dcfg.Description then
			dBody = Text({
				Parent = card, ZIndex = 303, Font = FONT, TextSize = 12.5, LayoutOrder = 2,
				Text = tostring(dcfg.Content or dcfg.Description),
				TextColor3 = Theme.SubText, TextWrapped = true, TextTransparency = 1,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			})
		end

		local row = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 3, ZIndex = 303, Parent = card,
		})
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = row,
		})

		local closed = false
		local function close()
			if closed then return end
			closed = true
			Tween(scrim, { BackgroundTransparency = 1 }, EASE_OUT)
			Tween(card, { BackgroundTransparency = 1, Size = UDim2.new(0, 320, 0, card.AbsoluteSize.Y) }, EASE_OUT)
			Tween(cardStroke, { Transparency = 1 }, EASE_OUT)
			Tween(dTitle, { TextTransparency = 1 }, EASE_OUT)
			if dBody then Tween(dBody, { TextTransparency = 1 }, EASE_OUT) end
			task.delay(0.22, function() if scrim then scrim:Destroy() end end)
		end

		for i, opt in ipairs(buttons) do
			local primary = opt.Primary or (i == #buttons and #buttons > 1)
			local btn = New("TextButton", {
				BackgroundColor3 = primary and Theme.Accent or Theme.SurfaceAlt,
				AutoButtonColor = false, Text = tostring(opt.Title or opt.Name or "Okay"),
				Font = FONT_M, TextSize = 12.5,
				TextColor3 = primary and Theme.OnAccent or Theme.Text,
				Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = i, ZIndex = 304, Parent = row,
			})
			Padding(btn, 0, 0, 14, 14)
			Corner(6, btn)
			if primary then BindAccent(btn, "BackgroundColor3") else Stroke(btn, Theme.Line) end
			if not primary then Interact(btn, Theme.SurfaceAlt, Theme.Hover, Theme.Active) end

			btn.MouseButton1Click:Connect(function()
				close()
				if opt.Callback then task.spawn(opt.Callback) end
			end)
		end

		card.Size = UDim2.new(0, 300, 0, 0)
		Tween(scrim, { BackgroundTransparency = 0.45 }, EASE_OUT)
		Tween(card, { BackgroundTransparency = 0, Size = UDim2.new(0, 320, 0, 0) }, EASE_SMOOTH)
		Tween(cardStroke, { Transparency = 0 }, EASE_SMOOTH)
		Tween(dTitle, { TextTransparency = 0 }, EASE_SMOOTH)
		if dBody then Tween(dBody, { TextTransparency = 0 }, EASE_SMOOTH) end

		if dcfg.Dismissable ~= false then
			block.MouseButton1Click:Connect(close)
		end

		return { Close = close }
	end

	closeBtn.MouseButton1Click:Connect(function()
		if cfg.OnClose == "hide" then
			Window:SetVisible(false)
			return
		end
		Window:Dialog({
			Title   = "Unload interface",
			Content = "This closes " .. title .. " and removes every element it created.",
			Buttons = {
				{ Title = "Cancel" },
				{ Title = "Unload", Primary = true, Callback = function()
					if cfg.OnClose and typeof(cfg.OnClose) == "function" then
						task.spawn(cfg.OnClose)
					end
					Onyx:Unload()
				end },
			},
		})
	end)

	----------------------------------------------------------------
	-- toggle keybind + touch button
	----------------------------------------------------------------
	Onyx:Connect(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		if Window.ToggleKey and input.KeyCode == Window.ToggleKey then
			Window:Toggle()
		end
	end)

	function Window:SetToggleKey(key)
		Window.ToggleKey = key
	end

	if UserInputService.TouchEnabled and cfg.MobileButton ~= false then
		local fab = New("TextButton", {
			Name = "Toggle", BackgroundColor3 = Theme.Surface, AutoButtonColor = false,
			Text = "", Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(42, 42),
			ZIndex = 30, Parent = WindowLayer,
		})
		Corner(21, fab)
		Stroke(fab, Theme.LineBright, 0.3)
		local fabDot = New("Frame", {
			BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10), ZIndex = 31, Parent = fab,
		})
		Corner(5, fabDot)
		BindAccent(fabDot, "BackgroundColor3")

		local moved = false
		Draggable(fab, fab, function() moved = false end)
		fab.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch then moved = true end
		end)
		fab.MouseButton1Click:Connect(function()
			if moved then moved = false; return end
			Window:Toggle()
		end)
		Window.MobileButton = fab
	end

	----------------------------------------------------------------
	-- tabs
	----------------------------------------------------------------
	local tabOrder = 0

	function Window.CreateTab(x, y)
		local tcfg = y
		if x ~= Window then tcfg = x end
		if typeof(tcfg) == "string" then tcfg = { Title = tcfg } end
		tcfg = tcfg or {}

		tabOrder = tabOrder + 1
		local tabName = tostring(tcfg.Title or tcfg.Name or ("Tab " .. tabOrder))
		local iconAsset = ResolveIcon(tcfg.Icon)
		local iconGlyph = (not iconAsset and typeof(tcfg.Icon) == "string" and tcfg.Icon ~= "") and tcfg.Icon or nil

		local Tab = { Title = tabName, Window = Window, Index = tabOrder }

		-- rail button ------------------------------------------------------
		local btn = New("TextButton", {
			Name = tabName, BackgroundColor3 = Theme.Rail, BackgroundTransparency = 1,
			AutoButtonColor = false, Text = "", Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = tabOrder, ZIndex = 5, Parent = TabList,
		})
		Corner(6, btn)

		local marker = New("Frame", {
			BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(2, 0), ZIndex = 7, Parent = btn,
		})
		Corner(1, marker)
		BindAccent(marker, "BackgroundColor3")

		local textX = 12
		local iconObj
		if iconAsset then
			iconObj = New("ImageLabel", {
				BackgroundTransparency = 1, Image = iconAsset, ImageColor3 = Theme.Muted,
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0),
				Size = UDim2.fromOffset(15, 15), ZIndex = 6, Parent = btn,
			})
			textX = 34
		elseif iconGlyph then
			iconObj = Text({
				Parent = btn, ZIndex = 6, Font = FONT_M, TextSize = 13, Text = iconGlyph,
				TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0),
				Size = UDim2.fromOffset(15, 15),
			})
			textX = 34
		end

		local label = Text({
			Parent = btn, ZIndex = 6, Font = FONT_M, TextSize = 12.5, Text = tabName,
			TextColor3 = Theme.SubText, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, textX, 0, 0), Size = UDim2.new(1, -textX - 10, 1, 0),
		})

		-- page -------------------------------------------------------------
		local page = New("ScrollingFrame", {
			Name = tabName, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), Visible = false,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.LineBright,
			ScrollBarImageTransparency = 0.3,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 4, Parent = Content,
		})
		Padding(page, 14, 16, 14, 12)
		List(page, 9)

		Tab.Instance  = btn
		Tab.Page      = page
		Tab.Container = page

		function Tab.Select()
			if Window.ActiveTab == Tab then return end
			Window.CloseAllPopouts()

			if Window.ActiveTab then
				local prev = Window.ActiveTab
				prev.Page.Visible = false
				Tween(prev.Instance, { BackgroundTransparency = 1 }, EASE_SNAP)
				Tween(prev.TitleLabel, { TextColor3 = Theme.SubText }, EASE_SNAP)
				Tween(prev.Indicator, { Size = UDim2.fromOffset(2, 0) }, EASE_SNAP)
				if prev.IconObject then
					Tween(prev.IconObject, prev.IconIsImage
						and { ImageColor3 = Theme.Muted } or { TextColor3 = Theme.Muted }, EASE_SNAP)
				end
			end

			Window.ActiveTab = Tab
			page.Visible = true
			page.CanvasPosition = Vector2.new(0, 0)
			Tween(btn, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Surface }, EASE_SNAP)
			Tween(label, { TextColor3 = Theme.Text }, EASE_SNAP)
			Tween(marker, { Size = UDim2.fromOffset(2, 16) }, EASE_OUT)
			if iconObj then
				Tween(iconObj, iconAsset
					and { ImageColor3 = Theme.Text } or { TextColor3 = Theme.Text }, EASE_SNAP)
			end
			if tcfg.OnSelect then task.spawn(tcfg.OnSelect) end
		end
		Tab.Indicator   = marker
		Tab.TitleLabel  = label
		Tab.IconObject  = iconObj
		Tab.IconIsImage = iconAsset ~= nil

		btn.MouseButton1Click:Connect(Tab.Select)
		btn.MouseEnter:Connect(function()
			if Window.ActiveTab == Tab then return end
			Tween(btn, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Hover }, EASE_SNAP)
			Tween(label, { TextColor3 = Theme.Text }, EASE_SNAP)
		end)
		btn.MouseLeave:Connect(function()
			if Window.ActiveTab == Tab then return end
			Tween(btn, { BackgroundTransparency = 1 }, EASE_SNAP)
			Tween(label, { TextColor3 = Theme.SubText }, EASE_SNAP)
		end)

		function Tab.SetTitle(a, newTitle)
			if a ~= Tab then newTitle = a end
			Tab.Title  = tostring(newTitle)
			label.Text = Tab.Title
		end

		ElementAPI(Tab, page, Window)

		-- a Section is just a titled container that shares the element API
		function Tab.CreateSection(p1, p2)
			local scfg = p2
			if p1 ~= Tab then scfg = p1 end
			if typeof(scfg) == "string" then scfg = { Title = scfg } end
			scfg = scfg or {}

			local holder = New("Frame", {
				Name = "Section", BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = #page:GetChildren(), ZIndex = 5, Parent = page,
			})
			List(holder, 7)

			local head = New("Frame", {
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 1, ZIndex = 5, Parent = holder,
			})
			local headLabel = Text({
				Parent = head, ZIndex = 6, Font = FONT_B, TextSize = 11.5,
				Text = string.upper(tostring(scfg.Title or scfg.Name or "Section")),
				TextColor3 = Theme.Muted, Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
			})
			local rule = New("Frame", {
				BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 1),
				Size = UDim2.new(1, 0, 0, 1), ZIndex = 5, Parent = head,
			})
			headLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				rule.Size = UDim2.new(1, -(headLabel.AbsoluteSize.X + 10), 0, 1)
			end)
			task.defer(function()
				rule.Size = UDim2.new(1, -(headLabel.AbsoluteSize.X + 10), 0, 1)
			end)

			local inner = New("Frame", {
				Name = "Items", BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2, ZIndex = 5, Parent = holder,
			})
			List(inner, 6)

			local Section = { Title = scfg.Title, Instance = holder, Container = inner, Window = Window }
			function Section.SetTitle(a, t)
				if a ~= Section then t = a end
				headLabel.Text = string.upper(tostring(t))
			end
			function Section.Destroy() holder:Destroy() end
			ElementAPI(Section, inner, Window)
			return Section
		end
		Tab.AddSection = Tab.CreateSection
		Tab.Section    = Tab.CreateSection

		table.insert(Window.Tabs, Tab)
		if #Window.Tabs == 1 or tcfg.Default then Tab.Select() end
		return Tab
	end

	Window.AddTab = Window.CreateTab
	Window.Tab    = Window.CreateTab

	function Window.SelectTab(p1, p2)
		local target = p2
		if p1 ~= Window then target = p1 end
		if typeof(target) == "number" then target = Window.Tabs[target] end
		if target and target.Select then target.Select() end
	end

	function Window.Notify(p1, p2)
		return Onyx.Notify(p1 ~= Window and p1 or p2)
	end

	table.insert(Onyx.Windows, Window)
	return Window
end

-- ================================================================
--  ELEMENTS
-- ================================================================

local function RegisterFlag(element, flag)
	if not flag then return end
	element.Flag = flag
	Onyx.Options[flag] = element
	Onyx.Flags[flag] = element.Value
end

local function SetFlag(element, value)
	element.Value = value
	if element.Flag then Onyx.Flags[element.Flag] = value end
end

local function Fire(callback, ...)
	if typeof(callback) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, args.n))
		if not ok then
			warn("[Onyx] callback error: " .. tostring(err))
		end
	end)
end

-- shared row scaffold: title / description on the left, control slot on the right
local function BaseRow(parent, opts)
	opts = opts or {}
	local minH = opts.Height or 34
	local slotW = opts.SlotWidth or 0

	local row = New("TextButton", {
		Name                   = opts.Name or "Element",
		BackgroundColor3       = Theme.Surface,
		AutoButtonColor        = false,
		Text                   = "",
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, minH),
		AutomaticSize          = Enum.AutomaticSize.Y,
		LayoutOrder            = opts.LayoutOrder or 0,
		ZIndex                 = 6,
		Parent                 = parent,
	})
	Corner(6, row)
	local rowStroke = Stroke(row, Theme.Line)
	Padding(row, 8, 8, 11, 10)

	local col = New("Frame", {
		Name = "Text", BackgroundTransparency = 1,
		Size = UDim2.new(1, -(slotW + (slotW > 0 and 12 or 0)), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 7, Parent = row,
	})
	List(col, 2)

	local titleLabel = Text({
		Name = "Title", Parent = col, ZIndex = 7, Font = FONT_M, TextSize = 12.5,
		Text = tostring(opts.Title or ""), Size = UDim2.new(1, 0, 0, 15),
	})

	local descLabel
	if opts.Description and opts.Description ~= "" then
		descLabel = Text({
			Name = "Description", Parent = col, ZIndex = 7, Font = FONT, TextSize = 11.5,
			Text = tostring(opts.Description), TextColor3 = Theme.Muted,
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})
	end

	local slot = New("Frame", {
		Name = "Slot", BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(slotW, minH - 16), ZIndex = 7, Parent = row,
	})

	return {
		Row = row, Stroke = rowStroke, Column = col, Slot = slot,
		Title = titleLabel, Description = descLabel,
		SetTitle = function(t) titleLabel.Text = tostring(t) end,
		SetDescription = function(t)
			if descLabel then descLabel.Text = tostring(t or "") end
		end,
	}
end

-- attaches every element constructor to `holder`, creating instances in `parent`
function ElementAPI(holder, parent, Window)

	local function order()
		return #parent:GetChildren()
	end

	------------------------------------------------------------------
	-- Label
	------------------------------------------------------------------
	function holder.Label(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		if typeof(cfg) == "string" then cfg = { Title = cfg } end
		cfg = cfg or {}

		local label = Text({
			Name = "Label", Parent = parent, ZIndex = 6, Font = FONT_M, TextSize = 12.5,
			Text = tostring(cfg.Title or cfg.Text or ""),
			TextColor3 = cfg.Color or Theme.SubText, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order(),
		})

		local api = { Instance = label, Type = "Label" }
		function api.SetTitle(a, t) label.Text = tostring(typeof(a) == "string" and a or t) end
		api.SetText = api.SetTitle
		function api.SetVisible(a, v) label.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		function api.Destroy() label:Destroy() end
		return api
	end
	holder.AddLabel = holder.Label

	------------------------------------------------------------------
	-- Paragraph
	------------------------------------------------------------------
	function holder.Paragraph(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local box = New("Frame", {
			Name = "Paragraph", BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order(), ZIndex = 6, Parent = parent,
		})
		Corner(6, box)
		Stroke(box, Theme.Line)
		Padding(box, 10, 11, 11, 11)
		List(box, 4)

		local head = Text({
			Parent = box, ZIndex = 7, Font = FONT_SB, TextSize = 12.5,
			Text = tostring(cfg.Title or cfg.Name or ""), Size = UDim2.new(1, 0, 0, 15),
		})
		local body = Text({
			Parent = box, ZIndex = 7, Font = FONT, TextSize = 12,
			Text = tostring(cfg.Content or cfg.Description or cfg.Text or ""),
			TextColor3 = Theme.SubText, TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		})

		local api = { Instance = box, Type = "Paragraph" }
		function api.SetTitle(a, t) head.Text = tostring(typeof(a) == "string" and a or t) end
		function api.SetContent(a, t) body.Text = tostring(typeof(a) == "string" and a or t) end
		api.SetText = api.SetContent
		function api.SetVisible(a, v) box.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		function api.Destroy() box:Destroy() end
		return api
	end
	holder.AddParagraph = holder.Paragraph

	------------------------------------------------------------------
	-- Divider
	------------------------------------------------------------------
	function holder.Divider(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		if typeof(cfg) == "string" then cfg = { Title = cfg } end
		cfg = cfg or {}

		local wrap = New("Frame", {
			Name = "Divider", BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, cfg.Title and 18 or 9),
			LayoutOrder = order(), ZIndex = 6, Parent = parent,
		})

		if cfg.Title then
			local lbl = Text({
				Parent = wrap, ZIndex = 7, Font = FONT_M, TextSize = 11,
				Text = string.upper(tostring(cfg.Title)), TextColor3 = Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
			})
			local function lines()
				local half = (wrap.AbsoluteSize.X - lbl.TextBounds.X) / 2 - 8
				if half < 4 then half = 4 end
				return half
			end
			local left = New("Frame", {
				BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(0, 1), ZIndex = 6, Parent = wrap,
			})
			local right = New("Frame", {
				BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(0, 1), ZIndex = 6, Parent = wrap,
			})
			local function refresh()
				local w = lines()
				left.Size  = UDim2.fromOffset(w, 1)
				right.Size = UDim2.fromOffset(w, 1)
			end
			wrap:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
			task.defer(refresh)
		else
			New("Frame", {
				BackgroundColor3 = Theme.Line, BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, 0, 0, 1), ZIndex = 6, Parent = wrap,
			})
		end

		return {
			Instance = wrap, Type = "Divider",
			SetVisible = function(a, v)
				wrap.Visible = (typeof(a) == "boolean" and a or v) and true or false
			end,
			Destroy = function() wrap:Destroy() end,
		}
	end
	holder.AddDivider = holder.Divider
	holder.Separator  = holder.Divider

	------------------------------------------------------------------
	-- Button
	------------------------------------------------------------------
	function holder.Button(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = BaseRow(parent, {
			Name = "Button", Title = cfg.Title or cfg.Name or "Button",
			Description = cfg.Description, SlotWidth = 22, LayoutOrder = order(),
		})
		Interact(base.Row, Theme.Surface, Theme.Hover, Theme.Active)

		local chevron = Text({
			Parent = base.Slot, ZIndex = 8, Font = FONT_M, TextSize = 13,
			Text = "\u{203A}", TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1),
		})
		base.Row.MouseEnter:Connect(function() Tween(chevron, { TextColor3 = Theme.Text }, EASE_SNAP) end)
		base.Row.MouseLeave:Connect(function() Tween(chevron, { TextColor3 = Theme.Muted }, EASE_SNAP) end)
		AttachTooltip(base.Row, cfg.Tooltip)

		local api = { Instance = base.Row, Type = "Button", Callback = cfg.Callback }

		base.Row.MouseButton1Click:Connect(function()
			-- brief accent flash so the press always reads
			Tween(base.Stroke, { Color = Theme.Accent, Transparency = 0.3 }, EASE_SNAP)
			task.delay(0.16, function()
				Tween(base.Stroke, { Color = Theme.Line, Transparency = 0 }, EASE_OUT)
			end)

			if cfg.Confirm then
				Window:Dialog({
					Title   = cfg.ConfirmTitle or "Are you sure?",
					Content = cfg.ConfirmText or ("Run \"" .. tostring(cfg.Title or "this action") .. "\"?"),
					Buttons = {
						{ Title = "Cancel" },
						{ Title = "Confirm", Primary = true, Callback = function() Fire(api.Callback) end },
					},
				})
			else
				Fire(api.Callback)
			end
		end)

		api.SetTitle = function(a, t) base.SetTitle(typeof(a) == "string" and a or t) end
		api.SetDescription = function(a, t) base.SetDescription(typeof(a) == "string" and a or t) end
		api.SetCallback = function(a, f) api.Callback = (typeof(a) == "function" and a) or f end
		api.SetVisible = function(a, v) base.Row.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		api.Destroy = function() base.Row:Destroy() end
		return api
	end
	holder.AddButton = holder.Button

	------------------------------------------------------------------
	-- Toggle
	------------------------------------------------------------------
	function holder.Toggle(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = BaseRow(parent, {
			Name = "Toggle", Title = cfg.Title or cfg.Name or "Toggle",
			Description = cfg.Description, SlotWidth = 34, LayoutOrder = order(),
		})
		Interact(base.Row, Theme.Surface, Theme.Hover, Theme.Active)
		AttachTooltip(base.Row, cfg.Tooltip)

		local track = New("Frame", {
			BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(34, 18), ZIndex = 8, Parent = base.Slot,
		})
		Corner(9, track)
		local trackStroke = Stroke(track, Theme.LineBright)

		local knob = New("Frame", {
			BackgroundColor3 = Theme.Muted, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(12, 12), ZIndex = 9, Parent = track,
		})
		Corner(6, knob)

		local api = { Instance = base.Row, Type = "Toggle", Value = false, Callback = cfg.Callback }

		local function render(animate)
			local info = animate and EASE_OUT or TweenInfo.new(0)
			if api.Value then
				Tween(track, { BackgroundColor3 = Theme.Accent }, info)
				Tween(trackStroke, { Color = Theme.Accent, Transparency = 0.4 }, info)
				Tween(knob, { BackgroundColor3 = Theme.OnAccent, Position = UDim2.new(1, -15, 0.5, 0) }, info)
			else
				Tween(track, { BackgroundColor3 = Theme.SurfaceAlt }, info)
				Tween(trackStroke, { Color = Theme.LineBright, Transparency = 0 }, info)
				Tween(knob, { BackgroundColor3 = Theme.Muted, Position = UDim2.new(0, 3, 0.5, 0) }, info)
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
		function api.Toggle() return api.Set(not api.Value) end
		api.SetValue = api.Set
		api.SetTitle = function(a, t) base.SetTitle(typeof(a) == "string" and a or t) end
		api.SetDescription = function(a, t) base.SetDescription(typeof(a) == "string" and a or t) end
		api.SetVisible = function(a, v) base.Row.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		api.Destroy = function()
			if api.Flag then Onyx.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		base.Row.MouseButton1Click:Connect(function() api.Set(not api.Value) end)

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, (cfg.Default or cfg.Value) and true or false)
		render(false)
		if api.Value and cfg.FireOnStart ~= false then Fire(api.Callback, api.Value) end
		return api
	end
	holder.AddToggle = holder.Toggle

	------------------------------------------------------------------
	-- Slider
	------------------------------------------------------------------
	function holder.Slider(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local min       = tonumber(cfg.Min or cfg.Minimum) or 0
		local max       = tonumber(cfg.Max or cfg.Maximum) or 100
		local increment = tonumber(cfg.Increment or cfg.Step) or 1
		local decimals  = tonumber(cfg.Rounding)
		local suffix    = cfg.Suffix or ""
		if decimals == nil then
			decimals = (increment % 1 == 0) and 0 or 2
		end

		local row = New("Frame", {
			Name = "Slider", BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 48), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order(), ZIndex = 6, Parent = parent,
		})
		Corner(6, row)
		Stroke(row, Theme.Line)
		Padding(row, 9, 10, 11, 11)
		List(row, 6)
		AttachTooltip(row, cfg.Tooltip)

		local head = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), ZIndex = 7, Parent = row,
		})
		local titleLabel = Text({
			Parent = head, ZIndex = 7, Font = FONT_M, TextSize = 12.5,
			Text = tostring(cfg.Title or cfg.Name or "Slider"), Size = UDim2.new(1, -70, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local valueLabel = Text({
			Parent = head, ZIndex = 7, Font = FONT_MONO, TextSize = 12,
			Text = "0", TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 70, 1, 0),
		})

		if cfg.Description and cfg.Description ~= "" then
			Text({
				Parent = row, ZIndex = 7, Font = FONT, TextSize = 11.5,
				Text = tostring(cfg.Description), TextColor3 = Theme.Muted,
				TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			})
		end

		local lane = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), ZIndex = 7, Parent = row,
		})
		local track = New("Frame", {
			BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 4), ZIndex = 7, Parent = lane,
		})
		Corner(2, track)
		local fill = New("Frame", {
			BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1), ZIndex = 8, Parent = track,
		})
		Corner(2, fill)
		BindAccent(fill, "BackgroundColor3")

		local knob = New("Frame", {
			BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(10, 10), ZIndex = 9, Parent = track,
		})
		Corner(5, knob)
		Stroke(knob, Theme.Backdrop, 0, 2)
		BindAccent(knob, "BackgroundColor3")

		local api = { Instance = row, Type = "Slider", Value = min, Min = min, Max = max, Callback = cfg.Callback }

		local function format(v)
			if decimals <= 0 then return tostring(math.floor(v + 0.5)) end
			return string.format("%." .. decimals .. "f", v)
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
			value = tonumber(value) or min
			value = Clamp(Round(value, increment), min, max)
			if decimals > 0 then value = tonumber(string.format("%." .. decimals .. "f", value)) end
			local changed = value ~= api.Value
			SetFlag(api, value)
			render(true)
			if changed then Fire(api.Callback, value) end
			return value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set

		function api.SetRange(a, newMin, newMax)
			if a ~= api then newMax = newMin; newMin = a end
			min = tonumber(newMin) or min
			max = tonumber(newMax) or max
			api.Min, api.Max = min, max
			api.Set(api.Value)
		end
		api.SetTitle = function(a, t) titleLabel.Text = tostring(typeof(a) == "string" and a or t) end
		api.SetVisible = function(a, v) row.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		api.Destroy = function()
			if api.Flag then Onyx.Options[api.Flag] = nil end
			row:Destroy()
		end

		-- dragging ---------------------------------------------------------
		local dragging = false
		local function apply(x)
			local width = track.AbsoluteSize.X
			if width <= 0 then return end
			local alpha = Clamp((x - track.AbsolutePosition.X) / width, 0, 1)
			local raw = min + (max - min) * alpha
			local value = Clamp(Round(raw, increment), min, max)
			if decimals > 0 then value = tonumber(string.format("%." .. decimals .. "f", value)) end
			if value ~= api.Value then
				SetFlag(api, value)
				Fire(api.Callback, value)
			end
			render(false)
		end

		local hit = New("TextButton", {
			BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			Size = UDim2.new(1, 0, 1, 0), ZIndex = 10, Parent = lane,
		})
		hit.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			dragging = true
			Tween(knob, { Size = UDim2.fromOffset(14, 14) }, EASE_SNAP)
			apply(input.Position.X)
		end)
		Onyx:Connect(UserInputService.InputChanged, function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			apply(input.Position.X)
		end)
		Onyx:Connect(UserInputService.InputEnded, function(input)
			if not dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then return end
			dragging = false
			Tween(knob, { Size = UDim2.fromOffset(10, 10) }, EASE_SNAP)
		end)

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, Clamp(tonumber(cfg.Default or cfg.Value) or min, min, max))
		render(false)
		return api
	end
	holder.AddSlider = holder.Slider

	------------------------------------------------------------------
	-- Input (textbox)
	------------------------------------------------------------------
	function holder.Input(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local width = tonumber(cfg.Width) or 148
		local base = BaseRow(parent, {
			Name = "Input", Title = cfg.Title or cfg.Name or "Input",
			Description = cfg.Description, SlotWidth = width, LayoutOrder = order(),
		})
		AttachTooltip(base.Row, cfg.Tooltip)

		local field = New("Frame", {
			BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(width, 26), ZIndex = 8, Parent = base.Slot,
		})
		Corner(5, field)
		local fieldStroke = Stroke(field, Theme.LineBright)

		local box = New("TextBox", {
			BackgroundTransparency = 1, Font = FONT, TextSize = 12,
			TextColor3 = Theme.Text, PlaceholderText = tostring(cfg.Placeholder or "Type here"),
			PlaceholderColor3 = Theme.Muted, Text = tostring(cfg.Default or cfg.Value or ""),
			TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = cfg.ClearOnFocus or false,
			ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 9, Parent = field,
		})
		Padding(box, 0, 0, 8, 8)

		local api = { Instance = base.Row, Type = "Input", Value = box.Text, Callback = cfg.Callback }

		box.Focused:Connect(function()
			Tween(fieldStroke, { Color = Theme.Accent, Transparency = 0.25 }, EASE_SNAP)
		end)
		box.FocusLost:Connect(function(enter)
			Tween(fieldStroke, { Color = Theme.LineBright, Transparency = 0 }, EASE_SNAP)
			if cfg.Numeric then
				local n = tonumber(box.Text)
				box.Text = n and tostring(n) or ""
			end
			SetFlag(api, box.Text)
			if cfg.OnEnter and not enter then return end
			Fire(api.Callback, box.Text, enter)
		end)
		if cfg.Live then
			box:GetPropertyChangedSignal("Text"):Connect(function()
				SetFlag(api, box.Text)
				Fire(api.Callback, box.Text, false)
			end)
		end
		base.Row.MouseButton1Click:Connect(function() box:CaptureFocus() end)

		function api.Set(a, v)
			local value = v
			if a ~= api then value = a end
			box.Text = tostring(value or "")
			SetFlag(api, box.Text)
			Fire(api.Callback, box.Text, false)
			return box.Text
		end
		function api.Get() return box.Text end
		api.SetValue = api.Set
		api.SetTitle = function(a, t) base.SetTitle(typeof(a) == "string" and a or t) end
		api.SetVisible = function(a, v) base.Row.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		api.Destroy = function()
			if api.Flag then Onyx.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, box.Text)
		return api
	end
	holder.AddInput   = holder.Input
	holder.Textbox    = holder.Input
	holder.AddTextbox = holder.Input

	------------------------------------------------------------------
	-- Keybind
	------------------------------------------------------------------
	local KEY_ALIASES = {
		LeftShift = "LShift", RightShift = "RShift",
		LeftControl = "LCtrl", RightControl = "RCtrl",
		LeftAlt = "LAlt", RightAlt = "RAlt",
		MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
	}

	local function KeyName(key)
		if key == nil then return "None" end
		local name = typeof(key) == "EnumItem" and key.Name or tostring(key)
		return KEY_ALIASES[name] or name
	end

	function holder.Keybind(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local base = BaseRow(parent, {
			Name = "Keybind", Title = cfg.Title or cfg.Name or "Keybind",
			Description = cfg.Description, SlotWidth = 76, LayoutOrder = order(),
		})
		Interact(base.Row, Theme.Surface, Theme.Hover, Theme.Active)
		AttachTooltip(base.Row, cfg.Tooltip)

		local chip = New("TextButton", {
			BackgroundColor3 = Theme.SurfaceAlt, AutoButtonColor = false, Text = "None",
			Font = FONT_MONO, TextSize = 11.5, TextColor3 = Theme.SubText,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(76, 24), ZIndex = 8, Parent = base.Slot,
		})
		Corner(5, chip)
		local chipStroke = Stroke(chip, Theme.LineBright)

		local api = {
			Instance = base.Row, Type = "Keybind",
			Value = cfg.Default or cfg.Value or cfg.Key,
			Mode = tostring(cfg.Mode or "Toggle"),
			Toggled = false, Callback = cfg.Callback, Changed = cfg.ChangedCallback,
		}

		local listening = false

		local function render()
			chip.Text = listening and "..." or KeyName(api.Value)
			Tween(chip, { TextColor3 = listening and Theme.Text or Theme.SubText }, EASE_SNAP)
			Tween(chipStroke, {
				Color = listening and Theme.Accent or Theme.LineBright,
				Transparency = listening and 0.2 or 0,
			}, EASE_SNAP)
		end

		local function startListening()
			listening = true
			render()
		end

		chip.MouseButton1Click:Connect(startListening)
		base.Row.MouseButton1Click:Connect(startListening)

		function api.Set(a, key)
			local value = key
			if a ~= api then value = a end
			if typeof(value) == "string" then
				local ok, enum = pcall(function() return Enum.KeyCode[value] end)
				value = ok and enum or nil
			end
			listening = false
			SetFlag(api, value)
			render()
			Fire(api.Changed, value)
			return value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set
		api.SetTitle = function(a, t) base.SetTitle(typeof(a) == "string" and a or t) end
		api.SetVisible = function(a, v) base.Row.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		api.Destroy = function()
			if api.Flag then Onyx.Options[api.Flag] = nil end
			base.Row:Destroy()
		end

		Onyx:Connect(UserInputService.InputBegan, function(input, processed)
			if listening then
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
						api.Set(nil)
					else
						api.Set(input.KeyCode)
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton2
					or input.UserInputType == Enum.UserInputType.MouseButton3 then
					api.Set(input.UserInputType)
				end
				return
			end

			if processed or api.Value == nil then return end
			local match = (input.KeyCode == api.Value) or (input.UserInputType == api.Value)
			if not match then return end

			if api.Mode == "Hold" then
				api.Toggled = true
				Fire(api.Callback, true)
			elseif api.Mode == "Always" then
				Fire(api.Callback, true)
			else
				api.Toggled = not api.Toggled
				Fire(api.Callback, api.Toggled)
			end

			-- flash the chip so the bind visibly fires
			Tween(chipStroke, { Color = Theme.Accent, Transparency = 0.2 }, EASE_SNAP)
			task.delay(0.15, function()
				if not listening then
					Tween(chipStroke, { Color = Theme.LineBright, Transparency = 0 }, EASE_OUT)
				end
			end)
		end)

		Onyx:Connect(UserInputService.InputEnded, function(input)
			if api.Mode ~= "Hold" or api.Value == nil or not api.Toggled then return end
			if (input.KeyCode == api.Value) or (input.UserInputType == api.Value) then
				api.Toggled = false
				Fire(api.Callback, false)
			end
		end)

		RegisterFlag(api, cfg.Flag)
		SetFlag(api, api.Value)
		render()
		return api
	end
	holder.AddKeybind = holder.Keybind
	holder.Bind       = holder.Keybind

	------------------------------------------------------------------
	-- shared popout panel (dropdown lists, colour panels)
	------------------------------------------------------------------
	local function CreatePopout(anchor, opts)
		opts = opts or {}

		local catcher = New("TextButton", {
			Name = "Catcher", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 401, Parent = PopLayer,
		})
		local panel = New("Frame", {
			Name = "Popout", BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
			Size = UDim2.fromOffset(opts.Width or 200, opts.Height or 120),
			Visible = false, BackgroundTransparency = 1, ClipsDescendants = true,
			ZIndex = 402, Parent = PopLayer,
		})
		Corner(7, panel)
		local panelStroke = Stroke(panel, Theme.LineBright, 1)

		local isOpen = false
		local height = opts.Height or 120

		local function reposition()
			local screen = Root.AbsoluteSize
			local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
			local w = panel.Size.X.Offset
			local x = pos.X + size.X - w
			if opts.AlignLeft then x = pos.X end
			x = Clamp(x, 8, math.max(8, screen.X - w - 8))
			local y = pos.Y + size.Y + 6
			if y + height > screen.Y - 8 then
				y = pos.Y - height - 6
			end
			y = Clamp(y, 8, math.max(8, screen.Y - height - 8))
			panel.Position = UDim2.fromOffset(x, y)
		end

		local function close()
			if not isOpen then return end
			isOpen = false
			Tween(panel, { BackgroundTransparency = 1, Size = UDim2.fromOffset(panel.Size.X.Offset, math.max(0, height - 10)) }, EASE_OUT)
			Tween(panelStroke, { Transparency = 1 }, EASE_OUT)
			task.delay(0.2, function()
				if not isOpen then
					panel.Visible = false
					catcher.Visible = false
				end
			end)
			if opts.OnClose then opts.OnClose() end
		end

		local function open()
			if isOpen then return end
			Window.CloseAllPopouts(close)
			isOpen = true
			height = opts.GetHeight and opts.GetHeight() or height
			panel.Size = UDim2.fromOffset(panel.Size.X.Offset, math.max(0, height - 10))
			reposition()
			panel.Visible = true
			catcher.Visible = true
			Tween(panel, { BackgroundTransparency = 0, Size = UDim2.fromOffset(panel.Size.X.Offset, height) }, EASE_SMOOTH)
			Tween(panelStroke, { Transparency = 0 }, EASE_SMOOTH)
			if opts.OnOpen then opts.OnOpen() end
		end

		catcher.MouseButton1Click:Connect(close)
		anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if isOpen then reposition() end
		end)
		anchor.Destroying:Connect(function()
			catcher:Destroy()
			panel:Destroy()
		end)

		local unregister = Window.RegisterPopout(close)
		panel.Destroying:Connect(unregister)

		return {
			Panel = panel,
			Open = open,
			Close = close,
			IsOpen = function() return isOpen end,
			Toggle = function() if isOpen then close() else open() end end,
			SetHeight = function(h) height = h end,
			Reposition = reposition,
		}
	end

	------------------------------------------------------------------
	-- Dropdown
	------------------------------------------------------------------
	function holder.Dropdown(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local multi       = (cfg.Multi or cfg.MultiSelect or cfg.MultiSelection) and true or false
		local placeholder = tostring(cfg.Placeholder or (multi and "None selected" or "Select..."))
		local values      = cfg.Values or cfg.Options or cfg.List or {}
		local maxVisible  = tonumber(cfg.MaxVisible) or 6
		local searchable  = cfg.Search and true or false

		local base = BaseRow(parent, {
			Name = "Dropdown", Title = cfg.Title or cfg.Name or "Dropdown",
			Description = cfg.Description, SlotWidth = tonumber(cfg.Width) or 158,
			LayoutOrder = order(),
		})
		Interact(base.Row, Theme.Surface, Theme.Hover, Theme.Active)
		AttachTooltip(base.Row, cfg.Tooltip)

		local control = New("TextButton", {
			BackgroundColor3 = Theme.SurfaceAlt, AutoButtonColor = false, Text = "",
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 26), ZIndex = 8, Parent = base.Slot,
		})
		Corner(5, control)
		local controlStroke = Stroke(control, Theme.LineBright)

		local display = Text({
			Parent = control, ZIndex = 9, Font = FONT, TextSize = 12,
			Text = placeholder, TextColor3 = Theme.Muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -26, 1, 0),
		})
		local arrow = Text({
			Parent = control, ZIndex = 9, Font = FONT_M, TextSize = 11,
			Text = "\u{25BE}", TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
		})

		local api = {
			Instance = base.Row, Type = "Dropdown", Multi = multi,
			Values = values, Value = multi and {} or nil,
			Selected = {},  -- set form: [value] = true
			Callback = cfg.Callback,
		}

		local popout, listFrame, searchBox
		local rowButtons = {}

		local function labelOf(v)
			return tostring(v)
		end

		local function refreshDisplay()
			if multi then
				local picked = {}
				for _, v in ipairs(api.Values) do
					if api.Selected[v] then table.insert(picked, labelOf(v)) end
				end
				if #picked == 0 then
					display.Text = placeholder
					display.TextColor3 = Theme.Muted
				elseif #picked <= 3 then
					display.Text = table.concat(picked, ", ")
					display.TextColor3 = Theme.Text
				else
					display.Text = #picked .. " selected"
					display.TextColor3 = Theme.Text
				end
			else
				if api.Value == nil then
					display.Text = placeholder
					display.TextColor3 = Theme.Muted
				else
					display.Text = labelOf(api.Value)
					display.TextColor3 = Theme.Text
				end
			end
		end

		local function panelHeight()
			local rows = math.min(#api.Values, maxVisible)
			if rows < 1 then rows = 1 end
			return rows * 29 + 8 + (searchable and 34 or 0)
		end

		local function markRow(button, tick, selected)
			Tween(button, { BackgroundColor3 = selected and Theme.Active or Theme.Surface }, EASE_SNAP)
			Tween(tick, { BackgroundTransparency = selected and 0 or 1 }, EASE_SNAP)
		end

		local function refreshRows()
			for _, entry in pairs(rowButtons) do
				markRow(entry.Button, entry.Tick, multi and api.Selected[entry.Value] or api.Value == entry.Value)
				entry.Label.TextColor3 = (multi and api.Selected[entry.Value] or api.Value == entry.Value)
					and Theme.Text or Theme.SubText
			end
		end

		local function choose(value)
			if multi then
				if api.Selected[value] then
					api.Selected[value] = nil
				else
					api.Selected[value] = true
				end
				local out = {}
				for _, v in ipairs(api.Values) do
					if api.Selected[v] then table.insert(out, v) end
				end
				SetFlag(api, out)
			else
				if api.Value == value and cfg.AllowNull then
					api.Selected = {}
					SetFlag(api, nil)
				else
					api.Selected = { [value] = true }
					SetFlag(api, value)
				end
			end
			refreshDisplay()
			refreshRows()
			Fire(api.Callback, api.Value)
			if not multi and popout then popout.Close() end
		end

		local function buildRows(filter)
			for _, entry in pairs(rowButtons) do entry.Button:Destroy() end
			rowButtons = {}

			for i, value in ipairs(api.Values) do
				local text = labelOf(value)
				if filter and filter ~= "" and not string.find(string.lower(text), string.lower(filter), 1, true) then
					continue
				end

				local btn = New("TextButton", {
					Name = text, BackgroundColor3 = Theme.Surface, BackgroundTransparency = 0,
					AutoButtonColor = false, Text = "", Size = UDim2.new(1, 0, 0, 26),
					LayoutOrder = i, ZIndex = 404, Parent = listFrame,
				})
				Corner(5, btn)

				local lbl = Text({
					Parent = btn, ZIndex = 405, Font = FONT, TextSize = 12, Text = text,
					TextColor3 = Theme.SubText, TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -28, 1, 0),
				})
				local tick = New("Frame", {
					BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0,
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
					Size = UDim2.fromOffset(5, 5), ZIndex = 405, Parent = btn,
				})
				Corner(3, tick)
				BindAccent(tick, "BackgroundColor3")

				btn.MouseEnter:Connect(function()
					local selected = multi and api.Selected[value] or api.Value == value
					if not selected then Tween(btn, { BackgroundColor3 = Theme.Hover }, EASE_SNAP) end
					Tween(lbl, { TextColor3 = Theme.Text }, EASE_SNAP)
				end)
				btn.MouseLeave:Connect(function()
					local selected = multi and api.Selected[value] or api.Value == value
					Tween(btn, { BackgroundColor3 = selected and Theme.Active or Theme.Surface }, EASE_SNAP)
					if not selected then Tween(lbl, { TextColor3 = Theme.SubText }, EASE_SNAP) end
				end)
				btn.MouseButton1Click:Connect(function() choose(value) end)

				rowButtons[text] = { Button = btn, Label = lbl, Tick = tick, Value = value }
			end

			refreshRows()
		end

		popout = CreatePopout(control, {
			Width = math.max(158, tonumber(cfg.Width) or 158),
			Height = panelHeight(),
			GetHeight = panelHeight,
			OnOpen = function()
				Tween(arrow, { Rotation = 180, TextColor3 = Theme.Text }, EASE_OUT)
				Tween(controlStroke, { Color = Theme.Accent, Transparency = 0.25 }, EASE_SNAP)
				if searchBox then searchBox.Text = "" end
				buildRows(nil)
			end,
			OnClose = function()
				Tween(arrow, { Rotation = 0, TextColor3 = Theme.Muted }, EASE_OUT)
				Tween(controlStroke, { Color = Theme.LineBright, Transparency = 0 }, EASE_SNAP)
			end,
		})

		Padding(popout.Panel, 4, 4, 4, 4)

		if searchable then
			local searchWrap = New("Frame", {
				BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 26), ZIndex = 403, Parent = popout.Panel,
			})
			Corner(5, searchWrap)
			Stroke(searchWrap, Theme.Line)
			searchBox = New("TextBox", {
				BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = Theme.Text,
				PlaceholderText = "Search", PlaceholderColor3 = Theme.Muted, Text = "",
				TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
				Size = UDim2.fromScale(1, 1), ZIndex = 404, Parent = searchWrap,
			})
			Padding(searchBox, 0, 0, 8, 8)
			searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				buildRows(searchBox.Text)
			end)
		end

		listFrame = New("ScrollingFrame", {
			Name = "Options", BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, searchable and 32 or 0),
			Size = UDim2.new(1, 0, 1, searchable and -32 or 0),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.LineBright,
			ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 403, Parent = popout.Panel,
		})
		List(listFrame, 3)

		control.MouseButton1Click:Connect(popout.Toggle)
		base.Row.MouseButton1Click:Connect(popout.Toggle)

		function api.SetValues(a, newValues)
			local v = newValues
			if a ~= api then v = a end
			api.Values = v or {}
			-- drop selections that no longer exist
			local valid = {}
			for _, value in ipairs(api.Values) do valid[value] = true end
			for value in pairs(api.Selected) do
				if not valid[value] then api.Selected[value] = nil end
			end
			if not multi and api.Value ~= nil and not valid[api.Value] then
				SetFlag(api, nil)
			end
			popout.SetHeight(panelHeight())
			buildRows(searchBox and searchBox.Text or nil)
			refreshDisplay()
		end
		api.Refresh = api.SetValues
		api.SetOptions = api.SetValues

		function api.Set(a, value)
			local v = value
			if a ~= api then v = a end

			if multi then
				api.Selected = {}
				local out = {}
				if typeof(v) == "table" then
					for _, item in ipairs(v) do
						api.Selected[item] = true
					end
					for _, item in ipairs(api.Values) do
						if api.Selected[item] then table.insert(out, item) end
					end
				end
				SetFlag(api, out)
			else
				api.Selected = v ~= nil and { [v] = true } or {}
				SetFlag(api, v)
			end
			refreshDisplay()
			refreshRows()
			Fire(api.Callback, api.Value)
			return api.Value
		end
		function api.Get() return api.Value end
		api.SetValue = api.Set
		api.SetTitle = function(a, t) base.SetTitle(typeof(a) == "string" and a or t) end
		api.SetVisible = function(a, v) base.Row.Visible = (typeof(a) == "boolean" and a or v) and true or false end
		api.Destroy = function()
			if api.Flag then Onyx.Options[api.Flag] = nil end
			popout.Close()
			popout.Panel:Destroy()
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)

		local default = cfg.Default or cfg.Value
		if default ~= nil then
			if multi then
				api.Selected = {}
				local out = {}
				if typeof(default) == "table" then
					for _, item in ipairs(default) do api.Selected[item] = true end
					for _, item in ipairs(api.Values) do
						if api.Selected[item] then table.insert(out, item) end
					end
				end
				SetFlag(api, out)
			else
				api.Selected = { [default] = true }
				SetFlag(api, default)
			end
		elseif multi then
			SetFlag(api, {})
		end

		refreshDisplay()
		buildRows(nil)
		return api
	end
	holder.AddDropdown = holder.Dropdown

	------------------------------------------------------------------
	-- ColorPicker
	------------------------------------------------------------------
	local function ToHex(c)
		return string.format("%02X%02X%02X",
			math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end

	local function FromHex(str)
		str = tostring(str):gsub("#", ""):gsub("%s", "")
		if #str ~= 6 then return nil end
		local r, g, b = tonumber(str:sub(1, 2), 16), tonumber(str:sub(3, 4), 16), tonumber(str:sub(5, 6), 16)
		if not (r and g and b) then return nil end
		return Color3.fromRGB(r, g, b)
	end

	function holder.Colorpicker(p1, p2)
		local cfg = p2
		if p1 ~= holder then cfg = p1 end
		cfg = cfg or {}

		local useAlpha = (cfg.Alpha ~= nil or cfg.Transparency ~= nil) and true or false
		local PANEL_W  = 214
		local INNER    = PANEL_W - 16
		local PANEL_H  = 8 + 106 + 8 + 10 + (useAlpha and 18 or 0) + 8 + 26 + 8

		local base = BaseRow(parent, {
			Name = "Colorpicker", Title = cfg.Title or cfg.Name or "Color",
			Description = cfg.Description, SlotWidth = 44, LayoutOrder = order(),
		})
		Interact(base.Row, Theme.Surface, Theme.Hover, Theme.Active)
		AttachTooltip(base.Row, cfg.Tooltip)

		local swatch = New("TextButton", {
			BackgroundColor3 = cfg.Default or cfg.Value or Color3.fromRGB(255, 255, 255),
			AutoButtonColor = false, Text = "", BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(44, 22), ZIndex = 8, Parent = base.Slot,
		})
		Corner(5, swatch)
		Stroke(swatch, Theme.LineBright, 0.3)

		local api = {
			Instance = base.Row, Type = "Colorpicker",
			Value = cfg.Default or cfg.Value or Color3.fromRGB(255, 255, 255),
			Transparency = tonumber(cfg.Transparency or cfg.Alpha) or 0,
			Callback = cfg.Callback,
		}

		local h, s, v = api.Value:ToHSV()

		local popout = CreatePopout(swatch, { Width = PANEL_W, Height = PANEL_H })
		Padding(popout.Panel, 8, 8, 8, 8)
		List(popout.Panel, 8)

		-- saturation / value field ----------------------------------------
		local field = New("Frame", {
			BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0,
			Size = UDim2.fromOffset(INNER, 106), LayoutOrder = 1, ZIndex = 403, Parent = popout.Panel,
		})
		Corner(5, field)
		New("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 404, Parent = field,
		}, {
			New("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
				}),
			}),
			New("UICorner", { CornerRadius = UDim.new(0, 5) }),
		})
		New("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 405, Parent = field,
		}, {
			New("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(0, 0, 0)),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
				}),
			}),
			New("UICorner", { CornerRadius = UDim.new(0, 5) }),
		})
		local cursor = New("Frame", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(9, 9), ZIndex = 407, Parent = field,
		})
		Corner(5, cursor)
		Stroke(cursor, Color3.new(1, 1, 1), 0, 2)

		-- hue strip ---------------------------------------------------------
		local hueBar = New("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			Size = UDim2.fromOffset(INNER, 10), LayoutOrder = 2, ZIndex = 403, Parent = popout.Panel,
		}, {
			New("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
				}),
			}),
			New("UICorner", { CornerRadius = UDim.new(0, 5) }),
		})
		local hueCursor = New("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(3, 14), ZIndex = 405, Parent = hueBar,
		})
		Corner(2, hueCursor)
		Stroke(hueCursor, Theme.Backdrop, 0.4)

		-- alpha strip -------------------------------------------------------
		local alphaBar, alphaCursor, alphaGradient
		if useAlpha then
			alphaBar = New("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
				Size = UDim2.fromOffset(INNER, 10), LayoutOrder = 3, ZIndex = 403, Parent = popout.Panel,
			})
			Corner(5, alphaBar)
			alphaGradient = New("UIGradient", {
				Color = ColorSequence.new(api.Value),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = alphaBar,
			})
			alphaCursor = New("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(3, 14), ZIndex = 405, Parent = alphaBar,
			})
			Corner(2, alphaCursor)
			Stroke(alphaCursor, Theme.Backdrop, 0.4)
		end

		-- hex row -----------------------------------------------------------
		local hexRow = New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(INNER, 26),
			LayoutOrder = 4, ZIndex = 403, Parent = popout.Panel,
		})
		local preview = New("Frame", {
			BackgroundColor3 = api.Value, BorderSizePixel = 0,
			Size = UDim2.fromOffset(26, 26), ZIndex = 404, Parent = hexRow,
		})
		Corner(5, preview)
		Stroke(preview, Theme.LineBright)

		local hexWrap = New("Frame", {
			BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0,
			Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 0, 26),
			ZIndex = 404, Parent = hexRow,
		})
		Corner(5, hexWrap)
		Stroke(hexWrap, Theme.Line)
		local hexBox = New("TextBox", {
			BackgroundTransparency = 1, Font = FONT_MONO, TextSize = 12,
			TextColor3 = Theme.Text, Text = "#" .. ToHex(api.Value),
			TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
			Size = UDim2.fromScale(1, 1), ZIndex = 405, Parent = hexWrap,
		})
		Padding(hexBox, 0, 0, 8, 8)

		local function render(fire)
			local color = Color3.fromHSV(h, s, v)
			api.Value = color
			if api.Flag then
				Onyx.Flags[api.Flag] = color
				if useAlpha then Onyx.Flags[api.Flag .. "_Transparency"] = api.Transparency end
			end

			field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cursor.Position        = UDim2.fromScale(s, 1 - v)
			hueCursor.Position     = UDim2.fromScale(h, 0.5)
			preview.BackgroundColor3 = color
			swatch.BackgroundColor3  = color
			if not hexBox:IsFocused() then hexBox.Text = "#" .. ToHex(color) end
			if useAlpha then
				alphaGradient.Color = ColorSequence.new(color)
				alphaCursor.Position = UDim2.fromScale(1 - api.Transparency, 0.5)
			end

			if fire then Fire(api.Callback, color, api.Transparency) end
		end

		-- drag handling for the three strips ---------------------------------
		local function bindDrag(gui, onMove)
			local dragging = false
			gui.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch then return end
				dragging = true
				onMove(input.Position)
			end)
			Onyx:Connect(UserInputService.InputChanged, function(input)
				if not dragging then return end
				if input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch then return end
				onMove(input.Position)
			end)
			Onyx:Connect(UserInputService.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
			end)
		end

		bindDrag(field, function(pos)
			local a = field.AbsolutePosition
			local z = field.AbsoluteSize
			s = Clamp((pos.X - a.X) / math.max(1, z.X), 0, 1)
			v = 1 - Clamp((pos.Y - a.Y) / math.max(1, z.Y), 0, 1)
			render(true)
		end)
		bindDrag(hueBar, function(pos)
			local a = hueBar.AbsolutePosition
			local z = hueBar.AbsoluteSize
			h = Clamp((pos.X - a.X) / math.max(1, z.X), 0, 1)
			render(true)
		end)
		if useAlpha then
			bindDrag(alphaBar, function(pos)
				local a = alphaBar.AbsolutePosition
				local z = alphaBar.AbsoluteSize
				api.Transparency = 1 - Clamp((pos.X - a.X) / math.max(1, z.X), 0, 1)
				render(true)
			end)
		end

		hexBox.FocusLost:Connect(function()
			local color = FromHex(hexBox.Text)
			if color then
				h, s, v = color:ToHSV()
				render(true)
			else
				hexBox.Text = "#" .. ToHex(api.Value)
			end
		end)

		swatch.MouseButton1Click:Connect(popout.Toggle)
		base.Row.MouseButton1Click:Connect(popout.Toggle)

		function api.Set(a, color, transparency)
			local c = color
			if a ~= api then c = a; transparency = color end
			if typeof(c) == "string" then c = FromHex(c) end
			if typeof(c) == "Color3" then h, s, v = c:ToHSV() end
			if transparency ~= nil then api.Transparency = Clamp(tonumber(transparency) or 0, 0, 1) end
			render(true)
			return api.Value
		end
		function api.Get() return api.Value, api.Transparency end
		api.SetValue = api.Set
		api.SetTitle = function(a, t) base.SetTitle(typeof(a) == "string" and a or t) end
		api.SetVisible = function(a, val) base.Row.Visible = (typeof(a) == "boolean" and a or val) and true or false end
		api.Destroy = function()
			if api.Flag then Onyx.Options[api.Flag] = nil end
			popout.Close()
			popout.Panel:Destroy()
			base.Row:Destroy()
		end

		RegisterFlag(api, cfg.Flag)
		render(false)
		return api
	end
	holder.AddColorpicker = holder.Colorpicker
	holder.ColorPicker    = holder.Colorpicker
	holder.AddColorPicker = holder.Colorpicker

	return holder
end

-- ================================================================
--  WATERMARK
-- ================================================================

function Onyx.Watermark(a, b)
	local cfg = b
	if a ~= Onyx then cfg = a end
	if typeof(cfg) == "string" then cfg = { Text = cfg } end
	cfg = cfg or {}

	local mark = New("Frame", {
		Name = "Watermark", BackgroundColor3 = Theme.Surface, BorderSizePixel = 0,
		Position = cfg.Position or UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 40, Parent = WindowLayer,
	})
	Corner(6, mark)
	Stroke(mark, Theme.LineBright, 0.35)
	Padding(mark, 0, 0, 10, 10)

	local dot = New("Frame", {
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(5, 5), ZIndex = 41, Parent = mark,
	})
	Corner(3, dot)
	BindAccent(dot, "BackgroundColor3")

	local label = Text({
		Parent = mark, ZIndex = 41, Font = FONT_MONO, TextSize = 11.5,
		Text = tostring(cfg.Text or "Onyx"), TextColor3 = Theme.SubText,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Padding(label, 0, 0, 0, 12)

	local api = { Instance = mark }
	function api.SetText(x, t) label.Text = tostring(typeof(x) == "string" and x or t) end
	function api.SetVisible(x, val) mark.Visible = (typeof(x) == "boolean" and x or val) and true or false end
	function api.Destroy() mark:Destroy() end

	if cfg.ShowFPS then
		local base = tostring(cfg.Text or "Onyx")
		local frames, clock = 0, os.clock()
		Onyx:Connect(RunService.RenderStepped, function()
			frames = frames + 1
			local now = os.clock()
			if now - clock >= 0.5 then
				label.Text = base .. "  \u{2502}  " .. math.floor(frames / (now - clock)) .. " fps"
				frames, clock = 0, now
			end
		end)
	end

	if cfg.Draggable ~= false then Draggable(mark, mark) end
	return api
end

-- ================================================================
--  FLAGS
-- ================================================================

function Onyx.GetFlag(a, b)
	local flag = b
	if a ~= Onyx then flag = a end
	return Onyx.Flags[flag]
end

function Onyx.SetFlag(a, b, c)
	local flag, value = b, c
	if a ~= Onyx then flag, value = a, b end
	local element = Onyx.Options[flag]
	if element and element.Set then
		return element.Set(value)
	end
	Onyx.Flags[flag] = value
	return value
end

-- ================================================================
--  ACCENT
-- ================================================================

function Onyx.SetAccent(a, b)
	local color = b
	if a ~= Onyx then color = a end
	if typeof(color) ~= "Color3" then return end

	Theme.Accent = color
	for i = #Onyx.AccentBound, 1, -1 do
		local pair = Onyx.AccentBound[i]
		local obj, prop = pair[1], pair[2]
		if obj and obj.Parent then
			pcall(function() Tween(obj, { [prop] = color }, EASE_OUT) end)
		else
			table.remove(Onyx.AccentBound, i)
		end
	end
end

-- ================================================================
--  CONFIGURATION (uses executor file IO when available)
-- ================================================================

local HasFileIO = (typeof(writefile) == "function")
	and (typeof(readfile) == "function")
	and (typeof(isfile) == "function")

local function EnsureFolder(path)
	if typeof(isfolder) ~= "function" or typeof(makefolder) ~= "function" then return end
	if not isfolder(path) then makefolder(path) end
end

local function Serialize(value)
	local t = typeof(value)
	if t == "Color3" then
		return { __t = "Color3", R = value.R, G = value.G, B = value.B }
	elseif t == "EnumItem" then
		return { __t = "Enum", Enum = tostring(value.EnumType), Name = value.Name }
	elseif t == "table" then
		local out = {}
		for k, v in pairs(value) do out[k] = Serialize(v) end
		return out
	end
	return value
end

local function Deserialize(value)
	if typeof(value) ~= "table" then return value end
	if value.__t == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	elseif value.__t == "Enum" then
		local ok, item = pcall(function()
			local enumName = value.Enum:gsub("^Enum%.", "")
			return Enum[enumName][value.Name]
		end)
		return ok and item or nil
	end
	local out = {}
	for k, v in pairs(value) do out[k] = Deserialize(v) end
	return out
end

function Onyx.GetConfig()
	local data = {}
	for flag, element in pairs(Onyx.Options) do
		if element.Type == "Colorpicker" then
			data[flag] = Serialize(element.Value)
			data[flag .. "_Transparency"] = element.Transparency
		else
			data[flag] = Serialize(element.Value)
		end
	end
	return data
end

function Onyx.LoadConfigTable(a, b)
	local data = b
	if a ~= Onyx then data = a end
	if typeof(data) ~= "table" then return false, "config is not a table" end

	for flag, raw in pairs(data) do
		local element = Onyx.Options[flag]
		if element and element.Set then
			local value = Deserialize(raw)
			if element.Type == "Colorpicker" then
				element.Set(value, data[flag .. "_Transparency"])
			else
				element.Set(value)
			end
		end
	end
	return true
end

function Onyx.SaveConfig(a, b)
	local name = b
	if a ~= Onyx then name = a end
	name = tostring(name or "default")

	if not HasFileIO then return false, "no file IO in this environment" end

	EnsureFolder(Onyx.Folder)
	EnsureFolder(Onyx.Folder .. "/configs")

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Onyx.GetConfig())
	if not ok then return false, "failed to encode config" end

	local ok2, err = pcall(writefile, Onyx.Folder .. "/configs/" .. name .. ".json", encoded)
	if not ok2 then return false, tostring(err) end
	return true
end

function Onyx.LoadConfig(a, b)
	local name = b
	if a ~= Onyx then name = a end
	name = tostring(name or "default")

	if not HasFileIO then return false, "no file IO in this environment" end

	local path = Onyx.Folder .. "/configs/" .. name .. ".json"
	if not isfile(path) then return false, "config does not exist" end

	local ok, contents = pcall(readfile, path)
	if not ok then return false, "failed to read config" end

	local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, contents)
	if not ok2 then return false, "config is not valid JSON" end

	return Onyx.LoadConfigTable(decoded)
end

function Onyx.DeleteConfig(a, b)
	local name = b
	if a ~= Onyx then name = a end
	name = tostring(name or "default")

	if not HasFileIO or typeof(delfile) ~= "function" then return false, "no file IO in this environment" end
	local path = Onyx.Folder .. "/configs/" .. name .. ".json"
	if not isfile(path) then return false, "config does not exist" end
	local ok, err = pcall(delfile, path)
	return ok, err
end

function Onyx.ListConfigs()
	local out = {}
	if typeof(listfiles) ~= "function" or typeof(isfolder) ~= "function" then return out end
	local dir = Onyx.Folder .. "/configs"
	if not isfolder(dir) then return out end
	local ok, files = pcall(listfiles, dir)
	if not ok then return out end
	for _, file in ipairs(files) do
		local name = tostring(file):match("([^/\\]+)%.json$")
		if name then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

-- ================================================================
--  LIFECYCLE
-- ================================================================

function Onyx.Toggle(a, b)
	local state = b
	if a ~= Onyx then state = a end
	for _, window in ipairs(Onyx.Windows) do
		if state == nil then
			window.Toggle()
		else
			window.SetVisible(state)
		end
	end
end

function Onyx.Unload()
	if Onyx.Unloaded then return end
	Onyx.Unloaded = true

	for _, conn in ipairs(Onyx.Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(Onyx.Connections)
	table.clear(Onyx.Windows)
	table.clear(Onyx.Options)
	table.clear(Onyx.AccentBound)

	if Root then Root:Destroy() end
	if Onyx.OnUnload then pcall(Onyx.OnUnload) end
end
Onyx.Destroy = Onyx.Unload

-- convenience: `Onyx.Flags.MyFlag` stays live, `Onyx:GetOption("MyFlag")` gives the element
function Onyx.GetOption(a, b)
	local flag = b
	if a ~= Onyx then flag = a end
	return Onyx.Options[flag]
end

return Onyx
