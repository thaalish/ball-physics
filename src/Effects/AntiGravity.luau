--!strict
--[[
	Reduces the effect of gravity on the ball, making it stay in the air longer.

	The fraction of gravity cancelled is set by antiGravity.fraction in Config.
	At 1 the ball is weightless; at 0.5 it falls at half speed.

	Requires a VectorForce child named INSTANCE_NAME on the ball.
	Simulator.new() checks for an existing child and calls setup() only if one is absent.
--]]

local Config = require(script.Parent.Parent.Config)
local Util = require(script.Parent.Parent.Runtime.Util)

local Types = require(script.Parent.Parent.Types)
type Effect = Types.Effect

local INSTANCE_NAME = "AntiGravity"

return {
	property = "Force",
	instance = INSTANCE_NAME,
	enabled = Config.antiGravity.enabled,

	setup = function(ball: BasePart): Instance
		local attachment = Util.getOrCreateAttachment(ball)
		local vectorForce = Instance.new("VectorForce")
		vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
		vectorForce.Force = Vector3.new(0, ball.AssemblyMass * workspace.Gravity * Config.antiGravity.fraction, 0)
		vectorForce.Attachment0 = attachment
		return vectorForce
	end,
} :: Effect
