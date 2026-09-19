# LoveUI

A pink sidebar interface library for Roblox script executors. Single file, no
dependencies, loaded with `loadstring`.

```lua
local Love = loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/LoveUI.lua"))()

local Window = Love:CreateWindow({ Title = "My Script", SubTitle = "v1.0", Theme = "Rose" })
local Tab    = Window:CreateTab("Main")
local Group  = Tab:CreateSection("Combat")

Group:Toggle({ Title = "Aimbot", Flag = "Aimbot", Callback = print })
```

Run the demo:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/iamdookie1/Ui2/main/LoveUI-example.lua"))()
```

LoveUI is separate from [Onyx](README.md) — a different library in the same
repository, not a theme for it. Load whichever you want; they do not share code
or state.

---

## Design

It is a sidebar, not a floating panel. The window lives off the left edge of
the screen and slides in, so it never sits over the middle of the game. There
is no topbar icon and no draggable frame: a translucent pink handle rides the
panel's right edge, moving with it, so the same handle opens it and closes it.

- **Drag the handle right** to open, **left** to close. Past the threshold it
  commits; short of it, it snaps back.
- **Keep dragging right** once it is open and the panel **widens**. It grows
  sideways, never taller, so it never becomes a column down the middle of the
  screen. Drag back left to narrow it, then further to close it.
- **Tap the handle** to toggle without dragging.
- **Press the keybind** (Right Shift by default).

Edge access is the only access method. That is deliberate — the handle is
always in the same place, it cannot be covered by a game's own topbar, and it
works the same on PC and on mobile.

Every method accepts both call styles, so `Window:CreateTab(...)` and
`Window.CreateTab(...)` both work.

### Getting the current build

`game:HttpGet` results are cached by executors and by GitHub's CDN, so a fresh
push can take a while to reach you:

```lua
-- always fetch the newest main
local url = "https://raw.githubusercontent.com/iamdookie1/Ui2/main/LoveUI.lua?v=" .. tostring(tick())
local Love = loadstring(game:HttpGet(url))()
```

`print(Love.Version)` tells you which build you actually loaded.

---

## Themes

Six palettes, all of them pink somewhere — that is the whole premise of the
library. They differ in how loud the pink is and what it sits on.

| Name | Look |
| --- | --- |
| `Rose` | dark neutral, muted rose accent (default) |
| `Bubblegum` | dark violet-black, neon pink |
| `Wine` | deep maroon panels, warm pink |
| `Midnight` | near-black, hot magenta |
| `Blush` | light, dusty rose on off-white |
| `Sakura` | light, soft petal pink |

```lua
Love:SetTheme("Midnight")   -- switch
Love:NextTheme()            -- cycle to the next one, returns its name
Love.ThemeName              -- current name
Love.ThemeOrder             -- { "Rose", "Bubblegum", ... }
Love.Themes.Rose.Accent     -- read any colour
```

Switching repaints everything that is already on screen — the library records
every painted property against the theme token it came from, so live elements
change with it.

### Pickers stay in step

The swatch in the window header opens a list of every palette, with the
current one highlighted. A `ThemeDropdown` on a page does the same job.

Changing the theme **any** way — the header swatch, a `ThemeDropdown`,
`Love:SetTheme`, `Love:NextTheme` — moves every other picker with it. No
picker can sit there naming a palette you are no longer using.

```lua
Group:ThemeDropdown({ Title = "Theme" })    -- a dropdown wired to the library
```

Each palette defines: `Bg`, `Panel`, `Card`, `Hover`, `Line`, `Text`, `Sub`,
`Muted`, `Accent`, `OnAccent`, `Error`.

---

## Window

```lua
local Window = Love:CreateWindow({
    Title        = "My Script",
    SubTitle     = "v1.0",
    Theme        = "Rose",
    Background   = "hearts",                  -- hearts · glow · plain
    Width        = 300,                       -- how far it slides in
    MaxWidth     = 620,                       -- how far it can be widened
    Height       = 0.74,                      -- fraction of the screen
    HandleWidth  = 8,
    HandleHeight = 132,
    Threshold    = 60,                        -- drag distance that commits
    Keybind      = Enum.KeyCode.RightShift,
    StartOpen    = false,
})
```

| Method | Does |
| --- | --- |
| `Window:CreateTab(title \| cfg)` | adds a tab, returns it |
| `Window:SetOpen(bool)` | slide in or out |
| `Window:Toggle()` | flip it |
| `Window:SetTitle(text)` | rename the header |
| `Window:SetWidth(n)` | widen or narrow, clamped to Width…MaxWidth |
| `Window:Expand()` / `Window:Collapse()` | jump to MaxWidth or back |
| `Window:ToggleWidth()` | what the header chevrons do |
| `Window:SetToggleKey(keycode)` | rebind |
| `Window:Notify(cfg)` | same as `Love:Notify` |
| `Window:Destroy()` | remove this window only |

`Window.Open`, `Window.Tabs`, `Window.ActiveTab`, `Window.Width` and
`Window.Instance` (the drawer frame) are readable.

### Room for more

The panel starts narrow and short. When you need more room it goes **wider**,
not taller — drag the handle right past flush, press the chevrons in the
header, or call it:

```lua
Window:SetWidth(480)
Window:ToggleWidth()        -- base width ↔ MaxWidth
```

A widened panel still hides completely, and a drag that only widens it by a
few pixels snaps back rather than leaving a ragged edge.

### Backdrop

The panel is not a flat fill. A wash of the accent runs down it, two soft
glows sit in opposite corners, and a few hearts drift behind the content at
the edge of visible. All of it is drawn from frames and gradients — no image
assets to fail to load — and all of it is painted with theme tokens, so it
follows a theme switch like everything else.

```lua
Love:CreateWindow({ Background = "hearts" })   -- default
Love:CreateWindow({ Background = "glow" })     -- wash and glows, no hearts
Love:CreateWindow({ Background = "plain" })    -- flat, as it was
```

---

## Tabs and sections

```lua
local Tab   = Window:CreateTab("Main")        -- or { Title = "Main" }
local Group = Tab:CreateSection("Combat")     -- or { Title = "Combat" }

Tab:Select()        -- bring it to the front
Tab.Page            -- the ScrollingFrame behind it
Group:Destroy()
```

The first tab you create is selected automatically. Tab pills scroll
horizontally when they outgrow the panel, so the number of tabs is not capped
by the sidebar's width.

Elements are created on a section: `Group:Toggle{...}`. Every element also
exists on the tab itself (`Tab:Toggle{...}`) if you do not want a header.

---

## Elements

Every constructor takes a config table and returns an element handle. Handles
share a shape: `Instance`, `Type`, `Value`, `Set`, `Get`, `SetTitle`,
`Destroy`, and a `Flag` if you gave one.

### Label

```lua
local l = Group:Label("Plain text")     -- or { Title = "Plain text" }
l:SetText("Changed")
```

### Paragraph

```lua
local p = Group:Paragraph({ Title = "Heads up", Content = "Wraps across lines." })
p:SetTitle("New title")
p:SetContent("New body")
```

### Divider

```lua
Group:Divider()
```

### Button

```lua
Group:Button({
    Title       = "Kill all",
    Description = "Removes every NPC",
    Callback    = function() end,
})
```

### Toggle

```lua
local t = Group:Toggle({
    Title    = "Aimbot",
    Default  = false,
    Flag     = "Aimbot",
    Callback = function(on) end,
})
t:Set(true)
t:Get()
```

Clicking anywhere on the row flips it, not just the switch.

### Slider

```lua
local s = Group:Slider({
    Title     = "FOV",
    Min       = 20,
    Max       = 400,
    Default   = 120,
    Increment = 5,
    Suffix    = "px",
    Rounding  = 0,          -- decimals shown, inferred from Increment
    Flag      = "AimFov",
    Callback  = function(value) end,
})
s:Set(250)
```

Values clamp to `Min`/`Max` and snap to `Increment`.

### Dropdown

```lua
local d = Group:Dropdown({
    Title       = "Target part",
    Values      = { "Head", "HumanoidRootPart", "Torso" },
    Default     = "Head",
    Placeholder = "Select...",
    KeepOpen    = false,     -- true leaves the list open after a pick
    Flag        = "AimPart",
    Callback    = function(value) end,
})
d:SetValues({ "A", "B" })   -- rebuild; clears the pick if it is gone
d:SetOpen(true)
d:Toggle()
```

The list expands inline inside the panel rather than floating over it, so it
cannot end up off the side of a narrow sidebar.

Pass `Multi = true` and it holds a list instead of a single pick:

```lua
local m = Group:Dropdown({
    Title    = "Ignore",
    Values   = { "Friends", "Team", "Downed" },
    Multi    = true,
    Flag     = "Ignore",
    Callback = function(list, value, added) end,
})
m:Select("Team")            -- flips one value on or off
m:Set({ "Team", "Downed" }) -- replace the whole selection
m:Get()                     -- { "Team", "Downed" }
```

A multi dropdown stays open while you pick; pass `KeepOpen = false` to close
it after each one. `SetValues` drops anything selected that is no longer in
the list.

### ThemeDropdown

```lua
Group:ThemeDropdown({ Title = "Theme" })
```

A dropdown of every palette that sets the theme when you pick, and follows
along when the theme changes somewhere else. See [Themes](#themes).

### Input

```lua
local i = Group:Input({
    Title       = "Nickname",
    Placeholder = "type here",
    Default     = "",
    Flag        = "Nickname",
    Callback    = function(text) end,       -- on enter / focus lost
})
i:Set("hello")
```

### Keybind

```lua
local k = Group:Keybind({
    Title           = "Panic key",
    Default         = Enum.KeyCode.P,
    Flag            = "PanicKey",
    Callback        = function(key) end,        -- fires when the key is pressed
    ChangedCallback = function(key) end,        -- fires when it is rebound
})
k:Set(Enum.KeyCode.Q)
```

Click the chip, then press a key to rebind. Escape clears it. Inputs the game
has already handled are ignored, so typing in a chat box will not trigger it.

### Textarea

Multi-line text, for anything you would paste a list into.

```lua
local t = Group:Textarea({
    Title       = "Target list",
    Placeholder = "one name per line",
    Height      = 84,
    Default     = "",
    Flag        = "Targets",
    Callback    = function(text, enter) end,   -- on focus lost
})
t:Set("alice\nbob")
t.Lines()       -- { "alice", "bob" }
```

### ColorPicker

```lua
local c = Group:ColorPicker({
    Title    = "Tracer colour",
    Default  = Color3.fromRGB(244, 114, 182),
    Flag     = "TracerColour",
    Callback = function(colour) end,
})
c:Set(Color3.fromRGB(0, 200, 255))
c:SetOpen(true)
```

Hue, saturation and value as three bars rather than a gradient square — a
square needs more room than a sidebar has, and bars are easier to hit with a
thumb. The header swatch shows the current colour.

### Progress

```lua
local p = Group:Progress({ Title = "Scan", Default = 0 })
p:Set(0.5)                  -- 0..1 by default, shows "50%"

local q = Group:Progress({ Title = "Items", Max = 50 })
q:Set(12)                   -- shows "12 / 50"
```

Pass `Text = false` to hide the readout, or `Format = function(value, max)`
to write your own.

### Console

A scrolling log you can print into. It trims itself and follows the newest
line.

```lua
local log = Group:Console({ Title = "Output", Height = 110, MaxLines = 60 })
log:Append("scan started")
log:Success("done")         -- in the accent colour
log:Error("no target")      -- in the theme's error colour
log:Clear()
```

### Stat

A label with a value pinned to the right, for anything you update on a loop.

```lua
local ping = Group:Stat({ Title = "Ping", Value = "-" })
ping:Set("42ms")
```

---

## Notifications

```lua
Love:Notify({ Title = "Done", Content = "Everything worked.", Duration = 4 })
Love:Notify("short form")
```

Toasts stack in the bottom-right corner, slide in, and remove themselves when
their duration is up.

They are deliberately small — 176px wide, two lines of body text at most, and
the stack caps at three, pushing the oldest out rather than climbing the
screen. Change the cap with `Love.MaxToasts = 5`.

Each one carries the accent: a wash across the card, a bar down the left edge,
a beating heart, and a hairline underneath that drains for however long the
toast is up, so it shows its own clock instead of vanishing out of nowhere.

---

## Movement

Nothing in the library just appears. The pieces that move, and why:

| What | Does |
| --- | --- |
| The sidebar | slides on a long quintic curve; the panel edge catches the accent as it lands |
| The heart | beats when the sidebar opens, when the theme changes, and once in a while on its own |
| The handle | breathes slowly while the sidebar is shut, so a strip of pink at the screen edge reads as something you can grab |
| Tab pages | cross-fade and slide — the outgoing page leaves the way it came in, the incoming one arrives from the other side |
| Dropdowns | expand to a measured height, rows fading in one after another rather than a block appearing |
| Toggles | overshoot slightly, so the switch has some weight |
| Buttons | the chevron jumps forward and settles back, so a press that runs something silent still looks like it did something |
| Toasts | slide in from the right, drain their timer line, and slide back out |

---

## Flags

Any element with a `Flag` writes its value into `Love.Flags` and registers
itself in `Love.Options`.

```lua
Love:GetFlag("AimFov")          -- read
Love:SetFlag("AimFov", 200)     -- write, and update the element on screen
Love.Flags.AimFov               -- the raw table
Love.Options.AimFov:Set(200)    -- the element handle
```

There is no config file support in LoveUI yet — flags are in-memory only.

---

## Lifecycle

```lua
Love:Unload()       -- destroys the interface and disconnects everything
Love.Unloaded       -- true afterwards
Window:Destroy()    -- one window, leaving the library alive
```

`Love:Connect(signal, fn)` registers a connection that `Unload` will clean up
for you.

---

## Environment notes

- Parents to `gethui()` when the executor has it, then `CoreGui`, then
  `PlayerGui`, so the interface survives what the game does to its own UI.
- Uses `cloneref` for service handles when available.
- Falls back across fonts, so it still renders where Gotham is unavailable.
- Icons are drawn from frames rather than font glyphs — the heart in the header
  and the chevrons are built out of rotated shapes, which look the same
  everywhere.

---

## Repository layout

| Path | What |
| --- | --- |
| `LoveUI.lua` | the library |
| `LoveUI-example.lua` | feature demo |
| `LoveUI.md` | this file |
| `tests/love-spec.lua` | behaviour suite |
| `tests/love.sh` | runs it against the mock |

---

## Development

```bash
./tests/love.sh                 # behaviour suite
./tests/lint.sh LoveUI.lua LoveUI-example.lua
```

The suite runs the library against a mock Roblox API under the `luau` CLI —
the same harness Onyx uses. The mock rejects properties a class does not have,
so a bug like assigning `Text` to a `Frame` fails here instead of in game.
