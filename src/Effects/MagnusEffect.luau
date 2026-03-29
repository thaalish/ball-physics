--!strict
--[[
	Curves the ball in flight based on how fast and in which direction it is spinning.
	A ball spinning to the right curves right; backspin produces lift.

	Formula: F = (3/2) * density * (omega:Cross(v))

	The strength of the curve is controlled by the ball's density (from CustomPhysicalProperties,
	or defaultDensity in Config if none are set) and the Config.magnus.strength multiplier.

	Requires a VectorForce child named INSTANCE_NAME on the ball.
	Simulator.new() checks for an existing child and calls setup() only if one is absent.
--]]

local Config = require(script.Parent.Parent.Config)
local Util = require(script.Parent.Parent.Runtime.Util)

local Types = require(script.Parent.Parent.Types)
type Effect = Types.Effect

local INSTANCE_NAME = "MagnusForce"

local function toRadians(v: Vector3): Vector3
	return Vector3.new(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
end

local function isNaN(v: Vector3): boolean
	return v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z
end

return {
	property = "Force",
	instance = INSTANCE_NAME,
	enabled = Config.magnus.enabled,
	resetValue = Vector3.zero,

	setup = function(ball: BasePart): Instance
		local attachment = Util.getOrCreateAttachment(ball)
		local vectorForce = Instance.new("VectorForce")
		vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
		vectorForce.Attachment0 = attachment
		return vectorForce
	end,

	compute = function(ball: BasePart, _: number): Vector3
		local velocity = ball.AssemblyLinearVelocity
		local omega = toRadians(ball.AssemblyAngularVelocity)
		local density = if ball.CustomPhysicalProperties
			then ball.CustomPhysicalProperties.Density
			else Config.magnus.defaultDensity

		local magnus = (3 / 2) * density * Config.magnus.strength * omega:Cross(velocity)
		return if isNaN(magnus) then Vector3.zero else magnus
	end,
} :: Effect
