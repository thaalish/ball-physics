--!strict
--[[
	Simulates the unpredictable lateral drift of a knuckleball pitch.

	The ball drifts sideways in an oscillating pattern perpendicular to its travel
	direction. The effect is strongest with little to no spin - high spin suppresses
	it, as the Magnus effect dominates.

	Each ball gets a random drift pattern so multiple balls in the air at once
	behave independently.

	Requires a VectorForce child named INSTANCE_NAME on the ball.
	Simulator.new() checks for an existing child and calls setup() only if one is absent.
--]]

local Config = require(script.Parent.Parent.Config)
local Util = require(script.Parent.Parent.Runtime.Util)

local Types = require(script.Parent.Parent.Types)
type Effect = Types.Effect

local INSTANCE_NAME = "KnuckleBall"

-- Minimum horizontal speed (stud/s) below which no knuckleball force is applied.
-- The effect ramps up from zero at this speed, reaching full intensity at targetSpeed.
local SPEED_THRESHOLD = 70

-- Minimum spin magnitude used as a denominator guard.
local MIN_SPIN = 0.075

-- The spin magnitude (deg/s) at which the effect is reduced to ~37% strength.
-- Double the spin and it drops to ~14%. Lower values suppress the effect sooner.
local SPIN_SCALE = 15

local ballPhases: { [BasePart]: { number } } = {}
setmetatable(ballPhases, { __mode = "k" } :: any)

local function getPhases(ball: BasePart): { number }
	if not ballPhases[ball] then
		ballPhases[ball] = { math.random() * math.pi * 2, math.random() * math.pi * 2 }
	end
	return ballPhases[ball]
end

return {
	property = "Force",
	instance = INSTANCE_NAME,
	enabled = Config.knuckleball.enabled,
	resetValue = Vector3.zero,

	setup = function(ball: BasePart): Instance
		local attachment = Util.getOrCreateAttachment(ball)
		local vectorForce = Instance.new("VectorForce")
		vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
		vectorForce.Attachment0 = attachment
		return vectorForce
	end,

	compute = function(ball: BasePart, _: number): Vector3
		local velocity = ball.AssemblyLinearVelocity * Vector3.new(1, 0, 1)

		if velocity.Magnitude < SPEED_THRESHOLD or Util.isTouchingGround(ball) then
			return Vector3.zero
		end

		local speed = velocity.Magnitude
		local spin = math.max(MIN_SPIN, ball.AssemblyAngularVelocity.Magnitude)

		-- Intensity suppressed exponentially by spin.
		local intensity = math.exp(-spin / SPIN_SCALE)
		-- Ramp smoothly from 0 to full intensity as speed reaches targetSpeed.
		-- Above targetSpeed the intensity stays at 1 - fast balls still knuckleball.
		local speedRamp =
			math.clamp((speed - SPEED_THRESHOLD) / (Config.knuckleball.targetSpeed - SPEED_THRESHOLD), 0, 1)

		intensity = intensity * speedRamp

		if intensity < 0.01 then
			return Vector3.zero
		end

		-- Two-harmonic oscillation with per-ball phase offsets.
		-- Golden-ratio frequency ratio (~1.618) keeps the combined wave quasi-periodic:
		-- smooth and directional per-frame, but non-repeating over longer timescales.
		local phases = getPhases(ball)
		local time = workspace:GetServerTimeNow()
		local primaryFrequency = Config.knuckleball.oscillationFrequency -- rad/s
		local secondaryFrequency = primaryFrequency * 1.618
		local drift = math.sin(time * primaryFrequency + phases[1]) + 0.4 * math.sin(time * secondaryFrequency + phases[2])

		-- Apply force perpendicular to the horizontal velocity direction.
		-- right = 90 deg left in the XZ plane from the ball's travel direction.
		local forward = velocity.Unit
		local right = Vector3.new(-forward.Z, 0, forward.X)

		-- Multiply by mass so `strength` behaves as a mass-independent acceleration (stud/s^2).
		return right * drift * Config.knuckleball.strength * intensity * ball.AssemblyMass
	end,
} :: Effect
