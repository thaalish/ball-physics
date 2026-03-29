--!strict
--[[
	Slows the ball's spin over time, simulating air resistance and surface friction.
	Spin decays faster when the ball is on the ground than when it is airborne.
	Both rates are configurable via angularDamping in Config.

	Decay formula: newOmega' = exp(-rate * deltaTime) * omega
--]]

local Config = require(script.Parent.Parent.Config)
local Util = require(script.Parent.Parent.Runtime.Util)

local Types = require(script.Parent.Parent.Types)
type Effect = Types.Effect

return {
	name = "AngularDamping",
	property = "AssemblyAngularVelocity",
	enabled = Config.angularDamping.enabled,

	compute = function(ball: BasePart, deltaTime: number): Vector3
		local omega = ball.AssemblyAngularVelocity
		local rate = if Util.isTouchingGround(ball) then Config.angularDamping.groundRate else Config.angularDamping.airRate
		return math.exp(-rate * deltaTime) * omega
	end,
} :: Effect
