--!strict
--[[
	Listens for ownership events from the server and runs simulation locally
	for whichever balls this client is responsible for.

	Not part of the public API - use BallPhysics.new() from init.luau instead.
--]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Parent.Config)
local Simulator = require(script.Parent.Simulator)

local BALL_ID_ATTR = "_BPId"
local STREAM_TIMEOUT = 10 -- seconds to wait for a ball to stream in

local replication = ReplicatedStorage:WaitForChild(Config.replicationChannel) :: RemoteEvent

-- Module-level state is safe because Client is always used as a singleton.
local _owned: { BasePart } = {}

local Client = {}
Client.__index = Client

function Client.new()
	local self = setmetatable({}, Client)
	self._simulators = {} :: { [BasePart]: typeof(Simulator.new(nil :: any)) }
	self._connection = nil :: RBXScriptConnection?
	self:Enable()
	return self
end

function Client.isOwned(ball: BasePart): boolean
	return table.find(_owned, ball) ~= nil
end

-- Waits for a tagged ball with the given ID to stream in, up to STREAM_TIMEOUT seconds.
local function waitForBallById(id: number): BasePart?
	for _, instance in CollectionService:GetTagged(Config.ballTag) do
		if instance:GetAttribute(BALL_ID_ATTR) == id then
			return instance :: BasePart
		end
	end

	local found: BasePart? = nil
	local connection: RBXScriptConnection
	local thread = coroutine.running()
	connection = CollectionService:GetInstanceAddedSignal(Config.ballTag):Connect(function(instance: Instance)
		if instance:GetAttribute(BALL_ID_ATTR) == id then
			found = instance :: BasePart
			connection:Disconnect()
			task.spawn(thread)
		end
	end)

	task.delay(STREAM_TIMEOUT, function()
		if connection.Connected then
			connection:Disconnect()
			task.spawn(thread)
		end
	end)

	coroutine.yield()
	return found
end

function Client:handleEvent(ball: BasePart, event: string)
	if event == "Add" then
		-- Pre-create a disabled simulator so Enable is instant when ownership arrives.
		if not self._simulators[ball] then
			self._simulators[ball] = Simulator.new(ball)
		end
	elseif event == "Start" then
		table.insert(_owned, ball)
		local sim = self._simulators[ball]
		if sim then
			sim:Enable()
		else
			local newSim = Simulator.new(ball)
			newSim:Enable()
			self._simulators[ball] = newSim
		end
	elseif event == "End" then
		local index = table.find(_owned, ball)
		if index then
			table.remove(_owned, index)
		end

		local sim = self._simulators[ball]
		if sim then
			sim:Disable()
		end
	end
end

function Client:Enable()
	self:Disable()
	self._connection = replication.OnClientEvent:Connect(function(ball: BasePart, event: string, ballId: number)
		if ball then
			self:handleEvent(ball, event)
			return
		end

		-- StreamingEnabled: instance hasn't replicated yet. Wait for it by attribute.
		task.spawn(function()
			local streamed = waitForBallById(ballId)
			if streamed then
				self:handleEvent(streamed, event)
			else
				local msg = ("BallPhysics: ball ID %d did not stream within %ds - '%s' event dropped"):format(
					ballId, STREAM_TIMEOUT, event)
				if event == "Start" then
					-- "Start" means this client was assigned ownership but the ball never
					-- arrived. Simulation will not run for this ball on this client.
					warn(msg .. " (client will not simulate this ball)")
				else
					warn(msg)
				end
			end
		end)
	end)
end

function Client:Disable()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

function Client:Destroy()
	self:Disable()
	for _, sim in self._simulators do
		sim:Destroy()
	end
	table.clear(self._simulators)
	table.clear(_owned)
end

return Client
