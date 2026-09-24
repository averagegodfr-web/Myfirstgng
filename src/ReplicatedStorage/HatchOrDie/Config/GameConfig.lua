-- Global tuning knobs. Change numbers here, not in services.
local GameConfig = {
	Version = "0.1.0",

	-- Day / night timing (seconds)
	FirstDayLength = 40,
	DayLength = 50,
	NightLength = 85,
	BossNightLength = 150,
	DayRespawnDelay = 4,
	WipeResetDelay = 7,

	-- Eggs
	StarterEgg = "ForestEgg",
	StarterHatchTime = 10,
	MaxEggs = 30,

	-- Creatures
	BaseCreatureSlots = 15,
	ExtraSlotsBonus = 25,
	CreatureMoveSpeed = 26,
	CreatureLeashDistance = 70,
	CreatureAggroRadius = 40,
	CreatureDefendRadius = 16,
	CreatureKORecoverTime = 25,
	EvolveMutationChance = 0.05,
	FeedXP = 20,
	FeedHealPercent = 0.35,
	FeedCooldown = 0.75,

	-- Player torch
	TorchDamage = 12,
	TorchRange = 10,
	TorchCooldown = 0.45,

	-- World
	GroundY = 0,
	BerryRegrowTime = 40,
	CrystalRegrowTime = 60,
	CrystalCoins = { 8, 15 },

	-- Enemies
	EnemyRetargetInterval = 0.5,
	EnemyAggroRadius = 90,

	-- Saving
	DataStoreName = "HatchOrDie_Players_v1",
	AutosaveInterval = 120,

	-- Optional audio. Paste rbxassetid:// ids to enable music.
	Music = { Day = "", Night = "", Boss = "" },
	Sounds = {
		Hatch = "rbxasset://sounds/electronicpingshort.wav",
		Swing = "rbxasset://sounds/swordslash.wav",
	},

	-- Monetization: create these in Creator Dashboard and paste the ids. 0 = disabled.
	Gamepasses = {
		VIP = 0,
		DoubleHatch = 0,
		AutoHatch = 0,
		ExtraSlots = 0,
	},
	Products = {
		EggPack = 0,
		GalaxyAura = 0,
	},
}

function GameConfig.NightReward(night: number)
	return {
		Coins = 25 + 12 * night,
		CreatureXP = 45 + 10 * night,
		Berries = 2,
	}
end

-- Eggs handed out at dawn for surviving a given night.
function GameConfig.NightEggRewards(night: number): { string }
	local eggs = {}
	if night % 3 == 0 then
		table.insert(eggs, "ForestEgg")
	end
	if night == 5 or night % 7 == 0 then
		table.insert(eggs, "EmberEgg")
	end
	return eggs
end

return GameConfig
