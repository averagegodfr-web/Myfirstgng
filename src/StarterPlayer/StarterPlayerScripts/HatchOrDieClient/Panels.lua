-- Modal menus: Eggs (with odds), Creatures (collection + evolve/equip/aura), Shop.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local UIKit = require(script.Parent.UIKit)

local Panels = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local ctx
local window: Frame
local titleLabel: TextLabel
local content: Frame
local windowSize: UDim2
local current: string? = nil
local selectedCreature: string? = nil
local shopTab = "Eggs"
local lastSignature = ""

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
end

local function scrolling(props): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in props do
		defaults[k] = v
	end
	return UIKit.new("ScrollingFrame", defaults)
end

local function oddsText(egg): string
	local total = 0
	for _, entry in egg.Pool do
		total += entry.Weight
	end
	local parts = {}
	for _, entry in egg.Pool do
		table.insert(parts, ("%s %s %.0f%%"):format(UIKit.FamilyIcons[entry.Family], entry.Family, entry.Weight / total * 100))
	end
	return table.concat(parts, "  ") .. ("\n🧬 Mutation chance %.0f%%"):format(egg.MutationChance * 100)
end

local function sortedEggIds(): { string }
	local ids = {}
	for id in ctx.EggData do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return ctx.EggData[a].Order < ctx.EggData[b].Order
	end)
	return ids
end

---------------------------------------------------------------------------------------------------
-- Eggs
---------------------------------------------------------------------------------------------------
local function renderEggs()
	local profile = ctx.Profile
	titleLabel.Text = ("🥚 EGGS (%d/%d)"):format(#profile.Eggs, ctx.GameConfig.MaxEggs)

	local status = UIKit.text({ Size = UDim2.new(1, 0, 0, 24), TextColor3 = C.SubText, Parent = content })
	if profile.Incubator then
		local egg = ctx.EggData[profile.Incubator.EggId]
		status.Text = ("Incubating: %s - watch the timer above the menu"):format(if egg then egg.Name else "Egg")
		status.TextColor3 = C.Gold
	else
		status.Text = "Your incubator is empty - pick an egg to hatch!"
	end

	local list = scrolling({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), Parent = content })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 250), CellPadding = UDim2.fromOffset(10, 10), Parent = list })

	local counts = {}
	local firstOf = {}
	for _, egg in profile.Eggs do
		counts[egg.EggId] = (counts[egg.EggId] or 0) + 1
		firstOf[egg.EggId] = firstOf[egg.EggId] or egg.Id
	end

	for _, eggId in sortedEggIds() do
		local egg = ctx.EggData[eggId]
		local count = counts[eggId] or 0
		local card = UIKit.panel({ BackgroundColor3 = C.PanelLight, Parent = list })
		UIKit.padding(card, 8)
		UIKit.viewport({ Size = UDim2.new(1, 0, 0, 80), Parent = card }, ctx.Models.BuildEgg(eggId), true)
		UIKit.text({ Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 22), Text = egg.Name, Font = Enum.Font.FredokaOne, TextColor3 = ctx.Rarity.Colors[egg.Rarity], Parent = card })
		UIKit.text({ Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 16), Text = ("%s • %ds • Owned x%d"):format(egg.Rarity, egg.HatchTime, count), TextColor3 = C.SubText, Parent = card })
		UIKit.text({ Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 0, 52), Text = oddsText(egg), TextColor3 = C.Text, Font = Enum.Font.Gotham, Parent = card })
		if count > 0 then
			UIKit.button({
				Position = UDim2.new(0, 0, 1, -40),
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = if profile.Incubator then C.PanelLight else Color3.fromRGB(70, 170, 90),
				Text = if profile.Incubator then "Incubator busy" else "HATCH",
				Parent = card,
			}, function()
				ctx.Net.Get("RequestHatch"):FireServer(firstOf[eggId])
			end)
		else
			UIKit.button({
				Position = UDim2.new(0, 0, 1, -40),
				Size = UDim2.new(1, 0, 0, 40),
				Text = ("Buy - 🪙 %d"):format(egg.Price),
				Parent = card,
			}, function()
				ctx.Net.Get("BuyItem"):FireServer(eggId)
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Creatures
---------------------------------------------------------------------------------------------------
local function findCreature(id: string?)
	if not id then
		return nil
	end
	for _, record in ctx.Profile.Creatures do
		if record.Id == id then
			return record
		end
	end
	return nil
end

local function totalDiscoverable(): number
	local CD = ctx.CreatureData
	local families = 0
	for _ in CD.Families do
		families += 1
	end
	return families * #CD.Stages * (1 + #CD.Mutations)
end

local function renderCreatureDetail(parent: Frame, record)
	local CD = ctx.CreatureData
	local profile = ctx.Profile
	local rarity = CD.GetRarity(record)
	local stats = CD.GetStats(record)
	local family = CD.Families[record.Family]
	local stage = CD.Stages[record.Stage]

	UIKit.viewport({ Size = UDim2.new(1, 0, 0, 150), Parent = parent }, ctx.Models.BuildCreature(record), true)
	UIKit.text({ Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 0, 26), Text = CD.GetDisplayName(record), Font = Enum.Font.FredokaOne, TextColor3 = ctx.Rarity.Colors[rarity], Parent = parent })
	UIKit.text({
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(1, 0, 0, 16),
		Text = ("%s • %s • %s"):format(rarity, stage.Name, if record.Mutation then "🧬 " .. record.Mutation else "No mutation"),
		TextColor3 = C.SubText,
		Parent = parent,
	})
	UIKit.text({
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.new(1, 0, 0, 34),
		Text = ("❤️ %d  ⚔️ %.1f  🎯 %.0f\n✨ %s"):format(stats.MaxHealth, stats.Damage, stats.Range, family.Ability.Name),
		Font = Enum.Font.Gotham,
		Parent = parent,
	})

	local nextText
	if stage.XPToEvolve then
		local nextRecord = table.clone(record)
		nextRecord.Stage += 1
		nextRecord.Mutation = nil
		local known = profile.Discovered[CD.DiscoveryKey(nextRecord)]
		local nextName = if known then CD.GetStageName(nextRecord) else "???"
		nextText = ("Next: %s  |  XP %d/%d  |  Nights %d/%d"):format(nextName, record.XP, stage.XPToEvolve, record.StageNights, stage.NightsToEvolve)
	else
		nextText = ("Fully evolved • %d nights survived"):format(record.Nights)
	end
	UIKit.text({ Position = UDim2.fromOffset(0, 232), Size = UDim2.new(1, 0, 0, 16), Text = nextText, TextColor3 = C.Accent, Parent = parent })

	local buttons = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 254), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = parent })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = buttons })
	local equipped = profile.Equipped == record.Id
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = if equipped then C.PanelLight else Color3.fromRGB(70, 140, 255), Text = if equipped then "Equipped" else "Equip", Parent = buttons }, function()
		ctx.Net.Get("EquipCreature"):FireServer(record.Id)
	end)
	local canEvolve = CD.CanEvolve(record)
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = if canEvolve then C.Gold else C.PanelLight, TextColor3 = if canEvolve then Color3.fromRGB(40, 25, 0) else C.SubText, Text = "Evolve", Parent = buttons }, function()
		ctx.Net.Get("EvolveCreature"):FireServer(record.Id)
	end)
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), Text = if record.Locked then "🔒 Locked" else "🔓 Lock", Parent = buttons }, function()
		ctx.Net.Get("ToggleLock"):FireServer(record.Id)
	end)
	UIKit.button({ Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Text = "Release", Parent = buttons }, function()
		ctx.Net.Get("ReleaseCreature"):FireServer(record.Id)
	end)

	if equipped then
		local auras = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 294), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = parent })
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = auras })
		UIKit.button({ Size = UDim2.fromOffset(60, 28), Text = "No aura", Parent = auras }, function()
			ctx.Net.Get("EquipAura"):FireServer("")
		end)
		for auraId, aura in ctx.CreatureData.Auras do
			local owned = profile.Auras[auraId] or (auraId == "Golden" and player:GetAttribute("Pass_VIP"))
			if owned then
				UIKit.button({ Size = UDim2.fromOffset(80, 28), BackgroundColor3 = aura.Color:Lerp(Color3.new(0, 0, 0), 0.4), Text = aura.Name:gsub(" Aura", ""), Parent = auras }, function()
					ctx.Net.Get("EquipAura"):FireServer(auraId)
				end)
			end
		end
	end
end

local function renderCreatures()
	local profile = ctx.Profile
	local CD = ctx.CreatureData
	local discovered = 0
	for _ in profile.Discovered do
		discovered += 1
	end
	titleLabel.Text = ("🐲 CREATURES (%d/%d) • Discovered %d/%d"):format(#profile.Creatures, ctx.SlotLimit(), discovered, totalDiscoverable())

	if #profile.Creatures == 0 then
		UIKit.text({ Size = UDim2.new(1, 0, 0, 40), Text = "No creatures yet - hatch an egg!", Parent = content })
		return
	end
	if not findCreature(selectedCreature) then
		selectedCreature = profile.Equipped or profile.Creatures[1].Id
	end

	local list = scrolling({ Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 74), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local sorted = table.clone(profile.Creatures)
	table.sort(sorted, function(a, b)
		if (a.Id == profile.Equipped) ~= (b.Id == profile.Equipped) then
			return a.Id == profile.Equipped
		end
		local ra, rb = ctx.Rarity.Rank[CD.GetRarity(a)], ctx.Rarity.Rank[CD.GetRarity(b)]
		if ra ~= rb then
			return ra > rb
		end
		return a.Stage > b.Stage
	end)

	for i, record in sorted do
		local rarity = CD.GetRarity(record)
		local selected = record.Id == selectedCreature
		local card = UIKit.button({
			LayoutOrder = i,
			BackgroundColor3 = if selected then ctx.Rarity.Colors[rarity]:Lerp(C.Panel, 0.55) else C.PanelLight,
			Text = "",
			Parent = list,
		}, function()
			selectedCreature = record.Id
			Panels.Render(true)
		end)
		card:FindFirstChildOfClass("UIStroke").Color = ctx.Rarity.Colors[rarity]
		UIKit.text({ Size = UDim2.new(1, 0, 0, 30), Text = UIKit.FamilyIcons[record.Family] .. (if record.Mutation then "🧬" else ""), Parent = card })
		UIKit.text({ Position = UDim2.fromOffset(2, 30), Size = UDim2.new(1, -4, 0, 24), Text = CD.GetDisplayName(record), TextColor3 = ctx.Rarity.Colors[rarity], Parent = card })
		local tags = (if record.Id == profile.Equipped then "⭐ " else "") .. (if record.Locked then "🔒 " else "") .. CD.Stages[record.Stage].Name
		UIKit.text({ Position = UDim2.fromOffset(2, 54), Size = UDim2.new(1, -4, 0, 16), Text = tags, TextColor3 = C.SubText, Parent = card })
	end

	local detail = UIKit.new("Frame", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = content })
	local record = findCreature(selectedCreature)
	if record then
		renderCreatureDetail(detail, record)
	end
end

---------------------------------------------------------------------------------------------------
-- Shop
---------------------------------------------------------------------------------------------------
local function shopRow(parent: Instance, name: string, description: string, priceText: string, buttonText: string, enabled: boolean, onBuy: () -> ())
	local row = UIKit.panel({ Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.PanelLight, Parent = parent })
	UIKit.text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(0.62, -10, 0, 24), Text = name, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	UIKit.text({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(0.62, -10, 0, 26), Text = description, TextColor3 = C.SubText, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 44),
		BackgroundColor3 = if enabled then Color3.fromRGB(70, 170, 90) else C.Panel,
		TextColor3 = if enabled then C.Text else C.SubText,
		Text = if buttonText ~= "" then buttonText else priceText,
		Parent = row,
	}, function()
		if enabled then
			onBuy()
		end
	end)
end

local function renderShop()
	local profile = ctx.Profile
	titleLabel.Text = ("🛒 SHOP • 🪙 %s"):format(UIKit.formatNumber(profile.Coins))

	local tabs = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = content })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabs })
	for _, category in ctx.ShopData.Categories do
		UIKit.button({
			Size = UDim2.new(0.25, -5, 1, 0),
			BackgroundColor3 = if category == shopTab then Color3.fromRGB(70, 140, 255) else C.PanelLight,
			Text = category,
			Parent = tabs,
		}, function()
			shopTab = category
			Panels.Render(true)
		end)
	end

	local list = scrolling({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42), Parent = content })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })

	if shopTab == "Robux" then
		for _, item in ctx.ShopData.Robux do
			local configTable = if item.Kind == "Gamepass" then ctx.GameConfig.Gamepasses else ctx.GameConfig.Products
			local id = configTable[item.ConfigKey] or 0
			local owned = item.Kind == "Gamepass" and player:GetAttribute("Pass_" .. item.ConfigKey)
			local buttonText = if owned then "Owned" elseif id == 0 then "Coming soon" else ""
			shopRow(list, item.Name, item.Description, ("R$ %d"):format(item.Robux), buttonText, id ~= 0 and not owned, function()
				if item.Kind == "Gamepass" then
					MarketplaceService:PromptGamePassPurchase(player, id)
				else
					MarketplaceService:PromptProductPurchase(player, id)
				end
			end)
		end
		UIKit.text({ Size = UDim2.new(1, -8, 0, 36), Text = "Robux items are convenience & cosmetics only. Everything that matters in a fight can be earned by playing.", TextColor3 = C.SubText, Font = Enum.Font.Gotham, Parent = list })
		return
	end

	for _, item in ctx.ShopData.Items do
		if item.Category == shopTab then
			local description = item.Description or ""
			local owned = false
			if item.Kind == "Egg" then
				description = oddsText(ctx.EggData[item.EggId]):gsub("\n", "  ")
			elseif item.Kind == "Aura" then
				owned = profile.Auras[item.AuraId] == true
				description = "Cosmetic only - particles + glow on your creature."
			end
			local affordable = profile.Coins >= item.Price
			local buttonText = if owned then "Owned" else ""
			shopRow(list, item.Name, description, ("🪙 %d"):format(item.Price), buttonText, affordable and not owned, function()
				ctx.Net.Get("BuyItem"):FireServer(item.Id)
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local RENDERERS = { Eggs = renderEggs, Creatures = renderCreatures, Shop = renderShop }

local function signature(): string
	local profile = ctx.Profile
	if not profile then
		return ""
	end
	local coins = if current == "Shop" then tostring(profile.Coins) else ""
	local parts = { current or "", coins, tostring(profile.Equipped), tostring(profile.Incubator ~= nil), tostring(#profile.Eggs) }
	for _, record in profile.Creatures do
		table.insert(parts, ("%s%d%s%s%s%d%d"):format(record.Id, record.Stage, tostring(record.Mutation), tostring(record.Locked), tostring(record.Aura), record.XP, record.StageNights))
	end
	for auraId in profile.Auras do
		table.insert(parts, auraId)
	end
	return table.concat(parts, "|")
end

function Panels.Render(force: boolean?)
	if not current or not ctx.Profile then
		return
	end
	local sig = signature()
	if not force and sig == lastSignature then
		return
	end
	lastSignature = sig
	clear()
	RENDERERS[current]()
end

function Panels.Open(name: string)
	if not RENDERERS[name] then
		return
	end
	current = name
	window.Visible = true
	window.Size = UIKit.scaleUDim2(windowSize, 0.94)
	UIKit.tween(window, 0.2, { Size = windowSize }, Enum.EasingStyle.Back)
	Panels.Render(true)
end

function Panels.Close()
	current = nil
	window.Visible = false
	clear()
end

function Panels.Toggle(name: string)
	if current == name then
		Panels.Close()
	else
		Panels.Open(name)
	end
end

function Panels.IsOpen(): boolean
	return current ~= nil
end

function Panels.Init(context)
	ctx = context
	local find = ctx.Layout.Finder(ctx.Gui)
	window = find("Window", "Frame")
	titleLabel = find("WindowTitle", "TextLabel")
	content = find("WindowContent", "Frame")
	local closeButton = find("WindowClose")
	UIKit.decorate(closeButton)
	closeButton.Activated:Connect(Panels.Close)
	windowSize = window.Size
	window.Visible = false

	ctx.ProfileChanged:Connect(function()
		Panels.Render(false)
	end)
end

return Panels
