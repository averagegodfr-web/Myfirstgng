-- Smooth server-driven movement. Instead of teleporting an anchored part every frame (which looks
-- choppy on clients), the model is unanchored and pulled toward a goal by AlignPosition/AlignOrientation.
-- Roblox replicates and interpolates physics, so everyone sees smooth motion.
local Mover = {}

export type Mover = {
	Root: BasePart,
	Position: AlignPosition,
	Orientation: AlignOrientation,
}

function Mover.Attach(model: Model, responsiveness: number?): Mover
	local root = model.PrimaryPart :: BasePart
	root.Anchored = false
	root.Massless = false
	root.CanCollide = false
	root.CanTouch = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "MoverAttachment"
	attachment.Parent = root

	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = math.huge
	align.MaxVelocity = math.huge
	align.Responsiveness = responsiveness or 35
	align.Position = root.Position
	align.Parent = root

	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = math.huge
	orient.MaxAngularVelocity = math.huge
	orient.Responsiveness = (responsiveness or 35) * 0.7
	orient.CFrame = root.CFrame - root.Position
	orient.Parent = root

	return { Root = root, Position = align, Orientation = orient }
end

-- Call after the model is parented to Workspace so the server keeps authority over the physics.
function Mover.Claim(mover: Mover)
	pcall(function()
		mover.Root:SetNetworkOwner(nil)
	end)
end

function Mover.Set(mover: Mover, position: Vector3, facing: Vector3?)
	mover.Position.Position = position
	if facing and facing.Magnitude > 0.01 then
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude > 0.01 then
			mover.Orientation.CFrame = CFrame.lookAt(Vector3.zero, flat)
		end
	end
end

-- Instantly move (spawns, revives, leash snaps).
function Mover.Teleport(mover: Mover, position: Vector3, facing: Vector3?)
	Mover.Set(mover, position, facing)
	mover.Root.CFrame = CFrame.new(position) * mover.Orientation.CFrame.Rotation
	mover.Root.AssemblyLinearVelocity = Vector3.zero
	Mover.Claim(mover)
end

return Mover
