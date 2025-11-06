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

-- Dossier des modèles de PETs
local PetModelsFolder = ReplicatedStorage:FindFirstChild("PetModels")

-- Variables
local activePets = {} -- Table: {petName = {model = Model, connection = RBXScriptConnection, animator = Animator, animations = {}}}

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

-- Charger les animations d'un modèle
local function loadAnimations(model, petName)
	local animations = {}
	
	-- Trouver l'AnimationController ou Humanoid
	local animController = model:FindFirstChildOfClass("AnimationController")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	
	if not animController and not humanoid then
		warn("🐾 [PET FOLLOWER] Pas d'AnimationController/Humanoid pour:", petName)
		return animations
	end
	
	-- Créer un Animator si nécessaire
	local animator = animController and animController:FindFirstChildOfClass("Animator")
	if not animator and humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
	end
	
	if not animator then
		animator = Instance.new("Animator")
		if animController then
			animator.Parent = animController
		elseif humanoid then
			animator.Parent = humanoid
		end
	end
	
	-- Chercher les animations dans le dossier AnimSaves du modèle
	local animSavesFolder = model:FindFirstChild("AnimSaves")
	if animSavesFolder then
		print("🐾 [PET FOLLOWER] Dossier AnimSaves trouvé pour:", petName)
		for _, anim in ipairs(animSavesFolder:GetChildren()) do
			-- Priorité au KeyframeSequence (Moon Animator)
			if anim:IsA("KeyframeSequence") then
				print("🔧 [PET FOLLOWER] Chargement KeyframeSequence (Moon Animator):", anim.Name)
				local animName = anim.Name:lower()
				
				-- Utiliser KeyframeSequenceProvider pour enregistrer le KeyframeSequence
				local success, result = pcall(function()
					local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
					local contentId = KeyframeSequenceProvider:RegisterKeyframeSequence(anim)
					print("   - ContentId généré:", contentId)
					
					local newAnim = Instance.new("Animation")
					newAnim.AnimationId = contentId
					
					local track = animator:LoadAnimation(newAnim)
					return track
				end)
				
				if success and result then
					animations[animName] = result
					print("✅ [PET FOLLOWER] KeyframeSequence chargé:", petName, "-", anim.Name, "-> clé:", animName)
					print("   - Track Length:", result.Length)
				else
					warn("❌ [PET FOLLOWER] Erreur chargement KeyframeSequence:", anim.Name, result)
				end
			elseif anim:IsA("Animation") then
				-- C'est un objet Animation standard
				local animName = anim.Name:lower()
				local success, track = pcall(function()
					return animator:LoadAnimation(anim)
				end)
				
				if success and track then
					animations[animName] = track
					print("✅ [PET FOLLOWER] Animation chargée:", petName, "-", anim.Name, "-> clé:", animName)
					print("   - AnimationId:", anim.AnimationId)
					print("   - Track Length:", track.Length)
				else
					warn("❌ [PET FOLLOWER] Erreur chargement animation:", anim.Name, track)
				end
			else
				print("⚠️ [PET FOLLOWER] Objet ignoré:", anim.Name, anim.ClassName)
			end
		end
	else
		warn("⚠️ [PET FOLLOWER] Pas de dossier AnimSaves trouvé pour:", petName)
	end
	
	local count = 0
	for _ in pairs(animations) do count = count + 1 end
	print("🐾 [PET FOLLOWER] Total animations chargées:", count, "pour", petName)
	
	return animations, animator
end

-- Créer un modèle de PET (vrai modèle ou fallback)
local function createPetModel(petName)
	local petData = PetManager.getPetInfo(petName)
	if not petData then return nil end
	
	local model = nil
	local animations = {}
	local animator = nil
	
	-- Essayer de charger le vrai modèle depuis PetModels
	if PetModelsFolder then
		local petModelTemplate = PetModelsFolder:FindFirstChild(petData.modelName)
		if petModelTemplate then
			model = petModelTemplate:Clone()
			model.Name = "Pet_" .. petName
			print("✅ [PET FOLLOWER] Modèle réel chargé:", petName)
			
			-- Charger les animations
			animations, animator = loadAnimations(model, petName)
		end
	end
	
	-- Si pas de modèle trouvé, créer un modèle simple (fallback)
	if not model then
		print("⚠️ [PET FOLLOWER] Modèle non trouvé, création d'un cube pour:", petName)
		model = Instance.new("Model")
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
		
		model.PrimaryPart = body
	end
	
	-- Trouver ou créer le PrimaryPart
	if not model.PrimaryPart then
		-- Chercher une part appelée "Body", "HumanoidRootPart", ou la première MeshPart
		local primaryPart = model:FindFirstChild("Body") 
			or model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChildOfClass("MeshPart")
			or model:FindFirstChildOfClass("Part")
		
		if primaryPart then
			model.PrimaryPart = primaryPart
		else
			warn("🐾 [PET FOLLOWER] Impossible de trouver PrimaryPart pour:", petName)
			return nil
		end
	end
	
	local body = model.PrimaryPart
	
	-- S'assurer que le PrimaryPart ne collide pas
	body.CanCollide = false
	
	-- Ajouter BodyGyro et BodyPosition si pas déjà présents
	if not body:FindFirstChildOfClass("BodyGyro") then
		local bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
		bodyGyro.P = 3000
		bodyGyro.D = 500
		bodyGyro.Parent = body
	end
	
	if not body:FindFirstChildOfClass("BodyPosition") then
		local bodyPosition = Instance.new("BodyPosition")
		bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
		bodyPosition.P = 3000
		bodyPosition.D = 500
		bodyPosition.Parent = body
	end
	
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
	
	return model, animations, animator
end

-- Faire suivre un PET (volant)
local function followPlayerFlying(petModel, slotIndex, animations)
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
	
	-- Calculer la vitesse réelle du joueur (vélocité horizontale du RootPart)
	local playerVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
	
	-- Gérer les animations (Walk si le joueur bouge, Idle si immobile)
	if animations and next(animations) then
		local walkAnim = animations["walk"]
		local idleAnim = animations["idle"]
		
		-- Si le joueur bouge OU si le pet est loin de sa cible
		if playerVelocity > 1 or distance > 3 then
			-- En mouvement : jouer Walk
			if walkAnim then
				if not walkAnim.IsPlaying then
					if idleAnim and idleAnim.IsPlaying then
						idleAnim:Stop()
					end
					walkAnim.Looped = true
					walkAnim:Play()
					walkAnim:AdjustSpeed(1.5)
				end
			end
		else
			-- Immobile : jouer Idle
			if idleAnim then
				if not idleAnim.IsPlaying then
					if walkAnim and walkAnim.IsPlaying then
						walkAnim:Stop()
					end
					idleAnim.Looped = true
					idleAnim:Play()
				end
			end
		end
	end
	
	-- Si trop loin, téléporter
	if distance > 50 then
		body.CFrame = CFrame.new(targetPos)
	else
		-- Sinon, suivre doucement
		bodyPosition.Position = targetPos
	end
	
	-- Faire regarder le pet dans la même direction que le joueur (Flying)
	local targetLookVector = rootPart.CFrame.LookVector
	local targetLookPos = body.Position + targetLookVector
	bodyGyro.CFrame = CFrame.new(body.Position, targetLookPos)
	
	-- Animation de flottement (bobbing)
	local time = tick()
	local bobbing = math.sin(time * 3 + slotIndex) * 0.3
	bodyPosition.Position = targetPos + Vector3.new(0, bobbing, 0)
end

-- Faire suivre un PET (au sol)
local function followPlayerGround(petModel, slotIndex, animations)
	if not petModel or not petModel.PrimaryPart then return end
	if not rootPart or not rootPart.Parent then return end
	
	local body = petModel.PrimaryPart
	local bodyPosition = body:FindFirstChildOfClass("BodyPosition")
	local bodyGyro = body:FindFirstChildOfClass("BodyGyro")
	
	if not bodyPosition or not bodyGyro then return end
	
	-- Position cible : répartir les PETs derrière le joueur selon sa direction
	local angleOffset = (slotIndex - 1) * (360 / 3)
	local angle = math.rad(angleOffset)
	local radius = 5 -- Distance du joueur
	
	-- Calculer la position derrière le joueur en fonction de sa direction
	local lookVector = rootPart.CFrame.LookVector
	local rightVector = rootPart.CFrame.RightVector
	
	-- Position de base derrière le joueur
	local behindOffset = -lookVector * radius
	
	-- Ajouter un décalage latéral selon le slot
	local sideOffset = rightVector * math.cos(angle) * 2
	
	local targetPos = rootPart.Position + behindOffset + sideOffset
	
	-- Raycast pour trouver le sol
	local rayOrigin = targetPos + Vector3.new(0, 10, 0)
	local rayDirection = Vector3.new(0, -20, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, petModel}
	
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if rayResult then
		-- Positionner exactement sur le sol (pas de hauteur supplémentaire)
		local heightOffset = body.Size.Y / 2
		targetPos = rayResult.Position + Vector3.new(0, heightOffset, 0)
	else
		targetPos = targetPos + Vector3.new(0, 0.5, 0)
	end
	
	-- Distance au joueur
	local distance = (body.Position - targetPos).Magnitude
	
	-- Calculer la vitesse réelle du joueur (vélocité horizontale du RootPart)
	local playerVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
	
	-- Gérer les animations (Walk si le joueur bouge, Idle si immobile)
	if animations and next(animations) then
		local walkAnim = animations["popotam_walk"] or animations["walk"]
		local idleAnim = animations["popotam_idle"] or animations["idle"]
		
		-- Si le joueur bouge OU si le pet est loin de sa cible
		if playerVelocity > 1 or distance > 3 then
			-- En mouvement : jouer Walk
			if walkAnim then
				if not walkAnim.IsPlaying then
					if idleAnim and idleAnim.IsPlaying then
						idleAnim:Stop()
					end
					walkAnim.Looped = true
					walkAnim:Play()
					walkAnim:AdjustSpeed(1.5)
				end
			end
		else
			-- Immobile : jouer Idle
			if idleAnim then
				if not idleAnim.IsPlaying then
					if walkAnim and walkAnim.IsPlaying then
						walkAnim:Stop()
					end
					idleAnim.Looped = true
					idleAnim:Play()
				end
			end
		end
	end
	
	-- Si trop loin, téléporter
	if distance > 50 then
		body.CFrame = CFrame.new(targetPos)
	else
		-- Sinon, suivre doucement
		bodyPosition.Position = targetPos
	end
	
	-- Faire regarder le pet dans la même direction que le joueur (Ground)
	local targetLookVector = rootPart.CFrame.LookVector
	local targetLookPos = body.Position + targetLookVector
	bodyGyro.CFrame = CFrame.new(body.Position, targetLookPos)
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
	
	-- Créer le nouveau PET (sans charger les animations encore)
	local petModel, _, _ = createPetModel(petName)
	
	if not petModel then
		warn("🐾 [PET FOLLOWER] Impossible de créer le modèle pour:", petName)
		return
	end
	
	-- Positionner le PET près du joueur (utiliser PivotTo au lieu de SetPrimaryPartCFrame pour ne pas casser les animations!)
	petModel.Parent = workspace
	petModel:PivotTo(rootPart.CFrame * CFrame.new(2, 1, 2))
	
	-- CHARGER LES ANIMATIONS APRÈS que le modèle soit dans le workspace
	local animations, animator = loadAnimations(petModel, petName)
	print("🐾 [PET FOLLOWER] Animations rechargées après spawn:", petName)
	
	-- Obtenir le type de mouvement
	local petInfo = PetManager.getPetInfo(petName)
	local movementType = petInfo and petInfo.movementType or "Flying"
	
	-- Démarrer le suivi selon le type
	local connection
	if movementType == "Ground" then
		connection = RunService.Heartbeat:Connect(function()
			followPlayerGround(petModel, slotIndex, animations)
		end)
	else -- Flying
		connection = RunService.Heartbeat:Connect(function()
			followPlayerFlying(petModel, slotIndex, animations)
		end)
	end
	
	-- Enregistrer le PET
	activePets[petName] = {
		model = petModel,
		connection = connection,
		slotIndex = slotIndex,
		animations = animations,
		animator = animator
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
