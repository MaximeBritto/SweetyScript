-- CandyPickupServer.lua
-- Script côté serveur pour gérer le ramassage sécurisé des bonbons
-- À placer dans ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Attendre le RemoteEvent
local pickupEvent = ReplicatedStorage:WaitForChild("PickupCandyEvent")

-- Table pour éviter les doubles ramassages (anti-spam)
local recentPickups = {}
local PICKUP_COOLDOWN = 0.5 -- Cooldown de 0.5 secondes entre chaque ramassage

-- Fonction pour vérifier si un bonbon appartient au joueur
local function isOwner(player, candyModel)
	if not candyModel or not candyModel.Parent then
		return false
	end
	
	local ownerTag = candyModel:FindFirstChild("CandyOwner")
	if not ownerTag or not ownerTag:IsA("IntValue") then
		-- Bonbons sans propriétaire = BLOQUER (sécurité)
		warn("🚫 [PICKUP SERVER] Bonbon sans propriétaire bloqué:", candyModel.Name)
		return false
	end
	
	-- Vérifier que c'est bien le propriétaire
	local isOwner = ownerTag.Value == player.UserId
	if not isOwner then
		warn("🚫 [PICKUP SERVER] Tentative de vol:", player.Name, "→ Bonbon de UserId:", ownerTag.Value)
	end
	return isOwner
end

-- Fonction pour donner le bonbon au joueur
local function giveCandy(player, candyModel)
	local candyType = candyModel:FindFirstChild("CandyType")
	if not candyType then
		warn("⚠️ [PICKUP SERVER] Bonbon sans CandyType:", candyModel.Name)
		return false
	end
	
	-- Récupérer les données de taille si présentes
	local sizeData = nil
	local candySize = candyModel:FindFirstChild("CandySize")
	local candyRarity = candyModel:FindFirstChild("CandyRarity")
	local colorR = candyModel:FindFirstChild("CandyColorR")
	local colorG = candyModel:FindFirstChild("CandyColorG")
	local colorB = candyModel:FindFirstChild("CandyColorB")
	
	if candySize and candyRarity then
		sizeData = {
			size = candySize.Value,
			rarity = candyRarity.Value,
			color = Color3.fromRGB(
				colorR and colorR.Value or 255,
				colorG and colorG.Value or 255,
				colorB and colorB.Value or 255
			)
		}
		print("🍬 [PICKUP SERVER] Taille détectée:", candyType.Value, "|", sizeData.rarity, "|", sizeData.size .. "x")
	end
	
	-- Utiliser CandyTools pour donner le bonbon
	local CandyTools = require(ReplicatedStorage:WaitForChild("CandyTools"))
	
	-- Pré-configurer les données de taille pour CandyTools
	if sizeData then
		_G.restoreCandyData = sizeData
		print("📋 [PICKUP SERVER] Configuration taille pour:", candyType.Value)
	else
		_G.restoreCandyData = nil
	end
	
	local success = CandyTools.giveCandy(player, candyType.Value, 1)
	_G.restoreCandyData = nil
	
	if success then
		print("✅ [PICKUP SERVER] Bonbon donné:", player.Name, "←", candyType.Value, sizeData and ("(" .. sizeData.rarity .. " " .. sizeData.size .. "x)") or "")
		return true
	else
		warn("❌ [PICKUP SERVER] Échec de donner le bonbon:", candyType.Value)
		return false
	end
end

-- Gestionnaire de l'événement de ramassage
pickupEvent.OnServerEvent:Connect(function(player, candyModel)
	-- Vérifications de sécurité
	if not player or not player.Parent then
		return
	end
	
	if not candyModel or not candyModel.Parent then
		warn("⚠️ [PICKUP SERVER] Bonbon invalide ou déjà détruit")
		return
	end
	
	-- Anti-spam: vérifier le cooldown
	local playerKey = player.UserId
	local candyKey = candyModel
	local now = tick()
	
	if recentPickups[playerKey] and recentPickups[playerKey][candyKey] then
		local lastPickup = recentPickups[playerKey][candyKey]
		if now - lastPickup < PICKUP_COOLDOWN then
			print("⏳ [PICKUP SERVER] Cooldown actif pour", player.Name)
			return
		end
	end
	
	-- Vérifier que le joueur est le propriétaire
	if not isOwner(player, candyModel) then
		warn("🚫 [PICKUP SERVER] Tentative de vol de bonbon par", player.Name, "| Bonbon:", candyModel.Name)
		return
	end
	
	-- Vérifier la distance (anti-cheat)
	local character = player.Character
	if not character then
		return
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end
	
	local candyPosition
	if candyModel:IsA("Model") then
		local base = candyModel.PrimaryPart or candyModel:FindFirstChildWhichIsA("BasePart")
		candyPosition = base and base.Position
	elseif candyModel:IsA("BasePart") then
		candyPosition = candyModel.Position
	end
	
	if not candyPosition then
		warn("⚠️ [PICKUP SERVER] Impossible de déterminer la position du bonbon")
		return
	end
	
	local distance = (humanoidRootPart.Position - candyPosition).Magnitude
	if distance > 15 then -- Distance max de 15 studs (plus large que le client pour éviter les faux positifs)
		warn("🚫 [PICKUP SERVER] Joueur trop loin du bonbon:", player.Name, "| Distance:", distance)
		return
	end
	
	-- Enregistrer le ramassage dans le cooldown
	if not recentPickups[playerKey] then
		recentPickups[playerKey] = {}
	end
	recentPickups[playerKey][candyKey] = now
	
	-- Donner le bonbon au joueur
	local success = giveCandy(player, candyModel)
	
	if success then
		-- Détruire le bonbon du monde
		candyModel:Destroy()
		
		-- Confirmer au client (pour jouer le son)
		pickupEvent:FireClient(player)
		
		print("✅ [PICKUP SERVER] Ramassage réussi:", player.Name, "| Bonbon:", candyModel.Name)
	else
		warn("❌ [PICKUP SERVER] Échec du ramassage pour", player.Name)
	end
end)

-- Nettoyage périodique du cache de cooldown
task.spawn(function()
	while true do
		task.wait(60) -- Nettoyer toutes les minutes
		
		local now = tick()
		for playerKey, candies in pairs(recentPickups) do
			for candyKey, timestamp in pairs(candies) do
				if now - timestamp > PICKUP_COOLDOWN * 2 then
					candies[candyKey] = nil
				end
			end
			
			-- Supprimer les entrées vides
			if next(candies) == nil then
				recentPickups[playerKey] = nil
			end
		end
	end
end)

print("✅ [PICKUP SERVER] Système de ramassage sécurisé initialisé")
