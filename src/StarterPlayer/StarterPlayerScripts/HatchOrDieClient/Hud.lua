-- Always-on HUD: phase banner + timer, objective, currencies, creature card, commands,
-- ability/feed buttons, menu bar, incubator timer, toasts, announcements, boss bar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)

local Hud = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local ctx
local refs = {}
local lastPhaseKey = ""
local bossState = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------------
local function buildPhaseBanner(gui: ScreenGui)
	local banner = UIKit.panel({
		Name = "PhaseBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(300, 62),
		Parent = gui,
	})
	refs.BannerGradient = UIKit.new("UIGradient", { Rotation = 90, Parent = banner })
	refs.PhaseTitle = UIKit.text({
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 4),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.3,
		Parent = banner,
	})
	refs.PhaseSub = UIKit.text({
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 38),
		TextColor3 = C.SubText,
		Parent = banner,
	})

	refs.Objective = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0.6, 0, 0, 22),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = C.Bg,
		TextColor3 = C.Text,
		Font = Enum.Font.GothamMedium,
		Parent = gui,
	})
	UIKit.corner(refs.Objective, 8)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 22), Parent = refs.Objective })
end

local function buildBossBar(gui: ScreenGui)
	local frame = UIKit.new("Frame", {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.7, 0, 0, 42),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 42), Parent = frame })
	refs.BossName = UIKit.text({
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 120, 90),
		TextStrokeTransparency = 0.2,
		Parent = frame,
	})
	local back, fill = UIKit.bar({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 18), Parent = frame }, Color3.fromRGB(220, 50, 50))
	UIKit.stroke(back, Color3.new(0, 0, 0), 2, 0.2)
	refs.BossFill = fill
	refs.BossFrame = frame
end

local function buildCurrencies(gui: ScreenGui)
	local panel = UIKit.panel({
		Name = "Currencies",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(150, 92),
		Parent = gui,
	})
	UIKit.padding(panel, 6)
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), Parent = panel })
	local function row(icon: string, color: Color3)
		return UIKit.text({
			Size = UDim2.new(1, 0, 0, 25),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Font = Enum.Font.FredokaOne,
			Text = icon .. " 0",
			Parent = panel,
		})
	end
	refs.Coins = row("🪙", C.Gold)
	refs.Berries = row("🍓", C.Berry)
	refs.Best = row("🏆", C.Text)
end

local function buildCreatureCard(gui: ScreenGui)
	local card = UIKit.panel({
		Name = "CreatureCard",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.45, 0),
		Size = UDim2.fromOffset(230, 128),
		Parent = gui,
	})
	UIKit.padding(card, 8)
	refs.CreatureName = UIKit.text({ Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	refs.CreatureStage = UIKit.text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local _, hpFill = UIKit.bar({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14), Parent = card }, C.Good)
	refs.CreatureHPFill = hpFill
	refs.CreatureHPText = UIKit.text({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14), TextStrokeTransparency = 0.2, Parent = card })
	local _, xpFill = UIKit.bar({ Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 10), Parent = card }, C.Accent)
	refs.CreatureXPFill = xpFill
	refs.CreatureXPText = UIKit.text({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	refs.EvolveButton = UIKit.button({
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = C.Gold,
		TextColor3 = Color3.fromRGB(40, 25, 0),
		Text = "✨ EVOLVE!",
		Visible = false,
		Parent = card,
	}, function()
		local profile = ctx.Profile
		if profile and profile.Equipped then
			ctx.Net.Get("EvolveCreature"):FireServer(profile.Equipped)
		end
	end)
	refs.CreatureCard = card
end

local function buildActions(gui: ScreenGui)
	local cluster = UIKit.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(250, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	refs.ModeButtons = {}
	local modes = { { "Follow", "1" }, { "Attack", "2" }, { "Defend", "3" } }
	for i, entry in modes do
		local mode, key = entry[1], entry[2]
		refs.ModeButtons[mode] = UIKit.button({
			Position = UDim2.new((i - 1) / 3, 2, 0, 0),
			Size = UDim2.new(1 / 3, -4, 0, 34),
			Text = ("%s [%s]"):format(mode, key),
			Parent = cluster,
		}, function()
			ctx.Net.Get("SetCommand"):FireServer(mode)
		end)
	end

	refs.FeedButton = UIKit.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, 0),
		Size = UDim2.fromOffset(92, 92),
		BackgroundColor3 = Color3.fromRGB(150, 50, 80),
		Text = "🍓\nFEED [F]",
		Parent = cluster,
	}, function()
		ctx.Net.Get("FeedCreature"):FireServer()
	end)

	refs.AbilityButton = UIKit.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = Color3.fromRGB(80, 60, 170),
		Text = "ABILITY\n[Q]",
		Parent = cluster,
	}, function()
		ctx.Net.Get("UseAbility"):FireServer()
	end)
	refs.AbilityButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	refs.AbilityCooldown = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = refs.AbilityButton,
	})
	UIKit.corner(refs.AbilityCooldown, 60)
end

local function buildMenu(gui: ScreenGui)
	local bar = UIKit.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(330, 58),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = bar,
	})
	local items = { { "Eggs", "🥚 Eggs" }, { "Creatures", "🐲 Creatures" }, { "Shop", "🛒 Shop" } }
	refs.MenuButtons = {}
	for _, item in items do
		refs.MenuButtons[item[1]] = UIKit.button({
			Size = UDim2.fromOffset(104, 54),
			BackgroundColor3 = C.Panel,
			Text = item[2],
			Parent = bar,
		}, function()
			ctx.Panels.Toggle(item[1])
		end)
	end
	refs.EggBadge = UIKit.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Bad,
		Font = Enum.Font.FredokaOne,
		Visible = false,
		ZIndex = 3,
		Parent = refs.MenuButtons.Eggs,
	})
	UIKit.corner(refs.EggBadge, 12)

	local incubator = UIKit.panel({
		Name = "Incubator",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(300, 46),
		Visible = false,
		Parent = gui,
	})
	refs.IncubatorText = UIKit.text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), Font = Enum.Font.FredokaOne, Parent = incubator })
	local _, fill = UIKit.bar({ Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 0, 10), Parent = incubator }, C.Gold)
	refs.IncubatorFill = fill
	refs.Incubator = incubator
end

local function buildMessages(gui: ScreenGui)
	refs.Toasts = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(320, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = refs.Toasts })

	refs.Announcement = UIKit.text({
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 152),
		Size = UDim2.new(0.8, 0, 0, 40),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.1,
		TextTransparency = 1,
		Parent = gui,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 38, Parent = refs.Announcement })

	refs.BigTitle = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0.8, 0, 0, 90),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Parent = gui,
	})
	refs.BigSub = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 62),
		Size = UDim2.new(0.6, 0, 0, 32),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0.2,
		TextTransparency = 1,
		Parent = gui,
	})

	local result = UIKit.panel({
		Name = "NightResult",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(360, 190),
		Visible = false,
		Parent = gui,
	})
	UIKit.padding(result, 12)
	refs.ResultTitle = UIKit.text({ Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.FredokaOne, Parent = result })
	refs.ResultBody = UIKit.text({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), TextScaled = false, TextSize = 20, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, Parent = result })
	refs.Result = result

	refs.DeathOverlay = UIKit.text({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(80, 0, 0),
		BackgroundTransparency = 0.55,
		Text = "💀 YOU FELL\nYou'll return at dawn... if anyone survives.",
		Font = Enum.Font.FredokaOne,
		Visible = false,
		ZIndex = 0,
		Parent = gui,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 40, Parent = refs.DeathOverlay })
end

---------------------------------------------------------------------------------------------------
-- Public messaging
---------------------------------------------------------------------------------------------------
function Hud.Toast(text: string, color: Color3?)
	local toast = UIKit.panel({
		Size = UDim2.fromOffset(320, 38),
		BackgroundColor3 = C.Bg,
		Parent = refs.Toasts,
	})
	local label = UIKit.text({
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 1, -6),
		Text = text,
		TextColor3 = color or C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = label })
	local toasts = refs.Toasts:GetChildren()
	local frames = {}
	for _, child in toasts do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 5 then
		frames[1]:Destroy()
	end
	task.delay(4.5, function()
		if toast.Parent then
			UIKit.tween(label, 0.4, { TextTransparency = 1 })
			UIKit.tween(toast, 0.4, { BackgroundTransparency = 1 })
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

local announceToken = 0
function Hud.Announce(text: string, color: Color3?, big: boolean?)
	announceToken += 1
	local token = announceToken
	local label = refs.Announcement
	label.Text = text
	label.TextColor3 = color or C.Gold
	label.Size = UDim2.new(0.8, 0, 0, if big then 54 else 38)
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.1
	if big then
		label.Rotation = -3
		UIKit.tween(label, 0.4, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	end
	task.delay(if big then 5 else 4, function()
		if announceToken == token then
			UIKit.tween(label, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local titleToken = 0
function Hud.BigTitle(title: string, sub: string, color: Color3)
	titleToken += 1
	local token = titleToken
	refs.BigTitle.Text = title
	refs.BigTitle.TextColor3 = color
	refs.BigSub.Text = sub
	refs.BigTitle.TextTransparency = 1
	refs.BigSub.TextTransparency = 1
	refs.BigTitle.Size = UDim2.new(0.8, 0, 0, 140)
	UIKit.tween(refs.BigTitle, 0.5, { TextTransparency = 0, Size = UDim2.new(0.8, 0, 0, 90) }, Enum.EasingStyle.Back)
	UIKit.tween(refs.BigSub, 0.8, { TextTransparency = 0 })
	task.delay(3, function()
		if titleToken == token then
			UIKit.tween(refs.BigTitle, 0.7, { TextTransparency = 1 })
			UIKit.tween(refs.BigSub, 0.7, { TextTransparency = 1 })
		end
	end)
end

function Hud.ShowNightResult(result)
	local lines = {}
	if result.Wipe then
		refs.ResultTitle.Text = ("☠️ NIGHT %d CLAIMED EVERYONE"):format(result.Night)
		refs.ResultTitle.TextColor3 = C.Bad
		table.insert(lines, "The run resets to Night 1.")
		table.insert(lines, "Your creatures, eggs and coins are safe.")
		table.insert(lines, "Evolve, hatch stronger eggs, and try again!")
	elseif result.Survived then
		refs.ResultTitle.Text = ("☀️ NIGHT %d SURVIVED!"):format(result.Night)
		refs.ResultTitle.TextColor3 = C.Gold
		table.insert(lines, ("🪙 +%d coins"):format(result.Coins or 0))
		table.insert(lines, ("✨ +%d creature XP"):format(result.XP or 0))
		table.insert(lines, ("🍓 +%d berries"):format(result.Berries or 0))
		for _, eggId in result.Eggs or {} do
			local egg = ctx.EggData[eggId]
			table.insert(lines, "🥚 " .. (if egg then egg.Name else eggId))
		end
	else
		refs.ResultTitle.Text = "💀 YOU FELL LAST NIGHT"
		refs.ResultTitle.TextColor3 = C.Bad
		table.insert(lines, "No rewards this time.")
		table.insert(lines, "Stay close to your creature and feed it when it's hurt.")
	end
	refs.ResultBody.Text = table.concat(lines, "\n")
	refs.Result.Visible = true
	refs.Result.Size = UDim2.fromOffset(300, 150)
	UIKit.tween(refs.Result, 0.35, { Size = UDim2.fromOffset(360, 190) }, Enum.EasingStyle.Back)
	task.delay(5, function()
		refs.Result.Visible = false
	end)
end

function Hud.SetBoss(data)
	bossState = data
	refs.BossFrame.Visible = data ~= nil
	if data then
		refs.BossName.Text = data.Name .. (if data.Enraged then "  🔥 ENRAGED" else "") .. (if data.Exposed then "  💥 CORE EXPOSED" else "")
		refs.BossFill.BackgroundColor3 = if data.Exposed then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(220, 50, 50)
		UIKit.tween(refs.BossFill, 0.15, { Size = UDim2.fromScale(math.clamp(data.Health / data.MaxHealth, 0, 1), 1) })
	end
end

---------------------------------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------------------------------
local function equippedRecord(profile)
	if not profile or not profile.Equipped then
		return nil
	end
	for _, record in profile.Creatures do
		if record.Id == profile.Equipped then
			return record
		end
	end
	return nil
end

local function objectiveText(profile): string
	if not profile then
		return "Loading..."
	end
	local phase = ctx.Root:GetAttribute("Phase")
	local record = equippedRecord(profile)
	if #profile.Creatures == 0 then
		if profile.Incubator then
			return "🥚 Your first egg is hatching... get ready!"
		elseif #profile.Eggs > 0 then
			return "🥚 Open Eggs and hatch an egg!"
		end
		return "🥚 Find an egg in the forest!"
	end
	if player:GetAttribute("CreatureKO") then
		return "💫 Your creature is down! Feed it a berry [F] to revive it"
	end
	if record and ctx.CreatureData.CanEvolve(record) then
		return "✨ Your creature can EVOLVE! Tap Evolve"
	end
	if phase == "Night" then
		if bossState then
			return "⚠️ Dodge the red zones! Hit the glowing core after a slam"
		end
		return "🌙 Survive until morning! Click enemies to send your creature"
	end
	local remaining = (ctx.Root:GetAttribute("PhaseEndsAt") or 0) - serverNow()
	if remaining < 12 then
		return "⚠️ Night is coming! Stay near camp and your creature"
	end
	if profile.Berries == 0 then
		return "🍓 Pick berries in the forest - they feed and heal your creature"
	end
	if profile.Incubator == nil and #profile.Eggs > 0 then
		return "🥚 You have an egg waiting - open Eggs to hatch it"
	end
	if record then
		local stage = ctx.CreatureData.Stages[record.Stage]
		if stage and stage.XPToEvolve and record.XP < stage.XPToEvolve then
			return "Feed your creature [F] and explore the Cave, Ruins and Cabin for eggs"
		end
	end
	return "Explore for eggs and crystals before nightfall"
end

function Hud.RefreshProfile()
	local profile = ctx.Profile
	if not profile then
		return
	end
	refs.Coins.Text = "🪙 " .. UIKit.formatNumber(profile.Coins)
	refs.Berries.Text = "🍓 " .. profile.Berries
	refs.Best.Text = "🏆 Best: Night " .. profile.HighestNight

	local eggCount = #profile.Eggs
	refs.EggBadge.Visible = eggCount > 0
	refs.EggBadge.Text = tostring(eggCount)

	local record = equippedRecord(profile)
	refs.CreatureCard.Visible = record ~= nil
	if record then
		local CD = ctx.CreatureData
		local rarity = CD.GetRarity(record)
		refs.CreatureName.Text = UIKit.FamilyIcons[record.Family] .. " " .. CD.GetDisplayName(record)
		refs.CreatureName.TextColor3 = ctx.Rarity.Colors[rarity]
		local stage = CD.Stages[record.Stage]
		refs.CreatureStage.Text = ("%s • %s • Stage %d/%d"):format(rarity, stage.Name, record.Stage, #CD.Stages)
		if stage.XPToEvolve then
			refs.CreatureXPFill.Size = UDim2.fromScale(math.clamp(record.XP / stage.XPToEvolve, 0, 1), 1)
			refs.CreatureXPText.Text = ("XP %d/%d • Nights %d/%d"):format(record.XP, stage.XPToEvolve, record.StageNights, stage.NightsToEvolve)
		else
			refs.CreatureXPFill.Size = UDim2.fromScale(1, 1)
			refs.CreatureXPText.Text = "MAX STAGE • " .. record.Nights .. " nights survived"
		end
		refs.EvolveButton.Visible = CD.CanEvolve(record)
	end
	refs.Objective.Text = objectiveText(profile)
end

local function refreshCreatureAttributes()
	local hp = player:GetAttribute("CreatureHP") or 0
	local maxHp = player:GetAttribute("CreatureMaxHP") or 1
	local ko = player:GetAttribute("CreatureKO")
	refs.CreatureHPFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	refs.CreatureHPFill.BackgroundColor3 = if ko then C.Bad elseif hp / maxHp < 0.35 then Color3.fromRGB(255, 170, 60) else C.Good
	refs.CreatureHPText.Text = if ko then "KNOCKED OUT" else ("%d / %d"):format(hp, maxHp)
	local mode = player:GetAttribute("CreatureMode") or "Attack"
	for name, button in refs.ModeButtons do
		button.BackgroundColor3 = if name == mode then Color3.fromRGB(70, 140, 255) else C.PanelLight
	end
	if ctx.Profile then
		refs.Objective.Text = objectiveText(ctx.Profile)
	end
end

local function refreshPhase()
	local root = ctx.Root
	local phase = root:GetAttribute("Phase") or "Day"
	local night = root:GetAttribute("Night") or 1
	local modifier = root:GetAttribute("Modifier") or "None"
	local isNight = phase == "Night"
	refs.PhaseTitle.Text = if isNight then ("🌙 NIGHT %d"):format(night) else ("☀️ DAY %d"):format(night)
	refs.PhaseTitle.TextColor3 = if isNight then Color3.fromRGB(200, 185, 255) else Color3.fromRGB(255, 225, 130)
	local top = if isNight then Color3.fromRGB(45, 30, 95) else Color3.fromRGB(70, 120, 170)
	if modifier == "BloodMoon" or modifier == "Nightmare" or modifier == "Apocalypse" then
		top = Color3.fromRGB(110, 20, 20)
	end
	refs.BannerGradient.Color = ColorSequence.new(top, C.Panel)

	local key = phase .. night
	if key ~= lastPhaseKey then
		local first = lastPhaseKey == ""
		lastPhaseKey = key
		if not first or isNight then
			if isNight then
				local sub = if modifier == "BloodMoon" then "🩸 BLOOD MOON - SURVIVE" else "SURVIVE UNTIL MORNING"
				Hud.BigTitle(("NIGHT %d"):format(night), sub, Color3.fromRGB(190, 170, 255))
			else
				Hud.BigTitle(("DAY %d"):format(night), "PREPARE FOR THE NIGHT", Color3.fromRGB(255, 220, 120))
			end
		end
		if not isNight then
			refs.DeathOverlay.Visible = false
		end
	end
end

local function tick()
	local root = ctx.Root
	local phase = root:GetAttribute("Phase") or "Day"
	local remaining = (root:GetAttribute("PhaseEndsAt") or 0) - serverNow()
	local label = if phase == "Night" then "SURVIVE" else "PREPARE"
	refs.PhaseSub.Text = ("%s • %s"):format(label, UIKit.formatTime(remaining))
	refs.PhaseSub.TextColor3 = if phase == "Day" and remaining < 12 then C.Bad else C.SubText

	local readyAt = player:GetAttribute("AbilityReadyAt") or 0
	local cooldown = readyAt - serverNow()
	local record = equippedRecord(ctx.Profile)
	local ability = record and ctx.CreatureData.Families[record.Family].Ability
	if ability then
		refs.AbilityCooldown.Size = UDim2.fromScale(1, math.clamp(cooldown / ability.Cooldown, 0, 1))
		refs.AbilityButton.Text = if cooldown > 0 then ("%s\n%ds"):format(ability.Name, math.ceil(cooldown)) else ability.Name .. "\n[Q]"
	else
		refs.AbilityCooldown.Size = UDim2.fromScale(1, 0)
		refs.AbilityButton.Text = "ABILITY\n[Q]"
	end
	refs.FeedButton.Text = ("🍓 FEED [F]\nx%d"):format(if ctx.Profile then ctx.Profile.Berries else 0)
	refs.Objective.Text = objectiveText(ctx.Profile)

	local incubator = ctx.Profile and ctx.Profile.Incubator
	refs.Incubator.Visible = incubator ~= nil
	if incubator then
		local egg = ctx.EggData[incubator.EggId]
		local total = math.max(0.1, incubator.EndsAt - incubator.StartedAt)
		local left = incubator.EndsAt - serverNow()
		refs.IncubatorText.Text = ("🥚 %s hatching... %s"):format(if egg then egg.Name else "Egg", UIKit.formatTime(left + 0.99))
		refs.IncubatorFill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
	end
end

function Hud.SetDead(dead: boolean)
	refs.DeathOverlay.Visible = dead
end

function Hud.Init(context)
	ctx = context
	local gui = ctx.Gui
	buildPhaseBanner(gui)
	buildBossBar(gui)
	buildCurrencies(gui)
	buildCreatureCard(gui)
	buildActions(gui)
	buildMenu(gui)
	buildMessages(gui)
	refs.CreatureCard.Visible = false

	for _, attr in { "Phase", "Night", "Modifier" } do
		ctx.Root:GetAttributeChangedSignal(attr):Connect(refreshPhase)
	end
	for _, attr in { "CreatureHP", "CreatureMaxHP", "CreatureKO", "CreatureMode" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshCreatureAttributes)
	end
	ctx.ProfileChanged:Connect(Hud.RefreshProfile)

	refreshPhase()
	refreshCreatureAttributes()

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
end

return Hud
