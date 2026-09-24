-- Short-lived server VFX. Everything is anchored, non-colliding and cleaned up by Debris.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Effects = {}

local folder: Folder
local function getFolder(): Folder
	if not folder or not folder.Parent then
		folder = workspace:FindFirstChild("Effects") :: Folder
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Effects"
			folder.Parent = workspace
		end
	end
	return folder
end

local function fxPart(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	if shape then
		p.Shape = shape
	end
	return p
end

function Effects.Burst(position: Vector3, color: Color3, radius: number, duration: number?)
	local d = duration or 0.45
	local p = fxPart(Vector3.new(1, 1, 1), color, Enum.PartType.Ball)
	p.Transparency = 0.25
	p.Position = position
	p.Parent = getFolder()
	TweenService:Create(p, TweenInfo.new(d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, d + 0.1)
end

-- Returns travel time so the caller can apply damage on arrival.
function Effects.Projectile(from: Vector3, to: Vector3, color: Color3, speed: number, size: number?): number
	local dist = (to - from).Magnitude
	local t = math.max(0.05, dist / speed)
	local p = fxPart(Vector3.new(1, 1, 1) * (size or 1.2), color, Enum.PartType.Ball)
	p.Position = from
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Parent = p
	p.Parent = getFolder()
	TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Linear), { Position = to }):Play()
	Debris:AddItem(p, t + 0.05)
	return t
end

-- Flat danger zone on the ground. shape "Disc" uses size.X as radius; "Rect" uses size as (width, length).
function Effects.Telegraph(center: Vector3, shape: string, size: Vector2, duration: number, facing: Vector3?)
	local p
	if shape == "Disc" then
		p = fxPart(Vector3.new(0.2, size.X * 2, size.X * 2), Color3.fromRGB(255, 40, 40), Enum.PartType.Cylinder)
		p.CFrame = CFrame.new(center.X, 0.15, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	else
		p = fxPart(Vector3.new(size.X, 0.2, size.Y), Color3.fromRGB(255, 40, 40))
		local flat = Vector3.new(center.X, 0.15, center.Z)
		local dir = facing or Vector3.new(0, 0, -1)
		p.CFrame = CFrame.lookAt(flat, flat + Vector3.new(dir.X, 0, dir.Z))
	end
	p.Transparency = 0.75
	p.Parent = getFolder()
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.3 }):Play()
	Debris:AddItem(p, duration)
end

function Effects.Spikes(origin: Vector3, direction: Vector3, length: number, color: Color3)
	local dir = Vector3.new(direction.X, 0, direction.Z).Unit
	local count = math.floor(length / 5)
	for i = 1, count do
		local pos = origin + dir * (i * 5)
		local spike = Instance.new("WedgePart")
		spike.Anchored = true
		spike.CanCollide = false
		spike.CanQuery = false
		spike.CanTouch = false
		spike.Material = Enum.Material.Wood
		spike.Color = color
		spike.Size = Vector3.new(2.5, 0.1, 3)
		spike.CFrame = CFrame.lookAt(Vector3.new(pos.X, 0, pos.Z), Vector3.new(pos.X, 0, pos.Z) + dir)
		spike.Parent = getFolder()
		task.delay(i * 0.03, function()
			TweenService:Create(spike, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
				Size = Vector3.new(2.5, 6, 3),
				CFrame = CFrame.lookAt(Vector3.new(pos.X, 3, pos.Z), Vector3.new(pos.X, 3, pos.Z) + dir),
			}):Play()
		end)
		Debris:AddItem(spike, 1.2)
	end
end

function Effects.DamageNumber(position: Vector3, amount: number, color: Color3?)
	Effects.FloatText(position, tostring(math.floor(amount + 0.5)), color)
end

function Effects.FloatText(position: Vector3, text: string, color: Color3?)
	local anchor = fxPart(Vector3.new(0.1, 0.1, 0.1), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	anchor.Position = position + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.StudsOffset = Vector3.new(0, 1, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = anchor
	anchor.Parent = getFolder()
	TweenService:Create(gui, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.75)
end

-- Fade and destroy a model built by Shared/Models.
function Effects.FadeOut(model: Model, duration: number?)
	local d = duration or 0.35
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			TweenService:Create(part, TweenInfo.new(d), { Transparency = 1 }):Play()
		elseif part:IsA("ParticleEmitter") or part:IsA("Fire") or part:IsA("Sparkles") then
			part.Enabled = false
		end
	end
	Debris:AddItem(model, d + 0.05)
end

return Effects
