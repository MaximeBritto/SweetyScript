-- DebugBackpackSimple.lua
-- Debug ultra-simple pour voir où le CustomBackpack bloque
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("\n" .. string.rep("=", 60))
print("🔍 DEBUG BACKPACK SIMPLE")
print(string.rep("=", 60))

-- Vérifier toutes les 0.5 secondes pendant 10 secondes
for i = 1, 20 do
	task.wait(0.5)
	
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local customBackpack = playerGui:FindFirstChild("CustomBackpack")
		local hotbar = customBackpack and customBackpack:FindFirstChild("CustomHotbar")
		
		if hotbar then
			print("✅ [" .. i .. "] CustomHotbar TROUVÉ et", hotbar.Visible and "VISIBLE" or "INVISIBLE")
			
			-- Compter les slots
			local slotCount = 0
			for _, child in ipairs(hotbar:GetChildren()) do
				if child.Name:match("HotbarSlot_") then
					slotCount = slotCount + 1
				end
			end
			print("   → Nombre de slots:", slotCount)
			
			-- Arrêter le debug si tout est OK
			if slotCount >= 9 then
				print("✅ TOUT EST OK ! Arrêt du debug.")
				break
			end
		else
			print("⏳ [" .. i .. "] CustomHotbar pas encore créé...")
		end
	else
		print("❌ [" .. i .. "] PlayerGui introuvable")
	end
end

print(string.rep("=", 60))
print("🔍 FIN DU DEBUG")
print(string.rep("=", 60) .. "\n")
