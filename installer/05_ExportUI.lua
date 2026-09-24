-- HATCH OR DIE - EXPORT UI (optional): copies the game's HUD + menu window into StarterGui
-- so you can design it visually in Studio. Paste into the command bar after Parts 1-4.
-- The game uses StarterGui.HatchOrDieUI automatically. Keep the element NAMES; change anything else.
local StarterGui = game:GetService("StarterGui")
local client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("HatchOrDieClient")

if not client or not client:FindFirstChild("Layout") then
	warn("❌ Run installer Part 4 (client) first.")
elseif StarterGui:FindFirstChild("HatchOrDieUI") then
	warn("⚠️ StarterGui.HatchOrDieUI already exists, so nothing was changed (your edits are safe). Delete or rename it first to export a fresh copy.")
else
	local Layout = require(client.Layout)
	local gui = Layout.Build()
	-- These cover the screen, so they start hidden. Tick Visible on to edit them.
	gui:FindFirstChild("DeathOverlay").Visible = false
	gui:FindFirstChild("Window").Visible = false
	gui.Parent = StarterGui
	game:GetService("Selection"):Set({ gui })
	print("✅ UI exported to StarterGui.HatchOrDieUI. Edit it freely - just keep the element names. Press Play to see it in game.")
end
