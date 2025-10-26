-- PetServer.lua
-- Script serveur pour gérer les achats et équipement de PETs
-- À placer dans ServerScriptService

print("🐾 [PET SERVER] Démarrage...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Module PetManager
local PetManager
local success, err = pcall(function()
	PetManager = require(ReplicatedStorage:WaitForChild("PetManager", 10))
end)

if not success or not PetManager then
	warn("🐾 [PET SERVER] Impossible de charger PetManager:", err)
	return
end

print("🐾 [PET SERVER] PetManager chargé")

-- RemoteEvents
local achatPetEvent = ReplicatedStorage:FindFirstChild("AchatPetEvent")
if not achatPetEvent then
	achatPetEvent = Instance.new("RemoteEvent")
	achatPetEvent.Name = "AchatPetEvent"
	achatPetEvent.Parent = ReplicatedStorage
end

local achatPetRobuxEvent = ReplicatedStorage:FindFirstChild("AchatPetRobuxEvent")
if not achatPetRobuxEvent then
	achatPetRobuxEvent = Instance.new("RemoteEvent")
	achatPetRobuxEvent.Name = "AchatPetRobuxEvent"
	achatPetRobuxEvent.Parent = ReplicatedStorage
end

local equipPetEvent = ReplicatedStorage:FindFirstChild("EquipPetEvent")
if not equipPetEvent then
	equipPetEvent = Instance.new("RemoteEvent")
	equipPetEvent.Name = "EquipPetEvent"
	equipPetEvent.Parent = ReplicatedStorage
end

-- Initialiser les données PET d'un joueur
local function initPlayerPetData(player)
	local playerData = player:WaitForChild("PlayerData", 10)
	if not playerData then
		warn("🐾 [PET SERVER] PlayerData manquant pour:", player.Name)
		return
	end
	
	-- Dossier pour stocker les PETs possédés
	local petsFolder = playerData:FindFirstChild("Pets")
	if not petsFolder then
		petsFolder = Instance.new("Folder")
		petsFolder.Name = "Pets"
		petsFolder.Parent = playerData
	end
	
	-- Dossier pour les PETs équipés (max 3)
	local equippedPetsFolder = playerData:FindFirstChild("EquippedPets")
	if not equippedPetsFolder then
		equippedPetsFolder = Instance.new("Folder")
		equippedPetsFolder.Name = "EquippedPets"
		equippedPetsFolder.Parent = playerData
	end
	
	print("🐾 [PET SERVER] Données PET initialisées pour:", player.Name)
end

-- Vérifier si un joueur possède un PET
local function playerOwnsPet(player, petName)
	local playerData = player:FindFirstChild("PlayerData")
	local petsFolder = playerData and playerData:FindFirstChild("Pets")
	if not petsFolder then return false end
	
	for _, petValue in ipairs(petsFolder:GetChildren()) do
		if petValue:IsA("StringValue") and petValue.Value == petName then
			return true
		end
	end
	return false
end

-- Obtenir la liste des PETs équipés
local function getEquippedPets(player)
	local playerData = player:FindFirstChild("PlayerData")
	local equippedPetsFolder = playerData and playerData:FindFirstChild("EquippedPets")
	if not equippedPetsFolder then return {} end
	
	local pets = {}
	for _, petValue in ipairs(equippedPetsFolder:GetChildren()) do
		if petValue:IsA("StringValue") and petValue.Value ~= "" then
			table.insert(pets, petValue.Value)
		end
	end
	return pets
end

-- Appliquer les boosts de tous les PETs équipés
local function applyAllPetBoosts(player)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local equippedPets = getEquippedPets(player)
	
	if #equippedPets == 0 then
		-- Retirer les boosts
		humanoid.WalkSpeed = 16 -- Vitesse par défaut
		print("🐾 [PET SERVER] Boosts retirés pour:", player.Name)
		return
	end
	
	-- Calculer les boosts cumulés
	local boosts = PetManager.calculatePlayerBoosts(equippedPets)
	
	-- Appliquer le boost de vitesse
	humanoid.WalkSpeed = 16 * boosts.Speed
	print("🐾 [PET SERVER] Vitesse appliquée:", humanoid.WalkSpeed, "pour", player.Name)
	
	-- Les autres boosts (Money, Capacity, Production) seront appliqués dans vos autres scripts
	-- en utilisant PetManager.calculatePlayerBoosts(getEquippedPets(player))
	
	print("✅ [PET SERVER] Boosts appliqués pour:", player.Name, "PETs:", table.concat(equippedPets, ", "))
end

-- Ajouter un PET à un joueur
local function addPetToPlayer(player, petName)
	local playerData = player:FindFirstChild("PlayerData")
	local petsFolder = playerData and playerData:FindFirstChild("Pets")
	if not petsFolder then return false end
	
	-- Vérifier si déjà possédé
	if playerOwnsPet(player, petName) then
		return false
	end
	
	-- Ajouter le PET
	local petValue = Instance.new("StringValue")
	petValue.Name = petName
	petValue.Value = petName
	petValue.Parent = petsFolder
	
	print("🐾 [PET SERVER]", player.Name, "a obtenu:", petName)
	return true
end

-- Achat avec argent
achatPetEvent.OnServerEvent:Connect(function(player, petName, paymentType)
	print("🐾 [PET SERVER] Demande d'achat:", player.Name, "->", petName)
	print("🐾 [PET SERVER] Type de paiement:", paymentType)
	
	-- Vérifier que le PET existe
	local petData = PetManager.getPetInfo(petName)
	if not petData then
		warn("🐾 [PET SERVER] PET inconnu:", petName)
		achatPetEvent:FireClient(player, false, "PET inconnu!")
		return
	end
	
	-- Vérifier si déjà possédé
	local alreadyOwned = playerOwnsPet(player, petName)
	print("🐾 [PET SERVER] Déjà possédé?", alreadyOwned)
	if alreadyOwned then
		warn("🐾 [PET SERVER]", player.Name, "possède déjà:", petName)
		achatPetEvent:FireClient(player, false, "Vous possédez déjà ce PET!")
		return
	end
	
	-- Vérifier l'argent
	local playerData = player:FindFirstChild("PlayerData")
	local argentValue = playerData and playerData:FindFirstChild("Argent")
	if not argentValue then
		warn("🐾 [PET SERVER] Argent manquant pour:", player.Name)
		achatPetEvent:FireClient(player, false, "Erreur: Argent non trouvé")
		return
	end
	
	print("🐾 [PET SERVER] Argent actuel:", argentValue.Value, "Prix:", petData.prix)
	
	if argentValue.Value < petData.prix then
		warn("🐾 [PET SERVER]", player.Name, "n'a pas assez d'argent pour:", petName)
		achatPetEvent:FireClient(player, false, "Pas assez d'argent!")
		return
	end
	
	-- Débiter l'argent
	argentValue.Value = argentValue.Value - petData.prix
	
	-- Ajouter le PET
	if addPetToPlayer(player, petName) then
		print("✅ [PET SERVER]", player.Name, "a acheté:", petName, "pour", petData.prix, "$")
		achatPetEvent:FireClient(player, true)
	else
		-- Rembourser en cas d'erreur
		argentValue.Value = argentValue.Value + petData.prix
		warn("❌ [PET SERVER] Erreur lors de l'ajout du PET")
	end
end)

-- Achat avec Robux
achatPetRobuxEvent.OnServerEvent:Connect(function(player, petName)
	print("🐾 [PET SERVER] Demande d'achat Robux:", player.Name, "->", petName)
	
	-- Vérifier que le PET existe
	local petData = PetManager.getPetInfo(petName)
	if not petData then
		warn("🐾 [PET SERVER] PET inconnu:", petName)
		return
	end
	
	-- Vérifier si déjà possédé
	if playerOwnsPet(player, petName) then
		warn("🐾 [PET SERVER]", player.Name, "possède déjà:", petName)
		return
	end
	
	-- Prompt d'achat Robux
	local success, result = pcall(function()
		return MarketplaceService:PromptProductPurchase(player, petData.prixRobux)
	end)
	
	if success then
		print("🐾 [PET SERVER] Prompt Robux affiché pour:", player.Name)
		-- Note: L'ajout du PET se fera dans ProcessReceipt (à implémenter séparément)
	else
		warn("🐾 [PET SERVER] Erreur prompt Robux:", result)
	end
end)

-- Équiper/Déséquiper un PET
equipPetEvent.OnServerEvent:Connect(function(player, petName)
	print("🐾 [PET SERVER] Demande équipement:", player.Name, "->", petName)
	
	local playerData = player:FindFirstChild("PlayerData")
	local equippedPetsFolder = playerData and playerData:FindFirstChild("EquippedPets")
	if not equippedPetsFolder then
		warn("🐾 [PET SERVER] EquippedPets manquant pour:", player.Name)
		return
	end
	
	-- Vérifier que le joueur possède ce PET
	if not playerOwnsPet(player, petName) then
		warn("🐾 [PET SERVER]", player.Name, "ne possède pas:", petName)
		return
	end
	
	-- Vérifier si le PET est déjà équipé
	local existingSlot = equippedPetsFolder:FindFirstChild(petName)
	
	if existingSlot then
		-- Déséquiper
		existingSlot:Destroy()
		print("🐾 [PET SERVER]", player.Name, "a déséquipé:", petName)
	else
		-- Vérifier la limite de 3 PETs
		local equippedCount = #equippedPetsFolder:GetChildren()
		if equippedCount >= PetManager.MAX_EQUIPPED_PETS then
			warn("🐾 [PET SERVER]", player.Name, "a déjà 3 PETs équipés!")
			equipPetEvent:FireClient(player, false, "Vous avez déjà 3 PETs équipés!")
			return
		end
		
		-- Équiper le PET
		local petValue = Instance.new("StringValue")
		petValue.Name = petName
		petValue.Value = petName
		petValue.Parent = equippedPetsFolder
		print("✅ [PET SERVER]", player.Name, "a équipé:", petName)
	end
	
	-- Appliquer les boosts de tous les PETs équipés
	applyAllPetBoosts(player)
	
	equipPetEvent:FireClient(player, true)
end)

-- Réappliquer les boosts quand le personnage respawn
Players.PlayerAdded:Connect(function(player)
	initPlayerPetData(player)
	
	player.CharacterAdded:Connect(function(character)
		task.wait(1) -- Attendre que le personnage soit chargé
		applyAllPetBoosts(player)
	end)
end)

-- Initialiser les données pour les joueurs existants
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(initPlayerPetData, player)
	
	-- Gérer le respawn pour les joueurs déjà présents
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		applyAllPetBoosts(player)
	end)
end

print("✅ [PET SERVER] Système PET initialisé!")
