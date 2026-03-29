--!strict
--[[
	Each scenario launches a ball with a preset velocity and spin to demonstrate
	a specific physics effect.

	Velocities are in local space - +Z is forward,
	+Y is up, +X is right - and are rotated at spawn to match the player's
	facing direction.

	linVel is in stud/s. angVel is in rad/s (AssemblyAngularVelocity units).
--]]

export type Scenario = {
	name: string,
	desc: string,
	linVel: Vector3,
	angVel: Vector3,
	ballSize: number,
	lifetime: number,
}

local scenarios: { Scenario } = {
	{
		-- Y-axis spin while launched forward -> sideways Magnus curve
		name = "Magnus Curve",
		desc = "High spin - curves sideways",
		linVel = Vector3.new(-20, 50, 110),
		angVel = Vector3.new(0, 200, 0),
		ballSize = 2.5,
		lifetime = 10,
	},
	{
		-- Near target-speed with almost no spin -> erratic knuckleball drift
		name = "Knuckleball",
		desc = "Near-zero spin - erratic drift",
		linVel = Vector3.new(0, 50, 110),
		angVel = Vector3.new(2, 0, 1),
		ballSize = 2.5,
		lifetime = 10,
	},
	{
		-- +X spin while launched forward -> downward Magnus force, ball dips
		name = "Topspin",
		desc = "Forward spin - ball dips early",
		linVel = Vector3.new(0, 80, 100),
		angVel = Vector3.new(400, 0, 0),
		ballSize = 2.5,
		lifetime = 10,
	},
	{
		-- -X spin while launched forward -> upward Magnus force, ball floats
		name = "Backspin",
		desc = "Reverse spin - floats longer",
		linVel = Vector3.new(0, 35, 85),
		angVel = Vector3.new(-300, 0, 0),
		ballSize = 2.5,
		lifetime = 10,
	},
}

return scenarios
