--!strict
--[[
	Type definitions for writing custom effects.
	Import this module for full type safety:

		local Types = require(game.ReplicatedStorage.BallPhysics.Types)
		type Effect = Types.Effect
--]]

-- Describes a physics modifier applied to a ball each simulation frame.
-- Pass a table with these fields to BallPhysics.registerEffect().
export type Effect = {
	-- The Instance property to write each frame (e.g. "Force", "AssemblyAngularVelocity").
	property: string,

	-- Name of a child Instance on the ball to target.
	-- If nil, the ball BasePart itself is the target.
	instance: string?,

	-- Display name used by setEffectEnabled / isEffectEnabled.
	-- Only needed when `instance` is nil; otherwise `instance` doubles as the key.
	name: string?,

	-- Called once by Simulator.new() to create the child Instance when it doesn't exist.
	-- Return the new Instance - name and parent are set automatically after this returns.
	setup: ((ball: BasePart) -> Instance)?,

	-- Whether the effect runs each frame. Can be toggled at runtime.
	enabled: boolean,

	-- Returns the new value for `property`, called every frame.
	-- Omit for setup-only effects whose value never changes after setup (e.g. a constant VectorForce).
	compute: ((ball: BasePart, deltaTime: number) -> any)?,

	-- Value written to `property` when the simulator transitions into idle.
	-- Only needed for effects whose idle state is not the property's existing value
	-- (e.g. a VectorForce that should read Vector3.zero while the ball is inactive).
	-- If omitted, no reset is performed on idle.
	resetValue: any?,
}

return {}
