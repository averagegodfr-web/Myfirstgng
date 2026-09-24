--!nocheck
-- Headless smoke test: runs the real installers + server + client code in a fake engine.
-- Usage: lune run tools/sim/run.luau   (from the repo root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local sim = require("./fakeroblox")
local game = sim.game
sim.verbose = process.env.SIM_VERBOSE == "1"

local failures = 0
local function check(cond, label)
	if cond then
		print("  PASS  " .. label)
	else
		failures += 1
		print("  FAIL  " .. label)
	end
end

---------------------------------------------------------------------------------------------------
-- Script runner with per-side require caches
---------------------------------------------------------------------------------------------------
local function makeRequire()
	local cache = {}
	local function req(module)
		if cache[module] ~= nil then
			return cache[module]
		end
		assert(module.ClassName == "ModuleScript", "require on non-ModuleScript " .. tostring(module))
		local fn = luau.load(module.Source, { debugName = module:GetFullName(), environment = sim.makeEnv(module, req) })
		local result = fn()
		cache[module] = result
		return result
	end
	return req
end

local function runSource(source, name, scriptInstance, req)
	local fn = luau.load(source, { debugName = name, environment = sim.makeEnv(scriptInstance, req or makeRequire()) })
	sim.task.spawn(fn)
end

---------------------------------------------------------------------------------------------------
-- Remote routing (single test client)
---------------------------------------------------------------------------------------------------
local clientPlayer
local clientEvents = {}
sim.onFireServer = function(remote, ...)
	remote.OnServerEvent:Fire(clientPlayer, ...)
end
sim.onFireClient = function(remote, player, ...)
	if player == "ALL" or player == clientPlayer then
		clientEvents[remote.Name] = (clientEvents[remote.Name] or 0) + 1
		remote.OnClientEvent:Fire(...)
	end
end

---------------------------------------------------------------------------------------------------
print("== Installers")
-- Simulate a user's own models in ServerStorage.MapAssets (one tree with a sneaky script, one grass part).
do
	local roblox = require("@lune/roblox")
	local assets = sim.Instance.new("Folder")
	assets.Name = "mapassets"
	local trees = sim.Instance.new("Folder", assets)
	trees.Name = "Tree"
	local nested = sim.Instance.new("Folder", trees)
	nested.Name = "Pines"
	local tree = sim.Instance.new("Model", nested)
	tree.Name = "MyTree"
	local trunk = sim.Instance.new("Part", tree)
	trunk.Size = roblox.Vector3.new(2, 14, 2)
	trunk.CFrame = roblox.CFrame.new(50, 7, 50)
	sim.Instance.new("Script", tree).Name = "Virus"
	local grass = sim.Instance.new("Folder", assets)
	grass.Name = "Grass"
	local tuft = sim.Instance.new("Part", grass)
	tuft.Name = "Tuft"
	tuft.Size = roblox.Vector3.new(2, 1, 2)
	assets.Parent = game:GetService("ServerStorage")
end
for _, file in { "01_Map.lua", "02_Shared.lua", "03_Server.lua", "04_Client.lua" } do
	local before = #sim.errors
	runSource(fs.readFile("installer/" .. file), file, nil)
	check(#sim.errors == before, "installer " .. file .. " runs without errors")
end

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local map = sim.workspace:FindFirstChild("Map")
check(map ~= nil, "Workspace.Map exists")
check(map:FindFirstChild("CampCenter", true) ~= nil, "CampCenter exists")
check(map:FindFirstChild("BossArenaCenter", true) ~= nil, "BossArenaCenter exists")
check(#map.Resources:GetChildren() >= 20, "resources placed (" .. #map.Resources:GetChildren() .. ")")
check(#map.EggSpots:GetChildren() >= 15, "egg spots placed (" .. #map.EggSpots:GetChildren() .. ")")
check(#map.EnemySpawns:GetChildren() >= 10, "enemy spawns placed")
check(game:GetService("StarterPack"):FindFirstChild("Torch") ~= nil, "Torch tool in StarterPack")
check(sim.workspace:FindFirstChild("Baseplate") ~= nil, "studded Baseplate used as ground")
local customTrees, scripts, floating = 0, 0, 0
for _, m in map.Forest:GetChildren() do
	if m.Name == "MyTree" then
		customTrees += 1
		local box, size = m:GetBoundingBox()
		if math.abs(box.Position.Y - size.Y / 2) > 0.01 then
			floating += 1
		end
	end
end
for _, d in map:GetDescendants() do
	if d.ClassName == "Script" then
		scripts += 1
	end
end
check(customTrees > 100, ("user tree models used (%d placed)"):format(customTrees))
check(floating == 0, "user trees sit exactly on the ground")
check(scripts == 0, "scripts stripped from user models")
check(map:FindFirstChild("Grass") and #map.Grass:GetChildren() > 100 and map.Grass:GetChildren()[1]:FindFirstChildWhichIsA("BasePart").CanCollide == false, "user grass scattered, no collision")
check(RS.HatchOrDie.Config.GameConfig.ClassName == "ModuleScript", "shared modules installed")
check(SSS.HatchOrDie.ClassName == "Script" and SSS.HatchOrDie.Services.CycleService ~= nil, "server script installed")
check(SPS.HatchOrDieClient.ClassName == "LocalScript" and SPS.HatchOrDieClient.Hud ~= nil, "client script installed")

-- Installed Source must match src/ exactly.
check(fs.readFile("src/ServerScriptService/HatchOrDie/Services/CycleService.lua") == SSS.HatchOrDie.Services.CycleService.Source, "installed source matches src/")

---------------------------------------------------------------------------------------------------
print("== Model builders (every family x stage x mutation, every enemy, every egg)")
do
	local req = makeRequire()
	local Models = req(RS.HatchOrDie.Shared.Models)
	local CreatureData = req(RS.HatchOrDie.Config.CreatureData)
	local EnemyData = req(RS.HatchOrDie.Config.EnemyData)
	local EggData = req(RS.HatchOrDie.Config.EggData)
	local built = 0
	for family in CreatureData.Families do
		for stage = 1, #CreatureData.Stages do
			for _, mutation in { false, "Storm", "Inferno", "Crystal", "Plague", "Void", "Rainbow", "Celestial" } do
				local record = { Family = family, Stage = stage, Mutation = mutation or nil, Aura = "Fire", XP = 0, StageNights = 0 }
				local model = Models.BuildCreature(record)
				assert(model.PrimaryPart and model:GetAttribute("HipHeight") > 0 and model:GetAttribute("Top") > 0)
				CreatureData.GetStats(record)
				CreatureData.GetDisplayName(record)
				built += 1
			end
		end
	end
	for typeId in EnemyData.Types do
		for variant in EnemyData.Variants do
			local model = Models.BuildEnemy(typeId, variant)
			assert(model.PrimaryPart and model:GetAttribute("Radius") > 0)
			built += 1
		end
	end
	for eggId in EggData do
		Models.BuildEgg(eggId)
		built += 1
	end
	check(#sim.errors == 0, ("built %d models without errors"):format(built))

	local plan1 = EnemyData.GetNightPlan(1, 1)
	local plan10 = EnemyData.GetNightPlan(10, 1)
	check(#plan1.Types == 1 and plan1.Types[1].Id == "Crawler", "night 1 only spawns Crawlers")
	check(plan10.Boss and #plan10.Types == 3, "night 10 is a boss night with all 3 enemy types")
	print(("        night 1: %d enemies | night 5: %d | night 10: %d (hp x%.2f)"):format(plan1.TotalEnemies, EnemyData.GetNightPlan(5, 1).TotalEnemies, plan10.TotalEnemies, plan10.HealthMult))
end

---------------------------------------------------------------------------------------------------
print("== Server boot + first join")
local serverRequire = makeRequire()
runSource(SSS.HatchOrDie.Source, "HatchOrDie(server)", SSS.HatchOrDie, serverRequire)
sim.run(0.5)
check(#sim.errors == 0, "server boots without errors")

local Registry = serverRequire(SSS.HatchOrDie.Registry)
local DataService = Registry.DataService

clientPlayer = sim.addPlayer("Tester")
game:GetService("Players").LocalPlayer = clientPlayer
sim.run(0.5)
local profile = DataService.GetProfile(clientPlayer)
check(profile ~= nil, "profile loaded")
check(clientPlayer.Character ~= nil, "character spawned by server (CharacterAutoLoads off)")
check(profile.Incubator ~= nil, "starter egg is incubating immediately")

runSource(SPS.HatchOrDieClient.Source, "HatchOrDieClient", SPS.HatchOrDieClient, makeRequire())
sim.run(0.5)
check(#sim.errors == 0, "client boots without errors")
check(clientPlayer.PlayerGui:FindFirstChild("HatchOrDieUI") ~= nil, "HUD created")

sim.run(12)
check(#profile.Creatures == 1, "first creature hatched within ~12s")
check(profile.Equipped ~= nil, "first creature auto-equipped")
check((clientEvents.HatchResult or 0) == 1, "client received hatch reveal")
check(#sim.workspace.Creatures:GetChildren() == 1, "creature model in world")
check(RS.HatchOrDie:GetAttribute("Phase") == "Day", "phase is Day")

-- Give the player a torch and make them sturdy so we can observe full nights.
local character = clientPlayer.Character
character.Humanoid.MaxHealth = 1e6
character.Humanoid.Health = 1e6
local torch = clientPlayer.Backpack:FindFirstChild("Torch")
torch.Parent = character

local function swingFor(seconds)
	local t = 0
	while t < seconds do
		local tool = clientPlayer.Character and clientPlayer.Character:FindFirstChild("Torch")
		if tool then
			tool.Activated:Fire()
		end
		sim.run(0.5)
		t += 0.5
	end
end

-- Pick berries at the nearest bush via its ProximityPrompt, then feed.
local bush = map.Resources:FindFirstChild("BerryBush")
local prompt = bush.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
check(prompt ~= nil, "berry bush has a prompt")
local berriesBefore = profile.Berries
prompt.Triggered:Fire(clientPlayer)
sim.run(0.2)
check(profile.Berries > berriesBefore, "picking berries adds berries")
local xpBefore = profile.Creatures[1].XP
game:GetService("ReplicatedStorage").HatchOrDie.Remotes.FeedCreature:FireServer()
sim.run(0.2)
check(profile.Creatures[1].XP == xpBefore + 20, "feeding gives creature XP")

-- World eggs spawn during the day.
check(#sim.workspace.WorldEggs:GetChildren() >= 1, "world eggs spawned for the day")

---------------------------------------------------------------------------------------------------
print("== Night 1")
sim.run(45)
check(RS.HatchOrDie:GetAttribute("Phase") == "Night", "night falls after the day timer")
swingFor(20)
check(#sim.workspace.Enemies:GetChildren() > 0 or profile.Stats.Kills > 0, "enemies spawned at night")
swingFor(75)
check(RS.HatchOrDie:GetAttribute("Phase") == "Day" and RS.HatchOrDie:GetAttribute("Night") == 2, "survived to Day 2")
check(profile.HighestNight == 1, "HighestNight recorded")
check(profile.Stats.Kills > 0, ("kills recorded (%d)"):format(profile.Stats.Kills))
check((clientEvents.NightResult or 0) >= 1, "night result shown")
print(("        coins=%d berries=%d creatureXP=%d stageNights=%d"):format(profile.Coins, profile.Berries, profile.Creatures[1].XP, profile.Creatures[1].StageNights))

---------------------------------------------------------------------------------------------------
print("== Evolution")
local CreatureData = serverRequire(RS.HatchOrDie.Config.CreatureData)
local creature = profile.Creatures[1]
print("        evolve-ready right after night 1 without extra feeding: " .. tostring(CreatureData.CanEvolve(creature)))
if not CreatureData.CanEvolve(creature) then
	profile.Berries += 10
	for _ = 1, 6 do
		RS.HatchOrDie.Remotes.FeedCreature:FireServer()
		sim.run(1)
	end
end
check(CreatureData.CanEvolve(creature), "creature can evolve after night 1 + feeding")
RS.HatchOrDie.Remotes.EvolveCreature:FireServer(creature.Id)
sim.run(1)
check(creature.Stage == 2, "evolved to stage 2")
check((clientEvents.Evolved or 0) == 1, "client received evolution reveal")

---------------------------------------------------------------------------------------------------
print("== Shop + exploit checks")
profile.Coins = 1000
RS.HatchOrDie.Remotes.BuyItem:FireServer("EmberEgg")
sim.run(0.5)
check(profile.Coins == 650, "coin purchase deducts server-side price")
RS.HatchOrDie.Remotes.BuyItem:FireServer({ Id = "VoidEgg", Price = 0 })
RS.HatchOrDie.Remotes.BuyItem:FireServer("NotAnItem")
RS.HatchOrDie.Remotes.EvolveCreature:FireServer(12345)
RS.HatchOrDie.Remotes.RequestHatch:FireServer(nil)
RS.HatchOrDie.Remotes.SetCommand:FireServer("Explode")
RS.HatchOrDie.Remotes.EquipAura:FireServer("Galaxy")
sim.run(1)
check(profile.Coins == 650 and creature.Aura == nil, "malformed / unowned requests are ignored")
local emberEgg
for _, egg in profile.Eggs do
	if egg.EggId == "EmberEgg" then
		emberEgg = egg
	end
end
check(emberEgg ~= nil, "bought egg in inventory")

---------------------------------------------------------------------------------------------------
print("== Save / reload")
local userId = clientPlayer.UserId
sim.removePlayer(clientPlayer)
sim.run(1)
local saved = sim.datastore["P_" .. userId]
check(saved and saved.Data and #saved.Data.Creatures == 1 and saved.Lock == nil, "profile saved and session lock released on leave")
clientPlayer = sim.addPlayer("Returner", userId)
game:GetService("Players").LocalPlayer = clientPlayer
sim.run(1)
local reloaded = DataService.GetProfile(clientPlayer)
check(reloaded and #reloaded.Creatures == 1 and reloaded.Creatures[1].Stage == 2 and reloaded.HighestNight == 1, "progress restored on rejoin")
check(sim.datastore["P_" .. userId].Lock ~= nil, "session lock taken on join")

print("== Long run to the boss (nights 2-10)")
profile = DataService.GetProfile(clientPlayer)
check(profile ~= nil, "second player loaded")
local function sturdy()
	local c = clientPlayer.Character
	if c and c.Humanoid.MaxHealth < 1e6 then
		c.Humanoid.MaxHealth = 1e6
		c.Humanoid.Health = 1e6
		local t = clientPlayer.Backpack:FindFirstChild("Torch")
		if t then
			t.Parent = c
		end
	end
end
local sawBoss = false
local sawBossBar = false
local lastNight = RS.HatchOrDie:GetAttribute("Night")
for _ = 1, 3000 do
	sturdy()
	local tool = clientPlayer.Character and clientPlayer.Character:FindFirstChild("Torch")
	if tool then
		tool.Activated:Fire()
	end
	sim.run(0.5)
	if Registry.BossService.IsActive() then
		sawBoss = true
		-- stand next to the boss and burn it
		for _, e in Registry.EnemyService.GetAll() do
			if e.Data.IsBoss then
				clientPlayer.Character.HumanoidRootPart.CFrame = e.Root.CFrame * require("@lune/roblox").CFrame.new(0, 0, -8)
			end
		end
	end
	if (clientEvents.BossBar or 0) > 0 then
		sawBossBar = true
	end
	if RS.HatchOrDie:GetAttribute("Night") ~= lastNight then
		lastNight = RS.HatchOrDie:GetAttribute("Night")
	end
	if lastNight >= 11 then
		break
	end
end
check(sawBoss, "boss spawned on night 10")
check(sawBossBar, "boss bar sent to client")
check(lastNight >= 11, "reached Day 11")
print(("        highest night=%d bosses=%d coins=%d eggs=%d kills=%d"):format(profile.HighestNight, profile.BossesDefeated, profile.Coins, #profile.Eggs, profile.Stats.Kills))

---------------------------------------------------------------------------------------------------
print("== Wipe resets the run")
clientPlayer.Character.Humanoid.MaxHealth = 100
while RS.HatchOrDie:GetAttribute("Phase") ~= "Night" do
	sim.run(1)
end
clientPlayer.Character.Humanoid.Health = 0
sim.run(15)
check(RS.HatchOrDie:GetAttribute("Night") == 1, "everyone down at night -> back to Night 1")
check(clientPlayer.Character and clientPlayer.Character.Humanoid.Health > 0, "player respawned after wipe")

---------------------------------------------------------------------------------------------------
print("== Shutdown save")
sim.task.spawn(sim.bindToClose)
sim.run(2)
check(sim.datastore["P_" .. clientPlayer.UserId].Data.HighestNight >= 10, "BindToClose saved progress")

local invalid = {}
for name in sim.invalidProperties do
	table.insert(invalid, name)
end
table.sort(invalid)
check(#invalid == 0, "every property written exists in the real Roblox API" .. (if #invalid > 0 then ": " .. table.concat(invalid, ", ") else ""))

print("")
print(("Errors: %d  Warnings: %d  Failed checks: %d"):format(#sim.errors, #sim.warnings, failures))
for _, w in sim.warnings do
	print("  warn: " .. w)
end
if #sim.errors > 0 or failures > 0 then
	process.exit(1)
end
