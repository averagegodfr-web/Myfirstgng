-- Small UI helpers so every screen shares one look.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIKit = {}

local viewportSetters = setmetatable({}, { __mode = "k" })

UIKit.Colors = {
	Bg = Color3.fromRGB(16, 18, 28),
	Panel = Color3.fromRGB(28, 31, 46),
	PanelLight = Color3.fromRGB(44, 48, 70),
	Text = Color3.fromRGB(245, 245, 250),
	SubText = Color3.fromRGB(170, 175, 195),
	Gold = Color3.fromRGB(255, 205, 70),
	Good = Color3.fromRGB(110, 230, 120),
	Bad = Color3.fromRGB(255, 90, 90),
	Day = Color3.fromRGB(255, 185, 60),
	Night = Color3.fromRGB(110, 90, 255),
	Berry = Color3.fromRGB(255, 110, 150),
	Accent = Color3.fromRGB(90, 200, 255),
}

UIKit.FamilyIcons = { Sprout = "🌿", Ember = "🔥", Shade = "🌑" }

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, px: number)
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UIKit.panel(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = UIKit.new("Frame", defaults)
	UIKit.corner(frame, 12)
	UIKit.stroke(frame, Color3.new(0, 0, 0), 2, 0.5)
	return frame
end

function UIKit.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		TextWrapped = true,
		TextStrokeTransparency = 0.6,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	return UIKit.new("TextLabel", defaults)
end

function UIKit.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local defaults = {
		BackgroundColor3 = UIKit.Colors.PanelLight,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UIKit.Colors.Text,
		TextScaled = true,
		TextStrokeTransparency = 0.5,
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = UIKit.new("TextButton", defaults)
	UIKit.corner(button, 10)
	UIKit.stroke(button, Color3.new(0, 0, 0), 2, 0.4)
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = button })
	UIKit.decorate(button)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Hover/press bounce for any button, including ones a designer made in Studio. Safe to call twice.
local decorated = setmetatable({}, { __mode = "k" })
function UIKit.decorate(button: GuiButton)
	if decorated[button] or not button:IsA("GuiButton") then
		return
	end
	decorated[button] = true
	local scale = button:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = button })
	local base = scale.Scale
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = base * 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = base })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.06, { Scale = base * 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = base })
	end)
end

-- Multiplies a UDim2 (used to animate designer-sized frames relative to their own size).
function UIKit.scaleUDim2(size: UDim2, k: number): UDim2
	return UDim2.new(size.X.Scale * k, size.X.Offset * k, size.Y.Scale * k, size.Y.Offset * k)
end

function UIKit.bar(props: { [string]: any }, fillColor: Color3): (Frame, Frame)
	local back = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BorderSizePixel = 0,
	})
	for k, v in props do
		(back :: any)[k] = v
	end
	UIKit.corner(back, 6)
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = back,
	})
	UIKit.corner(fill, 6)
	return back, fill
end

function UIKit.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UIKit.formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

function UIKit.formatNumber(n: number): string
	if n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

-- Renders a model in a ViewportFrame, optionally spinning. Destroying the viewport stops the spin.
function UIKit.viewport(props: { [string]: any }, model: Model?, spin: boolean?): ViewportFrame
	local defaults = {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(160, 160, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	}
	for k, v in props do
		defaults[k] = v
	end
	local vp = UIKit.new("ViewportFrame", defaults)
	local camera = UIKit.new("Camera", { FieldOfView = 40, Parent = vp })
	vp.CurrentCamera = camera

	local current: Model? = nil
	local angle = 0
	local connection: RBXScriptConnection? = nil

	local function setModel(newModel: Model?)
		if current then
			current:Destroy()
		end
		current = newModel
		if not newModel then
			return
		end
		newModel:PivotTo(CFrame.new())
		newModel.Parent = vp
		local boxCFrame, size = newModel:GetBoundingBox()
		local center = Vector3.new(0, boxCFrame.Position.Y, 0)
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0.45, 0.35, -1).Unit * distance, center)
	end
	setModel(model)

	if spin then
		connection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 0.9
			if current and current.Parent then
				current:PivotTo(CFrame.Angles(0, angle, 0))
			end
		end)
		vp.Destroying:Connect(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end

	viewportSetters[vp] = setModel
	return vp
end

function UIKit.setViewportModel(vp: ViewportFrame, model: Model?)
	local setter = viewportSetters[vp]
	if setter then
		setter(model)
	end
end

return UIKit
