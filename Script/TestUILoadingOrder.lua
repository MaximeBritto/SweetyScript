-- TestUILoadingOrder.lua
-- Script de test pour vérifier l'ordre de chargement des UIs
-- À placer temporairement dans StarterPlayer > StarterPlayerScripts pour tester

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

print("🧪 [TEST] Début du test d'ordre de chargement des UIs")
print("🧪 [TEST] Timestamp:", os.time())

-- Tracker les événements
local events = {}

local function logEvent(eventName)
	local timestamp = tick()
	table.insert(events, {
		name = eventName,
		time = timestamp
	})
	print("🧪 [TEST]", eventName, "à", string.format("%.2f", timestamp))
end

-- 1. Vérifier si DataReady est déjà défini
if player:GetAttribute("DataReady") then
	logEvent("DataReady déjà défini (Attribute)")
end

-- 2. Écouter l'événement DataReady
local dataReadyEvent = ReplicatedStorage:WaitForChild("PlayerDataReady", 5)
if dataReadyEvent then
	logEvent("PlayerDataReady RemoteEvent trouvé")
	
	dataReadyEvent.OnClientEvent:Connect(function()
		logEvent("PlayerDataReady RemoteEvent déclenché")
	end)
else
	logEvent("PlayerDataReady RemoteEvent NON trouvé")
end

-- 3. Surveiller l'attribut DataReady
player.AttributeChanged:Connect(function(attrName)
	if attrName == "DataReady" then
		local value = player:GetAttribute("DataReady")
		logEvent("DataReady Attribute changé: " .. tostring(value))
	end
end)

-- 4. Vérifier la présence des UIs après 5 secondes
task.delay(5, function()
	logEvent("Vérification des UIs après 5 secondes")
	
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		logEvent("❌ PlayerGui non trouvé")
		return
	end
	
	-- Vérifier CustomBackpack
	local customBackpack = playerGui:FindFirstChild("CustomBackpack")
	if customBackpack then
		logEvent("✅ CustomBackpack trouvé")
		local hotbar = customBackpack:FindFirstChild("CustomHotbar")
		if hotbar then
			logEvent("✅ CustomHotbar trouvé")
		else
			logEvent("❌ CustomHotbar NON trouvé")
		end
	else
		logEvent("❌ CustomBackpack NON trouvé")
	end
	
	-- Vérifier si la hotbar par défaut est désactivée
	local coreGuiEnabled = true
	pcall(function()
		coreGuiEnabled = game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	
	if coreGuiEnabled then
		logEvent("⚠️ Hotbar par défaut ENCORE ACTIVE")
	else
		logEvent("✅ Hotbar par défaut désactivée")
	end
	
	-- Afficher le résumé
	print("\n🧪 [TEST] ===== RÉSUMÉ DES ÉVÉNEMENTS =====")
	for i, event in ipairs(events) do
		print(string.format("🧪 [TEST] %d. %s", i, event.name))
	end
	print("🧪 [TEST] =====================================\n")
end)

-- 5. Test final après 10 secondes
task.delay(10, function()
	logEvent("Test final après 10 secondes")
	
	-- Vérifier PlayerData
	local playerData = player:FindFirstChild("PlayerData")
	if playerData then
		logEvent("✅ PlayerData trouvé")
		
		local argent = playerData:FindFirstChild("Argent")
		if argent then
			logEvent("✅ Argent trouvé: " .. tostring(argent.Value))
		else
			logEvent("❌ Argent NON trouvé")
		end
	else
		logEvent("❌ PlayerData NON trouvé")
	end
	
	print("\n🧪 [TEST] ===== TEST TERMINÉ =====")
	print("🧪 [TEST] Total événements:", #events)
	print("🧪 [TEST] ==============================\n")
end)

print("🧪 [TEST] Script de test initialisé")
