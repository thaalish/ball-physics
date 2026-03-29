--!strict
--[[
	Ordered registry of active physics effects.
	AngularDamping runs first so spin is current when Magnus and KnuckleBall compute their forces.

	Custom effects can be appended via register() before any Simulator is created.
--]]

local Types = require(script.Parent.Types)
type Effect = Types.Effect

local effects: { Effect } = {
	require(script.AntiGravity),
	require(script.AngularDamping),
	require(script.KnuckleBall),
	require(script.MagnusEffect),
}

-- Appends a custom effect. Call before the first BallPhysics.new().
local function register(effect: Effect)
	table.insert(effects, effect)
end

-- Enables or disables the effect matching `name`.
local function setEffectEnabled(name: string, enabled: boolean)
	for _, effect in effects do
		if effect.name == name or effect.instance == name then
			effect.enabled = enabled
			return
		end
	end
	warn("BallPhysics.setEffectEnabled: no effect found with name '" .. name .. "'")
end

-- Returns the enabled state of the matching effect, or nil if not found.
local function isEffectEnabled(name: string): boolean?
	for _, effect in effects do
		if effect.name == name or effect.instance == name then
			return effect.enabled
		end
	end
	return nil
end

return {
	effects = effects,
	register = register,
	setEffectEnabled = setEffectEnabled,
	isEffectEnabled = isEffectEnabled,
}
