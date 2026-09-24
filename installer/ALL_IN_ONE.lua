-- HATCH OR DIE - ALL-IN-ONE installer (map + all code). Paste into the Studio command bar.
do
-- HATCH OR DIE - installer PART 1 of 4: MAP + TORCH  (map v3)
-- Paste everything into the Roblox Studio command bar (View > Command Bar) and press Enter.
-- Re-running rebuilds the map from scratch (it replaces Workspace.Map and the Torch).
--
-- USE YOUR OWN MODELS: before running, put your models in ServerStorage like this:
--   ServerStorage
--   └── MapAssets        (Folder)
--       ├── Trees        (Folder)  any number of tree models   -> replaces the built-in trees
--       ├── Grass        (Folder)  grass clumps / tufts        -> scattered over the ground
--       ├── Rocks        (Folder)  rocks / boulders            -> replaces the built-in rocks
--       └── Decor        (Folder)  flowers, logs, bushes, etc. -> scattered around the forest
-- Every folder is optional. Put several variants in a folder and they get mixed randomly.
-- Scripts inside your models are removed from the copies (protects against free-model viruses).

-- How many of each to place (lower these if your models have lots of parts).
local TREE_COUNT = 190
local GRASS_COUNT = 350
local ROCK_COUNT = 40
local DECOR_COUNT = 90
local SCALE_VARIATION = { 0.85, 1.2 }

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local ServerStorage = game:GetService("ServerStorage")
local rng = Random.new(1337)

local CAMP = Vector3.new(0, 0, 0)
local CABIN = Vector3.new(150, 0, 70)
local CAVE = Vector3.new(165, 0, -150)
local RUINS = Vector3.new(-160, 0, -130)
local ARENA = Vector3.new(0, 0, 190)
local HIDDEN = Vector3.new(-235, 0, 165)
local MAP_RADIUS = 265

-- Clean up previous installs (your Baseplate is kept).
for _, name in { "Map", "Enemies", "Creatures", "Effects", "WorldEggs" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
for _, child in workspace:GetChildren() do
	if child:IsA("SpawnLocation") then
		child:Destroy()
	end
end
workspace.Terrain:Clear()

-- Ground: the studded Baseplate. Reuse the template's one, or make one if it's missing.
local baseplate = workspace:FindFirstChild("Baseplate")
if not baseplate then
	baseplate = Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Color = Color3.fromRGB(75, 151, 75)
	baseplate.Material = Enum.Material.Plastic
	baseplate.TopSurface = Enum.SurfaceType.Studs
	baseplate.Parent = workspace
end
baseplate.Anchored = true
baseplate.Locked = true
baseplate.Size = Vector3.new(math.max(baseplate.Size.X, 640), 16, math.max(baseplate.Size.Z, 640))
baseplate.CFrame = CFrame.new(0, -8, 0)

local Map = Instance.new("Model")
Map.Name = "Map"

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or Map
	return f
end

local function part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Class" and k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or Map
	return p
end

local function ball(parent, position, diameter, color, material)
	return part({ Parent = parent, Shape = Enum.PartType.Ball, Size = Vector3.new(diameter, diameter, diameter), Position = position, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

local function column(parent, position, height, diameter, color, material)
	return part({
		Parent = parent,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Wood,
	})
end

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function distToSegment(p, a, b)
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
	return (ap - ab * t).Magnitude
end

local POIS = {
	{ CAMP, 42 }, { CABIN, 30 }, { CAVE, 42 }, { RUINS, 38 }, { ARENA, 62 }, { HIDDEN, 36 },
}
local PATHS = { { CAMP, CABIN }, { CAMP, CAVE }, { CAMP, RUINS }, { CAMP, ARENA } }

local function isOpen(p, margin)
	for _, poi in POIS do
		if flatDist(p, poi[1]) < poi[2] + (margin or 0) then
			return false
		end
	end
	for _, path in PATHS do
		if distToSegment(p, path[1], path[2]) < 9 + (margin or 0) then
			return false
		end
	end
	return true
end

local function randomRingPoint(minR, maxR)
	local angle = rng:NextNumber() * math.pi * 2
	local r = rng:NextNumber(minR, maxR)
	return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

---------------------------------------------------------------------------------------------------
-- Your models (ServerStorage.MapAssets)
---------------------------------------------------------------------------------------------------
-- Forgiving lookup: MapAssets can be in ServerStorage, ReplicatedStorage, Workspace or Lighting,
-- names are case-insensitive, singular or plural both work, and models can be nested in sub-folders.
local function findChildLoose(parent, names)
	for _, child in parent:GetChildren() do
		local lower = child.Name:lower():gsub("%s", "")
		if table.find(names, lower) then
			return child
		end
	end
	return nil
end

local assetsFolder
for _, container in { ServerStorage, game:GetService("ReplicatedStorage"), workspace, game:GetService("Lighting") } do
	assetsFolder = findChildLoose(container, { "mapassets", "mapasset", "assets" })
	if assetsFolder then
		break
	end
end

local CATEGORY_NAMES = {
	Trees = { "trees", "tree" },
	Grass = { "grass", "grasses" },
	Rocks = { "rocks", "rock", "stones", "stone" },
	Decor = { "decor", "decors", "decoration", "decorations", "props", "prop" },
}

local function collectModels(container, out)
	for _, child in container:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(out, child)
		elseif child:IsA("Folder") then
			collectModels(child, out)
		end
	end
end

local function assetList(category)
	local list = {}
	local f = assetsFolder and findChildLoose(assetsFolder, CATEGORY_NAMES[category])
	if f then
		collectModels(f, list)
	end
	return list
end

local TREE_ASSETS = assetList("Trees")
local GRASS_ASSETS = assetList("Grass")
local ROCK_ASSETS = assetList("Rocks")
local DECOR_ASSETS = assetList("Decor")

if assetsFolder then
	print(("🔎 Found your assets at %s"):format(assetsFolder:GetFullName()))
	for _, child in assetsFolder:GetChildren() do
		local count = {}
		collectModels(child, count)
		print(("   - %s (%s): %d model(s)"):format(child.Name, child.ClassName, #count))
	end
	if assetsFolder:IsDescendantOf(workspace) then
		print("⚠️ Your MapAssets folder is in Workspace, so the originals are still visible in the world. Move it to ServerStorage.")
	end
else
	print("🔎 No MapAssets folder found in ServerStorage, ReplicatedStorage, Workspace or Lighting.")
end

-- Clones a random variant, anchors it, strips scripts, randomly rotates/scales it and sets it on the ground.
local function placeAsset(list, parent, position, decorative)
	local clone = list[rng:NextInteger(1, #list)]:Clone()
	local model = clone
	if clone:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = clone.Name
		clone.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			if decorative then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
	end
	pcall(function()
		model:ScaleTo(model:GetScale() * rng:NextNumber(SCALE_VARIATION[1], SCALE_VARIATION[2]))
	end)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, position.Y - bottom, 0))
	model.Parent = parent
	return model
end

local paths = folder("Paths")
for _, path in PATHS do
	local a, b = path[1], path[2]
	local mid = (a + b) / 2
	local length = flatDist(a, b)
	part({
		Parent = paths,
		Size = Vector3.new(9, 0.2, length),
		CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.05, mid.Z), Vector3.new(b.X, 0.05, b.Z)),
		Color = Color3.fromRGB(125, 100, 70),
		Material = Enum.Material.Ground,
		CanCollide = false,
	})
end

-- Invisible boundary
local bounds = folder("Bounds")
for _, spec in { { Vector3.new(0, 40, 290), Vector3.new(600, 80, 4) }, { Vector3.new(0, 40, -290), Vector3.new(600, 80, 4) }, { Vector3.new(290, 40, 0), Vector3.new(4, 80, 600) }, { Vector3.new(-290, 40, 0), Vector3.new(4, 80, 600) } } do
	part({ Parent = bounds, Position = spec[1], Size = spec[2], Transparency = 1, CanQuery = false })
end

---------------------------------------------------------------------------------------------------
-- Camp
---------------------------------------------------------------------------------------------------
local camp = folder("Camp")
part({ Parent = camp, Name = "CampCenter", Position = Vector3.new(0, 0.5, 0), Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false })
part({ Parent = camp, Name = "CampGround", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 70, 70), CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(125, 100, 70), Material = Enum.Material.Ground, CanCollide = false })

for i = 1, 10 do
	local a = i / 10 * math.pi * 2
	ball(camp, Vector3.new(math.cos(a) * 3.2, 0.4, math.sin(a) * 3.2), 1.4, Color3.fromRGB(110, 110, 115), Enum.Material.Slate)
end
for _, rot in { 0, 90 } do
	part({ Parent = camp, Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 0.8, 0.8), CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(rot + 45), 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
end
local fire = part({ Parent = camp, Name = "Campfire", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(0, 1.2, 0), Color = Color3.fromRGB(255, 140, 40), Material = Enum.Material.Neon, CanCollide = false })
local fireFx = Instance.new("Fire")
fireFx.Size = 7
fireFx.Heat = 12
fireFx.Parent = fire
local fireLight = Instance.new("PointLight")
fireLight.Range = 36
fireLight.Brightness = 2.5
fireLight.Color = Color3.fromRGB(255, 170, 90)
fireLight.Shadows = true
fireLight.Parent = fire

local spawn = Instance.new("SpawnLocation")
spawn.Name = "CampSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(10, 0.4, 10)
spawn.Position = Vector3.new(0, 0.2, 16)
spawn.Color = Color3.fromRGB(255, 205, 90)
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.6
spawn.CanCollide = true
spawn.Neutral = true
spawn.Duration = 2
spawn.Parent = camp

-- Tents
for _, spec in { { Vector3.new(-20, 0, -8), 30 }, { Vector3.new(20, 0, -10), -30 }, { Vector3.new(-22, 0, 14), 110 } } do
	local base = CFrame.new(spec[1]) * CFrame.Angles(0, math.rad(spec[2]), 0)
	local color = Color3.fromRGB(rng:NextInteger(150, 200), rng:NextInteger(80, 120), rng:NextInteger(50, 80))
	part({ Parent = camp, Class = "WedgePart", Size = Vector3.new(8, 6, 4), CFrame = base * CFrame.new(0, 3, -2), Color = color, Material = Enum.Material.Fabric })
	part({ Parent = camp, Class = "WedgePart", Size = Vector3.new(8, 6, 4), CFrame = base * CFrame.new(0, 3, 2) * CFrame.Angles(0, math.rad(180), 0), Color = color, Material = Enum.Material.Fabric })
end

-- Crates + incubator decor
for _, pos in { Vector3.new(8, 1.25, -18), Vector3.new(10.5, 1.25, -17), Vector3.new(9, 3.75, -17.5) } do
	part({ Parent = camp, Size = Vector3.new(2.5, 2.5, 2.5), Position = pos, Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
end
column(camp, Vector3.new(-12, 0, 2), 2, 5, Color3.fromRGB(90, 90, 100), Enum.Material.Slate)
local decoEgg = part({ Parent = camp, Size = Vector3.new(2.6, 3.4, 2.6), Position = Vector3.new(-12, 3.7, 2), Color = Color3.fromRGB(255, 230, 150), Material = Enum.Material.Neon, CanCollide = false })
local decoMesh = Instance.new("SpecialMesh")
decoMesh.MeshType = Enum.MeshType.Sphere
decoMesh.Parent = decoEgg

-- Shop stall + keeper
local stall = folder("ShopStall", camp)
local stallBase = CFrame.new(22, 0, 12) * CFrame.Angles(0, math.rad(-120), 0)
part({ Parent = stall, Size = Vector3.new(10, 3, 3), CFrame = stallBase * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(140, 95, 60), Material = Enum.Material.WoodPlanks })
for _, x in { -4.5, 4.5 } do
	part({ Parent = stall, Size = Vector3.new(0.6, 8, 0.6), CFrame = stallBase * CFrame.new(x, 4, 3), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood })
	part({ Parent = stall, Size = Vector3.new(0.6, 8, 0.6), CFrame = stallBase * CFrame.new(x, 4, -1.2), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood })
end
for i = 0, 4 do
	part({ Parent = stall, Size = Vector3.new(2, 0.3, 6), CFrame = stallBase * CFrame.new(-4 + i * 2, 8.2, 1) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then Color3.fromRGB(220, 60, 60) else Color3.fromRGB(245, 240, 230), Material = Enum.Material.Fabric })
end
local keeper = Instance.new("Model")
keeper.Name = "ShopKeeper"
keeper.Parent = stall
local keeperBody = part({ Parent = keeper, Name = "Body", Size = Vector3.new(2.4, 3.4, 1.6), CFrame = stallBase * CFrame.new(0, 3.2, 2.4), Color = Color3.fromRGB(80, 60, 120), Material = Enum.Material.Fabric })
ball(keeper, (stallBase * CFrame.new(0, 5.8, 2.4)).Position, 2, Color3.fromRGB(240, 200, 160))
part({ Parent = keeper, Class = "WedgePart", Size = Vector3.new(2.4, 1.6, 2.4), CFrame = stallBase * CFrame.new(0, 7.4, 2.4), Color = Color3.fromRGB(60, 40, 90), Material = Enum.Material.Fabric })
keeper.PrimaryPart = keeperBody
local keeperTag = Instance.new("BillboardGui")
keeperTag.Size = UDim2.fromOffset(160, 40)
keeperTag.StudsOffset = Vector3.new(0, 5, 0)
keeperTag.MaxDistance = 60
local keeperLabel = Instance.new("TextLabel")
keeperLabel.BackgroundTransparency = 1
keeperLabel.Size = UDim2.fromScale(1, 1)
keeperLabel.Font = Enum.Font.FredokaOne
keeperLabel.TextScaled = true
keeperLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
keeperLabel.TextStrokeTransparency = 0.3
keeperLabel.Text = "🛒 Old Keeper"
keeperLabel.Parent = keeperTag
keeperTag.Parent = keeperBody

-- Title sign
local signBoard = part({ Parent = camp, Size = Vector3.new(18, 6, 0.6), Position = Vector3.new(0, 9, -26), Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.WoodPlanks })
for _, x in { -7, 7 } do
	part({ Parent = camp, Size = Vector3.new(0.8, 12, 0.8), Position = Vector3.new(x, 6, -26.2), Color = Color3.fromRGB(60, 40, 30), Material = Enum.Material.Wood })
end
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Back
signGui.CanvasSize = Vector2.new(600, 200)
local signText = Instance.new("TextLabel")
signText.BackgroundTransparency = 1
signText.Size = UDim2.fromScale(1, 1)
signText.Font = Enum.Font.FredokaOne
signText.TextScaled = true
signText.Text = "🥚 HATCH OR DIE ☠️"
signText.TextColor3 = Color3.fromRGB(255, 220, 90)
signText.TextStrokeTransparency = 0
signText.Parent = signGui
signGui.Parent = signBoard
local signGuiFront = signGui:Clone()
signGuiFront.Face = Enum.NormalId.Front
signGuiFront.Parent = signBoard

-- Lamp posts
for i = 1, 6 do
	local a = i / 6 * math.pi * 2 + 0.3
	local pos = Vector3.new(math.cos(a) * 34, 0, math.sin(a) * 34)
	column(camp, pos, 9, 0.6, Color3.fromRGB(50, 45, 40), Enum.Material.Metal)
	local bulb = ball(camp, pos + Vector3.new(0, 9.6, 0), 1.4, Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Parent = bulb
end

---------------------------------------------------------------------------------------------------
-- Cabin
---------------------------------------------------------------------------------------------------
local cabin = folder("Cabin")
local cabinCF = CFrame.lookAt(CABIN, CAMP)
local wallColor = Color3.fromRGB(120, 85, 55)
part({ Parent = cabin, Size = Vector3.new(22, 1, 18), CFrame = cabinCF * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(100, 75, 50), Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Size = Vector3.new(22, 10, 1), CFrame = cabinCF * CFrame.new(0, 6, 8.5), Color = wallColor, Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Size = Vector3.new(1, 10, 18), CFrame = cabinCF * CFrame.new(-10.5, 6, 0), Color = wallColor, Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Size = Vector3.new(1, 10, 18), CFrame = cabinCF * CFrame.new(10.5, 6, 0), Color = wallColor, Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Size = Vector3.new(8, 10, 1), CFrame = cabinCF * CFrame.new(-7, 6, -8.5), Color = wallColor, Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Size = Vector3.new(8, 10, 1), CFrame = cabinCF * CFrame.new(7, 6, -8.5), Color = wallColor, Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Size = Vector3.new(6, 3, 1), CFrame = cabinCF * CFrame.new(0, 9.5, -8.5), Color = wallColor, Material = Enum.Material.WoodPlanks })
part({ Parent = cabin, Class = "WedgePart", Size = Vector3.new(24, 6, 10), CFrame = cabinCF * CFrame.new(0, 14, -5) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(80, 50, 40), Material = Enum.Material.Wood })
part({ Parent = cabin, Class = "WedgePart", Size = Vector3.new(24, 6, 10), CFrame = cabinCF * CFrame.new(0, 14, 5), Color = Color3.fromRGB(80, 50, 40), Material = Enum.Material.Wood })
part({ Parent = cabin, Size = Vector3.new(6, 0.5, 3.5), CFrame = cabinCF * CFrame.new(-5, 3.5, 4), Color = Color3.fromRGB(90, 65, 45), Material = Enum.Material.Wood })
local lantern = ball(cabin, (cabinCF * CFrame.new(-5, 4.4, 4)).Position, 0.9, Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
local lanternLight = Instance.new("PointLight")
lanternLight.Range = 16
lanternLight.Color = Color3.fromRGB(255, 190, 110)
lanternLight.Parent = lantern

---------------------------------------------------------------------------------------------------
-- Cave (Glowcap Cave)
---------------------------------------------------------------------------------------------------
local cave = folder("Cave")
local caveCF = CFrame.lookAt(CAVE, CAMP)
local rock = Color3.fromRGB(95, 95, 105)
part({ Parent = cave, Size = Vector3.new(6, 20, 36), CFrame = caveCF * CFrame.new(-17, 10, 2), Color = rock, Material = Enum.Material.Slate })
part({ Parent = cave, Size = Vector3.new(6, 20, 36), CFrame = caveCF * CFrame.new(17, 10, 2), Color = rock, Material = Enum.Material.Slate })
part({ Parent = cave, Size = Vector3.new(40, 20, 6), CFrame = caveCF * CFrame.new(0, 10, 18), Color = rock, Material = Enum.Material.Slate })
part({ Parent = cave, Size = Vector3.new(44, 5, 40), CFrame = caveCF * CFrame.new(0, 21, 2), Color = rock, Material = Enum.Material.Slate })
for _ = 1, 16 do
	local offset = Vector3.new(rng:NextNumber(-24, 24), rng:NextNumber(0, 22), rng:NextNumber(-12, 24))
	if math.abs(offset.X) > 17 or offset.Y > 18 or offset.Z > 18 then
		ball(cave, (caveCF * CFrame.new(offset)).Position, rng:NextNumber(8, 14), rock:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.2)), Enum.Material.Slate)
	end
end
for i = 1, 8 do
	local local_ = Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-6, 14))
	local pos = (caveCF * CFrame.new(local_)).Position
	local h = rng:NextNumber(1.5, 3.5)
	column(cave, pos, h, 0.5, Color3.fromRGB(220, 220, 200), Enum.Material.SmoothPlastic)
	local cap = ball(cave, pos + Vector3.new(0, h, 0), rng:NextNumber(1.6, 2.8), if i % 2 == 0 then Color3.fromRGB(80, 230, 255) else Color3.fromRGB(190, 110, 255), Enum.Material.Neon)
	cap.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Color = cap.Color
	light.Parent = cap
end

---------------------------------------------------------------------------------------------------
-- Ruins
---------------------------------------------------------------------------------------------------
local ruins = folder("Ruins")
local stone = Color3.fromRGB(150, 145, 130)
part({ Parent = ruins, Size = Vector3.new(44, 1, 44), Position = RUINS + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(120, 118, 105), Material = Enum.Material.Cobblestone })
for i = 1, 10 do
	local a = i / 10 * math.pi * 2
	local pos = RUINS + Vector3.new(math.cos(a) * 17, 1, math.sin(a) * 17)
	local h = if i % 3 == 0 then rng:NextNumber(3, 6) else rng:NextNumber(10, 16)
	local pillar = part({ Parent = ruins, Size = Vector3.new(3, h, 3), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, a, math.rad(rng:NextNumber(-4, 4))), Color = stone, Material = Enum.Material.Concrete })
	if h > 8 then
		part({ Parent = ruins, Size = Vector3.new(3.4, 1, 3.4), CFrame = pillar.CFrame * CFrame.new(0, h / 2 + 0.5, 0), Color = stone, Material = Enum.Material.Concrete })
	end
	part({ Parent = ruins, Size = Vector3.new(3.2, 0.4, 3.2), CFrame = pillar.CFrame * CFrame.new(0, h / 2 - 0.3, 0), Color = Color3.fromRGB(80, 120, 60), Material = Enum.Material.Grass })
end
part({ Parent = ruins, Size = Vector3.new(7, 3, 7), Position = RUINS + Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(130, 125, 115), Material = Enum.Material.Marble })
part({ Parent = ruins, Size = Vector3.new(14, 6, 2), CFrame = CFrame.new(RUINS + Vector3.new(-12, 4, -14)) * CFrame.Angles(0, math.rad(20), math.rad(8)), Color = stone, Material = Enum.Material.Concrete })

---------------------------------------------------------------------------------------------------
-- Boss arena
---------------------------------------------------------------------------------------------------
local arena = folder("BossArena")
part({ Parent = arena, Name = "BossArenaCenter", Position = ARENA + Vector3.new(0, 0.5, 0), Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CanQuery = false })
part({ Parent = arena, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 92, 92), CFrame = CFrame.new(ARENA + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 78, 85), Material = Enum.Material.Slate, CanCollide = false })
for i = 1, 14 do
	local a = i / 14 * math.pi * 2
	local h = rng:NextNumber(10, 17)
	part({ Parent = arena, Size = Vector3.new(4, h, 3), CFrame = CFrame.new(ARENA + Vector3.new(math.cos(a) * 47, h / 2, math.sin(a) * 47)) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-5, 5))), Color = Color3.fromRGB(70, 68, 75), Material = Enum.Material.Slate })
end
for i = 1, 8 do
	local a = i / 8 * math.pi * 2
	part({ Parent = arena, Size = Vector3.new(1, 0.25, 6), CFrame = CFrame.new(ARENA + Vector3.new(math.cos(a) * 14, 0.25, math.sin(a) * 14)) * CFrame.Angles(0, -a, 0), Color = Color3.fromRGB(170, 255, 90), Material = Enum.Material.Neon, CanCollide = false })
end
for i = 1, 5 do
	local pos = ARENA + Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(55, 70))
	local trunk = column(arena, pos, rng:NextNumber(12, 18), 2, Color3.fromRGB(60, 50, 45), Enum.Material.Wood)
	trunk.Name = "DeadTree" .. i
end

---------------------------------------------------------------------------------------------------
-- Hidden grove
---------------------------------------------------------------------------------------------------
local grove = folder("HiddenGrove")
for i = 1, 22 do
	local a = i / 22 * math.pi * 2
	local gap = math.abs(((a - math.rad(300)) + math.pi) % (2 * math.pi) - math.pi) < 0.25
	if not gap then
		ball(grove, HIDDEN + Vector3.new(math.cos(a) * 24, 5, math.sin(a) * 24), rng:NextNumber(12, 16), Color3.fromRGB(85, 85, 95), Enum.Material.Slate)
	end
end
column(grove, HIDDEN + Vector3.new(6, 0, 6), 22, 4, Color3.fromRGB(200, 190, 230), Enum.Material.Wood)
for _, off in { Vector3.new(6, 24, 6), Vector3.new(2, 21, 9), Vector3.new(10, 21, 3) } do
	local leaves = ball(grove, HIDDEN + off, 12, Color3.fromRGB(110, 200, 255), Enum.Material.Neon)
	leaves.Transparency = 0.3
	leaves.CanCollide = false
end
for _ = 1, 14 do
	local p = HIDDEN + Vector3.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-15, 15))
	column(grove, p, 1.2, 0.2, Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
	local flower = ball(grove, p + Vector3.new(0, 1.4, 0), 0.8, if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 120, 220) else Color3.fromRGB(120, 255, 240), Enum.Material.Neon)
	flower.CanCollide = false
end

---------------------------------------------------------------------------------------------------
-- Forest (trees + rocks)
---------------------------------------------------------------------------------------------------
local forest = folder("Forest")
local leafColors = { Color3.fromRGB(70, 140, 60), Color3.fromRGB(85, 160, 70), Color3.fromRGB(60, 120, 55), Color3.fromRGB(100, 150, 60) }
local trees = 0
local attempts = 0
while trees < TREE_COUNT and attempts < TREE_COUNT * 20 do
	attempts += 1
	local p = randomRingPoint(44, MAP_RADIUS + 20)
	if isOpen(p, 0) then
		trees += 1
		if #TREE_ASSETS > 0 then
			placeAsset(TREE_ASSETS, forest, p, false)
		else
			local h = rng:NextNumber(12, 22)
			local d = rng:NextNumber(1.8, 3.2)
			column(forest, p, h, d, Color3.fromRGB(95, 70, 45), Enum.Material.Wood)
			local leaf = leafColors[rng:NextInteger(1, #leafColors)]
			local size = rng:NextNumber(9, 13)
			ball(forest, p + Vector3.new(0, h + 1, 0), size, leaf, Enum.Material.LeafyGrass).CanCollide = false
			ball(forest, p + Vector3.new(rng:NextNumber(-2, 2), h - 2.5, rng:NextNumber(-2, 2)), size * 0.85, leaf:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.LeafyGrass).CanCollide = false
		end
	end
end
for _ = 1, ROCK_COUNT do
	local p = randomRingPoint(40, MAP_RADIUS)
	if isOpen(p, -4) then
		if #ROCK_ASSETS > 0 then
			placeAsset(ROCK_ASSETS, forest, p, false)
		else
			ball(forest, p + Vector3.new(0, 0.5, 0), rng:NextNumber(2.5, 6), Color3.fromRGB(115, 115, 120), Enum.Material.Slate)
		end
	end
end

-- Grass and decor are walk-through (no collision) so they never block players or clicks.
local function isGroundFree(p)
	if flatDist(p, CAMP) < 14 or flatDist(p, ARENA) < 46 or flatDist(p, RUINS) < 23 or flatDist(p, CAVE) < 22 or flatDist(p, CABIN) < 13 then
		return false
	end
	for _, path in PATHS do
		if distToSegment(p, path[1], path[2]) < 5 then
			return false
		end
	end
	return true
end
if #GRASS_ASSETS > 0 then
	local grass = folder("Grass")
	local placed = 0
	attempts = 0
	while placed < GRASS_COUNT and attempts < GRASS_COUNT * 10 do
		attempts += 1
		local p = randomRingPoint(0, MAP_RADIUS + 10)
		if isGroundFree(p) then
			placed += 1
			placeAsset(GRASS_ASSETS, grass, p, true)
		end
	end
end
if #DECOR_ASSETS > 0 then
	local decor = folder("Decor")
	local placed = 0
	attempts = 0
	while placed < DECOR_COUNT and attempts < DECOR_COUNT * 20 do
		attempts += 1
		local p = randomRingPoint(20, MAP_RADIUS)
		if isGroundFree(p) and isOpen(p, -20) then
			placed += 1
			placeAsset(DECOR_ASSETS, decor, p, true)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Resources: berry bushes + coin crystals
---------------------------------------------------------------------------------------------------
local resources = folder("Resources")

local function berryBush(p)
	local bush = Instance.new("Model")
	bush.Name = "BerryBush"
	local body = ball(bush, p + Vector3.new(0, 2, 0), 5, Color3.fromRGB(60, 130, 55), Enum.Material.LeafyGrass)
	body.Name = "Bush"
	bush.PrimaryPart = body
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local berry = ball(bush, p + Vector3.new(math.cos(a) * 2.3, 2 + math.sin(i * 1.7) * 1.2, math.sin(a) * 2.3), 0.9, Color3.fromRGB(230, 40, 80), Enum.Material.SmoothPlastic)
		berry.Name = "Berry"
		berry.CanCollide = false
	end
	bush.Parent = resources
end

local function coinCrystal(p)
	local crystal = Instance.new("Model")
	crystal.Name = "CoinCrystal"
	local main = part({ Parent = crystal, Size = Vector3.new(1.6, 4.5, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(8)), Color = Color3.fromRGB(255, 205, 70), Material = Enum.Material.Neon })
	main.Name = "Crystal"
	part({ Parent = crystal, Size = Vector3.new(1.1, 2.8, 1.1), CFrame = CFrame.new(p + Vector3.new(1.2, 1.2, 0.4)) * CFrame.Angles(0, 0, math.rad(-25)), Color = Color3.fromRGB(255, 225, 120), Material = Enum.Material.Neon })
	part({ Parent = crystal, Size = Vector3.new(1, 2.2, 1), CFrame = CFrame.new(p + Vector3.new(-1, 1, -0.5)) * CFrame.Angles(math.rad(20), 0, math.rad(25)), Color = Color3.fromRGB(255, 190, 50), Material = Enum.Material.Neon })
	crystal.PrimaryPart = main
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Color = Color3.fromRGB(255, 205, 70)
	light.Parent = main
	crystal.Parent = resources
end

-- A few berry bushes right by camp so the first feed happens fast.
for i = 1, 3 do
	local a = i / 3 * math.pi * 2 + 0.8
	berryBush(Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46))
end
local bushes = 3
attempts = 0
while bushes < 20 and attempts < 2000 do
	attempts += 1
	local p = randomRingPoint(55, 220)
	if isOpen(p, 2) then
		bushes += 1
		berryBush(p)
	end
end

for _, localPos in { Vector3.new(-9, 0, 8), Vector3.new(10, 0, 10), Vector3.new(0, 0, 14), Vector3.new(7, 0, -2) } do
	coinCrystal((caveCF * CFrame.new(localPos)).Position)
end
for i = 1, 3 do
	local a = i / 3 * math.pi * 2
	coinCrystal(RUINS + Vector3.new(math.cos(a) * 9, 1, math.sin(a) * 9))
end
local crystals = 0
attempts = 0
while crystals < 6 and attempts < 2000 do
	attempts += 1
	local p = randomRingPoint(70, 240)
	if isOpen(p, 2) then
		crystals += 1
		coinCrystal(p)
	end
end

---------------------------------------------------------------------------------------------------
-- Egg spots + enemy spawns
---------------------------------------------------------------------------------------------------
local eggSpots = folder("EggSpots")
local function eggSpot(position, area)
	local spot = part({ Parent = eggSpots, Name = "EggSpot", Size = Vector3.new(2, 0.4, 2), Position = position, Transparency = 1, CanCollide = false, CanQuery = false })
	spot:SetAttribute("Area", area)
end
eggSpot((caveCF * CFrame.new(0, 0.2, 10)).Position, "Cave")
eggSpot(RUINS + Vector3.new(0, 4.2, 0), "Ruins")
eggSpot((cabinCF * CFrame.new(4, 1.2, 4)).Position, "Cabin")
eggSpot(HIDDEN + Vector3.new(0, 0.2, 0), "Hidden")
local spots = 0
attempts = 0
while spots < 14 and attempts < 2000 do
	attempts += 1
	local p = randomRingPoint(55, 235)
	if isOpen(p, 3) then
		spots += 1
		eggSpot(p + Vector3.new(0, 0.2, 0), "Forest")
	end
end

local enemySpawns = folder("EnemySpawns")
for i = 1, 14 do
	local a = i / 14 * math.pi * 2
	part({ Parent = enemySpawns, Name = "EnemySpawn", Size = Vector3.new(4, 1, 4), Position = Vector3.new(math.cos(a) * 245, 0.5, math.sin(a) * 245), Transparency = 1, CanCollide = false, CanQuery = false })
end

Map.Parent = workspace

---------------------------------------------------------------------------------------------------
-- Torch tool (StarterPack)
---------------------------------------------------------------------------------------------------
local oldTorch = StarterPack:FindFirstChild("Torch")
if oldTorch then
	oldTorch:Destroy()
end
local torch = Instance.new("Tool")
torch.Name = "Torch"
torch.ToolTip = "Swing to burn enemies"
torch.CanBeDropped = false
torch.Grip = CFrame.new(0, 0, 1)
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.4, 0.4, 3.2)
handle.Color = Color3.fromRGB(110, 75, 45)
handle.Material = Enum.Material.Wood
handle.CanCollide = false
handle.Parent = torch
local flame = Instance.new("Part")
flame.Name = "Flame"
flame.Shape = Enum.PartType.Ball
flame.Size = Vector3.new(0.9, 0.9, 0.9)
flame.Color = Color3.fromRGB(255, 150, 40)
flame.Material = Enum.Material.Neon
flame.CanCollide = false
flame.Massless = true
flame.CFrame = handle.CFrame * CFrame.new(0, 0, -1.7)
flame.Parent = torch
local weld = Instance.new("WeldConstraint")
weld.Part0 = handle
weld.Part1 = flame
weld.Parent = flame
local torchFire = Instance.new("Fire")
torchFire.Size = 2.5
torchFire.Heat = 6
torchFire.Parent = flame
local torchLight = Instance.new("PointLight")
torchLight.Range = 24
torchLight.Brightness = 2
torchLight.Color = Color3.fromRGB(255, 180, 100)
torchLight.Parent = flame
torch.Parent = StarterPack

Players.CharacterAutoLoads = false

print(("✅ HATCH OR DIE Part 1/4 (map v3) done: map + torch built. Your models used -> Trees: %d, Grass: %d, Rocks: %d, Decor: %d variants. Now run Part 2."):format(#TREE_ASSETS, #GRASS_ASSETS, #ROCK_ASSETS, #DECOR_ASSETS))
if not assetsFolder then
	print("ℹ️ No MapAssets folder found, so built-in trees/rocks were used. See the top of this script to use your own models.")
end
end
do
-- HATCH OR DIE - installer PART 2 of 4: SHARED CODE (ReplicatedStorage)
-- Generated by tools/build_installer.py from src/. Do not edit by hand.
-- Paste everything into the Roblox Studio command bar and press Enter.
local function make(parent, className, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	if source then
		inst.Source = source
	end
	inst.Parent = parent
	return inst
end

local n1 = make(game:GetService("ReplicatedStorage"), "Folder", "HatchOrDie", nil)
do
local n2 = make(n1, "Folder", "Config", nil)
make(n2, "ModuleScript", "CreatureData", [=[
local Rarity = require(script.Parent.Rarity)

local CreatureData = {}

-- Stage requirements count XP and nights earned *at the current stage*.
CreatureData.Stages = {
	{ Name = "Baby", Scale = 1.0, StatMult = 1.0, XPToEvolve = 100, NightsToEvolve = 1 },
	{ Name = "Teen", Scale = 1.55, StatMult = 1.9, XPToEvolve = 450, NightsToEvolve = 3 },
	{ Name = "Adult", Scale = 2.2, StatMult = 3.3 },
}

CreatureData.Families = {
	Sprout = {
		Rarity = "Common",
		Names = { "Sproutling", "Thornback", "Elderwood Drake" },
		Body = "Lizard",
		Primary = Color3.fromRGB(110, 190, 80),
		Secondary = Color3.fromRGB(215, 235, 160),
		Accent = Color3.fromRGB(255, 120, 150),
		EyeColor = Color3.fromRGB(30, 30, 30),
		Stats = { Health = 140, Damage = 9, AttackRate = 1.1, Range = 7 },
		Ranged = false,
		Ability = { Name = "Thorn Burst", Kind = "Burst", Radius = 16, DamageMult = 2.5, HealOwner = 25, Cooldown = 12 },
		Description = "Tough and loyal. Heals you with Thorn Burst.",
	},
	Ember = {
		Rarity = "Rare",
		Names = { "Emberling", "Cinderfang", "Blaze Wyrm" },
		Body = "Fox",
		Primary = Color3.fromRGB(255, 115, 45),
		Secondary = Color3.fromRGB(255, 225, 190),
		Accent = Color3.fromRGB(255, 225, 80),
		EyeColor = Color3.fromRGB(40, 20, 10),
		Stats = { Health = 100, Damage = 12, AttackRate = 1.0, Range = 22 },
		Ranged = true,
		Ability = { Name = "Fire Nova", Kind = "Burst", Radius = 20, DamageMult = 2.2, Cooldown = 10 },
		Description = "Spits fireballs from range. Fire Nova scorches crowds.",
	},
	Shade = {
		Rarity = "Epic",
		Names = { "Shadeling", "Duskstalker", "Void Sovereign" },
		Body = "Wolf",
		Primary = Color3.fromRGB(75, 55, 125),
		Secondary = Color3.fromRGB(35, 25, 55),
		Accent = Color3.fromRGB(175, 115, 255),
		EyeColor = Color3.fromRGB(175, 115, 255),
		Stats = { Health = 120, Damage = 15, AttackRate = 1.25, Range = 8 },
		Ranged = false,
		Ability = { Name = "Shadow Pounce", Kind = "Pounce", Radius = 40, DamageMult = 4.5, Cooldown = 9 },
		Description = "A fast hunter. Shadow Pounce deletes a single target.",
	},
}

-- Mutations mostly change looks. StatBonus is deliberately small.
CreatureData.Mutations = {
	{ Id = "Storm", Name = "Storm", Weight = 30, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(120, 205, 255) },
	{ Id = "Inferno", Name = "Inferno", Weight = 28, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(255, 85, 20) },
	{ Id = "Crystal", Name = "Crystal", Weight = 20, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(165, 255, 255) },
	{ Id = "Plague", Name = "Plague", Weight = 14, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(145, 255, 60) },
	{ Id = "Void", Name = "Void", Weight = 6, Rarity = "Mythic", StatBonus = 0.15, Color = Color3.fromRGB(95, 0, 170) },
	{ Id = "Rainbow", Name = "Rainbow", Weight = 1.6, Rarity = "Mythic", StatBonus = 0.15, Color = Color3.fromRGB(255, 255, 255) },
	{ Id = "Celestial", Name = "Celestial", Weight = 0.4, Rarity = "Mythic", StatBonus = 0.20, Color = Color3.fromRGB(255, 240, 190) },
}

CreatureData.MutationById = {}
do
	local total = 0
	for _, m in CreatureData.Mutations do
		total += m.Weight
	end
	for _, m in CreatureData.Mutations do
		m.Chance = m.Weight / total
		CreatureData.MutationById[m.Id] = m
	end
end

-- Auras are cosmetic only.
CreatureData.Auras = {
	Fire = { Name = "Fire Aura", Color = Color3.fromRGB(255, 120, 30), Order = 1 },
	Toxic = { Name = "Toxic Aura", Color = Color3.fromRGB(120, 255, 60), Order = 2 },
	Lightning = { Name = "Lightning Aura", Color = Color3.fromRGB(110, 200, 255), Order = 3 },
	Crystal = { Name = "Crystal Aura", Color = Color3.fromRGB(190, 255, 255), Order = 4 },
	Galaxy = { Name = "Galaxy Aura", Color = Color3.fromRGB(170, 90, 255), Order = 5, Robux = true },
	Golden = { Name = "Golden Aura", Color = Color3.fromRGB(255, 205, 60), Order = 6, VIP = true },
}

function CreatureData.RollMutation(rng: Random): string
	local roll = rng:NextNumber()
	local acc = 0
	for _, m in CreatureData.Mutations do
		acc += m.Chance
		if roll <= acc then
			return m.Id
		end
	end
	return CreatureData.Mutations[1].Id
end

function CreatureData.GetStageName(record): string
	local fam = CreatureData.Families[record.Family]
	return fam and fam.Names[record.Stage] or "???"
end

function CreatureData.GetDisplayName(record): string
	local base = CreatureData.GetStageName(record)
	if record.Mutation then
		return record.Mutation .. " " .. base
	end
	return base
end

function CreatureData.GetRarity(record): string
	local fam = CreatureData.Families[record.Family]
	local rarity = fam and fam.Rarity or "Common"
	local mut = record.Mutation and CreatureData.MutationById[record.Mutation]
	if mut then
		rarity = Rarity.Max(rarity, mut.Rarity)
	end
	return rarity
end

function CreatureData.GetStats(record)
	local fam = CreatureData.Families[record.Family]
	local stage = CreatureData.Stages[record.Stage] or CreatureData.Stages[1]
	local mut = record.Mutation and CreatureData.MutationById[record.Mutation]
	local mult = stage.StatMult * (1 + (mut and mut.StatBonus or 0))
	return {
		MaxHealth = math.floor(fam.Stats.Health * mult),
		Damage = math.floor(fam.Stats.Damage * mult * 10) / 10,
		AttackRate = fam.Stats.AttackRate,
		Range = fam.Stats.Range * (0.85 + 0.15 * record.Stage),
	}
end

function CreatureData.CanEvolve(record): (boolean, string?)
	local stage = CreatureData.Stages[record.Stage]
	if not stage or not stage.XPToEvolve then
		return false, "Already fully evolved"
	end
	if (record.XP or 0) < stage.XPToEvolve then
		return false, ("Needs %d more XP"):format(stage.XPToEvolve - (record.XP or 0))
	end
	if (record.StageNights or 0) < stage.NightsToEvolve then
		return false, ("Must survive %d more night(s)"):format(stage.NightsToEvolve - (record.StageNights or 0))
	end
	return true, nil
end

function CreatureData.DiscoveryKey(record): string
	return ("%s:%d:%s"):format(record.Family, record.Stage, record.Mutation or "Normal")
end

return CreatureData
]=])
make(n2, "ModuleScript", "EggData", [=[
-- Pool weights are relative. Odds are shown to players in the Eggs panel (required for paid random items).
local EggData = {
	ForestEgg = {
		Name = "Forest Egg",
		Rarity = "Common",
		HatchTime = 20,
		Price = 75,
		Order = 1,
		Color = Color3.fromRGB(125, 200, 95),
		SpotColor = Color3.fromRGB(95, 70, 45),
		NeonSpots = false,
		MutationChance = 0.02,
		Pool = {
			{ Family = "Sprout", Weight = 70 },
			{ Family = "Ember", Weight = 25 },
			{ Family = "Shade", Weight = 5 },
		},
	},
	EmberEgg = {
		Name = "Ember Egg",
		Rarity = "Rare",
		HatchTime = 40,
		Price = 350,
		Order = 2,
		Color = Color3.fromRGB(255, 125, 45),
		SpotColor = Color3.fromRGB(255, 225, 90),
		NeonSpots = true,
		MutationChance = 0.06,
		Pool = {
			{ Family = "Ember", Weight = 60 },
			{ Family = "Sprout", Weight = 25 },
			{ Family = "Shade", Weight = 15 },
		},
	},
	VoidEgg = {
		Name = "Void Egg",
		Rarity = "Legendary",
		HatchTime = 75,
		Price = 2000,
		Order = 3,
		Color = Color3.fromRGB(85, 40, 160),
		SpotColor = Color3.fromRGB(90, 255, 255),
		NeonSpots = true,
		MutationChance = 0.18,
		Pool = {
			{ Family = "Shade", Weight = 60 },
			{ Family = "Ember", Weight = 30 },
			{ Family = "Sprout", Weight = 10 },
		},
	},
}

return EggData
]=])
make(n2, "ModuleScript", "EnemyData", [=[
local EnemyData = {}

EnemyData.Types = {
	Crawler = {
		Name = "Crawler",
		Shape = "Crawler",
		Behavior = "Melee",
		Health = 38,
		Damage = 7,
		Speed = 17,
		AttackRange = 4.5,
		AttackCooldown = 1.0,
		Windup = 0,
		Coins = 3,
		XP = 7,
		UnlockNight = 1,
		Weight = 60,
		Color = Color3.fromRGB(55, 75, 40),
		EyeColor = Color3.fromRGB(255, 60, 60),
	},
	Hunter = {
		Name = "Hunter",
		Shape = "Hunter",
		Behavior = "Ranged",
		Health = 34,
		Damage = 9,
		Speed = 13,
		AttackRange = 48,
		PreferredRange = 30,
		AttackCooldown = 2.6,
		Windup = 0.8,
		ProjectileSpeed = 70,
		Coins = 5,
		XP = 10,
		UnlockNight = 3,
		Weight = 25,
		Color = Color3.fromRGB(45, 40, 60),
		EyeColor = Color3.fromRGB(255, 70, 220),
	},
	Brute = {
		Name = "Brute",
		Shape = "Brute",
		Behavior = "Melee",
		Health = 240,
		Damage = 26,
		Speed = 8.5,
		AttackRange = 8,
		SmashRadius = 8,
		AttackCooldown = 2.4,
		Windup = 1.0,
		Coins = 15,
		XP = 28,
		UnlockNight = 5,
		Weight = 15,
		Color = Color3.fromRGB(90, 60, 50),
		EyeColor = Color3.fromRGB(255, 150, 30),
	},
	RotwoodColossus = {
		Name = "Rotwood Colossus",
		Shape = "Colossus",
		Behavior = "Boss",
		IsBoss = true,
		Health = 3200,
		Damage = 30,
		Speed = 9,
		AttackRange = 18,
		AttackCooldown = 4.2,
		Windup = 1.3,
		Coins = 0,
		XP = 0,
		Color = Color3.fromRGB(85, 60, 40),
		EyeColor = Color3.fromRGB(140, 255, 90),
	},
}

EnemyData.Variants = {
	Normal = { HealthMult = 1, DamageMult = 1, SpeedMult = 1, RewardMult = 1, Scale = 1 },
	Elite = {
		HealthMult = 2.3,
		DamageMult = 1.5,
		SpeedMult = 1.12,
		RewardMult = 3,
		Scale = 1.3,
		Prefix = "Elite ",
		Tint = Color3.fromRGB(255, 200, 40),
	},
	Nightmare = {
		HealthMult = 3.2,
		DamageMult = 1.9,
		SpeedMult = 1.2,
		RewardMult = 5,
		Scale = 1.4,
		Prefix = "Nightmare ",
		Tint = Color3.fromRGB(210, 0, 45),
	},
}

-- One formula drives every night, so night 1 and night 100 use the same map and code.
function EnemyData.GetNightPlan(night: number, playerCount: number, rng: Random?)
	local n = math.max(1, night)
	local players = math.max(1, playerCount)
	local random = rng or Random.new()

	local plan = {
		Night = n,
		HealthMult = 1 + 0.16 * (n - 1),
		DamageMult = 1 + 0.09 * (n - 1),
		RewardMult = 1,
		TotalEnemies = math.floor((6 + n * 2.5) * (1 + 0.45 * (players - 1))),
		MaxAlive = math.min(10 + n * 2 + (players - 1) * 4, 40),
		EliteChance = if n >= 6 then math.min(0.04 * (n - 5), 0.4) else 0,
		NightmareChance = if n >= 50 then math.min(0.1 + 0.01 * (n - 50), 0.5) else 0,
		Boss = (n % 10 == 0) or n == 25,
		MiniBoss = n == 5,
		Modifier = "Night",
		Types = {},
	}

	if n >= 100 then
		plan.Modifier = "Apocalypse"
		plan.RewardMult = 2
	elseif n >= 50 then
		plan.Modifier = "Nightmare"
		plan.RewardMult = 1.5
	elseif n >= 4 and not plan.Boss and random:NextNumber() < 0.2 then
		plan.Modifier = "BloodMoon"
		plan.RewardMult = 1.5
		plan.TotalEnemies = math.floor(plan.TotalEnemies * 1.3)
		plan.EliteChance = math.max(plan.EliteChance, 0.1)
	end

	for id, data in EnemyData.Types do
		if not data.IsBoss and n >= data.UnlockNight then
			table.insert(plan.Types, { Id = id, Weight = data.Weight })
		end
	end
	table.sort(plan.Types, function(a, b)
		return a.Id < b.Id
	end)

	return plan
end

function EnemyData.PickType(plan, rng: Random): string
	local total = 0
	for _, t in plan.Types do
		total += t.Weight
	end
	local roll = rng:NextNumber() * total
	for _, t in plan.Types do
		roll -= t.Weight
		if roll <= 0 then
			return t.Id
		end
	end
	return plan.Types[1].Id
end

function EnemyData.PickVariant(plan, rng: Random): string
	local roll = rng:NextNumber()
	if roll < plan.NightmareChance then
		return "Nightmare"
	elseif roll < plan.NightmareChance + plan.EliteChance then
		return "Elite"
	end
	return "Normal"
end

return EnemyData
]=])
make(n2, "ModuleScript", "GameConfig", [=[
-- Global tuning knobs. Change numbers here, not in services.
local GameConfig = {
	Version = "0.1.0",

	-- Day / night timing (seconds)
	FirstDayLength = 40,
	DayLength = 50,
	NightLength = 85,
	BossNightLength = 150,
	DayRespawnDelay = 4,
	WipeResetDelay = 7,

	-- Eggs
	StarterEgg = "ForestEgg",
	StarterHatchTime = 10,
	MaxEggs = 30,

	-- Creatures
	BaseCreatureSlots = 15,
	ExtraSlotsBonus = 25,
	CreatureMoveSpeed = 26,
	CreatureLeashDistance = 70,
	CreatureAggroRadius = 40,
	CreatureDefendRadius = 16,
	CreatureKORecoverTime = 25,
	EvolveMutationChance = 0.05,
	FeedXP = 20,
	FeedHealPercent = 0.35,
	FeedCooldown = 0.75,

	-- Player torch
	TorchDamage = 12,
	TorchRange = 10,
	TorchCooldown = 0.45,

	-- World
	GroundY = 0,
	BerryRegrowTime = 40,
	CrystalRegrowTime = 60,
	CrystalCoins = { 8, 15 },

	-- Enemies
	EnemyRetargetInterval = 0.5,
	EnemyAggroRadius = 90,

	-- Saving
	DataStoreName = "HatchOrDie_Players_v1",
	AutosaveInterval = 120,

	-- Optional audio. Paste rbxassetid:// ids to enable music.
	Music = { Day = "", Night = "", Boss = "" },
	Sounds = {
		Hatch = "rbxasset://sounds/electronicpingshort.wav",
		Swing = "rbxasset://sounds/swordslash.wav",
	},

	-- Monetization: create these in Creator Dashboard and paste the ids. 0 = disabled.
	Gamepasses = {
		VIP = 0,
		DoubleHatch = 0,
		AutoHatch = 0,
		ExtraSlots = 0,
	},
	Products = {
		EggPack = 0,
		GalaxyAura = 0,
	},
}

function GameConfig.NightReward(night: number)
	return {
		Coins = 25 + 12 * night,
		CreatureXP = 45 + 10 * night,
		Berries = 2,
	}
end

-- Eggs handed out at dawn for surviving a given night.
function GameConfig.NightEggRewards(night: number): { string }
	local eggs = {}
	if night % 3 == 0 then
		table.insert(eggs, "ForestEgg")
	end
	if night == 5 or night % 7 == 0 then
		table.insert(eggs, "EmberEgg")
	end
	return eggs
end

return GameConfig
]=])
make(n2, "ModuleScript", "Rarity", [=[
local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Rarity.Rank = {}
for i, name in Rarity.Order do
	Rarity.Rank[name] = i
end

Rarity.Colors = {
	Common = Color3.fromRGB(205, 205, 210),
	Uncommon = Color3.fromRGB(95, 225, 115),
	Rare = Color3.fromRGB(70, 155, 255),
	Epic = Color3.fromRGB(185, 95, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 60, 125),
}

Rarity.ReleaseCoins = {
	Common = 10,
	Uncommon = 20,
	Rare = 40,
	Epic = 80,
	Legendary = 200,
	Mythic = 500,
}

function Rarity.Max(a: string, b: string): string
	return if (Rarity.Rank[a] or 1) >= (Rarity.Rank[b] or 1) then a else b
end

function Rarity.AtLeast(rarity: string, minimum: string): boolean
	return (Rarity.Rank[rarity] or 1) >= (Rarity.Rank[minimum] or 1)
end

return Rarity
]=])
make(n2, "ModuleScript", "ShopData", [=[
local ShopData = {}

ShopData.Categories = { "Eggs", "Boosts", "Cosmetics", "Robux" }

-- Coin shop. Robux items live in ShopData.Robux and are validated server-side via MarketplaceService.
ShopData.Items = {
	{ Id = "ForestEgg", Category = "Eggs", Kind = "Egg", EggId = "ForestEgg", Price = 75, Name = "Forest Egg" },
	{ Id = "EmberEgg", Category = "Eggs", Kind = "Egg", EggId = "EmberEgg", Price = 350, Name = "Ember Egg" },
	{ Id = "VoidEgg", Category = "Eggs", Kind = "Egg", EggId = "VoidEgg", Price = 2000, Name = "Void Egg" },
	{ Id = "Berries5", Category = "Boosts", Kind = "Berries", Amount = 5, Price = 30, Name = "5 Berries", Description = "Feed = XP + heal. Feeding a knocked-out creature revives it." },
	{ Id = "Berries20", Category = "Boosts", Kind = "Berries", Amount = 20, Price = 100, Name = "20 Berries", Description = "Bulk berries for long nights." },
	{ Id = "FireAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Fire", Price = 600, Name = "Fire Aura" },
	{ Id = "ToxicAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Toxic", Price = 900, Name = "Toxic Aura" },
	{ Id = "LightningAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Lightning", Price = 1200, Name = "Lightning Aura" },
	{ Id = "CrystalAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Crystal", Price = 1800, Name = "Crystal Aura" },
}

ShopData.Robux = {
	{ Id = "VIP", Kind = "Gamepass", ConfigKey = "VIP", Robux = 299, Name = "VIP", Description = "VIP tag, Golden Aura, a free Forest Egg every dawn." },
	{ Id = "DoubleHatch", Kind = "Gamepass", ConfigKey = "DoubleHatch", Robux = 99, Name = "2x Hatch Speed", Description = "All eggs hatch twice as fast." },
	{ Id = "AutoHatch", Kind = "Gamepass", ConfigKey = "AutoHatch", Robux = 199, Name = "Auto Hatch", Description = "Your next egg starts incubating automatically." },
	{ Id = "ExtraSlots", Kind = "Gamepass", ConfigKey = "ExtraSlots", Robux = 79, Name = "+25 Creature Slots", Description = "Keep more of your collection." },
	{ Id = "EggPack", Kind = "Product", ConfigKey = "EggPack", Robux = 149, Name = "Ember Egg Pack", Description = "3 Ember Eggs + 200 coins." },
	{ Id = "GalaxyAura", Kind = "Product", ConfigKey = "GalaxyAura", Robux = 129, Name = "Galaxy Aura", Description = "Cosmetic only. Your creature shimmers with stars." },
}

ShopData.ById = {}
for _, item in ShopData.Items do
	ShopData.ById[item.Id] = item
end

return ShopData
]=])
end
do
local n3 = make(n1, "Folder", "Shared", nil)
make(n3, "ModuleScript", "Models", [=[
-- Procedural models built from parts, so the game ships with zero uploaded assets.
-- Every model has an anchored, invisible "Root" PrimaryPart; all other parts are welded to it,
-- so the server only moves Root.CFrame. Attributes: HipHeight (root height above ground), Radius.
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
function Models.BuildCreature(record): Model
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
function Models.BuildEnemy(typeId: string, variantId: string?): Model
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
function Models.BuildEgg(eggId: string): Model
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

return Models
]=])
make(n3, "ModuleScript", "Net", [=[
-- All remotes live in ReplicatedStorage.HatchOrDie.Remotes and are created by the server.
local RunService = game:GetService("RunService")

local Root = script.Parent.Parent

local Net = {}

Net.Events = {
	-- client -> server
	"ClientReady",
	"RequestHatch",
	"EquipCreature",
	"FeedCreature",
	"SetCommand",
	"SetTarget",
	"UseAbility",
	"EvolveCreature",
	"ReleaseCreature",
	"ToggleLock",
	"EquipAura",
	"BuyItem",
	-- server -> client
	"SyncData",
	"HatchResult",
	"Evolved",
	"Notify",
	"Announce",
	"BossBar",
	"OpenPanel",
	"NightResult",
	"Effect",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = Root:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = Root
		end
		for _, name in Net.Events do
			if not f:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = f
			end
		end
		folder = f
	else
		folder = Root:WaitForChild("Remotes")
	end
	return folder :: Folder
end

function Net.Get(name: string): RemoteEvent
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

-- Server-side handler with a per-player rate limit and error isolation.
function Net.On(name: string, handler: (Player, ...any) -> (), cooldown: number?)
	local remote = Net.Get(name)
	local last = setmetatable({}, { __mode = "k" })
	remote.OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		if cooldown and last[player] and now - last[player] < cooldown then
			return
		end
		last[player] = now
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] %s failed for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.Notify(player: Player, text: string, color: Color3?)
	Net.Get("Notify"):FireClient(player, text, color)
end

function Net.NotifyAll(text: string, color: Color3?)
	Net.Get("Notify"):FireAllClients(text, color)
end

function Net.Announce(text: string, color: Color3?, big: boolean?)
	Net.Get("Announce"):FireAllClients(text, color, big)
end

return Net
]=])
make(n3, "ModuleScript", "Signal", [=[
-- Minimal signal that passes tables by reference (BindableEvents deep-copy them).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { Fn = fn, Connected = true }
	table.insert(self._handlers, handler)
	return {
		Disconnect = function()
			handler.Connected = false
			local i = table.find(self._handlers, handler)
			if i then
				table.remove(self._handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		if handler.Connected then
			task.spawn(handler.Fn, ...)
		end
	end
end

return Signal
]=])
end
print("✅ HATCH OR DIE Part 2/4 done. Now run Part 3.")
end
do
-- HATCH OR DIE - installer PART 3 of 4: SERVER CODE (ServerScriptService)
-- Generated by tools/build_installer.py from src/. Do not edit by hand.
-- Paste everything into the Roblox Studio command bar and press Enter.
local function make(parent, className, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	if source then
		inst.Source = source
	end
	inst.Parent = parent
	return inst
end

local n1 = make(game:GetService("ServerScriptService"), "Script", "HatchOrDie", [=[
-- HATCH OR DIE server bootstrap. Services are loaded into a shared Registry to avoid circular requires,
-- then Init() (wire signals) runs for all of them before Start() (begin work).
local Registry = require(script.Registry)

local ORDER = {
	"DataService",
	"EconomyService",
	"EnemyService",
	"CreatureService",
	"EggService",
	"CombatService",
	"BossService",
	"WorldService",
	"ShopService",
	"CycleService",
}

for _, name in ORDER do
	Registry[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Init then
		service.Init()
	end
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[HATCH OR DIE] Server started")
]=])
do
local n2 = make(n1, "Folder", "Modules", nil)
make(n2, "ModuleScript", "Atmosphere", [=[
-- Lighting presets for each phase. The same map reads completely differently per preset.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Atmosphere = {}

local PRESETS = {
	Day = {
		Lighting = {
			Brightness = 2.2,
			Ambient = Color3.fromRGB(110, 110, 120),
			OutdoorAmbient = Color3.fromRGB(140, 140, 150),
			FogEnd = 900,
			FogColor = Color3.fromRGB(190, 215, 235),
			ExposureCompensation = 0,
		},
		Atmosphere = { Density = 0.25, Color = Color3.fromRGB(199, 220, 240), Decay = Color3.fromRGB(106, 112, 125), Glare = 0, Haze = 1 },
		Color = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.15, Contrast = 0.05, Brightness = 0 },
	},
	Night = {
		Lighting = {
			Brightness = 1,
			Ambient = Color3.fromRGB(40, 45, 75),
			OutdoorAmbient = Color3.fromRGB(55, 60, 100),
			FogEnd = 260,
			FogColor = Color3.fromRGB(15, 18, 35),
			ExposureCompensation = 0.2,
		},
		Atmosphere = { Density = 0.4, Color = Color3.fromRGB(40, 45, 80), Decay = Color3.fromRGB(20, 20, 40), Glare = 0, Haze = 2 },
		Color = { TintColor = Color3.fromRGB(190, 200, 255), Saturation = -0.1, Contrast = 0.15, Brightness = 0 },
	},
	BloodMoon = {
		Lighting = {
			Brightness = 1,
			Ambient = Color3.fromRGB(85, 30, 30),
			OutdoorAmbient = Color3.fromRGB(110, 40, 40),
			FogEnd = 220,
			FogColor = Color3.fromRGB(60, 5, 5),
			ExposureCompensation = 0.2,
		},
		Atmosphere = { Density = 0.45, Color = Color3.fromRGB(120, 20, 20), Decay = Color3.fromRGB(60, 10, 10), Glare = 0, Haze = 2 },
		Color = { TintColor = Color3.fromRGB(255, 170, 170), Saturation = 0, Contrast = 0.2, Brightness = 0 },
	},
	Nightmare = {
		Lighting = {
			Brightness = 0.8,
			Ambient = Color3.fromRGB(60, 20, 40),
			OutdoorAmbient = Color3.fromRGB(80, 30, 55),
			FogEnd = 150,
			FogColor = Color3.fromRGB(30, 0, 15),
			ExposureCompensation = 0.1,
		},
		Atmosphere = { Density = 0.55, Color = Color3.fromRGB(70, 10, 40), Decay = Color3.fromRGB(30, 0, 20), Glare = 0, Haze = 3 },
		Color = { TintColor = Color3.fromRGB(255, 130, 150), Saturation = -0.4, Contrast = 0.3, Brightness = -0.02 },
	},
	Apocalypse = {
		Lighting = {
			Brightness = 1.4,
			Ambient = Color3.fromRGB(110, 50, 20),
			OutdoorAmbient = Color3.fromRGB(140, 60, 25),
			FogEnd = 200,
			FogColor = Color3.fromRGB(120, 40, 10),
			ExposureCompensation = 0.2,
		},
		Atmosphere = { Density = 0.5, Color = Color3.fromRGB(200, 80, 30), Decay = Color3.fromRGB(90, 30, 10), Glare = 0.5, Haze = 3 },
		Color = { TintColor = Color3.fromRGB(255, 175, 120), Saturation = 0.1, Contrast = 0.3, Brightness = 0 },
	},
}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect
local clockTarget = 8
local clockRate = 0

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function Atmosphere.Init()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
	atmosphere = ensure("Atmosphere", "HOD_Atmosphere") :: Atmosphere
	colorCorrection = ensure("ColorCorrectionEffect", "HOD_Color") :: ColorCorrectionEffect
	local bloom = ensure("BloomEffect", "HOD_Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ClockTime = 8

	-- Continuous clock so the sun visibly moves through each phase.
	task.spawn(function()
		while true do
			local dt = task.wait(0.2)
			if clockRate > 0 then
				local diff = (clockTarget - Lighting.ClockTime) % 24
				local step = math.min(diff, clockRate * dt)
				Lighting.ClockTime = (Lighting.ClockTime + step) % 24
			end
		end
	end)
end

function Atmosphere.Apply(presetName: string, tweenTime: number?)
	local preset = PRESETS[presetName] or PRESETS.Night
	local info = TweenInfo.new(tweenTime or 4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, preset.Lighting):Play()
	TweenService:Create(atmosphere, info, preset.Atmosphere):Play()
	TweenService:Create(colorCorrection, info, preset.Color):Play()
end

-- Moves the clock forward to `target` hours over `duration` seconds.
function Atmosphere.AdvanceClock(target: number, duration: number)
	clockTarget = target % 24
	local diff = (clockTarget - Lighting.ClockTime) % 24
	clockRate = diff / math.max(duration, 0.1)
end

return Atmosphere
]=])
make(n2, "ModuleScript", "Effects", [=[
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
]=])
end
make(n1, "ModuleScript", "Registry", [=[
-- Filled by the bootstrap script. Services look each other up here at call time.
return {}
]=])
do
local n3 = make(n1, "Folder", "Services", nil)
make(n3, "ModuleScript", "BossService", [=[
-- The Rotwood Colossus (night 10, 20, 25, 30...).
-- Readable patterns: Slam (red circle) exposes its glowing Core for 3s (2.5x damage taken);
-- Root Line (red lane) punishes standing at range; it summons Crawlers at 70% and 40%;
-- below 50% it enrages (faster, shorter telegraphs).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local Net = require(Root.Shared.Net)

local BossService = {}

local BOSS_ID = "RotwoodColossus"
local SLAM_RADIUS = 18
local LINE_LENGTH = 60
local LINE_WIDTH = 9
local CORE_EXPOSE_TIME = 3
local CORE_DAMAGE_MULT = 2.5

local boss = nil
local arenaCenter = Vector3.new(0, 0, 190)
local lastBarPush = 0

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function pushBar(force: boolean?)
	if not boss then
		Net.Get("BossBar"):FireAllClients(nil)
		return
	end
	local now = os.clock()
	if not force and now - lastBarPush < 0.15 then
		return
	end
	lastBarPush = now
	Net.Get("BossBar"):FireAllClients({
		Name = boss.Model.Name,
		Health = math.max(0, math.floor(boss.Health)),
		MaxHealth = boss.MaxHealth,
		Enraged = boss.Enraged,
		Exposed = boss.DamageTakenMult > 1,
	})
end

local function setCore(e, exposed: boolean)
	local core = e.Model:FindFirstChild("Core") :: BasePart?
	if not core then
		return
	end
	core.Material = if exposed then Enum.Material.Neon else Enum.Material.SmoothPlastic
	core.Color = if exposed then Color3.fromRGB(255, 240, 90) else Color3.fromRGB(60, 90, 40)
	local light = core:FindFirstChild("CoreLight") :: PointLight?
	if light then
		light.Range = if exposed then 22 else 0
	end
end

local function shake(intensity: number)
	Net.Get("Effect"):FireAllClients("Shake", intensity)
end

local function slam(e)
	e.Busy = true
	local windup = if e.Enraged then 1.0 else 1.3
	local center = e.Root.Position
	Effects.Telegraph(center, "Disc", Vector2.new(SLAM_RADIUS, 0), windup)
	task.delay(windup, function()
		if not e.Alive then
			return
		end
		Effects.Burst(Vector3.new(center.X, 1, center.Z), Color3.fromRGB(120, 90, 60), SLAM_RADIUS, 0.5)
		shake(1)
		for _, t in Registry.EnemyService.GatherTargets() do
			if flatDist(t.Root.Position, center) <= SLAM_RADIUS + Registry.EnemyService.TargetRadius(t) then
				Registry.EnemyService.ApplyDamage(t, e.Damage)
				if t.Kind == "Player" then
					local away = Vector3.new(t.Root.Position.X - center.X, 0, t.Root.Position.Z - center.Z)
					local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
					t.Root.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 45, 0)
				end
			end
		end
		e.DamageTakenMult = CORE_DAMAGE_MULT
		setCore(e, true)
		pushBar(true)
		for _, player in Players:GetPlayers() do
			Net.Notify(player, "💥 CORE EXPOSED! Hit it now for massive damage!", Color3.fromRGB(255, 230, 60))
		end
		task.delay(CORE_EXPOSE_TIME, function()
			if e.Alive then
				e.DamageTakenMult = 1
				setCore(e, false)
				pushBar(true)
			end
		end)
		e.Busy = false
		e.NextAttack = os.clock() + (if e.Enraged then 3.0 else 4.2)
	end)
end

local function rootLine(e, target)
	e.Busy = true
	local windup = if e.Enraged then 0.9 else 1.1
	local origin = e.Root.Position
	local toTarget = Vector3.new(target.Root.Position.X - origin.X, 0, target.Root.Position.Z - origin.Z)
	local dir = if toTarget.Magnitude > 0.1 then toTarget.Unit else e.Root.CFrame.LookVector
	Effects.Telegraph(origin + dir * (LINE_LENGTH / 2), "Rect", Vector2.new(LINE_WIDTH, LINE_LENGTH), windup, dir)
	task.delay(windup, function()
		if not e.Alive then
			return
		end
		Effects.Spikes(origin, dir, LINE_LENGTH, Color3.fromRGB(90, 60, 35))
		shake(0.5)
		for _, t in Registry.EnemyService.GatherTargets() do
			local rel = Vector3.new(t.Root.Position.X - origin.X, 0, t.Root.Position.Z - origin.Z)
			local along = rel:Dot(dir)
			local side = (rel - dir * along).Magnitude
			if along >= 0 and along <= LINE_LENGTH and side <= LINE_WIDTH / 2 + Registry.EnemyService.TargetRadius(t) then
				Registry.EnemyService.ApplyDamage(t, e.Damage * 0.8)
			end
		end
		e.Busy = false
		e.NextAttack = os.clock() + (if e.Enraged then 2.6 else 3.6)
	end)
end

local function summon(e, count: number)
	Net.Announce("🌲 The Colossus calls its brood!", Color3.fromRGB(150, 255, 110), false)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local pos = e.Root.Position + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
		local variant = if e.Night >= 20 then "Elite" else "Normal"
		Registry.EnemyService.Spawn("Crawler", variant, pos, e.Plan)
	end
end

local function onDamaged(e)
	local ratio = e.Health / e.MaxHealth
	if not e.Summon1 and ratio <= 0.7 then
		e.Summon1 = true
		summon(e, 3 + #Players:GetPlayers())
	end
	if not e.Enraged and ratio <= 0.5 then
		e.Enraged = true
		e.Speed *= 1.35
		for _, part in e.Model:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Eye" then
				part.Color = Color3.fromRGB(255, 60, 30)
			end
		end
		local fire = Instance.new("Fire")
		fire.Size = 12
		fire.Heat = 10
		fire.Parent = e.Model:FindFirstChild("Head")
		Net.Announce("🔥 THE COLOSSUS IS ENRAGED!", Color3.fromRGB(255, 90, 40), true)
		shake(1.2)
	end
	if not e.Summon2 and ratio <= 0.4 then
		e.Summon2 = true
		summon(e, 4 + #Players:GetPlayers())
	end
	pushBar(false)
end

local function tick(e, dt: number, now: number, targets)
	if e.Busy then
		return
	end
	if now >= (e.NextRetarget or 0) then
		e.NextRetarget = now + 1
		local best, bestDist = nil, 160
		for _, t in targets do
			local d = flatDist(t.Root.Position, e.Root.Position) * (if t.Kind == "Player" then 0.8 else 1)
			if d < bestDist then
				best, bestDist = t, d
			end
		end
		e.Target = best
	end

	local target = if e.Target and Registry.EnemyService.IsTargetValid(e.Target) then e.Target else nil
	local pos = e.Root.Position
	local goal = if target then target.Root.Position else arenaCenter
	local toGoal = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = toGoal.Magnitude
	local dir = if dist > 0.1 then toGoal / dist else e.Root.CFrame.LookVector

	local newPos = pos
	if dist > 12 then
		newPos = pos + dir * e.Speed * dt
	end
	e.Root.CFrame = CFrame.lookAt(newPos, newPos + Vector3.new(dir.X, 0, dir.Z))

	if target and now >= e.NextAttack then
		if dist <= SLAM_RADIUS + 2 then
			slam(e)
		elseif dist <= LINE_LENGTH then
			rootLine(e, target)
		end
	end
end

local function onDeath(e, killer: Player?)
	boss = nil
	pushBar(true)
	shake(1.5)
	Effects.Burst(e.Root.Position, Color3.fromRGB(150, 255, 90), 30, 1.2)
	local who = if killer then (" " .. killer.DisplayName .. " landed the final blow!") else ""
	Net.Announce("🏆 THE ROTWOOD COLOSSUS HAS FALLEN!" .. who, Color3.fromRGB(255, 215, 60), true)

	for _, player in Players:GetPlayers() do
		local profile = Registry.DataService.GetProfile(player)
		if profile then
			profile.BossesDefeated += 1
			Registry.EconomyService.AddCoins(player, 300)
			Registry.CreatureService.AddXP(player, 150)
			Registry.EggService.GiveEgg(player, "VoidEgg", "Boss reward")
		end
	end
	Registry.CycleService.EndNightEarly(12)
end

function BossService.IsActive(): boolean
	return boss ~= nil and boss.Alive
end

function BossService.Spawn(plan)
	if BossService.IsActive() then
		return
	end
	local players = #Players:GetPlayers()
	local scaling = {
		Night = plan.Night,
		HealthMult = (1 + 0.6 * math.max(0, players - 1)) * math.max(1, plan.Night / 10) ^ 1.1,
		DamageMult = plan.DamageMult,
		RewardMult = 1,
	}
	Net.Announce("⚠️ THE ROTWOOD COLOSSUS AWAKENS", Color3.fromRGB(255, 60, 60), true)
	shake(1.5)
	Effects.Burst(arenaCenter + Vector3.new(0, 5, 0), Color3.fromRGB(90, 255, 90), 25, 1)

	local e = Registry.EnemyService.Spawn(BOSS_ID, "Normal", arenaCenter, scaling)
	if not e then
		return
	end
	e.Plan = plan
	e.Night = plan.Night
	e.CustomTick = tick
	e.OnDamaged = onDamaged
	e.OnDeath = onDeath
	e.NextAttack = os.clock() + 4
	e.Enraged = false
	boss = e
	pushBar(true)
end

-- Boss survives until dawn: it retreats, no reward.
function BossService.Retreat()
	if not boss then
		return
	end
	local e = boss
	boss = nil
	pushBar(true)
	if e.Alive then
		Net.Announce("The Colossus retreats into the forest... it will return.", Color3.fromRGB(200, 200, 200), false)
		Registry.EnemyService.Remove(e)
	end
end

function BossService.Init()
	local map = workspace:FindFirstChild("Map")
	local center = map and map:FindFirstChild("BossArenaCenter", true)
	if center and center:IsA("BasePart") then
		arenaCenter = Vector3.new(center.Position.X, GameConfig.GroundY, center.Position.Z)
	end
end

return BossService
]=])
make(n3, "ModuleScript", "CombatService", [=[
-- Player weapon: the Torch (StarterPack). Hit detection is a server-side range + facing check,
-- so the client never reports hits or damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)

local CombatService = {}

local function torchDamage(): number
	local night = Root:GetAttribute("Night") or 1
	return GameConfig.TorchDamage * (1 + 0.08 * (night - 1))
end

local function swing(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	local look = rootPart.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local origin = rootPart.Position
	Effects.Burst(origin + flatLook * 4, Color3.fromRGB(255, 160, 50), 2.5, 0.2)

	local damage = torchDamage()
	for _, e in Registry.EnemyService.GetInRadius(origin, GameConfig.TorchRange + 2) do
		local offset = Vector3.new(e.Root.Position.X - origin.X, 0, e.Root.Position.Z - origin.Z)
		local edgeDist = offset.Magnitude - e.Radius
		if edgeDist <= GameConfig.TorchRange and (edgeDist < 3 or offset.Unit:Dot(flatLook) > 0.2) then
			Registry.EnemyService.Damage(e, damage, player)
		end
	end
end

local function hookTool(player: Player, tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("HODHooked") then
		return
	end
	tool:SetAttribute("HODHooked", true)
	local last = 0
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - last < GameConfig.TorchCooldown then
			return
		end
		last = now
		swing(player)
	end)
end

function CombatService.Start()
	local function onCharacter(player: Player, character: Model)
		for _, child in character:GetChildren() do
			hookTool(player, child)
		end
		character.ChildAdded:Connect(function(child)
			hookTool(player, child)
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CombatService
]=])
make(n3, "ModuleScript", "CreatureService", [=[
-- Owns creature records (in the profile) and the one active creature per player in the world.
-- Combat is semi-automatic: the creature picks targets itself; the player steers it with
-- Follow / Attack / Defend, tap-to-target, an ability, and feeding.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local CreatureData = require(Root.Config.CreatureData)
local Rarity = require(Root.Config.Rarity)
local Models = require(Root.Shared.Models)
local Net = require(Root.Shared.Net)

local CreatureService = {}

local VALID_MODES = { Follow = true, Attack = true, Defend = true }

local active: { [Player]: any } = {}
local modes: { [Player]: string } = {}
local folder: Folder
local rng = Random.new()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function profileOf(player: Player)
	return Registry.DataService.GetProfile(player)
end

local function ownerRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and rootPart and humanoid.Health > 0 then
		return rootPart :: BasePart, humanoid
	end
	return nil, nil
end

function CreatureService.CreateRecord(family: string, mutation: string?)
	return {
		Id = "C" .. (string.gsub(HttpService:GenerateGUID(false), "-", "")):sub(1, 12),
		Family = family,
		Stage = 1,
		Mutation = mutation,
		XP = 0,
		StageNights = 0,
		Nights = 0,
		Kills = 0,
		Aura = nil,
		Locked = false,
		At = os.time(),
	}
end

function CreatureService.FindCreature(profile, id: string)
	for i, record in profile.Creatures do
		if record.Id == id then
			return record, i
		end
	end
	return nil, nil
end

function CreatureService.GetSlotLimit(player: Player): number
	local bonus = if player:GetAttribute("Pass_ExtraSlots") then GameConfig.ExtraSlotsBonus else 0
	return GameConfig.BaseCreatureSlots + bonus
end

function CreatureService.GetActive()
	local list = {}
	for _, state in active do
		if not state.KO then
			table.insert(list, state)
		end
	end
	return list
end

function CreatureService.IsTargetable(state): boolean
	return state ~= nil and active[state.Player] == state and not state.KO
end

---------------------------------------------------------------------------------------------------
-- World model
---------------------------------------------------------------------------------------------------
local function publish(state)
	local player = state.Player
	player:SetAttribute("CreatureHP", math.floor(state.Health))
	player:SetAttribute("CreatureMaxHP", state.MaxHealth)
	player:SetAttribute("CreatureKO", state.KO)
	player:SetAttribute("CreatureMode", state.Mode)
	if state.Bar then
		state.Bar.Size = UDim2.fromScale(math.clamp(state.Health / state.MaxHealth, 0, 1), 1)
	end
end

local function makeNameplate(model: Model, record, top: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(160, 38)
	gui.StudsOffset = Vector3.new(0, top + 1.5, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = CreatureData.GetDisplayName(record)
	label.TextColor3 = Rarity.Colors[CreatureData.GetRarity(record)]
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0.15, 0, 0, 26)
	back.Size = UDim2.new(0.7, 0, 0, 7)
	back.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back

	gui.Parent = model.PrimaryPart
	return fill
end

local function despawn(player: Player)
	local state = active[player]
	if not state then
		return
	end
	active[player] = nil
	if state.Model then
		state.Model:Destroy()
	end
	player:SetAttribute("CreatureHP", nil)
	player:SetAttribute("CreatureMaxHP", nil)
	player:SetAttribute("CreatureKO", nil)
end

local function spawnFor(player: Player, keepHealthRatio: number?)
	despawn(player)
	local profile = profileOf(player)
	if not profile or not profile.Equipped then
		return
	end
	local record = CreatureService.FindCreature(profile, profile.Equipped)
	if not record then
		profile.Equipped = nil
		return
	end

	local model = Models.BuildCreature(record)
	model.Name = player.Name .. "'s " .. CreatureData.GetStageName(record)
	model:SetAttribute("OwnerId", player.UserId)
	local root = model.PrimaryPart :: BasePart
	local hip = model:GetAttribute("HipHeight") :: number
	local top = model:GetAttribute("Top") :: number
	local stats = CreatureData.GetStats(record)

	local rootPart = ownerRoot(player)
	local base = if rootPart then rootPart.Position + Vector3.new(4, 0, 4) else Registry.EnemyService.GetCampPosition()
	root.CFrame = CFrame.new(base.X, GameConfig.GroundY + hip, base.Z)

	local state = {
		Player = player,
		Record = record,
		Family = CreatureData.Families[record.Family],
		Model = model,
		Root = root,
		Hip = hip,
		Radius = model:GetAttribute("Radius") :: number,
		Scale = model:GetAttribute("Scale") :: number,
		Stats = stats,
		MaxHealth = stats.MaxHealth,
		Health = stats.MaxHealth * (keepHealthRatio or 1),
		Mode = modes[player] or "Attack",
		Target = nil,
		ManualTarget = nil,
		NextAttack = 0,
		NextThink = 0,
		KO = false,
		Bob = 0,
		Rainbow = record.Mutation == "Rainbow",
	}
	state.Bar = makeNameplate(model, record, top)
	model.Parent = folder
	active[player] = state
	publish(state)
	return state
end

function CreatureService.Refresh(player: Player)
	local state = active[player]
	local ratio = if state and not state.KO then state.Health / state.MaxHealth else 1
	spawnFor(player, ratio)
end

---------------------------------------------------------------------------------------------------
-- Health
---------------------------------------------------------------------------------------------------
local function heal(state, amount: number)
	state.Health = math.min(state.MaxHealth, state.Health + amount)
	publish(state)
end

local function revive(state, ratio: number)
	if active[state.Player] ~= state then
		return
	end
	state.KO = false
	state.Health = state.MaxHealth * ratio
	local rootPart = ownerRoot(state.Player)
	if rootPart then
		local p = rootPart.Position + Vector3.new(3, 0, 3)
		state.Root.CFrame = CFrame.new(p.X, GameConfig.GroundY + state.Hip, p.Z)
	end
	state.Model.Parent = folder
	Effects.Burst(state.Root.Position, Color3.fromRGB(120, 255, 140), 4, 0.5)
	publish(state)
end

function CreatureService.DamageCreature(state, amount: number)
	if not CreatureService.IsTargetable(state) then
		return
	end
	state.Health = math.max(0, state.Health - amount)
	Effects.DamageNumber(state.Root.Position + Vector3.new(0, state.Hip + 1, 0), amount, Color3.fromRGB(255, 150, 60))
	if state.Health <= 0 then
		state.KO = true
		state.Target = nil
		state.KOToken = (state.KOToken or 0) + 1
		local token = state.KOToken
		Effects.Burst(state.Root.Position, Color3.fromRGB(255, 255, 255), 4, 0.4)
		state.Model.Parent = nil
		local name = CreatureData.GetDisplayName(state.Record)
		Net.Notify(state.Player, ("💫 %s was knocked out! Feed it a berry (F) or wait %ds."):format(name, GameConfig.CreatureKORecoverTime), Color3.fromRGB(255, 170, 60))
		task.delay(GameConfig.CreatureKORecoverTime, function()
			if state.KO and state.KOToken == token then
				revive(state, 0.5)
			end
		end)
	end
	publish(state)
end

---------------------------------------------------------------------------------------------------
-- Progression
---------------------------------------------------------------------------------------------------
local function equippedRecord(player: Player)
	local profile = profileOf(player)
	if not profile or not profile.Equipped then
		return nil, profile
	end
	return CreatureService.FindCreature(profile, profile.Equipped), profile
end

function CreatureService.AddXP(player: Player, amount: number)
	local record = equippedRecord(player)
	if not record then
		return
	end
	local wasReady = CreatureData.CanEvolve(record)
	record.XP += math.floor(amount)
	Registry.DataService.Changed(player)
	if not wasReady and CreatureData.CanEvolve(record) then
		Net.Notify(player, ("✨ %s is ready to EVOLVE! Open Creatures or tap Evolve."):format(CreatureData.GetDisplayName(record)), Color3.fromRGB(255, 220, 80))
	end
end

-- Called at dawn for every player who survived the night.
function CreatureService.AwardNight(player: Player, xp: number)
	local record = equippedRecord(player)
	if not record then
		return
	end
	record.Nights += 1
	record.StageNights += 1
	CreatureService.AddXP(player, xp)
end

function CreatureService.OnDawn()
	for _, state in active do
		if state.KO then
			revive(state, 1)
		else
			heal(state, state.MaxHealth)
		end
	end
end

local function evolve(player: Player, id: string)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local record = CreatureService.FindCreature(profile, id)
	if not record then
		return
	end
	local ok, reason = CreatureData.CanEvolve(record)
	if not ok then
		Net.Notify(player, reason or "Can't evolve yet", Color3.fromRGB(255, 120, 120))
		return
	end

	local fromName = CreatureData.GetDisplayName(record)
	local stage = CreatureData.Stages[record.Stage]
	record.XP -= stage.XPToEvolve
	record.StageNights = 0
	record.Stage += 1

	local mutated = false
	if not record.Mutation and rng:NextNumber() < GameConfig.EvolveMutationChance then
		record.Mutation = CreatureData.RollMutation(rng)
		mutated = true
		profile.Stats.Mutations += 1
	end
	profile.Stats.Evolutions += 1
	local key = CreatureData.DiscoveryKey(record)
	local isNew = not profile.Discovered[key]
	profile.Discovered[key] = true
	Registry.DataService.Changed(player)

	if profile.Equipped == record.Id then
		local state = active[player]
		if state and not state.KO then
			Effects.Burst(state.Root.Position, Color3.new(1, 1, 1), 10, 0.8)
		end
		spawnFor(player, 1)
	end

	Net.Get("Evolved"):FireClient(player, { Creature = record, FromName = fromName, Mutated = mutated, IsNew = isNew })

	local newName = CreatureData.GetDisplayName(record)
	local rarity = CreatureData.GetRarity(record)
	if mutated or record.Stage >= #CreatureData.Stages then
		task.delay(3, function()
			Net.Announce(("🐲 %s's %s evolved into %s!"):format(player.DisplayName, fromName, newName), Rarity.Colors[rarity], mutated)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Equip / manage
---------------------------------------------------------------------------------------------------
function CreatureService.Equip(player: Player, id: string): boolean
	local profile = profileOf(player)
	if not profile or not CreatureService.FindCreature(profile, id) then
		return false
	end
	profile.Equipped = id
	Registry.DataService.Changed(player)
	spawnFor(player, 1)
	return true
end

local function isNight(): boolean
	return Root:GetAttribute("Phase") == "Night"
end

---------------------------------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------------------------------
local function acquireTarget(state, rootPart: BasePart)
	if state.Mode == "Follow" then
		return nil
	end
	if state.ManualTarget then
		if Registry.EnemyService.IsAlive(state.ManualTarget) then
			return state.ManualTarget
		end
		state.ManualTarget = nil
	end
	local defending = state.Mode == "Defend"
	local radius = if defending then GameConfig.CreatureDefendRadius else GameConfig.CreatureAggroRadius
	local best, bestDist = nil, math.huge
	for _, e in Registry.EnemyService.GetInRadius(rootPart.Position, radius) do
		local d = flatDist(e.Root.Position, state.Root.Position)
		if d < bestDist then
			best, bestDist = e, d
		end
	end
	return best
end

local function performAttack(state, target)
	local player = state.Player
	local damage = state.Stats.Damage
	if state.Family.Ranged then
		local from = state.Root.Position + Vector3.new(0, state.Hip * 0.5, 0)
		local travel = Effects.Projectile(from, target.Root.Position, state.Family.Accent, 90, 0.9 * state.Scale)
		task.delay(travel, function()
			Registry.EnemyService.Damage(target, damage, player)
		end)
	else
		local look = state.Root.CFrame.LookVector
		Effects.Burst(state.Root.Position + look * (state.Radius + 1), state.Family.Accent, 1.5 * state.Scale, 0.2)
		Registry.EnemyService.Damage(target, damage, player)
	end
end

local function useAbility(player: Player)
	local state = active[player]
	if not state or state.KO then
		return
	end
	local now = serverNow()
	if now < (player:GetAttribute("AbilityReadyAt") or 0) then
		return
	end
	local ability = state.Family.Ability
	local damage = state.Stats.Damage * ability.DamageMult

	if ability.Kind == "Burst" then
		local center = state.Root.Position
		Effects.Burst(center, state.Family.Accent, ability.Radius, 0.5)
		for _, e in Registry.EnemyService.GetInRadius(center, ability.Radius) do
			Registry.EnemyService.Damage(e, damage, player)
		end
		if ability.HealOwner then
			local _, humanoid = ownerRoot(player)
			if humanoid then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + ability.HealOwner)
			end
			heal(state, state.MaxHealth * 0.15)
		end
	elseif ability.Kind == "Pounce" then
		local target = state.Target
		if not Registry.EnemyService.IsAlive(target) then
			target = nil
			local bestDist = ability.Radius
			for _, e in Registry.EnemyService.GetInRadius(state.Root.Position, ability.Radius) do
				local d = flatDist(e.Root.Position, state.Root.Position)
				if d < bestDist then
					target, bestDist = e, d
				end
			end
		end
		if not target then
			Net.Notify(player, "No enemy in range to pounce on.", Color3.fromRGB(200, 200, 200))
			return
		end
		local tp = target.Root.Position
		local from = state.Root.Position
		local dir = Vector3.new(tp.X - from.X, 0, tp.Z - from.Z)
		local landing = if dir.Magnitude > 0.1 then tp - dir.Unit * (target.Radius + state.Radius) else tp
		Effects.Burst(from, state.Family.Accent, 3, 0.3)
		state.Root.CFrame = CFrame.lookAt(Vector3.new(landing.X, GameConfig.GroundY + state.Hip, landing.Z), Vector3.new(tp.X, GameConfig.GroundY + state.Hip, tp.Z))
		Effects.Burst(landing, state.Family.Accent, 5, 0.4)
		Registry.EnemyService.Damage(target, damage, player)
		state.Target = target
	end

	player:SetAttribute("AbilityReadyAt", now + ability.Cooldown)
end

---------------------------------------------------------------------------------------------------
-- Per-frame movement and combat
---------------------------------------------------------------------------------------------------
local function step(state, dt: number, now: number)
	if state.KO then
		return
	end
	local rootPart = ownerRoot(state.Player)
	if not rootPart then
		return
	end

	if now >= state.NextThink then
		state.NextThink = now + 0.15
		state.Target = acquireTarget(state, rootPart)
		if state.Target and flatDist(state.Target.Root.Position, rootPart.Position) > GameConfig.CreatureLeashDistance then
			state.Target = nil
			state.ManualTarget = nil
		end
	end

	local pos = state.Root.Position
	local target = if Registry.EnemyService.IsAlive(state.Target) then state.Target else nil
	local goal: Vector3
	local face: Vector3
	if target then
		local tp = target.Root.Position
		local toTarget = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
		local reach = state.Stats.Range + target.Radius
		if toTarget.Magnitude > reach * 0.85 then
			goal = tp - toTarget.Unit * reach * 0.7
		else
			goal = pos
		end
		face = tp
	else
		goal = (rootPart.CFrame * CFrame.new(3.5 + state.Radius, 0, 4 + state.Radius)).Position
		face = goal + rootPart.CFrame.LookVector * 10
	end

	local delta = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = delta.Magnitude
	local newPos = pos
	if dist > CreatureService.LeashTeleport then
		newPos = Vector3.new(goal.X, pos.Y, goal.Z)
	elseif dist > 0.3 then
		local speed = GameConfig.CreatureMoveSpeed * (if dist > 20 then 1.6 else 1)
		newPos = pos + delta.Unit * math.min(dist, speed * dt)
	end

	local moving = (newPos - pos).Magnitude > 0.01
	state.Bob += dt * (if moving then 14 else 3)
	local y = GameConfig.GroundY + state.Hip + math.abs(math.sin(state.Bob)) * 0.25 * state.Scale
	local lookDir = Vector3.new(face.X - newPos.X, 0, face.Z - newPos.Z)
	if lookDir.Magnitude < 0.1 then
		lookDir = state.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if lookDir.Magnitude < 0.01 then
		lookDir = Vector3.new(0, 0, -1)
	end
	local at = Vector3.new(newPos.X, y, newPos.Z)
	state.Root.CFrame = CFrame.lookAt(at, at + lookDir)

	if target and now >= state.NextAttack then
		local d = flatDist(state.Root.Position, target.Root.Position)
		if d <= state.Stats.Range + target.Radius + 0.5 then
			state.NextAttack = now + 1 / state.Stats.AttackRate
			performAttack(state, target)
		end
	end

	if state.Rainbow then
		local color = Color3.fromHSV((os.clock() * 0.25) % 1, 0.7, 1)
		for _, part in state.Model:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("Tint") then
				part.Color = color
			end
		end
	end
end

CreatureService.LeashTeleport = GameConfig.CreatureLeashDistance

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function CreatureService.Init()
	folder = workspace:FindFirstChild("Creatures") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Creatures"
		folder.Parent = workspace
	end

	Registry.DataService.ProfileLoaded:Connect(function(player: Player)
		if player.Character then
			spawnFor(player)
		end
	end)
	Registry.DataService.ProfileReleasing:Connect(function(player: Player)
		despawn(player)
		modes[player] = nil
	end)
end

function CreatureService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			if profileOf(player) then
				spawnFor(player)
			end
			local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					despawn(player)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, state in active do
			local ok, err = pcall(step, state, dt, now)
			if not ok then
				warn("[CreatureService] step error: " .. tostring(err))
			end
		end
	end)

	Net.On("EquipCreature", function(player, id)
		if type(id) ~= "string" then
			return
		end
		local profile = profileOf(player)
		if not profile or profile.Equipped == id then
			return
		end
		if isNight() and active[player] then
			Net.Notify(player, "You can't swap creatures at night!", Color3.fromRGB(255, 120, 120))
			return
		end
		if CreatureService.Equip(player, id) then
			local record = CreatureService.FindCreature(profile, id)
			Net.Notify(player, ("Equipped %s"):format(CreatureData.GetDisplayName(record)), Color3.fromRGB(150, 230, 255))
		end
	end, 0.8)

	Net.On("FeedCreature", function(player)
		local state = active[player]
		if not state then
			Net.Notify(player, "Hatch and equip a creature first!", Color3.fromRGB(255, 170, 60))
			return
		end
		if not Registry.EconomyService.SpendBerries(player, 1) then
			Net.Notify(player, "No berries! Pick 🍓 bushes in the forest.", Color3.fromRGB(255, 120, 120))
			return
		end
		if state.KO then
			state.KO = false
			revive(state, 0.4)
			Net.Notify(player, "🍓 Your creature is back on its feet!", Color3.fromRGB(120, 255, 140))
		else
			heal(state, state.MaxHealth * GameConfig.FeedHealPercent)
			Effects.Burst(state.Root.Position + Vector3.new(0, state.Hip, 0), Color3.fromRGB(255, 110, 150), 2, 0.4)
			Effects.FloatText(state.Root.Position + Vector3.new(0, state.Hip + 2, 0), "+" .. GameConfig.FeedXP .. " XP", Color3.fromRGB(255, 150, 200))
		end
		CreatureService.AddXP(player, GameConfig.FeedXP)
	end, GameConfig.FeedCooldown)

	Net.On("SetCommand", function(player, mode)
		if type(mode) ~= "string" or not VALID_MODES[mode] then
			return
		end
		modes[player] = mode
		local state = active[player]
		if state then
			state.Mode = mode
			state.ManualTarget = nil
			state.Target = nil
			publish(state)
		end
	end, 0.2)

	Net.On("SetTarget", function(player, instance)
		local state = active[player]
		if not state or typeof(instance) ~= "Instance" then
			return
		end
		local enemy = Registry.EnemyService.FindByModel(instance)
		if not enemy then
			return
		end
		local rootPart = ownerRoot(player)
		if not rootPart or flatDist(rootPart.Position, enemy.Root.Position) > 120 then
			return
		end
		state.ManualTarget = enemy
		state.Target = enemy
		if state.Mode == "Follow" then
			state.Mode = "Attack"
			modes[player] = "Attack"
		end
		publish(state)
	end, 0.2)

	Net.On("UseAbility", useAbility, 0.3)

	Net.On("EvolveCreature", function(player, id)
		if type(id) == "string" then
			evolve(player, id)
		end
	end, 1)

	Net.On("ToggleLock", function(player, id)
		local profile = profileOf(player)
		local record = profile and type(id) == "string" and CreatureService.FindCreature(profile, id)
		if record then
			record.Locked = not record.Locked
			Registry.DataService.Changed(player)
		end
	end, 0.3)

	Net.On("ReleaseCreature", function(player, id)
		local profile = profileOf(player)
		if not profile or type(id) ~= "string" then
			return
		end
		local record, index = CreatureService.FindCreature(profile, id)
		if not record or not index then
			return
		end
		if record.Locked then
			Net.Notify(player, "That creature is locked. Unlock it first.", Color3.fromRGB(255, 120, 120))
			return
		end
		if profile.Equipped == id then
			Net.Notify(player, "You can't release your equipped creature.", Color3.fromRGB(255, 120, 120))
			return
		end
		table.remove(profile.Creatures, index)
		local coins = (Rarity.ReleaseCoins[CreatureData.GetRarity(record)] or 10) * record.Stage
		Registry.EconomyService.AddCoins(player, coins)
		Net.Notify(player, ("Released %s (+%d coins)"):format(CreatureData.GetDisplayName(record), coins), Color3.fromRGB(255, 215, 70))
	end, 0.3)

	Net.On("EquipAura", function(player, auraId)
		local profile = profileOf(player)
		local record = equippedRecord(player)
		if not profile or not record then
			return
		end
		if auraId == "" or auraId == nil then
			record.Aura = nil
		elseif type(auraId) == "string" and CreatureData.Auras[auraId] then
			local owned = profile.Auras[auraId] or (auraId == "Golden" and player:GetAttribute("Pass_VIP"))
			if not owned then
				return
			end
			record.Aura = auraId
		else
			return
		end
		Registry.DataService.Changed(player)
		CreatureService.Refresh(player)
	end, 0.5)
end

return CreatureService
]=])
make(n3, "ModuleScript", "CycleService", [=[
-- The central loop: DAY (prepare) -> NIGHT (survive) -> DAWN (rewards) -> next night.
-- Phase state is published as attributes on ReplicatedStorage.HatchOrDie (Phase, Night,
-- PhaseEndsAt, Modifier) so every client UI can react without extra remotes.
-- A night ends when its timer runs out OR when every enemy of the wave (and the boss) is dead.
-- If everyone in the server is down at once, the run resets to Night 1. Hatch... or die.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Atmosphere = require(script.Parent.Parent.Modules.Atmosphere)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local EnemyData = require(Root.Config.EnemyData)
local Net = require(Root.Shared.Net)

local CycleService = {}

local rng = Random.new()
local phase = "Day"
local night = 1
local endsAt = 0
local runToken = 0
local wiping = false
local waitingForDawn: { [Player]: boolean } = {}
local spawnPoints: { BasePart } = {}
local spawnerDone = false

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function publish(modifier: string?)
	Root:SetAttribute("Phase", phase)
	Root:SetAttribute("Night", night)
	Root:SetAttribute("PhaseEndsAt", endsAt)
	Root:SetAttribute("Modifier", modifier or "None")
end

local function setPhase(newPhase: string, duration: number, modifier: string?)
	phase = newPhase
	endsAt = serverNow() + duration
	publish(modifier)
end

function CycleService.GetPhase(): string
	return phase
end

function CycleService.GetNight(): number
	return night
end

function CycleService.EndNightEarly(delaySeconds: number)
	if phase ~= "Night" then
		return
	end
	local newEnd = serverNow() + delaySeconds
	if newEnd < endsAt then
		endsAt = newEnd
		Root:SetAttribute("PhaseEndsAt", endsAt)
	end
end

-- Returns false if the run was reset (wipe) while waiting.
local function waitForPhaseEnd(token: number): boolean
	local earlyEndQueued = false
	while serverNow() < endsAt do
		if runToken ~= token then
			return false
		end
		if phase == "Night" and spawnerDone and not earlyEndQueued
			and Registry.EnemyService.CountAlive() == 0 and not Registry.BossService.IsActive() then
			earlyEndQueued = true
			Net.NotifyAll("🌅 The forest falls quiet... dawn is coming.", Color3.fromRGB(255, 220, 150))
			CycleService.EndNightEarly(4)
		end
		task.wait(0.25)
	end
	return runToken == token
end

---------------------------------------------------------------------------------------------------
-- Player lives
---------------------------------------------------------------------------------------------------
local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function checkWipe()
	if phase ~= "Night" or wiping then
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	for _, player in players do
		if isAlive(player) and not waitingForDawn[player] then
			return
		end
	end
	wiping = true
	runToken += 1
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		if phase == "Night" and not wiping then
			waitingForDawn[player] = true
			Net.Notify(player, "💀 You fell! You'll return at dawn - if anyone survives...", Color3.fromRGB(255, 80, 80))
			checkWipe()
		else
			task.delay(GameConfig.DayRespawnDelay, function()
				if player.Parent and not waitingForDawn[player] and not isAlive(player) then
					player:LoadCharacter()
				end
			end)
		end
	end)
end

local function respawnWaiting()
	for player in waitingForDawn do
		waitingForDawn[player] = nil
		if player.Parent then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		if not isAlive(player) then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Night
---------------------------------------------------------------------------------------------------
local function randomSpawnPosition(): Vector3
	if #spawnPoints == 0 then
		local angle = rng:NextNumber() * math.pi * 2
		return Vector3.new(math.cos(angle) * 220, 0, math.sin(angle) * 220)
	end
	local point = spawnPoints[rng:NextInteger(1, #spawnPoints)]
	return point.Position + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
end

local function runSpawner(plan, duration: number, token: number)
	spawnerDone = false
	local total = plan.TotalEnemies
	local window = duration * 0.6
	local groupSize = math.clamp(math.floor(plan.Night / 4) + 1, 1, 4)
	local groups = math.max(1, math.ceil(total / groupSize))
	local interval = window / groups
	task.wait(3)
	local spawned = 0
	while spawned < total and runToken == token and phase == "Night" do
		local origin = randomSpawnPosition()
		for _ = 1, groupSize do
			if spawned >= total then
				break
			end
			if Registry.EnemyService.CountAlive() < plan.MaxAlive then
				local typeId = EnemyData.PickType(plan, rng)
				local variant = EnemyData.PickVariant(plan, rng)
				Registry.EnemyService.Spawn(typeId, variant, origin + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), plan)
				spawned += 1
			end
		end
		task.wait(interval)
	end
	spawnerDone = true
end

local function milestoneText(n: number, plan): string?
	if n == 100 then
		return "☄️ NIGHT 100 - THE APOCALYPSE"
	elseif n == 50 then
		return "👁️ NIGHT 50 - NIGHTMARE BEGINS"
	elseif plan.Boss then
		return "⚠️ BOSS NIGHT"
	elseif plan.Modifier == "BloodMoon" then
		return "🩸 BLOOD MOON - enemies swarm, rewards x1.5"
	elseif plan.MiniBoss then
		return "⚠️ An Alpha Brute hunts tonight"
	end
	return nil
end

local function dawn(plan)
	Registry.BossService.Retreat()
	Registry.EnemyService.ClearAll()

	local reward = GameConfig.NightReward(night)
	local coins = math.floor(reward.Coins * plan.RewardMult)
	for _, player in Players:GetPlayers() do
		local profile = Registry.DataService.GetProfile(player)
		if profile then
			if waitingForDawn[player] then
				Net.Get("NightResult"):FireClient(player, { Night = night, Survived = false })
			else
				Registry.EconomyService.AddCoins(player, coins)
				Registry.EconomyService.AddBerries(player, reward.Berries)
				Registry.CreatureService.AwardNight(player, reward.CreatureXP)
				profile.Stats.NightsSurvived += 1
				if night > profile.HighestNight then
					profile.HighestNight = night
				end
				local eggs = GameConfig.NightEggRewards(night)
				if player:GetAttribute("Pass_VIP") then
					table.insert(eggs, "ForestEgg")
				end
				for _, eggId in eggs do
					Registry.EggService.GiveEgg(player, eggId, "night reward")
				end
				Registry.DataService.Changed(player)
				Net.Get("NightResult"):FireClient(player, {
					Night = night,
					Survived = true,
					Coins = coins,
					XP = reward.CreatureXP,
					Berries = reward.Berries,
					Eggs = eggs,
				})
			end
		end
	end

	respawnWaiting()
	Registry.CreatureService.OnDawn()
end

local function wipe(lostNight: number)
	Registry.BossService.Retreat()
	Registry.EnemyService.ClearAll()
	Net.Announce(("☠️ EVERYONE FELL ON NIGHT %d. The forest resets..."):format(lostNight), Color3.fromRGB(255, 60, 60), true)
	for _, player in Players:GetPlayers() do
		Net.Get("NightResult"):FireClient(player, { Night = lostNight, Survived = false, Wipe = true })
	end
	task.wait(GameConfig.WipeResetDelay)
	night = 1
	wiping = false
	respawnWaiting()
	Registry.CreatureService.OnDawn()
end

local function runLoop()
	while true do
		local token = runToken

		-- DAY
		local dayLength = if night == 1 then GameConfig.FirstDayLength else GameConfig.DayLength
		setPhase("Day", dayLength)
		Atmosphere.Apply("Day", 4)
		Atmosphere.AdvanceClock(7.5, 3)
		task.delay(3, function()
			if phase == "Day" then
				Atmosphere.AdvanceClock(17.8, dayLength - 3)
			end
		end)
		Registry.WorldService.OnDayStart(night)
		waitForPhaseEnd(token)

		-- NIGHT
		local plan = EnemyData.GetNightPlan(night, #Players:GetPlayers(), rng)
		local nightLength = if plan.Boss then GameConfig.BossNightLength else GameConfig.NightLength
		setPhase("Night", nightLength, plan.Modifier)
		Atmosphere.Apply(plan.Modifier, 4)
		if plan.Modifier == "Apocalypse" then
			Atmosphere.AdvanceClock(18.4, 4)
		else
			Atmosphere.AdvanceClock(0, 4)
			task.delay(4, function()
				if phase == "Night" then
					Atmosphere.AdvanceClock(4.5, nightLength - 4)
				end
			end)
		end
		local milestone = milestoneText(night, plan)
		if milestone then
			Net.Announce(milestone, Color3.fromRGB(255, 90, 90), true)
		end
		spawnerDone = false
		task.spawn(runSpawner, plan, nightLength, token)
		if plan.Boss then
			task.delay(6, function()
				if runToken == token and phase == "Night" then
					Registry.BossService.Spawn(plan)
				end
			end)
		elseif plan.MiniBoss then
			task.delay(20, function()
				if runToken == token and phase == "Night" then
					local alpha = Registry.EnemyService.Spawn("Brute", "Elite", randomSpawnPosition(), plan)
					if alpha then
						alpha.Model.Name = "Alpha Brute"
						alpha.MaxHealth *= 2
						alpha.Health = alpha.MaxHealth
						alpha.Coins *= 3
					end
				end
			end)
		end

		local survived = waitForPhaseEnd(token)
		if survived then
			Atmosphere.AdvanceClock(6.5, 3)
			dawn(plan)
			night += 1
		else
			wipe(night)
		end
	end
end

function CycleService.Init()
	Atmosphere.Init()
	Players.CharacterAutoLoads = false

	local map = workspace:FindFirstChild("Map")
	local spawns = map and map:FindFirstChild("EnemySpawns")
	if spawns then
		for _, p in spawns:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(spawnPoints, p)
			end
		end
	end

	Registry.DataService.ProfileReleasing:Connect(function(player: Player)
		waitingForDawn[player] = nil
		task.delay(0.5, checkWipe)
	end)
end

function CycleService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		else
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		waitingForDawn[player] = nil
	end)

	runLoop()
end

return CycleService
]=])
make(n3, "ModuleScript", "DataService", [=[
-- Player profiles: load with a session lock, reconcile with defaults, migrate by version,
-- autosave, save on leave and on shutdown. Profiles are plain tables (DataStore-safe).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local Net = require(Root.Shared.Net)
local Signal = require(Root.Shared.Signal)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile)

local CURRENT_VERSION = 1
local SESSION_TIMEOUT = 330
local LOAD_ATTEMPTS = 6

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local store: DataStore? = nil
local savingEnabled = true

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function defaultProfile()
	return {
		Version = CURRENT_VERSION,
		Coins = 0,
		Berries = 3,
		Eggs = {},
		Creatures = {},
		Equipped = nil,
		Incubator = nil,
		Auras = {},
		Discovered = {},
		HighestNight = 0,
		BossesDefeated = 0,
		Stats = { Kills = 0, Hatches = 0, Mutations = 0, Evolutions = 0, NightsSurvived = 0 },
		Settings = { Music = true },
		Receipts = {},
		CreatedAt = os.time(),
	}
end

-- Adds any fields that exist in the template but not in saved data (new features after launch).
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

-- [fromVersion] = function(data) ... end. Add an entry whenever the schema changes shape.
local MIGRATIONS = {}

local function migrate(data)
	while (data.Version or 0) < CURRENT_VERSION do
		local from = data.Version or 0
		local step = MIGRATIONS[from]
		if step then
			step(data)
		end
		data.Version = from + 1
	end
	reconcile(data, defaultProfile())
	return data
end

local function keyFor(player: Player): string
	return "P_" .. player.UserId
end

local function isStudioAccessError(err: any): boolean
	local text = tostring(err)
	return text:find("403") ~= nil or text:find("Studio") ~= nil or text:find("API") ~= nil
end

local function loadData(player: Player)
	if not store or not savingEnabled then
		return defaultProfile()
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local loaded = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(old)
				old = old or {}
				local lock = old.Lock
				local force = attempt == LOAD_ATTEMPTS
				if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < SESSION_TIMEOUT and not force then
					lockedElsewhere = true
					return nil
				end
				lockedElsewhere = false
				loaded = old.Data
				old.Lock = { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if ok and not lockedElsewhere then
			return if loaded then migrate(loaded) else defaultProfile()
		end
		if not ok then
			warn(("[DataService] Load failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(err)))
			if isStudioAccessError(err) then
				savingEnabled = false
				warn("[DataService] DataStores unavailable (enable 'Studio Access to API Services'). Saving disabled this session.")
				return defaultProfile()
			end
		end
		if not player.Parent then
			return nil
		end
		task.wait(if lockedElsewhere then 5 else 2)
	end
	return nil
end

function DataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not store or not savingEnabled then
		return false
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			old = old or {}
			local lock = old.Lock
			if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < SESSION_TIMEOUT then
				-- Another server owns this profile now; never overwrite its newer data.
				return nil
			end
			old.Data = profile
			old.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return old
		end)
	end)
	if not ok then
		warn(("[DataService] Save failed for %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

function DataService.GetProfile(player: Player)
	return profiles[player]
end

function DataService.WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.GetLoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

function DataService.IsSavingEnabled(): boolean
	return savingEnabled and store ~= nil
end

-- Mark the profile as changed; the client view and leaderstats are pushed once per batch.
function DataService.Changed(player: Player)
	dirty[player] = true
end

local function clientView(profile)
	local view = table.clone(profile)
	view.Receipts = nil
	return view
end

local function updateLeaderstats(player: Player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = stats
		local best = Instance.new("IntValue")
		best.Name = "Best Night"
		best.Parent = stats
		stats.Parent = player
	end
	local values = stats :: any
	values.Coins.Value = profile.Coins
	values["Best Night"].Value = profile.HighestNight
end

function DataService.SyncNow(player: Player)
	local profile = profiles[player]
	if profile then
		dirty[player] = nil
		updateLeaderstats(player, profile)
		Net.Get("SyncData"):FireClient(player, clientView(profile), DataService.IsSavingEnabled())
	end
end

local function onPlayerAdded(player: Player)
	local profile = loadData(player)
	if not player.Parent then
		return
	end
	if not profile then
		player:Kick("Your save data could not be loaded. Please rejoin in a minute - your progress is safe.")
		return
	end
	profiles[player] = profile
	DataService.SyncNow(player)
	DataService.ProfileLoaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	DataService.ProfileReleasing:Fire(player, profile)
	DataService.Save(player, true)
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.Init()
	if game.PlaceId == 0 then
		savingEnabled = false
		warn("[DataService] Place is not published - saving disabled. Publish the place to enable DataStores.")
	else
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(GameConfig.DataStoreName)
		end)
		if ok then
			store = result
		else
			savingEnabled = false
			warn("[DataService] Could not open DataStore: " .. tostring(result))
		end
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Net.On("ClientReady", function(player)
		DataService.SyncNow(player)
	end, 2)

	-- Batched client sync.
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player in dirty do
				DataService.SyncNow(player)
			end
		end
	end)

	-- Autosave.
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
]=])
make(n3, "ModuleScript", "EconomyService", [=[
-- Single soft currency (Coins) plus Berries (creature food). All mutations go through here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local Net = require(Root.Shared.Net)

local EconomyService = {}

local function profileOf(player: Player)
	return Registry.DataService.GetProfile(player)
end

function EconomyService.AddCoins(player: Player, amount: number): boolean
	local profile = profileOf(player)
	if not profile or amount <= 0 then
		return false
	end
	profile.Coins += math.floor(amount)
	Registry.DataService.Changed(player)
	return true
end

function EconomyService.SpendCoins(player: Player, amount: number): boolean
	local profile = profileOf(player)
	if not profile or amount < 0 then
		return false
	end
	if profile.Coins < amount then
		Net.Notify(player, ("Not enough coins (%d more needed)"):format(amount - profile.Coins), Color3.fromRGB(255, 90, 90))
		return false
	end
	profile.Coins -= amount
	Registry.DataService.Changed(player)
	return true
end

function EconomyService.AddBerries(player: Player, amount: number): boolean
	local profile = profileOf(player)
	if not profile or amount <= 0 then
		return false
	end
	profile.Berries += math.floor(amount)
	Registry.DataService.Changed(player)
	return true
end

function EconomyService.SpendBerries(player: Player, amount: number): boolean
	local profile = profileOf(player)
	if not profile or profile.Berries < amount then
		return false
	end
	profile.Berries -= amount
	Registry.DataService.Changed(player)
	return true
end

return EconomyService
]=])
make(n3, "ModuleScript", "EggService", [=[
-- Egg inventory + one incubator per player. The server decides every hatch result; the client
-- only asks "incubate this egg" and plays the reveal it is told about.
-- Incubation end time is stored in the profile (unix time), so it survives rejoining.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local EggData = require(Root.Config.EggData)
local CreatureData = require(Root.Config.CreatureData)
local Rarity = require(Root.Config.Rarity)
local Net = require(Root.Shared.Net)

local EggService = {}

local rng = Random.new()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function profileOf(player: Player)
	return Registry.DataService.GetProfile(player)
end

local function newEggId(): string
	return "E" .. (string.gsub(HttpService:GenerateGUID(false), "-", "")):sub(1, 12)
end

local function rollFamily(egg): string
	local total = 0
	for _, entry in egg.Pool do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in egg.Pool do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Family
		end
	end
	return egg.Pool[1].Family
end

-- force = true bypasses the egg bag limit (paid products must always be delivered).
function EggService.GiveEgg(player: Player, eggId: string, source: string?, force: boolean?)
	local profile = profileOf(player)
	local egg = EggData[eggId]
	if not profile or not egg then
		return nil
	end
	if #profile.Eggs >= GameConfig.MaxEggs and not force then
		local refund = math.floor(egg.Price * 0.5)
		Registry.EconomyService.AddCoins(player, refund)
		Net.Notify(player, ("Egg bag full! %s sold for %d coins."):format(egg.Name, refund), Color3.fromRGB(255, 200, 80))
		return nil
	end
	local record = { Id = newEggId(), EggId = eggId, At = os.time() }
	table.insert(profile.Eggs, record)
	Registry.DataService.Changed(player)
	local suffix = if source then (" (" .. source .. ")") else ""
	Net.Notify(player, ("🥚 You got a %s!%s"):format(egg.Name, suffix), Rarity.Colors[egg.Rarity])
	EggService.TryAutoHatch(player)
	return record
end

function EggService.StartIncubation(player: Player, eggRecordId: string): (boolean, string?)
	local profile = profileOf(player)
	if not profile then
		return false, "Still loading..."
	end
	if profile.Incubator then
		return false, "Your incubator is busy."
	end
	if #profile.Creatures >= Registry.CreatureService.GetSlotLimit(player) then
		return false, "Creature storage full! Release a creature first."
	end
	local index
	for i, egg in profile.Eggs do
		if egg.Id == eggRecordId then
			index = i
			break
		end
	end
	if not index then
		return false, "You don't have that egg."
	end
	local eggRecord = table.remove(profile.Eggs, index)
	local egg = EggData[eggRecord.EggId] or EggData.ForestEgg

	local hatchTime = egg.HatchTime
	if profile.Stats.Hatches == 0 then
		hatchTime = GameConfig.StarterHatchTime
	end
	if player:GetAttribute("Pass_DoubleHatch") then
		hatchTime *= 0.5
	end
	local now = serverNow()
	profile.Incubator = { EggId = eggRecord.EggId, StartedAt = now, EndsAt = now + hatchTime }
	Registry.DataService.Changed(player)
	return true, nil
end

function EggService.TryAutoHatch(player: Player)
	local profile = profileOf(player)
	if not profile or profile.Incubator or #profile.Eggs == 0 then
		return
	end
	if not player:GetAttribute("Pass_AutoHatch") then
		return
	end
	-- Rarest egg first.
	local best
	for _, egg in profile.Eggs do
		if not best or (EggData[egg.EggId].Order or 0) > (EggData[best.EggId].Order or 0) then
			best = egg
		end
	end
	EggService.StartIncubation(player, best.Id)
end

local function hatch(player: Player)
	local profile = profileOf(player)
	local incubator = profile and profile.Incubator
	if not incubator then
		return
	end
	profile.Incubator = nil

	local egg = EggData[incubator.EggId] or EggData.ForestEgg
	local family = rollFamily(egg)
	local mutation = nil
	if rng:NextNumber() < egg.MutationChance then
		mutation = CreatureData.RollMutation(rng)
	end

	local record = Registry.CreatureService.CreateRecord(family, mutation)
	table.insert(profile.Creatures, record)
	profile.Stats.Hatches += 1
	if mutation then
		profile.Stats.Mutations += 1
	end
	local key = CreatureData.DiscoveryKey(record)
	local isNew = not profile.Discovered[key]
	profile.Discovered[key] = true

	if not profile.Equipped then
		Registry.CreatureService.Equip(player, record.Id)
	end
	Registry.DataService.Changed(player)
	Net.Get("HatchResult"):FireClient(player, { EggId = incubator.EggId, Creature = record, IsNew = isNew })

	local rarity = CreatureData.GetRarity(record)
	if Rarity.AtLeast(rarity, "Epic") then
		local name = CreatureData.GetDisplayName(record)
		task.delay(3.5, function()
			Net.Announce(("🌟 %s HATCHED A %s!"):format(player.DisplayName:upper(), name:upper()), Rarity.Colors[rarity], Rarity.AtLeast(rarity, "Legendary"))
		end)
	end

	task.delay(1, EggService.TryAutoHatch, player)
end

function EggService.Init()
	Registry.DataService.ProfileLoaded:Connect(function(player: Player, profile)
		-- First join: a free egg that starts hatching immediately (first hatch within ~15s).
		if profile.Stats.Hatches == 0 and #profile.Creatures == 0 and not profile.Incubator then
			if #profile.Eggs == 0 then
				table.insert(profile.Eggs, { Id = newEggId(), EggId = GameConfig.StarterEgg, At = os.time() })
			end
			EggService.StartIncubation(player, profile.Eggs[1].Id)
			Net.Notify(player, "🥚 Your first egg is hatching! Watch the timer at the bottom.", Color3.fromRGB(255, 230, 120))
		else
			EggService.TryAutoHatch(player)
		end
	end)
end

function EggService.Start()
	Net.On("RequestHatch", function(player, eggRecordId)
		if type(eggRecordId) ~= "string" then
			return
		end
		local ok, reason = EggService.StartIncubation(player, eggRecordId)
		if not ok and reason then
			Net.Notify(player, reason, Color3.fromRGB(255, 120, 120))
		end
	end, 0.5)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = serverNow()
			for _, player in Players:GetPlayers() do
				local profile = profileOf(player)
				if profile and profile.Incubator and now >= profile.Incubator.EndsAt then
					local ok, err = pcall(hatch, player)
					if not ok then
						warn("[EggService] hatch failed: " .. tostring(err))
					end
				end
			end
		end
	end)
end

return EggService
]=])
make(n3, "ModuleScript", "EnemyService", [=[
-- Data-driven enemies. Every enemy type shares one AI loop; behavior comes from EnemyData.
-- Enemies are anchored and moved by CFrame (no physics, no pathfinding) to stay cheap on mobile.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local EnemyData = require(Root.Config.EnemyData)
local Models = require(Root.Shared.Models)
local Signal = require(Root.Shared.Signal)

local EnemyService = {}
EnemyService.Killed = Signal.new() -- (enemy, killer)

local enemies = {}
local byModel = {}
local folder: Folder
local campPosition = Vector3.zero
local rng = Random.new()

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

---------------------------------------------------------------------------------------------------
-- Targets (players + creatures)
---------------------------------------------------------------------------------------------------
function EnemyService.GatherTargets()
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and rootPart and humanoid.Health > 0 then
			table.insert(list, { Kind = "Player", Player = player, Root = rootPart, Humanoid = humanoid })
		end
	end
	for _, state in Registry.CreatureService.GetActive() do
		table.insert(list, { Kind = "Creature", Player = state.Player, Root = state.Root, State = state })
	end
	return list
end

function EnemyService.IsTargetValid(target): boolean
	if not target or not target.Root.Parent then
		return false
	end
	if target.Kind == "Player" then
		return target.Humanoid.Health > 0 and target.Player.Parent ~= nil
	end
	return Registry.CreatureService.IsTargetable(target.State)
end

function EnemyService.TargetRadius(target): number
	if target.Kind == "Creature" then
		return target.State.Radius
	end
	return 1.5
end

function EnemyService.ApplyDamage(target, amount: number)
	if target.Kind == "Player" then
		target.Humanoid:TakeDamage(amount)
		Effects.DamageNumber(target.Root.Position + Vector3.new(0, 3, 0), amount, Color3.fromRGB(255, 70, 70))
	else
		Registry.CreatureService.DamageCreature(target.State, amount)
	end
end

local function pickTarget(e, targets)
	local best, bestDist = nil, GameConfig.EnemyAggroRadius
	local pos = e.Root.Position
	for _, target in targets do
		local d = flatDist(pos, target.Root.Position)
		if d < bestDist then
			best, bestDist = target, d
		end
	end
	return best
end

---------------------------------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------------------------------
local function makeHealthBar(e)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(90, 26)
	gui.StudsOffset = Vector3.new(0, e.Top + 1.2, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0

	if e.Variant.Prefix then
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 0, 14)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = e.Variant.Tint or Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.Text = e.Model.Name
		nameLabel.Parent = gui
	end

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.fromScale(0.5, 1)
	back.Size = UDim2.new(1, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(25, 20, 25)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = e.Root
	return fill
end

function EnemyService.Spawn(typeId: string, variantId: string?, position: Vector3, plan)
	local data = EnemyData.Types[typeId]
	if not data then
		return nil
	end
	local vId = variantId or "Normal"
	local variant = EnemyData.Variants[vId] or EnemyData.Variants.Normal
	local p = plan or {}
	local night = p.Night or 1

	local model = Models.BuildEnemy(typeId, vId)
	model.Name = (variant.Prefix or "") .. data.Name
	local root = model.PrimaryPart :: BasePart
	local hip = model:GetAttribute("HipHeight") :: number
	local top = model:GetAttribute("Top") :: number
	root.CFrame = CFrame.new(position.X, GameConfig.GroundY + hip, position.Z)

	local e = {
		TypeId = typeId,
		Data = data,
		Variant = variant,
		VariantId = vId,
		Model = model,
		Root = root,
		Hip = hip,
		Top = top,
		Radius = model:GetAttribute("Radius") :: number,
		MaxHealth = math.floor(data.Health * (p.HealthMult or 1) * variant.HealthMult),
		Health = 0,
		Damage = data.Damage * (p.DamageMult or 1) * variant.DamageMult,
		Speed = data.Speed * variant.SpeedMult,
		Coins = math.floor(data.Coins * variant.RewardMult * (p.RewardMult or 1) * (1 + 0.1 * (night - 1))),
		XP = math.floor(data.XP * variant.RewardMult * (1 + 0.05 * (night - 1))),
		NextAttack = os.clock() + 1 + rng:NextNumber(),
		NextRetarget = 0,
		Target = nil,
		Alive = true,
		Busy = false,
		DamageTakenMult = 1,
	}
	e.Health = e.MaxHealth
	if not data.IsBoss then
		e.Bar = makeHealthBar(e)
	end

	model.Parent = folder
	table.insert(enemies, e)
	byModel[model] = e
	Effects.Burst(root.Position, Color3.fromRGB(90, 0, 130), 3, 0.4)
	return e
end

---------------------------------------------------------------------------------------------------
-- Damage / death
---------------------------------------------------------------------------------------------------
local function removeFromList(e)
	byModel[e.Model] = nil
	local i = table.find(enemies, e)
	if i then
		table.remove(enemies, i)
	end
end

local function kill(e, killer: Player?)
	if not e.Alive then
		return
	end
	e.Alive = false
	removeFromList(e)
	Effects.Burst(e.Root.Position, e.Data.EyeColor, e.Radius * 2, 0.4)
	Effects.FadeOut(e.Model, 0.4)

	if killer and killer.Parent then
		Registry.EconomyService.AddCoins(killer, e.Coins)
		Registry.CreatureService.AddXP(killer, e.XP)
		local profile = Registry.DataService.GetProfile(killer)
		if profile then
			profile.Stats.Kills += 1
		end
		if e.Coins > 0 then
			Effects.FloatText(e.Root.Position + Vector3.new(0, e.Top + 2, 0), "+" .. e.Coins .. " coins", Color3.fromRGB(255, 215, 70))
		end
	end
	if e.OnDeath then
		task.spawn(e.OnDeath, e, killer)
	end
	EnemyService.Killed:Fire(e, killer)
end

function EnemyService.Damage(e, amount: number, source: Player?)
	if not e or not e.Alive or amount <= 0 then
		return
	end
	local dealt = amount * e.DamageTakenMult
	e.Health -= dealt
	if source then
		e.LastHitBy = source
	end
	local color = if e.DamageTakenMult > 1 then Color3.fromRGB(255, 230, 60) else Color3.new(1, 1, 1)
	Effects.DamageNumber(e.Root.Position + Vector3.new(0, e.Top + 1, 0), dealt, color)
	if e.Bar then
		e.Bar.Size = UDim2.fromScale(math.clamp(e.Health / e.MaxHealth, 0, 1), 1)
	end
	if e.OnDamaged then
		e.OnDamaged(e)
	end
	if e.Health <= 0 then
		kill(e, source or e.LastHitBy)
	end
end

function EnemyService.Remove(e)
	if not e.Alive then
		return
	end
	e.Alive = false
	removeFromList(e)
	Effects.Burst(e.Root.Position, Color3.fromRGB(40, 0, 60), e.Radius * 1.5, 0.5)
	Effects.FadeOut(e.Model, 0.6)
end

function EnemyService.ClearAll()
	for _, e in table.clone(enemies) do
		EnemyService.Remove(e)
	end
end

---------------------------------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------------------------------
function EnemyService.GetAll()
	return table.clone(enemies)
end

function EnemyService.CountAlive(): number
	return #enemies
end

function EnemyService.IsAlive(e): boolean
	return e ~= nil and e.Alive == true
end

function EnemyService.FindByModel(model: Instance?)
	local current = model
	while current and current ~= folder do
		if byModel[current] then
			return byModel[current]
		end
		current = current.Parent
	end
	return nil
end

function EnemyService.GetInRadius(position: Vector3, radius: number)
	local list = {}
	for _, e in enemies do
		if flatDist(position, e.Root.Position) <= radius + e.Radius then
			table.insert(list, e)
		end
	end
	return list
end

function EnemyService.GetCampPosition(): Vector3
	return campPosition
end

---------------------------------------------------------------------------------------------------
-- AI
---------------------------------------------------------------------------------------------------
local function attack(e, target, now: number)
	local data = e.Data
	e.NextAttack = now + data.AttackCooldown * (0.9 + rng:NextNumber() * 0.2)

	if data.Behavior == "Ranged" then
		e.Busy = true
		local eye = e.Model:FindFirstChild("Eye") :: BasePart?
		local eyeColor = eye and eye.Color
		if eye then
			eye.Color = Color3.new(1, 1, 1)
		end
		task.delay(data.Windup, function()
			e.Busy = false
			if eye and eyeColor then
				eye.Color = eyeColor
			end
			if not e.Alive or not EnemyService.IsTargetValid(target) then
				return
			end
			local from = if eye then eye.Position else e.Root.Position + Vector3.new(0, 2, 0)
			local aim = target.Root.Position
			local travel = Effects.Projectile(from, aim, data.EyeColor, data.ProjectileSpeed, 1.2)
			task.delay(travel, function()
				if EnemyService.IsTargetValid(target) and flatDist(target.Root.Position, aim) < 5 then
					EnemyService.ApplyDamage(target, e.Damage)
				end
			end)
		end)
	elseif data.Windup > 0 then
		e.Busy = true
		local radius = data.SmashRadius or 6
		local center = e.Root.Position + e.Root.CFrame.LookVector * (e.Radius + radius * 0.4)
		Effects.Telegraph(center, "Disc", Vector2.new(radius, 0), data.Windup)
		task.delay(data.Windup, function()
			e.Busy = false
			if not e.Alive then
				return
			end
			Effects.Burst(Vector3.new(center.X, 1, center.Z), Color3.fromRGB(160, 110, 80), radius, 0.35)
			for _, t in EnemyService.GatherTargets() do
				if flatDist(t.Root.Position, center) <= radius + EnemyService.TargetRadius(t) then
					EnemyService.ApplyDamage(t, e.Damage)
				end
			end
		end)
	else
		EnemyService.ApplyDamage(target, e.Damage)
	end
end

local function stepEnemy(e, dt: number, now: number, targets)
	if now >= e.NextRetarget then
		e.NextRetarget = now + GameConfig.EnemyRetargetInterval
		e.Target = pickTarget(e, targets)
	end
	local target = e.Target
	if target and not EnemyService.IsTargetValid(target) then
		target = nil
		e.Target = nil
	end

	local data = e.Data
	local pos = e.Root.Position
	local goal = if target then target.Root.Position else campPosition
	local toGoal = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = toGoal.Magnitude
	local dir = if dist > 0.01 then toGoal / dist else e.Root.CFrame.LookVector
	local targetRadius = if target then EnemyService.TargetRadius(target) else 0

	local move = Vector3.zero
	if not e.Busy then
		if data.Behavior == "Ranged" and target then
			if dist > data.PreferredRange then
				move = dir
			elseif dist < data.PreferredRange * 0.5 then
				move = -dir * 0.6
			end
		else
			local stopAt = if target then data.AttackRange * 0.8 + targetRadius + e.Radius * 0.5 else 8
			if dist > stopAt then
				move = dir
			end
		end
	end

	local newPos = pos + move * e.Speed * dt
	local look = Vector3.new(dir.X, 0, dir.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	e.Root.CFrame = CFrame.lookAt(newPos, newPos + look)

	if target and not e.Busy and now >= e.NextAttack and dist <= data.AttackRange + targetRadius + e.Radius * 0.5 then
		attack(e, target, now)
	end
end

function EnemyService.Init()
	folder = workspace:FindFirstChild("Enemies") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Enemies"
		folder.Parent = workspace
	end
	local map = workspace:FindFirstChild("Map")
	local camp = map and map:FindFirstChild("CampCenter", true)
	if camp and camp:IsA("BasePart") then
		campPosition = camp.Position
	end
end

function EnemyService.Start()
	RunService.Heartbeat:Connect(function(dt)
		if #enemies == 0 then
			return
		end
		local now = os.clock()
		local targets = EnemyService.GatherTargets()
		for _, e in table.clone(enemies) do
			if e.Alive then
				local ok, err = pcall(e.CustomTick or stepEnemy, e, dt, now, targets)
				if not ok then
					warn("[EnemyService] AI error, removing enemy: " .. tostring(err))
					EnemyService.Remove(e)
				end
			end
		end
	end)
end

return EnemyService
]=])
make(n3, "ModuleScript", "ShopService", [=[
-- Coin shop + Robux (gamepasses and developer products). Prices and rewards come only from
-- server-side config; the client sends an item id, never a price or amount.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local ShopData = require(Root.Config.ShopData)
local EggData = require(Root.Config.EggData)
local CreatureData = require(Root.Config.CreatureData)
local Net = require(Root.Shared.Net)

local ShopService = {}

local GOOD = Color3.fromRGB(120, 255, 140)

-- Developer product handlers, keyed by GameConfig.Products key.
local PRODUCT_HANDLERS = {
	EggPack = function(player: Player)
		for _ = 1, 3 do
			Registry.EggService.GiveEgg(player, "EmberEgg", "Egg Pack", true)
		end
		Registry.EconomyService.AddCoins(player, 200)
	end,
	GalaxyAura = function(player: Player, profile)
		profile.Auras.Galaxy = true
		Registry.DataService.Changed(player)
		Net.Notify(player, "🌌 Galaxy Aura unlocked! Equip it from the Creatures menu.", GOOD)
	end,
}

local productIdToKey = {}
for key, id in GameConfig.Products do
	if id ~= 0 then
		productIdToKey[id] = key
	end
end

local function applyVIPTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VIPTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.fromOffset(80, 24)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "⭐ VIP"
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = head
end

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		applyVIPTag(player)
	elseif key == "AutoHatch" then
		Registry.EggService.TryAutoHatch(player)
	end
end

local function checkPasses(player: Player)
	for key, id in GameConfig.Gamepasses do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
end

local function buyItem(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return
	end
	local item = ShopData.ById[itemId]
	local profile = Registry.DataService.GetProfile(player)
	if not item or not profile then
		return
	end

	if item.Kind == "Egg" then
		if not EggData[item.EggId] then
			return
		end
		if #profile.Eggs >= GameConfig.MaxEggs then
			Net.Notify(player, "Your egg bag is full - hatch some eggs first!", Color3.fromRGB(255, 120, 120))
			return
		end
		if Registry.EconomyService.SpendCoins(player, item.Price) then
			Registry.EggService.GiveEgg(player, item.EggId, "purchased")
		end
	elseif item.Kind == "Berries" then
		if Registry.EconomyService.SpendCoins(player, item.Price) then
			Registry.EconomyService.AddBerries(player, item.Amount)
			Net.Notify(player, ("🍓 +%d berries"):format(item.Amount), GOOD)
		end
	elseif item.Kind == "Aura" then
		if not CreatureData.Auras[item.AuraId] then
			return
		end
		if profile.Auras[item.AuraId] then
			Net.Notify(player, "You already own that aura.", Color3.fromRGB(200, 200, 200))
			return
		end
		if Registry.EconomyService.SpendCoins(player, item.Price) then
			profile.Auras[item.AuraId] = true
			Registry.DataService.Changed(player)
			Net.Notify(player, ("✨ %s unlocked! Equip it from the Creatures menu."):format(CreatureData.Auras[item.AuraId].Name), GOOD)
		end
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Registry.DataService.WaitForProfile(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(profile.Receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productIdToKey[info.ProductId]
	local handler = key and PRODUCT_HANDLERS[key]
	if not handler then
		warn("[ShopService] No handler for product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(handler, player, profile)
	if not ok then
		warn("[ShopService] Product grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Receipts, info.PurchaseId)
	while #profile.Receipts > 50 do
		table.remove(profile.Receipts, 1)
	end
	Registry.DataService.Changed(player)
	Registry.DataService.Save(player, false)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Init()
	Registry.DataService.ProfileLoaded:Connect(function(player: Player)
		checkPasses(player)
	end)
end

function ShopService.Start()
	Net.On("BuyItem", buyItem, 0.4)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, id in GameConfig.Gamepasses do
			if id == passId then
				grantPass(player, key)
				Net.Notify(player, "⭐ Thanks for your support! Pass activated.", Color3.fromRGB(255, 210, 60))
			end
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if player:GetAttribute("Pass_VIP") then
				task.wait(0.5)
				applyVIPTag(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return ShopService
]=])
make(n3, "ModuleScript", "WorldService", [=[
-- Day-phase activities: berry bushes, coin crystals, eggs hidden around the map, the shop keeper.
-- Map layout lives in Workspace.Map (built by the installer); this service only adds behavior.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local EggData = require(Root.Config.EggData)
local Rarity = require(Root.Config.Rarity)
local Models = require(Root.Shared.Models)
local Net = require(Root.Shared.Net)

local WorldService = {}

-- Chance per day that a special spot holds an egg, and which egg.
local SPOT_TABLE = {
	Cave = { { Egg = "EmberEgg", Chance = 0.35 } },
	Ruins = { { Egg = "EmberEgg", Chance = 0.25 } },
	Cabin = { { Egg = "ForestEgg", Chance = 0.6 } },
	Hidden = { { Egg = "VoidEgg", Chance = 0.06 }, { Egg = "EmberEgg", Chance = 0.5 } },
}

local AREA_NAMES = {
	Cave = "the Glowcap Cave",
	Ruins = "the Old Ruins",
	Cabin = "the Abandoned Cabin",
	Hidden = "the Hidden Grove",
	Forest = "the forest",
}

local rng = Random.new()
local map: Instance
local worldEggs: Folder

local function prompt(parent: Instance, actionText: string, objectText: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = hold
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function setVisible(model: Instance, name: string, visible: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			d.Transparency = if visible then 0 else 1
		end
	end
end

local function primaryPartOf(model: Instance): BasePart?
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function setupBush(bush: Instance)
	local anchor = primaryPartOf(bush)
	if not anchor then
		return
	end
	local p = prompt(anchor, "Pick Berries", "Berry Bush", 0.3)
	p.Triggered:Connect(function(player)
		if not Registry.DataService.GetProfile(player) then
			return
		end
		local amount = rng:NextInteger(1, 2)
		Registry.EconomyService.AddBerries(player, amount)
		Effects.FloatText(anchor.Position + Vector3.new(0, 3, 0), ("+%d 🍓"):format(amount), Color3.fromRGB(255, 110, 150))
		p.Enabled = false
		setVisible(bush, "Berry", false)
		task.delay(GameConfig.BerryRegrowTime, function()
			p.Enabled = true
			setVisible(bush, "Berry", true)
		end)
	end)
end

local function setupCrystal(crystal: Instance)
	local anchor = primaryPartOf(crystal)
	if not anchor then
		return
	end
	local p = prompt(anchor, "Mine", "Coin Crystal", 0.8)
	p.Triggered:Connect(function(player)
		if not Registry.DataService.GetProfile(player) then
			return
		end
		local range = GameConfig.CrystalCoins
		local coins = rng:NextInteger(range[1], range[2])
		Registry.EconomyService.AddCoins(player, coins)
		Effects.Burst(anchor.Position, Color3.fromRGB(255, 215, 70), 3, 0.3)
		Effects.FloatText(anchor.Position + Vector3.new(0, 3, 0), ("+%d coins"):format(coins), Color3.fromRGB(255, 215, 70))
		p.Enabled = false
		for _, d in crystal:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 0.85
			end
		end
		task.delay(GameConfig.CrystalRegrowTime, function()
			p.Enabled = true
			for _, d in crystal:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 0
				end
			end
		end)
	end)
end

local function spawnWorldEgg(spot: BasePart, eggId: string, area: string)
	local model = Models.BuildEgg(eggId)
	local root = model.PrimaryPart :: BasePart
	local base = CFrame.new(spot.Position.X, spot.Position.Y + 1.6, spot.Position.Z)
	root.CFrame = base
	model.Parent = worldEggs
	TweenService:Create(root, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = base * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(90), 0),
	}):Play()

	local egg = EggData[eggId]
	if Rarity.AtLeast(egg.Rarity, "Rare") then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = egg.Color
		sparkles.Parent = root
	end

	local p = prompt(root, "Take Egg", egg.Name, 0.6)
	local taken = false
	p.Triggered:Connect(function(player)
		if taken or not Registry.DataService.GetProfile(player) then
			return
		end
		taken = true
		model:Destroy()
		Effects.Burst(base.Position, egg.Color, 4, 0.4)
		Registry.EggService.GiveEgg(player, eggId, "found in " .. (AREA_NAMES[area] or "the forest"))
		if Rarity.AtLeast(egg.Rarity, "Rare") then
			Net.Announce(("🥚 %s found a %s in %s!"):format(player.DisplayName, egg.Name, AREA_NAMES[area] or "the forest"), Rarity.Colors[egg.Rarity], false)
		end
	end)
end

function WorldService.OnDayStart(_night: number)
	worldEggs:ClearAllChildren()
	local spots = map and map:FindFirstChild("EggSpots")
	if not spots then
		return
	end
	local forestSpots = {}
	for _, spot in spots:GetChildren() do
		if spot:IsA("BasePart") then
			local area = spot:GetAttribute("Area") or "Forest"
			if area == "Forest" then
				table.insert(forestSpots, spot)
			else
				for _, entry in SPOT_TABLE[area] or {} do
					if rng:NextNumber() < entry.Chance then
						spawnWorldEgg(spot, entry.Egg, area)
						break
					end
				end
			end
		end
	end
	local count = math.min(1 + #Players:GetPlayers(), #forestSpots)
	for _ = 1, count do
		local spot = table.remove(forestSpots, rng:NextInteger(1, #forestSpots))
		spawnWorldEgg(spot, "ForestEgg", "Forest")
	end
end

function WorldService.Init()
	map = workspace:FindFirstChild("Map") :: Instance
	worldEggs = Instance.new("Folder")
	worldEggs.Name = "WorldEggs"
	worldEggs.Parent = workspace
	if not map then
		warn("[WorldService] Workspace.Map not found - run installer Part 1 (map).")
	end
end

function WorldService.Start()
	if not map then
		return
	end
	local resources = map:FindFirstChild("Resources")
	if resources then
		for _, child in resources:GetChildren() do
			if child.Name == "BerryBush" then
				setupBush(child)
			elseif child.Name == "CoinCrystal" then
				setupCrystal(child)
			end
		end
	end

	local keeper = map:FindFirstChild("ShopKeeper", true)
	local anchor = keeper and primaryPartOf(keeper)
	if anchor then
		local p = prompt(anchor, "Open Shop", "Old Keeper", 0)
		p.Triggered:Connect(function(player)
			Net.Get("OpenPanel"):FireClient(player, "Shop")
		end)
	end
end

return WorldService
]=])
end
game:GetService("Players").CharacterAutoLoads = false
print("✅ HATCH OR DIE Part 3/4 done. Now run Part 4.")
end
do
-- HATCH OR DIE - installer PART 4 of 4: CLIENT CODE (StarterPlayerScripts)
-- Generated by tools/build_installer.py from src/. Do not edit by hand.
-- Paste everything into the Roblox Studio command bar and press Enter.
local function make(parent, className, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	if source then
		inst.Source = source
	end
	inst.Parent = parent
	return inst
end

local n1 = make(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "LocalScript", "HatchOrDieClient", [=[
-- HATCH OR DIE client entry. The client only renders and sends intents; the server decides outcomes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Root = ReplicatedStorage:WaitForChild("HatchOrDie")

local Net = require(Root.Shared.Net)
local Signal = require(Root.Shared.Signal)
local Models = require(Root.Shared.Models)
local GameConfig = require(Root.Config.GameConfig)
local CreatureData = require(Root.Config.CreatureData)
local EggData = require(Root.Config.EggData)
local ShopData = require(Root.Config.ShopData)
local Rarity = require(Root.Config.Rarity)

local UIKit = require(script.UIKit)
local Layout = require(script.Layout)
local Hud = require(script.Hud)
local Panels = require(script.Panels)
local Cinematics = require(script.Cinematics)

local gui = Layout.Obtain(player)

local ctx = {
	Root = Root,
	Net = Net,
	Gui = gui,
	Models = Models,
	GameConfig = GameConfig,
	CreatureData = CreatureData,
	EggData = EggData,
	ShopData = ShopData,
	Rarity = Rarity,
	Layout = Layout,
	Profile = nil,
	SavingEnabled = true,
	ProfileChanged = Signal.new(),
	Hud = Hud,
	Panels = Panels,
	Cinematics = Cinematics,
}

function ctx.SlotLimit(): number
	local bonus = if player:GetAttribute("Pass_ExtraSlots") then GameConfig.ExtraSlotsBonus else 0
	return GameConfig.BaseCreatureSlots + bonus
end

Hud.Init(ctx)
Panels.Init(ctx)
Cinematics.Init(ctx)

---------------------------------------------------------------------------------------------------
-- Server -> client
---------------------------------------------------------------------------------------------------
local warnedNoSave = false
Net.Get("SyncData").OnClientEvent:Connect(function(profile, savingEnabled)
	ctx.Profile = profile
	ctx.SavingEnabled = savingEnabled
	ctx.ProfileChanged:Fire(profile)
	if not savingEnabled and not warnedNoSave then
		warnedNoSave = true
		Hud.Toast("⚠️ Saving is OFF (Studio test or DataStores unavailable).", Color3.fromRGB(255, 170, 60))
	end
end)

Net.Get("Notify").OnClientEvent:Connect(function(text, color)
	Hud.Toast(text, color)
end)

Net.Get("Announce").OnClientEvent:Connect(function(text, color, big)
	Hud.Announce(text, color, big)
	if big then
		Cinematics.Shake(0.6, 0.4)
	end
end)

Net.Get("HatchResult").OnClientEvent:Connect(function(result)
	if Panels.IsOpen() then
		Panels.Close()
	end
	Cinematics.Hatch(result)
end)

Net.Get("Evolved").OnClientEvent:Connect(function(result)
	if Panels.IsOpen() then
		Panels.Close()
	end
	Cinematics.Evolve(result)
end)

Net.Get("BossBar").OnClientEvent:Connect(function(data)
	Hud.SetBoss(data)
end)

Net.Get("OpenPanel").OnClientEvent:Connect(function(name)
	Panels.Open(name)
end)

Net.Get("NightResult").OnClientEvent:Connect(function(result)
	Hud.ShowNightResult(result)
end)

Net.Get("Effect").OnClientEvent:Connect(function(kind, value)
	if kind == "Shake" then
		Cinematics.Shake(value or 1, 0.5)
	end
end)

---------------------------------------------------------------------------------------------------
-- Death overlay
---------------------------------------------------------------------------------------------------
local function onCharacter(character: Model)
	Hud.SetDead(false)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		if Root:GetAttribute("Phase") == "Night" then
			Hud.SetDead(true)
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------------------------------------------
-- Input: Q ability, F feed, 1/2/3 commands, click/tap an enemy to target it
---------------------------------------------------------------------------------------------------
local targetHighlight = UIKit.new("Highlight", {
	FillTransparency = 1,
	OutlineColor = Color3.fromRGB(255, 220, 60),
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Parent = workspace,
})
local highlightToken = 0

local function tryTarget(screenPosition: Vector2)
	local camera = workspace.CurrentCamera
	local enemies = workspace:FindFirstChild("Enemies")
	if not camera or not enemies then
		return
	end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { enemies }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= enemies do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return
	end
	Net.Get("SetTarget"):FireServer(model)
	targetHighlight.Adornee = model
	highlightToken += 1
	local token = highlightToken
	task.delay(2.5, function()
		if highlightToken == token then
			targetHighlight.Adornee = nil
		end
	end)
end

local KEY_ACTIONS = {
	[Enum.KeyCode.Q] = function()
		Net.Get("UseAbility"):FireServer()
	end,
	[Enum.KeyCode.F] = function()
		Net.Get("FeedCreature"):FireServer()
	end,
	[Enum.KeyCode.One] = function()
		Net.Get("SetCommand"):FireServer("Follow")
	end,
	[Enum.KeyCode.Two] = function()
		Net.Get("SetCommand"):FireServer("Attack")
	end,
	[Enum.KeyCode.Three] = function()
		Net.Get("SetCommand"):FireServer("Defend")
	end,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local action = KEY_ACTIONS[input.KeyCode]
		if action then
			action()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		tryTarget(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

---------------------------------------------------------------------------------------------------
-- Optional music (set ids in GameConfig.Music)
---------------------------------------------------------------------------------------------------
local music = UIKit.new("Sound", { Looped = true, Volume = 0.35, Parent = SoundService })
local function updateMusic()
	local phase = Root:GetAttribute("Phase")
	local id = if phase == "Night" then GameConfig.Music.Night else GameConfig.Music.Day
	if id == "" then
		music:Stop()
		return
	end
	if music.SoundId ~= id then
		music.SoundId = id
		music:Play()
	end
end
Root:GetAttributeChangedSignal("Phase"):Connect(updateMusic)
updateMusic()

---------------------------------------------------------------------------------------------------
-- VIP chat tag
---------------------------------------------------------------------------------------------------
local TextChatService = game:GetService("TextChatService")
TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker and speaker:GetAttribute("Pass_VIP") then
			props.PrefixText = "<font color='#FFD23C'>[VIP]</font> " .. message.PrefixText
		end
	end
	return props
end

Net.Get("ClientReady"):FireServer()
]=])
make(n1, "ModuleScript", "Cinematics", [=[
-- Hatch and evolution reveals, plus camera shake. Reveals are queued so they never overlap.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local UIKit = require(script.Parent.UIKit)

local Cinematics = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local ctx
local gui: ScreenGui
local queue = {}
local running = false

local function playSound(id: string?, volume: number?)
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Cinematics.Shake(intensity: number, duration: number?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local d = duration or 0.45
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= d or not humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local falloff = 1 - t / d
		local k = intensity * falloff
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k)
	end)
end

local function overlay()
	local root = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Active = true,
		Parent = gui,
	})
	UIKit.tween(root, 0.3, { BackgroundTransparency = 0.3 })

	local rays = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(700, 700),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	})
	UIKit.corner(rays, 350)
	local gradient = UIKit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
		Parent = rays,
	})

	local vp = UIKit.viewport({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(340, 340),
		Parent = root,
	}, nil, false)

	local title = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 175),
		Size = UDim2.new(0.8, 0, 0, 56),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0,
		Parent = root,
	})
	local sub = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 232),
		Size = UDim2.new(0.7, 0, 0, 30),
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.SubText,
		Parent = root,
	})
	local tag = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.42, -170),
		Size = UDim2.new(0.6, 0, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.Gold,
		Parent = root,
	})
	local flash = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = root,
	})
	return {
		Root = root,
		Rays = rays,
		Gradient = gradient,
		Viewport = vp,
		Title = title,
		Sub = sub,
		Tag = tag,
		Flash = flash,
	}
end

local function spinRays(o, color: Color3)
	o.Rays.BackgroundColor3 = color
	o.Rays.BackgroundTransparency = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not o.Root.Parent then
			connection:Disconnect()
			return
		end
		o.Gradient.Rotation = (o.Gradient.Rotation + dt * 60) % 360
	end)
end

local function waitForDismiss(o, seconds: number)
	local done = false
	local button = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(220, 48),
		BackgroundColor3 = Color3.fromRGB(70, 170, 90),
		Text = "AWESOME!",
		Parent = o.Root,
	}, function()
		done = true
	end)
	local deadline = os.clock() + seconds
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	button:Destroy()
	UIKit.tween(o.Root, 0.25, { BackgroundTransparency = 1 })
	for _, d in o.Root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.Visible = false
		end
	end
	task.wait(0.25)
	o.Root:Destroy()
end

local function describe(record)
	local CD = ctx.CreatureData
	local rarity = CD.GetRarity(record)
	local color = ctx.Rarity.Colors[rarity]
	local mutationText = ""
	if record.Mutation then
		mutationText = ("🧬 %s MUTATION!"):format(record.Mutation:upper())
	end
	return rarity, color, mutationText
end

local function playHatch(result)
	local o = overlay()
	local egg = ctx.EggData[result.EggId]
	local record = result.Creature
	local rarity, color, mutationText = describe(record)
	local rare = ctx.Rarity.AtLeast(rarity, "Epic")

	local eggModel = ctx.Models.BuildEgg(result.EggId)
	UIKit.setViewportModel(o.Viewport, eggModel)
	o.Title.Text = "HATCHING..."
	o.Title.TextColor3 = C.Text
	o.Sub.Text = if egg then egg.Name else ""

	local shakes = if rare then 5 else 3
	for i = 1, shakes do
		local amount = 6 + i * 5
		for j = 1, 6 do
			local angle = math.rad(if j % 2 == 0 then amount else -amount)
			eggModel:PivotTo(CFrame.Angles(0, 0, angle))
			task.wait(0.04)
		end
		eggModel:PivotTo(CFrame.new())
		o.Flash.BackgroundTransparency = 0.8
		UIKit.tween(o.Flash, 0.2, { BackgroundTransparency = 1 })
		if i == shakes - 1 and rare then
			spinRays(o, color)
			o.Tag.Text = "✨ SOMETHING RARE... ✨"
		end
		task.wait(0.28)
	end

	playSound(ctx.GameConfig.Sounds.Hatch, 0.8)
	o.Flash.BackgroundTransparency = 0
	UIKit.tween(o.Flash, 0.7, { BackgroundTransparency = 1 })
	if not rare then
		spinRays(o, color)
	end
	local creatureModel = ctx.Models.BuildCreature(record)
	UIKit.setViewportModel(o.Viewport, creatureModel)
	local spin = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not creatureModel.Parent then
			connection:Disconnect()
			return
		end
		spin += dt
		creatureModel:PivotTo(CFrame.Angles(0, spin, 0))
	end)

	o.Title.Text = ctx.CreatureData.GetDisplayName(record)
	o.Title.TextColor3 = color
	o.Title.Size = UDim2.new(0.8, 0, 0, 90)
	UIKit.tween(o.Title, 0.4, { Size = UDim2.new(0.8, 0, 0, 56) }, Enum.EasingStyle.Back)
	o.Sub.Text = rarity:upper() .. (if mutationText ~= "" then "  •  " .. mutationText else "")
	o.Sub.TextColor3 = color
	o.Tag.Text = if result.IsNew then "🆕 NEW DISCOVERY!" else ""
	if rare then
		Cinematics.Shake(1.2, 0.6)
	end
	waitForDismiss(o, 7)
end

local function playEvolve(result)
	local o = overlay()
	local record = result.Creature
	local rarity, color, mutationText = describe(record)

	local before = table.clone(record)
	before.Stage = math.max(1, record.Stage - 1)
	if result.Mutated then
		before.Mutation = nil
	end
	local model = ctx.Models.BuildCreature(before)
	UIKit.setViewportModel(o.Viewport, model)
	o.Title.Text = result.FromName .. " is evolving..."
	o.Title.TextColor3 = C.Text
	spinRays(o, C.Gold)

	for i = 1, 4 do
		o.Flash.BackgroundTransparency = 0.3
		UIKit.tween(o.Flash, 0.35 - i * 0.05, { BackgroundTransparency = 1 })
		task.wait(0.5 - i * 0.08)
	end
	playSound(ctx.GameConfig.Sounds.Hatch, 0.9)
	o.Flash.BackgroundTransparency = 0
	UIKit.tween(o.Flash, 0.8, { BackgroundTransparency = 1 })
	UIKit.setViewportModel(o.Viewport, ctx.Models.BuildCreature(record))
	o.Rays.BackgroundColor3 = color
	Cinematics.Shake(1, 0.5)

	o.Tag.Text = if result.Mutated then "🧬 IT MUTATED!" else "✨ EVOLVED! ✨"
	o.Title.Text = ctx.CreatureData.GetDisplayName(record)
	o.Title.TextColor3 = color
	o.Sub.Text = rarity:upper() .. " • " .. ctx.CreatureData.Stages[record.Stage].Name:upper() .. (if mutationText ~= "" then "  •  " .. mutationText else "")
	o.Sub.TextColor3 = color
	waitForDismiss(o, 6)
end

local function pump()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		local ok, err = pcall(item.Fn, item.Data)
		if not ok then
			warn("[Cinematics] " .. tostring(err))
		end
	end
	running = false
end

function Cinematics.Hatch(result)
	table.insert(queue, { Fn = playHatch, Data = result })
	task.spawn(pump)
end

function Cinematics.Evolve(result)
	table.insert(queue, { Fn = playEvolve, Data = result })
	task.spawn(pump)
end

function Cinematics.Init(context)
	ctx = context
	gui = UIKit.new("ScreenGui", {
		Name = "HatchOrDieCinematics",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

return Cinematics
]=])
make(n1, "ModuleScript", "Hud", [=[
-- Always-on HUD: phase banner + timer, objective, currencies, creature card, commands,
-- ability/feed buttons, menu bar, incubator timer, toasts, announcements, boss bar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)

local Hud = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local ctx
local refs = {}
local lastPhaseKey = ""
local bossState = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------------------------------
-- Bind: find every element by name (built-in Layout or the designer's StarterGui.HatchOrDieUI)
---------------------------------------------------------------------------------------------------
local baseSizes = {}
local modeColors = {}
local toastTemplate: GuiObject? = nil

local function bind(gui: ScreenGui)
	local find = ctx.Layout.Finder(gui)
	for _, name in {
		"PhaseBanner", "PhaseTitle", "PhaseSub", "Objective", "BossBar", "BossName", "BossFill",
		"Coins", "Berries", "Best", "CreatureCard", "CreatureName", "CreatureStage", "CreatureHPFill",
		"CreatureHPText", "CreatureXPFill", "CreatureXPText", "EvolveButton", "FeedButton", "AbilityButton",
		"AbilityCooldown", "EggBadge", "Incubator", "IncubatorText", "IncubatorFill", "Toasts",
		"Announcement", "BigTitle", "BigSub", "NightResult", "ResultTitle", "ResultBody", "DeathOverlay",
	} do
		refs[name] = find(name)
	end
	refs.BannerGradient = refs.PhaseBanner:FindFirstChildOfClass("UIGradient")
	refs.ModeButtons = {}
	for _, mode in { "Follow", "Attack", "Defend" } do
		local button = find("Mode" .. mode)
		refs.ModeButtons[mode] = button
		modeColors[button] = button.BackgroundColor3
	end
	refs.MenuButtons = {}
	for _, name in { "Eggs", "Creatures", "Shop" } do
		refs.MenuButtons[name] = find("Menu" .. name)
	end
	local template = gui:FindFirstChild("ToastTemplate", true)
	if template and template:IsA("GuiObject") then
		toastTemplate = template
		template.Visible = false
	end
	for _, name in { "Announcement", "BigTitle", "NightResult" } do
		baseSizes[name] = refs[name].Size
	end

	-- Behavior
	local function onClick(button, fn)
		UIKit.decorate(button)
		button.Activated:Connect(fn)
	end
	onClick(refs.EvolveButton, function()
		local profile = ctx.Profile
		if profile and profile.Equipped then
			ctx.Net.Get("EvolveCreature"):FireServer(profile.Equipped)
		end
	end)
	for mode, button in refs.ModeButtons do
		onClick(button, function()
			ctx.Net.Get("SetCommand"):FireServer(mode)
		end)
	end
	onClick(refs.FeedButton, function()
		ctx.Net.Get("FeedCreature"):FireServer()
	end)
	onClick(refs.AbilityButton, function()
		ctx.Net.Get("UseAbility"):FireServer()
	end)
	for name, button in refs.MenuButtons do
		onClick(button, function()
			ctx.Panels.Toggle(name)
		end)
	end

	-- Start states (exported layouts are saved fully visible so they're easy to edit)
	refs.BossBar.Visible = false
	refs.CreatureCard.Visible = false
	refs.EvolveButton.Visible = false
	refs.EggBadge.Visible = false
	refs.Incubator.Visible = false
	refs.NightResult.Visible = false
	refs.DeathOverlay.Visible = false
	for _, name in { "Announcement", "BigTitle", "BigSub" } do
		refs[name].TextTransparency = 1
		refs[name].TextStrokeTransparency = 1
	end
end

---------------------------------------------------------------------------------------------------
-- Public messaging
---------------------------------------------------------------------------------------------------
function Hud.Toast(text: string, color: Color3?)
	local toast, label
	if toastTemplate then
		toast = toastTemplate:Clone()
		toast.Visible = true
		label = toast:FindFirstChild("Label", true) or toast
		toast.Parent = refs.Toasts
	else
		toast = UIKit.panel({ Size = UDim2.fromOffset(320, 38), BackgroundColor3 = C.Bg, Parent = refs.Toasts })
		label = UIKit.text({ Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), TextXAlignment = Enum.TextXAlignment.Left, Parent = toast })
		UIKit.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = label })
	end
	if label:IsA("TextLabel") or label:IsA("TextButton") then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
	local frames = {}
	for _, child in refs.Toasts:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(frames, child)
		end
	end
	if #frames > 5 then
		frames[1]:Destroy()
	end
	task.delay(4.5, function()
		if toast.Parent then
			for _, d in toast:GetDescendants() do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					UIKit.tween(d, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
				end
			end
			UIKit.tween(toast, 0.4, { BackgroundTransparency = 1 })
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

local announceToken = 0
function Hud.Announce(text: string, color: Color3?, big: boolean?)
	announceToken += 1
	local token = announceToken
	local label = refs.Announcement
	label.Text = text
	label.TextColor3 = color or C.Gold
	label.Size = if big then UIKit.scaleUDim2(baseSizes.Announcement, 1.35) else baseSizes.Announcement
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.1
	if big then
		label.Rotation = -3
		UIKit.tween(label, 0.4, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	end
	task.delay(if big then 5 else 4, function()
		if announceToken == token then
			UIKit.tween(label, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local titleToken = 0
function Hud.BigTitle(title: string, sub: string, color: Color3)
	titleToken += 1
	local token = titleToken
	refs.BigTitle.Text = title
	refs.BigTitle.TextColor3 = color
	refs.BigSub.Text = sub
	refs.BigTitle.TextTransparency = 1
	refs.BigSub.TextTransparency = 1
	refs.BigTitle.Size = UIKit.scaleUDim2(baseSizes.BigTitle, 1.5)
	UIKit.tween(refs.BigTitle, 0.5, { TextTransparency = 0, TextStrokeTransparency = 0, Size = baseSizes.BigTitle }, Enum.EasingStyle.Back)
	UIKit.tween(refs.BigSub, 0.8, { TextTransparency = 0, TextStrokeTransparency = 0.2 })
	task.delay(3, function()
		if titleToken == token then
			UIKit.tween(refs.BigTitle, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 })
			UIKit.tween(refs.BigSub, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

function Hud.ShowNightResult(result)
	local lines = {}
	if result.Wipe then
		refs.ResultTitle.Text = ("☠️ NIGHT %d CLAIMED EVERYONE"):format(result.Night)
		refs.ResultTitle.TextColor3 = C.Bad
		table.insert(lines, "The run resets to Night 1.")
		table.insert(lines, "Your creatures, eggs and coins are safe.")
		table.insert(lines, "Evolve, hatch stronger eggs, and try again!")
	elseif result.Survived then
		refs.ResultTitle.Text = ("☀️ NIGHT %d SURVIVED!"):format(result.Night)
		refs.ResultTitle.TextColor3 = C.Gold
		table.insert(lines, ("🪙 +%d coins"):format(result.Coins or 0))
		table.insert(lines, ("✨ +%d creature XP"):format(result.XP or 0))
		table.insert(lines, ("🍓 +%d berries"):format(result.Berries or 0))
		for _, eggId in result.Eggs or {} do
			local egg = ctx.EggData[eggId]
			table.insert(lines, "🥚 " .. (if egg then egg.Name else eggId))
		end
	else
		refs.ResultTitle.Text = "💀 YOU FELL LAST NIGHT"
		refs.ResultTitle.TextColor3 = C.Bad
		table.insert(lines, "No rewards this time.")
		table.insert(lines, "Stay close to your creature and feed it when it's hurt.")
	end
	refs.ResultBody.Text = table.concat(lines, "\n")
	refs.NightResult.Visible = true
	refs.NightResult.Size = UIKit.scaleUDim2(baseSizes.NightResult, 0.8)
	UIKit.tween(refs.NightResult, 0.35, { Size = baseSizes.NightResult }, Enum.EasingStyle.Back)
	task.delay(5, function()
		refs.NightResult.Visible = false
	end)
end

function Hud.SetBoss(data)
	bossState = data
	refs.BossBar.Visible = data ~= nil
	if data then
		refs.BossName.Text = data.Name .. (if data.Enraged then "  🔥 ENRAGED" else "") .. (if data.Exposed then "  💥 CORE EXPOSED" else "")
		refs.BossFill.BackgroundColor3 = if data.Exposed then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(220, 50, 50)
		UIKit.tween(refs.BossFill, 0.15, { Size = UDim2.fromScale(math.clamp(data.Health / data.MaxHealth, 0, 1), 1) })
	end
end

---------------------------------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------------------------------
local function equippedRecord(profile)
	if not profile or not profile.Equipped then
		return nil
	end
	for _, record in profile.Creatures do
		if record.Id == profile.Equipped then
			return record
		end
	end
	return nil
end

local function objectiveText(profile): string
	if not profile then
		return "Loading..."
	end
	local phase = ctx.Root:GetAttribute("Phase")
	local record = equippedRecord(profile)
	if #profile.Creatures == 0 then
		if profile.Incubator then
			return "🥚 Your first egg is hatching... get ready!"
		elseif #profile.Eggs > 0 then
			return "🥚 Open Eggs and hatch an egg!"
		end
		return "🥚 Find an egg in the forest!"
	end
	if player:GetAttribute("CreatureKO") then
		return "💫 Your creature is down! Feed it a berry [F] to revive it"
	end
	if record and ctx.CreatureData.CanEvolve(record) then
		return "✨ Your creature can EVOLVE! Tap Evolve"
	end
	if phase == "Night" then
		if bossState then
			return "⚠️ Dodge the red zones! Hit the glowing core after a slam"
		end
		return "🌙 Survive until morning! Click enemies to send your creature"
	end
	local remaining = (ctx.Root:GetAttribute("PhaseEndsAt") or 0) - serverNow()
	if remaining < 12 then
		return "⚠️ Night is coming! Stay near camp and your creature"
	end
	if profile.Berries == 0 then
		return "🍓 Pick berries in the forest - they feed and heal your creature"
	end
	if profile.Incubator == nil and #profile.Eggs > 0 then
		return "🥚 You have an egg waiting - open Eggs to hatch it"
	end
	if record then
		local stage = ctx.CreatureData.Stages[record.Stage]
		if stage and stage.XPToEvolve and record.XP < stage.XPToEvolve then
			return "Feed your creature [F] and explore the Cave, Ruins and Cabin for eggs"
		end
	end
	return "Explore for eggs and crystals before nightfall"
end

function Hud.RefreshProfile()
	local profile = ctx.Profile
	if not profile then
		return
	end
	refs.Coins.Text = "🪙 " .. UIKit.formatNumber(profile.Coins)
	refs.Berries.Text = "🍓 " .. profile.Berries
	refs.Best.Text = "🏆 Best: Night " .. profile.HighestNight

	local eggCount = #profile.Eggs
	refs.EggBadge.Visible = eggCount > 0
	refs.EggBadge.Text = tostring(eggCount)

	local record = equippedRecord(profile)
	refs.CreatureCard.Visible = record ~= nil
	if record then
		local CD = ctx.CreatureData
		local rarity = CD.GetRarity(record)
		refs.CreatureName.Text = UIKit.FamilyIcons[record.Family] .. " " .. CD.GetDisplayName(record)
		refs.CreatureName.TextColor3 = ctx.Rarity.Colors[rarity]
		local stage = CD.Stages[record.Stage]
		refs.CreatureStage.Text = ("%s • %s • Stage %d/%d"):format(rarity, stage.Name, record.Stage, #CD.Stages)
		if stage.XPToEvolve then
			refs.CreatureXPFill.Size = UDim2.fromScale(math.clamp(record.XP / stage.XPToEvolve, 0, 1), 1)
			refs.CreatureXPText.Text = ("XP %d/%d • Nights %d/%d"):format(record.XP, stage.XPToEvolve, record.StageNights, stage.NightsToEvolve)
		else
			refs.CreatureXPFill.Size = UDim2.fromScale(1, 1)
			refs.CreatureXPText.Text = "MAX STAGE • " .. record.Nights .. " nights survived"
		end
		refs.EvolveButton.Visible = CD.CanEvolve(record)
	end
	refs.Objective.Text = objectiveText(profile)
end

local function refreshCreatureAttributes()
	local hp = player:GetAttribute("CreatureHP") or 0
	local maxHp = player:GetAttribute("CreatureMaxHP") or 1
	local ko = player:GetAttribute("CreatureKO")
	refs.CreatureHPFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	refs.CreatureHPFill.BackgroundColor3 = if ko then C.Bad elseif hp / maxHp < 0.35 then Color3.fromRGB(255, 170, 60) else C.Good
	refs.CreatureHPText.Text = if ko then "KNOCKED OUT" else ("%d / %d"):format(hp, maxHp)
	local mode = player:GetAttribute("CreatureMode") or "Attack"
	for name, button in refs.ModeButtons do
		local selected = button:GetAttribute("SelectedColor") or Color3.fromRGB(70, 140, 255)
		button.BackgroundColor3 = if name == mode then selected else modeColors[button]
	end
	if ctx.Profile then
		refs.Objective.Text = objectiveText(ctx.Profile)
	end
end

local function refreshPhase()
	local root = ctx.Root
	local phase = root:GetAttribute("Phase") or "Day"
	local night = root:GetAttribute("Night") or 1
	local modifier = root:GetAttribute("Modifier") or "None"
	local isNight = phase == "Night"
	refs.PhaseTitle.Text = if isNight then ("🌙 NIGHT %d"):format(night) else ("☀️ DAY %d"):format(night)
	refs.PhaseTitle.TextColor3 = if isNight then Color3.fromRGB(200, 185, 255) else Color3.fromRGB(255, 225, 130)
	local top = if isNight then Color3.fromRGB(45, 30, 95) else Color3.fromRGB(70, 120, 170)
	if modifier == "BloodMoon" or modifier == "Nightmare" or modifier == "Apocalypse" then
		top = Color3.fromRGB(110, 20, 20)
	end
	if refs.BannerGradient then
		refs.BannerGradient.Color = ColorSequence.new(top, C.Panel)
	end

	local key = phase .. night
	if key ~= lastPhaseKey then
		local first = lastPhaseKey == ""
		lastPhaseKey = key
		if not first or isNight then
			if isNight then
				local sub = if modifier == "BloodMoon" then "🩸 BLOOD MOON - SURVIVE" else "SURVIVE UNTIL MORNING"
				Hud.BigTitle(("NIGHT %d"):format(night), sub, Color3.fromRGB(190, 170, 255))
			else
				Hud.BigTitle(("DAY %d"):format(night), "PREPARE FOR THE NIGHT", Color3.fromRGB(255, 220, 120))
			end
		end
		if not isNight then
			refs.DeathOverlay.Visible = false
		end
	end
end

local function tick()
	local root = ctx.Root
	local phase = root:GetAttribute("Phase") or "Day"
	local remaining = (root:GetAttribute("PhaseEndsAt") or 0) - serverNow()
	local label = if phase == "Night" then "SURVIVE" else "PREPARE"
	refs.PhaseSub.Text = ("%s • %s"):format(label, UIKit.formatTime(remaining))
	refs.PhaseSub.TextColor3 = if phase == "Day" and remaining < 12 then C.Bad else C.SubText

	local readyAt = player:GetAttribute("AbilityReadyAt") or 0
	local cooldown = readyAt - serverNow()
	local record = equippedRecord(ctx.Profile)
	local ability = record and ctx.CreatureData.Families[record.Family].Ability
	if ability then
		refs.AbilityCooldown.Size = UDim2.fromScale(1, math.clamp(cooldown / ability.Cooldown, 0, 1))
		refs.AbilityButton.Text = if cooldown > 0 then ("%s\n%ds"):format(ability.Name, math.ceil(cooldown)) else ability.Name .. "\n[Q]"
	else
		refs.AbilityCooldown.Size = UDim2.fromScale(1, 0)
		refs.AbilityButton.Text = "ABILITY\n[Q]"
	end
	refs.FeedButton.Text = ("🍓 FEED [F]\nx%d"):format(if ctx.Profile then ctx.Profile.Berries else 0)
	refs.Objective.Text = objectiveText(ctx.Profile)

	local incubator = ctx.Profile and ctx.Profile.Incubator
	refs.Incubator.Visible = incubator ~= nil
	if incubator then
		local egg = ctx.EggData[incubator.EggId]
		local total = math.max(0.1, incubator.EndsAt - incubator.StartedAt)
		local left = incubator.EndsAt - serverNow()
		refs.IncubatorText.Text = ("🥚 %s hatching... %s"):format(if egg then egg.Name else "Egg", UIKit.formatTime(left + 0.99))
		refs.IncubatorFill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
	end
end

function Hud.SetDead(dead: boolean)
	refs.DeathOverlay.Visible = dead
end

function Hud.Init(context)
	ctx = context
	bind(ctx.Gui)

	for _, attr in { "Phase", "Night", "Modifier" } do
		ctx.Root:GetAttributeChangedSignal(attr):Connect(refreshPhase)
	end
	for _, attr in { "CreatureHP", "CreatureMaxHP", "CreatureKO", "CreatureMode" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshCreatureAttributes)
	end
	ctx.ProfileChanged:Connect(Hud.RefreshProfile)

	refreshPhase()
	refreshCreatureAttributes()

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
end

return Hud
]=])
make(n1, "ModuleScript", "Layout", [=[
-- The default look of the HUD and menu window. Only builds instances; no gameplay logic.
-- Hud/Panels find every element BY NAME, so a designer can export this layout to StarterGui,
-- restyle it freely in Studio, and the game will use their version (see README "Editing the UI").
local StarterGui = game:GetService("StarterGui")

local UIKit = require(script.Parent.UIKit)

local Layout = {}

Layout.GUI_NAME = "HatchOrDieUI"
local C = UIKit.Colors

local function named(inst: Instance, name: string)
	inst.Name = name
	return inst
end

local function bar(parent: Instance, name: string, props, color: Color3)
	props.Parent = parent
	local back, fill = UIKit.bar(props, color)
	back.Name = name .. "Back"
	fill.Name = name
	return back, fill
end

function Layout.BuildHud(gui: ScreenGui)
	-- Phase banner
	local banner = UIKit.panel({ Name = "PhaseBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(300, 62), Parent = gui })
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 120, 170), C.Panel), Parent = banner })
	named(UIKit.text({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.3, Text = "☀️ DAY 1", TextColor3 = Color3.fromRGB(255, 225, 130), Parent = banner }), "PhaseTitle")
	named(UIKit.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 38), TextColor3 = C.SubText, Text = "PREPARE • 0:40", Parent = banner }), "PhaseSub")

	local objective = named(UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0.6, 0, 0, 22),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = C.Bg,
		Font = Enum.Font.GothamMedium,
		Text = "🥚 Your first egg is hatching... get ready!",
		Parent = gui,
	}), "Objective")
	UIKit.corner(objective, 8)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 22), Parent = objective })

	-- Boss bar
	local boss = UIKit.new("Frame", { Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.new(0.7, 0, 0, 42), BackgroundTransparency = 1, Parent = gui })
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 42), Parent = boss })
	named(UIKit.text({ Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 120, 90), TextStrokeTransparency = 0.2, Text = "Rotwood Colossus", Parent = boss }), "BossName")
	local bossBack = bar(boss, "BossFill", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 18) }, Color3.fromRGB(220, 50, 50))
	UIKit.stroke(bossBack, Color3.new(0, 0, 0), 2, 0.2)

	-- Currencies
	local currencies = UIKit.panel({ Name = "Currencies", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(150, 92), Parent = gui })
	UIKit.padding(currencies, 6)
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), Parent = currencies })
	for _, row in { { "Coins", "🪙 0", C.Gold }, { "Berries", "🍓 0", C.Berry }, { "Best", "🏆 Best: Night 0", C.Text } } do
		named(UIKit.text({ Size = UDim2.new(1, 0, 0, 25), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = row[3], Font = Enum.Font.FredokaOne, Text = row[2], Parent = currencies }), row[1])
	end

	-- Creature card
	local card = UIKit.panel({ Name = "CreatureCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.45, 0), Size = UDim2.fromOffset(230, 128), Parent = gui })
	UIKit.padding(card, 8)
	named(UIKit.text({ Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "🌿 Sproutling", Parent = card }), "CreatureName")
	named(UIKit.text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Text = "Common • Baby • Stage 1/3", Parent = card }), "CreatureStage")
	bar(card, "CreatureHPFill", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14) }, C.Good)
	named(UIKit.text({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14), TextStrokeTransparency = 0.2, Text = "140 / 140", Parent = card }), "CreatureHPText")
	bar(card, "CreatureXPFill", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 10) }, C.Accent)
	named(UIKit.text({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Text = "XP 0/100 • Nights 0/1", Parent = card }), "CreatureXPText")
	UIKit.button({ Name = "EvolveButton", Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.Gold, TextColor3 = Color3.fromRGB(40, 25, 0), Text = "✨ EVOLVE!", Parent = card })

	-- Actions: commands, feed, ability
	local actions = UIKit.new("Frame", { Name = "Actions", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(250, 170), BackgroundTransparency = 1, Parent = gui })
	for i, mode in { "Follow", "Attack", "Defend" } do
		UIKit.button({ Name = "Mode" .. mode, Position = UDim2.new((i - 1) / 3, 2, 0, 0), Size = UDim2.new(1 / 3, -4, 0, 34), Text = ("%s [%d]"):format(mode, i), Parent = actions })
	end
	UIKit.button({ Name = "FeedButton", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, 0), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = Color3.fromRGB(150, 50, 80), Text = "🍓 FEED [F]\nx0", Parent = actions })
	local ability = UIKit.button({ Name = "AbilityButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(120, 120), BackgroundColor3 = Color3.fromRGB(80, 60, 170), Text = "ABILITY\n[Q]", Parent = actions })
	ability:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local cooldown = UIKit.new("Frame", { Name = "AbilityCooldown", Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = ability })
	UIKit.corner(cooldown, 60)

	-- Menu bar
	local menu = UIKit.new("Frame", { Name = "Menu", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(330, 58), BackgroundTransparency = 1, Parent = gui })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	for i, item in { { "Eggs", "🥚 Eggs" }, { "Creatures", "🐲 Creatures" }, { "Shop", "🛒 Shop" } } do
		UIKit.button({ Name = "Menu" .. item[1], LayoutOrder = i, Size = UDim2.fromOffset(104, 54), BackgroundColor3 = C.Panel, Text = item[2], Parent = menu })
	end
	local badge = named(UIKit.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = C.Bad, Font = Enum.Font.FredokaOne, Text = "1", ZIndex = 3, Parent = menu:FindFirstChild("MenuEggs") }), "EggBadge")
	UIKit.corner(badge, 12)

	-- Incubator timer
	local incubator = UIKit.panel({ Name = "Incubator", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(300, 46), Parent = gui })
	named(UIKit.text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), Font = Enum.Font.FredokaOne, Text = "🥚 Forest Egg hatching... 0:10", Parent = incubator }), "IncubatorText")
	bar(incubator, "IncubatorFill", { Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 0, 10) }, C.Gold)

	-- Messages
	local toasts = UIKit.new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(320, 260), BackgroundTransparency = 1, Parent = gui })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = toasts })

	local announcement = named(UIKit.text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Size = UDim2.new(0.8, 0, 0, 40), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.1, TextColor3 = C.Gold, Text = "🌟 PLAYER HATCHED A CELESTIAL DRAGON!", Parent = gui }), "Announcement")
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 38, Parent = announcement })
	named(UIKit.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.8, 0, 0, 90), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "NIGHT 1", TextColor3 = Color3.fromRGB(190, 170, 255), Parent = gui }), "BigTitle")
	named(UIKit.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 62), Size = UDim2.new(0.6, 0, 0, 32), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.2, Text = "SURVIVE UNTIL MORNING", Parent = gui }), "BigSub")

	local result = UIKit.panel({ Name = "NightResult", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(360, 190), Parent = gui })
	UIKit.padding(result, 12)
	named(UIKit.text({ Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.FredokaOne, TextColor3 = C.Gold, Text = "☀️ NIGHT 1 SURVIVED!", Parent = result }), "ResultTitle")
	named(UIKit.text({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), TextScaled = false, TextSize = 20, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, Text = "🪙 +37 coins\n✨ +55 creature XP\n🍓 +2 berries", Parent = result }), "ResultBody")

	local death = named(UIKit.text({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 0, 0), BackgroundTransparency = 0.55, Text = "💀 YOU FELL\nYou'll return at dawn... if anyone survives.", Font = Enum.Font.FredokaOne, ZIndex = 0, Parent = gui }), "DeathOverlay")
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 40, Parent = death })
end

function Layout.BuildWindow(gui: ScreenGui)
	local window = UIKit.panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.78), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.05, ZIndex = 5, Parent = gui })
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(760, 520), Parent = window })
	UIKit.padding(window, 12)
	named(UIKit.text({ Size = UDim2.new(1, -50, 0, 32), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "🥚 EGGS", Parent = window }), "WindowTitle")
	UIKit.button({ Name = "WindowClose", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(40, 32), BackgroundColor3 = C.Bad, Text = "X", Parent = window })
	UIKit.new("Frame", { Name = "WindowContent", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, Parent = window })
end

-- Builds a complete default ScreenGui (used for the in-game default and for the StarterGui export).
function Layout.Build(): ScreenGui
	local gui = UIKit.new("ScreenGui", { Name = Layout.GUI_NAME, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	Layout.BuildHud(gui)
	Layout.BuildWindow(gui)
	return gui
end

-- Uses the designer's StarterGui.HatchOrDieUI when present, otherwise the built-in layout.
function Layout.Obtain(player: Player): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local template = StarterGui:FindFirstChild(Layout.GUI_NAME)
	local gui
	if template then
		gui = playerGui:WaitForChild(Layout.GUI_NAME, 10)
		if not gui then
			gui = template:Clone()
		end
	else
		gui = Layout.Build()
	end
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	return gui
end

-- Finds a UI element by name anywhere in the gui. Missing elements are replaced by hidden
-- placeholders so a designer deleting something never breaks the game.
function Layout.Finder(gui: ScreenGui)
	local missing = UIKit.new("Frame", { Name = "MissingElements", Visible = false, Parent = gui })
	return function(name: string, className: string?): any
		local found = gui:FindFirstChild(name, true)
		if found then
			return found
		end
		warn(("[HatchOrDie UI] '%s' not found in %s - add an element with that name to show it."):format(name, gui.Name))
		return UIKit.new(className or "TextButton", { Name = name, Parent = missing })
	end
end

return Layout
]=])
make(n1, "ModuleScript", "Panels", [=[
-- Modal menus: Eggs (with odds), Creatures (collection + evolve/equip/aura), Shop.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local UIKit = require(script.Parent.UIKit)

local Panels = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local ctx
local window: Frame
local titleLabel: TextLabel
local content: Frame
local windowSize: UDim2
local current: string? = nil
local selectedCreature: string? = nil
local shopTab = "Eggs"
local lastSignature = ""

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
end

local function scrolling(props): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in props do
		defaults[k] = v
	end
	return UIKit.new("ScrollingFrame", defaults)
end

local function oddsText(egg): string
	local total = 0
	for _, entry in egg.Pool do
		total += entry.Weight
	end
	local parts = {}
	for _, entry in egg.Pool do
		table.insert(parts, ("%s %s %.0f%%"):format(UIKit.FamilyIcons[entry.Family], entry.Family, entry.Weight / total * 100))
	end
	return table.concat(parts, "  ") .. ("\n🧬 Mutation chance %.0f%%"):format(egg.MutationChance * 100)
end

local function sortedEggIds(): { string }
	local ids = {}
	for id in ctx.EggData do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return ctx.EggData[a].Order < ctx.EggData[b].Order
	end)
	return ids
end

---------------------------------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------------------------------
local function renderEggs()
	local profile = ctx.Profile
	titleLabel.Text = ("🥚 EGGS (%d/%d)"):format(#profile.Eggs, ctx.GameConfig.MaxEggs)

	local status = UIKit.text({ Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.SubText, Parent = content })
	if profile.Incubator then
		local egg = ctx.EggData[profile.Incubator.EggId]
		status.Text = ("Incubating: %s - watch the timer above the menu"):format(if egg then egg.Name else "Egg")
		status.TextColor3 = C.Gold
	else
		status.Text = "Your incubator is empty - pick an egg to hatch!"
	end

	local list = scrolling({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), Parent = content })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 250), CellPadding = UDim2.fromOffset(10, 10), Parent = list })

	local counts = {}
	local firstOf = {}
	for _, egg in profile.Eggs do
		counts[egg.EggId] = (counts[egg.EggId] or 0) + 1
		firstOf[egg.EggId] = firstOf[egg.EggId] or egg.Id
	end

	for _, eggId in sortedEggIds() do
		local egg = ctx.EggData[eggId]
		local count = counts[eggId] or 0
		local card = UIKit.panel({ BackgroundColor3 = C.PanelLight, Parent = list })
		UIKit.padding(card, 8)
		UIKit.viewport({ Size = UDim2.new(1, 0, 0, 80), Parent = card }, ctx.Models.BuildEgg(eggId), true)
		UIKit.text({ Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 22), Text = egg.Name, Font = Enum.Font.FredokaOne, TextColor3 = ctx.Rarity.Colors[egg.Rarity], Parent = card })
		UIKit.text({ Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 16), Text = ("%s • %ds • Owned x%d"):format(egg.Rarity, egg.HatchTime, count), TextColor3 = C.SubText, Parent = card })
		UIKit.text({ Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 0, 52), Text = oddsText(egg), TextColor3 = C.Text, Font = Enum.Font.Gotham, Parent = card })
		if count > 0 then
			UIKit.button({
				Position = UDim2.new(0, 0, 1, -40),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = if profile.Incubator then C.PanelLight else Color3.fromRGB(70, 170, 90),
				Text = if profile.Incubator then "Incubator busy" else "HATCH",
				Parent = card,
			}, function()
				ctx.Net.Get("RequestHatch"):FireServer(firstOf[eggId])
			end)
		else
			UIKit.button({
				Position = UDim2.new(0, 0, 1, -40),
				Size = UDim2.new(1, 0, 0, 40),
				Text = ("Buy - 🪙 %d"):format(egg.Price),
				Parent = card,
			}, function()
				ctx.Net.Get("BuyItem"):FireServer(eggId)
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Creatures
---------------------------------------------------------------------------------------------------
local function findCreature(id: string?)
	if not id then
		return nil
	end
	for _, record in ctx.Profile.Creatures do
		if record.Id == id then
			return record
		end
	end
	return nil
end

local function totalDiscoverable(): number
	local CD = ctx.CreatureData
	local families = 0
	for _ in CD.Families do
		families += 1
	end
	return families * #CD.Stages * (1 + #CD.Mutations)
end

local function renderCreatureDetail(parent: Frame, record)
	local CD = ctx.CreatureData
	local profile = ctx.Profile
	local rarity = CD.GetRarity(record)
	local stats = CD.GetStats(record)
	local family = CD.Families[record.Family]
	local stage = CD.Stages[record.Stage]

	UIKit.viewport({ Size = UDim2.new(1, 0, 0, 150), Parent = parent }, ctx.Models.BuildCreature(record), true)
	UIKit.text({ Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 0, 26), Text = CD.GetDisplayName(record), Font = Enum.Font.FredokaOne, TextColor3 = ctx.Rarity.Colors[rarity], Parent = parent })
	UIKit.text({
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(1, 0, 0, 16),
		Text = ("%s • %s • %s"):format(rarity, stage.Name, if record.Mutation then "🧬 " .. record.Mutation else "No mutation"),
		TextColor3 = C.SubText,
		Parent = parent,
	})
	UIKit.text({
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.new(1, 0, 0, 34),
		Text = ("❤️ %d  ⚔️ %.1f  🎯 %.0f\n✨ %s"):format(stats.MaxHealth, stats.Damage, stats.Range, family.Ability.Name),
		Font = Enum.Font.Gotham,
		Parent = parent,
	})

	local nextText
	if stage.XPToEvolve then
		local nextRecord = table.clone(record)
		nextRecord.Stage += 1
		nextRecord.Mutation = nil
		local known = profile.Discovered[CD.DiscoveryKey(nextRecord)]
		local nextName = if known then CD.GetStageName(nextRecord) else "???"
		nextText = ("Next: %s  |  XP %d/%d  |  Nights %d/%d"):format(nextName, record.XP, stage.XPToEvolve, record.StageNights, stage.NightsToEvolve)
	else
		nextText = ("Fully evolved • %d nights survived"):format(record.Nights)
	end
	UIKit.text({ Position = UDim2.fromOffset(0, 232), Size = UDim2.new(1, 0, 0, 16), Text = nextText, TextColor3 = C.Accent, Parent = parent })

	local buttons = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 254), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = parent })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = buttons })
	local equipped = profile.Equipped == record.Id
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = if equipped then C.PanelLight else Color3.fromRGB(70, 140, 255), Text = if equipped then "Equipped" else "Equip", Parent = buttons }, function()
		ctx.Net.Get("EquipCreature"):FireServer(record.Id)
	end)
	local canEvolve = CD.CanEvolve(record)
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = if canEvolve then C.Gold else C.PanelLight, TextColor3 = if canEvolve then Color3.fromRGB(40, 25, 0) else C.SubText, Text = "Evolve", Parent = buttons }, function()
		ctx.Net.Get("EvolveCreature"):FireServer(record.Id)
	end)
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), Text = if record.Locked then "🔒 Locked" else "🔓 Lock", Parent = buttons }, function()
		ctx.Net.Get("ToggleLock"):FireServer(record.Id)
	end)
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Text = "Release", Parent = buttons }, function()
		ctx.Net.Get("ReleaseCreature"):FireServer(record.Id)
	end)

	if equipped then
		local auras = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 294), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = parent })
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = auras })
		UIKit.button({ Size = UDim2.fromOffset(60, 28), Text = "No aura", Parent = auras }, function()
			ctx.Net.Get("EquipAura"):FireServer("")
		end)
		for auraId, aura in ctx.CreatureData.Auras do
			local owned = profile.Auras[auraId] or (auraId == "Golden" and player:GetAttribute("Pass_VIP"))
			if owned then
				UIKit.button({ Size = UDim2.fromOffset(80, 28), BackgroundColor3 = aura.Color:Lerp(Color3.new(0, 0, 0), 0.4), Text = aura.Name:gsub(" Aura", ""), Parent = auras }, function()
					ctx.Net.Get("EquipAura"):FireServer(auraId)
				end)
			end
		end
	end
end

local function renderCreatures()
	local profile = ctx.Profile
	local CD = ctx.CreatureData
	local discovered = 0
	for _ in profile.Discovered do
		discovered += 1
	end
	titleLabel.Text = ("🐲 CREATURES (%d/%d) • Discovered %d/%d"):format(#profile.Creatures, ctx.SlotLimit(), discovered, totalDiscoverable())

	if #profile.Creatures == 0 then
		UIKit.text({ Size = UDim2.new(1, 0, 0, 40), Text = "No creatures yet - hatch an egg!", Parent = content })
		return
	end
	if not findCreature(selectedCreature) then
		selectedCreature = profile.Equipped or profile.Creatures[1].Id
	end

	local list = scrolling({ Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 74), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local sorted = table.clone(profile.Creatures)
	table.sort(sorted, function(a, b)
		if (a.Id == profile.Equipped) ~= (b.Id == profile.Equipped) then
			return a.Id == profile.Equipped
		end
		local ra, rb = ctx.Rarity.Rank[CD.GetRarity(a)], ctx.Rarity.Rank[CD.GetRarity(b)]
		if ra ~= rb then
			return ra > rb
		end
		return a.Stage > b.Stage
	end)

	for i, record in sorted do
		local rarity = CD.GetRarity(record)
		local selected = record.Id == selectedCreature
		local card = UIKit.button({
			LayoutOrder = i,
			BackgroundColor3 = if selected then ctx.Rarity.Colors[rarity]:Lerp(C.Panel, 0.55) else C.PanelLight,
			Text = "",
			Parent = list,
		}, function()
			selectedCreature = record.Id
			Panels.Render(true)
		end)
		card:FindFirstChildOfClass("UIStroke").Color = ctx.Rarity.Colors[rarity]
		UIKit.text({ Size = UDim2.new(1, 0, 0, 30), Text = UIKit.FamilyIcons[record.Family] .. (if record.Mutation then "🧬" else ""), Parent = card })
		UIKit.text({ Position = UDim2.fromOffset(2, 30), Size = UDim2.new(1, -4, 0, 24), Text = CD.GetDisplayName(record), TextColor3 = ctx.Rarity.Colors[rarity], Parent = card })
		local tags = (if record.Id == profile.Equipped then "⭐ " else "") .. (if record.Locked then "🔒 " else "") .. CD.Stages[record.Stage].Name
		UIKit.text({ Position = UDim2.fromOffset(2, 54), Size = UDim2.new(1, -4, 0, 16), Text = tags, TextColor3 = C.SubText, Parent = card })
	end

	local detail = UIKit.new("Frame", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = content })
	local record = findCreature(selectedCreature)
	if record then
		renderCreatureDetail(detail, record)
	end
end

---------------------------------------------------------------------------------------------------
-- Shop
---------------------------------------------------------------------------------------------------
local function shopRow(parent: Instance, name: string, description: string, priceText: string, buttonText: string, enabled: boolean, onBuy: () -> ())
	local row = UIKit.panel({ Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.PanelLight, Parent = parent })
	UIKit.text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(0.62, -10, 0, 24), Text = name, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	UIKit.text({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(0.62, -10, 0, 26), Text = description, TextColor3 = C.SubText, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 44),
		BackgroundColor3 = if enabled then Color3.fromRGB(70, 170, 90) else C.Panel,
		TextColor3 = if enabled then C.Text else C.SubText,
		Text = if buttonText ~= "" then buttonText else priceText,
		Parent = row,
	}, function()
		if enabled then
			onBuy()
		end
	end)
end

local function renderShop()
	local profile = ctx.Profile
	titleLabel.Text = ("🛒 SHOP • 🪙 %s"):format(UIKit.formatNumber(profile.Coins))

	local tabs = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = content })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabs })
	for _, category in ctx.ShopData.Categories do
		UIKit.button({
			Size = UDim2.new(0.25, -5, 1, 0),
			BackgroundColor3 = if category == shopTab then Color3.fromRGB(70, 140, 255) else C.PanelLight,
			Text = category,
			Parent = tabs,
		}, function()
			shopTab = category
			Panels.Render(true)
		end)
	end

	local list = scrolling({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42), Parent = content })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })

	if shopTab == "Robux" then
		for _, item in ctx.ShopData.Robux do
			local configTable = if item.Kind == "Gamepass" then ctx.GameConfig.Gamepasses else ctx.GameConfig.Products
			local id = configTable[item.ConfigKey] or 0
			local owned = item.Kind == "Gamepass" and player:GetAttribute("Pass_" .. item.ConfigKey)
			local buttonText = if owned then "Owned" elseif id == 0 then "Coming soon" else ""
			shopRow(list, item.Name, item.Description, ("R$ %d"):format(item.Robux), buttonText, id ~= 0 and not owned, function()
				if item.Kind == "Gamepass" then
					MarketplaceService:PromptGamePassPurchase(player, id)
				else
					MarketplaceService:PromptProductPurchase(player, id)
				end
			end)
		end
		UIKit.text({ Size = UDim2.new(1, -8, 0, 36), Text = "Robux items are convenience & cosmetics only. Everything that matters in a fight can be earned by playing.", TextColor3 = C.SubText, Font = Enum.Font.Gotham, Parent = list })
		return
	end

	for _, item in ctx.ShopData.Items do
		if item.Category == shopTab then
			local description = item.Description or ""
			local owned = false
			if item.Kind == "Egg" then
				description = oddsText(ctx.EggData[item.EggId]):gsub("\n", "  ")
			elseif item.Kind == "Aura" then
				owned = profile.Auras[item.AuraId] == true
				description = "Cosmetic only - particles + glow on your creature."
			end
			local affordable = profile.Coins >= item.Price
			local buttonText = if owned then "Owned" else ""
			shopRow(list, item.Name, description, ("🪙 %d"):format(item.Price), buttonText, affordable and not owned, function()
				ctx.Net.Get("BuyItem"):FireServer(item.Id)
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local RENDERERS = { Eggs = renderEggs, Creatures = renderCreatures, Shop = renderShop }

local function signature(): string
	local profile = ctx.Profile
	if not profile then
		return ""
	end
	local coins = if current == "Shop" then tostring(profile.Coins) else ""
	local parts = { current or "", coins, tostring(profile.Equipped), tostring(profile.Incubator ~= nil), tostring(#profile.Eggs) }
	for _, record in profile.Creatures do
		table.insert(parts, ("%s%d%s%s%s%d%d"):format(record.Id, record.Stage, tostring(record.Mutation), tostring(record.Locked), tostring(record.Aura), record.XP, record.StageNights))
	end
	for auraId in profile.Auras do
		table.insert(parts, auraId)
	end
	return table.concat(parts, "|")
end

function Panels.Render(force: boolean?)
	if not current or not ctx.Profile then
		return
	end
	local sig = signature()
	if not force and sig == lastSignature then
		return
	end
	lastSignature = sig
	clear()
	RENDERERS[current]()
end

function Panels.Open(name: string)
	if not RENDERERS[name] then
		return
	end
	current = name
	window.Visible = true
	window.Size = UIKit.scaleUDim2(windowSize, 0.94)
	UIKit.tween(window, 0.2, { Size = windowSize }, Enum.EasingStyle.Back)
	Panels.Render(true)
end

function Panels.Close()
	current = nil
	window.Visible = false
	clear()
end

function Panels.Toggle(name: string)
	if current == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

function Panels.IsOpen(): boolean
	return current ~= nil
end

function Panels.Init(context)
	ctx = context
	local find = ctx.Layout.Finder(ctx.Gui)
	window = find("Window", "Frame")
	titleLabel = find("WindowTitle", "TextLabel")
	content = find("WindowContent", "Frame")
	local closeButton = find("WindowClose")
	UIKit.decorate(closeButton)
	closeButton.Activated:Connect(Panels.Close)
	windowSize = window.Size
	window.Visible = false

	ctx.ProfileChanged:Connect(function()
		Panels.Render(false)
	end)
end

return Panels
]=])
make(n1, "ModuleScript", "UIKit", [=[
-- Small UI helpers so every screen shares one look.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIKit = {}

local viewportSetters = setmetatable({}, { __mode = "k" })

UIKit.Colors = {
	Bg = Color3.fromRGB(16, 18, 28),
	Panel = Color3.fromRGB(28, 31, 46),
	PanelLight = Color3.fromRGB(44, 48, 70),
	Text = Color3.fromRGB(245, 245, 250),
	SubText = Color3.fromRGB(170, 175, 195),
	Gold = Color3.fromRGB(255, 205, 70),
	Good = Color3.fromRGB(110, 230, 120),
	Bad = Color3.fromRGB(255, 90, 90),
	Day = Color3.fromRGB(255, 185, 60),
	Night = Color3.fromRGB(110, 90, 255),
	Berry = Color3.fromRGB(255, 110, 150),
	Accent = Color3.fromRGB(90, 200, 255),
}

UIKit.FamilyIcons = { Sprout = "🌿", Ember = "🔥", Shade = "🌑" }

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, px: number)
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UIKit.panel(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = UIKit.new("Frame", defaults)
	UIKit.corner(frame, 12)
	UIKit.stroke(frame, Color3.new(0, 0, 0), 2, 0.5)
	return frame
end

function UIKit.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		TextStrokeTransparency = 0.6,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	return UIKit.new("TextLabel", defaults)
end

function UIKit.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local defaults = {
		BackgroundColor3 = UIKit.Colors.PanelLight,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		TextStrokeTransparency = 0.5,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = UIKit.new("TextButton", defaults)
	UIKit.corner(button, 10)
	UIKit.stroke(button, Color3.new(0, 0, 0), 2, 0.4)
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = button })
	UIKit.decorate(button)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Hover/press bounce for any button, including ones a designer made in Studio. Safe to call twice.
local decorated = setmetatable({}, { __mode = "k" })
function UIKit.decorate(button: GuiButton)
	if decorated[button] or not button:IsA("GuiButton") then
		return
	end
	decorated[button] = true
	local scale = button:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = button })
	local base = scale.Scale
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = base * 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = base })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.06, { Scale = base * 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = base })
	end)
end

-- Multiplies a UDim2 (used to animate designer-sized frames relative to their own size).
function UIKit.scaleUDim2(size: UDim2, k: number): UDim2
	return UDim2.new(size.X.Scale * k, size.X.Offset * k, size.Y.Scale * k, size.Y.Offset * k)
end

function UIKit.bar(props: { [string]: any }, fillColor: Color3): (Frame, Frame)
	local back = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BorderSizePixel = 0,
	})
	for k, v in props do
		(back :: any)[k] = v
	end
	UIKit.corner(back, 6)
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
	})
	UIKit.corner(fill, 6)
	return back, fill
end

function UIKit.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UIKit.formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

function UIKit.formatNumber(n: number): string
	if n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

-- Renders a model in a ViewportFrame, optionally spinning. Destroying the viewport stops the spin.
function UIKit.viewport(props: { [string]: any }, model: Model?, spin: boolean?): ViewportFrame
	local defaults = {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(160, 160, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	}
	for k, v in props do
		defaults[k] = v
	end
	local vp = UIKit.new("ViewportFrame", defaults)
	local camera = UIKit.new("Camera", { FieldOfView = 40, Parent = vp })
	vp.CurrentCamera = camera

	local current: Model? = nil
	local angle = 0
	local connection: RBXScriptConnection? = nil

	local function setModel(newModel: Model?)
		if current then
			current:Destroy()
		end
		current = newModel
		if not newModel then
			return
		end
		newModel:PivotTo(CFrame.new())
		newModel.Parent = vp
		local boxCFrame, size = newModel:GetBoundingBox()
		local center = Vector3.new(0, boxCFrame.Position.Y, 0)
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0.45, 0.35, -1).Unit * distance, center)
	end
	setModel(model)

	if spin then
		connection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.9
			if current and current.Parent then
				current:PivotTo(CFrame.Angles(0, angle, 0))
			end
		end)
		vp.Destroying:Connect(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end

	viewportSetters[vp] = setModel
	return vp
end

function UIKit.setViewportModel(vp: ViewportFrame, model: Model?)
	local setter = viewportSetters[vp]
	if setter then
		setter(model)
	end
end

return UIKit
]=])
print("✅ HATCH OR DIE Part 4/4 done. All done! Press Play to test, then File > Publish to Roblox.")
end
