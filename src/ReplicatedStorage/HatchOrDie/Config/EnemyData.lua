local EnemyData = {}

EnemyData.Types = {
	Crawler = {
		Name = "Crawler",
		Shape = "Crawler",
		Behavior = "Melee",
		Health = 38,
		Damage = 7,
		Speed = 17,
		AttackRange = 4.5,
		AttackCooldown = 1.0,
		Windup = 0,
		Coins = 3,
		XP = 7,
		UnlockNight = 1,
		Weight = 60,
		Color = Color3.fromRGB(55, 75, 40),
		EyeColor = Color3.fromRGB(255, 60, 60),
	},
	Hunter = {
		Name = "Hunter",
		Shape = "Hunter",
		Behavior = "Ranged",
		Health = 34,
		Damage = 9,
		Speed = 13,
		AttackRange = 48,
		PreferredRange = 30,
		AttackCooldown = 2.6,
		Windup = 0.8,
		ProjectileSpeed = 70,
		Coins = 5,
		XP = 10,
		UnlockNight = 3,
		Weight = 25,
		Color = Color3.fromRGB(45, 40, 60),
		EyeColor = Color3.fromRGB(255, 70, 220),
	},
	Brute = {
		Name = "Brute",
		Shape = "Brute",
		Behavior = "Melee",
		Health = 240,
		Damage = 26,
		Speed = 8.5,
		AttackRange = 8,
		SmashRadius = 8,
		AttackCooldown = 2.4,
		Windup = 1.0,
		Coins = 15,
		XP = 28,
		UnlockNight = 5,
		Weight = 15,
		Color = Color3.fromRGB(90, 60, 50),
		EyeColor = Color3.fromRGB(255, 150, 30),
	},
	RotwoodColossus = {
		Name = "Rotwood Colossus",
		Shape = "Colossus",
		Behavior = "Boss",
		IsBoss = true,
		Health = 3200,
		Damage = 30,
		Speed = 9,
		AttackRange = 18,
		AttackCooldown = 4.2,
		Windup = 1.3,
		Coins = 0,
		XP = 0,
		Color = Color3.fromRGB(85, 60, 40),
		EyeColor = Color3.fromRGB(140, 255, 90),
	},
}

EnemyData.Variants = {
	Normal = { HealthMult = 1, DamageMult = 1, SpeedMult = 1, RewardMult = 1, Scale = 1 },
	Elite = {
		HealthMult = 2.3,
		DamageMult = 1.5,
		SpeedMult = 1.12,
		RewardMult = 3,
		Scale = 1.3,
		Prefix = "Elite ",
		Tint = Color3.fromRGB(255, 200, 40),
	},
	Nightmare = {
		HealthMult = 3.2,
		DamageMult = 1.9,
		SpeedMult = 1.2,
		RewardMult = 5,
		Scale = 1.4,
		Prefix = "Nightmare ",
		Tint = Color3.fromRGB(210, 0, 45),
	},
}

-- One formula drives every night, so night 1 and night 100 use the same map and code.
function EnemyData.GetNightPlan(night: number, playerCount: number, rng: Random?)
	local n = math.max(1, night)
	local players = math.max(1, playerCount)
	local random = rng or Random.new()

	local plan = {
		Night = n,
		HealthMult = 1 + 0.16 * (n - 1),
		DamageMult = 1 + 0.09 * (n - 1),
		RewardMult = 1,
		TotalEnemies = math.floor((6 + n * 2.5) * (1 + 0.45 * (players - 1))),
		MaxAlive = math.min(10 + n * 2 + (players - 1) * 4, 40),
		EliteChance = if n >= 6 then math.min(0.04 * (n - 5), 0.4) else 0,
		NightmareChance = if n >= 50 then math.min(0.1 + 0.01 * (n - 50), 0.5) else 0,
		Boss = (n % 10 == 0) or n == 25,
		MiniBoss = n == 5,
		Modifier = "Night",
		Types = {},
	}

	if n >= 100 then
		plan.Modifier = "Apocalypse"
		plan.RewardMult = 2
	elseif n >= 50 then
		plan.Modifier = "Nightmare"
		plan.RewardMult = 1.5
	elseif n >= 4 and not plan.Boss and random:NextNumber() < 0.2 then
		plan.Modifier = "BloodMoon"
		plan.RewardMult = 1.5
		plan.TotalEnemies = math.floor(plan.TotalEnemies * 1.3)
		plan.EliteChance = math.max(plan.EliteChance, 0.1)
	end

	for id, data in EnemyData.Types do
		if not data.IsBoss and n >= data.UnlockNight then
			table.insert(plan.Types, { Id = id, Weight = data.Weight })
		end
	end
	table.sort(plan.Types, function(a, b)
		return a.Id < b.Id
	end)

	return plan
end

function EnemyData.PickType(plan, rng: Random): string
	local total = 0
	for _, t in plan.Types do
		total += t.Weight
	end
	local roll = rng:NextNumber() * total
	for _, t in plan.Types do
		roll -= t.Weight
		if roll <= 0 then
			return t.Id
		end
	end
	return plan.Types[1].Id
end

function EnemyData.PickVariant(plan, rng: Random): string
	local roll = rng:NextNumber()
	if roll < plan.NightmareChance then
		return "Nightmare"
	elseif roll < plan.NightmareChance + plan.EliteChance then
		return "Elite"
	end
	return "Normal"
end

return EnemyData
