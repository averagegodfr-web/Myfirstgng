-- Owns creature records (in the profile) and the one active creature per player in the world.
-- Combat is semi-automatic: the creature picks targets itself; the player steers it with
-- Follow / Attack / Defend, tap-to-target, an ability, and feeding.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)
local Mover = require(script.Parent.Parent.Modules.Mover)
local Animate = require(script.Parent.Parent.Modules.Animate)

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

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
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
		local ratio = math.clamp(state.Health / state.MaxHealth, 0, 1)
		state.Bar.Size = UDim2.fromScale(ratio, 1)
		state.Bar.Visible = ratio > 0.001
	end
end

-- The nameplate hangs from an attachment just above the model's real top, and always draws on top.
local function makeNameplate(model: Model, record, top: number)
	local anchor = Instance.new("Attachment")
	anchor.Name = "NameplateAttachment"
	anchor.Position = Vector3.new(0, top + 0.6, 0)
	anchor.Parent = model.PrimaryPart

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(160, 38)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.AlwaysOnTop = true
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

	gui.Parent = model
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
	-- Move the WHOLE model (not just Root): welds lock their offsets when the model enters Workspace.
	model:PivotTo(CFrame.new(base.X, GameConfig.GroundY + hip, base.Z))
	local mover = Mover.Attach(model, GameConfig.CreatureResponsiveness)

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
		Mover = mover,
		Pos = flat(base),
		Vel = Vector3.zero,
		Facing = Vector3.new(0, 0, -1),
		Anim = Animate.Setup(model),
	}
	state.Bar = makeNameplate(model, record, top)
	model.Parent = folder
	Mover.Claim(mover)
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
	state.Model.Parent = folder
	local rootPart = ownerRoot(state.Player)
	if rootPart then
		state.Pos = flat(rootPart.Position + Vector3.new(3, 0, 3))
	end
	state.Vel = Vector3.zero
	Mover.Teleport(state.Mover, Vector3.new(state.Pos.X, GameConfig.GroundY + state.Hip, state.Pos.Z), state.Facing)
	Effects.Burst(state.Root.Position, Color3.fromRGB(120, 255, 140), 4, 0.5, "Revive")
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
		Effects.Burst(state.Root.Position, Color3.fromRGB(255, 255, 255), 4, 0.4, "Knockout")
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
			Effects.Burst(state.Root.Position, Color3.new(1, 1, 1), 10, 0.8, "Evolve")
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
	local family = state.Record.Family
	Animate.Play(state.Anim, "Attack")
	if state.Family.Ranged then
		local from = state.Root.Position + Vector3.new(0, state.Hip * 0.5, 0)
		local travel = Effects.Projectile(from, target.Root.Position, state.Family.Accent, 90, 0.9 * state.Scale, "Projectile_" .. family)
		task.delay(travel, function()
			Registry.EnemyService.Damage(target, damage, player)
		end)
	else
		local look = state.Root.CFrame.LookVector
		Effects.Burst(state.Root.Position + look * (state.Radius + 1), state.Family.Accent, 1.5 * state.Scale, 0.2, "Attack_" .. family)
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
	local effectName = "Ability_" .. state.Record.Family
	Animate.Play(state.Anim, "Ability")

	if ability.Kind == "Burst" then
		local center = state.Root.Position
		Effects.Burst(center, state.Family.Accent, ability.Radius, 0.5, effectName)
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
		-- Swoop: move the goal; the physics mover carries the creature there in a quick arc.
		state.Pos = flat(landing)
		state.Vel = Vector3.zero
		state.Facing = if dir.Magnitude > 0.1 then dir.Unit else state.Facing
		Mover.Set(state.Mover, Vector3.new(landing.X, GameConfig.GroundY + state.Hip + 2, landing.Z), state.Facing)
		Effects.Burst(landing, state.Family.Accent, 5, 0.4, effectName)
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

	local pos: Vector3 = state.Pos
	local ownerPos = flat(rootPart.Position)
	local target = if Registry.EnemyService.IsAlive(state.Target) then state.Target else nil
	local goal: Vector3? = nil
	local wantFace: Vector3? = nil

	if target then
		local tp = flat(target.Root.Position)
		local toTarget = tp - pos
		local reach = state.Stats.Range + target.Radius
		if toTarget.Magnitude > reach * 0.85 then
			goal = tp - toTarget.Unit * reach * 0.7
		end
		wantFace = toTarget
	else
		-- Follow like a pet: keep whatever side it's on, only walk when it drifts out of the comfort band.
		local offset = pos - ownerPos
		local d = offset.Magnitude
		local side = if d > 0.1 then offset / d else -flat(rootPart.CFrame.LookVector)
		if side.Magnitude < 0.01 then
			side = Vector3.new(0, 0, 1)
		end
		local followDist = GameConfig.CreatureFollowDistance + state.Radius
		if d > GameConfig.CreatureLeashDistance then
			state.Pos = ownerPos + side.Unit * followDist
			state.Vel = Vector3.zero
			Mover.Teleport(state.Mover, Vector3.new(state.Pos.X, GameConfig.GroundY + state.Hip, state.Pos.Z), state.Facing)
			return
		elseif d > followDist + 2.5 then
			goal = ownerPos + side.Unit * followDist
		elseif d < followDist * 0.45 then
			goal = ownerPos + side.Unit * followDist * 0.8
		end
		wantFace = ownerPos - pos
	end

	local desired = Vector3.zero
	if goal then
		local to = goal - pos
		local dist = to.Magnitude
		if dist > 0.4 then
			local speed = GameConfig.CreatureMoveSpeed * (if dist > 20 then 1.7 else 1) * math.clamp(dist / 6, 0.35, 1)
			desired = to / dist * speed
		end
	end
	state.Vel = state.Vel:Lerp(desired, math.clamp(dt * GameConfig.CreatureAcceleration, 0, 1))
	pos += state.Vel * dt
	state.Pos = pos

	local speed = state.Vel.Magnitude
	local faceGoal = if speed > 3 then state.Vel else wantFace
	if faceGoal and faceGoal.Magnitude > 0.1 then
		local blended = state.Facing:Lerp(faceGoal.Unit, math.clamp(dt * 8, 0, 1))
		state.Facing = if blended.Magnitude > 0.01 then blended.Unit else faceGoal.Unit
	end

	local moving01 = math.clamp(speed / GameConfig.CreatureMoveSpeed, 0, 1)
	state.Bob += dt * (4 + 10 * moving01)
	local hop = math.abs(math.sin(state.Bob)) * 0.35 * state.Scale * moving01 + math.sin(now * 2.2) * 0.06 * state.Scale
	Mover.Set(state.Mover, Vector3.new(pos.X, GameConfig.GroundY + state.Hip + hop, pos.Z), state.Facing)
	Animate.SetMoving(state.Anim, speed > 2)

	if target and now >= state.NextAttack then
		local d = flatDist(pos, target.Root.Position)
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
			Effects.Burst(state.Root.Position + Vector3.new(0, state.Hip, 0), Color3.fromRGB(255, 110, 150), 2, 0.4, "Feed")
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
