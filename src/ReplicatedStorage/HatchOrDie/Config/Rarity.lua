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
