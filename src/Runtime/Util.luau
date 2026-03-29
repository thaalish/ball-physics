--!strict
--[[
	Shared helpers used across the Runtime modules.

	Not part of the public API - use BallPhysics from init.luau instead.
--]]

-- Small buffer below the ball bottom for ground detection raycasts.
local RAYCAST_BUFFER = 0.01

local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

-- Returns true when `part` has ground directly beneath it.
local function isTouchingGround(part: BasePart): boolean
	RAYCAST_PARAMS.FilterDescendantsInstances = { part }
	return workspace:Raycast(part.Position, Vector3.new(0, -(part.Size.Y / 2 + RAYCAST_BUFFER), 0), RAYCAST_PARAMS)
		~= nil
end

-- Finds or creates the PhysicsRoot Attachment at the centre of `ball`.
local function getOrCreateAttachment(ball: BasePart): Attachment
	for _, child in ball:GetChildren() do
		if child:IsA("Attachment") and child.Name == "PhysicsRoot" then
			return child :: Attachment
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PhysicsRoot"
	attachment.Parent = ball
	return attachment
end

return {
	isTouchingGround = isTouchingGround,
	getOrCreateAttachment = getOrCreateAttachment,
}
