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
    Settings     = true,                     -- settings icon + page in the topbar
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
| `Window:ToggleSettings()` | Opens/closes the settings page. Also `OpenSettings`, `CloseSettings`. |
| `Window:SettingsSection(title)` | Adds your own section to the settings page. |
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

-- option-heavy tabs can fold sections away
local Advanced = Tab:CreateSection({
    Title       = "Advanced",
    Collapsible = true,
    Collapsed   = false,       -- start folded
    OnCollapse  = function(folded) end,
})

Advanced:SetCollapsed(true)
Advanced:Toggle()
```

`Icon` accepts a numeric asset id, an `rbxassetid://` string, or a single
character drawn as text — note that Roblox's Gotham font has no glyphs for most
geometric shapes, so an asset id is the reliable choice. Elements can be added
to a tab directly or to a section; both expose the same constructors.

### Settings

The topbar carries a settings icon (drawn, like the rest) that slides open a
settings page over the window. It is a page rather than a tab so it stays out
of your script's own navigation, and it ships with:

- **Configuration** — config name, saved-config list, and save / load / delete /
  refresh as mini buttons, plus **Auto save** and **Auto load** toggles.
- **Interface** — accent colour, the show/hide keybind, notification corner.
- **Session** — unload, behind a confirmation.

Add your own with `Window:SettingsSection(title)`, which returns a section with
the full element API:

```lua
local Script = Window:SettingsSection("Script")
Script:Toggle({ Title = "Verbose log", Mini = true })
Script:Button({ Title = "Rejoin", Mini = true })
```

Pass `Settings = false` to `CreateWindow` to drop the icon and page entirely.

Interface preferences live in `OnyxUI/settings.json`, separate from configs on
purpose: a config is your script's state, these are the interface's. **Auto
save** writes the named config whenever a flagged value changes, debounced so
dragging a slider writes once. **Auto load** restores that config the next time
the script runs.

```lua
Onyx.Settings          -- { AutoSave, AutoLoad, Config, NotificationCorner, Accent }
Onyx:SaveSettings()
Onyx:ApplyAutoLoad()   -- normally automatic; call it yourself if you build async
```

Auto-load cannot run inside `CreateWindow` — the elements it restores do not
exist yet — so it is deferred until the calling script has finished building
the interface. If your script creates elements asynchronously (after a `wait`,
inside a coroutine), call `Onyx:ApplyAutoLoad()` yourself once they exist.

---

## Elements

Every constructor takes a config table and returns an element object. All
elements share `:SetTitle(text)`, `:SetVisible(bool)` and `:Destroy()`; value
elements add `:Set(value)` and `:Get()`.

Any element given a `Flag` publishes its value to `Onyx.Flags[flag]` and is
included in saved configs.

### Half-width elements

`Mini = true` makes an element take half a row, so two sit side by side:

```lua
Section:Toggle({ Title = "Visible only", Mini = true })
Section:Toggle({ Title = "Walls",        Mini = true })

Section:Button({ Title = "Freeze",  Mini = true })
Section:Button({ Title = "Release", Mini = true })
```

They pair up in creation order, two to a row, and the pair can mix types — a
mini button next to a mini toggle is fine. **Button, Toggle, Keybind and
Colorpicker** can be mini. Everything else — Slider, RangeSlider, Segmented,
Dropdown, Input, Textarea, Tags, Table, PlayerList, Stats, Progress, Graph,
Console, Terminal, Paragraph, Label and Divider — needs the full width and
ignores `Mini`.

Anything full width closes the open pair, so a slider between two minis keeps
them on separate rows. `Section:Break()` abandons a half-filled row on demand
if you want the next mini to start fresh.

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

### Terminal

A command line, not a log. Only what a command produced shows up: the line you
ran, then its result or its error. Ordinary chatter belongs in a Console, which
is why this deliberately has no `Log` / `Info` / `Warn`.

```lua
local term = Section:Terminal({
    Title  = "Console",
    Height = 150,
    Prefix = ">",
})

term:Register("speed", {
    Description = "set walk speed",
    Usage       = "speed <n>",
    Callback    = function(args, raw)
        local value = tonumber(args[1])
        if not value then return false, "speed needs a number" end
        humanoid.WalkSpeed = value
        return "walk speed is now " .. value
    end,
})
```

What a command callback returns decides what is shown:

| Return | Shown |
| --- | --- |
| a string | that string, as the outcome |
| `true` | `ok` |
| `false, "reason"` | `reason`, as an error |
| `nil` | nothing beyond the echoed command |
| it errors | the error, caught and shown in red |

`help` and `clear` are built in unless you register your own. Up and down
recall history. Unknown commands error unless you pass an `Unknown` handler.

```lua
term:Run("speed 50")     -- run one programmatically
term:Result("done")      -- push an outcome by hand
term:Error("failed")
term:Unregister("speed")
term:Clear()
term:GetText()
```

### Segmented

A visible one-of-N choice, for a mode you want readable at a glance rather
than one click away in a dropdown.

```lua
Section:Segmented({
    Title    = "Mode",
    Values   = { "Legit", "Semi", "Rage" },
    Default  = "Legit",        -- by value, or an index
    Flag     = "AimMode",
    Callback = function(value, index) end,
})
```

`:Set(value)` takes a value or an index; `:Get()` returns both.

### RangeSlider

Two handles on one track, for a span rather than a point. Whichever handle is
nearer the press takes the drag, and a reversed pair is corrected.

```lua
local range = Section:RangeSlider({
    Title      = "Target distance",
    Min        = 0,
    Max        = 1000,
    DefaultMin = 50,
    DefaultMax = 600,
    Increment  = 10,
    Suffix     = "m",
    Flag       = "TargetRange",   -- stored as { low, high }
    Callback   = function(low, high) end,
})

range:Set(100, 400)
local low, high = range:Get()
```

### Textarea

Multi-line input, for a webhook body, a list of names, or a snippet. `Input`
stays single-line.

```lua
local area = Section:Textarea({
    Title       = "Webhook body",
    Height      = 110,
    Placeholder = "one entry per line",
    Monospace   = true,
    Live        = false,        -- fire on every keystroke
    Flag        = "WebhookBody",
})

area:GetLines()     -- split on newlines, blanks dropped
area:SetHeight(160)
```

### Tags

Add and remove arbitrary strings as chips — a blacklist, a keyword filter.
A multi-select Dropdown only picks from a fixed list; this accepts anything
typed.

```lua
local tags = Section:Tags({
    Title       = "Ignore names",
    Placeholder = "add and press enter",
    Default     = { "friend1" },
    Max         = 64,
    Flag        = "IgnoreNames",   -- stored as an array
    Callback    = function(list) end,
})

tags:Add("someone")     -- false if duplicate, blank, or over Max
tags:Remove("friend1")
tags:Has("someone")
tags:Set({ "a", "b" })
tags:Clear()
```

Chips wrap by hand from their measured widths: `UIListLayout` only gained
wrapping recently and not every client running this has it.

### Table

A scrolling list built from a data array, with optional columns, per-row
action buttons and selection.

```lua
local drops = Section:Table({
    Title    = "Recent drops",
    Columns  = { { Title = "Item", Width = 0.5 }, "Rarity", "Value" },
    Height   = 160,
    RowHeight = 28,
    MaxRows  = 500,
    Empty    = "No drops yet.",
    Actions  = { { Title = "Sell", Width = 46, Callback = function(row) end } },
    OnSelect = function(row, index) end,
})

drops:SetRows({
    { "Blade of Dawn", "Legendary", "12,400" },
    { "Iron Shield",   "Common",    "80" },
})

local handle = drops:AddRow({ "Void Shard", "Rare", "3,150" })
handle.Update({ "Void Shard", "Rare", "3,400" })
handle.Remove()

drops:Select(1)
drops:GetSelected()     -- row data, index
drops:Clear()
```

A column with an explicit `Width` (0–1) keeps that share; the rest split what
is left. Rows can also be `{ Cells = {...}, Actions = {...}, Color = ... }` to
override per row.

### PlayerList

The server's players, kept current through `PlayerAdded` and `PlayerRemoving`,
with avatars, team colours and per-row actions.

```lua
local players = Section:PlayerList({
    Title       = "Players",
    Height      = 190,
    Avatars     = true,
    IgnoreLocal = false,
    Filter      = function(player) return true end,
    Actions = {
        { Title = "TP",    Callback = function(player) end },
        { Title = "Watch", Callback = function(player) end },
    },
    OnSelect = function(player) end,
})

players:Refresh()
players:GetSelected()
```

A selection whose player has left the server clears itself.

### Stats

A row of KPI tiles. Values may be strings or functions; a function is polled
like a live label, so a session counter needs no loop of its own.

```lua
Section:Stats({
    Columns = 3,
    Items = {
        { Label = "Kills",  Value = function() return kills end },
        { Label = "Coins",  Value = "120" },
        { Label = "Uptime", Value = uptimeFn, Interval = 1 },
    },
})

stats:Set("Coins", "500")    -- by label or index
```

### Progress

```lua
local bar = Section:Progress({
    Title     = "Farm cycle",
    Max       = 100,
    Value     = 0,
    ShowValue = true,
    Format    = function(value, max) return value .. "/" .. max end,
})

bar:Set(40)
bar:SetMax(200)
bar:SetIndeterminate(true)   -- shuttles until you Set a value again
```

### Graph

A sparkline drawn as columns rather than line segments, so it stays readable
at any width without rotated geometry.

```lua
local fps = Section:Graph({
    Title    = "Frames per second",
    Height   = 80,
    Points   = 48,          -- samples kept
    Max      = "auto",      -- or a fixed ceiling
    Suffix   = " fps",
    Source   = function() return currentFps end,
    Interval = 0.5,
})

fps:Push(60)
fps:SetValues({ 30, 45, 60 })
fps:Bind(function() return currentFps end, 0.25)
fps:Unbind()
fps:Clear()
```

With `Max = "auto"` the ceiling tracks the tallest sample in the window.

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

## Loading overlay

Covers the window body while a script is still getting ready. Unlike a toast it
holds the pointer, so nothing half-initialised can be clicked.

```lua
local loader = Window:Loading({
    Title   = "Onyx",
    Content = "Connecting to the server",
    Timeout = 30,        -- auto-close, optional
})

loader:SetStatus("loading configs")
loader:SetProgress(0.4)   -- a number switches the bar from shuttling to measuring
loader:Close()
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
