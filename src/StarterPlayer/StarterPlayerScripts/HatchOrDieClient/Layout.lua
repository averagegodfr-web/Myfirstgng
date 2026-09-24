-- The default look of the HUD and menu window. Only builds instances; no gameplay logic.
-- Hud/Panels find every element BY NAME, so a designer can export this layout to StarterGui,
-- restyle it freely in Studio, and the game will use their version (see README "Editing the UI").
--
-- Responsive rules used everywhere:
--  * Each HUD group is sized relative to SCREEN HEIGHT (SizeConstraint = RelativeYY), so it keeps its
--    shape on phones, tablets, PCs and 4K. Designed at 720p: yy(300, 62) = 300x62 px on a 720px-tall screen.
--  * Everything inside a group uses Scale only, so it grows/shrinks with the group.
--  * Round/square buttons have UIAspectRatioConstraint; groups have UISizeConstraint minimums.
--  * Each group has a UIScale named "AutoScale" (shrinks on narrow screens) and some have a
--    "TouchPosition" attribute (used on phones/tablets to dodge Roblox's thumbstick and jump button).
--  * The ScreenGui respects phone notches (ScreenInsets = DeviceSafeInsets).
local StarterGui = game:GetService("StarterGui")

local UIKit = require(script.Parent.UIKit)

local Layout = {}

Layout.GUI_NAME = "HatchOrDieUI"
local C = UIKit.Colors
local REF = 720

local function named(inst: Instance, name: string)
	inst.Name = name
	return inst
end

local function yy(width: number, height: number): UDim2
	return UDim2.fromScale(width / REF, height / REF)
end

-- Turns a top-level frame into a responsive group.
local function group(frame: GuiObject, minHeight: number?): GuiObject
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	UIKit.new("UIScale", { Name = "AutoScale", Parent = frame })
	if minHeight then
		local ratio = (frame.Size.X.Scale / frame.Size.Y.Scale)
		UIKit.new("UISizeConstraint", { MinSize = Vector2.new(math.floor(minHeight * ratio), minHeight), Parent = frame })
	end
	return frame
end

local function aspect(frame: Instance, ratio: number)
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = ratio, Parent = frame })
end

local function scalePadding(frame: Instance, amount: number)
	UIKit.new("UIPadding", {
		PaddingTop = UDim.new(amount, 0),
		PaddingBottom = UDim.new(amount, 0),
		PaddingLeft = UDim.new(amount * 0.6, 0),
		PaddingRight = UDim.new(amount * 0.6, 0),
		Parent = frame,
	})
end

local function bar(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3)
	local back, fill = UIKit.bar({ Position = position, Size = size, Parent = parent }, color)
	back.Name = name .. "Back"
	fill.Name = name
	return back, fill
end

local function text(props)
	props.Size = props.Size or UDim2.fromScale(1, 1)
	return UIKit.text(props)
end

function Layout.BuildHud(gui: ScreenGui)
	-- Phase banner (top center)
	local banner = group(UIKit.panel({ Name = "PhaseBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.01), Size = yy(300, 62), Parent = gui }))
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 120, 170), C.Panel), Parent = banner })
	named(text({ Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.94, 0.55), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.3, Text = "☀️ DAY 1", TextColor3 = Color3.fromRGB(255, 225, 130), Parent = banner }), "PhaseTitle")
	named(text({ Position = UDim2.fromScale(0.03, 0.62), Size = UDim2.fromScale(0.94, 0.3), TextColor3 = C.SubText, Text = "PREPARE • 0:40", Parent = banner }), "PhaseSub")

	local objective = group(named(text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.105),
		Size = yy(440, 24),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = C.Bg,
		Font = Enum.Font.GothamMedium,
		Text = "🥚 Your first egg is hatching... get ready!",
		Parent = gui,
	}), "Objective"))
	UIKit.corner(objective, 8)

	-- Boss bar (under the objective)
	local boss = group(UIKit.new("Frame", { Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.15), Size = yy(440, 42), BackgroundTransparency = 1, Parent = gui }))
	named(text({ Size = UDim2.fromScale(1, 0.44), Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 120, 90), TextStrokeTransparency = 0.2, Text = "Rotwood Colossus", Parent = boss }), "BossName")
	local bossBack = bar(boss, "BossFill", UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0.45), Color3.fromRGB(220, 50, 50))
	UIKit.stroke(bossBack, Color3.new(0, 0, 0), 2, 0.2)

	-- Currencies (top left)
	local currencies = group(UIKit.panel({ Name = "Currencies", Position = UDim2.fromScale(0.008, 0.012), Size = yy(150, 92), Parent = gui }), 60)
	scalePadding(currencies, 0.06)
	UIKit.new("UIListLayout", { Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = currencies })
	for i, row in { { "Coins", "🪙 0", C.Gold }, { "Berries", "🍓 0", C.Berry }, { "Best", "🏆 Best: Night 0", C.Text } } do
		named(text({ LayoutOrder = i, Size = UDim2.fromScale(1, 0.31), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = row[3], Font = Enum.Font.FredokaOne, Text = row[2], Parent = currencies }), row[1])
	end

	-- Creature card (left middle)
	local card = group(UIKit.panel({ Name = "CreatureCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.008, 0.45), Size = yy(230, 128), Parent = gui }), 84)
	scalePadding(card, 0.06)
	named(text({ Size = UDim2.fromScale(1, 0.2), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "🌿 Sproutling", Parent = card }), "CreatureName")
	named(text({ Position = UDim2.fromScale(0, 0.21), Size = UDim2.fromScale(1, 0.13), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Text = "Common • Baby • Stage 1/3", Parent = card }), "CreatureStage")
	bar(card, "CreatureHPFill", UDim2.fromScale(0, 0.37), UDim2.fromScale(1, 0.13), C.Good)
	named(text({ Position = UDim2.fromScale(0, 0.37), Size = UDim2.fromScale(1, 0.13), TextStrokeTransparency = 0.2, Text = "140 / 140", Parent = card }), "CreatureHPText")
	bar(card, "CreatureXPFill", UDim2.fromScale(0, 0.53), UDim2.fromScale(1, 0.08), C.Accent)
	named(text({ Position = UDim2.fromScale(0, 0.63), Size = UDim2.fromScale(1, 0.12), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Text = "XP 0/100 • Nights 0/1", Parent = card }), "CreatureXPText")
	UIKit.button({ Name = "EvolveButton", Position = UDim2.fromScale(0, 0.79), Size = UDim2.fromScale(1, 0.21), BackgroundColor3 = C.Gold, TextColor3 = Color3.fromRGB(40, 25, 0), Text = "✨ EVOLVE!", Parent = card })

	-- Actions: commands, feed, ability (bottom right; moves up on touch devices)
	local actions = group(UIKit.new("Frame", { Name = "Actions", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(0.992, 0.985), Size = yy(250, 170), BackgroundTransparency = 1, Parent = gui }))
	actions:SetAttribute("TouchPosition", UDim2.fromScale(0.992, 0.64))
	for i, mode in { "Follow", "Attack", "Defend" } do
		UIKit.button({ Name = "Mode" .. mode, Position = UDim2.fromScale((i - 1) / 3 + 0.005, 0), Size = UDim2.fromScale(0.323, 0.2), Text = ("%s [%d]"):format(mode, i), Parent = actions })
	end
	local feed = UIKit.button({ Name = "FeedButton", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.06, 1), Size = UDim2.fromScale(0.38, 0.56), BackgroundColor3 = Color3.fromRGB(150, 50, 80), Text = "🍓 FEED [F]\nx0", Parent = actions })
	aspect(feed, 1)
	local ability = UIKit.button({ Name = "AbilityButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromScale(0.48, 0.72), BackgroundColor3 = Color3.fromRGB(80, 60, 170), Text = "ABILITY\n[Q]", Parent = actions })
	aspect(ability, 1)
	ability:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local cooldown = UIKit.new("Frame", { Name = "AbilityCooldown", Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = ability })
	UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cooldown })

	-- Menu bar (bottom center)
	local menu = group(UIKit.new("Frame", { Name = "Menu", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.985), Size = yy(330, 58), BackgroundTransparency = 1, Parent = gui }))
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.025, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	for i, item in { { "Eggs", "🥚 Eggs" }, { "Creatures", "🐲 Creatures" }, { "Shop", "🛒 Shop" } } do
		UIKit.button({ Name = "Menu" .. item[1], LayoutOrder = i, Size = UDim2.fromScale(0.31, 0.93), BackgroundColor3 = C.Panel, Text = item[2], Parent = menu })
	end
	local badge = named(text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.95, 0.05), Size = UDim2.fromScale(0.45, 0.45), BackgroundTransparency = 0, BackgroundColor3 = C.Bad, Font = Enum.Font.FredokaOne, Text = "1", ZIndex = 3, Parent = menu:FindFirstChild("MenuEggs") }), "EggBadge")
	aspect(badge, 1)
	UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })

	-- Incubator timer (above the menu)
	local incubator = group(UIKit.panel({ Name = "Incubator", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.89), Size = yy(300, 46), Parent = gui }))
	named(text({ Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.46), Font = Enum.Font.FredokaOne, Text = "🥚 Forest Egg hatching... 0:10", Parent = incubator }), "IncubatorText")
	bar(incubator, "IncubatorFill", UDim2.fromScale(0.03, 0.62), UDim2.fromScale(0.94, 0.22), C.Gold)

	-- Notifications (top right)
	local toasts = group(UIKit.new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.992, 0.012), Size = yy(320, 190), BackgroundTransparency = 1, Parent = gui }))
	UIKit.new("UIListLayout", { Padding = UDim.new(0.02, 0), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toasts })

	-- Center messages (relative to the whole screen)
	named(text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.21), Size = UDim2.fromScale(0.8, 0.055), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.1, TextColor3 = C.Gold, Text = "🌟 PLAYER HATCHED A CELESTIAL DRAGON!", Parent = gui }), "Announcement")
	named(text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.8, 0.125), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "NIGHT 1", TextColor3 = Color3.fromRGB(190, 170, 255), Parent = gui }), "BigTitle")
	named(text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.445), Size = UDim2.fromScale(0.6, 0.045), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.2, Text = "SURVIVE UNTIL MORNING", Parent = gui }), "BigSub")

	local result = group(UIKit.panel({ Name = "NightResult", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = yy(360, 190), Parent = gui }), 130)
	scalePadding(result, 0.06)
	named(text({ Size = UDim2.fromScale(1, 0.22), Font = Enum.Font.FredokaOne, TextColor3 = C.Gold, Text = "☀️ NIGHT 1 SURVIVED!", Parent = result }), "ResultTitle")
	local body = named(text({ Position = UDim2.fromScale(0, 0.27), Size = UDim2.fromScale(1, 0.73), TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, Text = "🪙 +37 coins\n✨ +55 creature XP\n🍓 +2 berries", Parent = result }), "ResultBody")
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 30, Parent = body })

	local death = named(text({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 0, 0), BackgroundTransparency = 0.55, Text = "💀 YOU FELL\nYou'll return at dawn... if anyone survives.", Font = Enum.Font.FredokaOne, ZIndex = 0, Parent = gui }), "DeathOverlay")
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 48, Parent = death })
end

function Layout.BuildWindow(gui: ScreenGui)
	local window = UIKit.panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.8), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.05, ZIndex = 5, Parent = gui })
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 720), Parent = window })
	scalePadding(window, 0.025)
	named(text({ Size = UDim2.fromScale(0.85, 0.08), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "🥚 EGGS", Parent = window }), "WindowTitle")
	local close = UIKit.button({ Name = "WindowClose", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.1, 0.08), BackgroundColor3 = C.Bad, Text = "X", Parent = window })
	aspect(close, 1.25)
	UIKit.new("Frame", { Name = "WindowContent", Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.9), BackgroundTransparency = 1, Parent = window })
end

-- Builds a complete default ScreenGui (used for the in-game default and for the StarterGui export).
function Layout.Build(): ScreenGui
	local gui = UIKit.new("ScreenGui", {
		Name = Layout.GUI_NAME,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	})
	Layout.BuildHud(gui)
	Layout.BuildWindow(gui)
	return gui
end

-- Uses the designer's StarterGui.HatchOrDieUI when present, otherwise the built-in layout.
function Layout.Obtain(player: Player): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local template = StarterGui:FindFirstChild(Layout.GUI_NAME)
	local gui
	if template then
		gui = playerGui:WaitForChild(Layout.GUI_NAME, 10)
		if not gui then
			gui = template:Clone()
		end
	else
		gui = Layout.Build()
	end
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	return gui
end

-- Finds a UI element by name anywhere in the gui. Missing elements are replaced by hidden
-- placeholders so a designer deleting something never breaks the game.
function Layout.Finder(gui: ScreenGui)
	local missing = UIKit.new("Frame", { Name = "MissingElements", Visible = false, Parent = gui })
	return function(name: string, className: string?): any
		local found = gui:FindFirstChild(name, true)
		if found then
			return found
		end
		warn(("[HatchOrDie UI] '%s' not found in %s - add an element with that name to show it."):format(name, gui.Name))
		return UIKit.new(className or "TextButton", { Name = name, Parent = missing })
	end
end

-- Runtime responsiveness: shrink groups on narrow screens and move TouchPosition groups on phones.
function Layout.MakeResponsive(gui: ScreenGui)
	local UserInputService = game:GetService("UserInputService")
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local scales = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("UIScale") and d.Name == "AutoScale" then
			table.insert(scales, d)
		elseif isTouch and d:IsA("GuiObject") then
			local touchPosition = d:GetAttribute("TouchPosition")
			if typeof(touchPosition) == "UDim2" then
				d.Position = touchPosition
			end
		end
	end
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local ratio = viewport.X / math.max(viewport.Y, 1)
		-- 16:9 and wider = 1. 4:3 tablets ~0.83. Portrait screens bottom out at 0.45.
		local scale = math.clamp(ratio / 1.6, 0.45, 1)
		for _, s in scales do
			s.Scale = scale
		end
	end
	fit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

return Layout
