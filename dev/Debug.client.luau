--!strict
--[[
	Attaches a BillboardGui and SelectionBox to every tagged ball,
	showing live physics state: speed, velocity, spin, and network ownership.
	Optionally renders LineHandleAdornment arrows for force/velocity vectors.

	Press F3 to cycle through three modes:
		1 - Text + speed-coloured SelectionBox (default, matches previous behaviour)
		2 - Text + SelectionBox + vector arrows
		3 - Vector arrows only (no text)

	Arrow colours:
		Cyan	- linear velocity
		Orange	- Magnus force
		Purple	- Knuckleball force
		Green	- angular velocity (spin axis)

	To disable all overlays, set Config.debug.enabled = false.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.BallPhysics.Config)

if not Config.debug.enabled then
	return
end

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = require(ReplicatedStorage.BallPhysics.Runtime.Client)

-- Arrow scale constants - one stud of length per N units:
local VEL_SCALE: number = 1 / 15 -- 15 stud/s -> 1 stud
local FORCE_SCALE: number = 1 / 80 -- 80 N      -> 1 stud
local SPIN_SCALE: number = 1 / 40 -- 40 deg/s  -> 1 stud
local MAX_ARROW: number = 24 -- cap in stud/s

local COLOR_VEL = Color3.fromRGB(50, 220, 255) -- cyan
local COLOR_MAGNUS = Color3.fromRGB(255, 160, 30) -- orange
local COLOR_KNUCK = Color3.fromRGB(200, 80, 255) -- purple
local COLOR_SPIN = Color3.fromRGB(80, 255, 120) -- lime

local MODE_COUNT = 4
local MODE_NAMES = { "Text", "Text + Vectors", "Vectors Only", "Off" }
local debugMode = 1

type Arrows = {
	velocity: LineHandleAdornment,
	magnus: LineHandleAdornment,
	knuckle: LineHandleAdornment,
	spin: LineHandleAdornment,
}

type Entry = {
	billboard: BillboardGui,
	selection: SelectionBox,
	arrows: Arrows,
	lastUpdate: number,
}

local entries: { [BasePart]: Entry } = {}

local modeGui = Instance.new("ScreenGui")
modeGui.Name = "BallPhysicsDebugHUD"
modeGui.ResetOnSpawn = false
modeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
modeGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.fromOffset(600, 18)
modeLabel.Position = UDim2.new(0, 8, 1, -26)
modeLabel.AnchorPoint = Vector2.new(0, 1)
modeLabel.BackgroundTransparency = 1
modeLabel.RichText = true
modeLabel.TextSize = 11
modeLabel.Font = Enum.Font.Code
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Parent = modeGui

local function refreshModeLabel()
	local text =
		string.format("<font color='rgb(150,150,175)'>[F3] Debug Mode %d: %s</font>", debugMode, MODE_NAMES[debugMode])
	if debugMode == 2 or debugMode == 3 then
		text = text
			.. "    <font color='rgb(50,220,255)'>-- Vel</font>"
			.. "    <font color='rgb(255,160,30)'>-- Magnus</font>"
			.. "    <font color='rgb(200,80,255)'>-- Knuckle</font>"
			.. "    <font color='rgb(80,255,120)'>-- Spin</font>"
	end
	modeLabel.Text = text
end

refreshModeLabel()

local function makeArrow(ball: BasePart, color: Color3, thickness: number): LineHandleAdornment
	local adornment = Instance.new("LineHandleAdornment")
	adornment.Adornee = ball
	adornment.Length = 0
	adornment.Thickness = thickness
	adornment.Color3 = color
	adornment.CFrame = CFrame.new()
	adornment.Parent = ball
	return adornment
end

-- The arrow starts at the ball's surface so it isn't hidden inside the geometry.
local function setArrow(adornment: LineHandleAdornment, ball: BasePart, worldVec: Vector3, scale: number)
	local magnitude = worldVec.Magnitude
	if magnitude < 0.5 then
		adornment.Length = 0
		return
	end
	-- LineHandleAdornment CFrame is relative to its Adornee.
	local localDir = ball.CFrame:VectorToObjectSpace(worldVec / magnitude)
	local surfaceOrigin = localDir * (ball.Size.X / 2)
	adornment.CFrame = CFrame.new(surfaceOrigin, surfaceOrigin + localDir)
	adornment.Length = math.clamp(magnitude * scale, 1, MAX_ARROW)
end

local function hideArrows(arrows: Arrows)
	arrows.velocity.Length = 0
	arrows.magnus.Length = 0
	arrows.knuckle.Length = 0
	arrows.spin.Length = 0
end

local function addLabel(parent: Instance, order: number, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -8, 0, 16)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(210, 210, 210)
	label.TextSize = 11
	label.Font = Enum.Font.Code
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

local function buildEntry(ball: BasePart): Entry
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PhysicsDebug"
	billboard.Size = UDim2.fromOffset(230, 116)
	billboard.SizeOffset = Vector2.new(0, 0.6)
	billboard.StudsOffset = Vector3.new(0, ball.Size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = false
	billboard.Adornee = ball
	billboard.Parent = ball

	local background = Instance.new("Frame")
	background.Name = "BG"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	background.BackgroundTransparency = 0.25
	background.BorderSizePixel = 0
	background.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = background

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 7)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 7)
	padding.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = background

	local title = addLabel(background, 0, "Title")
	title.TextColor3 = Color3.fromRGB(80, 190, 255)
	title.Text = "[ " .. ball.Name .. " ]"

	addLabel(background, 1, "Speed")
	addLabel(background, 2, "LinVel")
	addLabel(background, 3, "Spin")
	addLabel(background, 4, "AngVel")
	addLabel(background, 5, "Owner")

	-- speed-coloured selection box
	local selection = Instance.new("SelectionBox")
	selection.Adornee = ball
	selection.Color3 = Color3.fromRGB(0, 160, 255)
	selection.LineThickness = 0.04
	selection.SurfaceTransparency = 0.88
	selection.SurfaceColor3 = Color3.fromRGB(0, 160, 255)
	selection.Parent = ball

	local arrows: Arrows = {
		velocity = makeArrow(ball, COLOR_VEL, 4),
		magnus = makeArrow(ball, COLOR_MAGNUS, 4),
		knuckle = makeArrow(ball, COLOR_KNUCK, 4),
		spin = makeArrow(ball, COLOR_SPIN, 4),
	}

	local isTextVisible = debugMode == 1 or debugMode == 2
	billboard.Enabled = isTextVisible
	if not isTextVisible then
		selection.Adornee = nil :: any
	end

	return { billboard = billboard, selection = selection, arrows = arrows, lastUpdate = 0 }
end

local function removeEntry(ball: BasePart)
	local entry = entries[ball]
	if not entry then
		return
	end
	entry.billboard:Destroy()
	entry.selection:Destroy()
	entry.arrows.velocity:Destroy()
	entry.arrows.magnus:Destroy()
	entry.arrows.knuckle:Destroy()
	entry.arrows.spin:Destroy()
	entries[ball] = nil
end

local function formatVector(vector: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", vector.X, vector.Y, vector.Z)
end

local function updateEntry(ball: BasePart, entry: Entry, now: number)
	local linVel = ball.AssemblyLinearVelocity
	local angVel = ball.AssemblyAngularVelocity

	if debugMode == 2 or debugMode == 3 then
		setArrow(entry.arrows.velocity, ball, linVel, VEL_SCALE)
		setArrow(entry.arrows.spin, ball, angVel, SPIN_SCALE)

		local magnusVF = ball:FindFirstChild("MagnusForce") :: VectorForce?
		if magnusVF then
			setArrow(entry.arrows.magnus, ball, magnusVF.Force, FORCE_SCALE)
		else
			entry.arrows.magnus.Length = 0
		end

		local knuckleVF = ball:FindFirstChild("KnuckleBall") :: VectorForce?
		if knuckleVF then
			setArrow(entry.arrows.knuckle, ball, knuckleVF.Force, FORCE_SCALE)
		else
			entry.arrows.knuckle.Length = 0
		end
	else
		hideArrows(entry.arrows)
	end

	-- Text labels are throttled (they don't need per-frame precision).
	if now - entry.lastUpdate < Config.debug.updateInterval then
		return
	end
	entry.lastUpdate = now

	if debugMode == 1 or debugMode == 2 then
		local background = entry.billboard:FindFirstChild("BG") :: Frame?
		if not background then
			return
		end

		local speed = linVel.Magnitude
		local spin = angVel.Magnitude

		local function set(name: string, text: string)
			local label = background:FindFirstChild(name) :: TextLabel?
			if label then
				label.Text = text
			end
		end

		set("Speed", string.format("Speed:  %.1f stud/s", speed))
		set("LinVel", "LinVel: " .. formatVector(linVel))
		set("Spin", string.format("Spin:   %.2f deg/s", spin))
		set("AngVel", "AngVel: " .. formatVector(angVel))

		local owned = Client.isOwned(ball)
		local ownerLabel = background:FindFirstChild("Owner") :: TextLabel?
		if ownerLabel then
			ownerLabel.Text = if owned then "Owner: LOCAL" else "Owner: SERVER"
			ownerLabel.TextColor3 = if owned then Color3.fromRGB(100, 255, 130) else Color3.fromRGB(180, 180, 180)
		end

		-- SelectionBox colour: blue (slow) -> red (fast)
		local colorFraction = math.clamp(speed / Config.debug.speedColorCeiling, 0, 1)
		entry.selection.Color3 =
			Color3.fromRGB(math.floor(255 * colorFraction), math.floor(160 * (1 - colorFraction) + 40 * colorFraction), math.floor(255 * (1 - colorFraction) + 40 * colorFraction))
	end
end

local function applyMode(ball: BasePart, entry: Entry)
	local isTextVisible = debugMode == 1 or debugMode == 2
	entry.billboard.Enabled = isTextVisible
	entry.selection.Adornee = if isTextVisible then ball else nil :: any
	if debugMode == 1 or debugMode == 4 then
		hideArrows(entry.arrows)
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F3 then
		debugMode = debugMode % MODE_COUNT + 1
		for ball, entry in entries do
			applyMode(ball, entry)
		end
		refreshModeLabel()
	end
end)

for _, instance in CollectionService:GetTagged(Config.ballTag) do
	if instance:IsA("BasePart") then
		entries[instance :: BasePart] = buildEntry(instance :: BasePart)
	end
end

CollectionService:GetInstanceAddedSignal(Config.ballTag):Connect(function(instance: Instance)
	if instance:IsA("BasePart") then
		entries[instance :: BasePart] = buildEntry(instance :: BasePart)
	end
end)

CollectionService:GetInstanceRemovedSignal(Config.ballTag):Connect(function(instance: Instance)
	if instance:IsA("BasePart") then
		removeEntry(instance :: BasePart)
	end
end)

RunService.Heartbeat:Connect(function()
	if debugMode == MODE_COUNT then
		return
	end

	local now = os.clock()
	for ball, entry in entries do
		if not ball.Parent then
			removeEntry(ball)
		else
			updateEntry(ball, entry, now)
		end
	end
end)
