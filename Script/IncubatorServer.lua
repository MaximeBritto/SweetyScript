-- DEBUGg IncubatorServer.lua  •  v4.0  (Système de slots avec crafting automatique)
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

-- Module pour empiler les bonbons dans la hot-bar


-- Module de recettes - Utilisation du RecipeManager
-- stylua: ignore
-- Cast to ModuleScript to make the type-checker happy
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager") :: ModuleScript)

-- Sécuriser le chargement de CandySizeManager
local CandySizeManager
local success, err = pcall(function()
    CandySizeManager = require(ReplicatedStorage:WaitForChild("CandySizeManager") :: ModuleScript)
end)

if success then
else
    CandySizeManager = {
        GetPrice = function() return 10 end,
        GetSize = function() return "Medium" end
    }
end
local RENDER_WORLD_INCUBATOR_MODELS = true
local RECIPES = RecipeManager.Recettes

-- Compter les recettes manuellement (c'est un dictionnaire, pas un array)
local recipeCount = 0
for recipeName, _ in pairs(RECIPES) do
	recipeCount = recipeCount + 1
end

for recipeName, _ in pairs(RECIPES) do
end

if recipeCount == 0 then
else
end


-- Utiliser les RemoteEvents existants et créer les nouveaux
local ouvrirRecettesEvent = ReplicatedStorage:WaitForChild("OuvrirRecettesEvent")

-- Récupérer les RemoteEvents/Functions déjà créés côté serveur (Init script)
local placeIngredientEvt = ReplicatedStorage:WaitForChild("PlaceIngredientInSlot")

local removeIngredientEvt = ReplicatedStorage:WaitForChild("RemoveIngredientFromSlot")

local startCraftingEvt = ReplicatedStorage:WaitForChild("StartCrafting")

local stopCraftingEvt = ReplicatedStorage:FindFirstChild("StopCrafting")
if not stopCraftingEvt then
    stopCraftingEvt = Instance.new("RemoteEvent")
    stopCraftingEvt.Name = "StopCrafting"
    stopCraftingEvt.Parent = ReplicatedStorage
end

local getSlotsEvt = ReplicatedStorage:WaitForChild("GetIncubatorSlots")

-- État courant d'un incubateur (craft en cours, progression, etc.)
local getStateEvt = ReplicatedStorage:FindFirstChild("GetIncubatorState")
if not getStateEvt then
    getStateEvt = Instance.new("RemoteFunction")
    getStateEvt.Name = "GetIncubatorState"
    getStateEvt.Parent = ReplicatedStorage
end

-- Nouveau: RemoteEvent de progrès pour l'UI incubateur
local craftProgressEvt = ReplicatedStorage:FindFirstChild("IncubatorCraftProgress")
if not craftProgressEvt then
    craftProgressEvt = Instance.new("RemoteEvent")
    craftProgressEvt.Name = "IncubatorCraftProgress"
    craftProgressEvt.Parent = ReplicatedStorage
end

-- Remote pour marquer un ingrédient comme "découvert" dans le Pokédex (persistant session)
local pokedexDiscoverEvt = ReplicatedStorage:FindFirstChild("PokedexMarkIngredientDiscovered")
if not pokedexDiscoverEvt then
    pokedexDiscoverEvt = Instance.new("RemoteEvent")
    pokedexDiscoverEvt.Name = "PokedexMarkIngredientDiscovered"
    pokedexDiscoverEvt.Parent = ReplicatedStorage
end

-- Handler: enregistre l'ingrédient dans PlayerData/IngredientsDecouverts
do -- handler pour PokedexMarkIngredientDiscovered (différé jusqu'à ce que la map soit prête)
    local function canonize(s)
        s = tostring(s or "")
        s = s:lower():gsub("[^%w]", "")
        return s
    end
    pokedexDiscoverEvt.OnServerEvent:Connect(function(player, ingredientName)
        if typeof(ingredientName) ~= "string" or ingredientName == "" then return end
        local pd = player:FindFirstChild("PlayerData")
        if not pd then return end
        local folder = pd:FindFirstChild("IngredientsDecouverts")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "IngredientsDecouverts"
            folder.Parent = pd
        end
        -- Utiliser le nom exact depuis RecipeManager si possible
        -- Résolution tolérante sans dépendre de la map globale si non encore dispo
        local trueName = ingredientName
        local _ok, _ = pcall(function()
            if RecipeManager and RecipeManager.Ingredients then
                local target = canonize(ingredientName)
                for k, _ in pairs(RecipeManager.Ingredients) do
                    if canonize(k) == target then trueName = k; break end
                end
            end
        end)
        local flag = folder:FindFirstChild(trueName)
        if not flag then
            flag = Instance.new("BoolValue")
            flag.Name = trueName
            flag.Value = true
            flag.Parent = folder
        else
            flag.Value = true
        end
    end)
end

-- Marquer l'ingrédient acheté comme découvert (écoute achat V2)
do -- écoute AchatIngredientEvent_V2 (différé)
    local achatEvent = ReplicatedStorage:FindFirstChild("AchatIngredientEvent_V2")
    if achatEvent then
        achatEvent.OnServerEvent:Connect(function(player, ingredient, quantity)
            if not player or typeof(ingredient) ~= "string" then return end
            local trueName = ingredient
            local canonical = ingredient:lower():gsub("[^%w]", "")
            local _ok, _ = pcall(function()
                if RecipeManager and RecipeManager.Ingredients then
                    for k, _ in pairs(RecipeManager.Ingredients) do
                        if k:lower():gsub("[^%w]", "") == canonical then trueName = k; break end
                    end
                end
            end)
            local pd = player:FindFirstChild("PlayerData")
            if not pd then return end
            local folder = pd:FindFirstChild("IngredientsDecouverts")
            if not folder then
                folder = Instance.new("Folder")
                folder.Name = "IngredientsDecouverts"
                folder.Parent = pd
            end
            local flag = folder:FindFirstChild(trueName)
            if not flag then
                flag = Instance.new("BoolValue")
                flag.Name = trueName
                flag.Value = true
                flag.Parent = folder
            else
                flag.Value = true
            end
        end)
    end
end

-------------------------------------------------
-- ÉTAT DES INCUBATEURS
-------------------------------------------------
local incubators = {}   -- id → {slots = {nil, nil, nil, nil, nil}, crafting = {recipe, timer}}
_G.incubators = incubators  -- Exposer globalement pour IslandManager

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
	-- Calcule quelle recette peut être faite avec les ingrédients dans les slots
	local ingredientCount = {}
	
	-- Compter les ingrédients dans les slots (nouveau système avec quantités)
	for slotIndex, slotData in pairs(slots) do
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
			elseif canMake and hasExtraIngredients then
			elseif not canMake then
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
                    
                    -- NORMALISATION DE TAILLE : Tous les ingrédients auront une taille visuelle similaire
                    local function getModelSize(obj)
                        if obj:IsA("Model") then
                            local _, size = obj:GetBoundingBox()
                            return size
                        elseif obj:IsA("BasePart") then
                            return obj.Size
                        end
                        return Vector3.new(1, 1, 1)
                    end
                    
                    local currentSize = getModelSize(visual)
                    local maxDim = math.max(currentSize.X, currentSize.Y, currentSize.Z)
                    if maxDim == 0 then maxDim = 1 end
                    
                    -- Taille cible normalisée (ajustez cette valeur selon vos besoins)
                    local TARGET_VISUAL_SIZE = 2.5  -- Taille de référence en studs
                    local scaleFactor = TARGET_VISUAL_SIZE / maxDim
                    
                    -- Appliquer le scale à toutes les BasePart pour normaliser la taille
                    if scaleFactor ~= 1 then
                        for _, part in pairs(visual:GetDescendants()) do
                            if part:IsA("BasePart") then
                                -- Scaler la taille
                                part.Size = part.Size * scaleFactor
                                -- Ajuster la position relative (pour les Models)
                                if visual:IsA("Model") then
                                    local pivot = visual:GetPivot()
                                    local offset = part.Position - pivot.Position
                                    part.Position = pivot.Position + (offset * scaleFactor)
                                end
                            elseif part:IsA("SpecialMesh") then
                                -- Scaler les meshes
                                part.Scale = part.Scale * scaleFactor
                            end
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
                            -- Définir le PrimaryPart si pas déjà défini
                            if not visual.PrimaryPart then
                                local firstPart = visual:FindFirstChildWhichIsA("BasePart", true)
                                if firstPart then
                                    visual.PrimaryPart = firstPart
                                end
                            end
                            base = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart", true)
                        elseif visual:IsA("BasePart") then
                            base = visual
                        end
                        
                        if base then
                            -- Calculer le StudsOffset adapté à la taille normalisée
                            local baseSize = base.Size
                            local maxHeight = math.max(baseSize.Y, baseSize.Z, baseSize.X)
                            local offsetY = maxHeight * 0.6 + 0.5  -- Offset proportionnel + marge
                            
                            local bb = Instance.new("BillboardGui")
                            bb.Name = "CountBillboard"
                            bb.Adornee = base
                            bb.Size = UDim2.new(2, 0, 0.8, 0)  -- Taille en studs pour garder une taille constante
                            bb.StudsOffset = Vector3.new(0, offsetY, 0)
                            bb.MaxDistance = 50  -- Distance max d'affichage (50 studs)
                            bb.AlwaysOnTop = true
                            bb.Parent = visual
                            
                            -- Ajouter un fond semi-transparent pour meilleure lisibilité
                            local bgFrame = Instance.new("Frame")
                            bgFrame.Size = UDim2.new(1, 0, 1, 0)
                            bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            bgFrame.BackgroundTransparency = 0.5
                            bgFrame.BorderSizePixel = 0
                            bgFrame.Parent = bb
                            local corner = Instance.new("UICorner", bgFrame)
                            corner.CornerRadius = UDim.new(0, 6)
                            
                            local lbl = Instance.new("TextLabel")
                            lbl.BackgroundTransparency = 1
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.Text = "x" .. tostring(quantity)
                            lbl.TextColor3 = Color3.fromRGB(255, 240, 160)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextScaled = true
                            lbl.TextStrokeTransparency = 0.5  -- Contour pour meilleure visibilité
                            lbl.Parent = bb
                            
                        else
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
    -- Aperçu 3D du bonbon via ViewportFrame (même cadrage que Pokédex)
    if RENDER_WORLD_INCUBATOR_MODELS and recipeName and _recipeDef and _recipeDef.modele then
        -- Nettoyer un ancien viewport si présent
        local oldVP = inc:FindFirstChild("CandyPreviewViewport")
        if oldVP then oldVP:Destroy() end
        local folder = ReplicatedStorage:FindFirstChild("CandyModels")
        if folder then
            local tpl = folder:FindFirstChild(_recipeDef.modele)
            if tpl then
                -- Créer Billboard + ViewportFrame
                local anchorPart = inc:FindFirstChildWhichIsA("BasePart", true)
                if not anchorPart and inc:IsA("BasePart") then anchorPart = inc end
                local bb = Instance.new("BillboardGui")
                bb.Name = "CandyPreviewViewport"
                bb.Adornee = anchorPart
                bb.AlwaysOnTop = true
                bb.Size = UDim2.new(0, 150, 0, 150)
                bb.StudsOffset = Vector3.new(0, 7.0, 0)
                bb.Parent = inc

                local vp = Instance.new("ViewportFrame")
                vp.Size = UDim2.new(1, 0, 1, 0)
                vp.BackgroundTransparency = 1
                vp.Ambient = Color3.fromRGB(200, 200, 200)
                vp.LightColor = Color3.fromRGB(255, 245, 220)
                vp.Parent = bb

                -- Cloner le modèle (convertir Tool → Model si besoin)
                local preview = tpl:Clone()
                if preview:IsA("Tool") then
                    local m = Instance.new("Model")
                    m.Name = "CandyPreviewModel"
                    for _, ch in ipairs(preview:GetChildren()) do ch.Parent = m end
                    preview:Destroy()
                    preview = m
                end
                preview.Parent = vp

                -- Créer caméra et cadrer comme Pokédex
                local cam = Instance.new("Camera")
                cam.FieldOfView = 40
                cam.Parent = vp
                vp.CurrentCamera = cam

                local function positionCameraToFit(camera, root)
                    local center, size
                    if root:IsA("BasePart") then
                        center = root.Position
                        size = root.Size
                    else
                        local cf, sz = root:GetBoundingBox()
                        center, size = cf.Position, sz
                    end
                    local radius = size.Magnitude * 0.5
                    local distance = (radius / math.tan(math.rad(camera.FieldOfView * 0.5))) * 1.25
                    local dir = Vector3.new(1, 0.8, 1).Unit
                    camera.CFrame = CFrame.new(center + dir * distance, center)
                end

                positionCameraToFit(cam, preview)
            end
        end
    end
end

local function consumeIngredient(player, ingredientName)
	-- Consomme un ingrédient de l'inventaire du joueur
	-- FILTRE LES BONBONS : ne peut pas consommer les outils avec IsCandy = true
	
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
            if matchesTool(equippedTool) then
                toolToConsume = equippedTool
            end
        else
		end
	end

	-- 2. Si non trouvé, chercher dans le sac
	if not toolToConsume and backpack then
		local toolCount = 0
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                toolCount = toolCount + 1
                if matchesTool(tool) then
                    toolToConsume = tool
                    break
                end
            end
        end
		if toolCount == 0 then
		end
	end

	if not toolToConsume then
		return false
	end

    local count = toolToConsume:FindFirstChild("Count")
    if not count then
        -- Créer Count si absent (considérer stack = 1)
        count = Instance.new("IntValue")
        count.Name = "Count"
        count.Value = 1
        count.Parent = toolToConsume
    end
	
	if count.Value <= 0 then
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
	if not backpack then 
		return false
	end
	
	-- Chercher s'il y a déjà un outil avec cet ingrédient (recherche robuste)
	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local baseName = tool:GetAttribute("BaseName")
			local toolName = tool.Name
			-- Comparaison EXACTE insensible à la casse (pas de correspondance partielle)
			local match = (baseName and baseName:lower() == ingredientName:lower()) or 
			              (toolName:lower() == ingredientName:lower())
			
			if match then
				local count = tool:FindFirstChild("Count")
				if count then
					count.Value += 1
					return true
				end
			end
		end
	end
	
	-- Si pas trouvé, créer un nouvel outil correctement configuré
	local ingredientTools = ReplicatedStorage:FindFirstChild("IngredientTools", true)
	if ingredientTools then
		
		-- Normaliser le nom de l'ingrédient (enlever espaces et accents)
		local function normalizeIngredientName(name)
			return name:lower():gsub("%s+", ""):gsub("é", "e"):gsub("è", "e"):gsub("ê", "e")
		end
		
		-- Recherche robuste : exacte, insensible casse, puis normalisée
		local template = nil
		local normalizedTarget = normalizeIngredientName(ingredientName)
		
		-- 1) Recherche exacte
		for _, child in pairs(ingredientTools:GetChildren()) do
			if child.Name == ingredientName then
				template = child
				break
			end
		end
		
		-- 2) Recherche insensible à la casse
		if not template then
			for _, child in pairs(ingredientTools:GetChildren()) do
				if child.Name:lower() == ingredientName:lower() then
					template = child
					break
				end
			end
		end
		
		-- 3) Recherche normalisée (sans espaces ni accents)
		if not template then
			for _, child in pairs(ingredientTools:GetChildren()) do
				if normalizeIngredientName(child.Name) == normalizedTarget then
					template = child
					break
				end
			end
		end
		
		-- 4) Dernier recours : recherche dans RecipeManager
		if not template and RecipeManager and RecipeManager.Ingredients then
			for ingredientKey, ingredientData in pairs(RecipeManager.Ingredients) do
				if normalizeIngredientName(ingredientKey) == normalizedTarget then
					-- Chercher avec le nom du modèle
					local modelName = ingredientData.modele
					template = ingredientTools:FindFirstChild(modelName)
					if template then
						-- Utiliser le nom exact de la clé RecipeManager pour BaseName
						ingredientName = ingredientKey
						break
					end
				end
			end
		end
		
		if template then
			
			-- Si le template est un dossier/Model, chercher le Tool à l'intérieur
			local toolToClone = template
			if template.ClassName ~= "Tool" then
				local toolInside = template:FindFirstChildOfClass("Tool")
				if toolInside then
					toolToClone = toolInside
				else
					return false
				end
			end
			
			local newTool = toolToClone:Clone()
			newTool:SetAttribute("BaseName", ingredientName)
			local count = newTool:FindFirstChild("Count")
			if not count then
				count = Instance.new("IntValue")
				count.Name = "Count"
				count.Parent = newTool
			end
			count.Value = 1
			newTool.Parent = backpack
			return true
		else
			for _, child in pairs(ingredientTools:GetChildren()) do
			end
			if RecipeManager and RecipeManager.Ingredients then
				for key, data in pairs(RecipeManager.Ingredients) do
				end
			end
			return false
		end
	else
		return false
	end
end

-------------------------------------------------
-- ÉVÉNEMENTS DU NOUVEAU SYSTÈME
-------------------------------------------------

-- Gestionnaire d'ouverture du menu (depuis IslandManager.lua)
-- On a juste besoin de s'assurer que l'incubateur est initialisé
-- Le client récupérera les slots via getSlotsEvt

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

	-- Sécurité: seul le propriétaire peut lire l'état de son incubateur
	local owner = getOwnerPlayerFromIncID(incID)
	if not owner or owner ~= player then
		return nil
	end
	
	if not incubators[incID] then
		incubators[incID] = {
			slots = {nil, nil, nil, nil, nil},
			crafting = nil
		}
	end
	
    local data = incubators[incID]
    
    -- 🔧 CRUCIAL: Définir l'ownerUserId aussi ici (au cas où GetSlots est appelé avant PlaceIngredient)
    if not data.ownerUserId and player then
        data.ownerUserId = player.UserId
    end
    
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
    -- Sécurité: seul le propriétaire peut lire l'état détaillé
    local stateOwner = getOwnerPlayerFromIncID(incID)
    if not stateOwner or stateOwner ~= player then
        return { isCrafting = false }
    end
    local data = incubators[incID]
    local crafting = data and data.crafting or nil
    if crafting then
        local stateOwnerCheck = getOwnerPlayerFromIncID(incID)
        local isOwner = (stateOwnerCheck == player)
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

	-- Sécurité: seul le propriétaire peut interagir avec son incubateur
	local owner = getOwnerPlayerFromIncID(incID)
	if not owner or owner ~= player then
		return
	end
	
	if not incubators[incID] then
		incubators[incID] = {
			slots = {nil, nil, nil, nil, nil},
			crafting = nil
		}
	end
	
    local data = incubators[incID]
    
    -- 🔧 CRUCIAL: Définir l'ownerUserId dès le premier placement d'ingrédient
    -- Sans ça, les slots idle ne seront pas sauvegardés correctement
    if not data.ownerUserId and player then
        data.ownerUserId = player.UserId
    end

    -- Bloquer toute modification des slots pendant une production en cours
    if data.crafting then
        return
    end
	
    -- Gestion remplacement: si le slot a un autre ingrédient, on préparera un remplacement total
    local prevIngredient, prevQuantity = nil, 0
    if data.slots[slotIndex] and data.slots[slotIndex].ingredient ~= ingredientName then
        prevIngredient = data.slots[slotIndex].ingredient
        prevQuantity = tonumber(data.slots[slotIndex].quantity) or 1
        -- Ne pas vider le slot tout de suite; valider d'abord la consommation du nouvel ingrédient
    end
	
    qty = tonumber(qty) or 1
    if qty < 1 then qty = 1 end
    
    -- Vérifier que le joueur a assez d'ingrédients (consommation en masse)
    local consumed = 0
    for i = 1, qty do
        if consumeIngredient(player, ingredientName) then
            consumed += 1
        else
            break
        end
    end
    if consumed == 0 then 
        return 
    end
	
    -- Si c'était un remplacement, restituer l'ancien stack au joueur puis écraser le slot
    if prevIngredient and prevQuantity > 0 then
        for i = 1, prevQuantity do
            returnIngredient(player, prevIngredient)
        end
        data.slots[slotIndex] = { ingredient = ingredientName, quantity = consumed }
    else
        -- Placer/empiler (même ingrédient)
        if data.slots[slotIndex] then
            data.slots[slotIndex].quantity = data.slots[slotIndex].quantity + consumed
        else
            data.slots[slotIndex] = { ingredient = ingredientName, quantity = consumed }
        end
    end
	
	-- Notifier le tutoriel
	if _G.TutorialManager then
		_G.TutorialManager.onIngredientsPlaced(player, ingredientName)
	end
	
	-- Vérifier si une recette peut être faite après ce placement
    local recipeName, _recipeDef2, quantity = calculateRecipeFromSlots(data.slots)
    if recipeName then
        -- Notifier seulement la sélection de recette (pas de démarrage)
        if _G.TutorialManager then _G.TutorialManager.onRecipeSelected(player, recipeName) end
    else
		for i = 1, 5 do
			if data.slots[i] then
			else
			end
		end
	end
	
	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-- Retirer un ingrédient d'un slot
removeIngredientEvt.OnServerEvent:Connect(function(player, incID, slotIndex, ingredientName)
    if not incubators[incID] then return end
    -- Sécurité: seul le propriétaire peut interagir avec son incubateur
    local startOwner = getOwnerPlayerFromIncID(incID)
    if not startOwner or startOwner ~= player then
        return
    end
	
	local data = incubators[incID]
    -- Bloquer retrait pendant production
    if data.crafting then
        return
    end
	local slotData = data.slots[slotIndex]
	
	if not slotData then
		return
	end
	
	local ingredient = slotData.ingredient or slotData
	local quantity = slotData.quantity or 1
	
	-- Retirer TOUT le stack du slot (demande utilisateur)
	data.slots[slotIndex] = nil

	-- Retourner l'intégralité au joueur
	for i = 1, (quantity or 1) do
		returnIngredient(player, ingredient)
	end
	
	-- Mettre à jour l'affichage
	updateIncubatorVisual(incID)
end)

-- Démarrer le crafting
startCraftingEvt.OnServerEvent:Connect(function(player, incID, recipeName)
	if not incubators[incID] then return end

    -- Sécurité: seul le propriétaire peut démarrer la production
    local owner = getOwnerPlayerFromIncID(incID)
    if not owner or owner ~= player then
        return
    end
	
	local data = incubators[incID]
	-- Marquer le propriétaire pour lier sans dépendre du scan de la map
	data.ownerUserId = player and player.UserId or (getOwnerPlayerFromIncID(incID) and getOwnerPlayerFromIncID(incID).UserId) or nil
	local calculatedRecipe, recipeDef, quantity = calculateRecipeFromSlots(data.slots)
	
	-- Vérifier que la recette correspond
	if calculatedRecipe ~= recipeName then
		return
	end
	
	if not recipeDef then
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
        local speedOwner = getOwnerPlayerFromIncID(incID)
        if speedOwner then
            local pd = speedOwner:FindFirstChild("PlayerData")
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
    -- NOUVEAU : calculer le temps par bonbon en utilisant candiesPerBatch
    local candiesPerBatch = recipeDef.candiesPerBatch or 1
    local totalCandies = quantity * candiesPerBatch -- Nombre TOTAL de bonbons à produire
    local timePerCandy = math.max(0.1, recipeDef.temps / candiesPerBatch / vitesseMultiplier)
    
    data.crafting = {
        recipe = recipeName,
        def = recipeDef,
        quantity = totalCandies, -- Nombre total de bonbons
        produced = 0,
        perCandyTime = timePerCandy, -- Temps par bonbon individuel
		elapsed = 0,
		slotMap = slotMap,
		inputLeft = inputLeft,
		inputOrder = inputOrder,
		ingredientsPerCandy = ingredientsPerCandy,
		ownerUserId = data.ownerUserId,
		batchesCount = quantity, -- Nombre de fournées (pour la consommation d'ingrédients)
    }
	
	-- Vider les slots (les ingrédients sont consommés)
	data.slots = {nil, nil, nil, nil, nil}
	
	
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
        return
    end

    -- CORRECTION: Utiliser inputLeft qui contient les ingrédients NON CONSOMMÉS
    -- au lieu de calculer à partir du nombre de bonbons restants
    if craft.inputLeft then
        -- Restituer tous les ingrédients restants (non consommés)
        for ingKey, remainingQty in pairs(craft.inputLeft) do
            if remainingQty > 0 then
                local trueName = ING_CANONICAL_TO_NAME[ingKey] or ingKey
                for i = 1, remainingQty do
                    returnIngredient(player, trueName)
                end
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
		return slot
	end
	return nil
end

local function applyEventBonuses(def, incID, recipeName)
    local islandSlot = _G.getIslandSlotFromIncubatorID and _G.getIslandSlotFromIncubatorID(incID) or nil
	if not islandSlot then 
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
	else
	end
	
	-- Appliquer les modifications sur la recette
	local modifiedDef = {}
	for k, v in pairs(def) do
		modifiedDef[k] = v
	end
	
	-- Modifier la rareté si nécessaire
	if eventRareteForce then
		modifiedDef.rarete = eventRareteForce
	elseif eventBonusRarete > 0 then
		-- Système d'amélioration de rareté
		local rarites = {"Common", "Rare", "Epic", "Legendary", "Mythic"}
		local currentIndex = 1
		for i, rarete in ipairs(rarites) do
			if def.rarete == rarete then
				currentIndex = i
				break
			end
		end
		local newIndex = math.min(currentIndex + eventBonusRarete, #rarites)
		modifiedDef.rarete = rarites[newIndex]
	end
	
	-- Modifier la valeur selon la nouvelle rareté
	if modifiedDef.rarete ~= def.rarete then
		local rareteMultipliers = {
			["Common"] = 1,
			["Rare"] = 1.5,
			["Epic"] = 2,
			["Legendary"] = 3,
			["Mythic"] = 5
		}
		local multiplier = rareteMultipliers[modifiedDef.rarete] or 1
		modifiedDef.valeur = math.floor(def.valeur * multiplier)
	end
	
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
	-- 🔧 Ne pas spawner si le joueur est déconnecté
	if ownerPlayer then
		local Players = game:GetService("Players")
		local playerInGame = Players:GetPlayerByUserId(ownerPlayer.UserId)
		if not playerInGame then
			-- Joueur déconnecté, ne pas spawner de bonbon visuel
			return
		end
	end
	
	local folder = ReplicatedStorage:FindFirstChild("CandyModels")
	if not folder then 
		return 
	end
	
	local template = folder:FindFirstChild(def.modele)
	if not template then
		return
	end

	local clone = template:Clone()

	local candyTag = Instance.new("StringValue")
	candyTag.Name = "CandyType"
	candyTag.Value = recipeName
	candyTag.Parent = clone
	
	-- Ajouter le propriétaire du bonbon
	local ownerTag = Instance.new("IntValue")
	ownerTag.Name = "CandyOwner"
	ownerTag.Value = ownerPlayer and ownerPlayer.UserId or 0
	ownerTag.Parent = clone
	
	-- 🔧 NOUVEAU: Ajouter l'ID de l'incubateur source pour la restauration
	if inc then
		local incubatorID = nil
		-- Chercher le ParcelID dans l'incubateur
		local parcelIDObj = inc:FindFirstChild("ParcelID", true)
		if parcelIDObj and parcelIDObj:IsA("StringValue") then
			incubatorID = parcelIDObj.Value
		end
		
		if incubatorID then
			local sourceTag = Instance.new("StringValue")
			sourceTag.Name = "SourceIncubatorID"
			sourceTag.Value = incubatorID
			sourceTag.Parent = clone
			print("🔗 [SPAWN] SourceIncubatorID ajouté:", incubatorID)
		else
			print("⚠️ [SPAWN] Impossible de trouver ParcelID pour l'incubateur")
		end
	end
	
    -- Générer une taille aléatoire pour le bonbon physique (ou utiliser les données forcées)
    if CandySizeManager then
        local success, sizeData = pcall(function()
            -- 🍬 NOUVEAU: Utiliser les données de taille forcées si disponibles (pour la restauration)
            if _G.restoreCandySize then
                print("🔄 [SPAWN] Utilisation des données de taille forcées:", _G.restoreCandySize.rarity, _G.restoreCandySize.size)
                return _G.restoreCandySize
            end
            
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
    		
    		-- Appliquer la taille au modèle physique
    		local applySuccess, applyError = pcall(function()
    			CandySizeManager.applySizeToModel(clone, sizeData)
    		end)
    		
    		if applySuccess then
    		else
    		end
    		
    	else
    	end
    else
	end

	clone.Parent = Workspace

    -- Déterminer le transform d'apparition (ancre personnalisée si dispo)
    local spawnCf, outDir = getCandySpawnTransform(inc)
    -- Légère avance dans la direction de sortie pour éviter le clipping
    local spawnPos = spawnCf.Position + (typeof(outDir) == "Vector3" and outDir.Unit * 0.25 or Vector3.new())

    if clone:IsA("BasePart") then
        clone.CFrame = CFrame.new(spawnPos, spawnPos + (typeof(outDir) == "Vector3" and outDir or Vector3.new(0,0,-1)))
		clone.Material = Enum.Material.Plastic
		clone.TopSurface = Enum.SurfaceType.Smooth
		clone.BottomSurface = Enum.SurfaceType.Smooth
		clone.CanTouch = false -- Désactiver par défaut pour tous les joueurs
        propel(clone, outDir)
        
        -- Désactiver les ClickDetectors pour les joueurs non-propriétaires (BasePart)
        local clickDetector = clone:FindFirstChildOfClass("ClickDetector")
        if clickDetector then
            -- Désactiver le ClickDetector par défaut
            clickDetector.MaxActivationDistance = 0
            -- Ajouter un script local pour gérer l'activation conditionnelle
            local localScript = Instance.new("LocalScript")
            localScript.Name = "CandyClickHandler"
            localScript.Source = [[
                local Players = game:GetService("Players")
                local player = Players.LocalPlayer
                local clickDetector = script.Parent:FindFirstChildOfClass("ClickDetector")
                local candy = script.Parent
                
                -- Vérifier le propriétaire du bonbon
                local function canInteract()
                    local candyOwner = candy:FindFirstChild("CandyOwner")
                    if not candyOwner or not candyOwner:IsA("IntValue") then
                        return true -- Rétrocompatibilité
                    end
                    return candyOwner.Value == player.UserId
                end
                
                -- Activer/désactiver le ClickDetector et CanTouch selon le propriétaire
                local function updateClickDetector()
                    if canInteract() then
                        clickDetector.MaxActivationDistance = 10
                        script.Parent.CanTouch = true
                    else
                        clickDetector.MaxActivationDistance = 0
                        script.Parent.CanTouch = false
                    end
                end
                
                -- Mettre à jour au démarrage
                updateClickDetector()
                
                -- Surveiller les changements de propriétaire
                local candyOwner = candy:FindFirstChild("CandyOwner")
                if candyOwner then
                    candyOwner.Changed:Connect(updateClickDetector)
                end
            ]]
            localScript.Parent = clone
        end

	else -- Model
		-- Positionner le model d'abord
        clone:PivotTo(CFrame.new(spawnPos, spawnPos + (typeof(outDir) == "Vector3" and outDir or Vector3.new(0,0,-1))))
		
		-- Configurer toutes les parties
		local partCount = 0
		for _, p in clone:GetDescendants() do
			if p:IsA("BasePart") then 
				partCount = partCount + 1
				p.Material = Enum.Material.Plastic
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				p.CanTouch = false -- Désactiver par défaut pour tous les joueurs
				p.Anchored = false
				p.CanCollide = true
			end
		end
		
		-- Propulser la partie principale
        local base = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if base then
            propel(base, outDir)
		else
		end
		
		-- Désactiver les ClickDetectors pour les joueurs non-propriétaires
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				local clickDetector = part:FindFirstChildOfClass("ClickDetector")
				if clickDetector then
					-- Désactiver le ClickDetector par défaut
					clickDetector.MaxActivationDistance = 0
					-- Ajouter un script local pour gérer l'activation conditionnelle
					local localScript = Instance.new("LocalScript")
					localScript.Name = "CandyClickHandler"
					localScript.Source = [[
						local Players = game:GetService("Players")
						local player = Players.LocalPlayer
						local clickDetector = script.Parent:FindFirstChildOfClass("ClickDetector")
						local candy = script.Parent.Parent
						
						-- Vérifier le propriétaire du bonbon
						local function canInteract()
							local candyOwner = candy:FindFirstChild("CandyOwner")
							if not candyOwner or not candyOwner:IsA("IntValue") then
								return true -- Rétrocompatibilité
							end
							return candyOwner.Value == player.UserId
						end
						
						-- Activer/désactiver le ClickDetector et CanTouch selon le propriétaire
						local function updateClickDetector()
							if canInteract() then
								clickDetector.MaxActivationDistance = 10
								script.Parent.CanTouch = true
							else
								clickDetector.MaxActivationDistance = 0
								script.Parent.CanTouch = false
							end
						end
						
						-- Mettre à jour au démarrage
						updateClickDetector()
						
						-- Surveiller les changements de propriétaire
						local candyOwner = candy:FindFirstChild("CandyOwner")
						if candyOwner then
							candyOwner.Changed:Connect(updateClickDetector)
						end
					]]
					localScript.Parent = part
				end
			end
		end
	end
	
end

-------------------------------------------------
-- BOUCLE SERVEUR POUR LE CRAFTING
-------------------------------------------------

task.spawn(function()
	while true do
		task.wait(1/30) -- 🆕 Boucle 30x par seconde pour effet ultra-smooth (30 FPS)
		for incID, data in pairs(incubators) do
			if data.crafting then
                local craft = data.crafting
                craft.elapsed += 1/30 -- 🆕 Incrémente par ~0.033 seconde

                local owner = getOwnerPlayerFromIncID(incID)
        if owner then
            local progress = math.clamp(craft.elapsed / craft.perCandyTime, 0, 1)
            local remainingCurrent = math.max(0, craft.perCandyTime - craft.elapsed)
            local remainingTotal = math.max(0, (craft.quantity - craft.produced - 1) * craft.perCandyTime + remainingCurrent)
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
                        local craftOwner = getOwnerPlayerFromIncID(incID)
                        local doDouble = false
                        if craftOwner then
                            local pd = craftOwner:FindFirstChild("PlayerData")
                            local su = pd and pd:FindFirstChild("ShopUnlocks")
                            local epi = su and su:FindFirstChild("EssenceEpique")
                            doDouble = (epi and epi.Value == true)
                        end
                        -- Passif Mythique: forcer Colossal via spawnCandy(ownerPlayer)
                        spawnCandy(modifiedDef, inc, recipeName, craftOwner)
                        if doDouble then
                            spawnCandy(modifiedDef, inc, recipeName, craftOwner)
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
                        -- Marquer la recette comme découverte (fiable via propriétaire d'incubateur)
                        do
                            local ownerPlr = getOwnerPlayerFromIncID(incID)
                            if ownerPlr then
                                local pd = ownerPlr:FindFirstChild("PlayerData")
                                if pd then
                                    local rf = pd:FindFirstChild("RecettesDecouvertes")
                                    if not rf then
                                        rf = Instance.new("Folder")
                                        rf.Name = "RecettesDecouvertes"
                                        rf.Parent = pd
                                    end
                                    if not rf:FindFirstChild(recipeName) then
                                        local discovered = Instance.new("BoolValue")
                                        discovered.Name = recipeName
                                        discovered.Value = true
                                        discovered.Parent = rf
                                    end
                                end
                            end
                        end
                    end

                    craft.produced += 1
                    craft.elapsed = 0
                    if craft.produced >= craft.quantity then
                        -- Restituer les ingrédients restants (extras non consommés)
                        do
                            local ownerPlr = getOwnerPlayerFromIncID(incID)
                            if ownerPlr and craft.slotMap then
                                for i = 1, 5 do
                                    local si = craft.slotMap[i]
                                    if si and si.ingredient and (tonumber(si.remaining) or 0) > 0 then
                                        for _ = 1, math.floor(si.remaining) do
                                            returnIngredient(ownerPlr, si.ingredient)
                                        end
                                        si.remaining = 0
                                    end
                                end
                            end
                        end
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

-------------------------------------------------
-- OFFLINE/SNAPSHOT PERSISTENCE API
-------------------------------------------------

-- Produire un bonbon (1 unité) pour un incubateur donné, en respectant les compteurs
local function _produceOneCandy(incID)
    local data = incubators[incID]
    if not data or not data.crafting then return false end
    local craft = data.crafting
    local inc = getIncubatorByID(incID)
    if not inc then return false end
    local def = craft.def
    if not def then return false end
    -- Décrémenter le slotMap et inputLeft comme dans la boucle serveur
    if craft.inputLeft and craft.inputOrder and #craft.inputOrder > 0 then
        for _, ingName in ipairs(craft.inputOrder) do
            local need = (def.ingredients and def.ingredients[ingName]) or 0
            if need > 0 and craft.inputLeft[ingName] and craft.inputLeft[ingName] > 0 then
                local toConsume = math.min(need, craft.inputLeft[ingName])
                craft.inputLeft[ingName] -= toConsume
            end
        end
    end
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
    -- Appliquer bonus event et spawn
    local modifiedDef, _ = applyEventBonuses(def, incID, craft.recipe)
    local owner = getOwnerPlayerFromIncID(incID)
    -- Passif: EssenceEpique → double spawn
    local doDouble = false
    if owner then
        local pd = owner:FindFirstChild("PlayerData")
        local su = pd and pd:FindFirstChild("ShopUnlocks")
        local epi = su and su:FindFirstChild("EssenceEpique")
        doDouble = (epi and epi.Value == true)
    end
    spawnCandy(modifiedDef, inc, craft.recipe, owner)
    if doDouble then
        spawnCandy(modifiedDef, inc, craft.recipe, owner)
    end
    craft.produced += 1
    craft.elapsed = 0
    if craft.produced >= (craft.quantity or 0) then
        data.crafting = nil
        updateIncubatorVisual(incID)
        pcall(function()
            local incModel2 = getIncubatorByID(incID)
            if incModel2 then setSmokeEnabled(incModel2, false) end
        end)
        return true
    else
        updateIncubatorVisual(incID)
        return true
    end
end

-- Snapshot de la production en cours pour un joueur
-- 🔧 NOUVELLE FONCTION: Extraire l'index d'incubateur depuis son ID
local function getIncubatorIndexFromID(incID)
    -- Format: "Ile_<Name>_<idx>" ou "Ile_Slot_X_<idx>"
    -- Extraire le dernier chiffre
    local idx = tonumber(string.match(incID or "", "_(%d+)$"))
    return idx
end

-- 🔧 NOUVELLE FONCTION: Trouver un incubateur par index sur l'île du joueur
local function findIncubatorByIndexForPlayer(userId, index)
    local player = game:GetService("Players"):GetPlayerByUserId(userId)
    if not player then return nil end
    
    -- Trouver l'île du joueur
    local islandByName = Workspace:FindFirstChild("Ile_" .. player.Name)
    local slot = player:GetAttribute("IslandSlot")
    local islandBySlot = slot and Workspace:FindFirstChild("Ile_Slot_" .. tostring(slot))
    local island = islandByName or islandBySlot
    
    if not island then return nil end
    
    -- Chercher l'incubateur avec cet index dans l'île
    for _, obj in ipairs(island:GetDescendants()) do
        if obj:IsA("StringValue") and obj.Name == "ParcelID" then
            local parcelIdx = tonumber(string.match(obj.Value or "", "_(%d+)$"))
            if parcelIdx == index then
                -- Retourner l'ID complet (nouveau)
                return obj.Value
            end
        end
    end
    
    return nil
end

_G.Incubator = _G.Incubator or {}
function _G.Incubator.snapshotProductionForPlayer(userId)
    local entries = {}
    for incID, data in pairs(incubators) do
        local owner = getOwnerPlayerFromIncID(incID)
        local bindUserId = data.ownerUserId or (owner and owner.UserId)
        if bindUserId == userId then
            -- 🔧 CORRECTION: Sauvegarder l'INDEX au lieu de l'ID complet
            local incIndex = getIncubatorIndexFromID(incID)
            if not incIndex then
                warn("⚠️ [INCUBATOR] Impossible d'extraire l'index de:", incID)
                continue
            end
            
            local craft = data.crafting
            if craft and craft.recipe and craft.def then
                -- Serialiser slotMap minimal (ingredient + remaining)
                local smap = nil
                if craft.slotMap then
                    smap = {}
                    for i = 1, 5 do
                        local si = craft.slotMap[i]
                        if si and si.ingredient and (tonumber(si.remaining) or 0) > 0 then
                            smap[i] = { ingredient = si.ingredient, remaining = tonumber(si.remaining) or 0 }
                        end
                    end
                end
                -- Copier inputLeft et inputOrder/ingredientsPerCandy si présents
                local ileft = nil
                if craft.inputLeft then
                    ileft = {}
                    for k, v in pairs(craft.inputLeft) do ileft[k] = v end
                end
                local iorder = nil
                if craft.inputOrder then
                    iorder = {}
                    for i, k in ipairs(craft.inputOrder) do iorder[i] = k end
                end
                local ingPerCandy = nil
                if craft.ingredientsPerCandy then
                    ingPerCandy = {}
                    for k, v in pairs(craft.ingredientsPerCandy) do ingPerCandy[k] = v end
                end
                table.insert(entries, {
                    incubatorIndex = incIndex,  -- 🔧 INDEX au lieu de incID
                    recipe = craft.recipe,
                    quantity = craft.quantity or 0,
                    produced = craft.produced or 0,
                    perCandyTime = craft.perCandyTime or 0,
                    elapsed = craft.elapsed or 0,
                    ownerUserId = bindUserId,
                    slotMap = smap,
                    inputLeft = ileft,
                    inputOrder = iorder,
                    ingredientsPerCandy = ingPerCandy,
                })
            elseif data.slots then
                -- 🔧 NOUVEAU: Sauvegarder aussi les slots SANS production en cours
                -- Cela évite la perte des ingrédients placés mais non craftés
                local hasIngredients = false
                local idleSlots = {}
                for i = 1, 5 do
                    local slotData = data.slots[i]
                    if slotData and slotData.ingredient then
                        hasIngredients = true
                        idleSlots[i] = {
                            ingredient = slotData.ingredient,
                            quantity = tonumber(slotData.quantity) or 1
                        }
                    end
                end
                
                if hasIngredients then
                    -- Marquer comme "idle" (pas de production) pour que restore sache quoi faire
                    local idleEntry = {
                        incubatorIndex = incIndex,  -- 🔧 INDEX au lieu de incID
                        isIdle = true,  -- Flag pour indiquer que c'est juste des slots, pas une production
                        idleSlots = idleSlots,
                        ownerUserId = bindUserId,
                    }
                    table.insert(entries, idleEntry)
                else
                end
            end
        end
    end
    return entries
end

-- Restaurer la production depuis snapshot (sans appliquer offline)
function _G.Incubator.restoreProductionForPlayer(userId, entries)
    if type(entries) ~= "table" then return end
    for _, e in ipairs(entries) do
        -- 🔧 CORRECTION: Utiliser l'index pour trouver le NOUVEL incubateur sur la nouvelle île
        local incIndex = e.incubatorIndex or e.incID  -- Support ancien format (incID) pour compatibilité
        local actualIncID = nil
        
        if type(incIndex) == "number" then
            -- Nouveau format: chercher par index
            actualIncID = findIncubatorByIndexForPlayer(userId, incIndex)
            if not actualIncID then
                warn("⚠️ [INCUBATOR] Incubateur index", incIndex, "introuvable pour userId", userId)
                continue
            end
            print("✅ [INCUBATOR] Trouvé incubateur index", incIndex, "→", actualIncID)
        else
            -- Ancien format: utiliser l'ID tel quel (compatibilité)
            actualIncID = incIndex
        end
        
        local owner = getOwnerPlayerFromIncID(actualIncID)
        local boundOk = (tonumber(e.ownerUserId) == tonumber(userId))
        -- Assouplir: si owner pas encore détecté (map pas prête), utiliser l'ownerUserId du snapshot
        if boundOk or (not owner) or (owner and owner.UserId == userId) then
            -- 🔧 NOUVEAU: Gérer la restauration des slots "idle" (ingrédients sans production)
            if e.isIdle and e.idleSlots then
                incubators[actualIncID] = incubators[actualIncID] or { slots = {nil, nil, nil, nil, nil}, crafting = nil }
                incubators[actualIncID].ownerUserId = tonumber(e.ownerUserId) or tonumber(userId)
                
                -- IMPORTANT: Les ingrédients ont déjà été consommés lors du placement initial
                -- Il faut les redonner au joueur car ils ne sont pas en production
                local ownerPlayer = owner or game:GetService("Players"):GetPlayerByUserId(userId)
                if ownerPlayer then
                    
                    for i = 1, 5 do
                        local slotData = e.idleSlots[i]
                        if slotData and slotData.ingredient then
                            local quantity = tonumber(slotData.quantity) or 1
                            
                            -- Utiliser la fonction canonique pour retrouver le nom exact
                            local trueName = slotData.ingredient
                            local canonical = slotData.ingredient:lower():gsub("[^%w]", "")
                            if ING_CANONICAL_TO_NAME[canonical] then
                                trueName = ING_CANONICAL_TO_NAME[canonical]
                            end
                            
                            -- Rendre les ingrédients au joueur (avec vérification backpack)
                            local backpack = ownerPlayer:FindFirstChildOfClass("Backpack")
                            if backpack then
                                for j = 1, quantity do
                                    local success = pcall(function()
                                        returnIngredient(ownerPlayer, trueName)
                                    end)
                                    if success then
                                    else
                                    end
                                end
                            else
                                -- Retry après délai si backpack pas encore prêt
                                task.delay(2, function()
                                    local bp = ownerPlayer:FindFirstChildOfClass("Backpack")
                                    if bp then
                                        for j = 1, quantity do
                                            returnIngredient(ownerPlayer, trueName)
                                        end
                                    else
                                    end
                                end)
                            end
                        end
                    end
                else
                end
                
                -- Ne PAS remettre dans les slots, on les rend au joueur pour qu'il gère
                -- incubators[actualIncID].slots reste vide
                updateIncubatorVisual(actualIncID)
            elseif e.recipe then
                -- Production en cours normale
                local def = RECIPES and RECIPES[e.recipe]
                if def then
                    incubators[actualIncID] = incubators[actualIncID] or { slots = {nil, nil, nil, nil, nil}, crafting = nil }
                    local craft = {
                        recipe = e.recipe,
                        def = def,
                        quantity = tonumber(e.quantity) or 0,
                        produced = math.clamp(tonumber(e.produced) or 0, 0, tonumber(e.quantity) or 0),
                        perCandyTime = math.max(0.1, tonumber(e.perCandyTime) or (def.temps or 1)),
                        elapsed = math.clamp(tonumber(e.elapsed) or 0, 0, math.max(0.1, tonumber(e.perCandyTime) or (def.temps or 1)))
                    }
                    -- Reconstituer les maps pour décrément visuel futur si fournies
                    craft.slotMap = nil
                    if type(e.slotMap) == "table" then
                        craft.slotMap = {}
                        for i = 1, 5 do
                            local si = e.slotMap[i]
                            if si and si.ingredient then
                                craft.slotMap[i] = { ingredient = si.ingredient, remaining = tonumber(si.remaining) or 0 }
                            end
                        end
                    end
                    craft.inputLeft = nil
                    if type(e.inputLeft) == "table" then
                        craft.inputLeft = {}
                        for k, v in pairs(e.inputLeft) do craft.inputLeft[k] = tonumber(v) or 0 end
                    end
                    craft.inputOrder = nil
                    if type(e.inputOrder) == "table" then
                        craft.inputOrder = {}
                        for i, k in ipairs(e.inputOrder) do craft.inputOrder[i] = k end
                    end
                    craft.ingredientsPerCandy = (type(e.ingredientsPerCandy) == "table") and e.ingredientsPerCandy or (def.ingredients or {})
                    craft.ownerUserId = tonumber(e.ownerUserId) or tonumber(userId)
                    incubators[actualIncID].ownerUserId = craft.ownerUserId
                    incubators[actualIncID].crafting = craft
                    updateIncubatorVisual(actualIncID)
                end
            end
        end
    end
end

-- Appliquer les gains hors-ligne par joueur
function _G.Incubator.applyOfflineForPlayer(userId, offlineSeconds)
    offlineSeconds = math.max(0, tonumber(offlineSeconds) or 0)
    if offlineSeconds <= 0 then return end
    for incID, data in pairs(incubators) do
        local owner = getOwnerPlayerFromIncID(incID)
        local boundOk = (tonumber(data.ownerUserId) == tonumber(userId))
        if boundOk or (not owner) or (owner and owner.UserId == userId) then
            local craft = data.crafting
            if craft and craft.perCandyTime and craft.quantity and craft.produced then
                local remaining = math.max(0, (craft.quantity or 0) - (craft.produced or 0))
                if remaining > 0 then
                    local totalTime = (craft.elapsed or 0) + offlineSeconds
                    local canProduce = math.min(remaining, math.floor(totalTime / (craft.perCandyTime or 1)))
                    for i = 1, canProduce do
                        if not data.crafting then break end
                        _produceOneCandy(incID)
                    end
                    
                    local progressEvt = ReplicatedStorage:FindFirstChild("IncubatorCraftProgress")
                    if progressEvt and progressEvt:IsA("RemoteEvent") then
                        local PlayersService = game:GetService("Players")
                        if not owner then owner = PlayersService:GetPlayerByUserId(userId) end
                        
                        if data.crafting then
                            -- Production en cours : envoyer la progression
                            data.crafting.elapsed = totalTime % (craft.perCandyTime or 1)
                            local currentIndex = (data.crafting.produced or 0) + 1
                            local total = data.crafting.quantity or 0
                            local prog = math.clamp((data.crafting.elapsed or 0) / (data.crafting.perCandyTime or 1), 0, 1)
                            local remainingCurrent = math.max(0, math.ceil((data.crafting.perCandyTime or 1) - (data.crafting.elapsed or 0)))
                            local remainingTotal = math.max(0, math.ceil((total - (currentIndex - 1) - 1) * (data.crafting.perCandyTime or 1) + remainingCurrent))
                            if owner then
                                progressEvt:FireClient(owner, incID, currentIndex, total, prog, remainingCurrent, remainingTotal)
                            end
                        else
                            -- Production terminée : envoyer un reset pour cacher l'UI
                            if owner then
                                progressEvt:FireClient(owner, incID, nil, nil, 0, 0, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end

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
        ev:Destroy()
    end
end

-- Gestion de l'ouverture du menu incubateur
ouvrirRecettesEvent.OnServerEvent:Connect(function(player)
	
	-- Appeler le TutorialManager si nécessaire
	if _G.TutorialManager then
		_G.TutorialManager.onIncubatorUsed(player)
	end
	
	-- Ici vous pouvez ajouter d'autres logiques d'ouverture si nécessaire
end)

pickupEvt.OnServerEvent:Connect(function(player, candy)
	
	if _G.TutorialManager then
		_G.TutorialManager.onCandyPickedUp(player)
	else
	end
	
	if not (candy and candy.Parent) then
		return
	end

	local candyType = candy:FindFirstChild("CandyType")
	if not candyType then
		return
	end
	
	-- Vérifier le propriétaire du bonbon
	local candyOwner = candy:FindFirstChild("CandyOwner")
	if candyOwner and candyOwner:IsA("IntValue") then
		-- Si le bonbon a un propriétaire marqué, vérifier que c'est le bon joueur
		if candyOwner.Value ~= player.UserId then
			-- Le bonbon appartient à un autre joueur, refuser le ramassage
			return
		end
	end

	local success, err = pcall(function()
		
		local playerData = player:FindFirstChild("PlayerData")
		if not playerData then
			return
		end

		local sacBonbons = playerData:FindFirstChild("SacBonbons")
		if not sacBonbons then
			return
		end

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
			
			-- 🎓 TUTORIAL: Signaler le ramassage au tutoriel
			
			if _G.TutorialManager then
				if _G.TutorialManager.isPlayerInTutorial then
					local inTutorial = _G.TutorialManager.isPlayerInTutorial(player)
					if inTutorial and _G.TutorialManager.getTutorialStep then
						local currentStep = _G.TutorialManager.getTutorialStep(player)
					end
				end
				
				if _G.TutorialManager.onCandyPickedUp then
					_G.TutorialManager.onCandyPickedUp(player)
				else
				end
			else
			end
			
			-- Notifier le client (pour détection tutoriel côté client aussi)
			local pickupEvent = ReplicatedStorage:FindFirstChild("PickupCandyEvent")
            if pickupEvent then
                pickupEvent:FireClient(player)
            end

            -- Marquer la recette correspondante comme découverte si pas déjà fait
            do
                local pd = player:FindFirstChild("PlayerData")
                if pd then
                    local rf = pd:FindFirstChild("RecettesDecouvertes")
                    if not rf then
                        rf = Instance.new("Folder")
                        rf.Name = "RecettesDecouvertes"
                        rf.Parent = pd
                    end
                    local recipeName = candyType.Value
                    if recipeName and recipeName ~= "" and not rf:FindFirstChild(recipeName) then
                        local discovered = Instance.new("BoolValue")
                        discovered.Name = recipeName
                        discovered.Value = true
                        discovered.Parent = rf
                    end
                end
            end
		else
		end
	end)

	if not success then
	end
end)


-------------------------------------------------
-- FIN DE PRODUCTION IMMÉDIATE (Robux)
-------------------------------------------------
local function finishCraftingNow(player, incID)
    if not incubators[incID] then return end
    -- Autoriser uniquement le propriétaire de l'incubateur
    local owner = getOwnerPlayerFromIncID(incID)
    if owner ~= player then
        return
    end
    local data = incubators[incID]
    local craft = data.crafting
    if not craft then return end

    local inc = getIncubatorByID(incID)
    if not inc then return end

    -- Préparer définitions et bonus comme dans la boucle serveur
    local recipeName = craft.recipe
    local def = craft.def
    local modifiedDef, _ = applyEventBonuses(def, incID, recipeName)
    local craftOwner = owner
    local doDouble = false
    if craftOwner then
        local pd = craftOwner:FindFirstChild("PlayerData")
        local su = pd and pd:FindFirstChild("ShopUnlocks")
        local epi = su and su:FindFirstChild("EssenceEpique")
        doDouble = (epi and epi.Value == true)
    end

    -- Consommer les ingrédients restants par step comme dans la boucle
    local function canonize(s)
        s = tostring(s or ""):lower():gsub("[^%w]", "")
        return s
    end

    while craft.produced < (craft.quantity or 0) do
        -- Décrémenter inputLeft
        if craft.inputLeft and craft.inputOrder and #craft.inputOrder > 0 then
            for _, ingName in ipairs(craft.inputOrder) do
                local need = (def.ingredients and def.ingredients[ingName]) or 0
                if need > 0 and craft.inputLeft[ingName] and craft.inputLeft[ingName] > 0 then
                    local toConsume = math.min(need, craft.inputLeft[ingName])
                    craft.inputLeft[ingName] -= toConsume
                end
            end
        end
        -- Décrémenter le slotMap visuel
        if craft.slotMap and craft.ingredientsPerCandy then
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

        -- Spawn du bonbon (et double spawn si passif épique)
        spawnCandy(modifiedDef, inc, recipeName, craftOwner)
        if doDouble then
            spawnCandy(modifiedDef, inc, recipeName, craftOwner)
        end

        craft.produced += 1
    end

    -- Restituer les ingrédients restants (extras non consommés)
    do
        local ownerPlr = getOwnerPlayerFromIncID(incID)
        if ownerPlr and craft.slotMap then
            for i = 1, 5 do
                local si = craft.slotMap[i]
                if si and si.ingredient and (tonumber(si.remaining) or 0) > 0 then
                    for _ = 1, math.floor(si.remaining) do
                        returnIngredient(ownerPlr, si.ingredient)
                    end
                    si.remaining = 0
                end
            end
        end
    end

    -- Finaliser comme en fin de boucle
    data.crafting = nil
    updateIncubatorVisual(incID)
    pcall(function()
        local incModel2 = getIncubatorByID(incID)
        if incModel2 then setSmokeEnabled(incModel2, false) end
    end)
    -- Cacher la barre de progression côté propriétaire
    local craftProgressEvt2 = ReplicatedStorage:FindFirstChild("IncubatorCraftProgress")
    if craftProgressEvt2 and craftProgressEvt2:IsA("RemoteEvent") then
        craftProgressEvt2:FireClient(owner, incID, nil, nil, 0, 0, 0)
    end
end

-- Exposer pour que le module d'achats puisse l'appeler
_G.IncubatorFinishNow = finishCraftingNow


-- 🍬 NOUVEAU: Fonction pour restaurer les bonbons sur le sol après reconnexion
local function restoreGroundCandies(player, candiesData)
    if not player or not candiesData or #candiesData == 0 then 
        print("⚠️ [INCUBATOR] Aucun bonbon à restaurer")
        return 
    end
    
    print("🍬 [INCUBATOR] Restauration de", #candiesData, "bonbons pour", player.Name)
    
    -- 🎯 Attendre que l'île du joueur soit chargée
    print("⏳ [INCUBATOR] Attente du chargement de l'île...")
    task.wait(5) -- Attendre 5 secondes pour que l'île se charge
    
    -- 🎯 Trouver un point de spawn sécurisé (incubateur du joueur)
    local spawnPosition = nil
    local playerIsland = nil
    
    -- Chercher l'île du joueur avec plusieurs tentatives
    local maxAttempts = 10
    for attempt = 1, maxAttempts do
        print("🔍 [INCUBATOR] Recherche de l'île (tentative", attempt, "/", maxAttempts, ")")
        
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == "Ile_" .. player.Name or obj.Name:match("^Ile_Slot_")) then
                if obj.Name:match("^Ile_Slot_") then
                    local slotNum = obj.Name:match("Slot_(%d+)")
                    local playerSlot = player:GetAttribute("IslandSlot")
                    if slotNum and playerSlot and tonumber(slotNum) == playerSlot then
                        playerIsland = obj
                        break
                    end
                else
                    playerIsland = obj
                    break
                end
            end
        end
        
        if playerIsland then
            print("✅ [INCUBATOR] Île trouvée:", playerIsland.Name)
            break
        else
            print("⚠️ [INCUBATOR] Île non trouvée, nouvelle tentative dans 1 seconde...")
            task.wait(1)
        end
    end
    
    -- 🎯 Créer une map incubatorID → spawnPoint
    local incubatorSpawnMap = {}
    local spawnPoints = {}
    
    if playerIsland then
        print("🔍 [INCUBATOR] Construction de la map incubateur → spawn point...")
        
        -- Parcourir toutes les parcelles (Parcel_1, Parcel_2, Parcel_3)
        for _, parcel in ipairs(playerIsland:GetChildren()) do
            if parcel:IsA("Model") and parcel.Name:match("^Parcel_") then
                print("  📦 Parcelle trouvée:", parcel.Name)
                
                -- Chercher le ParcelID dans cette parcelle
                local parcelID = nil
                for _, obj in ipairs(parcel:GetDescendants()) do
                    if obj:IsA("StringValue") and obj.Name == "ParcelID" then
                        parcelID = obj.Value
                        print("    🆔 ParcelID trouvé:", parcelID)
                        break
                    end
                end
                
                -- Chercher le SpawnCandyAtReconnexion dans cette parcelle
                local spawnPoint = parcel:FindFirstChild("SpawnCandyAtReconnexion", true)
                if spawnPoint and spawnPoint:IsA("BasePart") then
                    local spawnPos = spawnPoint.Position
                    table.insert(spawnPoints, spawnPos)
                    print("    ✅ SpawnCandyAtReconnexion trouvé à:", spawnPos)
                    
                    -- Associer ce spawn point à l'incubateur
                    if parcelID then
                        incubatorSpawnMap[parcelID] = spawnPos
                        print("    🔗 Associé:", parcelID, "→", spawnPos)
                    end
                end
            end
        end
        
        print("✅ [INCUBATOR] Map construite:", #spawnPoints, "spawn points trouvés")
        
        -- Position de spawn par défaut
        if #spawnPoints > 0 then
            spawnPosition = spawnPoints[1]
            print("✅ [INCUBATOR] Spawn par défaut:", spawnPosition)
        else
            local cf, size = playerIsland:GetBoundingBox()
            spawnPosition = cf.Position + Vector3.new(0, size.Y/2 + 2, 0)
            print("⚠️ [INCUBATOR] Aucun spawn point, utilisation centre île:", spawnPosition)
        end
    end
    
    -- Fonction pour trouver le spawn point d'un incubateur spécifique
    local function findSpawnPointForIncubator(incubatorID)
        if not incubatorID then return nil end
        
        local spawnPos = incubatorSpawnMap[incubatorID]
        if spawnPos then
            print("✅ [INCUBATOR] Spawn point trouvé pour", incubatorID, ":", spawnPos)
            return spawnPos
        else
            print("⚠️ [INCUBATOR] Pas de spawn point pour", incubatorID, ", utilisation par défaut")
            return nil
        end
    end
    
    -- Fallback: utiliser la position du personnage
    if not spawnPosition and player.Character then
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            spawnPosition = hrp.Position + Vector3.new(0, 5, 10)
            print("⚠️ [INCUBATOR] Utilisation position joueur comme fallback:", spawnPosition)
        end
    end
    
    -- Si toujours pas de position, utiliser une position par défaut
    if not spawnPosition then
        spawnPosition = Vector3.new(0, 50, 0)
        warn("⚠️ [INCUBATOR] Aucun point de spawn trouvé, utilisation position par défaut")
    end
    
    local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
    local restoredCount = 0
    
    for i, candyData in ipairs(candiesData) do
        print("🔄 [INCUBATOR] Traitement bonbon", i, "/", #candiesData, ":", candyData.candyType)
        
        local recipeDef = RecipeManager.Recettes[candyData.candyType]
        
        if recipeDef and recipeDef.modele then
            print("✅ [INCUBATOR] Recette trouvée:", candyData.candyType, "| Modèle:", recipeDef.modele)
            local folder = ReplicatedStorage:FindFirstChild("CandyModels")
            if folder then
                print("✅ [INCUBATOR] Dossier CandyModels trouvé")
                local template = folder:FindFirstChild(recipeDef.modele)
                if template then
                    print("✅ [INCUBATOR] Template trouvé:", recipeDef.modele)
                    local clone = template:Clone()
                    print("✅ [INCUBATOR] Clone créé")
                    
                    -- Ajouter les tags
                    local candyTag = Instance.new("StringValue")
                    candyTag.Name = "CandyType"
                    candyTag.Value = candyData.candyType
                    candyTag.Parent = clone
                    
                    local ownerTag = Instance.new("IntValue")
                    ownerTag.Name = "CandyOwner"
                    ownerTag.Value = player.UserId
                    ownerTag.Parent = clone
                    
                    -- Restaurer les données de taille si présentes
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
                        
                        -- Appliquer la taille au modèle
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
                    
                    -- Ancrer toutes les parties du bonbon temporairement
                    local partsToUnanchor = {}
                    if clone:IsA("Model") then
                        for _, part in ipairs(clone:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Anchored = true
                                part.CanCollide = false
                                part.CanTouch = false  -- 🔒 Empêcher les autres joueurs de ramasser
                                table.insert(partsToUnanchor, part)
                            end
                        end
                    elseif clone:IsA("BasePart") then
                        clone.Anchored = true
                        clone.CanCollide = false
                        clone.CanTouch = false  -- 🔒 Empêcher les autres joueurs de ramasser
                        table.insert(partsToUnanchor, clone)
                    end
                    
                    -- 🎯 Trouver le point de spawn spécifique pour ce bonbon
                    local candySpawnPos = spawnPosition -- Position par défaut
                    
                    if candyData.sourceIncubatorID then
                        print("🔍 [INCUBATOR] Recherche spawn point pour incubateur:", candyData.sourceIncubatorID)
                        local specificSpawn = findSpawnPointForIncubator(candyData.sourceIncubatorID)
                        if specificSpawn then
                            candySpawnPos = specificSpawn
                            print("✅ [INCUBATOR] Spawn point spécifique trouvé:", candySpawnPos)
                        else
                            print("⚠️ [INCUBATOR] Spawn point spécifique non trouvé, utilisation position par défaut")
                        end
                    else
                        print("ℹ️ [INCUBATOR] Pas de sourceIncubatorID, utilisation position par défaut")
                    end
                    
                    -- Positionner le bonbon autour du point de spawn
                    print("🔧 [INCUBATOR] Ajout du bonbon au workspace...")
                    clone.Parent = workspace
                    print("✅ [INCUBATOR] Bonbon ajouté au workspace")
                    
                    -- Créer une position aléatoire autour du point de spawn (plus proche)
                    local angle = math.random() * math.pi * 2
                    local radius = math.random(1, 4) -- Entre 1 et 4 studs du centre (plus compact)
                    local offsetX = math.cos(angle) * radius
                    local offsetZ = math.sin(angle) * radius
                    local targetPos = candySpawnPos + Vector3.new(offsetX, 0, offsetZ)
                    
                    print("🔧 [INCUBATOR] Positionnement à:", targetPos)
                    
                    if clone:IsA("Model") then
                        print("🔧 [INCUBATOR] Type: Model, utilisation de PivotTo")
                        clone:PivotTo(CFrame.new(targetPos))
                    elseif clone:IsA("BasePart") then
                        print("🔧 [INCUBATOR] Type: BasePart, utilisation de Position")
                        clone.Position = targetPos
                    end
                    
                    -- Désancrer après 1 seconde (moins de temps = moins de chute)
                    task.delay(1, function()
                        for _, part in ipairs(partsToUnanchor) do
                            if part and part.Parent then
                                part.Anchored = false
                                part.CanCollide = true
                            end
                        end
                    end)
                    
                    restoredCount = restoredCount + 1
                    print("✅ [INCUBATOR] Bonbon #" .. restoredCount .. " restauré:", candyData.candyType, "à", candyData.position[1], candyData.position[2], candyData.position[3])
                    
                    -- Vérifier que le bonbon est bien dans le workspace
                    if clone.Parent == workspace then
                        print("✅ [INCUBATOR] Bonbon confirmé dans workspace")
                    else
                        warn("❌ [INCUBATOR] Bonbon PAS dans workspace! Parent:", clone.Parent)
                    end
                else
                    warn("❌ [INCUBATOR] Template introuvable pour:", recipeDef.modele)
                end
            else
                warn("❌ [INCUBATOR] Dossier CandyModels introuvable")
            end
        else
            warn("❌ [INCUBATOR] Recette introuvable pour:", candyData.candyType)
        end
    end
    
    print("🏁 [INCUBATOR] Restauration terminée:", restoredCount, "/", #candiesData, "bonbons pour", player.Name)
end

-- Exposer la fonction pour SaveDataManager
_G.Incubator = _G.Incubator or {}
_G.Incubator.restoreGroundCandies = restoreGroundCandies


-- 💰 Système d'achat d'incubateur avec argent
local unlockIncubatorMoneyEvt = ReplicatedStorage:FindFirstChild("RequestUnlockIncubatorMoney")
if not unlockIncubatorMoneyEvt then
	unlockIncubatorMoneyEvt = Instance.new("RemoteEvent")
	unlockIncubatorMoneyEvt.Name = "RequestUnlockIncubatorMoney"
	unlockIncubatorMoneyEvt.Parent = ReplicatedStorage
end

local unlockPurchasedEvt = ReplicatedStorage:FindFirstChild("UnlockIncubatorPurchased")
if not unlockPurchasedEvt then
	unlockPurchasedEvt = Instance.new("RemoteEvent")
	unlockPurchasedEvt.Name = "UnlockIncubatorPurchased"
	unlockPurchasedEvt.Parent = ReplicatedStorage
end

-- Prix des incubateurs
local INCUBATOR_PRICES = {
	[2] = 100000000000,      -- 100B pour le 2ème
	[3] = 1000000000000,     -- 1T pour le 3ème
}

unlockIncubatorMoneyEvt.OnServerEvent:Connect(function(player, incubatorIndex)
	if not player or not incubatorIndex then return end
	
	local pd = player:FindFirstChild("PlayerData")
	if not pd then return end
	
	local iu = pd:FindFirstChild("IncubatorsUnlocked")
	if not iu then return end
	
	-- Vérifier que c'est le prochain incubateur à débloquer
	if incubatorIndex ~= iu.Value + 1 then
		warn("⚠️ [INCUBATOR] Tentative de débloquer l'incubateur", incubatorIndex, "mais seulement", iu.Value, "débloqués")
		return
	end
	
	-- Vérifier le prix
	local price = INCUBATOR_PRICES[incubatorIndex]
	if not price then
		warn("⚠️ [INCUBATOR] Prix non défini pour l'incubateur", incubatorIndex)
		return
	end
	
	-- Vérifier l'argent via GameManager
	if _G.GameManager and _G.GameManager.getArgent and _G.GameManager.retirerArgent then
		local currentMoney = _G.GameManager.getArgent(player)
		if currentMoney < price then
			warn("⚠️ [INCUBATOR] Pas assez d'argent:", currentMoney, "< ", price)
			return
		end
		
		-- Retirer l'argent
		local success = _G.GameManager.retirerArgent(player, price)
		if not success then
			warn("❌ [INCUBATOR] Échec du retrait d'argent")
			return
		end
		
		-- Débloquer l'incubateur
		iu.Value = incubatorIndex
		print("✅ [INCUBATOR] Incubateur", incubatorIndex, "débloqué pour", player.Name, "| Prix:", price)
		
		-- Notifier le client
		unlockPurchasedEvt:FireClient(player, incubatorIndex)
	else
		warn("⚠️ [INCUBATOR] GameManager non disponible")
	end
end)

print("✅ [INCUBATOR] Système d'achat d'incubateur initialisé")

-- 🧹 Nettoyage à la déconnexion : arrêter la production visuelle
game:GetService("Players").PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- Arrêter la production visuelle pour tous les incubateurs du joueur
	for incID, data in pairs(incubators) do
		if data.ownerUserId == userId then
			-- Arrêter le thread de production
			if data.crafting and data.crafting.thread then
				pcall(function()
					task.cancel(data.crafting.thread)
				end)
				data.crafting.thread = nil
			end
			
			-- Désactiver la fumée
			if setSmokeEnabled then
				pcall(function()
					setSmokeEnabled(incID, false)
				end)
			end
		end
	end
end)
