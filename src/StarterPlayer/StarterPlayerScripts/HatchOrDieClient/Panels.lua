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

-- Menus are sized from the window's real pixel size so cards fit phones, tablets and PCs.
local function contentSize(): Vector2
	local abs = content.AbsoluteSize
	if abs and abs.X > 50 and abs.Y > 50 then
		return abs
	end
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return Vector2.new(math.min(viewport.X * 0.85, 1050), math.min(viewport.Y * 0.68, 620))
end

-- Grid whose columns adapt to the available width. heightRatio = cell height / cell width.
local function grid(list: Instance, width: number, minCellWidth: number, heightRatio: number, sortOrder: Enum.SortOrder?)
	local pad = math.max(4, math.floor(width * 0.012))
	local columns = math.max(1, math.floor((width + pad) / (minCellWidth + pad)))
	local cellWidth = math.floor((width - 10 - pad * (columns - 1)) / columns)
	return UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * heightRatio)),
		CellPadding = UDim2.fromOffset(pad, pad),
		SortOrder = sortOrder or Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
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

	local size = contentSize()
	local status = UIKit.text({ Size = UDim2.fromScale(1, 0.07), TextColor3 = C.SubText, Parent = content })
	if profile.Incubator then
		local egg = ctx.EggData[profile.Incubator.EggId]
		status.Text = ("Incubating: %s - watch the timer above the menu"):format(if egg then egg.Name else "Egg")
		status.TextColor3 = C.Gold
	else
		status.Text = "Your incubator is empty - pick an egg to hatch!"
	end

	local list = scrolling({ Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.92), Parent = content })
	grid(list, size.X, 170, 1.3)

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
		UIKit.viewport({ Size = UDim2.fromScale(1, 0.3), Parent = card }, ctx.Models.BuildEgg(eggId), true)
		UIKit.text({ Position = UDim2.fromScale(0, 0.31), Size = UDim2.fromScale(1, 0.1), Text = egg.Name, Font = Enum.Font.FredokaOne, TextColor3 = ctx.Rarity.Colors[egg.Rarity], Parent = card })
		UIKit.text({ Position = UDim2.fromScale(0, 0.42), Size = UDim2.fromScale(1, 0.07), Text = ("%s • %ds • Owned x%d"):format(egg.Rarity, egg.HatchTime, count), TextColor3 = C.SubText, Parent = card })
		UIKit.text({ Position = UDim2.fromScale(0, 0.51), Size = UDim2.fromScale(1, 0.28), Text = oddsText(egg), TextColor3 = C.Text, Font = Enum.Font.Gotham, Parent = card })
		if count > 0 then
			UIKit.button({
				Position = UDim2.fromScale(0, 0.82),
				Size = UDim2.fromScale(1, 0.18),
				BackgroundColor3 = if profile.Incubator then C.PanelLight else Color3.fromRGB(70, 170, 90),
				Text = if profile.Incubator then "Incubator busy" else "HATCH",
				Parent = card,
			}, function()
				ctx.Net.Get("RequestHatch"):FireServer(firstOf[eggId])
			end)
		else
			UIKit.button({
				Position = UDim2.fromScale(0, 0.82),
				Size = UDim2.fromScale(1, 0.18),
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

	UIKit.viewport({ Size = UDim2.fromScale(1, 0.4), Parent = parent }, ctx.Models.BuildCreature(record), true)
	UIKit.text({ Position = UDim2.fromScale(0, 0.41), Size = UDim2.fromScale(1, 0.075), Text = CD.GetDisplayName(record), Font = Enum.Font.FredokaOne, TextColor3 = ctx.Rarity.Colors[rarity], Parent = parent })
	UIKit.text({
		Position = UDim2.fromScale(0, 0.49),
		Size = UDim2.fromScale(1, 0.045),
		Text = ("%s • %s • %s"):format(rarity, stage.Name, if record.Mutation then "🧬 " .. record.Mutation else "No mutation"),
		TextColor3 = C.SubText,
		Parent = parent,
	})
	UIKit.text({
		Position = UDim2.fromScale(0, 0.54),
		Size = UDim2.fromScale(1, 0.09),
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
	UIKit.text({ Position = UDim2.fromScale(0, 0.64), Size = UDim2.fromScale(1, 0.045), Text = nextText, TextColor3 = C.Accent, Parent = parent })

	local buttons = UIKit.new("Frame", { Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.1), BackgroundTransparency = 1, Parent = parent })
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
		local auras = UIKit.new("Frame", { Position = UDim2.fromScale(0, 0.82), Size = UDim2.fromScale(1, 0.18), BackgroundTransparency = 1, Parent = parent })
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromScale(0.235, 0.45), CellPadding = UDim2.fromScale(0.02, 0.08), Parent = auras })
		UIKit.button({ Text = "No aura", Parent = auras }, function()
			ctx.Net.Get("EquipAura"):FireServer("")
		end)
		for auraId, aura in ctx.CreatureData.Auras do
			local owned = profile.Auras[auraId] or (auraId == "Golden" and player:GetAttribute("Pass_VIP"))
			if owned then
				UIKit.button({ BackgroundColor3 = aura.Color:Lerp(Color3.new(0, 0, 0), 0.4), Text = aura.Name:gsub(" Aura", ""), Parent = auras }, function()
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
		UIKit.text({ Size = UDim2.fromScale(1, 0.1), Text = "No creatures yet - hatch an egg!", Parent = content })
		return
	end
	if not findCreature(selectedCreature) then
		selectedCreature = profile.Equipped or profile.Creatures[1].Id
	end

	local list = scrolling({ Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	grid(list, contentSize().X * 0.5 - 6, 95, 0.75)

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
		UIKit.text({ Size = UDim2.fromScale(1, 0.4), Text = UIKit.FamilyIcons[record.Family] .. (if record.Mutation then "🧬" else ""), Parent = card })
		UIKit.text({ Position = UDim2.fromScale(0.03, 0.4), Size = UDim2.fromScale(0.94, 0.32), Text = CD.GetDisplayName(record), TextColor3 = ctx.Rarity.Colors[rarity], Parent = card })
		local tags = (if record.Id == profile.Equipped then "⭐ " else "") .. (if record.Locked then "🔒 " else "") .. CD.Stages[record.Stage].Name
		UIKit.text({ Position = UDim2.fromScale(0.03, 0.72), Size = UDim2.fromScale(0.94, 0.22), Text = tags, TextColor3 = C.SubText, Parent = card })
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
	local rowHeight = math.clamp(math.floor(contentSize().Y * 0.16), 48, 110)
	local row = UIKit.panel({ Size = UDim2.new(1, -8, 0, rowHeight), BackgroundColor3 = C.PanelLight, Parent = parent })
	UIKit.text({ Position = UDim2.fromScale(0.02, 0.08), Size = UDim2.fromScale(0.6, 0.38), Text = name, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	UIKit.text({ Position = UDim2.fromScale(0.02, 0.5), Size = UDim2.fromScale(0.6, 0.42), Text = description, TextColor3 = C.SubText, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromScale(0.34, 0.7),
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

	local tabs = UIKit.new("Frame", { Size = UDim2.fromScale(1, 0.085), BackgroundTransparency = 1, Parent = content })
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

	local list = scrolling({ Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.9), Parent = content })
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
		UIKit.text({ Size = UDim2.new(1, -8, 0, math.clamp(math.floor(contentSize().Y * 0.09), 24, 60)), Text = "Robux items are convenience & cosmetics only. Everything that matters in a fight can be earned by playing.", TextColor3 = C.SubText, Font = Enum.Font.Gotham, Parent = list })
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
	clear()
	UIKit.tween(window, 0.15, { Size = UDim2.new() }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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
	local lastWidth = 0
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local width = content.AbsoluteSize.X
		if current and math.abs(width - lastWidth) > 40 then
			lastWidth = width
			Panels.Render(true)
		end
	end)

	ctx.ProfileChanged:Connect(function()
		Panels.Render(false)
	end)
end

return Panels
