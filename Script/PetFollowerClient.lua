-- PetFollowerClient.lua
-- Script client pour faire suivre le PET équipé au joueur
-- À placer dans StarterPlayer > StarterCharacterScripts

local player = game:GetService("Players").LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Module PetManager
local PetManager = require(ReplicatedStorage:WaitForChild("PetManager"))

-- Variables
local activePets = {} -- Table: {petName = {model = Model, connection = RBXScriptConnection}}

-- Couleurs pour chaque PET (temporaire avant les vrais modèles)
local PET_COLORS = {
	Lapin = Color3.fromRGB(255, 200, 200), -- Rose clair
	Chat = Color3.fromRGB(255, 180, 100), -- Orange
	Chien = Color3.fromRGB(150, 100, 50), -- Marron
	Renard = Color3.fromRGB(255, 100, 50), -- Orange foncé
	Panda = Color3.fromRGB(50, 50, 50), -- Noir/blanc
	Dragon = Color3.fromRGB(200, 50, 50), -- Rouge
	Licorne = Color3.fromRGB(255, 150, 255), -- Rose/violet
	Phoenix = Color3.fromRGB(255, 200, 50) -- Doré
}

-- Créer un modèle de PET simple (cube)
local function createPetModel(petName)
	local petData = PetManager.getPetInfo(petName)
	if not petData then return nil end
	
	-- Créer le modèle
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petName
	
	-- Corps principal (cube)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 2)
	body.Color = PET_COLORS[petName] or Color3.fromRGB(255, 255, 255)
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Anchored = false
	body.Parent = model
	
	-- Rendre le PET brillant
	local highlight = Instance.new("Highlight")
	highlight.FillColor = PET_COLORS[petName] or Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = petData.couleurRarete
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Parent = body
	
	-- Yeux (2 petites sphères)
	local leftEye = Instance.new("Part")
	leftEye.Name = "LeftEye"
	leftEye.Shape = Enum.PartType.Ball
	leftEye.Size = Vector3.new(0.3, 0.3, 0.3)
	leftEye.Color = Color3.new(0, 0, 0)
	leftEye.Material = Enum.Material.SmoothPlastic
	leftEye.CanCollide = false
	leftEye.Anchored = false
	leftEye.Parent = model
	
	local rightEye = leftEye:Clone()
	rightEye.Name = "RightEye"
	rightEye.Parent = model
	
	-- Welds pour les yeux
	local leftWeld = Instance.new("WeldConstraint")
	leftWeld.Part0 = body
	leftWeld.Part1 = leftEye
	leftWeld.Parent = leftEye
	
	local rightWeld = Instance.new("WeldConstraint")
	rightWeld.Part0 = body
	rightWeld.Part1 = rightEye
	rightWeld.Parent = rightEye
	
	-- Positionner les yeux
	leftEye.Position = body.Position + Vector3.new(-0.4, 0.3, -0.9)
	rightEye.Position = body.Position + Vector3.new(0.4, 0.3, -0.9)
	
	-- BodyGyro pour garder le PET droit
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
	bodyGyro.P = 3000
	bodyGyro.D = 500
	bodyGyro.Parent = body
	
	-- BodyPosition pour le mouvement fluide
	local bodyPosition = Instance.new("BodyPosition")
	bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyPosition.P = 3000
	bodyPosition.D = 500
	bodyPosition.Parent = body
	
	-- PrimaryPart
	model.PrimaryPart = body
	
	-- Ajouter un BillboardGui avec le nom du PET
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = petData.nom
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Parent = billboard
	
	return model
end

-- Faire suivre un PET (volant)
local function followPlayerFlying(petModel, slotIndex)
	if not petModel or not petModel.PrimaryPart then return end
	if not rootPart or not rootPart.Parent then return end
	
	local body = petModel.PrimaryPart
	local bodyPosition = body:FindFirstChildOfClass("BodyPosition")
	local bodyGyro = body:FindFirstChildOfClass("BodyGyro")
	
	if not bodyPosition or not bodyGyro then return end
	
	-- Position cible : répartir les PETs autour du joueur
	local angleOffset = (slotIndex - 1) * (360 / 3) -- 0°, 120°, 240°
	local angle = math.rad(angleOffset)
	local radius = 3
	
	local offsetX = math.cos(angle) * radius
	local offsetZ = math.sin(angle) * radius
	local offsetY = 2 -- Hauteur dans les airs
	
	local targetPos = rootPart.Position + Vector3.new(offsetX, offsetY, offsetZ)
	
	-- Distance au joueur
	local distance = (body.Position - targetPos).Magnitude
	
	-- Si trop loin, téléporter
	if distance > 50 then
		body.CFrame = CFrame.new(targetPos)
	else
		-- Sinon, suivre doucement
		bodyPosition.Position = targetPos
	end
	
	-- Garder le PET droit (regarder vers le joueur)
	local lookAtPos = Vector3.new(rootPart.Position.X, body.Position.Y, rootPart.Position.Z)
	bodyGyro.CFrame = CFrame.new(body.Position, lookAtPos)
	
	-- Animation de flottement (bobbing)
	local time = tick()
	local bobbing = math.sin(time * 3 + slotIndex) * 0.3
	bodyPosition.Position = targetPos + Vector3.new(0, bobbing, 0)
end

-- Faire suivre un PET (au sol)
local function followPlayerGround(petModel, slotIndex)
	if not petModel or not petModel.PrimaryPart then return end
	if not rootPart or not rootPart.Parent then return end
	
	local body = petModel.PrimaryPart
	local bodyPosition = body:FindFirstChildOfClass("BodyPosition")
	local bodyGyro = body:FindFirstChildOfClass("BodyGyro")
	
	if not bodyPosition or not bodyGyro then return end
	
	-- Position cible : répartir les PETs autour du joueur
	local angleOffset = (slotIndex - 1) * (360 / 3)
	local angle = math.rad(angleOffset)
	local radius = 2.5
	
	local offsetX = math.cos(angle) * radius
	local offsetZ = math.sin(angle) * radius
	
	local targetPos = rootPart.Position + Vector3.new(offsetX, 0, offsetZ)
	
	-- Raycast pour trouver le sol
	local rayOrigin = targetPos + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -20, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, petModel}
	
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if rayResult then
		targetPos = rayResult.Position + Vector3.new(0, 1, 0) -- 1 stud au-dessus du sol
	else
		targetPos = targetPos + Vector3.new(0, 1, 0)
	end
	
	-- Distance au joueur
	local distance = (body.Position - targetPos).Magnitude
	
	-- Si trop loin, téléporter
	if distance > 50 then
		body.CFrame = CFrame.new(targetPos)
	else
		-- Sinon, suivre doucement
		bodyPosition.Position = targetPos
	end
	
	-- Garder le PET droit (regarder vers le joueur)
	local lookAtPos = Vector3.new(rootPart.Position.X, body.Position.Y, rootPart.Position.Z)
	bodyGyro.CFrame = CFrame.new(body.Position, lookAtPos)
end

-- Détruire un PET spécifique
local function destroyPet(petName)
	local petData = activePets[petName]
	if not petData then return end
	
	if petData.connection then
		petData.connection:Disconnect()
	end
	
	if petData.model then
		petData.model:Destroy()
	end
	
	activePets[petName] = nil
	print("🐾 [PET FOLLOWER] PET détruit:", petName)
end

-- Détruire tous les PETs
local function destroyAllPets()
	for petName, _ in pairs(activePets) do
		destroyPet(petName)
	end
	print("� [PET FOLLLOWER] Tous les PETs détruits")
end

-- Spawner un PET
local function spawnPet(petName, slotIndex)
	-- Si déjà spawné, ne rien faire
	if activePets[petName] then
		print("🐾 [PET FOLLOWER] PET déjà spawné:", petName)
		return
	end
	
	print("🐾 [PET FOLLOWER] Spawn du PET:", petName, "Slot:", slotIndex)
	
	-- Créer le nouveau PET
	local petModel = createPetModel(petName)
	
	if not petModel then
		warn("🐾 [PET FOLLOWER] Impossible de créer le modèle pour:", petName)
		return
	end
	
	-- Positionner le PET près du joueur
	petModel:SetPrimaryPartCFrame(rootPart.CFrame + Vector3.new(2, 1, 2))
	petModel.Parent = workspace
	
	-- Obtenir le type de mouvement
	local petInfo = PetManager.getPetInfo(petName)
	local movementType = petInfo and petInfo.movementType or "Flying"
	
	-- Démarrer le suivi selon le type
	local connection
	if movementType == "Ground" then
		connection = RunService.Heartbeat:Connect(function()
			followPlayerGround(petModel, slotIndex)
		end)
	else -- Flying
		connection = RunService.Heartbeat:Connect(function()
			followPlayerFlying(petModel, slotIndex)
		end)
	end
	
	-- Enregistrer le PET
	activePets[petName] = {
		model = petModel,
		connection = connection,
		slotIndex = slotIndex
	}
	
	print("✅ [PET FOLLOWER] PET spawné:", petName, "Type:", movementType)
end

-- Synchroniser les PETs avec ceux équipés
local function syncPets()
	local playerData = player:FindFirstChild("PlayerData")
	local equippedPetsFolder = playerData and playerData:FindFirstChild("EquippedPets")
	if not equippedPetsFolder then return end
	
	-- Obtenir la liste des PETs équipés
	local equippedPets = {}
	for _, petValue in ipairs(equippedPetsFolder:GetChildren()) do
		if petValue:IsA("StringValue") and petValue.Value ~= "" then
			table.insert(equippedPets, petValue.Value)
		end
	end
	
	-- Détruire les PETs qui ne sont plus équipés
	for petName, _ in pairs(activePets) do
		local stillEquipped = false
		for _, equippedName in ipairs(equippedPets) do
			if equippedName == petName then
				stillEquipped = true
				break
			end
		end
		if not stillEquipped then
			destroyPet(petName)
		end
	end
	
	-- Spawner les nouveaux PETs
	for i, petName in ipairs(equippedPets) do
		if not activePets[petName] then
			spawnPet(petName, i)
		end
	end
end

-- Vérifier les PETs équipés au démarrage
task.wait(1) -- Attendre que PlayerData soit chargé
local playerData = player:WaitForChild("PlayerData", 10)
if playerData then
	local equippedPetsFolder = playerData:FindFirstChild("EquippedPets")
	if equippedPetsFolder then
		-- Synchroniser au démarrage
		syncPets()
		
		-- Écouter les changements (ajout/suppression de PETs)
		equippedPetsFolder.ChildAdded:Connect(function()
			task.wait(0.1)
			print("🐾 [PET FOLLOWER] PET ajouté, synchronisation...")
			syncPets()
		end)
		
		equippedPetsFolder.ChildRemoved:Connect(function()
			task.wait(0.1)
			print("🐾 [PET FOLLOWER] PET retiré, synchronisation...")
			syncPets()
		end)
	end
end

-- Nettoyer quand le personnage meurt
humanoid.Died:Connect(function()
	destroyAllPets()
end)

print("🐾 [PET FOLLOWER] Système de suivi initialisé!")
