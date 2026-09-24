-- Hatch and evolution reveals, plus camera shake. Reveals are queued so they never overlap.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local UIKit = require(script.Parent.UIKit)

local Cinematics = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local ctx
local gui: ScreenGui
local queue = {}
local running = false

local function playSound(id: string?, volume: number?)
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Cinematics.Shake(intensity: number, duration: number?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local d = duration or 0.45
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= d or not humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local falloff = 1 - t / d
		local k = intensity * falloff
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k)
	end)
end

local function overlay()
	local root = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Active = true,
		Parent = gui,
	})
	UIKit.tween(root, 0.3, { BackgroundTransparency = 0.3 })

	local rays = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(700, 700),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = root,
	})
	UIKit.corner(rays, 350)
	local gradient = UIKit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
		Parent = rays,
	})

	local vp = UIKit.viewport({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(340, 340),
		Parent = root,
	}, nil, false)

	local title = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 175),
		Size = UDim2.new(0.8, 0, 0, 56),
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0,
		Parent = root,
	})
	local sub = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 232),
		Size = UDim2.new(0.7, 0, 0, 30),
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.SubText,
		Parent = root,
	})
	local tag = UIKit.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.42, -170),
		Size = UDim2.new(0.6, 0, 0, 36),
		Font = Enum.Font.FredokaOne,
		TextColor3 = C.Gold,
		Parent = root,
	})
	local flash = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = root,
	})
	return {
		Root = root,
		Rays = rays,
		Gradient = gradient,
		Viewport = vp,
		Title = title,
		Sub = sub,
		Tag = tag,
		Flash = flash,
	}
end

local function spinRays(o, color: Color3)
	o.Rays.BackgroundColor3 = color
	o.Rays.BackgroundTransparency = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not o.Root.Parent then
			connection:Disconnect()
			return
		end
		o.Gradient.Rotation = (o.Gradient.Rotation + dt * 60) % 360
	end)
end

local function waitForDismiss(o, seconds: number)
	local done = false
	local button = UIKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(220, 48),
		BackgroundColor3 = Color3.fromRGB(70, 170, 90),
		Text = "AWESOME!",
		Parent = o.Root,
	}, function()
		done = true
	end)
	local deadline = os.clock() + seconds
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	button:Destroy()
	UIKit.tween(o.Root, 0.25, { BackgroundTransparency = 1 })
	for _, d in o.Root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.Visible = false
		end
	end
	task.wait(0.25)
	o.Root:Destroy()
end

local function describe(record)
	local CD = ctx.CreatureData
	local rarity = CD.GetRarity(record)
	local color = ctx.Rarity.Colors[rarity]
	local mutationText = ""
	if record.Mutation then
		mutationText = ("🧬 %s MUTATION!"):format(record.Mutation:upper())
	end
	return rarity, color, mutationText
end

local function playHatch(result)
	local o = overlay()
	local egg = ctx.EggData[result.EggId]
	local record = result.Creature
	local rarity, color, mutationText = describe(record)
	local rare = ctx.Rarity.AtLeast(rarity, "Epic")

	local eggModel = ctx.Models.BuildEgg(result.EggId)
	UIKit.setViewportModel(o.Viewport, eggModel)
	o.Title.Text = "HATCHING..."
	o.Title.TextColor3 = C.Text
	o.Sub.Text = if egg then egg.Name else ""

	local shakes = if rare then 5 else 3
	for i = 1, shakes do
		local amount = 6 + i * 5
		for j = 1, 6 do
			local angle = math.rad(if j % 2 == 0 then amount else -amount)
			eggModel:PivotTo(CFrame.Angles(0, 0, angle))
			task.wait(0.04)
		end
		eggModel:PivotTo(CFrame.new())
		o.Flash.BackgroundTransparency = 0.8
		UIKit.tween(o.Flash, 0.2, { BackgroundTransparency = 1 })
		if i == shakes - 1 and rare then
			spinRays(o, color)
			o.Tag.Text = "✨ SOMETHING RARE... ✨"
		end
		task.wait(0.28)
	end

	playSound(ctx.GameConfig.Sounds.Hatch, 0.8)
	o.Flash.BackgroundTransparency = 0
	UIKit.tween(o.Flash, 0.7, { BackgroundTransparency = 1 })
	if not rare then
		spinRays(o, color)
	end
	local creatureModel = ctx.Models.BuildCreature(record)
	UIKit.setViewportModel(o.Viewport, creatureModel)
	local spin = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not creatureModel.Parent then
			connection:Disconnect()
			return
		end
		spin += dt
		creatureModel:PivotTo(CFrame.Angles(0, spin, 0))
	end)

	o.Title.Text = ctx.CreatureData.GetDisplayName(record)
	o.Title.TextColor3 = color
	o.Title.Size = UDim2.new(0.8, 0, 0, 90)
	UIKit.tween(o.Title, 0.4, { Size = UDim2.new(0.8, 0, 0, 56) }, Enum.EasingStyle.Back)
	o.Sub.Text = rarity:upper() .. (if mutationText ~= "" then "  •  " .. mutationText else "")
	o.Sub.TextColor3 = color
	o.Tag.Text = if result.IsNew then "🆕 NEW DISCOVERY!" else ""
	if rare then
		Cinematics.Shake(1.2, 0.6)
	end
	waitForDismiss(o, 7)
end

local function playEvolve(result)
	local o = overlay()
	local record = result.Creature
	local rarity, color, mutationText = describe(record)

	local before = table.clone(record)
	before.Stage = math.max(1, record.Stage - 1)
	if result.Mutated then
		before.Mutation = nil
	end
	local model = ctx.Models.BuildCreature(before)
	UIKit.setViewportModel(o.Viewport, model)
	o.Title.Text = result.FromName .. " is evolving..."
	o.Title.TextColor3 = C.Text
	spinRays(o, C.Gold)

	for i = 1, 4 do
		o.Flash.BackgroundTransparency = 0.3
		UIKit.tween(o.Flash, 0.35 - i * 0.05, { BackgroundTransparency = 1 })
		task.wait(0.5 - i * 0.08)
	end
	playSound(ctx.GameConfig.Sounds.Hatch, 0.9)
	o.Flash.BackgroundTransparency = 0
	UIKit.tween(o.Flash, 0.8, { BackgroundTransparency = 1 })
	UIKit.setViewportModel(o.Viewport, ctx.Models.BuildCreature(record))
	o.Rays.BackgroundColor3 = color
	Cinematics.Shake(1, 0.5)

	o.Tag.Text = if result.Mutated then "🧬 IT MUTATED!" else "✨ EVOLVED! ✨"
	o.Title.Text = ctx.CreatureData.GetDisplayName(record)
	o.Title.TextColor3 = color
	o.Sub.Text = rarity:upper() .. " • " .. ctx.CreatureData.Stages[record.Stage].Name:upper() .. (if mutationText ~= "" then "  •  " .. mutationText else "")
	o.Sub.TextColor3 = color
	waitForDismiss(o, 6)
end

local function pump()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		local ok, err = pcall(item.Fn, item.Data)
		if not ok then
			warn("[Cinematics] " .. tostring(err))
		end
	end
	running = false
end

function Cinematics.Hatch(result)
	table.insert(queue, { Fn = playHatch, Data = result })
	task.spawn(pump)
end

function Cinematics.Evolve(result)
	table.insert(queue, { Fn = playEvolve, Data = result })
	task.spawn(pump)
end

function Cinematics.Init(context)
	ctx = context
	gui = UIKit.new("ScreenGui", {
		Name = "HatchOrDieCinematics",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

return Cinematics
