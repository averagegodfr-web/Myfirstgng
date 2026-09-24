-- HATCH OR DIE client entry. The client only renders and sends intents; the server decides outcomes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Root = ReplicatedStorage:WaitForChild("HatchOrDie")

local Net = require(Root.Shared.Net)
local Signal = require(Root.Shared.Signal)
local Models = require(Root.Shared.Models)
local GameConfig = require(Root.Config.GameConfig)
local CreatureData = require(Root.Config.CreatureData)
local EggData = require(Root.Config.EggData)
local ShopData = require(Root.Config.ShopData)
local Rarity = require(Root.Config.Rarity)

local UIKit = require(script.UIKit)
local Layout = require(script.Layout)
local Hud = require(script.Hud)
local Panels = require(script.Panels)
local Cinematics = require(script.Cinematics)

local gui = Layout.Obtain(player)

local ctx = {
	Root = Root,
	Net = Net,
	Gui = gui,
	Models = Models,
	GameConfig = GameConfig,
	CreatureData = CreatureData,
	EggData = EggData,
	ShopData = ShopData,
	Rarity = Rarity,
	Layout = Layout,
	Profile = nil,
	SavingEnabled = true,
	ProfileChanged = Signal.new(),
	Hud = Hud,
	Panels = Panels,
	Cinematics = Cinematics,
}

function ctx.SlotLimit(): number
	local bonus = if player:GetAttribute("Pass_ExtraSlots") then GameConfig.ExtraSlotsBonus else 0
	return GameConfig.BaseCreatureSlots + bonus
end

Hud.Init(ctx)
Panels.Init(ctx)
Cinematics.Init(ctx)

---------------------------------------------------------------------------------------------------
-- Server -> client
---------------------------------------------------------------------------------------------------
local warnedNoSave = false
Net.Get("SyncData").OnClientEvent:Connect(function(profile, savingEnabled)
	ctx.Profile = profile
	ctx.SavingEnabled = savingEnabled
	ctx.ProfileChanged:Fire(profile)
	if not savingEnabled and not warnedNoSave then
		warnedNoSave = true
		Hud.Toast("⚠️ Saving is OFF (Studio test or DataStores unavailable).", Color3.fromRGB(255, 170, 60))
	end
end)

Net.Get("Notify").OnClientEvent:Connect(function(text, color)
	Hud.Toast(text, color)
end)

Net.Get("Announce").OnClientEvent:Connect(function(text, color, big)
	Hud.Announce(text, color, big)
	if big then
		Cinematics.Shake(0.6, 0.4)
	end
end)

Net.Get("HatchResult").OnClientEvent:Connect(function(result)
	if Panels.IsOpen() then
		Panels.Close()
	end
	Cinematics.Hatch(result)
end)

Net.Get("Evolved").OnClientEvent:Connect(function(result)
	if Panels.IsOpen() then
		Panels.Close()
	end
	Cinematics.Evolve(result)
end)

Net.Get("BossBar").OnClientEvent:Connect(function(data)
	Hud.SetBoss(data)
end)

Net.Get("OpenPanel").OnClientEvent:Connect(function(name)
	Panels.Open(name)
end)

Net.Get("NightResult").OnClientEvent:Connect(function(result)
	Hud.ShowNightResult(result)
end)

Net.Get("Effect").OnClientEvent:Connect(function(kind, value)
	if kind == "Shake" then
		Cinematics.Shake(value or 1, 0.5)
	end
end)

---------------------------------------------------------------------------------------------------
-- Death overlay
---------------------------------------------------------------------------------------------------
local function onCharacter(character: Model)
	Hud.SetDead(false)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		if Root:GetAttribute("Phase") == "Night" then
			Hud.SetDead(true)
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------------------------------------------
-- Input: Q ability, F feed, 1/2/3 commands, click/tap an enemy to target it
---------------------------------------------------------------------------------------------------
local targetHighlight = UIKit.new("Highlight", {
	FillTransparency = 1,
	OutlineColor = Color3.fromRGB(255, 220, 60),
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Parent = workspace,
})
local highlightToken = 0

local function tryTarget(screenPosition: Vector2)
	local camera = workspace.CurrentCamera
	local enemies = workspace:FindFirstChild("Enemies")
	if not camera or not enemies then
		return
	end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { enemies }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not hit then
		return
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= enemies do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return
	end
	Net.Get("SetTarget"):FireServer(model)
	targetHighlight.Adornee = model
	highlightToken += 1
	local token = highlightToken
	task.delay(2.5, function()
		if highlightToken == token then
			targetHighlight.Adornee = nil
		end
	end)
end

local KEY_ACTIONS = {
	[Enum.KeyCode.Q] = function()
		Net.Get("UseAbility"):FireServer()
	end,
	[Enum.KeyCode.F] = function()
		Net.Get("FeedCreature"):FireServer()
	end,
	[Enum.KeyCode.One] = function()
		Net.Get("SetCommand"):FireServer("Follow")
	end,
	[Enum.KeyCode.Two] = function()
		Net.Get("SetCommand"):FireServer("Attack")
	end,
	[Enum.KeyCode.Three] = function()
		Net.Get("SetCommand"):FireServer("Defend")
	end,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local action = KEY_ACTIONS[input.KeyCode]
		if action then
			action()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		tryTarget(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

---------------------------------------------------------------------------------------------------
-- Optional music (set ids in GameConfig.Music)
---------------------------------------------------------------------------------------------------
local music = UIKit.new("Sound", { Looped = true, Volume = 0.35, Parent = SoundService })
local function updateMusic()
	local phase = Root:GetAttribute("Phase")
	local id = if phase == "Night" then GameConfig.Music.Night else GameConfig.Music.Day
	if id == "" then
		music:Stop()
		return
	end
	if music.SoundId ~= id then
		music.SoundId = id
		music:Play()
	end
end
Root:GetAttributeChangedSignal("Phase"):Connect(updateMusic)
updateMusic()

---------------------------------------------------------------------------------------------------
-- VIP chat tag
---------------------------------------------------------------------------------------------------
local TextChatService = game:GetService("TextChatService")
TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker and speaker:GetAttribute("Pass_VIP") then
			props.PrefixText = "<font color='#FFD23C'>[VIP]</font> " .. message.PrefixText
		end
	end
	return props
end

Net.Get("ClientReady"):FireServer()
