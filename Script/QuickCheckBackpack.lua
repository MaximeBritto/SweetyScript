-- QuickCheckBackpack.lua
-- Vérification rapide que la hotbar personnalisée fonctionne
-- À placer dans StarterPlayer > StarterPlayerScripts (temporaire, pour debug)

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

print("\n🔍 [CHECK] Vérification rapide de la hotbar...")

-- Attendre 3 secondes pour laisser le temps à tout de se charger
task.wait(3)

local issues = {}
local warnings = {}

-- 1. Vérifier que la hotbar par défaut est désactivée
local success, isDefaultEnabled = pcall(function()
	return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
end)

if success then
	if isDefaultEnabled then
		table.insert(issues, "❌ Hotbar par défaut ENCORE ACTIVE")
	else
		print("✅ Hotbar par défaut désactivée")
	end
else
	table.insert(warnings, "⚠️ Impossible de vérifier l'état de la hotbar par défaut")
end

-- 2. Vérifier que CustomBackpack existe
local playerGui = player:FindFirstChild("PlayerGui")
if playerGui then
	local customBackpack = playerGui:FindFirstChild("CustomBackpack")
	if customBackpack then
		print("✅ CustomBackpack ScreenGui trouvé")
		
		-- 3. Vérifier que la hotbar est visible
		local hotbar = customBackpack:FindFirstChild("CustomHotbar")
		if hotbar then
			print("✅ CustomHotbar trouvé")
			
			if hotbar.Visible then
				print("✅ CustomHotbar visible")
			else
				table.insert(issues, "❌ CustomHotbar existe mais n'est pas visible")
			end
			
			-- Compter les slots
			local slotCount = 0
			for _, child in ipairs(hotbar:GetChildren()) do
				if child.Name:match("HotbarSlot_") then
					slotCount = slotCount + 1
				end
			end
			
			if slotCount >= 9 then
				print("✅ CustomHotbar a", slotCount, "slots")
			else
				table.insert(warnings, "⚠️ CustomHotbar n'a que " .. slotCount .. " slots (attendu: 9)")
			end
		else
			table.insert(issues, "❌ CustomHotbar NON TROUVÉ dans CustomBackpack")
		end
	else
		table.insert(issues, "❌ CustomBackpack ScreenGui NON TROUVÉ")
	end
else
	table.insert(issues, "❌ PlayerGui NON TROUVÉ")
end

-- 4. Vérifier le Backpack
local backpack = player:FindFirstChild("Backpack")
if backpack then
	local toolCount = #backpack:GetChildren()
	print("✅ Backpack trouvé avec", toolCount, "outil(s)")
else
	table.insert(warnings, "⚠️ Backpack non trouvé")
end

-- Afficher le résumé
print("\n" .. string.rep("=", 50))
if #issues == 0 and #warnings == 0 then
	print("✅ TOUT FONCTIONNE PARFAITEMENT !")
	print("   La hotbar personnalisée est opérationnelle.")
else
	if #issues > 0 then
		print("❌ PROBLÈMES CRITIQUES DÉTECTÉS:")
		for i, issue in ipairs(issues) do
			print("   " .. i .. ".", issue)
		end
	end
	
	if #warnings > 0 then
		print("\n⚠️ AVERTISSEMENTS:")
		for i, warning in ipairs(warnings) do
			print("   " .. i .. ".", warning)
		end
	end
	
	print("\n💡 SUGGESTIONS:")
	if #issues > 0 then
		print("   - Vérifier la console (F9) pour les erreurs")
		print("   - Lancer Script/DiagnosticUILoading.lua pour plus de détails")
		print("   - Vérifier que CustomBackpack.lua est dans StarterPlayerScripts")
	end
end
print(string.rep("=", 50) .. "\n")
