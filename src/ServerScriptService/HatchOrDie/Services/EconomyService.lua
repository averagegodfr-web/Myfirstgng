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
