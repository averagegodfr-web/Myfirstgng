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
		Effects.Burst(Vector3.new(center.X, 1, center.Z), Color3.fromRGB(120, 90, 60), SLAM_RADIUS, 0.5, "BossSlam")
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
	local dir = if toTarget.Magnitude > 0.1 then toTarget.Unit else e.Facing
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
		Registry.EnemyService.Steer(e, Vector3.zero, nil, dt)
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
	local pos = e.Pos
	local goal = if target then target.Root.Position else arenaCenter
	local toGoal = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = toGoal.Magnitude
	local dir = if dist > 0.1 then toGoal / dist else e.Facing
	local move = if dist > 12 then dir * e.Speed * math.clamp((dist - 12) / 6, 0.3, 1) else Vector3.zero
	Registry.EnemyService.Steer(e, move, dir, dt)

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
	Effects.Burst(e.Root.Position, Color3.fromRGB(150, 255, 90), 30, 1.2, "BossDeath")
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
