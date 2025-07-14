-- IncubatorServer.lua  •  v4.0  (Système de slots avec crafting automatique)
-- ────────────────────────────────────────────────────────────────
--  • Nouveau système avec 5 slots d'entrée + 1 slot de sortie
--  • Calcul automatique des recettes selon les ingrédients placés
--  • Placement/retrait individuel des ingrédients dans les slots
-- ────────────────────────────────────────────────────────────────

-------------------------------------------------
-- SERVICES & REMOTES
-------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- Module de recettes - Utilisation du RecipeManager
-- stylua: ignore
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local RECIPES = RecipeManager.Recettes

print("✅ IncubatorServer: RecipeManager chargé avec " .. tostring(#RECIPES) .. " recettes")
for recipeName, _ in pairs(RECIPES) do
	print("  - Recette disponible: " .. recipeName)
end

-- Utiliser les RemoteEvents existants et créer les nouveaux
local openEvt = ReplicatedStorage:WaitForChild("OpenIncubatorMenu")

-- Créer les nouveaux RemoteEvents
local placeIngredientEvt = Instance.new("RemoteEvent")
placeIngredientEvt.Name = "PlaceIngredientInSlot"
placeIngredientEvt.Parent = ReplicatedStorage

local removeIngredientEvt = Instance.new("RemoteEvent")
removeIngredientEvt.Name = "RemoveIngredientFromSlot"
removeIngredientEvt.Parent = ReplicatedStorage

local startCraftingEvt = Instance.new("RemoteEvent")
startCraftingEvt.Name = "StartCrafting"
startCraftingEvt.Parent = ReplicatedStorage

local getSlotsEvt = Instance.new("RemoteFunction")
getSlotsEvt.Name = "GetIncubatorSlots"
getSlotsEvt.Parent = ReplicatedStorage

-------------------------------------------------
-- ÉTAT DES INCUBATEURS
-------------------------------------------------
local incubators = {}   -- id → {slots = {nil, nil, nil, nil, nil}, crafting = {recipe, timer}}

-------------------------------------------------
-- FONCTIONS UTILITAIRES
-------------------------------------------------
local function getIncubatorByID(id)
	-- Trouve l'incubateur (le modèle) via son ParcelID
	local allParts = Workspace:GetDescendants()
	for _, p in ipairs(allParts) do
		if p:IsA("StringValue") and p.Name == "ParcelID" and p.Value == id then
			-- On a trouvé l'ID, on remonte à la pièce qui le contient
			local partWithPrompt = p.Parent
			if partWithPrompt then
				-- On remonte jusqu'au modèle Incubator parent
				local model = partWithPrompt:FindFirstAncestorOfClass("Model")
				if model and model.Name == "Incubator" then
					return model
				end
			end
		end
	end
	return nil -- Pas trouvé
end

local function calculateRecipeFromSlots(slots)
	-- Calcule quelle recette peut être faite avec les ingrédients dans les slots
	local ingredientCount = {}
	
	-- Compter les ingrédients dans les slots (nouveau système avec quantités)
	for _, slotData in pairs(slots) do
		if slotData and slotData.ingredient and slotData.quantity then
			-- Les noms d'ingrédients dans le RecipeManager sont en minuscules
			local ingredientName = slotData.ingredient:lower()
			ingredientCount[ingredientName] = (ingredientCount[ingredientName] or 0) + slotData.quantity
		end
	end
	

	
	-- Chercher des recettes qui peuvent être faites avec les ingrédients disponibles
	local bestRecipe = nil
	local bestDef = nil
	local maxQuantity = 0
	
	for recipeName, def in pairs(RECIPES) do
		if def.ingredients then
			local canMake = true
			local minQuantity = math.huge
			
			-- Vérifier que tous les ingrédients requis sont présents
			for ingredient, needed in pairs(def.ingredients) do
				local available = ingredientCount[ingredient] or 0
				if available < needed then
					canMake = false
					break
				else
					-- Calculer combien de fois cette recette peut être faite avec cet ingrédient
					minQuantity = math.min(minQuantity, math.floor(available / needed))
				end
			end
			
			-- Vérifier qu'il n'y a pas d'ingrédients non utilisés dans la recette
			local hasExtraIngredients = false
			for ingredient, _ in pairs(ingredientCount) do
				if not def.ingredients[ingredient] then
					hasExtraIngredients = true
					break
				end
			end
			
			-- Si la recette peut être faite et n'a pas d'ingrédients en trop
			if canMake and not hasExtraIngredients and minQuantity > maxQuantity then
				bestRecipe = recipeName
				bestDef = def
				maxQuantity = minQuantity
			end
		end
	end
	
	if bestRecipe then
		return bestRecipe, bestDef, maxQuantity
	end
	
	return nil, nil, 0
end

local function updateIncubatorVisual(incubatorID)
	-- Met à jour l'affichage visuel de l'incubateur
	local inc = getIncubatorByID(incubatorID)
	if not inc then return end
	
	local data = incubators[incubatorID]
	if not data then return end
	
	-- Nettoyer les anciens visuels
	for _, obj in pairs(inc:GetChildren()) do
		if obj.Name == "IngredientVisual" then
			obj:Destroy()
		end
	end
	
	-- Créer les visuels pour les ingrédients dans les slots
	local ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientTools", true)
	if not ingredientToolFolder then return end
	
	local primary = inc.PrimaryPart
	if not primary then return end
	
	local slotPositions = {
		Vector3.new(0, 0, 2),    -- Slot 1 (devant)
		Vector3.new(-2, 0, 0),   -- Slot 2 (gauche)
		Vector3.new(0, 0, 0),    -- Slot 3 (centre)
		Vector3.new(2, 0, 0),    -- Slot 4 (droite)
		Vector3.new(0, 0, -2),   -- Slot 5 (derrière)
	}
	
	for i, slotData in pairs(data.slots) do
		if slotData then
			local ingredientName = slotData.ingredient or slotData
			local template = ingredientToolFolder:FindFirstChild(ingredientName)
			if template then
				local visual = template:Clone()
				visual.Name = "IngredientVisual"
				visual.Parent = inc
				
				-- Convertir Tool en Model si nécessaire
				if visual:IsA("Tool") then
					local model = Instance.new("Model")
					model.Name = "IngredientVisual"
					for _, obj in ipairs(visual:GetChildren()) do
						obj.Parent = model
					end
					visual:Destroy()
					visual = model
					visual.Parent = inc
				end
				
				-- Ancrer toutes les parties
				for _, part in pairs(visual:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanCollide = false
					end
				end
				
				-- Positionner selon le slot
				local slotPos = slotPositions[i] or Vector3.new(0, 0, 0)
				local finalPos = primary.Position + slotPos + Vector3.new(0, primary.Size.Y / 2 + 0.5, 0)
				
				if visual:IsA("Model") then
					visual:PivotTo(CFrame.new(finalPos))
				else
					visual.Position = finalPos
				end
			end
		end
	end
	
	-- Mettre à jour le billboard
	local bb = inc:FindFirstChild("IngredientBillboard")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "IngredientBillboard"
		bb.Adornee = primary
		bb.Size = UDim2.new(0, 220, 0, 40)
		bb.StudsOffset = Vector3.new(0, 6, 0)
		bb.AlwaysOnTop = true
		bb.Parent = inc

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Label"
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.SourceSansBold
		lbl.Parent = bb
	end
	
	-- Afficher le contenu des slots
	local parts = {}
	for i, slotData in pairs(data.slots) do
		if slotData then
			local ingredientName = slotData.ingredient or slotData
			local quantity = slotData.quantity or 1
			table.insert(parts, "Slot " .. i .. ": " .. ingredientName .. " x" .. quantity)
		end
	end
	
	-- Afficher la recette possible
	local recipeName, _, quantity = calculateRecipeFromSlots(data.slots)
	if recipeName then
		if quantity > 1 then
			table.insert(parts, "➡️ " .. quantity .. "x " .. recipeName)
		else
			table.insert(parts, "➡️ " .. recipeName)
		end
	end
	
	bb.Label.Text = #parts > 0 and table.concat(parts, " | ") or "Vide"
end

local function consumeIngredient(player, ingredientName)
	-- Consomme un ingrédient de l'inventaire du joueur
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local toolToConsume = nil

	-- 1. Chercher dans le personnage (outil équipé)
	if character then
		local equippedTool = character:FindFirstChildOfClass("Tool")
		if equippedTool and (equippedTool:GetAttribute("BaseName") == ingredientName or equippedTool.Name:match("^"..ingredientName)) then
			toolToConsume = equippedTool
		end
	end

	-- 2. Si non trouvé, chercher dans le sac
	if not toolToConsume and backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and (tool:GetAttribute("BaseName") == ingredientName or tool.Name:match("^"..ingredientName)) then
				toolToConsume = tool
				break
			end
		end
	end

	if not toolToConsume then
		return false
	end

	local count = toolToConsume:FindFirstChild("Count")
	if not count or count.Value <= 0 then
		return false
	end
	
	-- Décrémenter l'inventaire
	count.Value = count.Value - 1
	if count.Value <= 0 then
		toolToConsume:Destroy()
	end
	
	return true
end

local function returnIngredient(player, ingredientName)
	-- Retourne un ingrédient à l'inventaire du joueur
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	
	-- Chercher s'il y a déjà un outil avec cet ingrédient
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and (tool:GetAttribute("BaseName") == ingredientName or tool.Name:match("^"..ingredientName)) then
			local count = tool:FindFirstChild("Count")
			if count then
				count.Value += 1
				return
			end
		end
	end
	
	-- Si pas trouvé, créer un nouvel outil correctement configuré
	local ingredientTools = ReplicatedStorage:FindFirstChild("IngredientTools", true)
	if ingredientTools then
		local template = ingredientTools:FindFirstChild(ingredientName)
		if template then
			local newTool = template:Clone()
			newTool:SetAttribute("BaseName", ingredientName)
			local count = newTool:FindFirstChild("Count")
			if not count then
				count = Instance.new("IntValue")
				count.Name = "Count"
				count.Parent = newTool
			end
			count.Value = 1
			newTool.Parent = backpack
		end
	end
end

-------------------------------------------------
-- ÉVÉNEMENTS DU NOUVEAU SYSTÈME
-------------------------------------------------

-- Gestionnaire d'ouverture du menu (depuis IslandManager.lua)
-- On a juste besoin de s'assurer que l'incubateur est initialisé
-- Le client récupérera les slots via getSlotsEvt
print("🔧 Connexion de l'événement d'ouverture du menu...")

-- Cette fonction est appelée quand le joueur clique sur l'incubateur (depuis IslandManager.lua)
-- Elle n'a plus besoin de faire grand-chose car le nouveau système récupère les données différemment
-- Mais on l'utilise pour s'assurer que l'incubateur est initialisé
-- (L'événement est déjà envoyé au client par IslandManager.lua)

-- Récupérer les slots et la recette calculée
getSlotsEvt.OnServerInvoke = function(player, incID)
	-- Notifier le tutoriel que l'incubateur a été ouvert
	if _G.TutorialManager then
		_G.TutorialManager.onIncubatorUsed(player)
	end
	
	if not incubators[incID] then
		incubators[incID] = {
			slots = {nil, nil, nil, nil, nil},
			crafting = nil
		}
	end
	
	local data = incubators[incID]
	local recipeName, recipeDef, quantity = calculateRecipeFromSlots(data.slots)
	
	return {
		slots = data.slots,
		recipe = recipeName,
		recipeDef = recipeDef,
		quantity = quantity
	}
end

-- Placer un ingrédient dans un slot
placeIngredientEvt.OnServerEvent:Connect(function(player, incID, slotIndex, ingredientName)
	if not incubators[incID] then
		incubators[incID] = {
			slots = {nil, nil, nil, nil, nil},
			crafting = nil
		}
	end
	
	local data = incubators[incID]
	
	-- Vérifier si le slot contient déjà le même ingrédient (pour ajouter) ou un ingrédient différent (interdit)
	if data.slots[slotIndex] then
		if data.slots[slotIndex].ingredient ~= ingredientName then
			return
		end
	end
	
	-- Vérifier que le joueur a l'ingrédient
	if not consumeIngredient(player, ingredientName) then
		return
	end
	
	-- Placer l'ingrédient dans le slot (nouveau système avec quantités)
	if data.slots[slotIndex] then
		-- Ajouter à la quantité existante
		data.slots[slotIndex].quantity = data.slots[slotIndex].quantity + 1
	else
		-- Créer un nouveau slot avec quantité 1
		data.slots[slotIndex] = {
			ingredient = ingredientName,
			quantity = 1
		}
	end
	
	-- Notifier le tutoriel
	if _G.TutorialManager then
		_G.TutorialManager.onIngredientsPlaced(player, ingredientName)
	end
	
	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-- Retirer un ingrédient d'un slot
removeIngredientEvt.OnServerEvent:Connect(function(player, incID, slotIndex, ingredientName)
	if not incubators[incID] then return end
	
	local data = incubators[incID]
	local slotData = data.slots[slotIndex]
	
	if not slotData then
		return
	end
	
	local ingredient = slotData.ingredient or slotData
	local quantity = slotData.quantity or 1
	
	-- Retirer un ingrédient du slot
	if quantity > 1 then
		-- Décrémenter la quantité
		data.slots[slotIndex].quantity = quantity - 1
	else
		-- Vider le slot complètement
		data.slots[slotIndex] = nil
	end
	
	-- Retourner l'ingrédient au joueur
	returnIngredient(player, ingredient)
	
	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-- Démarrer le crafting
startCraftingEvt.OnServerEvent:Connect(function(player, incID, recipeName)
	if not incubators[incID] then return end
	
	local data = incubators[incID]
	local calculatedRecipe, recipeDef, quantity = calculateRecipeFromSlots(data.slots)
	
	-- Vérifier que la recette correspond
	if calculatedRecipe ~= recipeName then
		print("❌ Recette incorrecte. Calculée: " .. tostring(calculatedRecipe) .. ", Demandée: " .. tostring(recipeName))
		return
	end
	
	if not recipeDef then
		print("❌ Définition de recette non trouvée")
		return
	end
	
	-- Notifier le tutoriel
	if _G.TutorialManager then
		_G.TutorialManager.onRecipeSelected(player, recipeName)
		_G.TutorialManager.onProductionStarted(player)
	end
	
	-- Démarrer le crafting
	data.crafting = {
		recipe = recipeName,
		timer = recipeDef.temps,
		quantity = quantity  -- Stocker la quantité à produire
	}
	
	-- Vider les slots (les ingrédients sont consommés)
	data.slots = {nil, nil, nil, nil, nil}
	
	print("✅ Crafting démarré: " .. quantity .. "x " .. recipeName .. " (temps: " .. recipeDef.temps .. "s)")
	
	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-------------------------------------------------
-- FONCTIONS POUR LES EVENTS MAP
-------------------------------------------------
local function getIslandSlotFromIncubatorID(incID)
	-- Utilise l'EventMapManager pour obtenir le slot de l'île
	if _G.EventMapManager and _G.EventMapManager.getIslandSlotFromIncubator then
		local slot = _G.EventMapManager.getIslandSlotFromIncubator(incID)
		print("🔍 DEBUG getIslandSlotFromIncubatorID - incID:", incID, "→ slot:", slot)
		return slot
	end
	print("❌ EventMapManager non disponible pour incID:", incID)
	return nil
end

local function applyEventBonuses(def, incID, recipeName)
	local islandSlot = getIslandSlotFromIncubatorID(incID)
	print("🔍 DEBUG applyEventBonuses - incID:", incID, "islandSlot:", islandSlot)
	if not islandSlot then 
		print("⚠️ Slot d'île non trouvé pour incID:", incID)
		return def, 1 
	end
	
	-- Récupérer les bonus d'events via l'EventMapManager
	local eventMultiplier = 1
	local eventRareteForce = nil
	local eventBonusRarete = 0
	
	if _G.EventMapManager then
		eventMultiplier = _G.EventMapManager.getEventMultiplier(islandSlot) or 1
		eventRareteForce = _G.EventMapManager.getEventRareteForce(islandSlot)
		eventBonusRarete = _G.EventMapManager.getEventBonusRarete(islandSlot) or 0
		print("✅ Bonus d'events récupérés - Multiplicateur:", eventMultiplier, "Rareté forcée:", eventRareteForce, "Bonus rareté:", eventBonusRarete)
	else
		warn("❌ _G.EventMapManager non disponible!")
	end
	
	-- Appliquer les modifications sur la recette
	local modifiedDef = {}
	for k, v in pairs(def) do
		modifiedDef[k] = v
	end
	
	-- Modifier la rareté si nécessaire
	if eventRareteForce then
		modifiedDef.rarete = eventRareteForce
		print("🌪️ Event: Rareté forcée à " .. eventRareteForce .. " pour " .. recipeName)
	elseif eventBonusRarete > 0 then
		-- Système d'amélioration de rareté
		local rarites = {"Commune", "Rare", "Épique", "Légendaire", "Mythique"}
		local currentIndex = 1
		for i, rarete in ipairs(rarites) do
			if def.rarete == rarete then
				currentIndex = i
				break
			end
		end
		local newIndex = math.min(currentIndex + eventBonusRarete, #rarites)
		modifiedDef.rarete = rarites[newIndex]
		print("🌪️ Event: Rareté améliorée de " .. def.rarete .. " à " .. modifiedDef.rarete .. " pour " .. recipeName)
	end
	
	-- Modifier la valeur selon la nouvelle rareté
	if modifiedDef.rarete ~= def.rarete then
		local rareteMultipliers = {
			["Commune"] = 1,
			["Rare"] = 1.5,
			["Épique"] = 2,
			["Légendaire"] = 3,
			["Mythique"] = 5
		}
		local multiplier = rareteMultipliers[modifiedDef.rarete] or 1
		modifiedDef.valeur = math.floor(def.valeur * multiplier)
	end
	
	print("🌪️ Event actif sur l'île " .. islandSlot .. ": x" .. eventMultiplier .. " bonbons")
	return modifiedDef, eventMultiplier
end

local function propel(part)
	part.Anchored = false
	part.CanCollide = true
	part.AssemblyLinearVelocity = Vector3.new(
		math.random(-12,12),
		math.random(14,18),
		math.random(-12,12)
	)
	part.AssemblyAngularVelocity = Vector3.new(
		math.random(-2, 2),
		math.random(-2, 2),
		math.random(-2, 2)
	)
end

local function spawnCandy(def, inc, recipeName)
	local folder = ReplicatedStorage:FindFirstChild("CandyModels")
	if not folder then return end
	local template = folder:FindFirstChild(def.modele)
	if not template then
		warn("⚠️  Modèle «" .. def.modele .. "» introuvable dans CandyModels")
		return
	end

	local clone = template:Clone()

	local candyTag = Instance.new("StringValue")
	candyTag.Name = "CandyType"
	candyTag.Value = recipeName
	candyTag.Parent = clone

	clone.Parent = Workspace

	local primary = inc.PrimaryPart
	if not primary then
		warn("⚠️  Incubateur "..inc:GetFullName().." n'a pas de PrimaryPart. Impossible de faire apparaître le bonbon.")
		clone:Destroy()
		return
	end
	
	local spawnPos = primary.Position + Vector3.new(0, primary.Size.Y / 2 + 1, 0)

	if clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(spawnPos)
		clone.Material = Enum.Material.Plastic
		clone.TopSurface = Enum.SurfaceType.Smooth
		clone.BottomSurface = Enum.SurfaceType.Smooth
		clone.CanTouch = true
		propel(clone)

	else -- Model
		-- Positionner le model d'abord
		clone:PivotTo(CFrame.new(spawnPos))
		
		-- Configurer toutes les parties
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then 
				p.Material = Enum.Material.Plastic
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.CanTouch = true
				p.Anchored = false
				p.CanCollide = true
			end
		end
		
		-- Propulser la partie principale
		local base = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if base then
			propel(base)
		else
			warn("⚠️ Bonbon Model sans BasePart détectable:", recipeName)
		end
	end
end

-------------------------------------------------
-- BOUCLE SERVEUR POUR LE CRAFTING
-------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for incID, data in pairs(incubators) do
			if data.crafting then
				-- Appliquer le multiplicateur de vitesse des events
				local craftingIslandSlot = getIslandSlotFromIncubatorID(incID)
				local vitesseMultiplier = 1
				if craftingIslandSlot and _G.EventMapManager then
					vitesseMultiplier = _G.EventMapManager.getEventVitesseMultiplier(craftingIslandSlot) or 1
				end
				
				data.crafting.timer -= vitesseMultiplier
				
				if data.crafting.timer <= 0 then
					local recipeName = data.crafting.recipe
					local baseQuantity = data.crafting.quantity or 1  -- Quantité basée sur les ingrédients
					local def = RECIPES[recipeName]
					local inc = getIncubatorByID(incID)
					
					if def and inc then
						-- Appliquer les bonus d'events
						local modifiedDef, eventMultiplier = applyEventBonuses(def, incID, recipeName)
						
						-- Calculer la quantité totale (ingrédients × bonus events)
						local totalQuantity = baseQuantity * eventMultiplier
						
						-- Spawner le(s) bonbon(s) avec délai entre chaque
						-- Créer les bonbons un par un avec délai
						task.spawn(function()
							for i = 1, totalQuantity do
								spawnCandy(modifiedDef, inc, recipeName)
								if i < totalQuantity then
									task.wait(0.8) -- Délai de 0.8 secondes entre chaque bonbon
								end
							end
						end)
						
						-- Notifier le tutoriel
						if _G.TutorialManager then
							local tutorialIslandSlot = getIslandSlotFromIncubatorID(incID)
							if tutorialIslandSlot then
								for _, player in pairs(game:GetService("Players"):GetPlayers()) do
									local slot = player:GetAttribute("IslandSlot")
									if slot and slot == tutorialIslandSlot then
										_G.TutorialManager.onCandyCreated(player)
										break
									end
								end
							end
						end
						
						-- Marquer la recette comme découverte
						local incubator = getIncubatorByID(incID)
						if incubator then
							local islandContainer = incubator.Parent and incubator.Parent.Parent
							if islandContainer then
								local playerName = islandContainer.Name:match("^Ile_(.+)$")
								if not playerName or playerName:match("^Slot_") then
									local slotNumber = islandContainer.Name:match("Slot_(%d+)")
									if slotNumber then
										for _, player in pairs(game:GetService("Players"):GetPlayers()) do
											local slot = player:GetAttribute("IslandSlot")
											if slot and tostring(slot) == slotNumber then
												playerName = player.Name
												break
											end
										end
									end
								end
								
								if playerName then
									local player = game:GetService("Players"):FindFirstChild(playerName)
									if player and player:FindFirstChild("PlayerData") then
										local recettesDecouvertes = player.PlayerData:FindFirstChild("RecettesDecouvertes")
										if recettesDecouvertes then
											local dejaDecouverte = recettesDecouvertes:FindFirstChild(recipeName)
											if not dejaDecouverte then
												local discovered = Instance.new("BoolValue")
												discovered.Name = recipeName
												discovered.Value = true
												discovered.Parent = recettesDecouvertes
												print("🎉 " .. playerName .. " a découvert la recette : " .. recipeName .. " !")
											end
										end
									end
								end
							end
						end
					end
					
					-- Terminer le crafting
					data.crafting = nil
					updateIncubatorVisual(incID)
				end
			end
		end
	end
end)

-- Événement pour le ramassage des bonbons
local pickupEvt = Instance.new("RemoteEvent")
pickupEvt.Name = "PickupCandyEvent"
pickupEvt.Parent = ReplicatedStorage

pickupEvt.OnServerEvent:Connect(function(player, candy)
	if _G.TutorialManager then
		_G.TutorialManager.onCandyPickedUp(player)
	end
	
	if not (candy and candy.Parent) then
		warn("⚠️ Bonbon invalide ou déjà détruit")
		return
	end

	local candyType = candy:FindFirstChild("CandyType")
	if not candyType then
		warn("⚠️ CandyType non trouvé sur", candy:GetFullName())
		return
	end

	local success, err = pcall(function()
		print("🔍 DEBUG Ramassage - Joueur:", player.Name, "Bonbon:", candyType.Value)
		
		local playerData = player:FindFirstChild("PlayerData")
		if not playerData then
			warn("❌ PlayerData non trouvé pour le joueur :", player.Name)
			return
		end
		print("✅ PlayerData trouvé")

		local sacBonbons = playerData:FindFirstChild("SacBonbons")
		if not sacBonbons then
			warn("❌ SacBonbons non trouvé dans PlayerData de :", player.Name)
			return
		end
		print("✅ SacBonbons trouvé, enfants actuels:", #sacBonbons:GetChildren())

		-- Fonction pour ajouter un bonbon au sac (copie de GameManager)
		local function ajouterBonbonAuSac(plr, typeB)
			print("🔍 DEBUG ajouterBonbonAuSac - Type:", typeB)
			local sac = plr.PlayerData.SacBonbons
			local slot = sac:FindFirstChild(typeB)
			if slot then 
				print("✅ Slot existant trouvé, valeur actuelle:", slot.Value)
				slot.Value += 1
				print("✅ Nouvelle valeur:", slot.Value)
			else
				print("🔍 Création d'un nouveau slot pour:", typeB)
				local cnt = #sac:GetChildren()
				local maxSlots = plr.PlayerData:FindFirstChild("MaxSlotsSac")
				local maxSlotsValue = maxSlots and maxSlots.Value or 20
				print("🔍 Slots utilisés:", cnt, "/ Max:", maxSlotsValue)
				if cnt >= maxSlotsValue then 
					print("❌ Sac plein!")
					return false 
				end
				local iv = Instance.new("IntValue")
				iv.Name = typeB
				iv.Value = 1
				iv.Parent = sac
				print("✅ Nouveau slot créé:", iv.Name, "=", iv.Value)
			end
			return true
		end

		-- Ajouter le bonbon au sac
		local success = ajouterBonbonAuSac(player, candyType.Value)
		if success then
			candy:Destroy()
			print("✅ Bonbon ramassé et ajouté au sac:", candyType.Value)
		else
			warn("❌ Sac plein, impossible d'ajouter le bonbon")
		end
	end)

	if not success then
		warn("💥 ERREUR lors du ramassage du bonbon :", err)
	end
end)

print("✅ IncubatorServer v4.0 chargé – Système de slots avec crafting automatique.")
print("🔧 RemoteEvents créés:", placeIngredientEvt.Name, removeIngredientEvt.Name, startCraftingEvt.Name, getSlotsEvt.Name)
