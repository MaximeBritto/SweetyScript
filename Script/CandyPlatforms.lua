--[[
    🏭 PLATEFORMES À BONBONS - SYSTÈME SIMPLE
    Plateformes physiques sur l'île où poser directement les bonbons
    
    Utilisation: Cliquez sur une plateforme vide avec un bonbon équipé
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StockManager = require(game.ReplicatedStorage:WaitForChild("StockManager"))
local _CandyTools = require(game.ReplicatedStorage:WaitForChild("CandyTools"))
local RecipeManager = require(game.ReplicatedStorage:WaitForChild("RecipeManager"))

-- Configuration
local CONFIG = {
	GENERATION_INTERVAL = 5,    -- Génère argent toutes les 5 secondes
	BASE_GENERATION = 10,       -- Argent de base généré
	PICKUP_DISTANCE = 8,        -- Distance pour ramasser l'argent
	LEVITATION_HEIGHT = 3,      -- Hauteur de lévitation du bonbon
	ROTATION_SPEED = 2,         -- Vitesse de rotation (radians par seconde)
	
	-- 💰 Prix spécifiques pour chaque plateforme (modifiables manuellement)
	PLATFORM_PRICES = {
		[1] = 0,                        -- Platform1: 3K
		[2] = 200000,                      -- Platform2: 200K
		[3] = 10000000,                   -- Platform3: 10M
		[4] = 100000000000,                -- Platform4: 100B
		[5] = 500000000000000,             -- Platform5: 500T
		[6] = 100000000000000000,          -- Platform6: 100Qa
		[7] = 500000000000000000000,         -- Platform7: 500Qi
		[8] = 2000000000000000000000,      -- Platform8: 2Sx
	}
}

-- Variables globales
local activePlatforms = {}
local moneyDrops = {}

-- Exposer globalement pour IslandManager
_G.activePlatforms = activePlatforms
_G.moneyDrops = moneyDrops

-- Détection robuste d'un Tool bonbon
local function isCandyTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool:GetAttribute("IsCandy") == true then return true end
    if tool:GetAttribute("CandySize") or tool:GetAttribute("CandyRarity") then return true end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local baseName = tool:GetAttribute("BaseName") or tool.Name
    local CandyModels = ReplicatedStorage:FindFirstChild("CandyModels")
    if CandyModels then
        if CandyModels:FindFirstChild(baseName)
            or CandyModels:FindFirstChild("Bonbon" .. baseName)
            or CandyModels:FindFirstChild(baseName:gsub(" ", ""))
            or CandyModels:FindFirstChild("Bonbon" .. baseName:gsub(" ", "")) then
            return true
        end
    end
    local okRM, RM = pcall(function()
        return require(ReplicatedStorage:WaitForChild("RecipeManager"))
    end)
    if okRM and RM and RM.Recettes and RM.Recettes[baseName] then
        return true
    end
    return false
end

-- 🔧 Utilitaires déblocage plateformes
local function getPlayerIslandModel(player)
	if not player then return nil end
	local islandByName = workspace:FindFirstChild("Ile_" .. player.Name)
	if islandByName and islandByName:IsA("Model") then return islandByName end
	local slot = player:GetAttribute("IslandSlot")
	if slot then
		local islandBySlot = workspace:FindFirstChild("Ile_Slot_" .. tostring(slot))
		if islandBySlot and islandBySlot:IsA("Model") then return islandBySlot end
	end
	return nil
end

local function findIslandContainerForPart(part)
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") and typeof(current.Name) == "string" and string.match(current.Name, "^Ile_") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isPlatformInPlayersIsland(platform, player)
	local platformIsland = findIslandContainerForPart(platform)
	local playerIsland = getPlayerIslandModel(player)
	return platformIsland ~= nil and playerIsland ~= nil and platformIsland == playerIsland
end

local function getPlatformIndex(platform)
	if not platform or not platform.Name then return nil end
	local name = platform.Name
	local lower = string.lower(name)
	-- Cas simples: Platform1 / Plateforme1 / Plateform1
	local idx = string.match(lower, "^platform(%d+)$")
		or string.match(lower, "^plateforme(%d+)$")
		or string.match(lower, "^plateform(%d+)$")
	if idx then return tonumber(idx) end
	-- Avec séparateur: Platform_1 / Plateforme 1 / Platform-1
	idx = string.match(lower, "^platform[%s%._%-]+(%d+)$")
		or string.match(lower, "^plateforme[%s%._%-]+(%d+)$")
		or string.match(lower, "^plateform[%s%._%-]+(%d+)$")
	if idx then return tonumber(idx) end
	-- Fallback: si le nom contient 'platform' ou 'plateforme' et se termine par des chiffres
	local endsWithDigits = string.match(lower, "(%d+)$")
	if endsWithDigits and (string.find(lower, "platform", 1, true) or string.find(lower, "plateforme", 1, true) or string.find(lower, "plateform", 1, true)) then
		return tonumber(endsWithDigits)
	end
	return nil
end

-- 🔎 Trouver la BasePart d’une plateforme (supporte BasePart ou Model)
local function findPlatformBasePart(item)
	if not item then return nil end
	if item:IsA("BasePart") then return item end
	if item:IsA("Model") then
		if item.PrimaryPart and item.PrimaryPart:IsA("BasePart") then
			return item.PrimaryPart
		end
		local bestPart = nil
		local bestVolume = 0
		for _, d in ipairs(item:GetDescendants()) do
			if d:IsA("BasePart") then
				local vol = d.Size.X * d.Size.Y * d.Size.Z
				if vol > bestVolume then
					bestPart = d
					bestVolume = vol
				end
			end
		end
		return bestPart
	end
	return nil
end

local function getPlayerUnlockedCount(player)
	local pd = player and player:FindFirstChild("PlayerData")
	local pu = pd and pd:FindFirstChild("PlatformsUnlocked")
	return (pu and pu.Value) or 1
end

local function getUnlockCostForIndex(index)
	if not index then return 0 end
	-- Utiliser le prix spécifique de la table, ou un prix par défaut si non défini
	return CONFIG.PLATFORM_PRICES[index] or (index * 10000)
end

local function _isPlatformUnlockedForPlayer(player, platform)
    local idx = getPlatformIndex(platform)
    if not idx then return true end
    return idx <= getPlayerUnlockedCount(player)
end

-- 🔄 Fonction pour mettre à jour le texte des ProximityPrompt
local function updatePlatformPromptText(platform, player)
	local proximityPrompt = platform:FindFirstChild("ProximityPrompt")
	if not proximityPrompt then return end

	-- Si la plateforme n'appartient pas à l'île du joueur, indiquer indisponible
	if not isPlatformInPlayersIsland(platform, player) then
		proximityPrompt.ActionText = "Indisponible"
		proximityPrompt.ObjectText = "Autre île"
		return
	end

	-- Calculer index et état de déblocage
	local idx = getPlatformIndex(platform)
	local unlockedCount = getPlayerUnlockedCount(player)
	local isUnlocked = not idx or (idx <= unlockedCount)

	-- Vérifier si la plateforme a déjà un bonbon
	local isOccupied = activePlatforms[platform] ~= nil

	-- Vérifier si le joueur a un bonbon équipé
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local tool = humanoid and (humanoid:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool"))
	local hasCandy = tool and tool:GetAttribute("IsCandy")

	-- Déterminer le texte selon la situation
	if not isUnlocked then
		-- Verrouillée pour ce joueur
		if idx and idx > unlockedCount + 1 then
			proximityPrompt.ActionText = "Locked"
			proximityPrompt.ObjectText = "Unlock First Plateform " .. (unlockedCount + 1)
		else
			local cost = getUnlockCostForIndex(idx or (unlockedCount + 1))
			-- Formater le prix avec UIUtils pour afficher 2M, 2B, 2T, etc.
			local ok, UIUtils = pcall(function()
				return require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
			end)
			local formattedCost = (ok and UIUtils) and UIUtils.formatMoneyShort(cost) or tostring(cost)
			proximityPrompt.ActionText = "Unlock"
			proximityPrompt.ObjectText = "Plateform " .. (idx or "?") .. " (" .. formattedCost .. "$)"
		end
	elseif isOccupied then
		-- Il y a déjà un bonbon sur la plateforme
		if hasCandy then
			proximityPrompt.ActionText = "Replace"
			proximityPrompt.ObjectText = "Candy on Platform"
		else
			proximityPrompt.ActionText = "Remove"
			proximityPrompt.ObjectText = "Platform Candy"
		end
	else
		-- Plateforme vide
		if hasCandy then
			proximityPrompt.ActionText = "Place"
			proximityPrompt.ObjectText = "Candy on Platform"
		else
			proximityPrompt.ActionText = "Place"
			proximityPrompt.ObjectText = "Candy (Equip first)"
		end
	end
end



-- ✅ Hook appelé après achat Robux d'une plateforme
_G.OnPlatformPurchased = function(player, level)
    local lvl = tonumber(level)
    if not player or not lvl then return end
    -- Mettre à jour la progression côté serveur
    local pd = player:FindFirstChild("PlayerData")
    local pu = pd and pd:FindFirstChild("PlatformsUnlocked")
    if pu then
        pu.Value = math.max(pu.Value, lvl)
    end
    -- Rafraîchir le prompt de la plateforme correspondante si on la trouve
    local island = getPlayerIslandModel(player)
    if island then
        local target = island:FindFirstChild("Platform" .. tostring(lvl))
        if target then
            updatePlatformPromptText(target, player)
        end
    end
end

-- 🕱️ Gestion du clic sur une plateforme
function handlePlatformClick(player, platform)

	-- Bloquer toute interaction si ce n'est pas l'île du joueur
	if not isPlatformInPlayersIsland(platform, player) then
		updatePlatformPromptText(platform, player)
		return
	end

	-- Gestion du déblocage si nécessaire
	local idx = getPlatformIndex(platform)
	local unlockedCount = getPlayerUnlockedCount(player)
	print("🔍 [PLATFORM DEBUG] Plateforme:", platform.Name, "idx:", idx, "unlockedCount:", unlockedCount)
	if idx and idx > unlockedCount then
		-- Autoriser uniquement le prochain index
		if idx > unlockedCount + 1 then
			print("⚠️ [PLATFORM DEBUG] Plateforme trop avancée, retour")
			updatePlatformPromptText(platform, player)
			return
		end
		local cost = getUnlockCostForIndex(idx)
		print("💰 [PLATFORM DEBUG] Coût de déblocage:", cost)
		local canPay = false
		if _G.GameManager and _G.GameManager.getArgent and _G.GameManager.retirerArgent then
			local current = _G.GameManager.getArgent(player)
			print("💵 [PLATFORM DEBUG] Argent actuel:", current, "Coût:", cost)
			if current >= cost then
				canPay = _G.GameManager.retirerArgent(player, cost)
				print("✅ [PLATFORM DEBUG] Paiement réussi via GameManager:", canPay)
			end
		else
			-- Fallback minimaliste - utiliser PlayerData
			local pd = player:FindFirstChild("PlayerData")
			if pd and pd:FindFirstChild("Argent") and pd.Argent.Value >= cost then
				pd.Argent.Value -= cost
				canPay = true
				print("✅ [PLATFORM DEBUG] Paiement réussi via PlayerData")
			end
		end
		if canPay then
			print("🎉 [PLATFORM DEBUG] Déblocage de la plateforme", platform.Name)
			local pd = player:FindFirstChild("PlayerData")
			local pu = pd and pd:FindFirstChild("PlatformsUnlocked")
			if pu then pu.Value = math.max(pu.Value, idx) end
			
			-- 🎓 TUTORIEL: Notifier qu'une plateforme a été débloquée (appel direct côté serveur)
			if _G.TutorialManager and _G.TutorialManager.onPlatformUnlocked then
				print("🔓 [TUTORIAL SERVER] Appel direct de onPlatformUnlocked pour:", platform.Name)
				_G.TutorialManager.onPlatformUnlocked(player, platform.Name)
			else
				print("⚠️ [TUTORIAL SERVER] TutorialManager.onPlatformUnlocked introuvable!")
			end
		else
			-- Fallback: ouvrir le prompt Robux pour ce niveau
			if StockManager and type(StockManager.promptPlatformRobux) == "function" then
				StockManager.promptPlatformRobux(player, idx)
			end
		end
		-- Mettre à jour le prompt et arrêter ici (2 clics: un pour acheter, un pour placer)
		task.wait(0.05)
		updatePlatformPromptText(platform, player)
		return
	end

	-- Vérifier si la plateforme est occupée
	local isOccupied = activePlatforms[platform] ~= nil

	-- Gérer les différents cas selon la situation
	local character = player.Character
	if not character then 
		return 
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then 
		return 
	end

    -- Chercher l'outil équipé (peut être dans humanoid ou character)
    local tool = humanoid:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
    local hasCandy = isCandyTool(tool)

	if isOccupied then
		-- Il y a déjà un bonbon sur la plateforme
		if hasCandy then
			-- REMPLACER : Vérifier si c'est le même type de bonbon ET la même taille
			local data = activePlatforms[platform]
			
			local toolBaseName = tool:GetAttribute("BaseName") or tool.Name
			local platformCandyName = data and data.candy
			
			
			-- 🔧 CORRECTION : Trouver le modèle associé à chaque bonbon dans RecipeManager
			local function getCandyModel(candyName)
				if not candyName then return nil end
				-- Chercher dans les recettes
				for recipeName, recipeData in pairs(RecipeManager.Recettes) do
					if recipeName == candyName then
						return recipeData.modele or recipeName
					end
				end
				-- Si pas trouvé, retourner le nom tel quel (peut-être déjà un modèle)
				return candyName
			end
			
			local toolModel = getCandyModel(toolBaseName)
			local platformModel = getCandyModel(platformCandyName)
			
			
			-- Récupérer les données de taille du bonbon équipé
			local toolSize = tool:GetAttribute("CandySize")
			local toolRarity = tool:GetAttribute("CandyRarity")
			
			
			-- Récupérer les données de taille du bonbon sur la plateforme
			local platformSize = data and data.sizeData and data.sizeData.size
			local platformRarity = data and data.sizeData and data.sizeData.rarity
			
			
			-- 🔧 CORRECTION : Vérifier si c'est le même bonbon en comparant les MODÈLES
			local isSameCandy = (toolModel == platformModel)
			
			-- 🔧 CORRECTION: Utiliser la rareté comme critère principal (plus fiable que la taille exacte)
			local isSameRarity = false
			if toolRarity and platformRarity then
				-- Les deux ont une rareté définie : comparer les raretés
				isSameRarity = (toolRarity == platformRarity)
			elseif not toolRarity and not platformRarity then
				-- Aucun des deux n'a de rareté définie (bonbons sans système de taille)
				isSameRarity = true
			end
			
			-- Alternative : si pas de rareté, comparer les tailles avec tolérance
			local isSameSizeApprox = false
			if not toolRarity and not platformRarity and toolSize and platformSize then
				-- Comparer avec une tolérance de 0.05 pour les erreurs de précision
				isSameSizeApprox = math.abs(toolSize - platformSize) < 0.05
			end
			
			
			if isSameCandy and (isSameRarity or isSameSizeApprox) then
				-- 🔧 MÊME BONBON ET MÊME TAILLE : Pas besoin de swap, juste annuler l'action
				return
			else
				-- BONBON DIFFÉRENT : Faire le remplacement normal
				-- Sauvegarder temporairement les données de l'ancien bonbon
				local oldCandyData = data and {
					originalTool = data.originalTool,
					candy = data.candy
				}
				
				-- Retirer l'ancien bonbon de la plateforme (sans retour inventaire)
				removeCandyFromPlatform(platform, false)
				
				-- Placer le nouveau bonbon
				placeCandyOnPlatform(player, platform, tool)
				
				-- Maintenant retourner l'ancien bonbon manuellement à l'inventaire
				if oldCandyData and oldCandyData.originalTool and player then
					
					local backpack = player:FindFirstChild("Backpack")
					if backpack then
						-- 🔧 CORRECTION: Toujours créer un nouveau tool au lieu de chercher à incrémenter
						-- Cela évite le bug où on cherche le même bonbon qu'on vient de consommer
						local restoredTool = oldCandyData.originalTool:Clone()
						
						-- Vérifier que le clone est valide
						if restoredTool and restoredTool:IsA("Tool") then
							-- S'assurer que le Count est à 1
							local count = restoredTool:FindFirstChild("Count")
							if count then
								count.Value = 1
							else
								local newCount = Instance.new("IntValue")
								newCount.Name = "Count"
								newCount.Value = 1
								newCount.Parent = restoredTool
							end
							
							restoredTool.Parent = backpack
						else
						end
						
						-- Forcer la mise à jour de l'inventaire
						task.wait(0.1)
						if _G.CustomBackpack and _G.CustomBackpack.updateAllHotbarSlots then
							_G.CustomBackpack.updateAllHotbarSlots()
						end
						if _G.CustomBackpack and _G.CustomBackpack.scheduleInventoryUpdate then
							_G.CustomBackpack.scheduleInventoryUpdate()
						end
					end
				end
			end
		else
			-- RETIRER : Juste retirer le bonbon existant
			removeCandyFromPlatform(platform, true) -- true = retourner à l'inventaire
		end
	else
		-- Plateforme vide
		if hasCandy then
			-- PLACER : Placer le bonbon
			placeCandyOnPlatform(player, platform, tool)
		else
			-- Pas de bonbon équipé
			return
		end
	end
end

-- 🍬 Placer un bonbon sur une plateforme
function placeCandyOnPlatform(player, platform, tool)
	local candyName = tool.Name
	local countValue = tool:FindFirstChild("Count")
	local currentStackSize = countValue and countValue.Value or 1


	-- Trouver la partie Handle du tool original
	local originalHandle = tool:FindFirstChildOfClass("BasePart") or tool:FindFirstChild("Handle")
	if not originalHandle then
		return
	end


	-- Créer un nouveau Model et transférer tout le contenu du Tool
	local candyModel = Instance.new("Model")
	candyModel.Name = "FloatingCandy_" .. candyName

	-- Cloner le Tool complet temporairement
	local tempTool = tool:Clone()

	-- Transférer tous les enfants du Tool vers le Model
	for _, child in pairs(tempTool:GetChildren()) do
		child.Parent = candyModel
	end

	-- Supprimer le tool temporaire
	tempTool:Destroy()

	-- Trouver la vraie partie visible du bonbon (pas le Handle générique)
	local mainPart = nil
	local handlePart = nil

	-- D'abord, chercher une MeshPart ou une partie avec un Mesh (la vraie apparence)
	for _, child in pairs(candyModel:GetChildren()) do
		if child:IsA("MeshPart") then
			mainPart = child
			break
		elseif child:IsA("BasePart") and child:FindFirstChildOfClass("SpecialMesh") then
			mainPart = child
			break
		elseif child:IsA("BasePart") and child.Name == "Handle" then
			handlePart = child
		end
	end

	-- Si pas de MeshPart, utiliser le Handle mais cacher les autres parties
	if not mainPart then
		mainPart = handlePart or candyModel:FindFirstChildOfClass("BasePart")
	end

	-- Capturer taille/rareté pour restauration fidèle (défini AVANT utilisation)
	local sizeDataEntry = nil
	do
		local candySize = tool:GetAttribute("CandySize")
		local candyRarity = tool:GetAttribute("CandyRarity")
		if candySize and candyRarity then
			sizeDataEntry = { size = candySize, rarity = candyRarity,
		colorR = tool:GetAttribute("CandyColorR") or 100,
		colorG = tool:GetAttribute("CandyColorG") or 255,
		colorB = tool:GetAttribute("CandyColorB") or 100 }
		end
	end

	-- Appliquer la taille/rareté via CandySizeManager
	local sizeData = nil
	local okCSM, CSM = pcall(function()
		return require(game.ReplicatedStorage:WaitForChild("CandySizeManager"))
	end)
	if okCSM and CSM then
		-- Construire sizeData depuis le tool si dispo
		sizeData = CSM.getSizeDataFromTool(tool)
		-- Si sizeData enregistrée en placement est plus précise, l'utiliser
		if not sizeData and sizeDataEntry then
			sizeData = {
				size = sizeDataEntry.size,
				rarity = sizeDataEntry.rarity,
				color = Color3.fromRGB(sizeDataEntry.colorR or 255, sizeDataEntry.colorG or 255, sizeDataEntry.colorB or 255)
			}
		end
		if sizeData then
			CSM.applySizeToModel(mainPart, sizeData)
		end
	end

	if not mainPart then
		candyModel:Destroy()
		return
	end

	-- Ne pas modifier l'apparence/position des autres parts; seulement éviter les collisions parasites
	for _, child in pairs(candyModel:GetChildren()) do
		if child:IsA("BasePart") and child ~= mainPart then
			child.CanCollide = false
		end
	end

	-- Définir la PrimaryPart pour que le Model soit bien géré
	candyModel.PrimaryPart = mainPart

	-- Maintenant placer le Model dans workspace
	candyModel.Parent = workspace

	for _, child in pairs(candyModel:GetChildren()) do
		if child:IsA("BasePart") then
			for _, subChild in pairs(child:GetChildren()) do
			end
		end
	end

	-- Configurer la partie principale AVANT de la positionner
	mainPart.Anchored = true
	mainPart.CanCollide = false

	-- S'assurer que le bonbon est visible
	mainPart.Transparency = 0  -- Complètement opaque
	if mainPart.Size.Magnitude < 1 then
		mainPart.Size = Vector3.new(2, 2, 2)  -- Taille minimum pour être visible
	end

	-- Positionner tout le modèle au-dessus de la plateforme (pivot global)
	local platformTop = platform.Position.Y + (platform.Size.Y / 2)
	local targetPosition = Vector3.new(platform.Position.X, platformTop + CONFIG.LEVITATION_HEIGHT, platform.Position.Z)
	-- Garder l'orientation de la plateforme pour que les effets/scripts locaux suivent
	local targetCFrame = CFrame.new(targetPosition)
	candyModel:PivotTo(targetCFrame)


	-- Vérifier que le bonbon est bien visible
	if not candyModel.Parent or not mainPart.Parent then
		candyModel:Destroy()
		return
	end

	if mainPart:IsA("BasePart") and not mainPart:IsA("MeshPart") then
	end

	-- Sauvegarder une copie du tool original AVANT de le modifier
	local originalToolCopy = tool:Clone()
	-- Forcer le stack à 1 pour la copie sauvegardée (pour la restauration)
	local originalCopyCount = originalToolCopy:FindFirstChild("Count")
	if originalCopyCount then
		originalCopyCount.Value = 1
	else
		local newCount = Instance.new("IntValue")
		newCount.Name = "Count"
		newCount.Value = 1
		newCount.Parent = originalToolCopy
	end

	-- Debug avant modification du stack

	-- 🔧 CORRECTION: Décrémenter le stack au lieu de tout supprimer
	if currentStackSize > 1 and countValue then
		-- Décrémenter le stack de 1
		countValue.Value = currentStackSize - 1
		
	else
		-- Stack de 1 : retirer le tool complètement
		tool.Parent = nil
	end

	-- Éclairage du bonbon
	local candyLight = Instance.new("PointLight")
	candyLight.Color = mainPart.Color
	candyLight.Brightness = 1.5
	candyLight.Range = 10
	candyLight.Parent = mainPart

	-- Effets visuels: laisser le système d'effet existant du bonbon tel quel
	-- (aucun déplacement/ajout/suppression d'objets d'effet)

	-- ProximityPrompt pour retirer le bonbon
	local removePrompt = Instance.new("ProximityPrompt")
	removePrompt.ActionText = "Retirer Bonbon"
	removePrompt.ObjectText = candyName
	removePrompt.HoldDuration = 0
	removePrompt.MaxActivationDistance = 20
	removePrompt.RequiresLineOfSight = false
	removePrompt.Parent = mainPart

	removePrompt.Triggered:Connect(function(clickingPlayer)
		local aData = activePlatforms[platform]
		if aData and clickingPlayer and clickingPlayer.UserId == aData.ownerUserId then
			removeCandyFromPlatform(platform)
		else
		end
	end)


	-- Caches de passifs pour production hors-ligne
	local genIntervalOverride = CONFIG.GENERATION_INTERVAL
	local gainMultiplier = 1
	do
		local pd = player and player:FindFirstChild("PlayerData")
		local su = pd and pd:FindFirstChild("ShopUnlocks")
		local com = su and su:FindFirstChild("EssenceCommune")
		local leg = su and su:FindFirstChild("EssenceLegendaire")
		if com and com.Value == true then
			genIntervalOverride = math.max(1, genIntervalOverride / 2)
		end
		if leg and leg.Value == true then
			gainMultiplier = 2
		end
	end

	-- (sizeDataEntry déjà défini plus haut)

	-- Sauvegarder les données
	activePlatforms[platform] = {
		player = player,
		ownerUserId = player.UserId,
		ownerName = player.Name,
		candy = candyName,
		candyModel = candyModel,
		mainPart = mainPart, -- Sauvegarder la référence vers la partie principale
		originalTool = originalToolCopy, -- Sauvegarder une copie du tool original pour le retour
		lastGeneration = tick(),
		stackSize = 1, -- 🔧 CORRECTION: Toujours 1 car on ne place qu'un seul bonbon à la fois
		totalGenerated = 0,
		moneyStack = nil, -- Référence vers la boule d'argent stackée
		genIntervalOverride = genIntervalOverride,
		gainMultiplier = gainMultiplier,
		sizeData = sizeDataEntry
	}

	-- Debug final
	
	-- 🎓 TUTORIEL: Notifier qu'un bonbon a été placé (appel direct côté serveur)
	if _G.TutorialManager and _G.TutorialManager.onCandyPlacedOnPlatform then
		print("🎓 [TUTORIAL SERVER] Appel direct de onCandyPlacedOnPlatform pour:", platform.Name)
		_G.TutorialManager.onCandyPlacedOnPlatform(player, platform.Name)
	else
		print("⚠️ [TUTORIAL SERVER] TutorialManager.onCandyPlacedOnPlatform introuvable!")
	end

end

-- 🗑️ Retirer un bonbon d'une plateforme
function removeCandyFromPlatform(platform, returnToInventory)
	-- Par défaut, retourner à l'inventaire si le paramètre n'est pas spécifié
	if returnToInventory == nil then
		returnToInventory = true
	end
	
	local data = activePlatforms[platform]
	if not data then return end

	-- Rendre le bonbon au joueur s'il est encore connecté ET si returnToInventory est true
	if returnToInventory and data.player and data.player.Parent and data.originalTool then
		local backpack = data.player:FindFirstChild("Backpack")
		if backpack then
			-- 🔧 CORRECTION: Vérifier s'il existe déjà un tool IDENTIQUE (même nom ET même taille/rareté)
			local existingTool = nil
			local candyName = data.candy
			local baseName = data.originalTool:GetAttribute("BaseName") or candyName
			
			-- Récupérer les attributs de taille/rareté du bonbon à retourner
			local originalSize = data.originalTool:GetAttribute("CandySize")
			local originalRarity = data.originalTool:GetAttribute("CandyRarity")
			
			-- Chercher un tool existant avec le même nom de base ET la même taille/rareté
			for _, tool in pairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					local toolBaseName = tool:GetAttribute("BaseName") or tool.Name
					local toolSize = tool:GetAttribute("CandySize")
					local toolRarity = tool:GetAttribute("CandyRarity")
					
					-- Vérifier que c'est le même bonbon ET la même taille/rareté
					local sameBaseName = (toolBaseName == baseName)
					local sameSize = (toolSize == originalSize) -- nil == nil est true, ce qui est correct
					local sameRarity = (toolRarity == originalRarity)
					
					if sameBaseName and sameSize and sameRarity then
						existingTool = tool
						break
					end
				end
			end
			
			if existingTool then
				-- 🔧 CORRECTION: Incrémenter le stack existant seulement si c'est EXACTEMENT le même bonbon
				local count = existingTool:FindFirstChild("Count")
				if count then
					count.Value = count.Value + 1
				else
					-- Créer le Count s'il n'existe pas
					local newCount = Instance.new("IntValue")
					newCount.Name = "Count"
					newCount.Value = 2
					newCount.Parent = existingTool
				end
			else
				-- 🔧 CORRECTION: Créer un nouveau tool si aucun tool identique n'existe
				local restoredTool = data.originalTool:Clone()
				restoredTool.Parent = backpack
			end
			
			-- 🔧 NOUVEAU: Forcer la mise à jour de la hotbar et de l'inventaire
			task.wait(0.1) -- Petit délai pour laisser le tool se stabiliser
			if _G.CustomBackpack and _G.CustomBackpack.updateAllHotbarSlots then
				_G.CustomBackpack.updateAllHotbarSlots()
			end
			if _G.CustomBackpack and _G.CustomBackpack.scheduleInventoryUpdate then
				_G.CustomBackpack.scheduleInventoryUpdate()
			end
		else
		end
	else
	end

	-- Supprimer le modèle visuel
	if data.candyModel then
		data.candyModel:Destroy()
	end

	-- Nettoyer la stack d'argent aussi
	if data.moneyStack and data.moneyStack.Parent then
		moneyDrops[data.moneyStack] = nil
		data.moneyStack:Destroy()
	end

	activePlatforms[platform] = nil
end

-- 💰 Générer de l'argent (système de stack)
function generateMoney(platform, data)
	-- 🔧 Ne pas générer d'argent si le joueur est déconnecté
	if data.ownerUserId then
		local Players = game:GetService("Players")
		local playerInGame = Players:GetPlayerByUserId(data.ownerUserId)
		if not playerInGame then
			-- Joueur déconnecté, ne pas générer d'argent visuel
			return
		end
	end
	
	local currentTime = tick()
	-- Utiliser caches de passifs pour production hors-ligne
	local interval = data.genIntervalOverride or CONFIG.GENERATION_INTERVAL
	if currentTime - data.lastGeneration < interval then
		return
	end

	-- 💎 Calculer la valeur selon la recette et la taille du bonbon
	local baseValue = RecipeManager.calculatePlatformValue(data.candy, data.sizeData) or CONFIG.BASE_GENERATION
	
	local amount = (baseValue * data.stackSize) * (data.gainMultiplier or 1)

	-- Si pas de boule d'argent existante, en créer une (seulement si le joueur est connecté ET sur la bonne île)
	if not data.moneyStack or not data.moneyStack.Parent then
		-- 🔧 NOUVEAU: Ne pas créer de MoneyBag si le joueur est déconnecté OU sur une autre île
		local ownerPlayer = data.player or Players:GetPlayerByUserId(data.ownerUserId)
		if not ownerPlayer or not ownerPlayer.Parent or data.playerDisconnected or data.wrongIsland then
			-- Joueur déconnecté ou sur autre île : accumuler l'argent sans créer de MoneyBag
			data.accumulatedOfflineMoney = (data.accumulatedOfflineMoney or 0) + amount
			data.lastGeneration = currentTime
			data.totalGenerated = (data.totalGenerated or 0) + amount
			return
		end
		
		-- 🔧 NOUVEAU: Calculer le montant total AVANT de créer le MoneyBag
		local totalAmount = amount
		if data.accumulatedOfflineMoney and data.accumulatedOfflineMoney > 0 then
			totalAmount = totalAmount + data.accumulatedOfflineMoney
			print("💰 [MONEYBAG] Création avec argent offline:", data.accumulatedOfflineMoney, "$", "| Total:", totalAmount, "$")
			data.accumulatedOfflineMoney = 0
		end
		
		-- Utiliser totalAmount au lieu de amount pour la création
		amount = totalAmount
		-- Cloner le modèle 3D depuis ReplicatedStorage
		local moneyTemplate = game:GetService("ReplicatedStorage"):FindFirstChild("MoneyModel")
		local money
		
		if moneyTemplate then
			money = moneyTemplate:Clone()
			local ownerName = data.player and data.player.Name or data.ownerName or tostring(data.ownerUserId)
			money.Name = "MoneyStack_" .. ownerName
			
			-- Rendre toutes les parts du modèle non-collisionnables
			for _, part in ipairs(money:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
		else
			-- Fallback: créer une part simple si le modèle n'existe pas
			money = Instance.new("Part")
			local ownerName = data.player and data.player.Name or data.ownerName or tostring(data.ownerUserId)
			money.Name = "MoneyStack_" .. ownerName
			money.Material = Enum.Material.Neon
			money.BrickColor = BrickColor.new("Bright yellow")
			money.Shape = Enum.PartType.Ball
			money.Size = Vector3.new(1, 1, 1)
			money.Anchored = true
			money.CanCollide = false
		end
		
		-- Positionner DEVANT la plateforme (plus loin pour éviter le chevauchement)
		local forward = platform.CFrame.LookVector
		
		-- 🔧 CORRECTION: Distance fixe à 8 studs pour éviter que le bonbon cache le sac
		local desiredDist = 8
		
		local origin = platform.Position + Vector3.new(0, 1, 0)
		local target = origin + forward * desiredDist
		local rayParams = RaycastParams.new()
		
		-- 🔧 CORRECTION: Ignorer le bonbon ET la plateforme dans le raycast
		local filterList = {platform}
		if data.candyModel and data.candyModel.Parent then
			table.insert(filterList, data.candyModel)
		end
		rayParams.FilterDescendantsInstances = filterList
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist
		
		local hit = workspace:Raycast(origin, (target - origin), rayParams)
		local dist = desiredDist
		if hit then
			-- Si un mur est juste devant, avancer un peu moins pour rester visible
			dist = math.max(3, (hit.Position - origin).Magnitude - 0.5)
		end
		local frontOffset = forward * dist + Vector3.new(0, 2, 0)
		local targetPos = platform.Position + frontOffset
		
		-- Positionner le modèle ou la part
		if money:IsA("Model") then
			money:PivotTo(CFrame.new(targetPos))
		else
			money.Position = targetPos
		end
		
		-- 🏝️ NOUVEAU: Créer le MoneyBag dans l'île du joueur, pas dans workspace
		local ownerPlayer = data.player or Players:GetPlayerByUserId(data.ownerUserId)
		local playerIsland = ownerPlayer and getPlayerIslandModel(ownerPlayer)
		if playerIsland then
			money.Parent = playerIsland
			print("💰 [MONEYBAG] Créé dans l'île:", playerIsland.Name)
		else
			-- DEBUG: Pourquoi l'île n'est pas trouvée ?
			if ownerPlayer then
				print("🔍 [DEBUG] Recherche île pour:", ownerPlayer.Name)
				print("  - Ile_" .. ownerPlayer.Name .. ":", workspace:FindFirstChild("Ile_" .. ownerPlayer.Name) ~= nil)
				local slot = ownerPlayer:GetAttribute("IslandSlot")
				print("  - IslandSlot attribute:", slot)
				if slot then
					print("  - Ile_Slot_" .. tostring(slot) .. ":", workspace:FindFirstChild("Ile_Slot_" .. tostring(slot)) ~= nil)
				end
			else
				print("🔍 [DEBUG] Joueur non trouvé pour UserId:", data.ownerUserId)
			end
			
			-- Fallback: workspace si l'île n'est pas trouvée
			money.Parent = workspace
			warn("⚠️ [MONEYBAG] Île non trouvée, créé dans workspace")
		end

		-- Trouver une part pour attacher le BillboardGui
		local attachPart
		if money:IsA("Model") then
			attachPart = money.PrimaryPart or money:FindFirstChildWhichIsA("BasePart", true)
		else
			attachPart = money
		end

	-- GUI avec montant (formaté avec UIUtils)
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(4, 0, 2, 0)  -- Taille en studs (fixe dans l'espace 3D)
	billboardGui.StudsOffset = Vector3.new(0, 2, 0)
	billboardGui.Adornee = attachPart
	billboardGui.Parent = money

	-- Formater le montant avec UIUtils
	local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
	local formattedAmount = UIUtils.formatMoneyShort(amount)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "💰 " .. formattedAmount .. "$"
	label.TextColor3 = Color3.fromRGB(255, 255, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Name = "AmountLabel"
	label.Parent = billboardGui

		-- Animation: flottement et rotation
		if money:IsA("Model") then
			local startCFrame = money:GetPivot()
			local startTime = tick()
			local connection
			connection = RunService.Heartbeat:Connect(function()
				if not money or not money.Parent then
					connection:Disconnect()
					return
				end
				
				local elapsed = tick() - startTime
				-- Calcul du flottement (monte/descend de 0.5 stud)
				local bobHeight = math.sin(elapsed * 2) * 0.5
				-- Calcul de la rotation (360° toutes les 4 secondes)
				local rotation = (elapsed * 90) % 360
				
				-- Appliquer la transformation
				local newCFrame = startCFrame * CFrame.new(0, bobHeight, 0) * CFrame.Angles(0, math.rad(rotation), 0)
				money:PivotTo(newCFrame)
			end)
			
			-- Nettoyer la connexion quand le modèle est détruit
			money.AncestryChanged:Connect(function()
				if not money.Parent then
					connection:Disconnect()
				end
			end)
		else
			-- Animation simple pour une Part
			local bobTween = TweenService:Create(money, 
				TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Position = money.Position + Vector3.new(0, 1, 0)}
			)
			bobTween:Play()
		end

		-- Sauvegarder la référence
		data.moneyStack = money

		-- Sauvegarder pour ramassage (amount contient déjà l'argent offline)
		moneyDrops[money] = {
			player = data.player,
			ownerUserId = data.ownerUserId,
			amount = amount,
			created = currentTime,
			platform = platform -- Référence vers la plateforme
		}

	else
		-- Mettre à jour le montant existant
		-- 🔧 NOUVEAU: Vérifier que le MoneyBag existant est sur la bonne île
		if data.wrongIsland then
			-- Le MoneyBag est sur une autre île : accumuler l'argent sans mettre à jour le MoneyBag
			data.accumulatedOfflineMoney = (data.accumulatedOfflineMoney or 0) + amount
			data.lastGeneration = currentTime
			data.totalGenerated = (data.totalGenerated or 0) + amount
			return
		end
		
		local currentAmount = moneyDrops[data.moneyStack].amount
		local newAmount = currentAmount + amount
		moneyDrops[data.moneyStack].amount = newAmount

	-- Mettre à jour le texte (formaté avec UIUtils)
	local billboardGui = data.moneyStack:FindFirstChild("BillboardGui")
	if billboardGui then
		local label = billboardGui:FindFirstChild("AmountLabel")
		if label then
			local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
			local formattedAmount = UIUtils.formatMoneyShort(newAmount)
			label.Text = "💰 " .. formattedAmount .. "$"
		end
	end

		-- Effet visuel de stack (agrandir légèrement)
		local currentSize = data.moneyStack.Size
		local maxSize = Vector3.new(2, 2, 2)
		if currentSize.X < maxSize.X then
			data.moneyStack.Size = currentSize + Vector3.new(0.1, 0.1, 0.1)
		end
	end

	data.lastGeneration = currentTime
	data.totalGenerated = data.totalGenerated + amount

end

-- Table pour éviter les ramassages multiples
local pickupCooldowns = {}

-- 🚶 Ramassage automatique par proximité
function checkMoneyPickup(player)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local playerPos = rootPart.Position

	for money, data in pairs(moneyDrops) do
		if data.ownerUserId == player.UserId and money.Parent then
			-- ✅ PROTECTION: Vérifier si déjà en cours de ramassage
			if pickupCooldowns[money] then
				continue  -- Ignorer si déjà ramassé
			end
			
			local distance = (playerPos - money.Position).Magnitude
			if distance <= CONFIG.PICKUP_DISTANCE then
				-- Marquer immédiatement comme en cours de ramassage
				pickupCooldowns[money] = true
				-- Ajouter l'argent au joueur
				
				-- Vérifier l'argent AVANT
				local playerData = player:FindFirstChild("PlayerData")
				local argentAvant = playerData and playerData:FindFirstChild("Argent") and playerData.Argent.Value or 0
				local argentType = playerData and playerData:FindFirstChild("Argent") and playerData.Argent.ClassName or "N/A"
				
				if _G.GameManager and _G.GameManager.ajouterArgent then
					local success = _G.GameManager.ajouterArgent(player, data.amount)
					
					-- Vérifier l'argent APRÈS
					task.wait(0.1)
					local argentApres = playerData and playerData:FindFirstChild("Argent") and playerData.Argent.Value or 0
				else
					-- Fallback
					if playerData and playerData:FindFirstChild("Argent") then
						playerData.Argent.Value = playerData.Argent.Value + data.amount
					end
				end

				-- Effet de ramassage
				local effect = money:Clone()
				effect.Parent = workspace

				local pickupTween = TweenService:Create(effect,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Position = playerPos + Vector3.new(0, 5, 0),
						Size = Vector3.new(0.1, 0.1, 0.1),
						Transparency = 1
					}
				)
				pickupTween:Play()
				Debris:AddItem(effect, 0.5)

				-- Supprimer l'argent et nettoyer la référence dans la plateforme
				money:Destroy()
				moneyDrops[money] = nil
				pickupCooldowns[money] = nil  -- Nettoyer le cooldown
				
				-- 🎓 TUTORIEL: Notifier qu'de l'argent a été collecté (appel direct côté serveur)
				if _G.TutorialManager and _G.TutorialManager.onMoneyCollected then
					print("💰 [TUTORIAL SERVER] Appel direct de onMoneyCollected pour:", player.Name)
					_G.TutorialManager.onMoneyCollected(player)
				end

				-- Nettoyer la référence dans activePlatforms
				if data.platform and activePlatforms[data.platform] then
					activePlatforms[data.platform].moneyStack = nil
				end

			end
		end
	end
end

-- 🔄 Rotation des bonbons
function rotateCandies()
	for platform, data in pairs(activePlatforms) do
		if data.candyModel and data.candyModel.Parent and data.mainPart and data.mainPart.Parent then
			-- Sauvegarder la position pour éviter les déplacements
			local fixedPosition = data.mainPart.Position

			-- Rotation simple de la partie principale seulement
			local currentOrientation = data.mainPart.Orientation
			data.mainPart.Orientation = Vector3.new(
				currentOrientation.X,
				currentOrientation.Y + 2, -- 2 degrés par frame
				currentOrientation.Z
			)

			-- Forcer la position à rester fixe
			data.mainPart.Position = fixedPosition

			-- Debug occasionnel pour vérifier
			if math.random(1, 60) == 1 then -- 1 fois par seconde environ
			end
		else
			-- Debug si la rotation ne peut pas se faire
			if math.random(1, 120) == 1 then -- Plus rare
			end
		end
	end
end

-- 🔄 Boucle principale
RunService.Heartbeat:Connect(function()
	rotateCandies()

	for platform, data in pairs(activePlatforms) do
		-- La production continue même si le joueur est déconnecté
			generateMoney(platform, data)

		-- Si le joueur est en jeu, autoriser le ramassage automatique
		local ownerPlayer = data.player
		if not (ownerPlayer and ownerPlayer.Parent) then
			ownerPlayer = Players:GetPlayerByUserId(data.ownerUserId)
			if ownerPlayer then
				data.player = ownerPlayer -- réassocier l'objet Player
			end
		end
		if ownerPlayer and ownerPlayer.Parent then
			checkMoneyPickup(ownerPlayer)
		end
	end
end)

-- 🔄 Mise à jour périodique des textes des ProximityPrompt
task.spawn(function()
	while true do
		task.wait(1) -- Toutes les secondes

		-- Mettre à jour les textes pour tous les joueurs près des plateformes
		for _, player in pairs(Players:GetPlayers()) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local playerPos = player.Character.HumanoidRootPart.Position

				-- Chercher les plateformes proches
				for platform, _ in pairs(activePlatforms) do
					if (playerPos - platform.Position).Magnitude <= 25 then
						updatePlatformPromptText(platform, player)
					end
				end

				-- Chercher aussi les plateformes vides (avec le nouveau système)
				local function searchEmptyPlatforms(parent, depth)
					depth = depth or 0
					if depth > 10 then return end

					for _, child in pairs(parent:GetChildren()) do
						local idx = getPlatformIndex(child)
						if idx ~= nil then
							local part = findPlatformBasePart(child)
							if part and not activePlatforms[part] then
								if (playerPos - part.Position).Magnitude <= 25 then
									updatePlatformPromptText(part, player)
								end
							end
						elseif child:IsA("Model") or child:IsA("Folder") then
							searchEmptyPlatforms(child, depth + 1)
						end
					end
				end

				searchEmptyPlatforms(workspace)
			end
		end
	end
end)

-- 🧹 Nettoyage périodique des MoneyBags orphelins
task.spawn(function()
	while true do
		task.wait(10) -- Vérifier toutes les 10 secondes
		
		local now = tick()
		for money, data in pairs(moneyDrops) do
			if not money or not money.Parent then
				-- MoneyBag déjà détruit, nettoyer la référence
				moneyDrops[money] = nil
				continue
			end
			
			-- Nettoyer TOUS les MoneyBags avec disconnectTime après 5 secondes
			-- (Ce sont les anciens MoneyBags des joueurs qui se sont déconnectés)
			if data.disconnectTime and (now - data.disconnectTime) > 5 then
				print("🧹 [CLEANUP] Nettoyage MoneyBag ancien après 5s:", money.Name, "| Montant:", data.amount or 0, "$")
				money:Destroy()
				moneyDrops[money] = nil
			end
		end
	end
end)

-- 🧹 Fonction pour nettoyer le MoneyBag d'un joueur (optionnel: seulement sur une île spécifique)
local function cleanupPlayerMoneyBag(player, reason, specificIsland)
	local cleaned = 0
	
	for money, data in pairs(moneyDrops) do
		if data.ownerUserId == player.UserId and money.Parent then
			-- Si une île spécifique est fournie, vérifier que le MoneyBag est sur cette île
			local shouldClean = true
			if specificIsland then
				local moneyIsland = findIslandContainerForPart(money)
				shouldClean = (moneyIsland == specificIsland)
				if shouldClean then
					print("💰 [CLEANUP]", reason, "- MoneyBag sur ancienne île:", specificIsland.Name)
				end
			end
			
			if shouldClean then
				money:Destroy()
				moneyDrops[money] = nil
				cleaned = cleaned + 1
				print("💰 [CLEANUP]", reason, "- MoneyBag détruit:", player.Name, "| Montant:", data.amount or 0, "$")
			end
		end
	end
	if cleaned > 0 then
		print("✅ [CLEANUP]", cleaned, "MoneyBag(s) nettoyé(s) pour", player.Name)
	end
end

-- 🔍 Système de vérification périodique: nettoyer les MoneyBags qui ne sont pas sur l'île du joueur
task.spawn(function()
	while true do
		task.wait(1) -- Vérifier toutes les 1 seconde (plus rapide)
		
		-- D'abord, marquer les plateformes qui ne sont pas sur la bonne île
		for platform, data in pairs(activePlatforms) do
			local ownerPlayer = data.player or Players:GetPlayerByUserId(data.ownerUserId)
			if ownerPlayer then
				local platformIsland = findIslandContainerForPart(platform)
				local playerIsland = getPlayerIslandModel(ownerPlayer)
				
				if platformIsland and playerIsland and platformIsland ~= playerIsland then
					data.wrongIsland = true -- Marquer comme "mauvaise île"
				else
					data.wrongIsland = false
				end
			end
		end
		
		-- Ensuite, nettoyer les MoneyBags
		for money, data in pairs(moneyDrops) do
			if money.Parent then
				local ownerPlayer = Players:GetPlayerByUserId(data.ownerUserId)
				if ownerPlayer then
					-- 🔧 NOUVEAU: Vérifier la position physique du MoneyBag, pas sa hiérarchie
					local moneyPosition
					if money:IsA("Model") then
						moneyPosition = money:GetPivot().Position
					else
						moneyPosition = money.Position
					end
					
					local playerIsland = getPlayerIslandModel(ownerPlayer)
					
					if playerIsland and moneyPosition then
						-- Calculer la distance entre le MoneyBag et le centre de l'île du joueur
						local islandCenter = playerIsland:GetPivot().Position
						local distance = (moneyPosition - islandCenter).Magnitude
						
						print("🔍 [DEBUG] MoneyBag:", ownerPlayer.Name, "| Distance:", math.floor(distance), "studs | Île:", playerIsland.Name)
						
						-- Si le MoneyBag est à plus de 150 studs de l'île du joueur, le transférer
						if distance > 150 then
							-- Trouver la plateforme associée
							local platform = data.platform
							if platform and activePlatforms[platform] then
								local amount = data.amount or 0
								activePlatforms[platform].accumulatedOfflineMoney = (activePlatforms[platform].accumulatedOfflineMoney or 0) + amount
								activePlatforms[platform].moneyStack = nil
								print("🧹 [CLEANUP] MoneyBag transféré:", amount, "$", "| Distance:", math.floor(distance), "studs → Offline")
							end
							
							-- Détruire le MoneyBag
							money:Destroy()
							moneyDrops[money] = nil
						end
					end
				end
			else
				-- MoneyBag n'a plus de parent, nettoyer la référence
				moneyDrops[money] = nil
			end
		end
	end
end)

-- 🧹 Nettoyage à la déconnexion
Players.PlayerRemoving:Connect(function(player)
	print("🔌 [DISCONNECT] Déconnexion de", player.Name)
	
	-- Marquer les plateformes comme "joueur déconnecté" pour accumuler l'argent offline
	for platform, data in pairs(activePlatforms) do
		if data.player == player or data.ownerUserId == player.UserId then
			data.player = nil
			data.lastSeen = tick()
			data.playerDisconnected = true
		end
	end
	
	-- Ne PAS détruire les MoneyBags - ils restent là et continuent de générer
	print("ℹ️ [DISCONNECT] MoneyBags conservés pour", player.Name)
end)

-- 🔧 Pas de détection de changement d'île - Les MoneyBags restent où ils sont

-- 🔧 Configurer une plateforme existante (au lieu de la créer)
local function setupPlatform(platform)

	-- Vérifier que c'est bien une Part
	if not platform:IsA("BasePart") then
		return
	end

	-- Appliquer le style des plateformes (optionnel, vous pouvez garder votre style)
	platform.Material = Enum.Material.Neon
	platform.BrickColor = BrickColor.new("Bright blue")
	platform.Anchored = true
	platform.CanCollide = true

	-- Ajouter l'éclairage s'il n'existe pas déjà
	if not platform:FindFirstChild("PointLight") then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(0, 162, 255)
		light.Brightness = 2
		light.Range = 15
		light.Parent = platform
	end

	-- Ajouter le ProximityPrompt s'il n'existe pas déjà
	if not platform:FindFirstChild("ProximityPrompt") then
		local proximityPrompt = Instance.new("ProximityPrompt")
		proximityPrompt.ActionText = "Placer Bonbon"
		proximityPrompt.ObjectText = "Plateforme"
		proximityPrompt.HoldDuration = 0
		proximityPrompt.MaxActivationDistance = 20
		proximityPrompt.RequiresLineOfSight = false
		proximityPrompt.Parent = platform

		-- Gestion de l'interaction
		proximityPrompt.Triggered:Connect(function(player)
			handlePlatformClick(player, platform)
			-- Mettre à jour le texte après l'action
			task.wait(0.1)
			updatePlatformPromptText(platform, player)
		end)

		-- Mettre à jour le texte quand un joueur s'approche
		proximityPrompt.PromptShown:Connect(function(player)
			updatePlatformPromptText(platform, player)
		end)
	end

end

-- 🏭 Configurer les plateformes personnalisées existantes
local function setupCustomPlatforms()

	-- Fonction récursive pour chercher dans tous les modèles/dossiers
	local function searchForPlatforms(parent, depth)
		depth = depth or 0
		if depth > 10 then return end -- Éviter les boucles infinies

		for _, child in pairs(parent:GetChildren()) do
			-- Chercher les éléments nommés Platform/PlateformeX (BasePart ou Model)
			local idx = getPlatformIndex(child)
			if idx ~= nil then
				local part = findPlatformBasePart(child)
				if part then
					setupPlatform(part)
				end
			elseif child:IsA("Model") or child:IsA("Folder") then
				-- Chercher récursivement dans les modèles et dossiers
				searchForPlatforms(child, depth + 1)
			end
		end
	end

	-- Chercher dans workspace
	searchForPlatforms(workspace)

end

-- Initialisation
setupCustomPlatforms()

-- 🔄 Détection de nouvelles plateformes (pour les îles qui se créent dynamiquement)
local function watchForNewPlatforms()
	workspace.ChildAdded:Connect(function(child)
		task.wait(1) -- Attendre que l'objet soit complètement chargé
		if child:IsA("Model") or child:IsA("Folder") then
			-- Chercher des plateformes dans le nouveau modèle
			for _, subChild in pairs(child:GetDescendants()) do
				local idx = getPlatformIndex(subChild)
				if idx ~= nil then
					local part = findPlatformBasePart(subChild)
					part = part or (subChild:IsA("BasePart") and subChild or nil)
					if part then
						setupPlatform(part)
				end
			end
			end
		elseif getPlatformIndex(child) ~= nil then
			local part = findPlatformBasePart(child)
			part = part or (child:IsA("BasePart") and child or nil)
			if part then
				setupPlatform(part)
			end
		end
	end)
end

watchForNewPlatforms()

-- 🔧 Vérification périodique pour recréer les ProximityPrompts manquants
task.spawn(function()
	while true do
		task.wait(5) -- Vérifier toutes les 5 secondes
		
		-- Scanner toutes les plateformes dans workspace
		local function recheckPlatforms(parent, depth)
			depth = depth or 0
			if depth > 10 then return end
			
			for _, child in pairs(parent:GetChildren()) do
				local idx = getPlatformIndex(child)
				if idx ~= nil then
					local part = findPlatformBasePart(child)
					if part then
						-- Vérifier si le ProximityPrompt existe
						if not part:FindFirstChild("ProximityPrompt") then
							setupPlatform(part)
						end
					end
				elseif child:IsA("Model") or child:IsA("Folder") then
					recheckPlatforms(child, depth + 1)
				end
			end
		end
		
		recheckPlatforms(workspace)
	end
end)

-- Réassociation à la reconnexion
Players.PlayerAdded:Connect(function(player)
	for platform, data in pairs(activePlatforms) do
		if data.ownerUserId == player.UserId then
			data.player = player
			data.playerDisconnected = false -- 🔧 NOUVEAU: Réactiver la création de MoneyBags
			print("🔄 [RECONNECT] Réassociation plateforme pour", player.Name)
			
			-- 💰 NOUVEAU: Créer un MoneyBag avec l'argent accumulé offline
			if data.accumulatedOfflineMoney and data.accumulatedOfflineMoney > 0 then
				print("💰 [RECONNECT] Argent offline accumulé:", data.accumulatedOfflineMoney, "$")
				-- Forcer la création d'un nouveau MoneyBag à la prochaine génération
				data.moneyStack = nil
				-- Réinitialiser le timer pour générer immédiatement
				data.lastGeneration = 0
			end
		end
	end

	-- Réassocier également les piles d'argent
	for money, mdata in pairs(moneyDrops) do
		if mdata.ownerUserId == player.UserId then
			mdata.player = player
		end
	end
end)

-- 🔍 Fonction de diagnostic
local function diagnosticCandies()
	local count = 0
	for platform, data in pairs(activePlatforms) do
		count = count + 1
		if data.mainPart then
		end
	end
	if count == 0 then
	end
end

-- Debug périodique
task.spawn(function()
	while true do
		task.wait(10) -- Toutes les 10 secondes
		diagnosticCandies()
	end
end)

-- API publique de persistance
_G.CandyPlatforms = _G.CandyPlatforms or {}

function _G.CandyPlatforms.snapshotProductionForPlayer(userId)
	print("📸 [SNAPSHOT PLATFORMS] Début snapshot pour userId:", userId)
	
	-- Compter correctement les plateformes (table avec clés objets, pas indices numériques)
	local totalCount = 0
	for _ in pairs(activePlatforms) do
		totalCount = totalCount + 1
	end
	print("📸 [SNAPSHOT PLATFORMS] Nombre total de plateformes actives:", totalCount)
	
	local snapshot = {}
	local count = 0
	
	for platform, data in pairs(activePlatforms) do
		print("  🔍 Plateforme trouvée, ownerUserId:", data.ownerUserId, "| Cherché:", userId, "| Disconnected:", data.playerDisconnected or false)
		-- Sauvegarder TOUTES les données du joueur, même celles marquées pour nettoyage
		if data.ownerUserId == userId then
			local idx = getPlatformIndex(platform)
			print("  📦 Index:", idx, "| Candy:", data.candy)
			if idx then
				count = count + 1
				-- 💰 Capturer l'argent accumulé non récupéré
				local accumulatedMoney = 0
				if data.moneyStack and moneyDrops[data.moneyStack] then
					accumulatedMoney = moneyDrops[data.moneyStack].amount or 0
				end
				
				table.insert(snapshot, {
					platformIndex = idx,
					candy = data.candy,
					stackSize = data.stackSize or 1,
					genIntervalOverride = data.genIntervalOverride,
					gainMultiplier = data.gainMultiplier,
					lastGeneration = data.lastGeneration,
					totalGenerated = data.totalGenerated or 0,
					accumulatedMoney = accumulatedMoney, -- 🔧 Argent dans le MoneyBag
					accumulatedOfflineMoney = data.accumulatedOfflineMoney or 0, -- 🔧 NOUVEAU: Argent généré offline
					sizeData = data.sizeData
				})
			else
				warn("⚠️ [SNAPSHOT] Impossible d'obtenir l'index pour une plateforme")
			end
		end
	end
	
	print("✅ [SNAPSHOT PLATFORMS] Snapshot terminé:", count, "plateforme(s) sauvegardée(s)")
	return snapshot
end

local function findPlatformByIndexForPlayer(userId, index)
	-- Cherche dans l'île du joueur
	local player = Players:GetPlayerByUserId(userId)
	local island = player and getPlayerIslandModel(player)
	if island then
		for _, child in ipairs(island:GetDescendants()) do
			if child:IsA("BasePart") and getPlatformIndex(child) == index then
				return child
			end
		end
	end
	-- Fallback: rechercher globalement
	for _, child in ipairs(workspace:GetDescendants()) do
		if child:IsA("BasePart") then
			local idx = getPlatformIndex(child)
			if idx == index then return child end
		end
	end
	return nil
end

function _G.CandyPlatforms.restoreProductionForPlayer(userId, entries)
	if type(entries) ~= "table" then 
		print("⚠️ [RESTORE PLATFORMS] Pas d'entrées (type:", type(entries), ")")
		return 
	end
	
	-- 🧹 NETTOYAGE: Nettoyer les références aux anciens MoneyBags (mais ne pas les détruire)
	-- En mode Team Test, ils peuvent encore exister et contenir de l'argent
	print("🧹 [RESTORE] Vérification des MoneyBags existants pour userId:", userId)
	local existingMoney = {}
	local player = Players:GetPlayerByUserId(userId)
	local playerIsland = player and getPlayerIslandModel(player)
	
	for money, data in pairs(moneyDrops) do
		if data.ownerUserId == userId then
			-- 🔧 NOUVEAU: Vérifier que le MoneyBag est sur la bonne île
			local moneyIsland = findIslandContainerForPart(money)
			if playerIsland and moneyIsland == playerIsland then
				print("ℹ️ [RESTORE] MoneyBag existant trouvé sur la bonne île:", money.Name, "| Montant:", data.amount or 0, "$")
				existingMoney[data.platform] = {money = money, amount = data.amount}
			else
				print("⚠️ [RESTORE] MoneyBag existant sur mauvaise île:", money.Name, "| Sur:", moneyIsland and moneyIsland.Name or "workspace", "| Devrait être sur:", playerIsland and playerIsland.Name or "N/A")
				-- Transférer l'argent et détruire le MoneyBag
				if data.platform and activePlatforms[data.platform] then
					local amount = data.amount or 0
					activePlatforms[data.platform].accumulatedOfflineMoney = (activePlatforms[data.platform].accumulatedOfflineMoney or 0) + amount
					print("  💰 Transfert vers offline:", amount, "$")
				end
				money:Destroy()
				moneyDrops[money] = nil
			end
		end
	end
	
	print("🔄 [RESTORE PLATFORMS] Début restauration pour userId:", userId, "| Entrées:", #entries)
	
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		warn("⚠️ [RESTORE PLATFORMS] Joueur introuvable")
		return
	end
	
	local restoredCount = 0
	
	for i, entry in ipairs(entries) do
		print("🔍 [RESTORE PLATFORMS] Entrée", i, ":", entry.platformIndex, entry.candy, "x" .. (entry.stackSize or 1))
		local platform = findPlatformByIndexForPlayer(userId, entry.platformIndex)
		
		if not platform then
			warn("⚠️ [RESTORE PLATFORMS] Plateforme", entry.platformIndex, "introuvable")
			continue
		end
		
		print("✅ [RESTORE PLATFORMS] Plateforme", entry.platformIndex, "trouvée")
		if platform and not activePlatforms[platform] and player then
			local candyName = entry.candy
			local stackSize = entry.stackSize or 1
			local sizeDataEntry = entry.sizeData

			-- Utiliser CandyTools pour obtenir le VRAI Tool (modèle correct) puis le placer
			local okCT, CandyToolsModule = pcall(function()
				return require(game.ReplicatedStorage:WaitForChild("CandyTools"))
			end)
			if not okCT or not CandyToolsModule then
				return
			end

			-- Passer la taille via variable globale reconnue par CandyTools
			if sizeDataEntry then
				_G.restoreCandyData = {
					size = sizeDataEntry.size,
					rarity = sizeDataEntry.rarity,
					color = Color3.fromRGB(sizeDataEntry.colorR or 255, sizeDataEntry.colorG or 255, sizeDataEntry.colorB or 255),
				}
			end

			-- Créer le tool dans le backpack (temporaire), puis placer sur la plateforme
			local giveOk = CandyToolsModule.giveCandy(player, candyName, stackSize)
			_G.restoreCandyData = nil
			if not giveOk then
				return
			end

			-- Retrouver le Tool créé (même taille/rareté si dispo)
			local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
			local tool
			for _, t in ipairs(backpack:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("BaseName") == candyName then
					if sizeDataEntry then
						local ts = t:GetAttribute("CandySize")
						local tr = t:GetAttribute("CandyRarity")
						if tr == sizeDataEntry.rarity and ts and math.abs(ts - sizeDataEntry.size) < 0.05 then
							tool = t
							break
						end
					else
						tool = t
						break
					end
				end
			end

			if not tool then
				return
			end

			-- Placer via la fonction standard pour garantir un modèle identique au runtime
			placeCandyOnPlatform(player, platform, tool)
			-- Nettoyer l'instance Tool originale si elle a été détachée du backpack
			if tool and tool.Parent == nil then
				tool:Destroy()
			end
			
			-- Mettre à jour les caches et compteurs sur la plateforme placée
			local genIntervalOverride = CONFIG.GENERATION_INTERVAL
			local gainMultiplier = 1
			local pd = player and player:FindFirstChild("PlayerData")
			local su = pd and pd:FindFirstChild("ShopUnlocks")
			local com = su and su:FindFirstChild("EssenceCommune")
			local leg = su and su:FindFirstChild("EssenceLegendaire")
			if com and com.Value == true then
				genIntervalOverride = math.max(1, genIntervalOverride / 2)
			end
			if leg and leg.Value == true then
				gainMultiplier = 2
			end

			local data = activePlatforms[platform]
			if data then
				data.genIntervalOverride = entry.genIntervalOverride or genIntervalOverride
				data.gainMultiplier = entry.gainMultiplier or gainMultiplier
				data.lastGeneration = tick()
				data.totalGenerated = entry.totalGenerated or 0
				data.sizeData = sizeDataEntry or data.sizeData
			end
			
			-- 💰 NOUVEAU: Restaurer l'argent accumulé non récupéré
			local accumulatedMoney = entry.accumulatedMoney or 0
			local accumulatedOfflineMoney = entry.accumulatedOfflineMoney or 0
			
			-- Restaurer l'argent offline accumulé
			if accumulatedOfflineMoney > 0 and data then
				data.accumulatedOfflineMoney = accumulatedOfflineMoney
				print("💰 [RESTORE] Argent offline restauré:", accumulatedOfflineMoney, "$")
			end
			
			-- 🔧 Vérifier si un MoneyBag existe déjà pour cette plateforme (mode Team Test)
			if existingMoney[platform] then
				print("♻️ [RESTORE] Réutilisation MoneyBag existant pour plateforme", entry.platformIndex, "| Montant:", existingMoney[platform].amount, "$")
				data.moneyStack = existingMoney[platform].money
				-- Garder le montant existant (plus récent que la sauvegarde)
				-- Ne rien faire, le MoneyBag est déjà là avec le bon montant
			elseif accumulatedMoney > 0 and data then
				-- Créer nouvelle MoneyStack avec l'argent sauvegardé
				local moneyTemplate = game:GetService("ReplicatedStorage"):FindFirstChild("MoneyModel")
				local money
				
				if moneyTemplate then
					money = moneyTemplate:Clone()
					local ownerName = data.player and data.player.Name or data.ownerName or tostring(data.ownerUserId)
					money.Name = "MoneyStack_" .. ownerName
					
					-- Rendre toutes les parts du modèle non-collisionnables
					for _, part in ipairs(money:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = true
							part.CanCollide = false
						end
					end
				else
					-- Fallback
					money = Instance.new("Part")
					local ownerName = data.player and data.player.Name or data.ownerName or tostring(data.ownerUserId)
					money.Name = "MoneyStack_" .. ownerName
					money.Material = Enum.Material.Neon
					money.BrickColor = BrickColor.new("Bright yellow")
					money.Shape = Enum.PartType.Ball
					money.Size = Vector3.new(1.4, 1.4, 1.4)
					money.Anchored = true
					money.CanCollide = false
				end
				
				-- 🔧 CORRECTION: Distance fixe à 8 studs
				local forward = platform.CFrame.LookVector
				local frontOffset = forward * 8 + Vector3.new(0, 2, 0)
				local targetPos = platform.Position + frontOffset
				
				-- Positionner le modèle ou la part
				if money:IsA("Model") then
					money:PivotTo(CFrame.new(targetPos))
				else
					money.Position = targetPos
				end
				
				-- 🏝️ NOUVEAU: Créer le MoneyBag dans l'île du joueur
				local ownerPlayer = Players:GetPlayerByUserId(userId)
				local playerIsland = ownerPlayer and getPlayerIslandModel(ownerPlayer)
				if playerIsland then
					money.Parent = playerIsland
					print("💰 [MONEYBAG] Restauré dans l'île:", playerIsland.Name)
				else
					-- Fallback: workspace si l'île n'est pas trouvée
					money.Parent = workspace
					warn("⚠️ [MONEYBAG] Île non trouvée pour restauration, créé dans workspace")
				end
				
				-- Trouver une part pour attacher le BillboardGui
				local attachPart
				if money:IsA("Model") then
					attachPart = money.PrimaryPart or money:FindFirstChildWhichIsA("BasePart", true)
				else
					attachPart = money
				end
				
			-- GUI avec montant (formaté avec UIUtils)
			local billboardGui = Instance.new("BillboardGui")
			billboardGui.Size = UDim2.new(4, 0, 2, 0)  -- Taille en studs (fixe dans l'espace 3D)
			billboardGui.StudsOffset = Vector3.new(0, 2, 0)
			billboardGui.Adornee = attachPart
			billboardGui.Parent = money
			
			-- Formater le montant avec UIUtils
			local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
			local formattedAmount = UIUtils.formatMoneyShort(accumulatedMoney)
			
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = "💰 " .. formattedAmount .. "$"
			label.TextColor3 = Color3.fromRGB(255, 255, 0)
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.Name = "AmountLabel"
			label.Parent = billboardGui
				
				-- Animation: flottement et rotation
				if money:IsA("Model") then
					local startCFrame = money:GetPivot()
					local startTime = tick()
					local connection
					connection = RunService.Heartbeat:Connect(function()
						if not money or not money.Parent then
							connection:Disconnect()
							return
						end
						
						local elapsed = tick() - startTime
						local bobHeight = math.sin(elapsed * 2) * 0.5
						local rotation = (elapsed * 90) % 360
						
						local newCFrame = startCFrame * CFrame.new(0, bobHeight, 0) * CFrame.Angles(0, math.rad(rotation), 0)
						money:PivotTo(newCFrame)
					end)
					
					money.AncestryChanged:Connect(function()
						if not money.Parent then
							connection:Disconnect()
						end
					end)
				else
					local bobTween = TweenService:Create(money, 
						TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{Position = money.Position + Vector3.new(0, 1, 0)}
					)
					bobTween:Play()
				end
				
				-- Sauvegarder les références
				data.moneyStack = money
				moneyDrops[money] = {
					player = data.player,
					ownerUserId = data.ownerUserId,
					amount = accumulatedMoney,
					created = tick(),
					platform = platform
				}
				
			else
				warn("❌ [RESTORE PLATFORMS] Échec restauration plateforme", entry.platformIndex)
			end
			
			restoredCount = restoredCount + 1
		end
	end
	
	print("✅ [RESTORE PLATFORMS] Restauration terminée:", restoredCount, "plateforme(s) restaurée(s) sur", #entries)
end

-- 💸 Appliquer des gains hors-ligne à la reconnexion
function _G.CandyPlatforms.applyOfflineEarningsForPlayer(userId, offlineSeconds)
    offlineSeconds = math.max(0, offlineSeconds or 0)
    if offlineSeconds <= 0 then return end
    local totalOffline = 0
    local ownerPlayer = Players:GetPlayerByUserId(userId)
    for platform, data in pairs(activePlatforms) do
        if data.ownerUserId == userId then
            local interval = data.genIntervalOverride or CONFIG.GENERATION_INTERVAL
            if interval > 0 then
                local cycles = math.floor(offlineSeconds / interval)
                if cycles > 0 then
                    -- 💎 Calculer la valeur selon la recette et la taille du bonbon (comme dans generateMoney)
                    local baseValue = RecipeManager.calculatePlatformValue(data.candy, data.sizeData) or CONFIG.BASE_GENERATION
                    local amountPerCycle = (baseValue * (data.stackSize or 1)) * (data.gainMultiplier or 1)
                    local offlineAmount = cycles * amountPerCycle
                    totalOffline += offlineAmount
					-- 💰 Créer ou mettre à jour la MoneyStack (accumule avec existant)
					if not data.moneyStack or not data.moneyStack.Parent then
						local moneyTemplate = game:GetService("ReplicatedStorage"):FindFirstChild("MoneyModel")
						local money
						
						if moneyTemplate then
							money = moneyTemplate:Clone()
							local ownerName = data.player and data.player.Name or data.ownerName or tostring(data.ownerUserId)
							money.Name = "MoneyStack_" .. ownerName
							
							-- Rendre toutes les parts du modèle non-collisionnables
							for _, part in ipairs(money:GetDescendants()) do
								if part:IsA("BasePart") then
									part.Anchored = true
									part.CanCollide = false
								end
							end
						else
							-- Fallback
							money = Instance.new("Part")
							local ownerName = data.player and data.player.Name or data.ownerName or tostring(data.ownerUserId)
							money.Name = "MoneyStack_" .. ownerName
							money.Material = Enum.Material.Neon
							money.BrickColor = BrickColor.new("Bright yellow")
							money.Shape = Enum.PartType.Ball
							money.Size = Vector3.new(1.4, 1.4, 1.4)
							money.Anchored = true
							money.CanCollide = false
						end
						
						-- 🔧 CORRECTION: Distance fixe à 8 studs
						local forward = platform.CFrame.LookVector
						local frontOffset = forward * 8 + Vector3.new(0, 2, 0)
						local targetPos = platform.Position + frontOffset
						
						-- Positionner le modèle ou la part
						if money:IsA("Model") then
							money:PivotTo(CFrame.new(targetPos))
						else
							money.Position = targetPos
						end
						
						-- 🏝️ NOUVEAU: Créer le MoneyBag dans l'île du joueur
						local ownerPlayer = data.player or Players:GetPlayerByUserId(data.ownerUserId)
						local playerIsland = ownerPlayer and getPlayerIslandModel(ownerPlayer)
						if playerIsland then
							money.Parent = playerIsland
							print("💰 [MONEYBAG] Créé offline dans l'île:", playerIsland.Name)
						else
							-- Fallback: workspace si l'île n'est pas trouvée
							money.Parent = workspace
							warn("⚠️ [MONEYBAG] Île non trouvée pour offline, créé dans workspace")
						end
						
						-- Trouver une part pour attacher le BillboardGui
						local attachPart
						if money:IsA("Model") then
							attachPart = money.PrimaryPart or money:FindFirstChildWhichIsA("BasePart", true)
						else
							attachPart = money
						end
						
					local billboardGui = Instance.new("BillboardGui")
					billboardGui.Size = UDim2.new(4, 0, 2, 0)  -- Taille en studs (fixe dans l'espace 3D)
					billboardGui.StudsOffset = Vector3.new(0, 2, 0)
					billboardGui.Adornee = attachPart
					billboardGui.Parent = money
					
					-- Formater le montant avec UIUtils
					local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
					local formattedAmount = UIUtils.formatMoneyShort(offlineAmount)
					
					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = "💰 " .. formattedAmount .. "$"
					label.TextColor3 = Color3.fromRGB(255, 255, 0)
					label.TextScaled = true
					label.Font = Enum.Font.GothamBold
					label.Name = "AmountLabel"
					label.Parent = billboardGui
						
						-- Animation: flottement et rotation
						if money:IsA("Model") then
							local startCFrame = money:GetPivot()
							local startTime = tick()
							local connection
							connection = RunService.Heartbeat:Connect(function()
								if not money or not money.Parent then
									connection:Disconnect()
									return
								end
								
								local elapsed = tick() - startTime
								local bobHeight = math.sin(elapsed * 2) * 0.5
								local rotation = (elapsed * 90) % 360
								
								local newCFrame = startCFrame * CFrame.new(0, bobHeight, 0) * CFrame.Angles(0, math.rad(rotation), 0)
								money:PivotTo(newCFrame)
							end)
							
							money.AncestryChanged:Connect(function()
								if not money.Parent then
									connection:Disconnect()
								end
							end)
						else
							local bobTween = TweenService:Create(money, 
								TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
								{Position = money.Position + Vector3.new(0, 1, 0)}
							)
							bobTween:Play()
						end
						data.moneyStack = money
						moneyDrops[money] = {
							player = data.player,
							ownerUserId = data.ownerUserId,
							amount = offlineAmount,
							created = tick(),
							platform = platform
						}
					else
						-- 🔧 AMÉLIORATION: Accumulation correcte avec l'existant
						local currentAmount = moneyDrops[data.moneyStack] and moneyDrops[data.moneyStack].amount or 0
						local newAmount = currentAmount + offlineAmount
						moneyDrops[data.moneyStack] = moneyDrops[data.moneyStack] or {ownerUserId = data.ownerUserId, platform = platform, player = data.player}
						moneyDrops[data.moneyStack].amount = newAmount
					local billboardGui = data.moneyStack:FindFirstChild("BillboardGui")
					if billboardGui then
						local label = billboardGui:FindFirstChild("AmountLabel")
						if label then
							local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
							local formattedAmount = UIUtils.formatMoneyShort(newAmount)
							label.Text = "💰 " .. formattedAmount .. "$"
						end
					end
						-- Agrandir légèrement la taille si beaucoup d'argent s'accumule
						local currentSize = data.moneyStack.Size
						local maxSize = Vector3.new(2.5, 2.5, 2.5)
						if currentSize.X < maxSize.X and newAmount > currentAmount then
							local sizeIncrease = math.min(0.1, (newAmount - currentAmount) / 1000) -- 0.1 max par cycle
							data.moneyStack.Size = currentSize + Vector3.new(sizeIncrease, sizeIncrease, sizeIncrease)
						end
					end
					data.lastGeneration = tick()
					data.totalGenerated = (data.totalGenerated or 0) + offlineAmount
					
                    -- Ne plus afficher par plateforme; on affichera un seul toast total après la boucle
                end
            end
        end
    end
    -- Affichage unique du total (si > 0)
    if ownerPlayer and ownerPlayer.Parent and totalOffline > 0 then
        local function showCandyToast(amount, timeText)
            local ok, err = pcall(function()
                local pg = ownerPlayer:FindFirstChild("PlayerGui")
								if not pg then return end
								
								-- ⏳ Attendre que l'écran de chargement disparaisse (0.6s pour être sûr)
								task.wait(2.6)
								
								local gui = pg:FindFirstChild("CandyToastGui")
								if not gui then
									gui = Instance.new("ScreenGui")
									gui.Name = "CandyToastGui"
									gui.IgnoreGuiInset = true
									gui.ResetOnSpawn = false
									gui.DisplayOrder = 100
									gui.Parent = pg
								end
								-- Toast
								local toast = Instance.new("Frame")
								toast.Name = "OfflineToast"
								toast.Size = UDim2.new(0, 420, 0, 56)
								toast.AnchorPoint = Vector2.new(0.5, 0)
								toast.Position = UDim2.new(0.5, 0, 0, -60)
								toast.BackgroundColor3 = Color3.fromRGB(255, 214, 102)
								toast.Parent = gui
								local corner = Instance.new("UICorner")
								corner.CornerRadius = UDim.new(0, 14)
								corner.Parent = toast
								local stroke = Instance.new("UIStroke")
								stroke.Color = Color3.fromRGB(255, 168, 76)
								stroke.Thickness = 2
								stroke.Parent = toast
								local grad = Instance.new("UIGradient")
								grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 171, 222)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 236, 118))}
								grad.Rotation = 0
								grad.Parent = toast
								-- Icône
								local icon = Instance.new("TextLabel")
								icon.BackgroundTransparency = 1
								icon.Size = UDim2.new(0, 50, 1, 0)
								icon.Font = Enum.Font.GothamBold
								icon.TextScaled = true
								icon.Text = "🍬"
								icon.TextColor3 = Color3.fromRGB(255, 255, 255)
								icon.Parent = toast
								-- Texte
							local title = Instance.new("TextLabel")
							title.BackgroundTransparency = 1
							title.AnchorPoint = Vector2.new(0, 0.5)
							title.Position = UDim2.new(0, 58, 0.5, -10)
							title.Size = UDim2.new(1, -66, 0, 22)
							title.Font = Enum.Font.GothamBold
							title.TextScaled = true
							title.TextXAlignment = Enum.TextXAlignment.Left
							title.TextColor3 = Color3.fromRGB(46, 46, 46)
                            -- Formater le montant avec UIUtils
                            local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
                            local formattedAmount = UIUtils.formatMoneyShort(amount)
                            title.Text = "+" .. formattedAmount .. "$"
							title.Parent = toast
								local subtitle = Instance.new("TextLabel")
								subtitle.BackgroundTransparency = 1
								subtitle.AnchorPoint = Vector2.new(0, 0.5)
								subtitle.Position = UDim2.new(0, 58, 0.5, 12)
								subtitle.Size = UDim2.new(1, -66, 0, 18)
								subtitle.Font = Enum.Font.Gotham
								subtitle.TextScaled = true
								subtitle.TextXAlignment = Enum.TextXAlignment.Left
								subtitle.TextColor3 = Color3.fromRGB(66, 66, 66)
								subtitle.Text = "Gains hors-ligne (" .. timeText .. ")"
								subtitle.Parent = toast
								-- Animation slide/fade
								toast.BackgroundTransparency = 0
								toast.Position = UDim2.new(0.5, 0, 0, -60)
								local inTween = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 20)})
								inTween:Play()
								task.delay(6, function() -- 🕒 Durée augmentée de 4 à 6 secondes
									local outTween = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -60)})
									outTween:Play()
									outTween.Completed:Connect(function()
										toast:Destroy()
									end)
								end)
                            end)
        end
        local timeOffline = math.floor(offlineSeconds / 60)
        local timeText = timeOffline > 0 and (timeOffline .. " min") or (offlineSeconds .. " sec")
        showCandyToast(totalOffline, timeText)
    end
end

