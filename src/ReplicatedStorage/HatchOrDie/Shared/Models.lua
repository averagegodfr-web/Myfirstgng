-- Builds creature / enemy / egg models.
-- 1) If ReplicatedStorage.HatchOrDieAssets has a custom model for it, that model is used.
-- 2) Otherwise a procedural model is built from parts (so the game works with zero assets).
-- Every returned model has an invisible "Root" PrimaryPart that everything else is welded to.
-- Attributes: HipHeight (root height above ground), Radius, Top (height of the top above root), Scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = script.Parent.Parent.Config
local CreatureData = require(Config.CreatureData)
local EnemyData = require(Config.EnemyData)
local EggData = require(Config.EggData)

local Models = {}

local function newPart(size: Vector3, color: Color3, material: Enum.Material?, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = newPart(size, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function wedge(size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return newPart(size, color, material, "WedgePart")
end

local function makeModel(name: string, queryable: boolean)
	local model = Instance.new("Model")
	model.Name = name
	local root = newPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1))
	root.Name = "Root"
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local function add(part: BasePart, offset: CFrame, name: string?): BasePart
		part.CFrame = offset
		part.CanQuery = queryable
		if name then
			part.Name = name
		end
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	return model, root, add
end

-- Highest point above the root, computed from part CFrames (works before the model is parented).
local function setTop(model: Model)
	local top = 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			top = math.max(top, part.CFrame.Position.Y + part.Size.Y / 2)
		end
	end
	model:SetAttribute("Top", top)
end

local function particles(parent: Instance, color: Color3, size: number, rate: number, speed: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Rate = rate
	e.Speed = NumberRange.new(speed or 1.5, (speed or 1.5) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = parent
	return e
end

---------------------------------------------------------------------------------------------------
-- Creatures
---------------------------------------------------------------------------------------------------
local function proceduralCreature(record): Model
	local fam = CreatureData.Families[record.Family] or CreatureData.Families.Sprout
	local stageIndex = math.clamp(record.Stage or 1, 1, #CreatureData.Stages)
	local s = CreatureData.Stages[stageIndex].Scale
	local mut = record.Mutation and CreatureData.MutationById[record.Mutation]

	local primary, secondary, accent = fam.Primary, fam.Secondary, fam.Accent
	local eyeColor = fam.EyeColor
	local bodyMaterial = Enum.Material.SmoothPlastic
	local accentMaterial = Enum.Material.SmoothPlastic
	if mut then
		primary = primary:Lerp(mut.Color, 0.65)
		secondary = secondary:Lerp(mut.Color, 0.35)
		accent = mut.Color
		accentMaterial = Enum.Material.Neon
		eyeColor = mut.Color
		if mut.Id == "Crystal" then
			bodyMaterial = Enum.Material.Glass
		elseif mut.Id == "Void" then
			primary = Color3.fromRGB(35, 10, 60)
			secondary = Color3.fromRGB(15, 5, 30)
		elseif mut.Id == "Celestial" then
			primary = Color3.fromRGB(255, 250, 235)
			secondary = Color3.fromRGB(255, 225, 150)
		end
	end
	local eyeMaterial = if mut or fam.Body == "Wolf" then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local model, root, add = makeModel(record.Family, false)
	local bodySize = Vector3.new(2.2, 1.7, 2.8) * s
	local legLen = 0.6 * s
	local hip = bodySize.Y / 2 + legLen

	local function tinted(part: BasePart): BasePart
		part:SetAttribute("Tint", true)
		return part
	end

	tinted(add(ellipsoid(bodySize, primary, bodyMaterial), CFrame.new(), "Body"))
	add(ellipsoid(bodySize * Vector3.new(0.8, 0.65, 0.85), secondary), CFrame.new(0, -0.3 * s, 0), "Belly")

	local headCF = CFrame.new(0, 0.75 * s, -1.55 * s)
	tinted(add(ellipsoid(Vector3.new(1.7, 1.5, 1.6) * s, primary, bodyMaterial), headCF, "Head"))

	for _, x in { -0.42, 0.42 } do
		add(ellipsoid(Vector3.new(0.45, 0.55, 0.3) * s, Color3.new(1, 1, 1)), headCF * CFrame.new(x * s, 0.18 * s, -0.66 * s))
		add(ellipsoid(Vector3.new(0.24, 0.32, 0.2) * s, eyeColor, eyeMaterial), headCF * CFrame.new(x * s, 0.18 * s, -0.78 * s), "Eye")
	end

	local legHeight = legLen + 0.4 * s
	for _, off in { Vector2.new(-0.7, -0.8), Vector2.new(0.7, -0.8), Vector2.new(-0.7, 0.8), Vector2.new(0.7, 0.8) } do
		add(
			newPart(Vector3.new(0.45, legHeight, 0.45) * Vector3.new(s, 1, s), secondary),
			CFrame.new(off.X * s, -hip + legHeight / 2, off.Y * s)
		)
	end

	if fam.Body == "Lizard" then
		tinted(add(ellipsoid(Vector3.new(0.8, 0.7, 2.4) * s, primary, bodyMaterial), CFrame.new(0, -0.1 * s, 2.1 * s) * CFrame.Angles(math.rad(12), 0, 0), "Tail"))
		for i, z in { -0.6, 0.2, 1.0 } do
			local h = (0.75 - i * 0.1) * s
			add(wedge(Vector3.new(0.18 * s, h, 0.7 * s), accent, accentMaterial), CFrame.new(0, bodySize.Y / 2 + h / 2 - 0.15 * s, z * s))
		end
	elseif fam.Body == "Fox" then
		add(ellipsoid(Vector3.new(0.8, 0.6, 0.9) * s, secondary), headCF * CFrame.new(0, -0.25 * s, -0.75 * s), "Snout")
		for _, x in { -0.45, 0.45 } do
			add(wedge(Vector3.new(0.2, 0.75, 0.55) * s, primary), headCF * CFrame.new(x * s, 0.85 * s, 0) * CFrame.Angles(0, math.rad(180), 0))
		end
		local tailCF = CFrame.new(0, 0.4 * s, 2.0 * s) * CFrame.Angles(math.rad(35), 0, 0)
		tinted(add(ellipsoid(Vector3.new(1.0, 1.0, 2.3) * s, primary, bodyMaterial), tailCF, "Tail"))
		local tip = add(ellipsoid(Vector3.new(0.8, 0.8, 0.9) * s, accent, Enum.Material.Neon), tailCF * CFrame.new(0, 0, 1.1 * s), "TailTip")
		local fire = Instance.new("Fire")
		fire.Size = 2 * s
		fire.Heat = 3
		fire.Color = accent
		fire.SecondaryColor = primary
		fire.Parent = tip
	elseif fam.Body == "Wolf" then
		add(newPart(Vector3.new(0.7, 0.55, 0.9) * s, secondary), headCF * CFrame.new(0, -0.25 * s, -0.8 * s), "Snout")
		for _, x in { -0.45, 0.45 } do
			add(wedge(Vector3.new(0.2, 0.9, 0.5) * s, secondary), headCF * CFrame.new(x * s, 0.9 * s, 0.1 * s) * CFrame.Angles(0, math.rad(180), 0))
		end
		add(ellipsoid(Vector3.new(2.0, 1.6, 1.0) * s, secondary), CFrame.new(0, 0.35 * s, -0.9 * s), "Mane")
		tinted(add(ellipsoid(Vector3.new(0.6, 0.6, 2.2) * s, primary, bodyMaterial), CFrame.new(0, 0.1 * s, 2.0 * s) * CFrame.Angles(math.rad(20), 0, 0), "Tail"))
	end

	-- Teen+: back spikes
	if stageIndex >= 2 then
		for i = 1, 3 do
			local z = -0.9 + i * 0.5
			add(wedge(Vector3.new(0.15, 0.55, 0.5) * s, accent, accentMaterial), CFrame.new(0.55 * s, bodySize.Y / 2 - 0.1 * s, z * s) * CFrame.Angles(0, 0, math.rad(-25)))
			add(wedge(Vector3.new(0.15, 0.55, 0.5) * s, accent, accentMaterial), CFrame.new(-0.55 * s, bodySize.Y / 2 - 0.1 * s, z * s) * CFrame.Angles(0, 0, math.rad(25)))
		end
	end

	-- Adult: wings + horns + glow
	if stageIndex >= 3 then
		for _, side in { -1, 1 } do
			local wingCF = CFrame.new(side * 1.1 * s, 0.7 * s, 0.1 * s) * CFrame.Angles(0, 0, math.rad(side * -35))
			tinted(add(newPart(Vector3.new(2.6, 0.15, 1.8) * s, primary, bodyMaterial), wingCF * CFrame.new(side * 1.2 * s, 0, 0), "Wing"))
			add(newPart(Vector3.new(2.2, 0.17, 0.35) * s, accent, accentMaterial), wingCF * CFrame.new(side * 1.2 * s, 0.02 * s, -0.8 * s))
			add(wedge(Vector3.new(0.2, 0.8, 0.35) * s, accent, accentMaterial), headCF * CFrame.new(side * 0.4 * s, 0.9 * s, 0.35 * s) * CFrame.Angles(math.rad(-25), 0, 0))
		end
		local glow = Instance.new("PointLight")
		glow.Color = accent
		glow.Range = 10 * s
		glow.Brightness = 1
		glow.Parent = root
	end

	-- Mutation flair
	if mut then
		particles(root, mut.Color, 0.35 * s, 8)
		if mut.Id == "Celestial" then
			local halo = newPart(Vector3.new(0.15, 1.6 * s, 1.6 * s), Color3.fromRGB(255, 225, 120), Enum.Material.Neon)
			halo.Shape = Enum.PartType.Cylinder
			add(halo, headCF * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), "Halo")
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = Color3.fromRGB(255, 240, 180)
			sparkles.Parent = root
		elseif mut.Id == "Inferno" then
			local fire = Instance.new("Fire")
			fire.Size = 3 * s
			fire.Color = Color3.fromRGB(255, 90, 20)
			fire.SecondaryColor = Color3.fromRGB(255, 220, 60)
			fire.Parent = root
		elseif mut.Id == "Void" then
			particles(root, Color3.fromRGB(20, 0, 40), 0.8 * s, 10, 0.5)
		end
	end

	if record.Aura then
		local aura = CreatureData.Auras[record.Aura]
		if aura then
			local e = particles(root, aura.Color, 0.7 * s, 16, 2)
			e.Name = "Aura"
			local light = Instance.new("PointLight")
			light.Name = "AuraLight"
			light.Color = aura.Color
			light.Range = 8 * s
			light.Brightness = 1.5
			light.Parent = root
		end
	end

	model:SetAttribute("HipHeight", hip)
	model:SetAttribute("Radius", 1.4 * s)
	setTop(model)
	model:SetAttribute("Scale", s)
	return model
end

---------------------------------------------------------------------------------------------------
-- Enemies
---------------------------------------------------------------------------------------------------
local function proceduralEnemy(typeId: string, variantId: string?): Model
	local data = EnemyData.Types[typeId]
	local variant = EnemyData.Variants[variantId or "Normal"] or EnemyData.Variants.Normal
	local k = variant.Scale or 1
	local body = data.Color
	local eye = data.EyeColor
	if variant.Tint then
		body = body:Lerp(variant.Tint, 0.25)
		eye = variant.Tint
	end
	local dark = body:Lerp(Color3.new(0, 0, 0), 0.4)

	local model, _, add = makeModel(typeId, true)
	local hip, radius

	if data.Shape == "Crawler" then
		local legLen = 0.9 * k
		local size = Vector3.new(3, 1.4, 3.8) * k
		hip = size.Y / 2 + legLen
		radius = 2 * k
		add(ellipsoid(size, body), CFrame.new(), "Body")
		add(ellipsoid(Vector3.new(1.8, 1.1, 1.4) * k, dark), CFrame.new(0, 0.1 * k, -2 * k), "Head")
		for _, x in { -0.45, -0.15, 0.15, 0.45 } do
			add(ellipsoid(Vector3.new(0.25, 0.25, 0.2) * k, eye, Enum.Material.Neon), CFrame.new(x * k, 0.3 * k, -2.65 * k), "Eye")
		end
		for _, z in { -1, 0, 1 } do
			for _, side in { -1, 1 } do
				add(newPart(Vector3.new(2.2 * k, 0.3 * k, 0.3 * k), dark), CFrame.new(side * 1.6 * k, -0.6 * k, z * k) * CFrame.Angles(0, 0, math.rad(side * 35)))
			end
		end
	elseif data.Shape == "Hunter" then
		local legLen = 1.6 * k
		local size = Vector3.new(1.8, 3.2, 1.4) * k
		hip = size.Y / 2 + legLen
		radius = 1.5 * k
		add(newPart(size, body), CFrame.new() * CFrame.Angles(math.rad(-10), 0, 0), "Body")
		add(ellipsoid(Vector3.new(1.6, 1.4, 1.6) * k, dark), CFrame.new(0, 2.2 * k, -0.4 * k), "Head")
		add(ellipsoid(Vector3.new(0.7, 0.7, 0.4) * k, eye, Enum.Material.Neon), CFrame.new(0, 2.25 * k, -1.15 * k), "Eye")
		for _, side in { -1, 1 } do
			add(newPart(Vector3.new(0.4, 3.2, 0.4) * k, dark), CFrame.new(side * 1.2 * k, 0, -0.3 * k) * CFrame.Angles(math.rad(-15), 0, 0))
			add(newPart(Vector3.new(0.5 * k, legLen + 0.5 * k, 0.5 * k), dark), CFrame.new(side * 0.5 * k, -hip + (legLen + 0.5 * k) / 2, 0))
		end
	elseif data.Shape == "Brute" then
		local legLen = 2.2 * k
		local size = Vector3.new(5, 4.5, 3.8) * k
		hip = size.Y / 2 + legLen
		radius = 3 * k
		add(newPart(size, body, Enum.Material.Slate), CFrame.new(), "Body")
		add(newPart(Vector3.new(2.2, 1.8, 2) * k, dark), CFrame.new(0, 2.8 * k, -0.9 * k), "Head")
		for _, x in { -0.5, 0.5 } do
			add(newPart(Vector3.new(0.4, 0.3, 0.2) * k, eye, Enum.Material.Neon), CFrame.new(x * k, 2.95 * k, -1.95 * k), "Eye")
		end
		for _, side in { -1, 1 } do
			add(newPart(Vector3.new(1.8, 4.8, 1.8) * k, body, Enum.Material.Slate), CFrame.new(side * 3.4 * k, -0.6 * k, -0.4 * k), "Arm")
			add(newPart(Vector3.new(1.6 * k, legLen + 0.6 * k, 1.6 * k), dark), CFrame.new(side * 1.3 * k, -hip + (legLen + 0.6 * k) / 2, 0))
		end
	else -- Colossus boss
		local legLen = 6 * k
		local size = Vector3.new(8, 14, 7) * k
		hip = size.Y / 2 + legLen
		radius = 6 * k
		add(newPart(size, body, Enum.Material.Wood), CFrame.new(), "Body")
		add(newPart(Vector3.new(8.4, 3, 7.4) * k, Color3.fromRGB(70, 110, 45), Enum.Material.Grass), CFrame.new(0, 4 * k, 0), "Moss")
		add(newPart(Vector3.new(6, 5, 5.5) * k, dark, Enum.Material.Wood), CFrame.new(0, 9 * k, -0.6 * k), "Head")
		for _, x in { -1.4, 1.4 } do
			add(ellipsoid(Vector3.new(1.2, 0.9, 0.4) * k, eye, Enum.Material.Neon), CFrame.new(x * k, 9.6 * k, -3.4 * k), "Eye")
		end
		local core = add(ellipsoid(Vector3.new(2.8, 2.8, 1.2) * k, Color3.fromRGB(60, 90, 40), Enum.Material.SmoothPlastic), CFrame.new(0, 1 * k, -3.6 * k), "Core")
		local coreLight = Instance.new("PointLight")
		coreLight.Name = "CoreLight"
		coreLight.Color = eye
		coreLight.Range = 0
		coreLight.Brightness = 4
		coreLight.Parent = core
		for _, side in { -1, 1 } do
			add(newPart(Vector3.new(3, 12, 3) * k, body, Enum.Material.Wood), CFrame.new(side * 5.6 * k, -1.5 * k, -0.5 * k) * CFrame.Angles(0, 0, math.rad(side * 8)), "Arm")
			add(newPart(Vector3.new(3.2 * k, legLen + 1 * k, 3.2 * k), dark, Enum.Material.Wood), CFrame.new(side * 2.4 * k, -hip + (legLen + 1 * k) / 2, 0))
			add(newPart(Vector3.new(1, 6, 1) * k, dark, Enum.Material.Wood), CFrame.new(side * 2 * k, 13 * k, 0) * CFrame.Angles(0, 0, math.rad(side * -30)))
		end
	end

	model:SetAttribute("HipHeight", hip)
	model:SetAttribute("Radius", radius)
	setTop(model)
	return model
end

---------------------------------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------------------------------
local function proceduralEgg(eggId: string): Model
	local egg = EggData[eggId] or EggData.ForestEgg
	local model, root, add = makeModel(eggId, false)
	add(ellipsoid(Vector3.new(2, 2.6, 2), egg.Color), CFrame.new(), "Shell")

	local spotMaterial = if egg.NeonSpots then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local spots = { { 0, 0.5 }, { 1.3, -0.1 }, { 2.5, 0.35 }, { 3.7, -0.4 }, { 4.9, 0.15 }, { 5.8, 0.7 } }
	for _, spot in spots do
		local a, y = spot[1], spot[2]
		local r = math.sqrt(math.max(0, 1 - (y / 1.3) ^ 2)) * 0.97
		local pos = Vector3.new(r * math.cos(a), y, r * math.sin(a))
		add(ellipsoid(Vector3.new(0.55, 0.45, 0.2), egg.SpotColor, spotMaterial), CFrame.lookAt(pos, pos * 2))
	end

	local light = Instance.new("PointLight")
	light.Color = egg.Color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = root

	model:SetAttribute("HipHeight", 1.3)
	model:SetAttribute("Radius", 1)
	return model
end

---------------------------------------------------------------------------------------------------
-- Custom assets (ReplicatedStorage.HatchOrDieAssets)
---------------------------------------------------------------------------------------------------
Models.ASSETS_NAME = "HatchOrDieAssets"

function Models.GetAsset(category: string, ...: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild(Models.ASSETS_NAME)
	local folder = assets and assets:FindFirstChild(category)
	if not folder then
		return nil
	end
	local current: Instance = folder
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local nextChild = current:FindFirstChild(name)
		if not nextChild then
			return nil
		end
		current = nextChild
	end
	if current == folder or current:IsA("Folder") then
		return nil
	end
	return current
end

local function hasInternalJoints(model: Instance): boolean
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") or d:IsA("Bone") then
			return true
		end
	end
	return false
end

-- Turns any designer model into a game-ready one: front = the model's pivot front (-Z / LookVector),
-- centered on a new invisible Root, everything welded, non-colliding, scripts removed.
function Models.PrepareCustom(template: Instance, scale: number?, queryable: boolean?): Model
	local clone = template:Clone()
	local model: Model
	if clone:IsA("Model") then
		model = clone
	else
		model = Instance.new("Model")
		model.Name = clone.Name
		clone.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("Humanoid") then
			d.EvaluateStateMachine = false
		end
	end
	local oldPrimary = model.PrimaryPart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Root" then
			d.Name = "Root_Original"
		end
	end
	if scale and scale ~= 1 then
		pcall(function()
			model:ScaleTo(model:GetScale() * scale)
		end)
	end
	model:PivotTo(CFrame.new())

	local boxCFrame, size = model:GetBoundingBox()
	local jointed = hasInternalJoints(model)
	local root = newPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1))
	root.Name = "Root"
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new(boxCFrame.Position)
	root.Parent = model

	local main = oldPrimary or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = queryable == true
			d.Massless = true
			if not jointed or d == main then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	model.PrimaryPart = root
	model:SetAttribute("HipHeight", size.Y / 2)
	model:SetAttribute("Radius", math.max(size.X, size.Z) / 2)
	model:SetAttribute("Top", size.Y / 2)
	model:SetAttribute("Custom", true)
	return model
end

local function tintMarked(model: Model, color: Color3, amount: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Tint") then
			d.Color = d.Color:Lerp(color, amount)
		end
	end
end

-- Mutation + aura visuals for custom creature models (procedural ones do this themselves).
local function applyCreatureFlair(model: Model, record, s: number)
	local root = model.PrimaryPart :: BasePart
	local mut = record.Mutation and CreatureData.MutationById[record.Mutation]
	if mut then
		tintMarked(model, mut.Color, 0.6)
		particles(root, mut.Color, 0.35 * s, 8)
		local light = Instance.new("PointLight")
		light.Color = mut.Color
		light.Range = 8 * s
		light.Parent = root
	end
	if record.Aura then
		local aura = CreatureData.Auras[record.Aura]
		if aura then
			local e = particles(root, aura.Color, 0.7 * s, 16, 2)
			e.Name = "Aura"
			local light = Instance.new("PointLight")
			light.Name = "AuraLight"
			light.Color = aura.Color
			light.Range = 8 * s
			light.Brightness = 1.5
			light.Parent = root
		end
	end
end

-- Creatures: Assets/Creatures/<Family>/<Stage>_<Mutation>, then <Stage> (Baby/Teen/Adult or 1/2/3),
-- then Assets/Creatures/<Family> as a single model scaled per stage.
function Models.BuildCreature(record): Model
	local stageIndex = math.clamp(record.Stage or 1, 1, #CreatureData.Stages)
	local stage = CreatureData.Stages[stageIndex]
	local family = record.Family
	local template, scale = nil, 1
	if record.Mutation then
		template = Models.GetAsset("Creatures", family, stage.Name .. "_" .. record.Mutation)
			or Models.GetAsset("Creatures", family, tostring(stageIndex) .. "_" .. record.Mutation)
	end
	template = template or Models.GetAsset("Creatures", family, stage.Name) or Models.GetAsset("Creatures", family, tostring(stageIndex))
	if not template then
		template = Models.GetAsset("Creatures", family)
		scale = stage.Scale
	end
	if not template then
		return proceduralCreature(record)
	end
	local model = Models.PrepareCustom(template, scale, false)
	model.Name = family
	model:SetAttribute("Scale", stage.Scale)
	applyCreatureFlair(model, record, stage.Scale)
	return model
end

-- Enemies: Assets/Enemies/<TypeId>_<Variant>, then Assets/Enemies/<TypeId> (scaled + tinted per variant).
function Models.BuildEnemy(typeId: string, variantId: string?): Model
	local vId = variantId or "Normal"
	local variant = EnemyData.Variants[vId] or EnemyData.Variants.Normal
	local template = Models.GetAsset("Enemies", typeId .. "_" .. vId)
	local scale = 1
	if not template then
		template = Models.GetAsset("Enemies", typeId)
		scale = variant.Scale or 1
	end
	if not template then
		return proceduralEnemy(typeId, variantId)
	end
	local model = Models.PrepareCustom(template, scale, true)
	model.Name = typeId
	if variant.Tint then
		tintMarked(model, variant.Tint, 0.5)
		local light = Instance.new("PointLight")
		light.Color = variant.Tint
		light.Range = 10
		light.Parent = model.PrimaryPart
	end
	return model
end

-- Eggs: Assets/Eggs/<EggId>.
function Models.BuildEgg(eggId: string): Model
	local template = Models.GetAsset("Eggs", eggId)
	if not template then
		return proceduralEgg(eggId)
	end
	local model = Models.PrepareCustom(template, 1, false)
	model.Name = eggId
	return model
end

-- Built-in versions, used by the asset exporter as editable starting points.
Models.Procedural = {
	Creature = proceduralCreature,
	Enemy = proceduralEnemy,
	Egg = proceduralEgg,
}

return Models
