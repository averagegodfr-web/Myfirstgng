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
