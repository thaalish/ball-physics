--!strict
--[[
	Provides a GUI panel and keyboard shortcuts for launching test scenarios.

	Keybinds (only when the game hasn't consumed input):
		F4	- toggle the scenario panel open / closed
		0	- cycle ownership mode:  Server | Client
		1-5	- instantly launch that scenario with the current ownership mode

	The panel also has clickable buttons for each scenario and an ownership
	toggle you can click.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local scenarios = require(script.Parent.ScenarioData)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for the server to create this before connecting.
local remote = ReplicatedStorage:WaitForChild("BallPhysicsTestScenarios", 10) :: RemoteEvent?
if not remote then
	warn("BallPhysicsTestScenarios: RemoteEvent not found - TestScenarios.server.luau may not be running.")
	return
end

local ownershipMode: string = "client" -- "server" | "client"
local isPanelOpen: boolean = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BallPhysicsTests"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleBtn"
toggleButton.Size = UDim2.fromOffset(152, 26)
toggleButton.Position = UDim2.new(1, -160, 0, 8)
toggleButton.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
toggleButton.BorderSizePixel = 0
toggleButton.Text = "Physics Tests [F4] ▼"
toggleButton.TextColor3 = Color3.fromRGB(190, 190, 210)
toggleButton.TextSize = 11
toggleButton.Font = Enum.Font.Code
toggleButton.AutoButtonColor = true
toggleButton.Parent = screenGui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = toggleButton
end

local PANEL_W = 218

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(PANEL_W, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Position = UDim2.new(1, -(PANEL_W + 8), 0, 38)
panel.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ClipsDescendants = true
panel.Parent = screenGui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)
	layout.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = panel
end

-- Helper: full-width divider line
local function makeDivider(order: number)
	local divider = Instance.new("Frame")
	divider.LayoutOrder = order
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
	divider.BorderSizePixel = 0
	divider.Parent = panel
end

-- Title
do
	local titleLabel = Instance.new("TextLabel")
	titleLabel.LayoutOrder = 0
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "PHYSICS TESTS"
	titleLabel.TextColor3 = Color3.fromRGB(80, 190, 255)
	titleLabel.TextSize = 13
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel
end

makeDivider(1)

local ownerButton = Instance.new("TextButton")
ownerButton.Name = "OwnershipBtn"
ownerButton.LayoutOrder = 2
ownerButton.Size = UDim2.new(1, 0, 0, 32)
ownerButton.BackgroundTransparency = 1
ownerButton.TextSize = 12
ownerButton.Font = Enum.Font.Code
ownerButton.TextXAlignment = Enum.TextXAlignment.Left
ownerButton.AutoButtonColor = false
ownerButton.Parent = panel

makeDivider(3)

-- Returns the camera's horizontal look direction (unit vector, XZ plane).
-- Using the camera rather than HumanoidRootPart means the ball always
-- flies where the player is actually looking, even when strafing.
local function getCameraForward(): Vector3
	local look = workspace.CurrentCamera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, 1)
	end
	return flat.Unit
end

-- Scenario buttons
local scenarioButtons: { TextButton } = {}

for i, scenario in ipairs(scenarios) do
	local button = Instance.new("TextButton")
	button.Name = "Scenario" .. i
	button.LayoutOrder = 10 + i
	button.Size = UDim2.new(1, 0, 0, 42)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = panel

	-- Name line
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.fromOffset(0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = string.format("[%d]  %s", i, scenario.name)
	nameLabel.TextColor3 = Color3.fromRGB(215, 215, 228)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = button

	-- Description line
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, 0, 0, 14)
	descLabel.Position = UDim2.fromOffset(0, 24)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = "     " .. scenario.desc
	descLabel.TextColor3 = Color3.fromRGB(130, 130, 155)
	descLabel.TextSize = 11
	descLabel.Font = Enum.Font.Code
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = button

	-- Hover highlight
	button.MouseEnter:Connect(function()
		button.BackgroundTransparency = 0.82
		button.BackgroundColor3 = Color3.fromRGB(60, 110, 190)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundTransparency = 1
	end)

	button.Activated:Connect(function()
		remote:FireServer(i, ownershipMode, getCameraForward())
	end)

	scenarioButtons[i] = button
end

local function refreshOwnerButton()
	if ownershipMode == "server" then
		ownerButton.Text = "Ownership:  SERVER  (0 to toggle)"
		ownerButton.TextColor3 = Color3.fromRGB(255, 185, 50)
	else
		ownerButton.Text = "Ownership:  CLIENT  (0 to toggle)"
		ownerButton.TextColor3 = Color3.fromRGB(100, 210, 120)
	end
end

local function setPanel(isOpen: boolean)
	isPanelOpen = isOpen
	panel.Visible = isOpen
	toggleButton.Text = if isOpen then "Physics Tests [F4] ▲" else "Physics Tests [F4] ▼"
end

local function flashButton(index: number)
	local button = scenarioButtons[index]
	if not button then
		return
	end
	button.BackgroundTransparency = 0
	button.BackgroundColor3 = Color3.fromRGB(50, 160, 70)
	task.delay(0.18, function()
		button.BackgroundTransparency = 1
	end)
end

refreshOwnerButton()

toggleButton.Activated:Connect(function()
	setPanel(not isPanelOpen)
end)

ownerButton.Activated:Connect(function()
	ownershipMode = if ownershipMode == "server" then "client" else "server"
	refreshOwnerButton()
end)

local NUM_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F4 then
		setPanel(not isPanelOpen)
	elseif input.KeyCode == Enum.KeyCode.Zero then
		ownershipMode = if ownershipMode == "server" then "client" else "server"
		refreshOwnerButton()
	else
		local index = NUM_KEYS[input.KeyCode]
		if index then
			remote:FireServer(index, ownershipMode, getCameraForward())
			flashButton(index)
		end
	end
end)
