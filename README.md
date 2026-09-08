# Onyx UI

A black-theme interface library for Roblox script executors. Single file, no
dependencies, loaded with `loadstring`.

```lua
local Onyx = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/Ui.lua"))()

local Window = Onyx:CreateWindow({ Title = "My Script", SubTitle = "v1.0" })
local Tab    = Window:CreateTab({ Title = "Main" })
local Group  = Tab:CreateSection("Combat")

Group:Toggle({ Title = "Aimbot", Flag = "Aimbot", Callback = print })
```

Run the full feature demo:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/example.lua"))()
```

---

## Design

The theme is deliberately monochrome: a near-black backdrop, hairline borders
instead of heavy panels, and one near-white accent that carries every piece of
state (active tab, filled slider, enabled toggle). Layout is a left rail of
tabs with an accent marker, uppercase section headers with a rule running to
the edge, and a signed-in user card pinned to the bottom of the rail.

Full theming is not implemented yet — the palette lives in one table
(`Onyx.Theme`) and only the accent colour is swappable at runtime, via
`Onyx:SetAccent(color)`.

Every method accepts both call styles, so `Window:CreateTab(...)` and
`Window.CreateTab(...)` both work.

---

## Window

```lua
local Window = Onyx:CreateWindow({
    Title        = "My Script",              -- topbar title
    SubTitle     = "v1.0",                   -- muted text after the title
    Size         = UDim2.fromOffset(640, 440),
    Position     = UDim2.fromScale(0.5, 0.5),
    MinSize      = Vector2.new(480, 320),    -- resize floor
    Keybind      = Enum.KeyCode.RightShift,  -- show/hide the interface
    Accent       = Color3.fromRGB(232, 232, 240),
    RailWidth    = 158,
    Resizable    = true,                     -- bottom-right grip
    ShowUserInfo = true,                     -- avatar + name in the rail
    UnibarIcon   = true,                     -- show/hide button in Roblox's topbar
    MobileButton = "auto",                   -- floating button: auto | true | false
    OnClose      = "hide",                   -- or a function; default asks to unload
})
```

| Method | Description |
| --- | --- |
| `Window:CreateTab(cfg)` | Adds a tab. Also `AddTab`, `Tab`. |
| `Window:SelectTab(indexOrTab)` | Switches tabs. |
| `Window:Toggle()` | Shows/hides the window. |
| `Window:SetVisible(bool)` | Explicit show/hide. |
| `Window:Minimize(bool)` | Collapses to the topbar. |
| `Window:SetToggleKey(keyCode)` | Rebinds the show/hide key. |
| `Window:Dialog(cfg)` | Modal dialog (see below). |
| `Window:Notify(cfg)` | Same as `Onyx:Notify`. |
| `Window:Destroy()` | Removes this window only. |

The topbar has a minimize button and a close button; close opens a confirm
dialog and then unloads the whole library. Pass `OnClose = "hide"` to make it
hide instead, or a function to run your own teardown first. A dialog opened
while the window is minimized or hidden expands it first, since the dialog is
drawn inside the window.

### Showing and hiding

The show/hide control is an icon added to Roblox's own topbar (the unibar),
next to the chat and nine-dot buttons. It is a diamond mark drawn from frames,
so it needs no asset upload and no font coverage, and it dims while the
interface is hidden.

This works by widening the fixed-width frames inside
`CoreGui.TopBarApp.TopBarApp.UnibarLeftFrame` to make room, re-measuring every
two seconds because Roblox adds and resizes its own icons at will. `Onyx:Unload()`
puts those widths back. Where there is no unibar to attach to — Studio, an
older client, a future rewrite — nothing breaks: after a five second grace
period a floating draggable button appears instead, so the interface is never
unreachable. Force one or the other with `MobileButton = true` / `false`, or
turn the topbar icon off with `UnibarIcon = false`. The toggle keybind works
either way.

### Tabs and sections

```lua
local Tab = Window:CreateTab({
    Title    = "Visuals",
    Icon     = "rbxassetid://10723407389",  -- asset id, or a single character
    Default  = true,                         -- select this tab on open
    OnSelect = function() end,
})

local Section = Tab:CreateSection("ESP")
```

`Icon` accepts a numeric asset id, an `rbxassetid://` string, or a single
character drawn as text — note that Roblox's Gotham font has no glyphs for most
geometric shapes, so an asset id is the reliable choice. Elements can be added
to a tab directly or to a section; both expose the same constructors.

---

## Elements

Every constructor takes a config table and returns an element object. All
elements share `:SetTitle(text)`, `:SetVisible(bool)` and `:Destroy()`; value
elements add `:Set(value)` and `:Get()`.

Any element given a `Flag` publishes its value to `Onyx.Flags[flag]` and is
included in saved configs.

### Button

```lua
Section:Button({
    Title       = "Kill All",
    Description = "Removes every NPC.",
    Tooltip     = "Shown on hover",
    Confirm     = true,             -- ask before running
    Callback    = function() end,
})
```

### Toggle

```lua
local toggle = Section:Toggle({
    Title    = "Aimbot",
    Default  = false,
    Flag     = "Aimbot",
    Callback = function(state) end,
})

toggle:Set(true)
toggle:Toggle()
print(toggle:Get())
```

### Slider

```lua
local slider = Section:Slider({
    Title     = "Field of View",
    Min       = 0,
    Max       = 360,
    Default   = 120,
    Increment = 5,        -- step; fractional steps auto-enable decimals
    Rounding  = 0,        -- decimal places (optional override)
    Suffix    = "\u{00B0}",
    Flag      = "AimFOV",
    Callback  = function(value) end,
})

slider:SetRange(0, 100)
```

Values are clamped to the range and snapped to `Increment`.

### Dropdown

```lua
local dropdown = Section:Dropdown({
    Title      = "Hit Part",
    Values     = { "Head", "Torso", "Legs" },
    Default    = "Head",
    Search     = true,      -- adds a filter box
    MaxVisible = 6,         -- rows before the list scrolls
    AllowNull  = false,     -- clicking the selection clears it
    Flag       = "HitPart",
    Callback   = function(value) end,
})

dropdown:SetValues({ "Head", "Torso" })   -- also :Refresh / :SetOptions
```

Multi-select stores an array and keeps it in the order of `Values`:

```lua
local multi = Section:Dropdown({
    Title   = "Elements",
    Multi   = true,
    Values  = { "Box", "Name", "Health" },
    Default = { "Box", "Name" },
    Flag    = "EspElements",
})

for _, item in ipairs(multi:Get()) do print(item) end
```

Selections that no longer exist after `SetValues` are dropped automatically.

### Input

```lua
Section:Input({
    Title       = "Webhook",
    Placeholder = "https://",
    Default     = "",
    Width       = 148,
    Numeric     = false,   -- coerce to a number on focus loss
    Live        = false,   -- fire on every keystroke
    OnEnter     = false,   -- only fire when Enter is pressed
    Flag        = "Webhook",
    Callback    = function(text, enterPressed) end,
})
```

### Keybind

```lua
Section:Keybind({
    Title           = "Aim Key",
    Default         = Enum.KeyCode.E,
    Mode            = "Toggle",  -- "Toggle" | "Hold" | "Always"
    Flag            = "AimKey",
    Callback        = function(active) end,   -- fired when the bind is pressed
    ChangedCallback = function(key) end,      -- fired when the bind is rebound
})
```

Click the row to start listening. Escape or Backspace clears the bind. Mouse
buttons 2 and 3 can be bound as well.

### Colorpicker

```lua
local picker = Section:Colorpicker({
    Title        = "Box Colour",
    Default      = Color3.fromRGB(235, 235, 245),
    Transparency = 0,     -- include this key to show an alpha strip
    Flag         = "EspBox",
    Callback     = function(color, transparency) end,
})

picker:Set(Color3.fromRGB(255, 0, 0))
picker:Set("#FF0000")               -- hex also accepted
local color, alpha = picker:Get()
```

With alpha enabled the transparency is stored under `Flag .. "_Transparency"`.

### Console

A scrolling log pane with levelled output, a ring buffer, and copy/clear
actions in its header.

```lua
local console = Section:Console({
    Title       = "Output",
    Height      = 148,          -- pixel height of the log area
    MaxLines    = 200,          -- oldest lines are dropped past this
    Timestamps  = true,
    AutoScroll  = true,
    Placeholder = "No output yet.",
    Copy        = true,         -- COPY action in the header
    Clear       = true,         -- CLEAR action in the header
    Lines       = { "ready" },  -- seed content
})

console:Log("connected to", server.Name)   -- arguments join like print
console:Info("scanning")
console:Success("done")
console:Warn("rate limited")
console:Error("request failed")

console:Clear()
console:GetText()          -- every surviving line, newline separated
console:Copy()             -- uses setclipboard; false if unavailable
console:SetHeight(220)
console:SetAutoScroll(false)
```

Auto-scroll sticks to the newest line only while you are already at the
bottom, so scrolling up to read something is not yanked back by the next line.

### Text, static or live

```lua
Section:Label("Plain text")
Section:Paragraph({ Title = "Heads up", Content = "Wraps across lines." })
Section:Divider()          -- hairline
Section:Divider("or")      -- hairline with a centred caption
```

Both take a function instead of a string for text that keeps itself current.
It is polled on an interval (0.1s by default) and only written when the value
actually changes, so a live label costs close to nothing:

```lua
Section:Label({ Title = function() return "Ping: " .. ping .. "ms" end })

Section:Paragraph({
    Title    = "Session",
    Content  = function() return #targets .. " targets tracked" end,
    Interval = 0.25,
})
```

Either can be swapped at runtime, in both directions:

```lua
local label = Section:Label("Idle")

label:SetText("Running")                          -- back to a fixed string
label:SetText(function() return os.date("%X") end)  -- or bind to a value
label:Bind(function() return tostring(count) end, 0.5)
label:Unbind()
label:SetColor(Color3.fromRGB(240, 120, 120))
```

Paragraphs bind each half separately with `:BindTitle(fn)` and
`:BindContent(fn)`; `:SetTitle` / `:SetContent` accept a string or a function
and rebind accordingly. Binding stops when the element is destroyed.

---

## Notifications

```lua
Onyx:Notify({
    Title    = "Config saved",
    Content  = "default.json",
    Duration = 4,            -- 0 keeps it until clicked
    Type     = "success",    -- default | info | success | warning | error
})

Onyx:Notify("Short form")
```

Each toast carries a status badge with a drawn mark (a check, an alert, an
info bar, or the Onyx diamond for the default type) tinted to match the type,
a countdown underline, and dismisses on click. Hovering pauses the countdown.
The call returns `{ Close = function }`.

Move the stack with:

```lua
Onyx:SetNotificationCorner("top-right")
-- bottom-right (default) | bottom-left | bottom-center
-- top-right | top-left | top-center
```

## Dialogs

```lua
Window:Dialog({
    Title       = "Unload interface",
    Content     = "This removes every element the script created.",
    Dismissable = true,     -- clicking the backdrop closes it
    Buttons = {
        { Title = "Cancel" },
        { Title = "Unload", Primary = true, Callback = function() Onyx:Unload() end },
    },
})
```

## Watermark

```lua
local mark = Onyx:Watermark({ Text = "Onyx", ShowFPS = true, Draggable = true })
mark:SetText("Onyx | lobby")
mark:SetPosition(UDim2.fromOffset(20, 90))
```

It spawns below Roblox's own topbar rather than behind it, tracking
`GuiService.TopbarInset` so it stays clear when the unibar resizes. Dragging
it, passing an explicit `Position`, or calling `:SetPosition` pins it — after
that it stops following the inset.

---

## Flags and configuration

```lua
Onyx.Flags.Aimbot            -- live value of any flagged element
Onyx:GetFlag("Aimbot")
Onyx:SetFlag("Aimbot", true) -- drives the element, fires its callback
Onyx:GetOption("Aimbot")     -- the element object itself
```

Configs are JSON files under `Onyx.Folder` (default `OnyxUI/configs`) and need
executor file IO (`writefile` / `readfile` / `isfile`).

```lua
Onyx:SaveConfig("default")   -- returns ok, err
Onyx:LoadConfig("default")
Onyx:DeleteConfig("default")
Onyx:ListConfigs()           -- array of names

Onyx:GetConfig()             -- serialisable table, no file IO needed
Onyx:LoadConfigTable(tbl)
```

`Color3` and `EnumItem` values (colours, keybinds) survive the round trip.

## Interaction focus

One element owns the pointer at a time. While a slider is being dragged or a
popout is open, `Onyx.Focus` holds that element and everything else paints
itself idle and refuses input — so a second slider cannot be grabbed mid-drag,
and the row behind an open dropdown stops glowing. (Roblox does not fire
`MouseLeave` when another GUI covers an object, so without this the row under
a popout stays lit.) Focus is released on mouse-up, on close, and on unload.

## Lifecycle

```lua
Onyx:SetAccent(Color3.fromRGB(120, 90, 255))
Onyx:Toggle()          -- every window
Onyx:Toggle(false)     -- force hidden
Onyx.OnUnload = function() print("cleaning up") end
Onyx:Unload()          -- destroys the GUI and disconnects every connection
```

`Onyx:Unload()` disconnects every connection the library made, so your own
loops should check `Onyx.Unloaded` if they run past teardown.

---

## Environment notes

The library parents its `ScreenGui` to `gethui()` when available, then
`CoreGui`, then `PlayerGui`, and calls `syn.protect_gui` if the executor
exposes it. `cloneref` is used for service references when present. None of
these are required — it degrades to `PlayerGui` in a plain LocalScript.

## Repository layout

| File | Purpose |
| --- | --- |
| `Ui.lua` | The library. This is the file you `loadstring`. |
| `example.lua` | Feature demo covering every element. |
| `tests/` | Mock Roblox environment and the test suite. |

## Development

`tests/run.sh` executes the library against a mock Roblox API (instances,
signals, tweens, enums, `task`, and in-memory executor file IO) and asserts on
element behaviour, popouts, keybind rebinding, tab switching, config round
trips and teardown. It needs the `luau` CLI and downloads one into
`tests/.bin` if there is not one on `PATH`.

```sh
tests/run.sh
```
