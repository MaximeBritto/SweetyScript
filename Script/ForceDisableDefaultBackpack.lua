-- ForceDisableDefaultBackpack.lua
-- Script qui force la désactivation de la hotbar par défaut de Roblox
-- À placer dans StarterPlayer > StarterPlayerScripts
-- Ce script s'exécute AVANT CustomBackpack pour garantir que la hotbar est désactivée

local StarterGui = game:GetService("StarterGui")

print("🚫 [FORCE] Désactivation immédiate de la hotbar par défaut...")

-- Fonction pour désactiver la hotbar
local function forceDisable()
	local success = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	return success
end

-- Tentative immédiate
if forceDisable() then
	print("✅ [FORCE] Hotbar désactivée immédiatement")
else
	warn("⚠️ [FORCE] Échec de la désactivation immédiate")
end

-- Retry agressif pendant 3 secondes
local startTime = tick()
local attempts = 0
while (tick() - startTime) < 3 do
	attempts = attempts + 1
	if forceDisable() then
		if attempts > 1 then
			print("✅ [FORCE] Hotbar désactivée après", attempts, "tentatives")
		end
		break
	end
	task.wait(0.1)
end

-- Vérification finale après 1 seconde
task.delay(1, function()
	forceDisable()
	print("✅ [FORCE] Vérification finale effectuée")
end)

-- Vérification continue toutes les 0.5 secondes pendant 5 secondes
-- (au cas où Roblox réactive la hotbar)
task.spawn(function()
	for i = 1, 10 do
		task.wait(0.5)
		forceDisable()
	end
	print("✅ [FORCE] Surveillance terminée après 5 secondes")
end)
