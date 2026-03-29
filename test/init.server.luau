--[[
	Test runner for BallPhysics.

	Each .spec child module is required and executed.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestEZ = require(ReplicatedStorage.Packages.TestEZ)

TestEZ.TestBootstrap:run(script:GetChildren())
