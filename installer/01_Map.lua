-- HATCH OR DIE - installer PART 1 of 4: MAP + TORCH
-- Paste everything into the Roblox Studio command bar (View > Command Bar) and press Enter.
-- Re-running rebuilds the map from scratch (it replaces Workspace.Map, terrain and the Torch).

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local rng = Random.new(1337)

local CAMP = Vector3.new(0, 0, 0)
local CABIN = Vector3.new(150, 0, 70)
local CAVE = Vector3.new(165, 0, -150)
local RUINS = Vector3.new(-160, 0, -130)
local ARENA = Vector3.new(0, 0, 190)
local HIDDEN = Vector3.new(-235, 0, 165)
local MAP_RADIUS = 265

-- Clean up previous installs and the default baseplate.
for _, name in { "Map", "Baseplate", "Enemies", "Creatures", "Effects", "WorldEggs" } do
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
-- Ground (terrain) + paths
---------------------------------------------------------------------------------------------------
workspace.Terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(640, 16, 640), Enum.Material.Grass)
workspace.Terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(80, 16, 80), Enum.Material.Ground)

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
while trees < 190 and attempts < 4000 do
	attempts += 1
	local p = randomRingPoint(44, MAP_RADIUS + 20)
	if isOpen(p, 0) then
		trees += 1
		local h = rng:NextNumber(12, 22)
		local d = rng:NextNumber(1.8, 3.2)
		column(forest, p, h, d, Color3.fromRGB(95, 70, 45), Enum.Material.Wood)
		local leaf = leafColors[rng:NextInteger(1, #leafColors)]
		local size = rng:NextNumber(9, 13)
		ball(forest, p + Vector3.new(0, h + 1, 0), size, leaf, Enum.Material.LeafyGrass).CanCollide = false
		ball(forest, p + Vector3.new(rng:NextNumber(-2, 2), h - 2.5, rng:NextNumber(-2, 2)), size * 0.85, leaf:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.LeafyGrass).CanCollide = false
	end
end
for _ = 1, 40 do
	local p = randomRingPoint(40, MAP_RADIUS)
	if isOpen(p, -4) then
		ball(forest, p + Vector3.new(0, 0.5, 0), rng:NextNumber(2.5, 6), Color3.fromRGB(115, 115, 120), Enum.Material.Slate)
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

print("✅ HATCH OR DIE Part 1/4 done: map + torch built. Now run Part 2.")
