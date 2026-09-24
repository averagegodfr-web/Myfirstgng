--!nocheck
-- A tiny fake Roblox engine for headless smoke tests under Lune.
-- Real datatypes come from @lune/roblox; Instances, signals, services and the task scheduler are faked
-- here with a virtual clock so whole day/night cycles run in milliseconds.
local roblox = require("@lune/roblox")

local M = {}

---------------------------------------------------------------------------------------------------
-- Scheduler (virtual time)
---------------------------------------------------------------------------------------------------
local now = 0
local queue = {} -- { time, seq, thread, args }
local seq = 0
M.errors = {}

local function schedule(t, thread, ...)
	seq += 1
	table.insert(queue, { time = t, seq = seq, thread = thread, args = table.pack(...) })
end

local function resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		local msg = tostring(err) .. "\n" .. debug.traceback(thread)
		table.insert(M.errors, msg)
		print("[SIM ERROR] " .. msg)
	end
end

local task = {}
function task.spawn(fnOrThread, ...)
	local thread = if type(fnOrThread) == "thread" then fnOrThread else coroutine.create(fnOrThread)
	resume(thread, ...)
	return thread
end
function task.defer(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	schedule(now, thread, ...)
	return thread
end
function task.delay(t, fn, ...)
	local thread = coroutine.create(fn)
	schedule(now + (t or 0), thread, ...)
	return thread
end
function task.wait(t)
	local start = now
	local thread = coroutine.running()
	schedule(now + math.max(t or 0, 1 / 60), thread)
	coroutine.yield()
	return now - start
end
function task.cancel() end
M.task = task

function M.now()
	return now
end

local heartbeatSignal
function M.step(dt)
	now += dt
	if heartbeatSignal then
		heartbeatSignal:Fire(dt)
	end
	while true do
		table.sort(queue, function(a, b)
			if a.time == b.time then
				return a.seq < b.seq
			end
			return a.time < b.time
		end)
		local item = queue[1]
		if not item or item.time > now then
			break
		end
		table.remove(queue, 1)
		if coroutine.status(item.thread) == "suspended" then
			resume(item.thread, table.unpack(item.args, 1, item.args.n))
		end
	end
end

function M.run(seconds, dt)
	dt = dt or 1 / 20
	local target = now + seconds
	while now < target do
		M.step(dt)
	end
end

---------------------------------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	return {
		Connected = true,
		Disconnect = function()
			h.connected = false
		end,
	}
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c.Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	local thread = coroutine.running()
	table.insert(self.waiting, thread)
	return coroutine.yield()
end
function Signal:Fire(...)
	for _, h in table.clone(self.handlers) do
		if h.connected then
			task.spawn(h.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, thread in waiting do
		resume(thread, ...)
	end
end
M.Signal = Signal
heartbeatSignal = Signal.new()

---------------------------------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------------------------------
local ISA = {
	Part = { "BasePart", "PVInstance" },
	WedgePart = { "BasePart", "PVInstance" },
	SpawnLocation = { "Part", "BasePart", "PVInstance" },
	Model = { "PVInstance" },
	Workspace = { "Model", "PVInstance" },
	Script = { "BaseScript", "LuaSourceContainer" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer" },
	ModuleScript = { "LuaSourceContainer" },
	ScreenGui = { "LayerCollector", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	SurfaceGui = { "LayerCollector", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiButton", "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "GuiObject", "GuiBase2d" },
	ViewportFrame = { "GuiObject", "GuiBase2d" },
	ImageLabel = { "GuiObject", "GuiBase2d" },
	Tool = { "BackpackItem" },
	PointLight = { "Light" },
	Fire = {},
}

local DEFAULTS = {
	BasePart = function(p)
		p.Size = roblox.Vector3.new(4, 1, 2)
		p.CFrame = roblox.CFrame.new()
		p.Transparency = 0
		p.Anchored = false
		p.CanCollide = true
		p.Color = roblox.Color3.new(0.6, 0.6, 0.6)
		p.AssemblyLinearVelocity = roblox.Vector3.zero
	end,
	Humanoid = function(h)
		h.Health = 100
		h.MaxHealth = 100
		h.CameraOffset = roblox.Vector3.zero
	end,
	GuiObject = function(g)
		g.Visible = true
		g.Size = roblox.UDim2.new()
		g.Position = roblox.UDim2.new()
		g.BackgroundTransparency = 0
		g.Rotation = 0
	end,
	ProximityPrompt = function(p)
		p.Enabled = true
	end,
	UIGradient = function(g)
		g.Rotation = 0
	end,
}

-- Validate property names against Roblox's real API reflection database.
local reflection = roblox.getReflectionDatabase()
local validCache = {}
local function isValidProperty(className, prop)
	local key = className .. "." .. prop
	if validCache[key] ~= nil then
		return validCache[key]
	end
	local cls = reflection:GetClass(className)
	local ok = false
	while cls do
		if cls.Properties[prop] then
			ok = true
			break
		end
		cls = cls.Superclass and reflection:GetClass(cls.Superclass)
	end
	validCache[key] = ok
	return ok
end
M.invalidProperties = {}
local HARNESS_KEYS = { ViewportSize = true, LocalPlayer = true, CurrentCamera = true, PlaceId = true, JobId = true, Character = true, UserId = true, DisplayName = true, ProcessReceipt = true, OnIncomingMessage = true }

local Instance = {}
local instanceMeta = {}
local allInstances = setmetatable({}, { __mode = "k" })

local function isA(obj, className)
	local cls = rawget(obj, "__class")
	if cls == className or className == "Instance" then
		return true
	end
	for _, parent in ISA[cls] or {} do
		if parent == className then
			return true
		end
	end
	return false
end

local methods = {}

function methods:IsA(className)
	return isA(self, className)
end
function methods:GetChildren()
	return table.clone(rawget(self, "__children"))
end
function methods:GetDescendants()
	local out = {}
	local function walk(o)
		for _, c in rawget(o, "__children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods:FindFirstChild(name, recursive)
	for _, c in rawget(self, "__children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "__children") do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods:WaitForChild(name, timeout)
	local deadline = now + (timeout or 5)
	while true do
		local c = self:FindFirstChild(name)
		if c then
			return c
		end
		if now >= deadline then
			if timeout then
				return nil
			end
			error("Infinite yield on WaitForChild(" .. name .. ") in " .. self:GetFullName())
		end
		task.wait(0.05)
	end
end
function methods:FindFirstChildOfClass(className)
	for _, c in rawget(self, "__children") do
		if rawget(c, "__class") == className then
			return c
		end
	end
	return nil
end
function methods:FindFirstChildWhichIsA(className, recursive)
	for _, c in rawget(self, "__children") do
		if isA(c, className) then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "__children") do
			local f = c:FindFirstChildWhichIsA(className, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function methods:FindFirstAncestorOfClass(className)
	local p = self.Parent
	while p do
		if rawget(p, "__class") == className then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods:IsDescendantOf(other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods:GetFullName()
	local parts = {}
	local o = self
	while o do
		table.insert(parts, 1, o.Name)
		o = o.Parent
	end
	return table.concat(parts, ".")
end
function methods:Destroy()
	for _, c in table.clone(rawget(self, "__children")) do
		c:Destroy()
	end
	self.Parent = nil
	rawset(self, "__destroyed", true)
	local sig = rawget(self, "__signals").Destroying
	if sig then
		sig:Fire()
	end
end
function methods:ClearAllChildren()
	for _, c in table.clone(rawget(self, "__children")) do
		c:Destroy()
	end
end
function methods:Clone()
	local copy = Instance.new(rawget(self, "__class"))
	for k, v in rawget(self, "__props") do
		if k ~= "Parent" then
			rawget(copy, "__props")[k] = v
		end
	end
	for k, v in rawget(self, "__attrs") do
		rawget(copy, "__attrs")[k] = v
	end
	for _, c in rawget(self, "__children") do
		c:Clone().Parent = copy
	end
	return copy
end
function methods:SetAttribute(name, value)
	local attrs = rawget(self, "__attrs")
	if attrs[name] ~= value then
		attrs[name] = value
		local sig = rawget(self, "__attrSignals")[name]
		if sig then
			sig:Fire()
		end
	end
end
function methods:GetAttribute(name)
	return rawget(self, "__attrs")[name]
end
function methods:GetAttributeChangedSignal(name)
	local sigs = rawget(self, "__attrSignals")
	sigs[name] = sigs[name] or Signal.new()
	return sigs[name]
end
function methods:GetPropertyChangedSignal(_name)
	return Signal.new()
end
-- PVInstance
function methods:GetPivot()
	if isA(self, "BasePart") then
		return self.CFrame
	end
	local pp = self.PrimaryPart
	if pp then
		return pp.CFrame
	end
	local first = self:FindFirstChildWhichIsA("BasePart", true)
	return if first then first.CFrame else roblox.CFrame.new()
end
function methods:PivotTo(cf)
	if isA(self, "BasePart") then
		self.CFrame = cf
		return
	end
	local pivot = self:GetPivot()
	local delta = cf * pivot:Inverse()
	for _, d in self:GetDescendants() do
		if isA(d, "BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
function methods:GetBoundingBox()
	local minV, maxV
	for _, d in self:GetDescendants() do
		if isA(d, "BasePart") then
			local p, s = d.CFrame.Position, d.Size / 2
			local lo, hi = p - s, p + s
			minV = if minV then roblox.Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) else lo
			maxV = if maxV then roblox.Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) else hi
		end
	end
	minV = minV or roblox.Vector3.zero
	maxV = maxV or roblox.Vector3.zero
	return roblox.CFrame.new((minV + maxV) / 2), maxV - minV
end
function methods:GetExtentsSize()
	local _, size = self:GetBoundingBox()
	return size
end
-- Humanoid
function methods:TakeDamage(amount)
	if self.Health <= 0 then
		return
	end
	self.Health = math.max(0, self.Health - amount)
end
function methods:MoveTo() end
-- Sound / Tween-ish no-ops
function methods:Play() end
function methods:Stop() end
-- Remotes
function methods:FireServer(...)
	M.onFireServer(self, ...)
end
function methods:FireClient(player, ...)
	M.onFireClient(self, player, ...)
end
function methods:FireAllClients(...)
	M.onFireClient(self, "ALL", ...)
end
-- Players
function methods:LoadCharacter()
	M.loadCharacter(self)
end
function methods:Kick(msg)
	table.insert(M.errors, "KICKED: " .. tostring(msg))
end
function methods:GetPlayers()
	local list = {}
	for _, c in rawget(self, "__children") do
		if rawget(c, "__class") == "Player" then
			table.insert(list, c)
		end
	end
	return list
end
function methods:GetPlayerByUserId(id)
	for _, p in self:GetPlayers() do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
-- Raycast (client) – no hits in sim
function methods:Raycast()
	return nil
end
function methods:GetServerTimeNow()
	return 1.7e9 + now
end
function methods:ScreenPointToRay()
	return { Origin = roblox.Vector3.zero, Direction = roblox.Vector3.new(0, 0, -1) }
end
function methods:GetMouseLocation()
	return roblox.Vector2.zero
end

local EVENT_NAMES = {
	ChildAdded = true, ChildRemoved = true, Destroying = true, AncestryChanged = true, Changed = true,
	Died = true, CharacterAdded = true, CharacterRemoving = true, Activated = true, Triggered = true,
	OnServerEvent = true, OnClientEvent = true, MouseEnter = true, MouseLeave = true, MouseButton1Down = true,
	MouseButton1Up = true, MouseButton1Click = true, Ended = true, PlayerAdded = true, PlayerRemoving = true,
	Heartbeat = true, RenderStepped = true, Stepped = true, InputBegan = true, InputEnded = true,
	PromptGamePassPurchaseFinished = true, Completed = true, Touched = true,
}

function instanceMeta.__index(self, key)
	local m = methods[key]
	if m then
		return m
	end
	local props = rawget(self, "__props")
	local v = props[key]
	if v ~= nil then
		return v
	end
	if key == "Position" and props.CFrame and isA(self, "BasePart") then
		return props.CFrame.Position
	end
	if key == "LookVector" then
		return nil
	end
	if EVENT_NAMES[key] then
		local sigs = rawget(self, "__signals")
		sigs[key] = sigs[key] or Signal.new()
		return sigs[key]
	end
	if key == "ClassName" then
		return rawget(self, "__class")
	end
	for _, c in rawget(self, "__children") do
		if c.Name == key then
			return c
		end
	end
	return nil
end

local function setParent(self, newParent)
	local props = rawget(self, "__props")
	local old = props.Parent
	if old == newParent then
		return
	end
	if old then
		local list = rawget(old, "__children")
		local i = table.find(list, self)
		if i then
			table.remove(list, i)
		end
		local sig = rawget(old, "__signals").ChildRemoved
		if sig then
			sig:Fire(self)
		end
	end
	props.Parent = newParent
	if newParent then
		table.insert(rawget(newParent, "__children"), self)
		local sig = rawget(newParent, "__signals").ChildAdded
		if sig then
			sig:Fire(self)
		end
		local desc = rawget(newParent, "__descAdded")
		if desc then
			desc(self)
		end
	end
end

function instanceMeta.__newindex(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		setParent(self, value)
		return
	end
	if key == "Position" and isA(self, "BasePart") then
		local cf = props.CFrame or roblox.CFrame.new()
		props.CFrame = cf - cf.Position + value
		return
	end
	if key == "Orientation" then
		return
	end
	if key == "Shape" and value == roblox.Enum.PartType.Ball and props.Size then
		props[key] = value
		return
	end
	if key == "Health" and rawget(self, "__class") == "Humanoid" then
		local before = props.Health or 100
		props.Health = math.clamp(value, 0, props.MaxHealth or 100)
		if before > 0 and props.Health <= 0 then
			local sig = rawget(self, "__signals").Died
			if sig then
				sig:Fire()
			end
		end
		return
	end
	local cls = rawget(self, "__class")
	if not HARNESS_KEYS[key] and reflection:GetClass(cls) and not isValidProperty(cls, key) then
		M.invalidProperties[cls .. "." .. key] = true
	end
	props[key] = value
end

function instanceMeta.__tostring(self)
	return self.Name
end

function Instance.new(className, parent)
	local obj = setmetatable({
		__class = className,
		__props = { Name = className },
		__children = {},
		__attrs = {},
		__attrSignals = {},
		__signals = {},
	}, instanceMeta)
	for base, init in DEFAULTS do
		if isA(obj, base) then
			init(obj)
		end
	end
	allInstances[obj] = true
	if parent then
		obj.Parent = parent
	end
	return obj
end
M.Instance = Instance

function M.typeof(v)
	if type(v) == "table" and getmetatable(v) == instanceMeta then
		return "Instance"
	end
	return typeof(v)
end

---------------------------------------------------------------------------------------------------
-- DataModel + services
---------------------------------------------------------------------------------------------------
local game = Instance.new("DataModel")
game.Name = "Game"
game.PlaceId = 12345
game.JobId = "sim-job"
M.game = game

local services = {}
local function service(name, className)
	local s = Instance.new(className or name)
	s.Name = name
	s.Parent = game
	services[name] = s
	return s
end

local workspace = service("Workspace")
local terrain = Instance.new("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
function methods:FillBlock() end
function methods:Clear() end
M.workspace = workspace
workspace.CurrentCamera = Instance.new("Camera", workspace)
workspace.CurrentCamera.ViewportSize = roblox.Vector2.new(1280, 720)

local Players = service("Players")
Players.CharacterAutoLoads = true
service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
service("StarterPack")
local StarterPlayer = service("StarterPlayer")
Instance.new("StarterPlayerScripts", StarterPlayer).Name = "StarterPlayerScripts"
service("Lighting").ClockTime = 14
service("SoundService")
service("TextChatService")
service("StarterGui")
service("Selection")
function methods:Set() end
local RunService = service("RunService")
rawget(RunService, "__signals").Heartbeat = heartbeatSignal
rawget(RunService, "__signals").RenderStepped = heartbeatSignal
M.isServer = true
function methods:IsServer()
	return M.isServer
end
function methods:IsClient()
	return not M.isServer
end
function methods:IsStudio()
	return true
end

local TweenService = service("TweenService")
function methods:Create(inst, _info, props)
	return {
		Play = function()
			for k, v in props do
				inst[k] = v
			end
		end,
		Cancel = function() end,
		Completed = Signal.new(),
	}
end
local Debris = service("Debris")
function methods:AddItem(item, t)
	task.delay(t or 10, function()
		if item.Parent then
			item:Destroy()
		end
	end)
end
local HttpService = service("HttpService")
local guidCounter = 0
function methods:GenerateGUID()
	guidCounter += 1
	return ("%08x-aaaa-bbbb-cccc-%012x"):format(guidCounter, guidCounter)
end
-- DataStore (in-memory, shared across "servers" in a test)
M.datastore = {}
local DataStoreService = service("DataStoreService")
function methods:GetDataStore(_name)
	return {
		UpdateAsync = function(_self, key, fn)
			local old = M.datastore[key]
			local new = fn(if old then table.clone(old) else nil)
			if new ~= nil then
				M.datastore[key] = new
			end
			return new
		end,
	}
end
local MarketplaceService = service("MarketplaceService")
function methods:UserOwnsGamePassAsync()
	return false
end
function methods:PromptGamePassPurchase() end
function methods:PromptProductPurchase() end
function methods:BindToClose(fn)
	M.bindToClose = fn
end
service("UserInputService")
service("ContextActionService")
local CollectionService = service("CollectionService")

function methods:GetService(name)
	return services[name] or error("sim: unknown service " .. name)
end

---------------------------------------------------------------------------------------------------
-- Players & characters
---------------------------------------------------------------------------------------------------
local nextUserId = 1000
function M.addPlayer(name, userId)
	nextUserId += 1
	local player = Instance.new("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId or nextUserId
	Instance.new("PlayerGui", player).Name = "PlayerGui"
	Instance.new("Backpack", player).Name = "Backpack"
	player.Parent = Players
	rawget(Players, "__signals").PlayerAdded = rawget(Players, "__signals").PlayerAdded or Signal.new()
	rawget(Players, "__signals").PlayerAdded:Fire(player)
	if Players.CharacterAutoLoads then
		M.loadCharacter(player)
	end
	return player
end

function M.removePlayer(player)
	local sig = rawget(Players, "__signals").PlayerRemoving
	if sig then
		sig:Fire(player)
	end
	player.Parent = nil
end

function M.loadCharacter(player)
	if player.Character then
		player.Character:Destroy()
	end
	local character = Instance.new("Model")
	character.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = roblox.CFrame.new(0, 3, 16)
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	-- Roblox copies StarterGui into PlayerGui on spawn (ResetOnSpawn=false guis only once).
	for _, g in services.StarterGui:GetChildren() do
		if not player.PlayerGui:FindFirstChild(g.Name) then
			g:Clone().Parent = player.PlayerGui
		end
	end
	character.Parent = workspace
	player.Character = character
	-- StarterPack tools
	for _, tool in services.StarterPack:GetChildren() do
		tool:Clone().Parent = player.Backpack
	end
	local sig = rawget(player, "__signals").CharacterAdded
	if sig then
		sig:Fire(character)
	end
	return character
end

---------------------------------------------------------------------------------------------------
-- Environment for running Roblox scripts
---------------------------------------------------------------------------------------------------
local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = seed or 12345
	local r = setmetatable({}, Random)
	r._next = function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return r
end
function Random:NextNumber(a, b)
	local x = self._next()
	if a and b then
		return a + (b - a) * x
	end
	return x
end
function Random:NextInteger(a, b)
	return a + math.floor(self._next() * (b - a + 1))
end

local function TweenInfoNew(...)
	return { ... }
end

local RaycastParams = {
	new = function()
		return {}
	end,
}

function M.makeEnv(scriptInstance, requireFn)
	local env = {
		game = game,
		workspace = workspace,
		script = scriptInstance,
		require = requireFn,
		Instance = Instance,
		task = task,
		typeof = M.typeof,
		Random = Random,
		TweenInfo = { new = TweenInfoNew },
		RaycastParams = RaycastParams,
		wait = task.wait,
		os = setmetatable({
			clock = function()
				return now
			end,
			time = function()
				return math.floor(1.7e9 + now)
			end,
		}, { __index = os }),
		print = function(...)
			if M.verbose then
				print(...)
			end
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			local msg = table.concat(parts, " ")
			table.insert(M.warnings, msg)
			if M.verbose then
				print("[warn] " .. msg)
			end
		end,
	}
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim", "Enum", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "BrickColor", "Ray", "Region3" } do
		env[name] = roblox[name]
	end
	return setmetatable(env, { __index = _G })
end
M.warnings = {}

return M
