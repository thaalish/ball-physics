--!strict
--[[
	A physically-inspired ball physics library for Roblox. Applies Magnus effect,
	knuckleball drift, angular damping, and anti-gravity forces to tagged ball parts.
	Forces are modelled after real aerodynamic phenomena but tuned for gameplay feel.

	SETUP
		The simplest way to get started is via the scripts in the Setup folder

	SERVER
		Call BallPhysics.new(ball) for each ball part you want to track.

	CLIENT
		Call BallPhysics.new() once to start the replication singleton.

	CUSTOM EFFECTS
		Register additional effects before the first .new() call:
			BallPhysics.registerEffect(myEffect)

	CONFIGURATION
		All tunable values are in Config.luau - no other files need to be edited.
--]]

local RunService = game:GetService("RunService")

local Effects = require(script.Effects)

-- `any` because Server and Client return different sets of functions.
local impl: any = if RunService:IsServer() then require(script.Runtime.Server) else require(script.Runtime.Client)

return {
	-- Server: pass a ball BasePart to begin simulation.
	-- Client: call once with no argument to start replication.
	new = impl.new,

	-- Whether this client owns the ball's simulation. Always nil on the server.
	isOwned = impl.isOwned,

	-- Register a custom effect. Must be called before the first .new().
	registerEffect = Effects.register,

	-- Enable or disable a named effect at runtime.
	-- Built-in names: "AntiGravity", "AngularDamping", "MagnusForce", "KnuckleBall"
	setEffectEnabled = Effects.setEffectEnabled,

	-- Returns the enabled state of a named effect, or nil if not found.
	isEffectEnabled = Effects.isEffectEnabled,
}
