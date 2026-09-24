-- Lighting presets for each phase. The same map reads completely differently per preset.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Atmosphere = {}

local PRESETS = {
	Day = {
		Lighting = {
			Brightness = 2.2,
			Ambient = Color3.fromRGB(110, 110, 120),
			OutdoorAmbient = Color3.fromRGB(140, 140, 150),
			FogEnd = 900,
			FogColor = Color3.fromRGB(190, 215, 235),
			ExposureCompensation = 0,
		},
		Atmosphere = { Density = 0.25, Color = Color3.fromRGB(199, 220, 240), Decay = Color3.fromRGB(106, 112, 125), Glare = 0, Haze = 1 },
		Color = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.15, Contrast = 0.05, Brightness = 0 },
	},
	Night = {
		Lighting = {
			Brightness = 1,
			Ambient = Color3.fromRGB(40, 45, 75),
			OutdoorAmbient = Color3.fromRGB(55, 60, 100),
			FogEnd = 260,
			FogColor = Color3.fromRGB(15, 18, 35),
			ExposureCompensation = 0.2,
		},
		Atmosphere = { Density = 0.4, Color = Color3.fromRGB(40, 45, 80), Decay = Color3.fromRGB(20, 20, 40), Glare = 0, Haze = 2 },
		Color = { TintColor = Color3.fromRGB(190, 200, 255), Saturation = -0.1, Contrast = 0.15, Brightness = 0 },
	},
	BloodMoon = {
		Lighting = {
			Brightness = 1,
			Ambient = Color3.fromRGB(85, 30, 30),
			OutdoorAmbient = Color3.fromRGB(110, 40, 40),
			FogEnd = 220,
			FogColor = Color3.fromRGB(60, 5, 5),
			ExposureCompensation = 0.2,
		},
		Atmosphere = { Density = 0.45, Color = Color3.fromRGB(120, 20, 20), Decay = Color3.fromRGB(60, 10, 10), Glare = 0, Haze = 2 },
		Color = { TintColor = Color3.fromRGB(255, 170, 170), Saturation = 0, Contrast = 0.2, Brightness = 0 },
	},
	Nightmare = {
		Lighting = {
			Brightness = 0.8,
			Ambient = Color3.fromRGB(60, 20, 40),
			OutdoorAmbient = Color3.fromRGB(80, 30, 55),
			FogEnd = 150,
			FogColor = Color3.fromRGB(30, 0, 15),
			ExposureCompensation = 0.1,
		},
		Atmosphere = { Density = 0.55, Color = Color3.fromRGB(70, 10, 40), Decay = Color3.fromRGB(30, 0, 20), Glare = 0, Haze = 3 },
		Color = { TintColor = Color3.fromRGB(255, 130, 150), Saturation = -0.4, Contrast = 0.3, Brightness = -0.02 },
	},
	Apocalypse = {
		Lighting = {
			Brightness = 1.4,
			Ambient = Color3.fromRGB(110, 50, 20),
			OutdoorAmbient = Color3.fromRGB(140, 60, 25),
			FogEnd = 200,
			FogColor = Color3.fromRGB(120, 40, 10),
			ExposureCompensation = 0.2,
		},
		Atmosphere = { Density = 0.5, Color = Color3.fromRGB(200, 80, 30), Decay = Color3.fromRGB(90, 30, 10), Glare = 0.5, Haze = 3 },
		Color = { TintColor = Color3.fromRGB(255, 175, 120), Saturation = 0.1, Contrast = 0.3, Brightness = 0 },
	},
}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect
local clockTarget = 8
local clockRate = 0

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function Atmosphere.Init()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
	atmosphere = ensure("Atmosphere", "HOD_Atmosphere") :: Atmosphere
	colorCorrection = ensure("ColorCorrectionEffect", "HOD_Color") :: ColorCorrectionEffect
	local bloom = ensure("BloomEffect", "HOD_Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ClockTime = 8

	-- Continuous clock so the sun visibly moves through each phase.
	task.spawn(function()
		while true do
			local dt = task.wait(0.2)
			if clockRate > 0 then
				local diff = (clockTarget - Lighting.ClockTime) % 24
				local step = math.min(diff, clockRate * dt)
				Lighting.ClockTime = (Lighting.ClockTime + step) % 24
			end
		end
	end)
end

function Atmosphere.Apply(presetName: string, tweenTime: number?)
	local preset = PRESETS[presetName] or PRESETS.Night
	local info = TweenInfo.new(tweenTime or 4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, preset.Lighting):Play()
	TweenService:Create(atmosphere, info, preset.Atmosphere):Play()
	TweenService:Create(colorCorrection, info, preset.Color):Play()
end

-- Moves the clock forward to `target` hours over `duration` seconds.
function Atmosphere.AdvanceClock(target: number, duration: number)
	clockTarget = target % 24
	local diff = (clockTarget - Lighting.ClockTime) % 24
	clockRate = diff / math.max(duration, 0.1)
end

return Atmosphere
