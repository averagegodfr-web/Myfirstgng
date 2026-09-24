-- The default look of the HUD and menu window. Only builds instances; no gameplay logic.
-- Hud/Panels find every element BY NAME, so a designer can export this layout to StarterGui,
-- restyle it freely in Studio, and the game will use their version (see README "Editing the UI").
local StarterGui = game:GetService("StarterGui")

local UIKit = require(script.Parent.UIKit)

local Layout = {}

Layout.GUI_NAME = "HatchOrDieUI"
local C = UIKit.Colors

local function named(inst: Instance, name: string)
	inst.Name = name
	return inst
end

local function bar(parent: Instance, name: string, props, color: Color3)
	props.Parent = parent
	local back, fill = UIKit.bar(props, color)
	back.Name = name .. "Back"
	fill.Name = name
	return back, fill
end

function Layout.BuildHud(gui: ScreenGui)
	-- Phase banner
	local banner = UIKit.panel({ Name = "PhaseBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(300, 62), Parent = gui })
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 120, 170), C.Panel), Parent = banner })
	named(UIKit.text({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.3, Text = "☀️ DAY 1", TextColor3 = Color3.fromRGB(255, 225, 130), Parent = banner }), "PhaseTitle")
	named(UIKit.text({ Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 38), TextColor3 = C.SubText, Text = "PREPARE • 0:40", Parent = banner }), "PhaseSub")

	local objective = named(UIKit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.new(0.6, 0, 0, 22),
		BackgroundTransparency = 0.45,
		BackgroundColor3 = C.Bg,
		Font = Enum.Font.GothamMedium,
		Text = "🥚 Your first egg is hatching... get ready!",
		Parent = gui,
	}), "Objective")
	UIKit.corner(objective, 8)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 22), Parent = objective })

	-- Boss bar
	local boss = UIKit.new("Frame", { Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.new(0.7, 0, 0, 42), BackgroundTransparency = 1, Parent = gui })
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 42), Parent = boss })
	named(UIKit.text({ Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 120, 90), TextStrokeTransparency = 0.2, Text = "Rotwood Colossus", Parent = boss }), "BossName")
	local bossBack = bar(boss, "BossFill", { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 18) }, Color3.fromRGB(220, 50, 50))
	UIKit.stroke(bossBack, Color3.new(0, 0, 0), 2, 0.2)

	-- Currencies
	local currencies = UIKit.panel({ Name = "Currencies", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(150, 92), Parent = gui })
	UIKit.padding(currencies, 6)
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), Parent = currencies })
	for _, row in { { "Coins", "🪙 0", C.Gold }, { "Berries", "🍓 0", C.Berry }, { "Best", "🏆 Best: Night 0", C.Text } } do
		named(UIKit.text({ Size = UDim2.new(1, 0, 0, 25), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = row[3], Font = Enum.Font.FredokaOne, Text = row[2], Parent = currencies }), row[1])
	end

	-- Creature card
	local card = UIKit.panel({ Name = "CreatureCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.45, 0), Size = UDim2.fromOffset(230, 128), Parent = gui })
	UIKit.padding(card, 8)
	named(UIKit.text({ Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "🌿 Sproutling", Parent = card }), "CreatureName")
	named(UIKit.text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Text = "Common • Baby • Stage 1/3", Parent = card }), "CreatureStage")
	bar(card, "CreatureHPFill", { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14) }, C.Good)
	named(UIKit.text({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14), TextStrokeTransparency = 0.2, Text = "140 / 140", Parent = card }), "CreatureHPText")
	bar(card, "CreatureXPFill", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 10) }, C.Accent)
	named(UIKit.text({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 14), TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Text = "XP 0/100 • Nights 0/1", Parent = card }), "CreatureXPText")
	UIKit.button({ Name = "EvolveButton", Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.Gold, TextColor3 = Color3.fromRGB(40, 25, 0), Text = "✨ EVOLVE!", Parent = card })

	-- Actions: commands, feed, ability
	local actions = UIKit.new("Frame", { Name = "Actions", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(250, 170), BackgroundTransparency = 1, Parent = gui })
	for i, mode in { "Follow", "Attack", "Defend" } do
		UIKit.button({ Name = "Mode" .. mode, Position = UDim2.new((i - 1) / 3, 2, 0, 0), Size = UDim2.new(1 / 3, -4, 0, 34), Text = ("%s [%d]"):format(mode, i), Parent = actions })
	end
	UIKit.button({ Name = "FeedButton", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, 0), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = Color3.fromRGB(150, 50, 80), Text = "🍓 FEED [F]\nx0", Parent = actions })
	local ability = UIKit.button({ Name = "AbilityButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(120, 120), BackgroundColor3 = Color3.fromRGB(80, 60, 170), Text = "ABILITY\n[Q]", Parent = actions })
	ability:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local cooldown = UIKit.new("Frame", { Name = "AbilityCooldown", Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = ability })
	UIKit.corner(cooldown, 60)

	-- Menu bar
	local menu = UIKit.new("Frame", { Name = "Menu", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(330, 58), BackgroundTransparency = 1, Parent = gui })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	for i, item in { { "Eggs", "🥚 Eggs" }, { "Creatures", "🐲 Creatures" }, { "Shop", "🛒 Shop" } } do
		UIKit.button({ Name = "Menu" .. item[1], LayoutOrder = i, Size = UDim2.fromOffset(104, 54), BackgroundColor3 = C.Panel, Text = item[2], Parent = menu })
	end
	local badge = named(UIKit.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = C.Bad, Font = Enum.Font.FredokaOne, Text = "1", ZIndex = 3, Parent = menu:FindFirstChild("MenuEggs") }), "EggBadge")
	UIKit.corner(badge, 12)

	-- Incubator timer
	local incubator = UIKit.panel({ Name = "Incubator", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(300, 46), Parent = gui })
	named(UIKit.text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), Font = Enum.Font.FredokaOne, Text = "🥚 Forest Egg hatching... 0:10", Parent = incubator }), "IncubatorText")
	bar(incubator, "IncubatorFill", { Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 0, 10) }, C.Gold)

	-- Messages
	local toasts = UIKit.new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(320, 260), BackgroundTransparency = 1, Parent = gui })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = toasts })

	local announcement = named(UIKit.text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Size = UDim2.new(0.8, 0, 0, 40), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.1, TextColor3 = C.Gold, Text = "🌟 PLAYER HATCHED A CELESTIAL DRAGON!", Parent = gui }), "Announcement")
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 38, Parent = announcement })
	named(UIKit.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.8, 0, 0, 90), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "NIGHT 1", TextColor3 = Color3.fromRGB(190, 170, 255), Parent = gui }), "BigTitle")
	named(UIKit.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 62), Size = UDim2.new(0.6, 0, 0, 32), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.2, Text = "SURVIVE UNTIL MORNING", Parent = gui }), "BigSub")

	local result = UIKit.panel({ Name = "NightResult", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(360, 190), Parent = gui })
	UIKit.padding(result, 12)
	named(UIKit.text({ Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.FredokaOne, TextColor3 = C.Gold, Text = "☀️ NIGHT 1 SURVIVED!", Parent = result }), "ResultTitle")
	named(UIKit.text({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), TextScaled = false, TextSize = 20, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, Text = "🪙 +37 coins\n✨ +55 creature XP\n🍓 +2 berries", Parent = result }), "ResultBody")

	local death = named(UIKit.text({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 0, 0), BackgroundTransparency = 0.55, Text = "💀 YOU FELL\nYou'll return at dawn... if anyone survives.", Font = Enum.Font.FredokaOne, ZIndex = 0, Parent = gui }), "DeathOverlay")
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 40, Parent = death })
end

function Layout.BuildWindow(gui: ScreenGui)
	local window = UIKit.panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.78), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.05, ZIndex = 5, Parent = gui })
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(760, 520), Parent = window })
	UIKit.padding(window, 12)
	named(UIKit.text({ Size = UDim2.new(1, -50, 0, 32), Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, Text = "🥚 EGGS", Parent = window }), "WindowTitle")
	UIKit.button({ Name = "WindowClose", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(40, 32), BackgroundColor3 = C.Bad, Text = "X", Parent = window })
	UIKit.new("Frame", { Name = "WindowContent", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, Parent = window })
end

-- Builds a complete default ScreenGui (used for the in-game default and for the StarterGui export).
function Layout.Build(): ScreenGui
	local gui = UIKit.new("ScreenGui", { Name = Layout.GUI_NAME, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
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

return Layout
