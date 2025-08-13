-- DEBUGg IncubatorServer.lua  •  v4.0  (Système de slots avec crafting automatique)
-- ────────────────────────────────────────────────────────────────
--  • Nouveau système avec 5 slots d'entrée + 1 slot de sortie
--  • Calcul automatique des recettes selon les ingrédients placés
--  • Placement/retrait individuel des ingrédients dans les slots
-- ────────────────────────────────────────────────────────────────

print("🚀 DEBUGg IncubatorServer - DÉMARRAGE DU SCRIPT SERVEUR")

-------------------------------------------------
-- SERVICES & REMOTES
-------------------------------------------------
print("🔍 DEBUGg IncubatorServer - Chargement des services...")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
print("✅ DEBUGg IncubatorServer - Services chargés")

-- Module pour empiler les bonbons dans la hot-bar


-- Module de recettes - Utilisation du RecipeManager
print("🔍 DEBUGg IncubatorServer - Chargement RecipeManager...")
-- stylua: ignore
-- Cast to ModuleScript to make the type-checker happy
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager") :: ModuleScript)
print("🔍 DEBUGg IncubatorServer - Chargement CandySizeManager...")

-- Sécuriser le chargement de CandySizeManager
local CandySizeManager
local success, err = pcall(function()
    CandySizeManager = require(ReplicatedStorage:WaitForChild("CandySizeManager") :: ModuleScript)
end)

if success then
    print("✅ DEBUGg IncubatorServer - CandySizeManager chargé avec succès")
else
    print("❌ DEBUGg IncubatorServer - Erreur CandySizeManager:", err)
    print("🔧 DEBUGg IncubatorServer - Création d'un CandySizeManager temporaire...")
    CandySizeManager = {
        GetPrice = function() return 10 end,
        GetSize = function() return "Medium" end
    }
    print("✅ DEBUGg IncubatorServer - CandySizeManager temporaire créé")
end
local RENDER_WORLD_INCUBATOR_MODELS = true
local RECIPES = RecipeManager.Recettes

-- Compter les recettes manuellement (c'est un dictionnaire, pas un array)
local recipeCount = 0
for recipeName, _ in pairs(RECIPES) do
	recipeCount = recipeCount + 1
end

print("✅ DEBUGg IncubatorServer: RecipeManager chargé avec " .. tostring(recipeCount) .. " recettes")
for recipeName, _ in pairs(RECIPES) do
	print("  - Recette disponible: " .. recipeName)
end

if recipeCount == 0 then
	print("❌ DEBUGg IncubatorServer - AUCUNE RECETTE CHARGÉE! Problème avec RecipeManager!")
else
	print("✅ DEBUGg IncubatorServer - Recettes OK, production possible")
end

print("🔍 DEBUGg IncubatorServer - Début création des RemoteEvents...")

-- Utiliser les RemoteEvents existants et créer les nouveaux
local ouvrirRecettesEvent = ReplicatedStorage:WaitForChild("OuvrirRecettesEvent")

-- Créer les nouveaux RemoteEvents
print("🔧 DEBUGg IncubatorServer: Création des RemoteEvents...")
local placeIngredientEvt = Instance.new("RemoteEvent")
placeIngredientEvt.Name = "PlaceIngredientInSlot"
placeIngredientEvt.Parent = ReplicatedStorage
print("✅ PlaceIngredientInSlot créé")

local removeIngredientEvt = Instance.new("RemoteEvent")
removeIngredientEvt.Name = "RemoveIngredientFromSlot"
removeIngredientEvt.Parent = ReplicatedStorage
print("✅ RemoveIngredientFromSlot créé")

 local startCraftingEvt = Instance.new("RemoteEvent")
startCraftingEvt.Name = "StartCrafting"
startCraftingEvt.Parent = ReplicatedStorage
print("✅ StartCrafting créé")

 local stopCraftingEvt = ReplicatedStorage:FindFirstChild("StopCrafting")
 if not stopCraftingEvt then
     stopCraftingEvt = Instance.new("RemoteEvent")
     stopCraftingEvt.Name = "StopCrafting"
     stopCraftingEvt.Parent = ReplicatedStorage
     print("✅ StopCrafting créé")
 end

local getSlotsEvt = Instance.new("RemoteFunction")
getSlotsEvt.Name = "GetIncubatorSlots"
getSlotsEvt.Parent = ReplicatedStorage
print("✅ GetIncubatorSlots créé")

-- État courant d'un incubateur (craft en cours, progression, etc.)
local getStateEvt = ReplicatedStorage:FindFirstChild("GetIncubatorState")
if not getStateEvt then
    getStateEvt = Instance.new("RemoteFunction")
    getStateEvt.Name = "GetIncubatorState"
    getStateEvt.Parent = ReplicatedStorage
    print("✅ GetIncubatorState créé")
end

-- Nouveau: RemoteEvent de progrès pour l'UI incubateur
local craftProgressEvt = ReplicatedStorage:FindFirstChild("IncubatorCraftProgress")
if not craftProgressEvt then
    craftProgressEvt = Instance.new("RemoteEvent")
    craftProgressEvt.Name = "IncubatorCraftProgress"
    craftProgressEvt.Parent = ReplicatedStorage
end

-------------------------------------------------
-- ÉTAT DES INCUBATEURS
-------------------------------------------------
local incubators = {}   -- id → {slots = {nil, nil, nil, nil, nil}, crafting = {recipe, timer}}

-- Map canonique: clé normalisée → nom exact de l'ingrédient (pour restituer correctement)
local ING_CANONICAL_TO_NAME = {}
do
    local function canonize(s)
        s = tostring(s or "")
        s = s:lower()
        s = s:gsub("[^%w]", "")
        return s
    end
    for ingName, _ in pairs(RecipeManager.Ingredients or {}) do
        ING_CANONICAL_TO_NAME[canonize(ingName)] = ingName
    end
end

-------------------------------------------------
-- FONCTIONS UTILITAIRES
-------------------------------------------------
-- Déclaration anticipée pour l'effet fumée
local setSmokeEnabled
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
				-- Fallback: si pas de modèle "Incubator", retourner le premier Model trouvé
				if model then return model end
				-- Fallback 2: si l'objet porteur est un BasePart (MeshPart, etc.), l'utiliser comme racine
				if partWithPrompt:IsA("BasePart") then
					return partWithPrompt
				end
			end
		end
	end
	return nil -- Pas trouvé
end

-- Trouver le joueur propriétaire d'un incubateur via sa hiérarchie
local function getOwnerPlayerFromIncID(incID)
    local inc = getIncubatorByID(incID)
    if not inc then return nil end
    -- Remonter jusqu'au conteneur d'île (Model dont le nom commence par Ile_)
    local node: Instance? = inc
    local islandContainer: Instance? = nil
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
        return game:GetService("Players"):FindFirstChild(playerName)
    end
    -- Cas Ile_Slot_<n>
    local slotNumber = islandContainer.Name:match("Slot_(%d+)")
    if slotNumber then
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            local slot = player:GetAttribute("IslandSlot")
            if slot and tostring(slot) == tostring(slotNumber) then
                return player
            end
        end
    end
    return nil
end

local function calculateRecipeFromSlots(slots)
	print("🔍 DEBUGg SERVER calculateRecipeFromSlots - Début avec slots:", slots)
	-- Calcule quelle recette peut être faite avec les ingrédients dans les slots
	local ingredientCount = {}
	
	-- Compter les ingrédients dans les slots (nouveau système avec quantités)
	for slotIndex, slotData in pairs(slots) do
		if slotData and slotData.ingredient and slotData.quantity then
			-- Les noms d'ingrédients dans le RecipeManager sont en minuscules
			local ingredientName = slotData.ingredient:lower()
			ingredientCount[ingredientName] = (ingredientCount[ingredientName] or 0) + slotData.quantity
			print("🔍 DEBUGg SERVER - Slot", slotIndex .. ":", slotData.ingredient, "(" .. ingredientName .. ") x" .. slotData.quantity)
		end
	end
	
	print("🔍 DEBUGg SERVER - Ingrédients totaux:", ingredientCount)
	

	
	-- Chercher des recettes qui peuvent être faites avec les ingrédients disponibles
	local bestRecipe = nil
	local bestDef = nil
	local maxQuantity = 0
	
	for recipeName, def in pairs(RECIPES) do
		if def.ingredients then
			print("🔍 DEBUGg SERVER - Test recette:", recipeName)
			local canMake = true
			local minQuantity = math.huge
			
			-- Vérifier que tous les ingrédients requis sont présents
			for ingredient, needed in pairs(def.ingredients) do
				local available = ingredientCount[ingredient] or 0
				print("🔍 DEBUGg SERVER - Requis:", ingredient, "x", needed, "disponible:", available)
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
				print("✅ DEBUGg SERVER - Recette trouvée:", recipeName, "quantité:", minQuantity)
				bestRecipe = recipeName
				bestDef = def
				maxQuantity = minQuantity
			elseif canMake and hasExtraIngredients then
				print("❌ DEBUGg SERVER - Recette", recipeName, "refusée: ingrédients en trop")
			elseif not canMake then
				print("❌ DEBUGg SERVER - Recette", recipeName, "refusée: manque ingrédients")
			end
		end
	end
	
	if bestRecipe then
		print("✅ DEBUGg SERVER - Meilleure recette:", bestRecipe, "quantité:", maxQuantity)
		return bestRecipe, bestDef, maxQuantity
	end
	
	print("❌ DEBUGg SERVER - Aucune recette trouvée")
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
        if obj.Name == "IngredientVisual" or obj.Name == "RecipePreview" then
            obj:Destroy()
        end
    end
	
    -- Créer les visuels pour les ingrédients dans les slots (mode monde activé)
    if RENDER_WORLD_INCUBATOR_MODELS then
        -- Construire la vue "slots visuels":
        --  - pas de craft → data.slots
        --  - craft en cours → data.crafting.slotMap (restants par slot)
        local visualSlots = {}
        if data.crafting and data.crafting.slotMap then
            local map = data.crafting.slotMap
            for i = 1, 5 do
                local si = map[i]
                if si and si.ingredient and (si.remaining and si.remaining > 0) then
                    visualSlots[i] = { ingredient = si.ingredient, quantity = si.remaining }
                end
            end
        else
            for i = 1, 5 do
                local slotData = data.slots[i]
                if slotData then
                    visualSlots[i] = { ingredient = slotData.ingredient or slotData, quantity = slotData.quantity or 1 }
                end
            end
        end

        local ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientTools", true)
        if not ingredientToolFolder then
            ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientModels")
        end

        -- Récupérer les ancrages personnalisés si présents
        local function collectAnchorCFrames()
            local anchors = {}
            local pointsFolder = inc:FindFirstChild("IngredientAnchors") or inc:FindFirstChild("IngredientPoints")
            local function toCF(obj)
                if obj:IsA("Attachment") then return obj.WorldCFrame end
                if obj:IsA("BasePart") then return obj.CFrame end
                return nil
            end
            if pointsFolder then
                for i = 1, 5 do
                    local name = "Slot" .. i
                    local obj = pointsFolder:FindFirstChild(name)
                    if obj then
                        local cf = toCF(obj)
                        if cf then anchors[i] = cf end
                    end
                end
            end
            -- Support MeshPart: accepter Attachments nommés Slot1..Slot5 directement sous l'incubateur
            for i = 1, 5 do
                if not anchors[i] then
                    local name = "Slot" .. i
                    local direct = inc:FindFirstChild(name)
                    if not direct then direct = inc:FindFirstChild(name, true) end
                    if direct and (direct:IsA("Attachment") or direct:IsA("BasePart")) then
                        local cf = toCF(direct)
                        if cf then anchors[i] = cf end
                    end
                end
            end
            -- Compléter les indices manquants par des positions par défaut (BasePart ou Model)
            do
                local centerPos, centerHeight
                if inc:IsA("BasePart") then
                    centerPos = inc.Position
                    centerHeight = inc.Size.Y
                else
                    local primary = inc.PrimaryPart
                    local bboxCf, bboxSize = inc:GetBoundingBox()
                    centerPos = (primary and primary.Position) or bboxCf.Position
                    centerHeight = (primary and primary.Size.Y) or bboxSize.Y
                end
                local baseY = centerPos.Y + centerHeight / 2 + 0.5
                local defaults = {
                    CFrame.new(centerPos + Vector3.new(0, baseY - centerPos.Y, 2)),   -- Slot 1 (devant)
                    CFrame.new(centerPos + Vector3.new(-2, baseY - centerPos.Y, 0)),  -- Slot 2 (gauche)
                    CFrame.new(centerPos + Vector3.new(0, baseY - centerPos.Y, 0)),   -- Slot 3 (centre)
                    CFrame.new(centerPos + Vector3.new(2, baseY - centerPos.Y, 0)),   -- Slot 4 (droite)
                    CFrame.new(centerPos + Vector3.new(0, baseY - centerPos.Y, -2)),  -- Slot 5 (derrière)
                }
                for i = 1, 5 do
                    if not anchors[i] then anchors[i] = defaults[i] end
                end
            end
            return anchors
        end

        local anchors = collectAnchorCFrames()

        for i, slotData in pairs(visualSlots) do
            if slotData then
                local ingredientName = slotData.ingredient or slotData
                local template = ingredientToolFolder and ingredientToolFolder:FindFirstChild(ingredientName)
                if not template and ingredientToolFolder then
                    local ingDef = RecipeManager.Ingredients[ingredientName]
                    if ingDef and ingDef.modele then
                        template = ingredientToolFolder:FindFirstChild(ingDef.modele)
                    end
                end
                if template then
                    local visual = template:Clone()
                    visual.Name = "IngredientVisual"
                    visual.Parent = inc
                    if visual:IsA("Tool") then
                        local model = Instance.new("Model")
                        model.Name = "IngredientVisual"
                        for _, obj in ipairs(visual:GetChildren()) do obj.Parent = model end
                        visual:Destroy()
                        visual = model
                        visual.Parent = inc
                    end
                    -- Sécuriser les parties physiques
                    for _, part in pairs(visual:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Anchored = true
                            part.CanCollide = false
                            part.CanTouch = false
                            part.Massless = true
                        end
                    end
                    -- Positionner sur l'ancrage correspondant
                    local anchorCf = anchors[i]
                    if anchorCf then
                        if visual:IsA("Model") then
                            visual:PivotTo(anchorCf)
                        else
                            visual.CFrame = anchorCf
                        end
                    end

                    -- Afficher la quantité au-dessus si > 1
                    local quantity = slotData.quantity or 1
                    if quantity > 1 then
                        local base = nil
                        if visual:IsA("Model") then
                            base = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart")
                        elseif visual:IsA("BasePart") then
                            base = visual
                        end
                        if base then
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "CountBillboard"
                            bb.Adornee = base
                            bb.Size = UDim2.new(0, 70, 0, 24)
                            bb.StudsOffset = Vector3.new(0, 1.2, 0)
                            bb.AlwaysOnTop = true
                            bb.Parent = visual
                            local lbl = Instance.new("TextLabel")
                            lbl.BackgroundTransparency = 1
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.Text = "x" .. tostring(quantity)
                            lbl.TextColor3 = Color3.fromRGB(255, 240, 160)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextScaled = true
                            lbl.Parent = bb
                        end
                    end
                end
            end
        end
    end
	
	-- Supprimer un ancien billboard de statut pour éviter double texte "Production"
	local oldStatus = inc:FindFirstChild("IngredientBillboard")
	if oldStatus then oldStatus:Destroy() end

    -- Calcul recette pour un éventuel aperçu 3D
    local recipeName, _recipeDef
    do
        local _rName, _rDef = calculateRecipeFromSlots(data.slots)
        recipeName, _recipeDef = _rName, _rDef
    end
    -- Aperçu 3D du bonbon résultat dans le monde (désactivé pour UI-only)
    if RENDER_WORLD_INCUBATOR_MODELS and recipeName and _recipeDef and _recipeDef.modele then
        local folder = ReplicatedStorage:FindFirstChild("CandyModels")
        if folder then
            local tpl = folder:FindFirstChild(_recipeDef.modele)
            if tpl then
                local preview = tpl:Clone()
                preview.Name = "RecipePreview"
                preview.Parent = inc
                if preview:IsA("Tool") then
                    local m = Instance.new("Model")
                    m.Name = "RecipePreview"
                    for _, ch in ipairs(preview:GetChildren()) do ch.Parent = m end
                    preview:Destroy()
                    preview = m
                    preview.Parent = inc
                end
                for _, p in ipairs(preview:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.Anchored = true
                        p.CanCollide = false
                        p.Massless = true
                    end
                end
                -- Recalculer centre local dans ce bloc pour éviter l'usage de variables locales extérieures
                local centerPosLocal, centerHeightLocal
                if inc:IsA("BasePart") then
                    centerPosLocal = inc.Position
                    centerHeightLocal = inc.Size.Y
                else
                    local primaryLocal = inc.PrimaryPart
                    local bboxCfLocal, bboxSizeLocal = inc:GetBoundingBox()
                    centerPosLocal = (primaryLocal and primaryLocal.Position) or bboxCfLocal.Position
                    centerHeightLocal = (primaryLocal and primaryLocal.Size.Y) or bboxSizeLocal.Y
                end
                local centerOffsetY = math.clamp(centerHeightLocal * 0.25, 0.5, 2)
                local targetCf = CFrame.new(centerPosLocal + Vector3.new(0, centerOffsetY, 0))
                if preview:IsA("Model") then
                    preview:PivotTo(targetCf)
                else
                    preview.CFrame = targetCf
                end
                pcall(function()
                    if preview:IsA("Model") then preview:ScaleTo(0.6) end
                end)
                local light = Instance.new("PointLight")
                light.Brightness = 1.2
                light.Range = 8
                light.Color = Color3.fromRGB(255, 245, 200)
                light.Parent = preview:IsA("Model") and (preview.PrimaryPart or preview:FindFirstChildWhichIsA("BasePart")) or preview
            end
        end
    end
end

local function consumeIngredient(player, ingredientName)
	-- Consomme un ingrédient de l'inventaire du joueur
	-- FILTRE LES BONBONS : ne peut pas consommer les outils avec IsCandy = true
	print("🔍 DEBUGg SERVER consumeIngredient - Recherche de:", ingredientName, "pour joueur:", player.Name)
	
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
	local toolToConsume = nil
    -- Comparaison robuste (insensible à la casse/espaces)
    local function canonize(s)
        s = tostring(s or "")
        s = s:lower():gsub("[^%w]", "")
        return s
    end
    local target = canonize(ingredientName)
    local function matchesTool(tool)
        if not tool or not tool:IsA("Tool") then return false end
        local isCandy = tool:GetAttribute("IsCandy")
        if isCandy == true then return false end
        local baseName = tool:GetAttribute("BaseName")
        local nm = canonize(tool.Name)
        local bm = canonize(baseName)
        return (bm ~= "" and bm == target) or (nm ~= "" and nm:sub(1, #target) == target)
    end

	-- 1. Chercher dans le personnage (outil équipé)
	if character then
        local equippedTool = character:FindFirstChildOfClass("Tool")
        if equippedTool then
            print("🔍 DEBUGg SERVER - Outil équipé:", equippedTool.Name, "BaseName:", equippedTool:GetAttribute("BaseName"), "IsCandy:", equippedTool:GetAttribute("IsCandy"))
            if matchesTool(equippedTool) then
                toolToConsume = equippedTool
                print("✅ DEBUGg SERVER - Outil équipé trouvé")
            end
        else
			print("🔍 DEBUGg SERVER - Aucun outil équipé")
		end
	end

	-- 2. Si non trouvé, chercher dans le sac
	if not toolToConsume and backpack then
		print("🔍 DEBUGg SERVER - Recherche dans le backpack...")
		local toolCount = 0
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                toolCount = toolCount + 1
                print("🔍 DEBUGg SERVER - Tool", toolCount, ":", tool.Name, "BaseName:", tool:GetAttribute("BaseName"), "IsCandy:", tool:GetAttribute("IsCandy"))
                if matchesTool(tool) then
                    toolToConsume = tool
                    print("✅ DEBUGg SERVER - Outil dans backpack trouvé:", tool.Name)
                    break
                end
            end
        end
		if toolCount == 0 then
			print("❌ DEBUGg SERVER - Backpack vide")
		end
	end

	if not toolToConsume then
		print("❌ DEBUGg SERVER - Aucun outil trouvé pour:", ingredientName)
		return false
	end

    local count = toolToConsume:FindFirstChild("Count")
    if not count then
        -- Créer Count si absent (considérer stack = 1)
        count = Instance.new("IntValue")
        count.Name = "Count"
        count.Value = 1
        count.Parent = toolToConsume
        print("⚠️ DEBUGg SERVER - Count manquant, créé avec valeur 1 pour:", toolToConsume.Name)
    end
	
	if count.Value <= 0 then
		print("❌ DEBUGg SERVER - Count = 0 dans l'outil:", toolToConsume.Name)
		return false
	end
	
	print("✅ DEBUGg SERVER - Consommation réussie, Count avant:", count.Value)
	-- Décrémenter l'inventaire
	count.Value = count.Value - 1
	print("✅ DEBUGg SERVER - Count après:", count.Value)
	
	if count.Value <= 0 then
		print("✅ DEBUGg SERVER - Outil détruit:", toolToConsume.Name)
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
    local recipeName, recipeDefinition, quantity = calculateRecipeFromSlots(data.slots)
	
	return {
		slots = data.slots,
        recipe = recipeName,
        recipeDef = recipeDefinition,
		quantity = quantity
	}
end

-- Fournir l'état de production courant (pour verrouiller l'UI côté client)
getStateEvt.OnServerInvoke = function(player, incID)
    local data = incubators[incID]
    local crafting = data and data.crafting or nil
    if crafting then
        local owner = getOwnerPlayerFromIncID(incID)
        local isOwner = (owner == player)
        return {
            isCrafting = true,
            isOwner = isOwner,
            recipe = crafting.recipe,
            produced = crafting.produced or 0,
            quantity = crafting.quantity or 0,
            perCandyTime = crafting.perCandyTime or 0,
            elapsed = crafting.elapsed or 0,
        }
    end
    return { isCrafting = false }
end

-- Placer un ingrédient dans un slot
placeIngredientEvt.OnServerEvent:Connect(function(player, incID, slotIndex, ingredientName, qty)
	print("🔍 DEBUGg SERVER - PlaceIngredient reçu:", "Joueur:", player.Name, "incID:", incID, "slot:", slotIndex, "ingredient:", ingredientName, "qty:", qty)
	
	if not incubators[incID] then
		incubators[incID] = {
			slots = {nil, nil, nil, nil, nil},
			crafting = nil
		}
	end
	
    local data = incubators[incID]

    -- Bloquer toute modification des slots pendant une production en cours
    if data.crafting then
        warn("⛔ Tentative de placement pendant production en cours sur incubateur " .. tostring(incID))
        return
    end
	
    -- Vérifier si le slot contient déjà le même ingrédient (pour ajouter) ou un ingrédient différent (interdit)
    if data.slots[slotIndex] and data.slots[slotIndex].ingredient ~= ingredientName then 
		print("❌ DEBUGg SERVER - Slot occupé par autre ingrédient:", data.slots[slotIndex].ingredient)
		return 
	end
	
    qty = tonumber(qty) or 1
    if qty < 1 then qty = 1 end
    print("🔍 DEBUGg SERVER - Tentative de consommation de", qty, ingredientName)
    
    -- Vérifier que le joueur a assez d'ingrédients (consommation en masse)
    local consumed = 0
    for i = 1, qty do
        if consumeIngredient(player, ingredientName) then
            consumed += 1
			print("✅ DEBUGg SERVER - Consommation", i, "réussie")
        else
            print("❌ DEBUGg SERVER - Consommation", i, "échouée")
            break
        end
    end
    print("🔍 DEBUGg SERVER - Total consommé:", consumed, "sur", qty)
    if consumed == 0 then 
		print("❌ DEBUGg SERVER - Aucun ingrédient consommé, abandon")
		return 
	end
	
	-- Placer l'ingrédient dans le slot (nouveau système avec quantités)
    if data.slots[slotIndex] then
        data.slots[slotIndex].quantity = data.slots[slotIndex].quantity + consumed
    else
        data.slots[slotIndex] = { ingredient = ingredientName, quantity = consumed }
    end
	
	-- Notifier le tutoriel
	if _G.TutorialManager then
		_G.TutorialManager.onIngredientsPlaced(player, ingredientName)
	end
	
	-- Vérifier si une recette peut être faite après ce placement
	print("🔍 DEBUGg SERVER - Vérification recette après placement...")
	print("🔍 DEBUGg SERVER - Slots actuels:", data.slots)
    local recipeName, _recipeDef2, quantity = calculateRecipeFromSlots(data.slots)
    if recipeName then
        print("✅ DEBUGg SERVER - Recette trouvée:", recipeName, "quantité:", quantity)
        print("⏸️ DEBUGg SERVER - Attente du clic joueur pour démarrer la production (pas d'auto-start)")
        -- Notifier seulement la sélection de recette (pas de démarrage)
        if _G.TutorialManager then _G.TutorialManager.onRecipeSelected(player, recipeName) end
    else
		print("❌ DEBUGg SERVER - Aucune recette trouvée après placement")
		print("🔍 DEBUGg SERVER - Détails des slots pour debug:")
		for i = 1, 5 do
			if data.slots[i] then
				print("  Slot", i .. ":", data.slots[i].ingredient, "x" .. data.slots[i].quantity)
			else
				print("  Slot", i .. ": vide")
			end
		end
	end
	
	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-- Retirer un ingrédient d'un slot
removeIngredientEvt.OnServerEvent:Connect(function(player, incID, slotIndex, ingredientName)
    if not incubators[incID] then return end
	
	local data = incubators[incID]
    -- Bloquer retrait pendant production
    if data.crafting then
        warn("⛔ Tentative de retrait pendant production en cours sur incubateur " .. tostring(incID))
        return
    end
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
	
    -- Calcul vitesse des events au démarrage (constante pendant ce craft)
    local craftingIslandSlot = _G.getIslandSlotFromIncubatorID and _G.getIslandSlotFromIncubatorID(incID) or nil
    local vitesseMultiplier = 1
    -- Passif: EssenceCommune → Production vitesse x2
    do
        local owner = getOwnerPlayerFromIncID(incID)
        if owner then
            local pd = owner:FindFirstChild("PlayerData")
            local su = pd and pd:FindFirstChild("ShopUnlocks")
            local com = su and su:FindFirstChild("EssenceCommune")
            if com and com.Value == true then
                vitesseMultiplier *= 2
            end
        end
    end
    if craftingIslandSlot and _G.EventMapManager then
        vitesseMultiplier = _G.EventMapManager.getEventVitesseMultiplier(craftingIslandSlot) or 1
    end

	-- Préparer la carte des slots pour le rendu persistant pendant la production
    local slotMap = {}
    for i = 1, 5 do
        local slot = data.slots[i]
        if slot then
            local properName = slot.ingredient or slot
            local remaining = tonumber(slot.quantity) or 1
            slotMap[i] = { ingredient = properName, remaining = remaining }
        end
    end

	-- Construire la table des ingrédients restants pour toute la production
	local function canonize(s)
		s = tostring(s or "")
		s = s:lower():gsub("[^%w]", "")
		return s
	end
	local inputLeft = {}
	local inputOrder = {}
	local ingredientsPerCandy = {}
	for ingKey, neededPerCandy in pairs(recipeDef.ingredients or {}) do
		local ck = canonize(ingKey)
		inputLeft[ck] = (tonumber(neededPerCandy) or 0) * (tonumber(quantity) or 0)
		ingredientsPerCandy[ck] = tonumber(neededPerCandy) or 0
		table.insert(inputOrder, ck)
	end

    -- Démarrer un craft séquentiel par bonbon
    data.crafting = {
        recipe = recipeName,
        def = recipeDef,
        quantity = quantity,
        produced = 0,
        perCandyTime = math.max(0.1, recipeDef.temps / vitesseMultiplier),
		elapsed = 0,
		slotMap = slotMap,
		inputLeft = inputLeft,
		inputOrder = inputOrder,
		ingredientsPerCandy = ingredientsPerCandy,
    }
	
	-- Vider les slots (les ingrédients sont consommés)
	data.slots = {nil, nil, nil, nil, nil}
	
	print("✅ Crafting démarré: " .. quantity .. "x " .. recipeName .. " (temps: " .. recipeDef.temps .. "s)")
	
	-- Démarrer l'effet fumée (si un anchor existe)
	pcall(function()
		local incModel = getIncubatorByID(incID)
		if incModel then setSmokeEnabled(incModel, true) end
	end)

	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-- Arrêter le crafting et restituer les ingrédients restants
stopCraftingEvt.OnServerEvent:Connect(function(player, incID)
    if not incubators[incID] then return end
    local data = incubators[incID]
    local craft = data.crafting
    if not craft then return end

    -- Autoriser uniquement le propriétaire de l'incubateur
    local owner = getOwnerPlayerFromIncID(incID)
    if owner ~= player then
        warn("⛔ Joueur non autorisé à stopper la production sur incubateur " .. tostring(incID))
        return
    end

    local remaining = math.max(0, (craft.quantity or 0) - (craft.produced or 0))
    if remaining > 0 and craft.def and craft.def.ingredients then
        -- Restituer ingrédients pour chaque craft restant
        local function canonize(s)
            s = tostring(s or "")
            s = s:lower():gsub("[^%w]", "")
            return s
        end
        for ingKey, neededPerCandy in pairs(craft.def.ingredients) do
            local canonical = canonize(ingKey)
            local trueName = ING_CANONICAL_TO_NAME[canonical] or ingKey
            local totalToReturn = (tonumber(neededPerCandy) or 0) * remaining
            for i = 1, totalToReturn do
                returnIngredient(player, trueName)
            end
        end
    end

    -- Stopper la production
    data.crafting = nil
    updateIncubatorVisual(incID)
    -- Stopper la fumée si active
    pcall(function()
        local incModel = getIncubatorByID(incID)
        if incModel then setSmokeEnabled(incModel, false) end
    end)
    -- Cacher la barre de progression côté propriétaire
    local owner2 = getOwnerPlayerFromIncID(incID)
    if owner2 then
        local craftProgressEvt = ReplicatedStorage:FindFirstChild("IncubatorCraftProgress")
        if craftProgressEvt and craftProgressEvt:IsA("RemoteEvent") then
            -- Envoyer un reset pour que le client cache le billboard
            craftProgressEvt:FireClient(owner2, incID, nil, nil, 0, 0, 0)
        end
    end
end)

-------------------------------------------------
-- FONCTIONS POUR LES EVENTS MAP
-------------------------------------------------
function _G.getIslandSlotFromIncubatorID(incID)
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
    local islandSlot = _G.getIslandSlotFromIncubatorID and _G.getIslandSlotFromIncubatorID(incID) or nil
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

local function propel(part, direction)
    part.Anchored = false
    part.CanCollide = true
    if typeof(direction) == "Vector3" then
        local dir = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 1, 0)
        local forwardSpeed = math.random(12, 16)
        local upBoost = math.random(5, 9)
        part.AssemblyLinearVelocity = dir * forwardSpeed + Vector3.new(0, upBoost, 0)
    else
        part.AssemblyLinearVelocity = Vector3.new(
            math.random(-12,12),
            math.random(14,18),
            math.random(-12,12)
        )
    end
    part.AssemblyAngularVelocity = Vector3.new(
        math.random(-2, 2),
        math.random(-2, 2),
        math.random(-2, 2)
    )
end

local function getCandySpawnTransform(inc)
    -- Recherche d'une ancre dédiée pour l'apparition des bonbons
    local preferredNames = { "CandySpawn", "CandyExit", "SpawnPoint", "CandyMouth", "BonbonSpawn" }
    local anchor = nil
    for _, n in ipairs(preferredNames) do
        anchor = inc:FindFirstChild(n) or inc:FindFirstChild(n, true)
        if anchor then break end
    end
    if anchor then
        if anchor:IsA("Attachment") then
            local cf = anchor.WorldCFrame
            return cf, cf.LookVector
        elseif anchor:IsA("BasePart") then
            local cf = anchor.CFrame
            return cf, cf.LookVector
        end
    end
    -- Fallback: au-dessus du PrimaryPart
    local primary = inc.PrimaryPart or inc:FindFirstChildWhichIsA("BasePart", true)
    if primary then
        local pos = primary.Position + Vector3.new(0, primary.Size.Y / 2 + 1, 0)
        local cf = CFrame.new(pos)
        return cf, primary.CFrame.LookVector
    end
    return CFrame.new(0, 5, 0), Vector3.new(0, 1, 0)
end

-- Effet de fumée rose (texture 291880914) pendant la production
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
    emitter.Rate = 7 -- discret
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

local function spawnCandy(def, inc, recipeName, ownerPlayer)
	print("🍭 DEBUGg SERVER spawnCandy - Début:", recipeName, "modèle:", def.modele)
	
	local folder = ReplicatedStorage:FindFirstChild("CandyModels")
	if not folder then 
		print("❌ DEBUGg SERVER - CandyModels folder not found!")
		return 
	end
	print("✅ DEBUGg SERVER - CandyModels folder found")
	
	local template = folder:FindFirstChild(def.modele)
	if not template then
		print("❌ DEBUGg SERVER - Modèle «" .. def.modele .. "» introuvable dans CandyModels")
		return
	end
	print("✅ DEBUGg SERVER - Template trouvé:", template.Name)

	local clone = template:Clone()
	print("✅ DEBUGg SERVER - Clone créé")

	local candyTag = Instance.new("StringValue")
	candyTag.Name = "CandyType"
	candyTag.Value = recipeName
	candyTag.Parent = clone
	print("✅ DEBUGg SERVER - CandyTag ajouté")
	
    -- Générer une taille aléatoire pour le bonbon physique
    print("🔍 DEBUGg SERVER - Vérification CandySizeManager:", CandySizeManager ~= nil)
    if CandySizeManager then
    	print("🔍 DEBUGg SERVER - Début génération taille...")
        local success, sizeData = pcall(function()
            -- Passif: EssenceMythique → Forcer COLOSSAL (rarete "Colossal")
            local forceR = nil
            local owner = ownerPlayer
            if not owner then
                -- Fallback ultime: tentative par ParcelID si owner absent
                owner = getOwnerPlayerFromIncID((inc:FindFirstChild("ParcelID") and inc.ParcelID.Value) or "")
            end
            if owner then
                local pd = owner:FindFirstChild("PlayerData")
                local su = pd and pd:FindFirstChild("ShopUnlocks")
                local myth = su and su:FindFirstChild("EssenceMythique")
                if myth and myth.Value == true then
                    forceR = "Colossal"
                end
            end
            return CandySizeManager.generateRandomSize(forceR)
        end)
    	
    	if success then
    		print("✅ DEBUGg SERVER - Taille générée:", sizeData.size, sizeData.rarity)
    		
    		-- Sauvegarder la taille dans le modèle pour le transfert vers le Tool
    		local sizeValue = Instance.new("NumberValue")
    		sizeValue.Name = "CandySize"
    		sizeValue.Value = sizeData.size
    		sizeValue.Parent = clone
    		
    		local rarityValue = Instance.new("StringValue")
    		rarityValue.Name = "CandyRarity"
    		rarityValue.Value = sizeData.rarity
    		rarityValue.Parent = clone
    		
    		-- Sauvegarder la couleur
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
    		print("✅ DEBUGg SERVER - Propriétés de taille sauvegardées")
    		
    		-- Appliquer la taille au modèle physique
    		local applySuccess, applyError = pcall(function()
    			CandySizeManager.applySizeToModel(clone, sizeData)
    		end)
    		
    		if applySuccess then
    			print("✅ DEBUGg SERVER - Taille appliquée au modèle")
    		else
    			print("❌ DEBUGg SERVER - Erreur applySizeToModel:", applyError)
    		end
    		
    		print("🏭 INCUBATOR:", recipeName, "|", CandySizeManager.getDisplayString(sizeData), "| Prix:", CandySizeManager.calculatePrice(recipeName, sizeData) .. "$")
    	else
    		print("❌ DEBUGg SERVER - Erreur génération taille:", sizeData)
    	end
    else
    	print("⚠️ DEBUGg SERVER - CandySizeManager non disponible, pas de taille générée")
	end
	print("🔍 DEBUGg SERVER - Fin section CandySizeManager")

	clone.Parent = Workspace
	print("✅ DEBUGg SERVER - Bonbon ajouté au Workspace")

    -- Déterminer le transform d'apparition (ancre personnalisée si dispo)
    local spawnCf, outDir = getCandySpawnTransform(inc)
    -- Légère avance dans la direction de sortie pour éviter le clipping
    local spawnPos = spawnCf.Position + (typeof(outDir) == "Vector3" and outDir.Unit * 0.25 or Vector3.new())

    if clone:IsA("BasePart") then
		print("🔍 DEBUGg SERVER - Bonbon est une BasePart, configuration...")
        clone.CFrame = CFrame.new(spawnPos, spawnPos + (typeof(outDir) == "Vector3" and outDir or Vector3.new(0,0,-1)))
		clone.Material = Enum.Material.Plastic
		clone.TopSurface = Enum.SurfaceType.Smooth
		clone.BottomSurface = Enum.SurfaceType.Smooth
		clone.CanTouch = true
		print("🔍 DEBUGg SERVER - Appel propel()...")
        propel(clone, outDir)
		print("✅ DEBUGg SERVER - BasePart configurée et propulsée!")

	else -- Model
		print("🔍 DEBUGg SERVER - Bonbon est un Model, configuration...")
		-- Positionner le model d'abord
        clone:PivotTo(CFrame.new(spawnPos, spawnPos + (typeof(outDir) == "Vector3" and outDir or Vector3.new(0,0,-1))))
		print("✅ DEBUGg SERVER - Model positionné")
		
		-- Configurer toutes les parties
		local partCount = 0
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then 
				partCount = partCount + 1
				p.Material = Enum.Material.Plastic
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.CanTouch = true
				p.Anchored = false
				p.CanCollide = true
			end
		end
		print("✅ DEBUGg SERVER - Model configuré:", partCount, "parties")
		
		-- Propulser la partie principale
        local base = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if base then
			print("🔍 DEBUGg SERVER - Appel propel() sur base:", base.Name)
            propel(base, outDir)
			print("✅ DEBUGg SERVER - Model propulsé!")
		else
			print("⚠️ DEBUGg SERVER - Bonbon Model sans BasePart détectable:", recipeName)
		end
	end
	
	print("🎉 DEBUGg SERVER - spawnCandy terminé avec succès pour:", recipeName)
end

-------------------------------------------------
-- BOUCLE SERVEUR POUR LE CRAFTING
-------------------------------------------------
print("🚀✅ DEBUGg IncubatorServer - SCRIPT ENTIÈREMENT CHARGÉ ! EN ATTENTE DES ÉVÉNEMENTS...")

task.spawn(function()
	while true do
		task.wait(1)
		for incID, data in pairs(incubators) do
			if data.crafting then
				print("🔍 DEBUGg SERVER - Production en cours pour", incID .. ":", data.crafting.recipe, 
					"bonbon", (data.crafting.produced + 1) .. "/" .. data.crafting.quantity)
                local craft = data.crafting
                craft.elapsed += 1

                local owner = getOwnerPlayerFromIncID(incID)
        if owner then
            local progress = math.clamp(craft.elapsed / craft.perCandyTime, 0, 1)
            local remainingCurrent = math.max(0, math.ceil(craft.perCandyTime - craft.elapsed))
            local remainingTotal = math.max(0, math.ceil((craft.quantity - craft.produced - 1) * craft.perCandyTime + remainingCurrent))
            -- Assurer la présence (ou le reset) du Billboard côté client
            if craft.quantity and craft.quantity > 0 then
                craftProgressEvt:FireClient(owner, incID, craft.produced + 1, craft.quantity, progress, remainingCurrent, remainingTotal)
            else
                craftProgressEvt:FireClient(owner, incID, nil, nil, 0, 0, 0)
            end
        end

                if craft.elapsed >= craft.perCandyTime then
                    local recipeName = craft.recipe
                    local def = craft.def
                    local inc = getIncubatorByID(incID)
                    print("✅ DEBUGg SERVER - Temps écoulé! Création du bonbon", (craft.produced + 1) .. "/" .. craft.quantity)
                    if def and inc then
                        -- Décrémenter les ingrédients restants pour l'affichage visuel
                        if craft.inputLeft and craft.inputOrder and #craft.inputOrder > 0 then
                            for _, ingName in ipairs(craft.inputOrder) do
                                local need = (def.ingredients and def.ingredients[ingName]) or 0
                                if need > 0 and craft.inputLeft[ingName] and craft.inputLeft[ingName] > 0 then
                                    local toConsume = math.min(need, craft.inputLeft[ingName])
                                    craft.inputLeft[ingName] -= toConsume
                                end
                            end
                        end
                        -- Décrémenter le slotMap visuel par slot selon la recette
                        if craft.slotMap and craft.ingredientsPerCandy then
                            local function canonize(s)
                                s = tostring(s or "")
                                s = s:lower():gsub("[^%w]", "")
                                return s
                            end
                            for ingKey, needPerCandy in pairs(craft.ingredientsPerCandy) do
                                local remainingToConsume = tonumber(needPerCandy) or 0
                                if remainingToConsume > 0 then
                                    for i = 1, 5 do
                                        if remainingToConsume <= 0 then break end
                                        local si = craft.slotMap[i]
                                        if si and si.ingredient and (tonumber(si.remaining) or 0) > 0 then
                                            if canonize(si.ingredient) == tostring(ingKey) then
                                                local take = math.min(si.remaining or 0, remainingToConsume)
                                                si.remaining = math.max(0, (si.remaining or 0) - take)
                                                remainingToConsume -= take
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        local modifiedDef, _ = applyEventBonuses(def, incID, recipeName)
                        -- Passif: EssenceEpique → production multipliée par 2 (double spawn par tick)
                        local ownerPlayer = getOwnerPlayerFromIncID(incID)
                        local doDouble = false
                        if ownerPlayer then
                            local pd = ownerPlayer:FindFirstChild("PlayerData")
                            local su = pd and pd:FindFirstChild("ShopUnlocks")
                            local epi = su and su:FindFirstChild("EssenceEpique")
                            doDouble = (epi and epi.Value == true)
                        end
                        -- Passif Mythique: forcer Colossal via spawnCandy(ownerPlayer)
                        print("🍭 DEBUGg SERVER - Spawn bonbon:", recipeName)
                        spawnCandy(modifiedDef, inc, recipeName, ownerPlayer)
                        if doDouble then
                            spawnCandy(modifiedDef, inc, recipeName, ownerPlayer)
                        end
                        -- Notifier le tutoriel
						if _G.TutorialManager then
                            local owner2 = getOwnerPlayerFromIncID(incID)
                            if owner2 then
								for _, player in pairs(game:GetService("Players"):GetPlayers()) do
                                    if player == owner2 then
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

                    craft.produced += 1
                    craft.elapsed = 0
                    if craft.produced >= craft.quantity then
                        data.crafting = nil
                        updateIncubatorVisual(incID)
                        -- Arrêter la fumée à la fin de la production
                        pcall(function()
                            local incModel2 = getIncubatorByID(incID)
                            if incModel2 then setSmokeEnabled(incModel2, false) end
                        end)
                    else
                        -- Rafraîchir l'affichage pour mettre à jour les quantités restantes
                        updateIncubatorVisual(incID)
                    end
				end
			end
		end
	end
end)

-- Événement pour le ramassage des bonbons (assure unicité)
local pickupEvt = ReplicatedStorage:FindFirstChild("PickupCandyEvent")
if not pickupEvt then
    pickupEvt = Instance.new("RemoteEvent")
    pickupEvt.Name = "PickupCandyEvent"
    pickupEvt.Parent = ReplicatedStorage
end
-- Supprimer d'éventuels doublons créés par erreur
for _, ev in ipairs(ReplicatedStorage:GetChildren()) do
    if ev:IsA("RemoteEvent") and ev.Name == "PickupCandyEvent" and ev ~= pickupEvt then
        warn("⚠️ RemoteEvent 'PickupCandyEvent' dupliqué détecté, destruction du doublon")
        ev:Destroy()
    end
end

-- Gestion de l'ouverture du menu incubateur
ouvrirRecettesEvent.OnServerEvent:Connect(function(player)
	print("🍭 [SERVER] Ouverture menu incubateur pour:", player.Name)
	
	-- Appeler le TutorialManager si nécessaire
	if _G.TutorialManager then
		_G.TutorialManager.onIncubatorUsed(player)
	end
	
	-- Ici vous pouvez ajouter d'autres logiques d'ouverture si nécessaire
end)

pickupEvt.OnServerEvent:Connect(function(player, candy)
	print("🍭 [SERVER] Ramassage détecté pour:", player.Name)
	
	if _G.TutorialManager then
		print("🍭 [SERVER] Appel TutorialManager.onCandyPickedUp pour:", player.Name)
		_G.TutorialManager.onCandyPickedUp(player)
	else
		warn("⚠️ [SERVER] TutorialManager introuvable pour ramassage")
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

		-- Ajouter le bonbon via GameManager (empile également dans le Backpack)
		-- Rien à définir ici, on utilise la fonction déjà exposée dans _G.GameManager

		-- Transférer les données de taille du bonbon physique
		_G.currentPickupCandy = candy -- Variable globale pour transférer les données
		
		-- Ajouter le bonbon au sac ET au Backpack (GameManager fait les deux)
		local success = _G.GameManager and _G.GameManager.ajouterBonbonAuSac(player, candyType.Value)
		
		-- Nettoyer la variable temporaire
		_G.currentPickupCandy = nil

		-- Détruire le bonbon au sol si réussi
		if success then
			candy:Destroy()
			print("✅ Bonbon ramassé:", candyType.Value, "- Ajout:", success and "OK" or "FAIL")
			
			-- 🎓 TUTORIAL: Signaler le ramassage au tutoriel
			print("🎓 [TUTORIAL] === DÉBUG RAMASSAGE BONBON ===")
			print("🎓 [TUTORIAL] Joueur:", player.Name)
			print("🎓 [TUTORIAL] _G.TutorialManager existe:", _G.TutorialManager ~= nil)
			
			if _G.TutorialManager then
				print("🎓 [TUTORIAL] onCandyPickedUp existe:", _G.TutorialManager.onCandyPickedUp ~= nil)
				if _G.TutorialManager.isPlayerInTutorial then
					local inTutorial = _G.TutorialManager.isPlayerInTutorial(player)
					print("🎓 [TUTORIAL] Joueur en tutoriel:", inTutorial)
					if inTutorial and _G.TutorialManager.getTutorialStep then
						local currentStep = _G.TutorialManager.getTutorialStep(player)
						print("🎓 [TUTORIAL] Étape actuelle:", currentStep)
					end
				end
				
				if _G.TutorialManager.onCandyPickedUp then
					print("🎓 [TUTORIAL] Appel onCandyPickedUp...")
					_G.TutorialManager.onCandyPickedUp(player)
					print("🎓 [TUTORIAL] onCandyPickedUp terminé!")
				else
					warn("⚠️ [TUTORIAL] onCandyPickedUp manquante")
				end
			else
				warn("⚠️ [TUTORIAL] TutorialManager totalement absent de _G")
			end
			print("🎓 [TUTORIAL] === FIN DÉBUG ===")
			
			-- Notifier le client (pour détection tutoriel côté client aussi)
			local pickupEvent = ReplicatedStorage:FindFirstChild("PickupCandyEvent")
			if pickupEvent then
				pickupEvent:FireClient(player)
			end
		else
			warn("❌ Échec total du ramassage pour:", candyType.Value)
		end
	end)

	if not success then
		warn("💥 ERREUR lors du ramassage du bonbon :", err)
	end
end)

print("✅ DEBUGg IncubatorServer v4.0 chargé – Système de slots avec crafting automatique.")
print("🔧 RemoteEvents créés:", placeIngredientEvt.Name, removeIngredientEvt.Name, startCraftingEvt.Name, getSlotsEvt.Name)
