--!strict
--[[
	Manages one ball's physics simulation on the server side.
	Watches network ownership each frame - when a client takes ownership, simulation
	is handed off to them. When they release it, the server resumes.

	Not part of the public API - use BallPhysics.new(ball) from init.luau instead.
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local nextBallId = 0
local BALL_ID_ATTR = "_BPId"

local Config = require(script.Parent.Parent.Config)
local Simulator = require(script.Parent.Simulator)

-- Created once when this module first loads on the server.
local replication = Instance.new("RemoteEvent")
replication.Name = Config.replicationChannel
replication.Parent = ReplicatedStorage

local Server = {}
Server.__index = Server

function Server.new(ball: BasePart)
	assert(typeof(ball) == "Instance" and ball:IsA("BasePart"), "Server: expected BasePart, got " .. typeof(ball))

	-- Assign a stable unique ID so clients with StreamingEnabled can identify this
	-- ball by attribute if the Instance arrives as nil in the RemoteEvent.
	nextBallId += 1
	ball:SetAttribute(BALL_ID_ATTR, nextBallId)

	local self = setmetatable({}, Server)
	self.ball = ball
	self._ballId = nextBallId
	self._owner = nil :: Player?
	self._simulator = Simulator.new(ball)
	self._heartbeat = nil :: RBXScriptConnection?
	self._parentChanged = nil :: RBXScriptConnection?
	self._playerAdded = nil :: RBXScriptConnection?
	self._isAnnounced = false

	-- Notify all current clients, and any who join later.
	-- Deferred until the ball is in workspace so the Instance has replicated
	-- before clients receive the event. The ball ID is sent alongside so
	-- clients with StreamingEnabled can wait for it by attribute if the
	-- Instance arrives as nil.
	local function announceToClients()
		if self._isAnnounced then
			return
		end
		self._isAnnounced = true
		replication:FireAllClients(ball, "Add", self._ballId)
		self._playerAdded = Players.PlayerAdded:Connect(function(player: Player)
			replication:FireClient(player, ball, "Add", self._ballId)
		end)
	end

	self._parentChanged = ball:GetPropertyChangedSignal("Parent"):Connect(function()
		if not self.ball.Parent then
			self:Destroy()
		elseif self.ball:IsDescendantOf(workspace) then
			announceToClients()
		end
	end)

	if ball:IsDescendantOf(workspace) then
		announceToClients()
	end

	self:Enable()
	return self
end

function Server:_applyOwnerChange(old: Player?, new: Player?)
	if not old and new then
		-- Server -> Client: hand simulation to the owning client.
		replication:FireClient(new, self.ball, "Start", self._ballId)
		self._simulator:Disable()
	elseif old and not new then
		-- Client -> Server: reclaim simulation.
		replication:FireClient(old, self.ball, "End", self._ballId)
		self._simulator:Enable()
	else
		-- Client -> Client: transfer without a server gap.
		replication:FireClient(old :: Player, self.ball, "End", self._ballId)
		replication:FireClient(new :: Player, self.ball, "Start", self._ballId)
	end
end

function Server:Enable()
	self:Disable()
	self._simulator:Enable()

	self._heartbeat = RunService.Heartbeat:Connect(function()
		-- GetNetworkOwner returns nil when the server controls the part.
		local actual: Player? = if self.ball:CanSetNetworkOwnership() then self.ball:GetNetworkOwner() else nil

		if actual ~= self._owner then
			local prev = self._owner
			self._owner = actual
			self:_applyOwnerChange(prev, actual)
		end
	end)
end

function Server:Disable()
	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end
end

function Server:Destroy()
	self:Disable()

	if self._parentChanged then
		self._parentChanged:Disconnect()
		self._parentChanged = nil
	end

	if self._playerAdded then
		self._playerAdded:Disconnect()
		self._playerAdded = nil
	end

	self._simulator:Destroy()
	self.ball = nil :: any
end

return Server
