# Changelog

---

## [1.0.0] - 2026-03-28

Initial public release.

### Effects

- **Magnus Effect** - curves spinning balls in flight based on spin direction and speed
- **Knuckleball** - unpredictable lateral drift for low-spin balls, suppressed by spin; each ball drifts independently
- **Angular Damping** - slows ball spin over time; decays faster on the ground than in the air
- **Anti-Gravity** - partially cancels gravity to extend flight time

### Features

- Automatic client-server ownership handoff - simulation always runs on the network owner with server fallback
- AutoSetup scripts - zero-config wiring via CollectionService tags; no manual `BallPhysics.new()` calls required
- Custom effect registration via `BallPhysics.registerEffect()` - supports per-frame and setup-only effects
- Runtime effect toggling via `BallPhysics.setEffectEnabled()`
- AlarmClock vendored into the library - no external dependencies required
- Debug overlay (F3) - cycles through text, vector arrows, and off modes
- Test scenario panel (F4) - launches preset balls demonstrating each effect
- Unit tests for all effects via TestEZ
