-- HATCH OR DIE - EXPORT UI (optional): copies the game's HUD + menu window into StarterGui
-- so you can design it visually in Studio. Paste into the command bar after Parts 1-4.
-- The game uses StarterGui.HatchOrDieUI automatically. Keep the element NAMES; change anything else.
--
-- The exported UI works on every screen: groups scale with screen height, contents use Scale,
-- round buttons keep their shape, phone notches are respected, and on phones the action buttons
-- move above Roblox's jump button (the "TouchPosition" attribute on Actions).
local StarterGui = game:GetService("StarterGui")
local client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("HatchOrDieClient")

if not client or not client:FindFirstChild("Layout") then
	warn("❌ Run installer Part 4 (client) first.")
else
	local existing = StarterGui:FindFirstChild("HatchOrDieUI")
	if existing then
		-- Keep the previous design as a disabled backup instead of deleting anyone's work.
		existing.Name = "HatchOrDieUI_Backup_" .. os.date("%H%M%S")
		existing.Enabled = false
		print("ℹ️ Your previous UI was kept as StarterGui." .. existing.Name .. " (disabled).")
	end
	-- Require a fresh copy so a re-installed Part 4 is picked up (the command bar caches requires).
	local Layout = require(client:Clone().Layout)
	local gui = Layout.Build()
	-- These cover the screen, so they start hidden. Tick Visible on to edit them.
	gui:FindFirstChild("DeathOverlay").Visible = false
	gui:FindFirstChild("Window").Visible = false
	gui.Parent = StarterGui
	game:GetService("Selection"):Set({ gui })
	print("✅ UI exported to StarterGui.HatchOrDieUI. Edit it freely - just keep the element names. Press Play to see it in game.")
	print("📱 Test other screens: Test tab > Device, then pick a phone or tablet.")
end
