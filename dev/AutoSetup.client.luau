--[[
	Starts the Client singleton that listens for ownership events from the server
	and enables/disables local simulation accordingly.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallPhysics = require(ReplicatedStorage.BallPhysics)
BallPhysics.new()
