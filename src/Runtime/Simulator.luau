--!strict
--[[
	Runs all registered physics effects on a ball every frame.
	Managed by Server and Client - does not start automatically on construction.

	Not part of the public API - use BallPhysics.new() from init.luau instead.
--]]

local RunService = game:GetService("RunService")

local AlarmClock = require(script.Parent.Parent.AlarmClock)

local Effects = require(script.Parent.Parent.Effects)

-- Balls below both thresholds are considered idle and skip the effects loop.
local IDLE_LINEAR_THRESHOLD = 0.5  -- stud/s
local IDLE_ANGULAR_THRESHOLD = 0.1 -- rad/s

local Types = require(script.Parent.Parent.Types)
type Effect = Types.Effect

local Simulator = {}
Simulator.__index = Simulator

export type SimulatorInstance = typeof(setmetatable({} :: {
	ball: BasePart,
	_stepped: RBXScriptConnection?,
	_isIdle: boolean,
}, Simulator))

function Simulator.new(ball: BasePart): SimulatorInstance
	assert(ball.Shape == Enum.PartType.Ball, "Simulator: part must be a ball")

	local self = setmetatable({}, Simulator)
	self.ball = ball
	self._stepped = nil :: RBXScriptConnection?
	self._isIdle = false

	for _, effect: Effect in Effects.effects do
		if effect.enabled and effect.instance and effect.setup then
			if not ball:FindFirstChild(effect.instance) then
				local inst = effect.setup(ball)
				inst.Name = effect.instance
				inst.Parent = ball
			end
		end
	end

	return self
end

function Simulator:Enable()
	self:Disable()
	self._isIdle = false
	AlarmClock:ForbidSleep(self.ball)

	-- Pre-build profiler labels once so there's no string work inside the Stepped callback.
	local effects = Effects.effects
	local profileLabels: { string } = table.create(#effects)
	for i, effect: Effect in effects do
		profileLabels[i] = "BallPhysics/" .. (effect.name or effect.instance or effect.property)
	end

	self._stepped = RunService.Stepped:Connect(function(_, deltaTime: number)
		debug.profilebegin("BallPhysics/Stepped")
		local ball: BasePart = self.ball
		if not ball or not ball:IsDescendantOf(workspace) then
			self:Disable()
			debug.profileend()
			return
		end

		-- Skip effects when the ball is anchored/welded or both velocities are below their thresholds.
		if ball:IsGrounded()
			or (ball.AssemblyLinearVelocity.Magnitude < IDLE_LINEAR_THRESHOLD
				and ball.AssemblyAngularVelocity.Magnitude < IDLE_ANGULAR_THRESHOLD)
		then
			-- On the first idle frame, apply each effect's resetValue so residual
			-- forces don't keep pushing the ball while inactive.
			if not self._isIdle then
				self._isIdle = true
				for _, effect: Effect in effects do
					if not effect.enabled or effect.resetValue == nil then
						continue
					end
					local target: Instance = ball
					if effect.instance then
						local child = ball:FindFirstChild(effect.instance)
						if not child then
							continue
						end
						target = child
					end
					(target :: any)[effect.property] = effect.resetValue
				end
			end
			debug.profileend()
			return
		end
		self._isIdle = false

		for i, effect: Effect in effects do
			if not effect.enabled then
				continue
			end

			local target: Instance = ball
			if effect.instance then
				local child: Instance? = ball:FindFirstChild(effect.instance)
				if not child and effect.setup then
					-- Effect was enabled after the ball was created; set up its instance now.
					local newInstance = effect.setup(ball)
					newInstance.Name = effect.instance
					newInstance.Parent = ball
					child = newInstance
				end
				if child then
					target = child
				else
					warn("Simulator: " .. effect.instance .. " not found on " .. tostring(ball))
					continue
				end
			end

			-- Setup-only effects have no compute function.
			if not effect.compute then
				continue
			end

			local current = (target :: any)[effect.property]
			debug.profilebegin(profileLabels[i])
			local new = effect.compute(ball, deltaTime)
			debug.profileend()

			-- Skip assignment when the value hasn't meaningfully changed
			-- to avoid unnecessary property replication.
			-- Always allow Vector3.zero through so effects can snap values to a true zero.
			if typeof(current) == "Vector3" and typeof(new) == "Vector3" then
				if (new :: Vector3) ~= Vector3.zero and (current :: Vector3):FuzzyEq(new :: Vector3) then
					continue
				end
			end

			(target :: any)[effect.property] = new
		end
		debug.profileend()
	end)
end

function Simulator:Disable()
	if self._stepped then
		self._stepped:Disconnect()
		self._stepped = nil
	end

	AlarmClock:AllowSleep(self.ball)
end

function Simulator:Destroy()
	self:Disable()
	self.ball = nil :: any
end

return Simulator
