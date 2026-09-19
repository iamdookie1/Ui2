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
change with it. The round dot in the window header cycles the theme, and the
example's Themes tab drives the same calls.

Each palette defines: `Bg`, `Panel`, `Card`, `Hover`, `Line`, `Text`, `Sub`,
`Muted`, `Accent`, `OnAccent`.

---

## Window

```lua
local Window = Love:CreateWindow({
    Title        = "My Script",
    SubTitle     = "v1.0",
    Theme        = "Rose",
    Width        = 290,                       -- how far it slides in
    HandleWidth  = 7,
    HandleHeight = 130,
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
| `Window:SetToggleKey(keycode)` | rebind |
| `Window:Notify(cfg)` | same as `Love:Notify` |
| `Window:Destroy()` | remove this window only |

`Window.Open`, `Window.Tabs`, `Window.ActiveTab` and `Window.Instance` (the
drawer frame) are readable.

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

---

## Notifications

```lua
Love:Notify({ Title = "Done", Content = "Everything worked.", Duration = 4 })
Love:Notify("short form")
```

Toasts stack in the bottom-right corner, slide in, and remove themselves when
their duration is up.

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
