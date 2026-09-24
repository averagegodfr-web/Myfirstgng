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
