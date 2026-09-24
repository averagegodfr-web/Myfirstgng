-- Pool weights are relative. Odds are shown to players in the Eggs panel (required for paid random items).
local EggData = {
	ForestEgg = {
		Name = "Forest Egg",
		Rarity = "Common",
		HatchTime = 20,
		Price = 75,
		Order = 1,
		Color = Color3.fromRGB(125, 200, 95),
		SpotColor = Color3.fromRGB(95, 70, 45),
		NeonSpots = false,
		MutationChance = 0.02,
		Pool = {
			{ Family = "Sprout", Weight = 70 },
			{ Family = "Ember", Weight = 25 },
			{ Family = "Shade", Weight = 5 },
		},
	},
	EmberEgg = {
		Name = "Ember Egg",
		Rarity = "Rare",
		HatchTime = 40,
		Price = 350,
		Order = 2,
		Color = Color3.fromRGB(255, 125, 45),
		SpotColor = Color3.fromRGB(255, 225, 90),
		NeonSpots = true,
		MutationChance = 0.06,
		Pool = {
			{ Family = "Ember", Weight = 60 },
			{ Family = "Sprout", Weight = 25 },
			{ Family = "Shade", Weight = 15 },
		},
	},
	VoidEgg = {
		Name = "Void Egg",
		Rarity = "Legendary",
		HatchTime = 75,
		Price = 2000,
		Order = 3,
		Color = Color3.fromRGB(85, 40, 160),
		SpotColor = Color3.fromRGB(90, 255, 255),
		NeonSpots = true,
		MutationChance = 0.18,
		Pool = {
			{ Family = "Shade", Weight = 60 },
			{ Family = "Ember", Weight = 30 },
			{ Family = "Sprout", Weight = 10 },
		},
	},
}

return EggData
