-- Coin shop + Robux (gamepasses and developer products). Prices and rewards come only from
-- server-side config; the client sends an item id, never a price or amount.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local ShopData = require(Root.Config.ShopData)
local EggData = require(Root.Config.EggData)
local CreatureData = require(Root.Config.CreatureData)
local Net = require(Root.Shared.Net)

local ShopService = {}

local GOOD = Color3.fromRGB(120, 255, 140)

-- Developer product handlers, keyed by GameConfig.Products key.
local PRODUCT_HANDLERS = {
	EggPack = function(player: Player)
		for _ = 1, 3 do
			Registry.EggService.GiveEgg(player, "EmberEgg", "Egg Pack", true)
		end
		Registry.EconomyService.AddCoins(player, 200)
	end,
	GalaxyAura = function(player: Player, profile)
		profile.Auras.Galaxy = true
		Registry.DataService.Changed(player)
		Net.Notify(player, "🌌 Galaxy Aura unlocked! Equip it from the Creatures menu.", GOOD)
	end,
}

local productIdToKey = {}
for key, id in GameConfig.Products do
	if id ~= 0 then
		productIdToKey[id] = key
	end
end

local function applyVIPTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VIPTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VIPTag"
	gui.Size = UDim2.fromOffset(80, 24)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "⭐ VIP"
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = head
end

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		applyVIPTag(player)
	elseif key == "AutoHatch" then
		Registry.EggService.TryAutoHatch(player)
	end
end

local function checkPasses(player: Player)
	for key, id in GameConfig.Gamepasses do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
end

local function buyItem(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return
	end
	local item = ShopData.ById[itemId]
	local profile = Registry.DataService.GetProfile(player)
	if not item or not profile then
		return
	end

	if item.Kind == "Egg" then
		if not EggData[item.EggId] then
			return
		end
		if #profile.Eggs >= GameConfig.MaxEggs then
			Net.Notify(player, "Your egg bag is full - hatch some eggs first!", Color3.fromRGB(255, 120, 120))
			return
		end
		if Registry.EconomyService.SpendCoins(player, item.Price) then
			Registry.EggService.GiveEgg(player, item.EggId, "purchased")
		end
	elseif item.Kind == "Berries" then
		if Registry.EconomyService.SpendCoins(player, item.Price) then
			Registry.EconomyService.AddBerries(player, item.Amount)
			Net.Notify(player, ("🍓 +%d berries"):format(item.Amount), GOOD)
		end
	elseif item.Kind == "Aura" then
		if not CreatureData.Auras[item.AuraId] then
			return
		end
		if profile.Auras[item.AuraId] then
			Net.Notify(player, "You already own that aura.", Color3.fromRGB(200, 200, 200))
			return
		end
		if Registry.EconomyService.SpendCoins(player, item.Price) then
			profile.Auras[item.AuraId] = true
			Registry.DataService.Changed(player)
			Net.Notify(player, ("✨ %s unlocked! Equip it from the Creatures menu."):format(CreatureData.Auras[item.AuraId].Name), GOOD)
		end
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Registry.DataService.WaitForProfile(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(profile.Receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productIdToKey[info.ProductId]
	local handler = key and PRODUCT_HANDLERS[key]
	if not handler then
		warn("[ShopService] No handler for product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(handler, player, profile)
	if not ok then
		warn("[ShopService] Product grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Receipts, info.PurchaseId)
	while #profile.Receipts > 50 do
		table.remove(profile.Receipts, 1)
	end
	Registry.DataService.Changed(player)
	Registry.DataService.Save(player, false)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Init()
	Registry.DataService.ProfileLoaded:Connect(function(player: Player)
		checkPasses(player)
	end)
end

function ShopService.Start()
	Net.On("BuyItem", buyItem, 0.4)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, id in GameConfig.Gamepasses do
			if id == passId then
				grantPass(player, key)
				Net.Notify(player, "⭐ Thanks for your support! Pass activated.", Color3.fromRGB(255, 210, 60))
			end
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if player:GetAttribute("Pass_VIP") then
				task.wait(0.5)
				applyVIPTag(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return ShopService
