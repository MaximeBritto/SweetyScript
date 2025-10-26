-- IncubatorServer_New.lua - Système simplifié de recettes
-- Gère le déblocage des recettes et la production

-------------------------------------------------
-- SERVICES & MODULES
-------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- RemoteEvents
local unlockRecipeEvt = ReplicatedStorage:FindFirstChild("UnlockRecipe") or Instance.new("RemoteEvent")
unlockRecipeEvt.Name = "UnlockRecipe"
unlockRecipeEvt.Parent = ReplicatedStorage

local startProductionEvt = ReplicatedStorage:FindFirstChild("StartProduction") or Instance.new("RemoteEvent")
startProductionEvt.Name = "StartProduction"
startProductionEvt.Parent = ReplicatedStorage

local stopProductionEvt = ReplicatedStorage:FindFirstChild("StopProduction") or Instance.new("RemoteEvent")
stopProductionEvt.Name = "StopProduction"
stopProductionEvt.Parent = ReplicatedStorage

local getUnlockedRecipesFunc = ReplicatedStorage:FindFirstChild("GetUnlockedRecipes") or Instance.new("RemoteFunction")
getUnlockedRecipesFunc.Name = "GetUnlockedRecipes"
getUnlockedRecipesFunc.Parent = ReplicatedStorage

local productionProgressEvt = ReplicatedStorage:FindFirstChild("ProductionProgress") or Instance.new("RemoteEvent")
productionProgressEvt.Name = "ProductionProgress"
productionProgressEvt.Parent = ReplicatedStorage

-------------------------------------------------
-- ÉTAT DES INCUBATEURS
-------------------------------------------------
local incubators = {}
-- Structure: incubators[incID] = {
--   unlockedRecipes = {recipeName = true, ...},
--   production = {recipeName = "...", startTime = tick(), duration = 60, player = player}
-- }

-------------------------------------------------
-- FONCTIONS UTILITAIRES
-------------------------------------------------

-- Effet de fumée pendant la production
local setSmokeEnabled

local function getSmokeAnchor(inc: Instance)
	-- Cherche une Part/Attachment nommée "smokeEffect" (ou "SmokeEffect") sous l'incubateur
	local anchor = inc:FindFirstChild("smokeEffect") or inc:FindFirstChild("SmokeEffect")
	if not anchor then anchor = inc:FindFirstChild("smokeEffect", true) end
	if not anchor then anchor = inc:FindFirstChild("SmokeEffect", true) end
	if anchor and (anchor:IsA("BasePart") or anchor:IsA("Attachment")) then
		return anchor
	end
	return nil
end

local function ensureSmokeEmitter(inc: Instance)
	local anchor = getSmokeAnchor(inc)
	if not anchor then return nil end
	local emitter = anchor:FindFirstChild("IncubatorSmoke")
	if emitter and emitter:IsA("ParticleEmitter") then return emitter end

	emitter = Instance.new("ParticleEmitter")
	emitter.Name = "IncubatorSmoke"
	emitter.Texture = "rbxassetid://291880914" -- fumée rose
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightInfluence = 0
	emitter.LightEmission = 0.1
	emitter.Rate = 7
	emitter.Lifetime = NumberRange.new(1.6, 2.8)
	emitter.Speed = NumberRange.new(0.3, 0.9)
	emitter.Acceleration = Vector3.new(0, 0.6, 0)
	emitter.Drag = 1.8
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Rotation = NumberRange.new(-8, 8)
	emitter.RotSpeed = NumberRange.new(-6, 6)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.6),
		NumberSequenceKeypoint.new(0.4, 1.1),
		NumberSequenceKeypoint.new(1.0, 1.8),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	emitter.Color = ColorSequence.new(
		Color3.fromRGB(255, 170, 220),
		Color3.fromRGB(255, 205, 235)
	)
	emitter.Enabled = false
	emitter.Parent = anchor
	return emitter
end

setSmokeEnabled = function(inc: Instance, enabled: boolean)
	local em = ensureSmokeEmitter(inc)
	if em then
		em.Enabled = enabled and true or false
	end
end

-- Trouve l'incubateur par son ID
local function getIncubatorByID(id)
	for _, p in ipairs(Workspace:GetDescendants()) do
		if p:IsA("StringValue") and p.Name == "ParcelID" and p.Value == id then
			local partWithPrompt = p.Parent
			if partWithPrompt then
				local model = partWithPrompt:FindFirstAncestorOfClass("Model")
				if model and model.Name == "Incubator" then
					return model
				end
				if model then return model end
				if partWithPrompt:IsA("BasePart") then
					return partWithPrompt
				end
			end
		end
	end
	return nil
end

-- Trouve le joueur propriétaire d'un incubateur
local function getOwnerPlayerFromIncID(incID)
	local inc = getIncubatorByID(incID)
	if not inc then return nil end
	
	local node = inc
	local islandContainer = nil
	while node do
		if node:IsA("Model") and (node.Name:match("^Ile_") or node.Name:match("^Ile_Slot_")) then
			islandContainer = node
			break
		end
		node = node.Parent
	end
	
	if not islandContainer then return nil end
	
	-- Cas Ile_<PlayerName>
	local playerName = islandContainer.Name:match("^Ile_(.+)$")
	if playerName and not playerName:match("^Slot_") then
		return Players:FindFirstChild(playerName)
	end
	
	-- Cas Ile_Slot_<n>
	local slotNumber = islandContainer.Name:match("Slot_(%d+)")
	if slotNumber then
		for _, player in ipairs(Players:GetPlayers()) do
			local slot = player:GetAttribute("IslandSlot")
			if slot and tostring(slot) == tostring(slotNumber) then
				return player
			end
		end
	end
	
	return nil
end

-- Normalise le nom d'un ingrédient (minuscules)
local function normalizeIngredientName(name)
	return tostring(name):lower()
end

-- Vérifie si le joueur a les ingrédients requis
local function hasIngredients(player, ingredients)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	
	-- Compter les ingrédients disponibles
	local available = {}
	
	local function countFromTool(tool)
		if not tool:IsA("Tool") then return end
		local isCandy = tool:GetAttribute("IsCandy")
		if isCandy then return end
		
		local baseName = tool:GetAttribute("BaseName")
		if baseName then
			local normalized = normalizeIngredientName(baseName)
			local count = tool:FindFirstChild("Count")
			if count and count.Value > 0 then
				available[normalized] = (available[normalized] or 0) + count.Value
			end
		end
	end
	
	if character then
		for _, tool in pairs(character:GetChildren()) do
			countFromTool(tool)
		end
	end
	
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			countFromTool(tool)
		end
	end
	
	-- Vérifier si on a assez
	for ingredient, needed in pairs(ingredients) do
		local normalized = normalizeIngredientName(ingredient)
		local have = available[normalized] or 0
		if have < needed then
			return false
		end
	end
	
	return true
end

-- Consomme les ingrédients de l'inventaire du joueur
local function consumeIngredients(player, ingredients)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	
	-- Créer une copie des quantités à consommer
	local toConsume = {}
	for ingredient, needed in pairs(ingredients) do
		toConsume[normalizeIngredientName(ingredient)] = needed
	end
	
	local function consumeFromTool(tool)
		if not tool:IsA("Tool") then return end
		local isCandy = tool:GetAttribute("IsCandy")
		if isCandy then return end
		
		local baseName = tool:GetAttribute("BaseName")
		if not baseName then return end
		
		local normalized = normalizeIngredientName(baseName)
		local needed = toConsume[normalized]
		if not needed or needed <= 0 then return end
		
		local count = tool:FindFirstChild("Count")
		if not count then
			count = Instance.new("IntValue")
			count.Name = "Count"
			count.Value = 1
			count.Parent = tool
		end
		
		if count.Value <= 0 then return end
		
		local toTake = math.min(count.Value, needed)
		count.Value = count.Value - toTake
		toConsume[normalized] = toConsume[normalized] - toTake
		
		if count.Value <= 0 then
			tool:Destroy()
		end
	end
	
	-- Consommer depuis le personnage
	if character then
		for _, tool in pairs(character:GetChildren()) do
			consumeFromTool(tool)
		end
	end
	
	-- Consommer depuis le sac
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			consumeFromTool(tool)
		end
	end
	
	-- Vérifier qu'on a tout consommé
	for _, remaining in pairs(toConsume) do
		if remaining > 0 then
			return false
		end
	end
	
	return true
end

-- Propulse un bonbon dans une direction
local function propel(part, direction)
	if not part or not part:IsA("BasePart") then return end
	local dir = typeof(direction) == "Vector3" and direction or Vector3.new(0, 0, -1)
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(4000, 4000, 4000)
	bv.Velocity = dir.Unit * 8
	bv.Parent = part
	game:GetService("Debris"):AddItem(bv, 0.3)
end

-- Trouve le point de spawn des bonbons
local function getCandySpawnTransform(inc)
	local preferredNames = {"CandySpawn", "CandyExit", "SpawnPoint", "CandyMouth", "BonbonSpawn"}
	local anchor = nil
	for _, n in ipairs(preferredNames) do
		anchor = inc:FindFirstChild(n, true)
		if anchor then break end
	end
	
	if anchor then
		if anchor:IsA("BasePart") then
			return anchor.CFrame, anchor.CFrame.LookVector
		elseif anchor:IsA("Attachment") then
			return anchor.WorldCFrame, anchor.WorldCFrame.LookVector
		end
	end
	
	-- Fallback: utiliser le centre de l'incubateur
	local center
	if inc:IsA("Model") then
		center = inc:GetPivot()
	else
		center = inc.CFrame
	end
	return center * CFrame.new(0, 2, 0), Vector3.new(0, 0, -1)
end

-- Fait apparaître un bonbon physique dans le monde
local function spawnCandy(recipeDef, inc, recipeName, ownerPlayer)
	if not ownerPlayer or not Players:GetPlayerByUserId(ownerPlayer.UserId) then
		return
	end
	
	local folder = ReplicatedStorage:FindFirstChild("CandyModels")
	if not folder then
		warn("❌ Dossier CandyModels introuvable pour spawn")
		return
	end
	
	local template = folder:FindFirstChild(recipeDef.modele)
	if not template then
		warn("❌ Modèle introuvable pour spawn:", recipeDef.modele)
		return
	end
	
	local clone = template:Clone()
	
	-- Tags pour identifier le bonbon
	local candyTag = Instance.new("StringValue")
	candyTag.Name = "CandyType"
	candyTag.Value = recipeName
	candyTag.Parent = clone
	
	local ownerTag = Instance.new("IntValue")
	ownerTag.Name = "CandyOwner"
	ownerTag.Value = ownerPlayer.UserId
	ownerTag.Parent = clone
	
	-- Ajouter l'ID de l'incubateur source
	local parcelIDObj = inc:FindFirstChild("ParcelID", true)
	if parcelIDObj and parcelIDObj:IsA("StringValue") then
		local sourceTag = Instance.new("StringValue")
		sourceTag.Name = "SourceIncubatorID"
		sourceTag.Value = parcelIDObj.Value
		sourceTag.Parent = clone
	end
	
	clone.Parent = Workspace
	
	-- Position de spawn
	local spawnCf, outDir = getCandySpawnTransform(inc)
	local spawnPos = spawnCf.Position + (outDir.Unit * 0.25)
	
	if clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(spawnPos, spawnPos + outDir)
		clone.Material = Enum.Material.Plastic
		clone.TopSurface = Enum.SurfaceType.Smooth
		clone.BottomSurface = Enum.SurfaceType.Smooth
		clone.CanTouch = false
		propel(clone, outDir)
	else -- Model
		clone:PivotTo(CFrame.new(spawnPos, spawnPos + outDir))
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then
				p.Material = Enum.Material.Plastic
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.CanTouch = false
				p.Anchored = false
				p.CanCollide = true
			end
		end
		local base = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if base then
			propel(base, outDir)
		end
	end
	
	print("🍬 Bonbon spawné:", recipeName, "à", spawnPos)
end

-- Donne des bonbons au joueur (VERSION ANCIENNE - pas utilisée maintenant)
local function giveCandies(player, candyName, quantity)
	print("🔧 Tentative de donner des bonbons:", candyName, "x", quantity, "à", player.Name)
	
	-- Chercher le modèle dans plusieurs endroits
	local template = nil
	local searchLocations = {
		{folder = ReplicatedStorage:FindFirstChild("CandyModels"), name = "CandyModels"},
		{folder = ReplicatedStorage:FindFirstChild("CandyTools"), name = "CandyTools"},
		{folder = ReplicatedStorage:FindFirstChild("Tools"), name = "Tools"},
	}
	
	for _, location in ipairs(searchLocations) do
		if location.folder then
			template = location.folder:FindFirstChild(candyName)
			if template then
				print("✅ Modèle trouvé dans", location.name, ":", template.Name, "Type:", template.ClassName)
				break
			end
		end
	end
	
	-- Si pas trouvé, chercher partout dans ReplicatedStorage
	if not template then
		print("🔍 Recherche élargie dans ReplicatedStorage...")
		for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
			if obj.Name == candyName and (obj:IsA("Tool") or obj:IsA("Model")) then
				template = obj
				print("✅ Modèle trouvé:", template:GetFullName(), "Type:", template.ClassName)
				break
			end
		end
	end
	
	if not template then 
		warn("❌ Modèle de bonbon introuvable:", candyName)
		-- Lister les modèles disponibles
		print("📋 Recherche de modèles similaires...")
		local similar = {}
		for _, location in ipairs(searchLocations) do
			if location.folder then
				for _, child in ipairs(location.folder:GetChildren()) do
					if child.Name:lower():find(candyName:lower()) or candyName:lower():find(child.Name:lower()) then
						table.insert(similar, location.name .. "/" .. child.Name)
					end
				end
			end
		end
		if #similar > 0 then
			print("🔍 Modèles similaires trouvés:")
			for _, name in ipairs(similar) do
				print("  -", name)
			end
		else
			print("📋 Aucun modèle similaire. Liste complète dans CandyModels:")
			local candyModels = ReplicatedStorage:FindFirstChild("CandyModels")
			if candyModels then
				for _, child in ipairs(candyModels:GetChildren()) do
					print("  -", child.Name)
				end
			end
		end
		return false 
	end
	
	-- Créer le tool
	local tool = template:Clone()
	
	-- Si c'est un Model, le convertir en Tool
	if tool:IsA("Model") then
		print("🔄 Conversion Model → Tool")
		local newTool = Instance.new("Tool")
		newTool.Name = template.Name
		newTool.RequiresHandle = false
		
		-- Copier tous les enfants
		for _, child in ipairs(tool:GetChildren()) do
			child.Parent = newTool
		end
		
		-- Copier les attributs
		for _, attr in ipairs(tool:GetAttributes()) do
			newTool:SetAttribute(attr, tool:GetAttribute(attr))
		end
		
		tool:Destroy()
		tool = newTool
	end
	
	-- Configurer le tool
	tool:SetAttribute("IsCandy", true)
	tool:SetAttribute("BaseName", candyName)
	
	-- Ajouter/mettre à jour le Count
	local count = tool:FindFirstChild("Count")
	if not count then
		count = Instance.new("IntValue")
		count.Name = "Count"
		count.Parent = tool
	end
	count.Value = quantity
	
	-- Vérifier que le tool a un Handle (requis pour les Tools)
	local handle = tool:FindFirstChild("Handle")
	if not handle then
		print("⚠️ Pas de Handle trouvé, création d'un Handle invisible")
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.Transparency = 1
		handle.CanCollide = false
		handle.Parent = tool
	end
	
	-- Ajouter au backpack
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		warn("❌ Backpack introuvable pour", player.Name)
		tool:Destroy()
		return false
	end
	
	tool.Parent = backpack
	print("✅ Bonbons ajoutés au backpack:", candyName, "x", quantity)
	
	return true
end

-- Initialise les données d'un incubateur
local function initIncubator(incID)
	if not incubators[incID] then
		incubators[incID] = {
			unlockedRecipes = {},
			production = nil
		}
	end
	return incubators[incID]
end

-- Sauvegarde les recettes débloquées dans PlayerData
local function saveUnlockedRecipes(player, incID)
	local data = incubators[incID]
	if not data then return end
	
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return end
	
	-- Créer un dossier pour les recettes débloquées
	local folder = playerData:FindFirstChild("UnlockedRecipes_" .. incID)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "UnlockedRecipes_" .. incID
		folder.Parent = playerData
	end
	
	-- Sauvegarder chaque recette
	for recipeName, unlocked in pairs(data.unlockedRecipes) do
		if unlocked then
			local flag = folder:FindFirstChild(recipeName)
			if not flag then
				flag = Instance.new("BoolValue")
				flag.Name = recipeName
				flag.Value = true
				flag.Parent = folder
			end
		end
	end
end

-- Charge les recettes débloquées depuis PlayerData
local function loadUnlockedRecipes(player, incID)
	local data = initIncubator(incID)
	
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return end
	
	local folder = playerData:FindFirstChild("UnlockedRecipes_" .. incID)
	if not folder then return end
	
	for _, flag in ipairs(folder:GetChildren()) do
		if flag:IsA("BoolValue") and flag.Value then
			data.unlockedRecipes[flag.Name] = true
		end
	end
end

-------------------------------------------------
-- HANDLERS
-------------------------------------------------

-- Débloquer une recette
unlockRecipeEvt.OnServerEvent:Connect(function(player, incID, recipeName)
	if not incID or not recipeName then return end
	
	-- Vérifier que le joueur est le propriétaire
	local owner = getOwnerPlayerFromIncID(incID)
	if owner ~= player then
		warn("❌ Unlock refusé: joueur n'est pas propriétaire")
		return
	end
	
	-- Vérifier que la recette existe
	local recipeDef = RecipeManager.Recettes[recipeName]
	if not recipeDef then
		warn("❌ Unlock refusé: recette introuvable:", recipeName)
		return
	end
	
	-- Vérifier que le joueur a les ingrédients (mais NE PAS les consommer)
	if not hasIngredients(player, recipeDef.ingredients) then
		warn("❌ Unlock refusé: pas assez d'ingrédients pour", recipeName)
		return
	end
	
	-- Débloquer la recette (SANS consommer les ingrédients)
	local data = initIncubator(incID)
	data.unlockedRecipes[recipeName] = true
	
	-- Sauvegarder
	saveUnlockedRecipes(player, incID)
	
	print("✅ Recette débloquée:", recipeName, "pour", player.Name, "(ingrédients NON consommés)")
end)

-- Démarrer la production
startProductionEvt.OnServerEvent:Connect(function(player, incID, recipeName)
	print("🔧 Demande de production reçue:", player.Name, incID, recipeName)
	
	if not incID or not recipeName then 
		warn("❌ Production refusée: paramètres manquants")
		return 
	end
	
	-- Vérifier que le joueur est le propriétaire
	local owner = getOwnerPlayerFromIncID(incID)
	if owner ~= player then
		warn("❌ Production refusée: joueur n'est pas propriétaire")
		return
	end
	
	-- Vérifier que la recette est débloquée
	local data = initIncubator(incID)
	if not data.unlockedRecipes[recipeName] then
		warn("❌ Production refusée: recette non débloquée:", recipeName)
		return
	end
	
	-- Vérifier qu'il n'y a pas déjà une production en cours
	if data.production then
		warn("❌ Production refusée: production déjà en cours")
		return
	end
	
	-- Vérifier que la recette existe
	local recipeDef = RecipeManager.Recettes[recipeName]
	if not recipeDef then
		warn("❌ Production refusée: recette introuvable:", recipeName)
		return
	end
	
	-- Vérifier que le joueur a les ingrédients
	if not hasIngredients(player, recipeDef.ingredients) then
		warn("❌ Production refusée: pas assez d'ingrédients")
		return
	end
	
	-- Consommer les ingrédients
	if not consumeIngredients(player, recipeDef.ingredients) then
		warn("❌ Production refusée: échec de consommation des ingrédients")
		return
	end
	
	-- Démarrer la production
	data.production = {
		recipeName = recipeName,
		startTime = tick(),
		duration = recipeDef.temps or 60,
		player = player
	}
	
	print("🏭 Production démarrée:", recipeName, "pour", player.Name, "durée:", data.production.duration, "s")
	
	-- Activer la fumée
	local incModel = getIncubatorByID(incID)
	if incModel then
		setSmokeEnabled(incModel, true)
		print("💨 Fumée activée pour l'incubateur")
	end
	
	-- Boucle de progression
	task.spawn(function()
		local prod = data.production
		if not prod then 
			warn("❌ Production annulée: données perdues")
			return 
		end
		
		print("🔄 Boucle de production démarrée pour", recipeName)
		
		while prod and data.production == prod do
			local elapsed = tick() - prod.startTime
			local progress = math.min(elapsed / prod.duration, 1)
			
			-- Envoyer la progression au client
			pcall(function()
				productionProgressEvt:FireClient(player, incID, progress, recipeName)
			end)
			
			-- Debug: afficher la progression toutes les 5 secondes
			if math.floor(elapsed) % 5 == 0 and math.floor(elapsed) > 0 then
				print(string.format("⏳ Production en cours: %.0f%% (%ds/%ds)", progress * 100, elapsed, prod.duration))
			end
			
			if progress >= 1 then
				-- Production terminée
				print("🎉 Production terminée! Spawn des bonbons...")
				local candiesPerBatch = recipeDef.candiesPerBatch or 1
				print("📦 Modèle à spawner:", recipeDef.modele, "Quantité:", candiesPerBatch)
				
				-- Spawner les bonbons physiquement dans le monde
				local incModel = getIncubatorByID(incID)
				if incModel then
					for i = 1, candiesPerBatch do
						spawnCandy(recipeDef, incModel, recipeName, player)
						-- Petit délai entre chaque bonbon pour éviter qu'ils se superposent
						if i < candiesPerBatch then
							task.wait(0.05)
						end
					end
					print("✅ Production terminée:", recipeName, "pour", player.Name, "→", candiesPerBatch, "bonbons spawnés")
				else
					warn("⚠️ Incubateur introuvable pour spawn")
				end
				
				-- Réinitialiser la production
				data.production = nil
				
				-- Désactiver la fumée
				if incModel then
					setSmokeEnabled(incModel, false)
					print("� Fumée idésactivée")
				end
				
				print("🔚 Production réinitialisée")
				break
			end
			
			task.wait(0.5)
		end
		
		print("🔚 Boucle de production terminée")
	end)
end)

-- Arrêter la production
stopProductionEvt.OnServerEvent:Connect(function(player, incID)
	if not incID then return end
	
	-- Vérifier que le joueur est le propriétaire
	local owner = getOwnerPlayerFromIncID(incID)
	if owner ~= player then
		return
	end
	
	local data = incubators[incID]
	if not data or not data.production then
		return
	end
	
	-- Arrêter la production (pas de remboursement)
	data.production = nil
	
	-- Désactiver la fumée
	local incModel = getIncubatorByID(incID)
	if incModel then
		setSmokeEnabled(incModel, false)
		print("💨 Fumée désactivée (arrêt manuel)")
	end
	
	print("🛑 Production arrêtée pour", player.Name)
end)

-- Récupérer les recettes débloquées
getUnlockedRecipesFunc.OnServerInvoke = function(player, incID)
	if not incID then return {} end
	
	-- Charger les recettes si pas encore fait
	local data = initIncubator(incID)
	loadUnlockedRecipes(player, incID)
	
	return data.unlockedRecipes
end

-------------------------------------------------
-- INITIALISATION
-------------------------------------------------

-- Charger les recettes débloquées au spawn du joueur
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- Attendre un peu pour que les îles soient chargées
		task.wait(2)
		
		-- Trouver tous les incubateurs du joueur
		for _, desc in ipairs(Workspace:GetDescendants()) do
			if desc:IsA("StringValue") and desc.Name == "ParcelID" then
				local incID = desc.Value
				local owner = getOwnerPlayerFromIncID(incID)
				if owner == player then
					loadUnlockedRecipes(player, incID)
				end
			end
		end
	end)
end)

print("✅ IncubatorServer_New chargé")
