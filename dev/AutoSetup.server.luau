--!strict
--[[
	Tracks all BaseParts tagged with Config.ballTag in CollectionService and
	automatically creates and destroys Server handlers as they are added/removed.
--]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPhysics = require(ReplicatedStorage.BallPhysics)
local Config = require(ReplicatedStorage.BallPhysics.Config)

local handlers: { [BasePart]: { Destroy: (self: any) -> () } } = {}

local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local ball: BasePart = instance
	if handlers[ball] then
		return
	end

	local success, result = pcall(BallPhysics.new, ball)
	if success then
		handlers[ball] = result
	else
		warn("BallPhysics AutoSetup: failed to track", ball, "-", result)
	end
end

local function untrack(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local ball = instance :: BasePart
	local handler = handlers[ball]
	if handler then
		handler:Destroy()
		handlers[ball] = nil
	end
end

for _, instance in CollectionService:GetTagged(Config.ballTag) do
	task.spawn(track, instance)
end

CollectionService:GetInstanceAddedSignal(Config.ballTag):Connect(track)
CollectionService:GetInstanceRemovedSignal(Config.ballTag):Connect(untrack)
