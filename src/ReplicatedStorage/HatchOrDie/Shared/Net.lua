-- All remotes live in ReplicatedStorage.HatchOrDie.Remotes and are created by the server.
local RunService = game:GetService("RunService")

local Root = script.Parent.Parent

local Net = {}

Net.Events = {
	-- client -> server
	"ClientReady",
	"RequestHatch",
	"EquipCreature",
	"FeedCreature",
	"SetCommand",
	"SetTarget",
	"UseAbility",
	"EvolveCreature",
	"ReleaseCreature",
	"ToggleLock",
	"EquipAura",
	"BuyItem",
	-- server -> client
	"SyncData",
	"HatchResult",
	"Evolved",
	"Notify",
	"Announce",
	"BossBar",
	"OpenPanel",
	"NightResult",
	"Effect",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = Root:FindFirstChild("Remotes")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = Root
		end
		for _, name in Net.Events do
			if not f:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = f
			end
		end
		folder = f
	else
		folder = Root:WaitForChild("Remotes")
	end
	return folder :: Folder
end

function Net.Get(name: string): RemoteEvent
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

-- Server-side handler with a per-player rate limit and error isolation.
function Net.On(name: string, handler: (Player, ...any) -> (), cooldown: number?)
	local remote = Net.Get(name)
	local last = setmetatable({}, { __mode = "k" })
	remote.OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		if cooldown and last[player] and now - last[player] < cooldown then
			return
		end
		last[player] = now
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] %s failed for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.Notify(player: Player, text: string, color: Color3?)
	Net.Get("Notify"):FireClient(player, text, color)
end

function Net.NotifyAll(text: string, color: Color3?)
	Net.Get("Notify"):FireAllClients(text, color)
end

function Net.Announce(text: string, color: Color3?, big: boolean?)
	Net.Get("Announce"):FireAllClients(text, color, big)
end

return Net
