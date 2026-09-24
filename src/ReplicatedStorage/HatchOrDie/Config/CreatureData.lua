local Rarity = require(script.Parent.Rarity)

local CreatureData = {}

-- Stage requirements count XP and nights earned *at the current stage*.
CreatureData.Stages = {
	{ Name = "Baby", Scale = 1.0, StatMult = 1.0, XPToEvolve = 100, NightsToEvolve = 1 },
	{ Name = "Teen", Scale = 1.55, StatMult = 1.9, XPToEvolve = 450, NightsToEvolve = 3 },
	{ Name = "Adult", Scale = 2.2, StatMult = 3.3 },
}

CreatureData.Families = {
	Sprout = {
		Rarity = "Common",
		Names = { "Sproutling", "Thornback", "Elderwood Drake" },
		Body = "Lizard",
		Primary = Color3.fromRGB(110, 190, 80),
		Secondary = Color3.fromRGB(215, 235, 160),
		Accent = Color3.fromRGB(255, 120, 150),
		EyeColor = Color3.fromRGB(30, 30, 30),
		Stats = { Health = 140, Damage = 9, AttackRate = 1.1, Range = 7 },
		Ranged = false,
		Ability = { Name = "Thorn Burst", Kind = "Burst", Radius = 16, DamageMult = 2.5, HealOwner = 25, Cooldown = 12 },
		Description = "Tough and loyal. Heals you with Thorn Burst.",
	},
	Ember = {
		Rarity = "Rare",
		Names = { "Emberling", "Cinderfang", "Blaze Wyrm" },
		Body = "Fox",
		Primary = Color3.fromRGB(255, 115, 45),
		Secondary = Color3.fromRGB(255, 225, 190),
		Accent = Color3.fromRGB(255, 225, 80),
		EyeColor = Color3.fromRGB(40, 20, 10),
		Stats = { Health = 100, Damage = 12, AttackRate = 1.0, Range = 22 },
		Ranged = true,
		Ability = { Name = "Fire Nova", Kind = "Burst", Radius = 20, DamageMult = 2.2, Cooldown = 10 },
		Description = "Spits fireballs from range. Fire Nova scorches crowds.",
	},
	Shade = {
		Rarity = "Epic",
		Names = { "Shadeling", "Duskstalker", "Void Sovereign" },
		Body = "Wolf",
		Primary = Color3.fromRGB(75, 55, 125),
		Secondary = Color3.fromRGB(35, 25, 55),
		Accent = Color3.fromRGB(175, 115, 255),
		EyeColor = Color3.fromRGB(175, 115, 255),
		Stats = { Health = 120, Damage = 15, AttackRate = 1.25, Range = 8 },
		Ranged = false,
		Ability = { Name = "Shadow Pounce", Kind = "Pounce", Radius = 40, DamageMult = 4.5, Cooldown = 9 },
		Description = "A fast hunter. Shadow Pounce deletes a single target.",
	},
}

-- Mutations mostly change looks. StatBonus is deliberately small.
CreatureData.Mutations = {
	{ Id = "Storm", Name = "Storm", Weight = 30, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(120, 205, 255) },
	{ Id = "Inferno", Name = "Inferno", Weight = 28, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(255, 85, 20) },
	{ Id = "Crystal", Name = "Crystal", Weight = 20, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(165, 255, 255) },
	{ Id = "Plague", Name = "Plague", Weight = 14, Rarity = "Legendary", StatBonus = 0.10, Color = Color3.fromRGB(145, 255, 60) },
	{ Id = "Void", Name = "Void", Weight = 6, Rarity = "Mythic", StatBonus = 0.15, Color = Color3.fromRGB(95, 0, 170) },
	{ Id = "Rainbow", Name = "Rainbow", Weight = 1.6, Rarity = "Mythic", StatBonus = 0.15, Color = Color3.fromRGB(255, 255, 255) },
	{ Id = "Celestial", Name = "Celestial", Weight = 0.4, Rarity = "Mythic", StatBonus = 0.20, Color = Color3.fromRGB(255, 240, 190) },
}

CreatureData.MutationById = {}
do
	local total = 0
	for _, m in CreatureData.Mutations do
		total += m.Weight
	end
	for _, m in CreatureData.Mutations do
		m.Chance = m.Weight / total
		CreatureData.MutationById[m.Id] = m
	end
end

-- Auras are cosmetic only.
CreatureData.Auras = {
	Fire = { Name = "Fire Aura", Color = Color3.fromRGB(255, 120, 30), Order = 1 },
	Toxic = { Name = "Toxic Aura", Color = Color3.fromRGB(120, 255, 60), Order = 2 },
	Lightning = { Name = "Lightning Aura", Color = Color3.fromRGB(110, 200, 255), Order = 3 },
	Crystal = { Name = "Crystal Aura", Color = Color3.fromRGB(190, 255, 255), Order = 4 },
	Galaxy = { Name = "Galaxy Aura", Color = Color3.fromRGB(170, 90, 255), Order = 5, Robux = true },
	Golden = { Name = "Golden Aura", Color = Color3.fromRGB(255, 205, 60), Order = 6, VIP = true },
}

function CreatureData.RollMutation(rng: Random): string
	local roll = rng:NextNumber()
	local acc = 0
	for _, m in CreatureData.Mutations do
		acc += m.Chance
		if roll <= acc then
			return m.Id
		end
	end
	return CreatureData.Mutations[1].Id
end

function CreatureData.GetStageName(record): string
	local fam = CreatureData.Families[record.Family]
	return fam and fam.Names[record.Stage] or "???"
end

function CreatureData.GetDisplayName(record): string
	local base = CreatureData.GetStageName(record)
	if record.Mutation then
		return record.Mutation .. " " .. base
	end
	return base
end

function CreatureData.GetRarity(record): string
	local fam = CreatureData.Families[record.Family]
	local rarity = fam and fam.Rarity or "Common"
	local mut = record.Mutation and CreatureData.MutationById[record.Mutation]
	if mut then
		rarity = Rarity.Max(rarity, mut.Rarity)
	end
	return rarity
end

function CreatureData.GetStats(record)
	local fam = CreatureData.Families[record.Family]
	local stage = CreatureData.Stages[record.Stage] or CreatureData.Stages[1]
	local mut = record.Mutation and CreatureData.MutationById[record.Mutation]
	local mult = stage.StatMult * (1 + (mut and mut.StatBonus or 0))
	return {
		MaxHealth = math.floor(fam.Stats.Health * mult),
		Damage = math.floor(fam.Stats.Damage * mult * 10) / 10,
		AttackRate = fam.Stats.AttackRate,
		Range = fam.Stats.Range * (0.85 + 0.15 * record.Stage),
	}
end

function CreatureData.CanEvolve(record): (boolean, string?)
	local stage = CreatureData.Stages[record.Stage]
	if not stage or not stage.XPToEvolve then
		return false, "Already fully evolved"
	end
	if (record.XP or 0) < stage.XPToEvolve then
		return false, ("Needs %d more XP"):format(stage.XPToEvolve - (record.XP or 0))
	end
	if (record.StageNights or 0) < stage.NightsToEvolve then
		return false, ("Must survive %d more night(s)"):format(stage.NightsToEvolve - (record.StageNights or 0))
	end
	return true, nil
end

function CreatureData.DiscoveryKey(record): string
	return ("%s:%d:%s"):format(record.Family, record.Stage, record.Mutation or "Normal")
end

return CreatureData
