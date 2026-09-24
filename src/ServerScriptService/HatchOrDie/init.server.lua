-- HATCH OR DIE server bootstrap. Services are loaded into a shared Registry to avoid circular requires,
-- then Init() (wire signals) runs for all of them before Start() (begin work).
local Registry = require(script.Registry)

local ORDER = {
	"DataService",
	"EconomyService",
	"EnemyService",
	"CreatureService",
	"EggService",
	"CombatService",
	"BossService",
	"WorldService",
	"ShopService",
	"CycleService",
}

for _, name in ORDER do
	Registry[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Init then
		service.Init()
	end
end

for _, name in ORDER do
	local service = Registry[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[HATCH OR DIE] Server started")
