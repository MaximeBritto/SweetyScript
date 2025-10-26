-- IncubatorServer_New.lua - Système simplifié de recettes
-- Gère le déblocage des recettes et la production

-------------------------------------------------
-- SERVICES & MODULES
-------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local CandySizeManager = require(ReplicatedStorage:WaitForChild("CandySizeManager"))

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

local addToQueueEvt = ReplicatedStorage:FindFirstChild("AddToQueue") or Instance.new("RemoteEvent")
addToQueueEvt.Name = "AddToQueue"
addToQueueEvt.Parent = ReplicatedStorage

local removeFromQueueEvt = ReplicatedStorage:FindFirstChild("RemoveFromQueue") or Instance.new("RemoteEvent")
removeFromQueueEvt.Name = "RemoveFromQueue"
removeFromQueueEvt.Parent = ReplicatedStorage

local finishNowRobuxEvt = ReplicatedStorage:FindFirstChild("FinishNowRobux") or Instance.new("RemoteEvent")
finishNowRobuxEvt.Name = "FinishNowRobux"
finishNowRobuxEvt.Parent = ReplicatedStorage

local getQueueFunc = ReplicatedStorage:FindFirstChild("GetQueue") or Instance.new("RemoteFunction")
getQueueFunc.Name = "GetQueue"
getQueueFunc.Parent = ReplicatedStorage

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
		local newCount = count.Value - toTake
		toConsume[normalized] = toConsume[normalized] - toTake
		
		if newCount <= 0 then
			-- Détruire le tool s'il est vide
			tool:Destroy()
		else
			-- FORCER LA MISE À JOUR VISUELLE en recréant le tool
			local parent = tool.Parent
			local newTool = tool:Clone()
			local newCountObj = newTool:FindFirstChild("Count")
			if newCountObj then
				newCountObj.Value = newCount
			end
			
			tool:Destroy()
			newTool.Parent = parent
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
	
	-- 🔧 NOUVEAU: S'assurer que la recette est dans le Candy Dex (sécurité supplémentaire)
	local playerData = ownerPlayer:FindFirstChild("PlayerData")
	if playerData then
		local recettesDecouvertes = playerData:FindFirstChild("RecettesDecouvertes")
		if recettesDecouvertes and not recettesDecouvertes:FindFirstChild(recipeName) then
			local recetteFlag = Instance.new("BoolValue")
			recetteFlag.Name = recipeName
			recetteFlag.Value = true
			recetteFlag.Parent = recettesDecouvertes
			print("🍬 [SPAWN] Recette ajoutée au Candy Dex:", recipeName, "pour", ownerPlayer.Name)
		end
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
	
	-- Générer une taille aléatoire pour le bonbon
	local sizeData = CandySizeManager.generateRandomSize()
	
	-- Appliquer la taille au modèle
	CandySizeManager.applySizeToModel(clone, sizeData)
	
	-- Sauvegarder les données de taille dans le bonbon (Attributes)
	CandySizeManager.applySizeDataToTool(clone, sizeData)
	
	-- AUSSI sauvegarder en Values pour compatibilité avec CandyPickupServer
	local sizeValue = Instance.new("NumberValue")
	sizeValue.Name = "CandySize"
	sizeValue.Value = sizeData.size
	sizeValue.Parent = clone
	
	local rarityValue = Instance.new("StringValue")
	rarityValue.Name = "CandyRarity"
	rarityValue.Value = sizeData.rarity
	rarityValue.Parent = clone
	
	local colorR = Instance.new("NumberValue")
	colorR.Name = "CandyColorR"
	colorR.Value = math.floor(sizeData.color.R * 255)
	colorR.Parent = clone
	
	local colorG = Instance.new("NumberValue")
	colorG.Name = "CandyColorG"
	colorG.Value = math.floor(sizeData.color.G * 255)
	colorG.Parent = clone
	
	local colorB = Instance.new("NumberValue")
	colorB.Name = "CandyColorB"
	colorB.Value = math.floor(sizeData.color.B * 255)
	colorB.Parent = clone
	
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
	
	print("🍬 Bonbon spawné:", recipeName, sizeData.rarity, string.format("%.2fx", sizeData.size), "à", spawnPos)
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

-- Forward declaration (déclaration anticipée)
local processQueue

-- Boucle de production (factorisée pour réutilisation)
local function startProductionLoop(incID, data, recipeDef, recipeName, player)
	local prod = data.production
	if not prod then 
		warn("Production cancelled: data lost")
		return 
	end
	
	print("Production loop started for", recipeName)
	
	local candiesPerBatch = recipeDef.candiesPerBatch or 1
	local spawnInterval = prod.duration / candiesPerBatch
	local candiesSpawned = prod.candiesProduced or 0  -- Commencer à partir des bonbons déjà produits
	local lastSpawnTime = prod.startTime + (candiesSpawned * spawnInterval)  -- Ajuster le temps du dernier spawn
	
	if candiesSpawned > 0 then
		print(string.format("🔄 Resuming production: %d/%d candies already produced", candiesSpawned, candiesPerBatch))
	end
	
	print(string.format("Config: %d candies in %ds = 1 candy every %.1fs", 
		candiesPerBatch, prod.duration, spawnInterval))
	
	while prod and data.production == prod and not prod.stopped do
		local elapsed = tick() - prod.startTime
		
		-- Progress for current candy (0 to 1 between each spawn)
		local timeSinceLastSpawn = tick() - lastSpawnTime
		local currentCandyProgress = math.min(timeSinceLastSpawn / spawnInterval, 1)
		
		-- Send progress to client
		pcall(function()
			productionProgressEvt:FireClient(player, incID, currentCandyProgress, recipeName, candiesSpawned, candiesPerBatch)
		end)
		
		-- Spawn candy if interval elapsed
		if candiesSpawned < candiesPerBatch then
			local timeSinceLastSpawn2 = tick() - lastSpawnTime
			if timeSinceLastSpawn2 >= spawnInterval then
				local incModel = getIncubatorByID(incID)
				if incModel then
					spawnCandy(recipeDef, incModel, recipeName, player)
					candiesSpawned = candiesSpawned + 1
					lastSpawnTime = tick()
					
					-- Sauvegarder la progression pour le snapshot offline
					prod.candiesProduced = candiesSpawned
					
					print(string.format("Candy %d/%d spawned", candiesSpawned, candiesPerBatch))
				end
			end
		end
		
		-- Debug every 5 seconds
		if math.floor(elapsed) % 5 == 0 and math.floor(elapsed) > 0 then
			local timeProgress = elapsed / prod.duration
			print(string.format("Production: %.0f%% - %d/%d candies", 
				timeProgress * 100, candiesSpawned, candiesPerBatch))
		end
		
		-- Check if production finished (time-based)
		local timeProgress = elapsed / prod.duration
		if timeProgress >= 1 then
			-- Production finished - spawn remaining candies
			print("Production finished!")
			
			local incModel = getIncubatorByID(incID)
			if incModel and candiesSpawned < candiesPerBatch then
				local remaining = candiesPerBatch - candiesSpawned
				print("Spawning", remaining, "remaining candies...")
				for i = 1, remaining do
					spawnCandy(recipeDef, incModel, recipeName, player)
					candiesSpawned = candiesSpawned + 1
					task.wait(0.05)
				end
			end
			
			print("Total:", candiesSpawned, "candies spawned for", player.Name)
			
			-- Signal au client que la production est terminée (pour cacher le billboard)
			pcall(function()
				productionProgressEvt:FireClient(player, incID, 0, recipeName, 0, 0)
			end)
			
			-- Reset production
			data.production = nil
			
			-- Try to process queue
			local hasQueue = processQueue(incID, data)
			
			-- Disable smoke only if no queue
			if not hasQueue and incModel then
				setSmokeEnabled(incModel, false)
				print("Smoke disabled")
			end
			
			print("Production reset")
			break
		end
		
		task.wait(0.1)
	end
	
	print("Production loop finished")
end

-- Traite la queue de production (lance la prochaine recette)
processQueue = function(incID, data)
	if not data or not data.queue or #data.queue == 0 then
		return false
	end
	
	-- Récupérer la prochaine recette dans la queue
	local nextItem = table.remove(data.queue, 1)
	local recipeName = nextItem.recipeName
	local player = nextItem.player
	
	-- Vérifier que le joueur est toujours connecté
	if not player or not Players:GetPlayerByUserId(player.UserId) then
		print("⚠️ Player disconnected, skipping queue item")
		return processQueue(incID, data) -- Essayer le suivant
	end
	
	-- Vérifier que la recette existe
	local recipeDef = RecipeManager.Recettes[recipeName]
	if not recipeDef then
		print("⚠️ Recipe not found, skipping:", recipeName)
		return processQueue(incID, data) -- Essayer le suivant
	end
	
	-- NOTE: Les ingrédients ont déjà été consommés lors de l'ajout à la queue
	-- On ne les consomme PAS ici
	
	-- Démarrer la production
	data.production = {
		recipeName = recipeName,
		startTime = tick(),
		duration = recipeDef.temps or 60,
		player = player
	}
	data.ownerUserId = player.UserId
	
	print("🔄 Queue: Starting next production:", recipeName, "for", player.Name)
	
	-- Activer la fumée
	local incModel = getIncubatorByID(incID)
	if incModel then
		setSmokeEnabled(incModel, true)
	end
	
	-- Lancer la boucle de production
	task.spawn(function()
		startProductionLoop(incID, data, recipeDef, recipeName, player)
	end)
	
	return true
end

-- Initialise les données d'un incubateur
local function initIncubator(incID)
	if not incubators[incID] then
		incubators[incID] = {
			unlockedRecipes = {},
			production = nil,
			queue = {}  -- File d'attente de production
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
	
	-- Créer le dossier RecettesDecouvertes s'il n'existe pas
	local recettesDecouvertes = playerData:FindFirstChild("RecettesDecouvertes")
	if not recettesDecouvertes then
		recettesDecouvertes = Instance.new("Folder")
		recettesDecouvertes.Name = "RecettesDecouvertes"
		recettesDecouvertes.Parent = playerData
		print("📚 [LOAD] Création du dossier RecettesDecouvertes pour", player.Name)
	end
	
	for _, flag in ipairs(folder:GetChildren()) do
		if flag:IsA("BoolValue") and flag.Value then
			data.unlockedRecipes[flag.Name] = true
			
			-- 🔧 NOUVEAU: Synchroniser avec le Candy Dex
			if not recettesDecouvertes:FindFirstChild(flag.Name) then
				local recetteFlag = Instance.new("BoolValue")
				recetteFlag.Name = flag.Name
				recetteFlag.Value = true
				recetteFlag.Parent = recettesDecouvertes
				print("🔄 [LOAD] Recette synchronisée au Candy Dex:", flag.Name, "pour", player.Name)
			end
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
	
	-- 🔧 NOUVEAU: Ajouter la recette au Candy Dex (RecettesDecouvertes)
	local playerData = player:FindFirstChild("PlayerData")
	if playerData then
		local recettesDecouvertes = playerData:FindFirstChild("RecettesDecouvertes")
		if not recettesDecouvertes then
			recettesDecouvertes = Instance.new("Folder")
			recettesDecouvertes.Name = "RecettesDecouvertes"
			recettesDecouvertes.Parent = playerData
			print("📚 [UNLOCK] Création du dossier RecettesDecouvertes pour", player.Name)
		end
		
		-- Vérifier si la recette n'est pas déjà découverte
		if not recettesDecouvertes:FindFirstChild(recipeName) then
			local recetteFlag = Instance.new("BoolValue")
			recetteFlag.Name = recipeName
			recetteFlag.Value = true
			recetteFlag.Parent = recettesDecouvertes
			print("🍬 [CANDY DEX] Nouvelle recette découverte:", recipeName, "pour", player.Name)
		end
		
		-- Débloquer aussi les ingrédients utilisés dans le Candy Dex
		local ingredientsDecouverts = playerData:FindFirstChild("IngredientsDecouverts")
		if not ingredientsDecouverts then
			ingredientsDecouverts = Instance.new("Folder")
			ingredientsDecouverts.Name = "IngredientsDecouverts"
			ingredientsDecouverts.Parent = playerData
			print("📚 [UNLOCK] Création du dossier IngredientsDecouverts pour", player.Name)
		end
		
		-- Ajouter chaque ingrédient au dossier IngredientsDecouverts
		for ingredientName, quantity in pairs(recipeDef.ingredients) do
			local normalized = ingredientName:sub(1,1):upper() .. ingredientName:sub(2)
			if not ingredientsDecouverts:FindFirstChild(normalized) then
				local ingredientFlag = Instance.new("BoolValue")
				ingredientFlag.Name = normalized
				ingredientFlag.Value = true
				ingredientFlag.Parent = ingredientsDecouverts
				print("🥕 [CANDY DEX] Nouvel ingrédient découvert:", normalized, "pour", player.Name)
			end
		end
	end
	
	print("✅ Recette débloquée:", recipeName, "pour", player.Name, "(ingrédients NON consommés)")
	
	-- 🎓 TUTORIEL: Détecter le déblocage de recette
	if _G.TutorialManager and _G.TutorialManager.onRecipeUnlocked then
		_G.TutorialManager.onRecipeUnlocked(player, recipeName)
	end
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
	data.ownerUserId = player.UserId
	
	print("🏭 Production démarrée:", recipeName, "pour", player.Name, "durée:", data.production.duration, "s")
	
	-- Activer la fumée
	local incModel = getIncubatorByID(incID)
	if incModel then
		setSmokeEnabled(incModel, true)
		print("💨 Smoke enabled for incubator")
	end
	
	-- Lancer la boucle de production
	task.spawn(function()
		startProductionLoop(incID, data, recipeDef, recipeName, player)
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
	
	-- Arrêter la production en cours (PAS de remboursement pour celle-ci)
	data.production = nil
	
	-- Rembourser les ingrédients de la queue
	print("� Reefunding queue items. Queue size:", #data.queue)
	
	for i, queueItem in ipairs(data.queue) do
		if queueItem.ingredients and queueItem.player and Players:GetPlayerByUserId(queueItem.player.UserId) then
			print("💰 Refunding recipe:", queueItem.recipeName)
			
			-- Pour chaque ingrédient, chercher un tool existant ou en créer un nouveau
			for ingredientName, quantity in pairs(queueItem.ingredients) do
				local normalized = normalizeIngredientName(ingredientName)
				local backpack = queueItem.player:FindFirstChildOfClass("Backpack")
				local character = queueItem.player.Character
				
				-- Chercher un tool existant avec ce BaseName
				local foundTool = nil
				if backpack then
					for _, tool in pairs(backpack:GetChildren()) do
						if tool:IsA("Tool") and tool:GetAttribute("BaseName") then
							if normalizeIngredientName(tool:GetAttribute("BaseName")) == normalized then
								foundTool = tool
								break
							end
						end
					end
				end
				
				if foundTool then
					-- FORCER LA MISE À JOUR VISUELLE en recréant le tool
					local count = foundTool:FindFirstChild("Count")
					if count then
						local newCount = count.Value + quantity
						local parent = foundTool.Parent
						
						-- Cloner le tool avec le nouveau Count
						local newTool = foundTool:Clone()
						local newCountObj = newTool:FindFirstChild("Count")
						if newCountObj then
							newCountObj.Value = newCount
						end
						
						-- Détruire l'ancien et ajouter le nouveau
						foundTool:Destroy()
						newTool.Parent = parent
						
						print("✅ Refunded", quantity, ingredientName, "→ Total:", newCount)
					end
				else
					-- Pas de tool existant - on ne peut pas créer un nouveau sans template
					print("⚠️ No existing tool found for", ingredientName, "- cannot refund (no template)")
				end
			end
		end
	end
	
	-- Vider la queue
	data.queue = {}
	
	-- Désactiver la fumée
	local incModel = getIncubatorByID(incID)
	if incModel then
		setSmokeEnabled(incModel, false)
		print("💨 Smoke disabled (manual stop)")
	end
	
	-- Envoyer un signal au client pour cacher le billboard
	pcall(function()
		productionProgressEvt:FireClient(player, incID, 0, "", 0, 0)
	end)
	
	print("🛑 Production stopped for", player.Name, "(queue refunded)")
end)

-- Ajouter une recette (production ou queue selon l'état)
addToQueueEvt.OnServerEvent:Connect(function(player, incID, recipeName)
	if not incID or not recipeName then return end
	
	-- 🎓 TUTORIEL: Détecter le clic sur PRODUCE
	if _G.TutorialManager and _G.TutorialManager.onProductionStarted then
		_G.TutorialManager.onProductionStarted(player, recipeName)
	end
	
	-- Vérifier propriétaire
	local owner = getOwnerPlayerFromIncID(incID)
	if owner ~= player then
		warn("❌ Request refused: not owner")
		return
	end
	
	-- Vérifier recette débloquée
	local data = initIncubator(incID)
	if not data.unlockedRecipes[recipeName] then
		warn("❌ Request refused: recipe not unlocked")
		return
	end
	
	-- Vérifier que la recette existe
	local recipeDef = RecipeManager.Recettes[recipeName]
	if not recipeDef then
		warn("❌ Request refused: recipe not found")
		return
	end
	
	-- VÉRIFIER ET CONSOMMER LES INGRÉDIENTS IMMÉDIATEMENT
	if not hasIngredients(player, recipeDef.ingredients) then
		warn("❌ Request refused: not enough ingredients")
		return
	end
	
	if not consumeIngredients(player, recipeDef.ingredients) then
		warn("❌ Request refused: failed to consume ingredients")
		return
	end
	
	-- Si aucune production en cours, lancer immédiatement
	if not data.production then
		data.production = {
			recipeName = recipeName,
			startTime = tick(),
			duration = recipeDef.temps or 60,
			player = player,
			ingredients = recipeDef.ingredients -- Sauvegarder pour remboursement si besoin
		}
		data.ownerUserId = player.UserId
		
		print("🏭 Production started:", recipeName, "for", player.Name)
		
		-- Activer la fumée
		local incModel = getIncubatorByID(incID)
		if incModel then
			setSmokeEnabled(incModel, true)
		end
		
		-- Envoyer un signal au client pour afficher l'overlay
		pcall(function()
			productionProgressEvt:FireClient(player, incID, 0, recipeName, 0, recipeDef.candiesPerBatch or 60)
		end)
		
		-- Lancer la boucle de production
		task.spawn(function()
			startProductionLoop(incID, data, recipeDef, recipeName, player)
		end)
	else
		-- Production en cours, ajouter à la queue
		-- Vérifier limite queue (max 10)
		if #data.queue >= 10 then
			warn("❌ Queue full (max 10)")
			-- TODO: Rembourser les ingrédients ici
			return
		end
		
		table.insert(data.queue, {
			recipeName = recipeName,
			player = player,
			addedTime = tick(),
			ingredients = recipeDef.ingredients -- Sauvegarder pour remboursement
		})
		
		print("✅ Added to queue:", recipeName, "Queue size:", #data.queue)
	end
end)

-- Retirer une recette de la queue
removeFromQueueEvt.OnServerEvent:Connect(function(player, incID, index)
	if not incID or not index then return end
	
	-- Vérifier propriétaire
	local owner = getOwnerPlayerFromIncID(incID)
	if owner ~= player then
		return
	end
	
	local data = incubators[incID]
	if not data or not data.queue then return end
	
	if index >= 1 and index <= #data.queue then
		local removed = table.remove(data.queue, index)
		print("🗑️ Removed from queue:", removed.recipeName, "at position", index)
	end
end)

-- Finir la production avec Robux
finishNowRobuxEvt.OnServerEvent:Connect(function(player, incID)
	print("💎 Finish now request:", player.Name)
	
	if not incID then return end
	
	-- Vérifier propriétaire
	local owner = getOwnerPlayerFromIncID(incID)
	if owner ~= player then
		warn("❌ Finish refused: not owner")
		return
	end
	
	local data = incubators[incID]
	if not data or not data.production then
		warn("❌ Finish refused: no production active")
		return
	end
	
	local prod = data.production
	local recipeDef = RecipeManager.Recettes[prod.recipeName]
	if not recipeDef then return end
	
	-- Calculer le prix
	local elapsed = tick() - prod.startTime
	local remaining = math.max(0, prod.duration - elapsed)
	local price = math.max(5, math.min(50, math.ceil(remaining / 60) * 5))
	
	print("💰 Finish price:", price, "Robux for", remaining, "seconds")
	
	-- Prompt achat Robux
	local MarketplaceService = game:GetService("MarketplaceService")
	local success, result = pcall(function()
		return MarketplaceService:PromptProductPurchase(player, price)
	end)
	
	if not success then
		warn("❌ Robux prompt failed:", result)
		return
	end
	
	-- Note: Le callback de l'achat sera géré par ProcessReceipt
	-- Pour l'instant, on termine directement (à adapter selon ton système)
	
	print("⚡ Finishing production instantly...")
	
	-- Spawner tous les bonbons restants
	local candiesPerBatch = recipeDef.candiesPerBatch or 1
	local incModel = getIncubatorByID(incID)
	
	if incModel then
		-- Compter combien de bonbons ont déjà été spawnés
		-- (on ne peut pas le savoir ici, donc on spawn tout le batch)
		for i = 1, candiesPerBatch do
			spawnCandy(recipeDef, incModel, prod.recipeName, player)
			if i < candiesPerBatch and i % 10 == 0 then
				task.wait(0.05) -- Petit délai tous les 10 bonbons
			end
		end
		print("✅ All candies spawned instantly")
	end
	
	-- Signal au client que la production est terminée (pour cacher le billboard)
	pcall(function()
		productionProgressEvt:FireClient(player, incID, 0, prod.recipeName, 0, 0)
	end)
	
	-- Réinitialiser et traiter la queue
	data.production = nil
	local hasQueue = processQueue(incID, data)
	
	if not hasQueue and incModel then
		setSmokeEnabled(incModel, false)
	end
	
	print("⚡ Production finished instantly")
end)

-- Récupérer la queue
getQueueFunc.OnServerInvoke = function(player, incID)
	if not incID then return {} end
	
	local data = incubators[incID]
	if not data or not data.queue then return {} end
	
	-- Retourner seulement les noms des recettes
	local queueNames = {}
	for i, item in ipairs(data.queue) do
		queueNames[i] = item.recipeName
	end
	
	return queueNames
end

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

-------------------------------------------------
-- API GLOBALE POUR PRODUCTION OFFLINE
-------------------------------------------------

-- Initialiser l'API globale
if not _G.Incubator then
	_G.Incubator = {}
end

-- Fonction helper: Calculer combien de bonbons ont été produits
local function calculateCandiesProduced(production, recipeDef)
	if not production or not recipeDef then return 0 end
	
	local elapsed = tick() - production.startTime
	local candiesPerBatch = recipeDef.candiesPerBatch or 60
	local spawnInterval = production.duration / candiesPerBatch
	
	return math.min(math.floor(elapsed / spawnInterval), candiesPerBatch)
end

-- Helper: Extraire l'index d'un incubateur depuis son ID
local function getIncubatorIndexFromID(incID)
	-- Format: "Ile_Slot_X_Y" ou "Ile_Name_Y" -> extraire le dernier chiffre
	local idx = tonumber(string.match(incID or "", "_(%d+)$"))
	return idx
end

-- Helper: Trouver un incubateur par index sur l'île du joueur
local function findIncubatorByIndexForPlayer(userId, index)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return nil end
	
	-- Trouver l'île du joueur
	local island = Workspace:FindFirstChild("Ile_" .. player.Name)
	if not island then
		local slot = player:GetAttribute("IslandSlot")
		island = slot and Workspace:FindFirstChild("Ile_Slot_" .. tostring(slot))
	end
	
	if not island then return nil end
	
	-- Chercher l'incubateur avec cet index dans l'île
	for _, obj in ipairs(island:GetDescendants()) do
		if obj:IsA("StringValue") and obj.Name == "ParcelID" then
			local parcelIdx = tonumber(string.match(obj.Value or "", "_(%d+)$"))
			if parcelIdx == index then
				return obj.Value  -- Retourner le nouvel ID complet
			end
		end
	end
	
	return nil
end

-- NOUVELLE FONCTION: Sauvegarder les recettes débloquées
function _G.Incubator.getUnlockedRecipesForPlayer(userId)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return {} end
	
	local allUnlocked = {}
	
	for incID, data in pairs(incubators) do
		local ownerUserId = data.ownerUserId
		if not ownerUserId then
			local owner = getOwnerPlayerFromIncID(incID)
			ownerUserId = owner and owner.UserId
		end
		
		if ownerUserId == userId and data.unlockedRecipes then
			-- Extraire l'index de l'incubateur
			local incIndex = getIncubatorIndexFromID(incID)
			if incIndex then
				allUnlocked[incIndex] = {}
				for recipeName, unlocked in pairs(data.unlockedRecipes) do
					if unlocked then
						table.insert(allUnlocked[incIndex], recipeName)
					end
				end
			end
		end
	end
	
	return allUnlocked
end

-- NOUVELLE FONCTION: Restaurer les recettes débloquées
function _G.Incubator.restoreUnlockedRecipesForPlayer(userId, unlockedData)
	if type(unlockedData) ~= "table" then return end
	
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	
	for incIndex, recipes in pairs(unlockedData) do
		local incID = findIncubatorByIndexForPlayer(userId, incIndex)
		if incID then
			local data = initIncubator(incID)
			for _, recipeName in ipairs(recipes) do
				data.unlockedRecipes[recipeName] = true
			end
			print("✅ [RESTORE] Restored", #recipes, "recipes for incubator index", incIndex)
		end
	end
end

-- 1. SNAPSHOT: Sauvegarder l'état de production pour un joueur
function _G.Incubator.snapshotProductionForPlayer(userId)
	print("📸 [SNAPSHOT] Called for user", userId)
	local snapshots = {}
	
	local totalIncubators = 0
	for _ in pairs(incubators) do totalIncubators = totalIncubators + 1 end
	print("📸 [SNAPSHOT] Total incubators:", totalIncubators)
	
	for incID, data in pairs(incubators) do
		print("📸 [SNAPSHOT] Checking incubator:", incID)
		
		-- Extraire le userId depuis l'incubatorID (format: Ile_Slot_X_Y ou Ile_PlayerName)
		-- On utilise data.ownerUserId si disponible, sinon on cherche le joueur
		local ownerUserId = data.ownerUserId
		if not ownerUserId then
			local owner = getOwnerPlayerFromIncID(incID)
			ownerUserId = owner and owner.UserId
		end
		
		print("📸 [SNAPSHOT] OwnerUserId:", ownerUserId, "Target:", userId)
		
		if ownerUserId == userId then
			print("📸 [SNAPSHOT] Owner matches! Has production:", data.production ~= nil)
			if data.production then
				print("📸 [SNAPSHOT] Production found:", data.production.recipeName)
				local recipeDef = RecipeManager.Recettes[data.production.recipeName]
				if recipeDef then
					local candiesProduced = calculateCandiesProduced(data.production, recipeDef)
					
					-- Extraire l'INDEX au lieu de sauvegarder l'ID complet
					local incIndex = getIncubatorIndexFromID(incID)
					if not incIndex then
						warn("⚠️ [SNAPSHOT] Cannot extract index from:", incID)
						continue
					end
					
					table.insert(snapshots, {
						incubatorIndex = incIndex,  -- INDEX au lieu de incubatorID
						recipeName = data.production.recipeName,
						startTime = data.production.startTime,
						duration = data.production.duration,
						candiesProduced = candiesProduced,
						candiesTotal = recipeDef.candiesPerBatch or 60,
						queue = data.queue or {}
					})
					
					print("💾 Snapshot production: Index", incIndex, data.production.recipeName, candiesProduced .. "/" .. (recipeDef.candiesPerBatch or 60))
				end
			end
		end
	end
	
	if #snapshots > 0 then
		print("✅ Saved", #snapshots, "production(s) for user", userId)
	end
	
	return snapshots
end

-- 2. RESTORE: Restaurer l'état de production (sans appliquer offline)
function _G.Incubator.restoreProductionForPlayer(userId, entries)
	if type(entries) ~= "table" then return end
	
	local restored = 0
	
	for _, entry in ipairs(entries) do
		local incIndex = entry.incubatorIndex
		if not incIndex then 
			print("⚠️ [RESTORE] Entry without incubatorIndex")
			continue 
		end
		
		print("🔍 [RESTORE] Looking for incubator index:", incIndex, "for user", userId)
		
		-- Trouver l'incubateur par index sur la NOUVELLE île du joueur
		local incID = findIncubatorByIndexForPlayer(userId, incIndex)
		if not incID then
			print("⚠️ [RESTORE] Incubator index", incIndex, "not found on player's island")
			continue
		end
		
		print("✅ [RESTORE] Found incubator:", incID, "for index:", incIndex)
		
		local owner = Players:GetPlayerByUserId(userId)
		if not owner then
			print("⚠️ [RESTORE] Player not found:", userId)
			continue
		end
		
		local recipeDef = RecipeManager.Recettes[entry.recipeName]
		if not recipeDef then
			warn("⚠️ Recipe not found for restore:", entry.recipeName)
			continue
		end
		
		-- Restaurer la production
		local data = initIncubator(incID)
		data.production = {
			recipeName = entry.recipeName,
			startTime = entry.startTime or tick(),
			duration = entry.duration or 60,
			player = owner,
			candiesProduced = entry.candiesProduced or 0,
			ingredients = recipeDef.ingredients
		}
		data.ownerUserId = userId
		
		-- Restaurer la queue
		if entry.queue and type(entry.queue) == "table" then
			data.queue = {}
			for _, queueItem in ipairs(entry.queue) do
				table.insert(data.queue, {
					recipeName = queueItem.recipeName,
					player = owner,
					addedTime = tick(),
					ingredients = queueItem.ingredients
				})
			end
		end
		
		-- Activer la fumée
		local incModel = getIncubatorByID(incID)
		if incModel then
			setSmokeEnabled(incModel, true)
		end
		
		-- NE PAS relancer la boucle ici - c'est applyOfflineForPlayer qui le fera après avoir généré les bonbons offline
		
		restored = restored + 1
		print("🔄 Restored production:", incID, entry.recipeName, entry.candiesProduced .. "/" .. entry.candiesTotal)
	end
	
	if restored > 0 then
		print("✅ Restored", restored, "production(s) for user", userId)
	end
end

-- Tracker pour éviter de générer plusieurs fois les bonbons offline
local offlineProcessed = {}

-- 3. APPLY OFFLINE: Appliquer les gains offline
function _G.Incubator.applyOfflineForPlayer(userId, offlineSeconds)
	offlineSeconds = math.max(0, tonumber(offlineSeconds) or 0)
	if offlineSeconds <= 0 then return end
	
	-- Vérifier si déjà traité
	if offlineProcessed[userId] then
		print("⚠️ Offline production already processed for user", userId)
		return
	end
	
	print("⏰ Applying", offlineSeconds, "seconds of offline production for user", userId)
	offlineProcessed[userId] = true
	
	-- Nettoyer après 10 secondes (pour permettre une nouvelle reconnexion plus tard)
	task.delay(10, function()
		offlineProcessed[userId] = nil
	end)
	
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		warn("⚠️ Player not found for offline production")
		return
	end
	
	local incubatorCount = 0
	for _ in pairs(incubators) do incubatorCount = incubatorCount + 1 end
	print("🔍 Total incubators:", incubatorCount)
	
	for incID, data in pairs(incubators) do
		print("🔍 Checking incubator:", incID)
		
		local owner = getOwnerPlayerFromIncID(incID)
		print("🔍 Owner:", owner and owner.Name or "nil", "UserId:", owner and owner.UserId or "nil")
		
		if not owner or owner.UserId ~= userId then
			print("❌ Owner mismatch, skipping")
			continue
		end
		
		print("✅ Owner matches!")
		
		if data.production then
			print("✅ Production found!")
			local prod = data.production
			print("🔍 Recipe:", prod.recipeName)
			print("🔍 StartTime:", prod.startTime)
			print("🔍 Duration:", prod.duration)
			print("🔍 CandiesProduced:", prod.candiesProduced or 0)
			
			local recipeDef = RecipeManager.Recettes[prod.recipeName]
			if not recipeDef then 
				print("❌ Recipe def not found")
				continue 
			end
			
			local candiesPerBatch = recipeDef.candiesPerBatch or 60
			local spawnInterval = prod.duration / candiesPerBatch
			local candiesProduced = prod.candiesProduced or 0
			
			print("🔍 CandiesPerBatch:", candiesPerBatch)
			print("🔍 SpawnInterval:", spawnInterval)
			
			-- Calculer combien de bonbons ont été produits offline
			local totalElapsed = (tick() - prod.startTime) + offlineSeconds
			local totalCanProduce = math.floor(totalElapsed / spawnInterval)
			local newCandies = math.min(totalCanProduce - candiesProduced, candiesPerBatch - candiesProduced)
			
			print("🔍 TotalElapsed:", totalElapsed)
			print("🔍 TotalCanProduce:", totalCanProduce)
			print("🔍 NewCandies:", newCandies)
			
			if newCandies > 0 then
				print("🌙 Offline production:", incID, prod.recipeName, newCandies, "candies")
				
				-- Spawner les bonbons
				local incModel = getIncubatorByID(incID)
				if incModel then
					for i = 1, newCandies do
						spawnCandy(recipeDef, incModel, prod.recipeName, owner)
						
						-- Petit délai pour éviter le lag
						if i % 10 == 0 then
							task.wait(0.05)
						end
					end
					
					prod.candiesProduced = candiesProduced + newCandies
					
					-- Si production terminée, traiter la queue
					if prod.candiesProduced >= candiesPerBatch then
						print("✅ Offline production completed:", prod.recipeName)
						data.production = nil
						
						-- Traiter la queue si présente
						if data.queue and #data.queue > 0 then
							print("🔄 Processing queue after offline production...")
							processQueue(incID, data)
						end
					else
						-- Mettre à jour le startTime pour la progression continue
						prod.startTime = tick() - (prod.candiesProduced * spawnInterval)
					end
				end
			else
				print("❌ NewCandies <= 0, nothing to spawn")
			end
		else
			print("❌ No production found for this incubator")
		end
	end
	
	print("✅ Offline production processing complete")
	
	-- Maintenant relancer les boucles de production pour les productions non terminées
	for incID, data in pairs(incubators) do
		local owner = getOwnerPlayerFromIncID(incID)
		local ownerUserId = data.ownerUserId
		if not ownerUserId then
			ownerUserId = owner and owner.UserId
		end
		
		if ownerUserId == userId and data.production then
			local prod = data.production
			local recipeDef = RecipeManager.Recettes[prod.recipeName]
			if recipeDef then
				local candiesPerBatch = recipeDef.candiesPerBatch or 60
				if prod.candiesProduced < candiesPerBatch then
					print("🔄 Relaunching production loop for:", incID, prod.recipeName, prod.candiesProduced .. "/" .. candiesPerBatch)
					task.spawn(function()
						startProductionLoop(incID, data, recipeDef, prod.recipeName, player)
					end)
				end
			end
		end
	end
end

-- 4. RESTORE GROUND CANDIES: Restaurer les bonbons au sol
function _G.Incubator.restoreGroundCandies(player, candiesData)
	if not player or not candiesData or type(candiesData) ~= "table" then return end
	
	print("🍬 [RESTORE] Restauration de", #candiesData, "bonbons pour", player.Name)
	
	-- Trouver l'île du joueur et construire la map des spawn points
	local playerIsland = Workspace:FindFirstChild("Ile_" .. player.Name)
	local incubatorSpawnMap = {}
	
	if playerIsland then
		for _, parcel in ipairs(playerIsland:GetChildren()) do
			if parcel:IsA("Model") and parcel.Name:match("^Parcel") then
				local parcelID = nil
				for _, obj in ipairs(parcel:GetDescendants()) do
					if obj:IsA("StringValue") and obj.Name == "ParcelID" then
						parcelID = obj.Value
						break
					end
				end
				
				local spawnPoint = parcel:FindFirstChild("SpawnCandyAtReconnexion", true)
				if spawnPoint and spawnPoint:IsA("BasePart") and parcelID then
					incubatorSpawnMap[parcelID] = spawnPoint.Position
					print("🔗 [RESTORE] Spawn point trouvé:", parcelID, "→", spawnPoint.Position)
				end
			end
		end
	end
	
	-- Position par défaut si aucun spawn point
	local defaultSpawn = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	defaultSpawn = defaultSpawn and defaultSpawn.Position + Vector3.new(0, 5, 10) or Vector3.new(0, 10, 0)
	
	-- Restaurer chaque bonbon
	for _, candyData in ipairs(candiesData) do
		local folder = ReplicatedStorage:FindFirstChild("CandyModels")
		if not folder then continue end
		
		local recipeDef = RecipeManager.Recettes[candyData.candyType]
		if not recipeDef then continue end
		
		local template = folder:FindFirstChild(recipeDef.modele)
		if not template then continue end
		
		local clone = template:Clone()
		
		-- Tags
		local candyTag = Instance.new("StringValue")
		candyTag.Name = "CandyType"
		candyTag.Value = candyData.candyType
		candyTag.Parent = clone
		
		local ownerTag = Instance.new("IntValue")
		ownerTag.Name = "CandyOwner"
		ownerTag.Value = player.UserId
		ownerTag.Parent = clone
		
		-- Restaurer SourceIncubatorID
		if candyData.sourceIncubatorID then
			local sourceTag = Instance.new("StringValue")
			sourceTag.Name = "SourceIncubatorID"
			sourceTag.Value = candyData.sourceIncubatorID
			sourceTag.Parent = clone
		end
		
		-- Restaurer taille et couleur
		if candyData.size and candyData.rarity then
			local sizeValue = Instance.new("NumberValue")
			sizeValue.Name = "CandySize"
			sizeValue.Value = candyData.size
			sizeValue.Parent = clone
			
			local rarityValue = Instance.new("StringValue")
			rarityValue.Name = "CandyRarity"
			rarityValue.Value = candyData.rarity
			rarityValue.Parent = clone
			
			local colorR = Instance.new("NumberValue")
			colorR.Name = "CandyColorR"
			colorR.Value = candyData.colorR or 255
			colorR.Parent = clone
			
			local colorG = Instance.new("NumberValue")
			colorG.Name = "CandyColorG"
			colorG.Value = candyData.colorG or 255
			colorG.Parent = clone
			
			local colorB = Instance.new("NumberValue")
			colorB.Name = "CandyColorB"
			colorB.Value = candyData.colorB or 255
			colorB.Parent = clone
			
			-- Appliquer la taille
			if CandySizeManager then
				local sizeDataObj = {
					size = candyData.size,
					rarity = candyData.rarity,
					color = Color3.fromRGB(candyData.colorR or 255, candyData.colorG or 255, candyData.colorB or 255)
				}
				pcall(function()
					CandySizeManager.applySizeToModel(clone, sizeDataObj)
				end)
			end
		end
		
		-- Ancrer temporairement
		local partsToUnanchor = {}
		if clone:IsA("Model") then
			for _, part in ipairs(clone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
					table.insert(partsToUnanchor, part)
				end
			end
		elseif clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			table.insert(partsToUnanchor, clone)
		end
		
		-- Trouver le spawn point spécifique
		local spawnPos = defaultSpawn
		if candyData.sourceIncubatorID and incubatorSpawnMap[candyData.sourceIncubatorID] then
			spawnPos = incubatorSpawnMap[candyData.sourceIncubatorID]
		end
		
		-- Positionner
		clone.Parent = Workspace
		local angle = math.random() * math.pi * 2
		local radius = math.random(1, 4)
		local offsetX = math.cos(angle) * radius
		local offsetZ = math.sin(angle) * radius
		local targetPos = spawnPos + Vector3.new(offsetX, 0, offsetZ)
		
		if clone:IsA("Model") then
			clone:PivotTo(CFrame.new(targetPos))
		elseif clone:IsA("BasePart") then
			clone.Position = targetPos
		end
		
		-- Désancrer après 1 seconde
		task.delay(1, function()
			for _, part in ipairs(partsToUnanchor) do
				if part and part.Parent then
					part.Anchored = false
					part.CanCollide = true
					part.CanTouch = true
				end
			end
		end)
	end
	
	print("✅ [RESTORE] Restauration terminée:", #candiesData, "bonbons")
end

-- 🧹 Nettoyage à la déconnexion : arrêter les boucles mais garder les données pour le snapshot
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	print("🧹 [CLEANUP] Player disconnecting:", player.Name, "UserId:", userId)
	
	-- Arrêter les boucles de production du joueur
	for incID, data in pairs(incubators) do
		if data.ownerUserId == userId then
			print("🧹 [CLEANUP] Stopping production loop for incubator:", incID)
			
			-- Marquer comme arrêté (la boucle va se terminer)
			if data.production then
				data.production.stopped = true
			end
			
			-- Désactiver la fumée
			local incModel = getIncubatorByID(incID)
			if incModel then
				setSmokeEnabled(incModel, false)
			end
		end
	end
	
	print("✅ [CLEANUP] Cleanup complete for", player.Name)
end)

-- 🧹 COMMANDE DEBUG: Nettoyer toutes les productions d'un joueur
function _G.CleanIncubatorProduction(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player then
		print("❌ Player not found:", playerName)
		return
	end
	
	local userId = player.UserId
	local cleaned = 0
	
	for incID, data in pairs(incubators) do
		if data.ownerUserId == userId then
			data.production = nil
			data.queue = {}
			cleaned = cleaned + 1
			print("🧹 Cleaned incubator:", incID)
		end
	end
	
	print("✅ Cleaned", cleaned, "incubators for", playerName)
end

print("✅ IncubatorServer_New chargé (avec production offline)")
print("🔥 VERSION SNAPSHOT: 2024-10-26-02:45 - AVEC LOGS DEBUG")
print("🔧 Commande disponible: _G.CleanIncubatorProduction('PlayerName')")
