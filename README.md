# BallPhysics - Aerodynamic ball physics for Roblox

A physically-inspired ball physics library for Roblox. Applies Magnus effect, knuckleball drift, angular damping, and anti-gravity forces to tagged ball parts. Forces are modelled after real aerodynamic phenomena but tuned for gameplay feel.

Simulation runs on whichever machine owns the ball's network physics - the library handles ownership handoff between server and clients automatically.

This started as a private physics system I built for my own games. Exploiters kept decompiling it, so when I decided to rewrite it I took it as a chance to do it properly and put it out publicly - so anyone can use it.

---

## Showcase

### 🎥 Magnus curve

A spinning ball curving sideways in flight.

![Magnus Curve](https://github.com/user-attachments/assets/77bb2f07-9da9-490c-a8c0-8d7a57a20246)

### 🎥 Knuckleball drift

A near-zero-spin ball drifting unpredictably.

![Knuckle](https://github.com/user-attachments/assets/9fcf0f6e-79f8-42d6-b173-3b1074723cb7)

### 🎥 Topspin and backspin

One ball dips early, the other floats.

![Top Spin](https://github.com/user-attachments/assets/f2a21547-7e25-47c2-a943-6820afdd8ae2)
![Back Spin](https://github.com/user-attachments/assets/f254839b-59ed-4316-a03d-dfa90f5d4a20)

---

## Installation

Choose whichever method suits your workflow:

### Option A - Release file

Download the latest `.rbxm` from the [Releases page](../../releases) and insert it into your place via Studio. Place `BallPhysics` into `ReplicatedStorage`, then follow the setup steps in [Quick start](#quick-start).

### Option B - Wally _(recommended for source control)_

Add BallPhysics to your `wally.toml`:

```toml
[dependencies]
BallPhysics = "thaalish/ball-physics@1.0.0"
```

Then run:

```
wally install
rojo serve default.project.json
```

Rojo places everything under `ReplicatedStorage`:

| Roblox name   | Filesystem | Purpose                                   |
| ------------- | ---------- | ----------------------------------------- |
| `BallPhysics` | `src/`     | Module library                            |
| `Setup`       | `dev/`     | Auto-setup and debug scripts _(dev only)_ |
| `Tests`       | `test/`    | Unit test specs _(dev only)_              |

> `Setup` and `Tests` are only included in the dev project (`default.project.json`) - not in release builds. See [Running tests](#running-tests) and [Debug tools](#debug-tools) for more.

## Quick start

1. Install and sync (above)
2. Tag any `BasePart` (Shape = Ball) with the CollectionService tag defined in `Config.ballTag` (default: `"PhysicsBall"`)
3. Add a **Server Script** in `ServerScriptService`:

```lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallPhysics = require(ReplicatedStorage.BallPhysics)
local Config = require(ReplicatedStorage.BallPhysics.Config)

local handlers = {}

local function track(instance)
    if instance:IsA("BasePart") then
        handlers[instance] = BallPhysics.new(instance)
    end
end

local function untrack(instance)
    if handlers[instance] then
        handlers[instance]:Destroy()
        handlers[instance] = nil
    end
end

for _, instance in CollectionService:GetTagged(Config.ballTag) do
    task.spawn(track, instance)
end
CollectionService:GetInstanceAddedSignal(Config.ballTag):Connect(track)
CollectionService:GetInstanceRemovedSignal(Config.ballTag):Connect(untrack)
```

4. Add a **Local Script** in `StarterPlayerScripts`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallPhysics = require(ReplicatedStorage.BallPhysics)
BallPhysics.new()
```

> If you are using `default.project.json`, the `Setup` folder (from `dev/`) handles steps 3 and 4 automatically.

## Configuration

All tunable values live in `src/Config.luau`. Every value is documented inline. Effects can be toggled independently:

```lua
magnus = {
    enabled = true,
    defaultDensity = 0.7,   -- higher = stronger curve (when no CustomPhysicalProperties)
    strength = 1,           -- global multiplier; >1 exaggerates, <1 reduces
},

knuckleball = {
    enabled = true,
    strength = 40,            -- peak lateral acceleration (stud/s^2)
    targetSpeed = 110,        -- full intensity at and above this speed (stud/s)
    oscillationFrequency = 7, -- rad/s; ~1.1 Hz
},

angularDamping = {
    enabled = true,
    airRate = 0.65,           -- spin decay rate while airborne
    groundRate = 1,         -- spin decay rate on the ground
},

antiGravity = {
    enabled = true,
    fraction = 0.625,         -- cancels 62.5% of gravity
},
```

You can also toggle effects at runtime:

```lua
BallPhysics.setEffectEnabled("KnuckleBall", false)
```

## Effects

| Effect           | What it does                                                          |
| ---------------- | --------------------------------------------------------------------- |
| `MagnusForce`    | Curves the ball based on spin direction and speed                     |
| `KnuckleBall`    | Adds unpredictable lateral drift when spin is low                     |
| `AngularDamping` | Slows the ball's spin over time; faster on the ground than in the air |
| `AntiGravity`    | Partially cancels gravity, keeping the ball in the air longer         |

## Custom effects

Register a custom effect **before** the first `BallPhysics.new()` call. Effects run in registration order.

`compute` is optional - omit it for setup-only effects whose value is written once in `setup` and never changes. Set a `name` field on any effect you want to toggle later via `setEffectEnabled`.

If your effect uses a child instance (e.g. a `VectorForce`) you should also set `resetValue` to the value that property should hold while the ball is idle. Without it the last computed force will keep applying when the ball comes to rest.

```lua
local BallPhysics = require(game.ReplicatedStorage.BallPhysics)

-- Per-frame effect: modify a property directly on the ball
BallPhysics.registerEffect({
    property = "AssemblyLinearVelocity",
    name     = "MyDrag",
    enabled  = true,
    compute  = function(ball: BasePart, deltaTime: number)
        return ball.AssemblyLinearVelocity * 0.999
    end,
})

-- Per-frame effect: apply a VectorForce (auto-created if missing)
BallPhysics.registerEffect({
    property   = "Force",
    instance   = "MyForce",
    enabled    = true,
    resetValue = Vector3.zero,
    setup = function(ball: BasePart): Instance
        local attachment = ball:FindFirstChildOfClass("Attachment")
            or Instance.new("Attachment", ball)
        local vectorForce = Instance.new("VectorForce")
        vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
        vectorForce.Attachment0 = attachment
        return vectorForce
    end,
    compute = function(ball: BasePart, _: number)
        return Vector3.new(0, 100, 0)
    end,
})

-- Setup-only effect: constant force, no per-frame cost
BallPhysics.registerEffect({
    property = "Force",
    instance = "MyLift",
    enabled  = true,
    setup = function(ball: BasePart): Instance
        local attachment = ball:FindFirstChildOfClass("Attachment")
            or Instance.new("Attachment", ball)
        local vectorForce = Instance.new("VectorForce")
        vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
        vectorForce.Force = Vector3.new(0, ball.AssemblyMass * 50, 0)
        vectorForce.Attachment0 = attachment
        return vectorForce
    end,
})
```

See `src/Types.luau` for the full `Effect` type definition.

## API

### Server

| Method                  | Description                                      |
| ----------------------- | ------------------------------------------------ |
| `BallPhysics.new(ball)` | Begin tracking a ball. Starts ownership polling. |
| `handle:Enable()`       | Resume ownership polling.                        |
| `handle:Disable()`      | Pause polling; state is preserved.               |
| `handle:Destroy()`      | Full teardown.                                   |

### Client

| Method                      | Description                                             |
| --------------------------- | ------------------------------------------------------- |
| `BallPhysics.new()`         | Start the client singleton (called by AutoSetup).       |
| `BallPhysics.isOwned(ball)` | `true` if this client owns `ball`'s network simulation. |

### Shared

| Method                                        | Description                                                                                                            |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `BallPhysics.registerEffect(effect)`          | Register a custom effect. Call before `BallPhysics.new()`.                                                             |
| `BallPhysics.setEffectEnabled(name, enabled)` | Enable or disable an effect by name. Built-ins: `"AntiGravity"`, `"AngularDamping"`, `"MagnusForce"`, `"KnuckleBall"`. |
| `BallPhysics.isEffectEnabled(name)`           | Returns the enabled state of the named effect, or `nil` if not found.                                                  |

## Debug tools

> **Dev only** - these scripts live in `dev/` and are loaded by `default.project.json`. They are not included in release builds or the Wally package.

Enable the debug scripts by setting `Config.debug.enabled = true`.

**Debug overlay** (`Debug.client.luau`) - press **F3** to cycle through modes:

- **Text** - BillboardGui showing speed, spin, velocity, and ownership
- **Text + Vectors** - adds live arrow adornments for velocity, Magnus force, knuckleball force, and spin axis
- **Vectors only**
- **Off**

**Test scenario panel** (`TestScenarios.client.luau`) - press **F4** to open. Launches preset balls to demonstrate each effect:

| Key | Scenario     | Description                      |
| --- | ------------ | -------------------------------- |
| `1` | Magnus Curve | High Y-spin, curves sideways     |
| `2` | Knuckleball  | Near-zero spin, erratic drift    |
| `3` | Topspin      | Forward spin, ball dips early    |
| `4` | Backspin     | Reverse spin, ball floats longer |

Press **0** to toggle between server-owned and client-owned simulation.

## Known limitations

**`setEffectEnabled` is global.** Enabling or disabling an effect applies to every ball in the scene. There is no built-in way to disable, say, Magnus force on one ball while leaving it active on others.

**StreamingEnabled: ownership events can be lost.** When `StreamingEnabled` is on, a ball instance may not have streamed to a client by the time the server fires an ownership event. The library waits up to 10 seconds for the ball to arrive. If it does not, the event is dropped and a warning is printed. A dropped `Start` event means that client will not simulate the ball.

## Running tests

Play in Studio and check the Output window. Tests run automatically on the server via TestEZ.
