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
-- Bind: find every element by name (built-in Layout or the designer's StarterGui.HatchOrDieUI)
---------------------------------------------------------------------------------------------------
local baseSizes = {}
local modeColors = {}
local toastTemplate: GuiObject? = nil

local function bind(gui: ScreenGui)
	local find = ctx.Layout.Finder(gui)
	for _, name in {
		"PhaseBanner", "PhaseTitle", "PhaseSub", "Objective", "BossBar", "BossName", "BossFill",
		"Coins", "Berries", "Best", "CreatureCard", "CreatureName", "CreatureStage", "CreatureHPFill",
		"CreatureHPText", "CreatureXPFill", "CreatureXPText", "EvolveButton", "FeedButton", "AbilityButton",
		"AbilityCooldown", "EggBadge", "Incubator", "IncubatorText", "IncubatorFill", "Toasts",
		"Announcement", "BigTitle", "BigSub", "NightResult", "ResultTitle", "ResultBody", "DeathOverlay",
	} do
		refs[name] = find(name)
	end
	refs.BannerGradient = refs.PhaseBanner:FindFirstChildOfClass("UIGradient")
	refs.ModeButtons = {}
	for _, mode in { "Follow", "Attack", "Defend" } do
		local button = find("Mode" .. mode)
		refs.ModeButtons[mode] = button
		modeColors[button] = button.BackgroundColor3
	end
	refs.MenuButtons = {}
	for _, name in { "Eggs", "Creatures", "Shop" } do
		refs.MenuButtons[name] = find("Menu" .. name)
	end
	local template = gui:FindFirstChild("ToastTemplate", true)
	if template and template:IsA("GuiObject") then
		toastTemplate = template
		template.Visible = false
	end
	for _, name in { "Announcement", "BigTitle", "NightResult" } do
		baseSizes[name] = refs[name].Size
	end
	ctx.Layout.MakeResponsive(gui)

	-- Behavior
	local function onClick(button, fn)
		UIKit.decorate(button)
		button.Activated:Connect(fn)
	end
	onClick(refs.EvolveButton, function()
		local profile = ctx.Profile
		if profile and profile.Equipped then
			ctx.Net.Get("EvolveCreature"):FireServer(profile.Equipped)
		end
	end)
	for mode, button in refs.ModeButtons do
		onClick(button, function()
			ctx.Net.Get("SetCommand"):FireServer(mode)
		end)
	end
	onClick(refs.FeedButton, function()
		ctx.Net.Get("FeedCreature"):FireServer()
	end)
	onClick(refs.AbilityButton, function()
		ctx.Net.Get("UseAbility"):FireServer()
	end)
	for name, button in refs.MenuButtons do
		onClick(button, function()
			ctx.Panels.Toggle(name)
		end)
	end

	-- Start states (exported layouts are saved fully visible so they're easy to edit)
	refs.BossBar.Visible = false
	refs.CreatureCard.Visible = false
	refs.EvolveButton.Visible = false
	refs.EggBadge.Visible = false
	refs.Incubator.Visible = false
	refs.NightResult.Visible = false
	refs.DeathOverlay.Visible = false
	for _, name in { "Announcement", "BigTitle", "BigSub" } do
		refs[name].TextTransparency = 1
		refs[name].TextStrokeTransparency = 1
		refs[name].Visible = false
	end
	refs.AbilityCooldown.Visible = false
end

---------------------------------------------------------------------------------------------------
-- Public messaging
---------------------------------------------------------------------------------------------------
function Hud.Toast(text: string, color: Color3?)
	local toast, label
	if toastTemplate then
		toast = toastTemplate:Clone()
		toast.Visible = true
		label = toast:FindFirstChild("Label", true) or toast
		toast.Parent = refs.Toasts
	else
		toast = UIKit.panel({ Size = UDim2.fromScale(1, 0.19), BackgroundColor3 = C.Bg, Parent = refs.Toasts })
		label = UIKit.text({ Position = UDim2.fromScale(0.03, 0.12), Size = UDim2.fromScale(0.94, 0.76), TextXAlignment = Enum.TextXAlignment.Left, Parent = toast })
	end
	if label:IsA("TextLabel") or label:IsA("TextButton") then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
	local frames = {}
	for _, child in refs.Toasts:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(frames, child)
		end
	end
	if #frames > 4 then
		frames[1]:Destroy()
	end
	task.delay(4.5, function()
		if toast.Parent then
			for _, d in toast:GetDescendants() do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					UIKit.tween(d, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
				end
			end
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
	label.Size = if big then UIKit.scaleUDim2(baseSizes.Announcement, 1.35) else baseSizes.Announcement
	label.Visible = true
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
	refs.BigTitle.Size = UIKit.scaleUDim2(baseSizes.BigTitle, 1.5)
	UIKit.tween(refs.BigTitle, 0.5, { TextTransparency = 0, TextStrokeTransparency = 0, Size = baseSizes.BigTitle }, Enum.EasingStyle.Back)
	UIKit.tween(refs.BigSub, 0.8, { TextTransparency = 0, TextStrokeTransparency = 0.2 })
	task.delay(3, function()
		if titleToken == token then
			UIKit.tween(refs.BigTitle, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 })
			UIKit.tween(refs.BigSub, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 })
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
	refs.NightResult.Visible = true
	refs.NightResult.Size = UIKit.scaleUDim2(baseSizes.NightResult, 0.8)
	UIKit.tween(refs.NightResult, 0.35, { Size = baseSizes.NightResult }, Enum.EasingStyle.Back)
	task.delay(5, function()
		UIKit.tween(refs.NightResult, 0.25, { Size = UDim2.new() }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end)
end

function Hud.SetBoss(data)
	bossState = data
	refs.BossBar.Visible = data ~= nil
	if data then
		refs.BossName.Text = data.Name .. (if data.Enraged then "  🔥 ENRAGED" else "") .. (if data.Exposed then "  💥 CORE EXPOSED" else "")
		refs.BossFill.BackgroundColor3 = if data.Exposed then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(220, 50, 50)
		UIKit.setFill(refs.BossFill, data.Health / data.MaxHealth, 0.15)
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
			UIKit.setFill(refs.CreatureXPFill, record.XP / stage.XPToEvolve)
			refs.CreatureXPText.Text = ("XP %d/%d • Nights %d/%d"):format(record.XP, stage.XPToEvolve, record.StageNights, stage.NightsToEvolve)
		else
			UIKit.setFill(refs.CreatureXPFill, 1)
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
	UIKit.setFill(refs.CreatureHPFill, if ko then 0 else hp / maxHp)
	refs.CreatureHPFill.BackgroundColor3 = if ko then C.Bad elseif hp / maxHp < 0.35 then Color3.fromRGB(255, 170, 60) else C.Good
	refs.CreatureHPText.Text = if ko then "KNOCKED OUT" else ("%d / %d"):format(hp, maxHp)
	local mode = player:GetAttribute("CreatureMode") or "Attack"
	for name, button in refs.ModeButtons do
		local selected = button:GetAttribute("SelectedColor") or Color3.fromRGB(70, 140, 255)
		button.BackgroundColor3 = if name == mode then selected else modeColors[button]
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
	if refs.BannerGradient then
		refs.BannerGradient.Color = ColorSequence.new(top, C.Panel)
	end

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
		local left = math.clamp(cooldown / ability.Cooldown, 0, 1)
		refs.AbilityCooldown.Size = UDim2.fromScale(1, left)
		refs.AbilityCooldown.Visible = left > 0.001
		refs.AbilityButton.Text = if cooldown > 0 then ("%s\n%ds"):format(ability.Name, math.ceil(cooldown)) else ability.Name .. "\n[Q]"
	else
		refs.AbilityCooldown.Size = UDim2.fromScale(1, 0)
		refs.AbilityCooldown.Visible = false
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
		UIKit.setFill(refs.IncubatorFill, 1 - left / total)
	end
end

function Hud.SetDead(dead: boolean)
	refs.DeathOverlay.Visible = dead
end

function Hud.Init(context)
	ctx = context
	bind(ctx.Gui)

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
