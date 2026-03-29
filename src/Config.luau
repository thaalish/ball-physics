--!strict
--[[
	This is the main configuration file for BallPhysics. Adjust the values below
	to tune how each physics effect feels in your game - no other files need to
	be touched for standard configuration.
--]]

export type Config = {
	-- CollectionService tag that identifies balls.
	ballTag: string,

	-- Name of the RemoteEvent created under ReplicatedStorage for client-server replication.
	replicationChannel: string,

	angularDamping: {
		enabled: boolean,
		-- How aggressively spin decays while the ball is on the ground.
		-- Higher values stop the ball spinning faster.
		groundRate: number,
		-- How aggressively spin decays while the ball is airborne.
		-- Keep this below groundRate so balls retain spin longer in the air.
		airRate: number,
	},

	magnus: {
		enabled: boolean,
		-- Density used in the Magnus formula when the ball has no CustomPhysicalProperties.
		-- Higher values produce a stronger curve.
		defaultDensity: number,
		-- Global multiplier applied to the Magnus force after the formula.
		-- 1 = physically accurate, >1 exaggerates the curve, <1 reduces it.
		strength: number,
	},

	knuckleball: {
		enabled: boolean,
		-- Peak lateral acceleration (stud/s^2) applied perpendicular to the travel direction.
		-- Multiplied by mass internally, so the effect feels the same regardless of ball weight.
		strength: number,
		-- Ball speed (stud/s) at which the knuckleball effect reaches full intensity.
		-- The effect ramps from zero at SPEED_THRESHOLD up to full intensity at this speed.
		-- Above this speed the intensity stays at maximum - fast balls still knuckleball.
		targetSpeed: number,
		-- Primary oscillation frequency in rad/s.
		-- 7 rad/s ~ 1.1 Hz, so the drift direction reverses roughly once per second.
		-- A second harmonic at 1.618x this frequency adds variation without pure repetition.
		oscillationFrequency: number,
	},

	antiGravity: {
		enabled: boolean,
		-- Fraction of gravity to cancel (0 = no effect, 1 = full weightlessness).
		fraction: number,
	},

	debug: {
		enabled: boolean,
		-- How often the debug overlay labels refresh, in seconds.
		updateInterval: number,
		-- Ball speed (stud/s) at which the SelectionBox colour gradient reaches full red.
		speedColorCeiling: number,
	},
}

local config: Config = {
	ballTag = "PhysicsBall",
	replicationChannel = "BallPhysicsReplication",

	angularDamping = {
		enabled = true,
		groundRate = 1,
		airRate = 0.65,
	},

	magnus = {
		enabled = true,
		defaultDensity = 0.7,
		strength = 1,
	},

	knuckleball = {
		enabled = true,
		strength = 40,
		targetSpeed = 110,
		oscillationFrequency = 7,
	},

	antiGravity = {
		enabled = true,
		fraction = 0.625,
	},

	debug = {
		enabled = false,
		updateInterval = 0.05,
		speedColorCeiling = 150,
	},
}

return config
