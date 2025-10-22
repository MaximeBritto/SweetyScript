-- IslandCleanup.lua
-- Nettoie complètement l'île d'un joueur à sa déconnexion
-- À placer dans ServerScriptService

print("🧹 [ISLAND CLEANUP] Script chargé!")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Fonction pour trouver l'île d'un joueur
local function getPlayerIsland(player)
	-- Chercher par nom
	local islandByName = Workspace:FindFirstChild("Ile_" .. player.Name)
	if islandByName then return islandByName end
	
	-- Chercher par slot
	local slot = player:GetAttribute("IslandSlot")
	if slot then
		local islandBySlot = Workspace:FindFirstChild("Ile_Slot_" .. tostring(slot))
		if islandBySlot then return islandBySlot end
	end
	
	return nil
end

-- Nettoyage à la déconnexion
Players.PlayerRemoving:Connect(function(player)
	print("🗑️ [ISLAND CLEANUP] Nettoyage pour:", player.Name)
	
	local userId = player.UserId
	local playerName = player.Name
	
	-- 1. NE RIEN FAIRE - IslandManager gère le nettoyage des plateformes
	-- Ce script ne gère que le nettoyage physique de l'île
	print("ℹ️ [ISLAND CLEANUP] Nettoyage des plateformes géré par IslandManager")
	
	-- 2. Nettoyer l'île physique
	local island = getPlayerIsland(player)
	if not island then
		warn("⚠️ [ISLAND CLEANUP] Île introuvable pour:", player.Name)
		return
	end
	
	local cleanedCount = 0
	
	-- Supprimer tous les objets de production sur l'île
	for _, obj in ipairs(island:GetDescendants()) do
		local shouldDestroy = false
		
		-- Supprimer les bonbons (Tools)
		if obj:IsA("Tool") then
			shouldDestroy = true
		end
		
		-- Supprimer les bonbons (avec attributs)
		if obj:FindFirstChild("CandyType") or obj:FindFirstChild("CandyOwner") or obj:GetAttribute("IsCandy") then
			shouldDestroy = true
		end
		
		-- Supprimer les billboards
		if obj:IsA("BillboardGui") and (obj.Name == "CountBillboard" or obj.Name == "CandyPreviewViewport") then
			shouldDestroy = true
		end
		
		if shouldDestroy then
			obj:Destroy()
			cleanedCount = cleanedCount + 1
		end
		
		-- Désactiver la fumée des incubateurs
		if obj:IsA("ParticleEmitter") and obj.Parent and obj.Parent.Name:match("Incubator") then
			obj.Enabled = false
		end
	end
	
	print("✅ [ISLAND CLEANUP] Nettoyé", cleanedCount, "objet(s) sur l'île")
	
	-- 3. NOUVEAU: Nettoyer les sacs d'argent dans tout le Workspace (ils sont en dehors de l'île)
	local moneyCount = 0
	for _, obj in ipairs(Workspace:GetChildren()) do
		-- Chercher les MeshPart avec "MoneyStack" dans le nom et le nom du joueur
		if obj:IsA("MeshPart") and obj.Name:match("MoneyStack") and obj.Name:match(playerName) then
			print("  💰 Suppression sac:", obj.Name)
			obj:Destroy()
			moneyCount = moneyCount + 1
		end
	end
	
	if moneyCount > 0 then
		print("✅ [ISLAND CLEANUP] Nettoyé", moneyCount, "sac(s) d'argent dans le Workspace")
	end
end)
