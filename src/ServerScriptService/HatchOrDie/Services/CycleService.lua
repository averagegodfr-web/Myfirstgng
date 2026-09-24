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
