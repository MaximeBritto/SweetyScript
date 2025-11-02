-- DiagnosticUILoading.lua
-- Script de diagnostic pour identifier les problèmes de chargement des UIs
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

print("\n" .. string.rep("=", 60))
print("🔍 DIAGNOSTIC UI LOADING - Début")
print(string.rep("=", 60))

-- 1. Vérifier PlayerDataReady RemoteEvent
task.spawn(function()
	print("\n📡 Vérification RemoteEvent PlayerDataReady...")
	local dataReadyEvent = ReplicatedStorage:FindFirstChild("PlayerDataReady")
	if dataReadyEvent then
		print("✅ PlayerDataReady RemoteEvent trouvé")
		print("   Type:", dataReadyEvent.ClassName)
		
		-- Écouter l'événement
		local received = false
		dataReadyEvent.OnClientEvent:Connect(function()
			received = true
			print("✅ PlayerDataReady RemoteEvent DÉCLENCHÉ à", tick())
		end)
		
		-- Vérifier après 3 secondes
		task.wait(3)
		if not received then
			warn("⚠️ PlayerDataReady RemoteEvent NON reçu après 3 secondes")
		end
	else
		warn("❌ PlayerDataReady RemoteEvent NON TROUVÉ dans ReplicatedStorage")
		print("   Contenu de ReplicatedStorage:")
		for _, child in ipairs(ReplicatedStorage:GetChildren()) do
			print("   -", child.Name, "(" .. child.ClassName .. ")")
		end
	end
end)

-- 2. Vérifier l'attribut DataReady
task.spawn(function()
	print("\n🏷️ Vérification Attribut DataReady...")
	local initialValue = player:GetAttribute("DataReady")
	print("   Valeur initiale:", tostring(initialValue))
	
	-- Surveiller les changements
	player.AttributeChanged:Connect(function(attrName)
		if attrName == "DataReady" then
			local value = player:GetAttribute("DataReady")
			print("✅ Attribut DataReady changé à:", tostring(value), "à", tick())
		end
	end)
	
	-- Vérifier après 3 secondes
	task.wait(3)
	local finalValue = player:GetAttribute("DataReady")
	if finalValue == true then
		print("✅ Attribut DataReady = true après 3 secondes")
	else
		warn("⚠️ Attribut DataReady =", tostring(finalValue), "après 3 secondes")
	end
end)

-- 3. Vérifier PlayerData
task.spawn(function()
	print("\n📦 Vérification PlayerData...")
	local playerData = player:FindFirstChild("PlayerData")
	if playerData then
		print("✅ PlayerData trouvé")
		print("   Contenu:")
		for _, child in ipairs(playerData:GetChildren()) do
			local valueStr = ""
			if child:IsA("ValueBase") then
				valueStr = " = " .. tostring(child.Value)
			end
			print("   -", child.Name, "(" .. child.ClassName .. ")" .. valueStr)
		end
	else
		warn("❌ PlayerData NON TROUVÉ")
		
		-- Attendre et réessayer
		task.wait(2)
		playerData = player:WaitForChild("PlayerData", 5)
		if playerData then
			print("✅ PlayerData trouvé après attente")
		else
			warn("❌ PlayerData toujours NON TROUVÉ après 5 secondes")
		end
	end
end)

-- 4. Vérifier le Backpack
task.spawn(function()
	print("\n🎒 Vérification Backpack...")
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		print("✅ Backpack trouvé")
		print("   Nombre d'outils:", #backpack:GetChildren())
	else
		warn("❌ Backpack NON TROUVÉ")
		
		-- Attendre et réessayer
		task.wait(2)
		backpack = player:WaitForChild("Backpack", 5)
		if backpack then
			print("✅ Backpack trouvé après attente")
		else
			warn("❌ Backpack toujours NON TROUVÉ après 5 secondes")
		end
	end
end)

-- 5. Vérifier la hotbar par défaut
task.spawn(function()
	print("\n🎮 Vérification Hotbar par défaut...")
	task.wait(2) -- Attendre que CustomBackpack ait essayé de la désactiver
	
	local success, isEnabled = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	
	if success then
		if isEnabled then
			warn("⚠️ Hotbar par défaut ENCORE ACTIVE")
		else
			print("✅ Hotbar par défaut désactivée")
		end
	else
		warn("❌ Impossible de vérifier l'état de la hotbar par défaut")
	end
end)

-- 6. Vérifier CustomBackpack UI
task.spawn(function()
	print("\n🖼️ Vérification CustomBackpack UI...")
	task.wait(3) -- Attendre que l'UI se charge
	
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		warn("❌ PlayerGui NON TROUVÉ")
		return
	end
	
	local customBackpack = playerGui:FindFirstChild("CustomBackpack")
	if customBackpack then
		print("✅ CustomBackpack ScreenGui trouvé")
		
		local hotbar = customBackpack:FindFirstChild("CustomHotbar")
		if hotbar then
			print("✅ CustomHotbar trouvé")
			print("   Visible:", hotbar.Visible)
			print("   Position:", tostring(hotbar.Position))
			print("   Size:", tostring(hotbar.Size))
			print("   Nombre de slots:", #hotbar:GetChildren())
		else
			warn("❌ CustomHotbar NON TROUVÉ dans CustomBackpack")
		end
	else
		warn("❌ CustomBackpack ScreenGui NON TROUVÉ dans PlayerGui")
		print("   Contenu de PlayerGui:")
		for _, child in ipairs(playerGui:GetChildren()) do
			print("   -", child.Name, "(" .. child.ClassName .. ")")
		end
	end
end)

-- 7. Résumé final après 5 secondes
task.delay(5, function()
	print("\n" .. string.rep("=", 60))
	print("🔍 DIAGNOSTIC UI LOADING - Résumé Final")
	print(string.rep("=", 60))
	
	local issues = {}
	
	-- Vérifier DataReady
	if player:GetAttribute("DataReady") ~= true then
		table.insert(issues, "❌ Attribut DataReady n'est pas true")
	end
	
	-- Vérifier PlayerData
	if not player:FindFirstChild("PlayerData") then
		table.insert(issues, "❌ PlayerData manquant")
	end
	
	-- Vérifier CustomBackpack
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local customBackpack = playerGui:FindFirstChild("CustomBackpack")
		if not customBackpack then
			table.insert(issues, "❌ CustomBackpack UI manquant")
		elseif not customBackpack:FindFirstChild("CustomHotbar") then
			table.insert(issues, "❌ CustomHotbar manquant")
		end
	else
		table.insert(issues, "❌ PlayerGui manquant")
	end
	
	-- Vérifier hotbar par défaut
	local success, isEnabled = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	if success and isEnabled then
		table.insert(issues, "⚠️ Hotbar par défaut encore active")
	end
	
	-- Afficher les résultats
	if #issues == 0 then
		print("✅ TOUT FONCTIONNE CORRECTEMENT")
	else
		print("⚠️ PROBLÈMES DÉTECTÉS:")
		for i, issue in ipairs(issues) do
			print("   " .. i .. ".", issue)
		end
	end
	
	print(string.rep("=", 60) .. "\n")
end)
