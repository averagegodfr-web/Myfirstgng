-- Player weapon: the Torch (StarterPack). Hit detection is a server-side range + facing check,
-- so the client never reports hits or damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Registry = require(script.Parent.Parent.Registry)
local Effects = require(script.Parent.Parent.Modules.Effects)

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)

local CombatService = {}

local function torchDamage(): number
	local night = Root:GetAttribute("Night") or 1
	return GameConfig.TorchDamage * (1 + 0.08 * (night - 1))
end

local function swing(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	local look = rootPart.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local origin = rootPart.Position
	Effects.Burst(origin + flatLook * 4, Color3.fromRGB(255, 160, 50), 2.5, 0.2)

	local damage = torchDamage()
	for _, e in Registry.EnemyService.GetInRadius(origin, GameConfig.TorchRange + 2) do
		local offset = Vector3.new(e.Root.Position.X - origin.X, 0, e.Root.Position.Z - origin.Z)
		local edgeDist = offset.Magnitude - e.Radius
		if edgeDist <= GameConfig.TorchRange and (edgeDist < 3 or offset.Unit:Dot(flatLook) > 0.2) then
			Registry.EnemyService.Damage(e, damage, player)
		end
	end
end

local function hookTool(player: Player, tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("HODHooked") then
		return
	end
	tool:SetAttribute("HODHooked", true)
	local last = 0
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - last < GameConfig.TorchCooldown then
			return
		end
		last = now
		swing(player)
	end)
end

function CombatService.Start()
	local function onCharacter(player: Player, character: Model)
		for _, child in character:GetChildren() do
			hookTool(player, child)
		end
		character.ChildAdded:Connect(function(child)
			hookTool(player, child)
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CombatService
