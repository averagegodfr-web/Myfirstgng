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
