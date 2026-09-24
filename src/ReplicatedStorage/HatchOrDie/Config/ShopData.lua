local ShopData = {}

ShopData.Categories = { "Eggs", "Boosts", "Cosmetics", "Robux" }

-- Coin shop. Robux items live in ShopData.Robux and are validated server-side via MarketplaceService.
ShopData.Items = {
	{ Id = "ForestEgg", Category = "Eggs", Kind = "Egg", EggId = "ForestEgg", Price = 75, Name = "Forest Egg" },
	{ Id = "EmberEgg", Category = "Eggs", Kind = "Egg", EggId = "EmberEgg", Price = 350, Name = "Ember Egg" },
	{ Id = "VoidEgg", Category = "Eggs", Kind = "Egg", EggId = "VoidEgg", Price = 2000, Name = "Void Egg" },
	{ Id = "Berries5", Category = "Boosts", Kind = "Berries", Amount = 5, Price = 30, Name = "5 Berries", Description = "Feed = XP + heal. Feeding a knocked-out creature revives it." },
	{ Id = "Berries20", Category = "Boosts", Kind = "Berries", Amount = 20, Price = 100, Name = "20 Berries", Description = "Bulk berries for long nights." },
	{ Id = "FireAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Fire", Price = 600, Name = "Fire Aura" },
	{ Id = "ToxicAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Toxic", Price = 900, Name = "Toxic Aura" },
	{ Id = "LightningAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Lightning", Price = 1200, Name = "Lightning Aura" },
	{ Id = "CrystalAura", Category = "Cosmetics", Kind = "Aura", AuraId = "Crystal", Price = 1800, Name = "Crystal Aura" },
}

ShopData.Robux = {
	{ Id = "VIP", Kind = "Gamepass", ConfigKey = "VIP", Robux = 299, Name = "VIP", Description = "VIP tag, Golden Aura, a free Forest Egg every dawn." },
	{ Id = "DoubleHatch", Kind = "Gamepass", ConfigKey = "DoubleHatch", Robux = 99, Name = "2x Hatch Speed", Description = "All eggs hatch twice as fast." },
	{ Id = "AutoHatch", Kind = "Gamepass", ConfigKey = "AutoHatch", Robux = 199, Name = "Auto Hatch", Description = "Your next egg starts incubating automatically." },
	{ Id = "ExtraSlots", Kind = "Gamepass", ConfigKey = "ExtraSlots", Robux = 79, Name = "+25 Creature Slots", Description = "Keep more of your collection." },
	{ Id = "EggPack", Kind = "Product", ConfigKey = "EggPack", Robux = 149, Name = "Ember Egg Pack", Description = "3 Ember Eggs + 200 coins." },
	{ Id = "GalaxyAura", Kind = "Product", ConfigKey = "GalaxyAura", Robux = 129, Name = "Galaxy Aura", Description = "Cosmetic only. Your creature shimmers with stars." },
}

ShopData.ById = {}
for _, item in ShopData.Items do
	ShopData.ById[item.Id] = item
end

return ShopData
