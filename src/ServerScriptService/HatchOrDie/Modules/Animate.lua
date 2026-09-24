-- Plays designer animations on custom models. Put Animation objects named Idle, Walk, Attack
-- and/or Ability anywhere inside a creature or enemy model (rigged with Motor6Ds). Missing ones are skipped.
local Animate = {}

export type Controller = {
	Tracks: { [string]: AnimationTrack },
	Moving: boolean?,
}

function Animate.Setup(model: Model): Controller?
	local animations = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Animation") and (d.Name == "Idle" or d.Name == "Walk" or d.Name == "Attack" or d.Name == "Ability") then
			animations[d.Name] = d
		end
	end
	if next(animations) == nil then
		return nil
	end
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
		local host = humanoid or model:FindFirstChildWhichIsA("AnimationController", true)
		if not host then
			host = Instance.new("AnimationController")
			host.Parent = model
		end
		animator = Instance.new("Animator")
		animator.Parent = host
	end
	local controller: Controller = { Tracks = {}, Moving = nil }
	for name, animation in animations do
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = name == "Idle" or name == "Walk"
			controller.Tracks[name] = track
		end
	end
	return controller
end

function Animate.SetMoving(controller: Controller?, moving: boolean)
	if not controller or controller.Moving == moving then
		return
	end
	controller.Moving = moving
	local walk, idle = controller.Tracks.Walk, controller.Tracks.Idle
	if moving then
		if idle then
			idle:Stop(0.2)
		end
		if walk then
			walk:Play(0.2)
		end
	else
		if walk then
			walk:Stop(0.2)
		end
		if idle then
			idle:Play(0.2)
		end
	end
end

function Animate.Play(controller: Controller?, name: string)
	local track = controller and controller.Tracks[name]
	if track then
		track:Play(0.05)
	end
end

return Animate
