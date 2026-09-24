-- HATCH OR DIE - EXPORT ASSETS (optional): puts every creature, enemy, boss and egg model into
-- ReplicatedStorage.HatchOrDieAssets so you can edit or replace them, plus example effect templates.
-- Paste into the command bar after Parts 1-4. Re-running only adds what's missing (never overwrites).
--
--   HatchOrDieAssets
--   ├── Creatures/<Family>/Baby, Teen, Adult   (optional extras: "Adult_Celestial", "Teen_Storm", ...)
--   ├── Enemies/Crawler, Hunter, Brute, RotwoodColossus   (optional extras: "Brute_Elite", ...)
--   ├── Eggs/ForestEgg, EmberEgg, VoidEgg
--   ├── Effects/            <- templates in here are USED by the game (empty = built-in effects)
--   └── EffectExamples/     <- ready-made templates: drag any of them into Effects to activate + edit
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local source = ReplicatedStorage:FindFirstChild("HatchOrDie")

if not source then
	warn("❌ Run installer Part 2 (shared code) first.")
else
	-- Fresh copy so the command bar's require cache never serves old code.
	local fresh = source:Clone()
	local Models = require(fresh.Shared.Models)
	local CreatureData = require(fresh.Config.CreatureData)
	local EnemyData = require(fresh.Config.EnemyData)
	local EggData = require(fresh.Config.EggData)

	local added, kept = 0, 0
	local function folder(parent, name)
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end
	local function put(parent, name, build)
		if parent:FindFirstChild(name) then
			kept += 1
			return
		end
		local model = build()
		model.Name = name
		-- Anchored so you can drag it into Workspace to edit without it falling. The game unanchors it.
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		model.Parent = parent
		added += 1
	end

	local assets = folder(ReplicatedStorage, "HatchOrDieAssets")
	local creatures = folder(assets, "Creatures")
	for family in CreatureData.Families do
		local f = folder(creatures, family)
		for index, stage in CreatureData.Stages do
			put(f, stage.Name, function()
				return Models.Procedural.Creature({ Family = family, Stage = index })
			end)
		end
	end
	local enemies = folder(assets, "Enemies")
	for id in EnemyData.Types do
		put(enemies, id, function()
			return Models.Procedural.Enemy(id, "Normal")
		end)
	end
	local eggs = folder(assets, "Eggs")
	for id in EggData do
		put(eggs, id, function()
			return Models.Procedural.Egg(id)
		end)
	end
	folder(assets, "Effects")

	-- Example effect templates: an invisible part with particles (+ optional light / trail).
	local examples = folder(assets, "EffectExamples")
	local function kp(t, v)
		return NumberSequenceKeypoint.new(t, v)
	end
	local function effect(name, color, size, speed, opts)
		opts = opts or {}
		put(examples, name, function()
			local model = Instance.new("Model")
			local p = Instance.new("Part")
			p.Name = "Effect"
			p.Size = Vector3.new(1, 1, 1)
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Parent = model
			model.PrimaryPart = p
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.5))
			e.LightEmission = 1
			e.Size = NumberSequence.new({ kp(0, size), kp(1, 0) })
			e.Transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) })
			e.Lifetime = NumberRange.new(0.25, opts.life or 0.7)
			e.Speed = NumberRange.new(speed * 0.5, speed)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rate = opts.rate or 300
			e.Enabled = opts.projectile == true
			e.Parent = p
			if opts.light then
				local light = Instance.new("PointLight")
				light.Color = color
				light.Range = opts.light
				light.Brightness = 2
				light.Parent = p
			end
			if opts.projectile then
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.3, 0)
				a0.Parent = p
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -0.3, 0)
				a1.Parent = p
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Color = ColorSequence.new(color)
				trail.LightEmission = 1
				trail.Lifetime = 0.25
				trail.Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) })
				trail.Parent = p
			end
			model:SetAttribute("Lifetime", opts.lifetime or 1.5)
			model:SetAttribute("EmitDuration", opts.emit or 0.12)
			return model
		end)
	end

	effect("Hit", Color3.fromRGB(255, 255, 255), 0.6, 18, { rate = 200, emit = 0.08 })
	effect("Attack_Sprout", Color3.fromRGB(140, 230, 90), 0.9, 12)
	effect("Attack_Shade", Color3.fromRGB(175, 115, 255), 0.9, 14)
	effect("Attack_Crawler", Color3.fromRGB(255, 70, 70), 0.6, 10, { rate = 150 })
	effect("Projectile_Ember", Color3.fromRGB(255, 130, 40), 1.1, 2, { projectile = true, light = 10, rate = 60 })
	effect("Projectile_Hunter", Color3.fromRGB(255, 70, 220), 1.0, 2, { projectile = true, light = 10, rate = 60 })
	effect("Ability_Sprout", Color3.fromRGB(120, 255, 120), 2.2, 40, { rate = 600, light = 20 })
	effect("Ability_Ember", Color3.fromRGB(255, 120, 30), 2.4, 45, { rate = 600, light = 24 })
	effect("Ability_Shade", Color3.fromRGB(150, 80, 255), 1.8, 25, { rate = 500, light = 16 })
	effect("Smash_Brute", Color3.fromRGB(170, 130, 90), 2.5, 30, { rate = 400 })
	effect("EnemySpawn", Color3.fromRGB(110, 0, 160), 1.5, 6, { rate = 200, life = 1 })
	effect("EnemyDeath", Color3.fromRGB(60, 0, 80), 1.4, 16, { rate = 300 })
	effect("BossSpawn", Color3.fromRGB(100, 255, 90), 4, 50, { rate = 800, light = 40, lifetime = 3 })
	effect("BossSlam", Color3.fromRGB(150, 110, 70), 3.5, 60, { rate = 800 })
	effect("BossSpikes", Color3.fromRGB(110, 80, 50), 1.5, 12, { rate = 200 })
	effect("BossDeath", Color3.fromRGB(160, 255, 100), 5, 70, { rate = 1000, light = 50, lifetime = 3 })
	effect("TorchSwing", Color3.fromRGB(255, 160, 50), 0.8, 14, { rate = 250 })
	effect("Feed", Color3.fromRGB(255, 110, 150), 0.6, 6, { rate = 150 })
	effect("Evolve", Color3.fromRGB(255, 240, 180), 3, 40, { rate = 800, light = 30, lifetime = 2.5 })
	effect("Revive", Color3.fromRGB(120, 255, 140), 1.2, 10, { rate = 300 })
	effect("Knockout", Color3.fromRGB(255, 255, 255), 1.2, 12, { rate = 300 })

	game:GetService("Selection"):Set({ assets })
	print(("✅ Assets exported to ReplicatedStorage.HatchOrDieAssets (%d added, %d already there and kept)."):format(added, kept))
	print("✏️ Edit a model: drag it into Workspace, change it, drag it back. Or replace it with your own model of the same name.")
	print("✨ Effects: drag a template from EffectExamples into Effects to use it, then tweak its particles / add Sounds.")
end
