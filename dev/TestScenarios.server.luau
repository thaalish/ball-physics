--!strict
--[[
	Listens on the "BallPhysicsTestScenarios" RemoteEvent for spawn requests
	fired by TestScenarios.client.luau.

	Each request supplies:
		scenarioIndex  number	- index into ScenarioData
		ownershipMode  string	- "server" | "client"

	The ball is spawned above the requesting player, velocities rotated to
	match their horizontal facing direction.  It auto-destroys after
	scenario.lifetime seconds.

	Network ownership:
		"server"	- server runs the Simulator (default Roblox ownership)
		"client"	- SetNetworkOwner(player) transfers simulation to the client;
	            	AutoSetup.server.luau will detect the ownership change and
	            	hand off via the replication RemoteEvent.
--]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BallPhysics.Config)
local scenarios = require(script.Parent.ScenarioData)

local BALL_COLOR = Color3.fromRGB(220, 60, 60)

local remote = Instance.new("RemoteEvent")
remote.Name = "BallPhysicsTestScenarios"
remote.Parent = ReplicatedStorage

remote.OnServerEvent:Connect(
	function(player: Player, scenarioIndex: number, ownershipMode: string, cameraForward: Vector3)
		if type(scenarioIndex) ~= "number" then
			return
		end
		if type(ownershipMode) ~= "string" then
			return
		end

		local scenario = scenarios[scenarioIndex]
		if not scenario then
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		-- Use the client-provided camera forward so the ball launches where the player is looking.
		-- Falls back to HumanoidRootPart LookVector if no valid vector was sent.
		local forward: Vector3
		do
			local src = if typeof(cameraForward) == "Vector3" and cameraForward.Magnitude > 0.5
				then cameraForward
				else (root :: BasePart).CFrame.LookVector
			local flat = Vector3.new(src.X, 0, src.Z)
			forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
		end

		-- Scenario convention: +Z = forward, +Y = up, +X = right.
		-- right = (forward.Z, 0, -forward.X) is the 90 deg clockwise perpendicular
		-- in the XZ plane (verified: facing +Z -> right = +X, facing +X -> right = -Z).
		local right = Vector3.new(forward.Z, 0, -forward.X)

		local function rotateToFacing(v: Vector3): Vector3
			return right * v.X + Vector3.yAxis * v.Y + forward * v.Z
		end

		local rotLinVel = rotateToFacing(scenario.linVel)
		local rotAngVel = rotateToFacing(scenario.angVel)

		local ball = Instance.new("Part")
		ball.Name = scenario.name
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(scenario.ballSize, scenario.ballSize, scenario.ballSize)
		ball.Color = BALL_COLOR
		ball.Material = Enum.Material.SmoothPlastic
		ball.CastShadow = false
		ball.Anchored = false
		ball.CFrame = root.CFrame:ToWorldSpace(CFrame.new(0, 0, -5))
		ball.Parent = workspace

		CollectionService:AddTag(ball, Config.ballTag)

		if ball:CanSetNetworkOwnership() then
			ball:SetNetworkOwner(ownershipMode == "client" and player or nil)
		end

		ball.AssemblyLinearVelocity = rotLinVel
		ball.AssemblyAngularVelocity = rotAngVel

		-- Auto-destroy after the scenario lifetime.
		task.delay(scenario.lifetime, function()
			if ball.Parent then
				ball:Destroy()
			end
		end)
	end
)
