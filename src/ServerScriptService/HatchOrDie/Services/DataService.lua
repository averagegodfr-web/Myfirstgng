-- Player profiles: load with a session lock, reconcile with defaults, migrate by version,
-- autosave, save on leave and on shutdown. Profiles are plain tables (DataStore-safe).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HatchOrDie")
local GameConfig = require(Root.Config.GameConfig)
local Net = require(Root.Shared.Net)
local Signal = require(Root.Shared.Signal)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile)

local CURRENT_VERSION = 1
local SESSION_TIMEOUT = 330
local LOAD_ATTEMPTS = 6

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local store: DataStore? = nil
local savingEnabled = true

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function defaultProfile()
	return {
		Version = CURRENT_VERSION,
		Coins = 0,
		Berries = 3,
		Eggs = {},
		Creatures = {},
		Equipped = nil,
		Incubator = nil,
		Auras = {},
		Discovered = {},
		HighestNight = 0,
		BossesDefeated = 0,
		Stats = { Kills = 0, Hatches = 0, Mutations = 0, Evolutions = 0, NightsSurvived = 0 },
		Settings = { Music = true },
		Receipts = {},
		CreatedAt = os.time(),
	}
end

-- Adds any fields that exist in the template but not in saved data (new features after launch).
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

-- [fromVersion] = function(data) ... end. Add an entry whenever the schema changes shape.
local MIGRATIONS = {}

local function migrate(data)
	while (data.Version or 0) < CURRENT_VERSION do
		local from = data.Version or 0
		local step = MIGRATIONS[from]
		if step then
			step(data)
		end
		data.Version = from + 1
	end
	reconcile(data, defaultProfile())
	return data
end

local function keyFor(player: Player): string
	return "P_" .. player.UserId
end

local function isStudioAccessError(err: any): boolean
	local text = tostring(err)
	return text:find("403") ~= nil or text:find("Studio") ~= nil or text:find("API") ~= nil
end

local function loadData(player: Player)
	if not store or not savingEnabled then
		return defaultProfile()
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local loaded = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(old)
				old = old or {}
				local lock = old.Lock
				local force = attempt == LOAD_ATTEMPTS
				if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < SESSION_TIMEOUT and not force then
					lockedElsewhere = true
					return nil
				end
				lockedElsewhere = false
				loaded = old.Data
				old.Lock = { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if ok and not lockedElsewhere then
			return if loaded then migrate(loaded) else defaultProfile()
		end
		if not ok then
			warn(("[DataService] Load failed for %s (attempt %d): %s"):format(player.Name, attempt, tostring(err)))
			if isStudioAccessError(err) then
				savingEnabled = false
				warn("[DataService] DataStores unavailable (enable 'Studio Access to API Services'). Saving disabled this session.")
				return defaultProfile()
			end
		end
		if not player.Parent then
			return nil
		end
		task.wait(if lockedElsewhere then 5 else 2)
	end
	return nil
end

function DataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not store or not savingEnabled then
		return false
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			old = old or {}
			local lock = old.Lock
			if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < SESSION_TIMEOUT then
				-- Another server owns this profile now; never overwrite its newer data.
				return nil
			end
			old.Data = profile
			old.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return old
		end)
	end)
	if not ok then
		warn(("[DataService] Save failed for %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

function DataService.GetProfile(player: Player)
	return profiles[player]
end

function DataService.WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.GetLoadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

function DataService.IsSavingEnabled(): boolean
	return savingEnabled and store ~= nil
end

-- Mark the profile as changed; the client view and leaderstats are pushed once per batch.
function DataService.Changed(player: Player)
	dirty[player] = true
end

local function clientView(profile)
	local view = table.clone(profile)
	view.Receipts = nil
	return view
end

local function updateLeaderstats(player: Player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = stats
		local best = Instance.new("IntValue")
		best.Name = "Best Night"
		best.Parent = stats
		stats.Parent = player
	end
	local values = stats :: any
	values.Coins.Value = profile.Coins
	values["Best Night"].Value = profile.HighestNight
end

function DataService.SyncNow(player: Player)
	local profile = profiles[player]
	if profile then
		dirty[player] = nil
		updateLeaderstats(player, profile)
		Net.Get("SyncData"):FireClient(player, clientView(profile), DataService.IsSavingEnabled())
	end
end

local function onPlayerAdded(player: Player)
	local profile = loadData(player)
	if not player.Parent then
		return
	end
	if not profile then
		player:Kick("Your save data could not be loaded. Please rejoin in a minute - your progress is safe.")
		return
	end
	profiles[player] = profile
	DataService.SyncNow(player)
	DataService.ProfileLoaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	DataService.ProfileReleasing:Fire(player, profile)
	DataService.Save(player, true)
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.Init()
	if game.PlaceId == 0 then
		savingEnabled = false
		warn("[DataService] Place is not published - saving disabled. Publish the place to enable DataStores.")
	else
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(GameConfig.DataStoreName)
		end)
		if ok then
			store = result
		else
			savingEnabled = false
			warn("[DataService] Could not open DataStore: " .. tostring(result))
		end
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Net.On("ClientReady", function(player)
		DataService.SyncNow(player)
	end, 2)

	-- Batched client sync.
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player in dirty do
				DataService.SyncNow(player)
			end
		end
	end)

	-- Autosave.
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
