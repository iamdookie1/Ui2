# Void

A monochrome interface library for Roblox script executors. Single file, no
dependencies, loaded with `loadstring`.

```lua
local Void = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/VoidUI.lua"))()

local Window = Void:CreateWindow({ Title = "My Script", SubTitle = "v1.0" })
local Tab    = Window:CreateTab("Main")
local Group  = Tab:CreateSection("Combat")

Group:Toggle({ Title = "Aimbot", Flag = "Aimbot", Callback = print })
```

Run the demo:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/VoidUI-example.lua"))()
```

Void covers the same ground as [Onyx](README.md) — a floating window, a rail
of tabs, sections, the whole element set, notifications, configs — and shares
no code with it. Load either.

---

## Design

Black, four greys, and one white accent that marks every piece of state there
is: the selected tab, a lit toggle, a filled slider, a focused field, a picked
option. Nothing else is ever coloured.

- **Corners are 3px**, which is to say almost square. Borders are hairlines.
- **Values are set in mono** — sliders, inputs, stats, console lines, the
  keybind hint — so a column of numbers lines up and reads as data rather than
  as prose.
- **Tabs live in a rail** down the left, marked by a 2px bar that slides
  between them.
- **A status strip** across the bottom carries a message on the left and the
  toggle key on the right.
- **Dropdowns and pickers open as popouts** in a layer above the window, so
  opening one never pushes the rest of the page around.

Every method accepts both call styles, so `Window:CreateTab(...)` and
`Window.CreateTab(...)` both work.

### The accent

White by default. Change it and everything bound to it follows, live:

```lua
Void:SetAccent(Color3.fromRGB(0, 255, 120))
Void.Ink.Edge      -- the accent
Void.Ink.OnEdge    -- text that sits on it, picked for contrast automatically
```

The rest of the palette is fixed and reads `Void`, `Panel`, `Card`, `Lift`,
`Line`, `Text`, `Sub`, `Mute`, `Warn` on `Void.Ink`.

---

## Window

```lua
local Window = Void:CreateWindow({
    Title        = "My Script",
    SubTitle     = "v1.0",
    Size         = UDim2.fromOffset(560, 400),
    RailWidth    = 120,
    Keybind      = Enum.KeyCode.RightShift,
    Status       = "idle",
    Scope        = "game",        -- or "universal", for configs
    StartOpen    = true,
    MobileButton = true,
    Watermark    = true,
})
```

| Method | Does |
| --- | --- |
| `Window:CreateTab(title \| cfg)` | adds a tab, returns it |
| `Window:SetOpen(bool)` / `Window:Toggle()` | show and hide |
| `Window:Fold(bool)` | collapse to the title bar, or back |
| `Window:SetTitle(text)` | rename it |
| `Window:SetStatus(text)` | write to the status strip |
| `Window:SetToggleKey(keycode)` | rebind; the strip follows |
| `Window:Notify(cfg)` | same as `Void:Notify` |
| `Window:Destroy()` | remove this window only |

Drag the title bar to move it. The dash folds it, the cross hides it. On a
phone the fob in the top left toggles it, since there is no Right Shift.

`Window.Open`, `Window.Minimised`, `Window.Tabs`, `Window.ActiveTab`,
`Window.Frame` and `Window.Watermark` are readable.

---

## Tabs and sections

```lua
local Tab   = Window:CreateTab("Main")
local Group = Tab:CreateSection("Combat")
local Fold  = Tab:CreateSection({ Title = "Advanced", Collapsible = true, Open = false })

Tab:Select()
Fold:Expand()      -- and Fold:Collapse(), Fold:SetOpen(bool)
Group:Destroy()
```

Elements live on a section (`Group:Toggle{...}`) or straight on the tab
(`Tab:Toggle{...}`) if you do not want a heading.

**A section's own methods are `Expand`, `Collapse` and `SetOpen`, not
`Toggle`** — every section also carries the element constructors, so
`Group:Toggle{...}` builds a toggle. The library errors on load if those two
ever collide again.

---

## Elements

Every constructor takes a config table and returns a handle with `Instance`,
`Type`, `Value`, `Set`, `Get`, `SetTitle`, `Destroy`, and a `Flag` if you gave
one.

Pass **`Half = true`** to any of them and two will share a line.

### Text

```lua
Group:Label("A plain line")
Group:Paragraph({ Title = "Heads up", Content = "Wraps across lines." })
Group:Divider()
Group:Divider("or")          -- a captioned rule
```

`Label:SetText`, `Paragraph:SetTitle`, `Paragraph:SetContent`.

### Button

```lua
Group:Button({
    Title       = "Kill all",
    Description = "Removes every NPC",
    Callback    = function() end,
})

Group:Button({
    Title       = "Reset",
    Confirm     = true,                  -- routes through a dialog first
    ConfirmText = "This cannot be undone.",
    Callback    = function() end,
})
```

### Toggle

```lua
local t = Group:Toggle({ Title = "Aimbot", Default = false, Flag = "Aimbot",
    Callback = function(on) end })
t:Set(true)
```

Clicking anywhere on the row flips it.

### Slider

```lua
local s = Group:Slider({
    Title = "FOV", Min = 20, Max = 400, Default = 120,
    Increment = 5, Suffix = "px", Rounding = 0, Flag = "Fov",
    Callback = function(value) end,
})
```

Clamps to `Min`/`Max`, snaps to `Increment`. The grip glows while you drag it.

### Dropdown

```lua
local d = Group:Dropdown({
    Title = "Target part", Values = { "Head", "Torso" }, Default = "Head",
    Placeholder = "none", Flag = "Part", Callback = function(value) end,
})
d:SetValues({ "A", "B" })
d:SetOpen(true)
```

Opens as a popout above the window. Pass `Multi = true` and it holds a list:

```lua
local m = Group:Dropdown({ Title = "Ignore", Values = { "Friends", "Team" },
    Multi = true, Callback = function(list, value, added) end })
m:Select("Team")             -- flips one value
m:Set({ "Team" })            -- replaces the selection
```

### Segmented

One row, one pick, no popout — better than a dropdown when there are three of
something.

```lua
Group:Segmented({ Title = "Smoothing", Values = { "Off", "Soft", "Hard" },
    Default = "Soft", Flag = "Smooth" })
```

### Input and Textarea

```lua
Group:Input({ Title = "Nickname", Placeholder = "type here", Flag = "Name",
    Callback = function(text, enter) end })

local t = Group:Textarea({ Title = "Targets", Height = 78, Flag = "Targets" })
t.Lines()       -- { "alice", "bob" }
```

The field's caret blinks while it has focus.

### Keybind

```lua
Group:Keybind({
    Title = "Panic key", Default = Enum.KeyCode.P, Flag = "Panic",
    Callback        = function(key) end,   -- when the key is pressed
    ChangedCallback = function(key) end,   -- when it is rebound
})
```

Click the chip, press a key. Escape clears it. Inputs the game has already
handled are ignored, so typing in chat will not trigger it.

### ColorPicker

```lua
Group:ColorPicker({ Title = "Tracer", Default = Color3.fromRGB(255, 255, 255),
    Flag = "Tracer", Callback = function(colour) end })
```

Hue, saturation and value as three bars in a popout.

### Progress, Console, Stat

```lua
local p = Group:Progress({ Title = "Scan", Default = 0 })
p:Set(0.5)                                  -- 0..1, or pass Max = 50

local log = Group:Console({ Title = "Output", Height = 104, MaxLines = 90 })
log:Append("scan started")
log:Good("finished")
log:Bad("no target")                        -- in the warning colour
log:Clear()

local ping = Group:Stat({ Title = "Ping", Value = "-" })
ping:Set("42ms")
```

---

## Notifications

```lua
Void:Notify({ Title = "Done", Content = "Everything worked.", Duration = 4 })
Void:Notify({ Title = "Broken", Warn = true })
Void:Notify("short form")
```

Fixed heights — 40 for a title, 60 with a body — stacked bottom right, capped
at four (`Void.MaxToasts`). Each carries a white bar down its left edge and a
hairline underneath that empties as it ages. A warning toast wears the warning
colour instead.

## Dialogs

```lua
Void:Dialog({
    Title = "Delete this config?",
    Content = "It will not come back.",
    Confirm = "Delete",
    Callback = function() end,
})
```

Or pass your own `Buttons = { { Title = ..., Callback = ..., Primary = true } }`.

---

## Flags and configs

Any element with a `Flag` writes into `Void.Flags` and registers in
`Void.Options`.

```lua
Void:GetFlag("Fov")
Void:SetFlag("Fov", 200)       -- updates the element on screen too
```

Configs go to the executor's filesystem as JSON:

```lua
Void:SaveConfig("main")        -- returns ok, reason
Void:LoadConfig("main")
Void:ListConfigs()             -- { "main", ... }
Void:DeleteConfig("main")
Void.CanSave                   -- false if the executor has no file IO
```

Configs are filed **per game** — under `Void/<PlaceId>/` — because a walkspeed
that suits one game is nonsense in another. Pass `Scope = "universal"` on the
window to share one set everywhere instead. Colours and keybinds survive the
round trip; both are tagged on the way out and rebuilt on the way back.

---

## Lifecycle

```lua
Void:Unload()       -- destroys the interface and disconnects everything
Void.Unloaded
Window:Destroy()    -- one window, leaving the library alive
```

`Void:Connect(signal, fn)` registers a connection for `Unload` to clean up.

---

## Environment notes

- Parents to `gethui()` when the executor has it, then `CoreGui`, then
  `PlayerGui`.
- Uses `cloneref` for service handles when available.
- Falls back across fonts, so it renders where Gotham or Code are unavailable.
- Every mark is drawn from frames — the ring in the title bar, the carets, the
  cross, the dash. No glyph coverage to depend on, no image assets to fail to
  load.

---

## One layout rule

Roblox sizes an `AutomaticSize` parent from its children's **offsets** and
ignores their scales. Two ways to break that, both of which have shipped in
this repository before: a child sized from the container a list is sizing, and
a big offset-sized child inside a parent that measures it.

So effects here are either scale-sized, a `UIStroke`, or inside something with
a fixed height. The suite walks the whole tree and fails on either shape.

---

## Repository layout

| Path | What |
| --- | --- |
| `VoidUI.lua` | the library |
| `VoidUI-example.lua` | feature demo |
| `VoidUI.md` | this file |
| `tests/void-spec.lua` | behaviour suite |
| `tests/void.sh` | runs it against the mock |

```sh
./tests/void.sh
./tests/lint.sh VoidUI.lua VoidUI-example.lua
```
