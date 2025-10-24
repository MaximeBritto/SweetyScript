-- IncubatorMenuClient.lua v4.0 - Système de slots avec crafting automatique
-- Interface Incubateur avec 4 slots d'entrée + 1 slot de sortie

----------------------------------------------------------------------
-- SERVICES & MODULES
----------------------------------------------------------------------
local plr = game:GetService("Players").LocalPlayer
local rep = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")


-- RemoteEvents avec gestion d'erreurs

local openEvt = rep:WaitForChild("OpenIncubatorMenu")

for _, child in pairs(rep:GetChildren()) do
end

-- Création ou récupération des RemoteEvents avec fallback sécurisé
local function getOrCreateRemoteEvent(name)
	local existing = rep:FindFirstChild(name)
	if not existing then
		local newEvent = Instance.new("RemoteEvent")
		newEvent.Name = name
		newEvent.Parent = rep
		return newEvent
	end
	return existing
end

local function getOrCreateRemoteFunction(name)
	local existing = rep:FindFirstChild(name)
	if not existing then
		local newFunction = Instance.new("RemoteFunction")
		newFunction.Name = name
		newFunction.Parent = rep
		return newFunction
	end
	return existing
end

local placeIngredientEvt = getOrCreateRemoteEvent("PlaceIngredientInSlot")
print("✅ PlaceIngredientInSlot disponible")

local removeIngredientEvt = getOrCreateRemoteEvent("RemoveIngredientFromSlot")
print("✅ RemoveIngredientFromSlot disponible")

local startCraftingEvt = getOrCreateRemoteEvent("StartCrafting")

-- IMPORTANT: n'utilise pas de création côté client pour éviter les sessions KO
local _getSlotsEvt = rep:WaitForChild("GetIncubatorSlots")
local _getStateEvt = rep:WaitForChild("GetIncubatorState")

local craftProgressEvt = getOrCreateRemoteEvent("IncubatorCraftProgress")

local _stopCraftingEvt = getOrCreateRemoteEvent("StopCrafting")
local _finishNowEvt = getOrCreateRemoteEvent("RequestFinishCrafting")
local _finishPurchasedEvt = rep:WaitForChild("FinishCraftingPurchased")
local _unlockPurchasedEvt = rep:WaitForChild("UnlockIncubatorPurchased")

local guiParent = plr:WaitForChild("PlayerGui")


-- Fermer l'UI après achat réussi (Robux)
if _finishPurchasedEvt then
    _finishPurchasedEvt.OnClientEvent:Connect(function()
        if gui then gui.Enabled = false end
        isMenuOpen = false
        currentIncID = nil
        currentRecipe = nil
    end)
end
if _unlockPurchasedEvt then
    _unlockPurchasedEvt.OnClientEvent:Connect(function()
        if gui then gui.Enabled = false end
        isMenuOpen = false
        currentIncID = nil
        currentRecipe = nil
    end)
end

----------------------------------------------------------------------
-- VARIABLES GLOBALES
----------------------------------------------------------------------
local NUM_INPUT_SLOTS = 4
local gui = nil
local currentIncID = nil
local slots = {nil, nil, nil, nil} -- 4 slots d'entrée
local currentRecipe = nil
local isMenuOpen = false
local isCraftingActive = false

----------------------------------------------------------------------
-- FONCTIONS UTILITAIRES
----------------------------------------------------------------------

-- Variables pour le drag and drop (style Minecraft)
local draggedItem = nil
local dragFrame = nil
local cursorFollowConnection = nil
local quantitySelectorOverlay = nil

-- Double-clic désactivé

-- Déclarations forward des fonctions
local updateOutputSlot = nil
local updateOutputViewport = nil
local showQuantitySelector = nil
-- Accès direct au RecipeManager côté client pour les mappages 'modele'
local RecipeManagerClient = nil
do
	local m = rep:FindFirstChild("RecipeManager")
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then RecipeManagerClient = mod end
	end
end

-- UIUtils pour reproduire EXACTEMENT le cadrage/zoom du Pokédex
local UIUtils = nil
do
    local m = rep:FindFirstChild("UIUtils")
    if m and m:IsA("ModuleScript") then
        local ok, mod = pcall(require, m)
        if ok then UIUtils = mod end
    end
end

-- Helpers pour touches modificatrices
local function isShiftDown()
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function isCtrlDown()
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

local function getAvailableIngredients()
	-- Récupère les ingrédients disponibles dans l'inventaire du joueur
	-- FILTRE LES BONBONS : ne montre que les outils qui ne sont PAS des bonbons
	-- SOUSTRAIT les ingrédients déjà placés dans les slots de l'incubateur
	local ingredients = {}
	local backpack = plr:FindFirstChildOfClass("Backpack")
	local character = plr.Character

	-- Vérifier les outils équipés
	if character then
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				-- FILTRER LES BONBONS : ne pas inclure les outils avec IsCandy = true
				local isCandy = tool:GetAttribute("IsCandy")
				if not isCandy then  -- Seulement si ce N'EST PAS un bonbon
					local baseName = tool:GetAttribute("BaseName")
					if baseName then
						local count = tool:FindFirstChild("Count")
						if count and count.Value > 0 then
							ingredients[baseName] = (ingredients[baseName] or 0) + count.Value
						end
					end
				end
			end
		end
	end

	-- Vérifier le sac
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				-- FILTRER LES BONBONS : ne pas inclure les outils avec IsCandy = true
				local isCandy = tool:GetAttribute("IsCandy")
				if not isCandy then  -- Seulement si ce N'EST PAS un bonbon
					local baseName = tool:GetAttribute("BaseName")
					if baseName then
						local count = tool:FindFirstChild("Count")
						if count and count.Value > 0 then
							ingredients[baseName] = (ingredients[baseName] or 0) + count.Value
						end
					end
				end
			end
		end
	end

    -- IMPORTANT: Ne pas soustraire les slots ici
    -- Les ingrédients placés dans les slots sont déjà consommés du backpack côté serveur.
    -- Soustraire à nouveau provoquerait une double déduction visible dans l'UI (ex: 30 → poser 1 → 27).

	return ingredients
end

-- Construit un modèle 3D pour un ingrédient (à afficher dans ViewportFrame)
local function buildIngredientModelForViewport(ingredientName: string)
	local rep = game:GetService("ReplicatedStorage")
	local tools = rep:FindFirstChild("IngredientTools")
	local models = rep:FindFirstChild("IngredientModels")
	local tpl = tools and tools:FindFirstChild(ingredientName)
	if not tpl and models then
		tpl = models:FindFirstChild(ingredientName)
	end
	if not tpl and RecipeManagerClient and RecipeManagerClient.Ingredients then
		local def = RecipeManagerClient.Ingredients[ingredientName]
		if def and def.modele and (tools or models) then
			tpl = (tools and tools:FindFirstChild(def.modele)) or (models and models:FindFirstChild(def.modele))
		end
	end
	-- Recherche élargie (insensible à la casse) dans tout ReplicatedStorage
	if not tpl then
		local target = string.lower(ingredientName)
		for _, obj in ipairs(rep:GetDescendants()) do
			if obj:IsA("Tool") or obj:IsA("Model") then
				local nameOk = string.lower(obj.Name) == target
				local baseOk = false
				pcall(function()
					local v = obj:GetAttribute("BaseName")
					if v and string.lower(tostring(v)) == target then baseOk = true end
				end)
				if nameOk or baseOk then
					tpl = obj
					break
				end
			end
		end
	end
	if not tpl then return nil end
	local worldModel = Instance.new("WorldModel")
	local visualRoot: Instance = nil

	if tpl:IsA("Tool") then
		-- Priorité au Handle (comme la hotbar)
		local handle = tpl:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local partClone = handle:Clone()
			partClone.Anchored = true
			partClone.CanCollide = false
			partClone.CFrame = CFrame.new(0, 0, 0)
			partClone.Parent = worldModel
			visualRoot = partClone
		else
			-- Fallback: cloner le premier BasePart du Tool
			local firstPart = tpl:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				local p2 = firstPart:Clone()
				p2.Anchored = true
				p2.CanCollide = false
				p2.CFrame = CFrame.new(0, 0, 0)
				p2.Parent = worldModel
				visualRoot = p2
			end
		end
	elseif tpl:IsA("Model") then
		-- Cloner uniquement la pièce principale probable
		local base = tpl.PrimaryPart or tpl:FindFirstChild("Handle") or tpl:FindFirstChildWhichIsA("BasePart", true)
		if base and base:IsA("BasePart") then
			local partClone = base:Clone()
			partClone.Anchored = true
			partClone.CanCollide = false
			partClone.CFrame = CFrame.new(0, 0, 0)
			partClone.Parent = worldModel
			visualRoot = partClone
		else
			-- En dernier recours, cloner l'ensemble
			local m = tpl:Clone()
			m.Parent = worldModel
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
			end
			visualRoot = m
		end
	else
		-- Autre type: tenter de cloner directement si BasePart
		if tpl:IsA("BasePart") then
			local p = tpl:Clone()
			p.Anchored = true
			p.CanCollide = false
			p.CFrame = CFrame.new(0, 0, 0)
			p.Parent = worldModel
			visualRoot = p
		end
	end

	if not visualRoot then return nil end
	return worldModel, visualRoot
end

-- Taille robuste pour Model ou BasePart
local function getObjectSizeForViewport(obj: Instance)
	if not obj then return Vector3.new(1,1,1) end
	if obj:IsA("Model") then
		local _, s = obj:GetBoundingBox()
		return s
	elseif obj:IsA("BasePart") then
		return obj.Size
	end
	return Vector3.new(1,1,1)
end

-- Gestion des spinners (rotation dans viewport)
local viewportSpinners = {}
local viewportAngles = {}
local function stopViewportSpinner(viewport)
	local conn = viewportSpinners[viewport]
	if conn then
		conn:Disconnect()
		viewportSpinners[viewport] = nil
	end
end
local function startViewportSpinner(viewport: ViewportFrame, rootInstance: Instance)
	-- Conserver l'angle précédent si on relance souvent
	local startAngle = viewportAngles[viewport] or 0
	stopViewportSpinner(viewport)
	if not viewport or not rootInstance then return end
	local isModel = rootInstance:IsA("Model")
	local baseCFrame
	if rootInstance:IsA("BasePart") then
		baseCFrame = rootInstance.CFrame
	elseif isModel then
		baseCFrame = CFrame.new(0,0,0)
	else
		return
	end
	local angle = startAngle
	local conn = RunService.RenderStepped:Connect(function(dt)
		angle += dt * 1.2 -- vitesse
		viewportAngles[viewport] = angle
		if isModel then
			for _, p in ipairs(rootInstance:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CFrame = p.CFrame * CFrame.Angles(0, dt * 1.2, 0)
				end
			end
		else
			local bp = rootInstance :: BasePart
			bp.CFrame = baseCFrame * CFrame.Angles(0, angle, 0)
		end
	end)
	viewportSpinners[viewport] = conn
	viewport.AncestryChanged:Connect(function()
		if not viewport:IsDescendantOf(game) then
			stopViewportSpinner(viewport)
		end
	end)
end

-- Active/désactive le mode "production en cours" : cache les slots et affiche un GROS bouton STOP
local function setProductionUIActive(active: boolean)
    isCraftingActive = active == true
    if not gui then return end
    local mainFrame = gui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    local craftingArea = mainFrame:FindFirstChild("CraftingArea")
    if not craftingArea then return end

    local inputContainer = craftingArea:FindFirstChild("InputContainer")
    if inputContainer then inputContainer.Visible = not isCraftingActive end
    local arrow = craftingArea:FindFirstChild("ArrowLabel")
    if arrow then arrow.Visible = not isCraftingActive end
    local smallStopBtn = craftingArea:FindFirstChild("StopButton", true)
    if smallStopBtn and smallStopBtn:IsA("TextButton") then
        smallStopBtn.Visible = false
    end

    -- Créer l'overlay STOP si besoin
    local stopOverlay = craftingArea:FindFirstChild("StopOverlay")
    if not stopOverlay then
        stopOverlay = Instance.new("Frame")
        stopOverlay.Name = "StopOverlay"
        stopOverlay.Size = UDim2.new(1, 0, 1, 0)
        stopOverlay.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        stopOverlay.BackgroundTransparency = 0.35
        stopOverlay.BorderSizePixel = 0
        stopOverlay.ZIndex = 80
        stopOverlay.Visible = false
        stopOverlay.Parent = craftingArea

        local center = Instance.new("Frame", stopOverlay)
        center.Size = UDim2.new(0, 360, 0, 260)
        center.Position = UDim2.new(0.5, -160, 0.5, -80)
        center.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
        center.BorderSizePixel = 0
        local cc = Instance.new("UICorner", center); cc.CornerRadius = UDim.new(0, 12)
        local cs = Instance.new("UIStroke", center); cs.Thickness = 2; cs.Color = Color3.fromRGB(90, 60, 60)
        center.ZIndex = 120

        local title = Instance.new("TextLabel", center)
        title.Size = UDim2.new(1, -20, 0, 40)
        title.Position = UDim2.new(0, 10, 0, 10)
        title.BackgroundTransparency = 1
        title.Text = "Production in progress"
        title.TextColor3 = Color3.new(1,1,1)
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.ZIndex = 121

        local bigStop = Instance.new("TextButton", center)
        bigStop.Name = "BigStopButton"
        bigStop.Size = UDim2.new(1, -40, 0, 86)
        bigStop.Position = UDim2.new(0, 20, 0, 68)
        bigStop.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
        bigStop.Text = "STOP !"
        bigStop.TextColor3 = Color3.new(1,1,1)
        bigStop.Font = Enum.Font.GothamBlack
        bigStop.TextScaled = true
        local bc = Instance.new("UICorner", bigStop); bc.CornerRadius = UDim.new(0, 10)
        local bs = Instance.new("UIStroke", bigStop); bs.Thickness = 3; bs.Color = Color3.fromRGB(80, 20, 20)
        bigStop.ZIndex = 130

        -- Nouveau bouton: Finir maintenant (Robux)
        local finishBtn = Instance.new("TextButton", center)
        finishBtn.Name = "FinishNowButton"
        finishBtn.Size = UDim2.new(1, -40, 0, 86)
        finishBtn.Position = UDim2.new(0, 20, 0, 164)
        finishBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        finishBtn.Text = "FINIR (R$)"
        finishBtn.TextColor3 = Color3.new(1,1,1)
        finishBtn.Font = Enum.Font.GothamBlack
        finishBtn.TextScaled = true
        local fc = Instance.new("UICorner", finishBtn); fc.CornerRadius = UDim.new(0, 10)
        local fs = Instance.new("UIStroke", finishBtn); fs.Thickness = 3; fs.Color = Color3.fromRGB(90, 60, 20)
        finishBtn.ZIndex = 130

        -- Effets de pulsation
        pcall(function()
            TweenService:Create(bigStop, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundColor3 = Color3.fromRGB(230, 70, 70)}):Play()
        end)
        pcall(function()
            TweenService:Create(finishBtn, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundColor3 = Color3.fromRGB(255, 220, 90)}):Play()
        end)

        bigStop.MouseButton1Click:Connect(function()
            if _stopCraftingEvt then
                bigStop.Active = false; bigStop.AutoButtonColor = false
                bigStop.Text = "..."
                -- Cacher immédiatement la barre de progression au-dessus de l'incubateur (BillboardGui)
                pcall(function()
                    if currentIncID then
                        local incModel = nil
                        for _, p in ipairs(workspace:GetDescendants()) do
                            if p:IsA("StringValue") and p.Name == "ParcelID" and p.Value == currentIncID then
                                local part = p.Parent
                                if part then incModel = part:FindFirstAncestorOfClass("Model") end
                                break
                            end
                        end
                        if incModel then
                            local bb = incModel:FindFirstChild("IncubatorProgress")
                            if bb and bb:IsA("BillboardGui") then bb.Enabled = false end
                        end
                    end
                end)
                _stopCraftingEvt:FireServer(currentIncID)
                task.delay(0.25, function()
                    -- Désactiver le mode prod et rafraîchir les slots depuis le serveur
                    setProductionUIActive(false)
                    -- Retirer immédiatement tout fond sombre
                    stopOverlay.Visible = false
                    local craftLock = craftingArea:FindFirstChild("CraftLockOverlay")
                    if craftLock then craftLock.Visible = false end
                    local ok, resp = pcall(function()
                        return _getSlotsEvt:InvokeServer(currentIncID)
                    end)
                    if ok and resp and resp.slots then
                        slots = { resp.slots[1], resp.slots[2], resp.slots[3], resp.slots[4] }
                    else
                        slots = {nil, nil, nil, nil}
                    end
                    updateSlotDisplay()
                    updateOutputSlot()
                    updateInventoryDisplay()
                    bigStop.Active = true; bigStop.AutoButtonColor = true
                    bigStop.Text = "STOP !"
                end)
            end
        end)

        finishBtn.MouseButton1Click:Connect(function()
            if _finishNowEvt and currentIncID then
                _finishNowEvt:FireServer(currentIncID)
            end
        end)
    end

    stopOverlay.Visible = isCraftingActive
end

-- Fonction pour créer un élément d'inventaire (style Minecraft) - Responsive
local function createInventoryItem(parent, ingredientName, quantity, isMobile, textSizeMultiplier, cornerRadius)
	-- Paramètres par défaut pour la rétrocompatibilité
	isMobile = isMobile or false
	textSizeMultiplier = textSizeMultiplier or 1
	cornerRadius = cornerRadius or 8

	local ingredientIcons = {
		Sucre = "🍬",
		Sirop = "🍯",
		Lait = "🥛",
		Fraise = "🍓",
		Vanille = "🍦",
		Chocolat = "🍫",
		Noisette = "🌰"
	}

	-- Taille responsive
	local itemWidth = isMobile and 60 or 90
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "InventoryItem_" .. ingredientName
	itemFrame.Size = UDim2.new(0, itemWidth, 1, isMobile and -5 or -10)
	itemFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	itemFrame.BorderSizePixel = 0
	itemFrame.Parent = parent

	local itemCorner = Instance.new("UICorner", itemFrame)
	itemCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 3))
	local itemStroke = Instance.new("UIStroke", itemFrame)
	itemStroke.Color = Color3.fromRGB(87, 60, 34)
	itemStroke.Thickness = math.max(1, math.floor(2 * textSizeMultiplier))

	-- Zone d'icône 3D (ViewportFrame)
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.new(1, 0, 0.6, 0)
	iconBox.Position = UDim2.new(0, 0, 0, 0)
	iconBox.BackgroundTransparency = 1
	iconBox.Parent = itemFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightDirection = Vector3.new(0, -1, -0.5)
	viewport.Parent = iconBox

	-- Construire le modèle 3D pour l'inventaire
	do
		viewport:ClearAllChildren()
		local worldModel, model = buildIngredientModelForViewport(ingredientName)
		if worldModel and model then
			worldModel.Parent = viewport
			local cam = Instance.new("Camera")
			cam.FieldOfView = 40
			cam.Parent = viewport
			viewport.CurrentCamera = cam
			-- NORMALISATION : Taille visuelle uniforme pour tous les ingrédients
			local size = getObjectSizeForViewport(model)
			local maxDim = math.max(size.X, size.Y, size.Z)
			if maxDim == 0 then maxDim = 1 end
			-- Taille cible normalisée : tous les objets rempliront ~70% du viewport
			local targetSize = 2.0  -- Taille de référence
			local scaleFactor = maxDim / targetSize
			-- Distance fixe ajustée par le facteur d'échelle pour uniformiser
			local dist = 4.5 * scaleFactor
			cam.CFrame = CFrame.new(Vector3.new(0, maxDim*0.15, dist), Vector3.new(0, 0, 0))
		else
			-- Fallback emoji si modèle introuvable
			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(1, 0, 1, 0)
			iconLabel.BackgroundTransparency = 1
			iconLabel.Text = ingredientIcons[ingredientName] or "📦"
			iconLabel.TextColor3 = Color3.new(1, 1, 1)
			iconLabel.TextSize = math.floor(28 * textSizeMultiplier)
			iconLabel.Font = Enum.Font.GothamBold
			iconLabel.TextScaled = isMobile
			iconLabel.Parent = iconBox
		end
	end

	-- Label du nom et quantité (responsive)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	-- Utiliser le champ 'nom' du RecipeManager si disponible
	local displayName = ingredientName
	if RecipeManagerClient and RecipeManagerClient.Ingredients and RecipeManagerClient.Ingredients[ingredientName] then
		displayName = RecipeManagerClient.Ingredients[ingredientName].nom or ingredientName
	end
	nameLabel.Text = isMobile and (displayName .. "\nx" .. quantity) or (displayName .. "\n" .. quantity)
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = math.floor(12 * textSizeMultiplier)
	nameLabel.Font = Enum.Font.SourceSans
	nameLabel.TextScaled = true  -- Toujours activé
	nameLabel.Parent = itemFrame

	-- Bouton invisible pour les interactions
	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = itemFrame

	-- Variables pour le long press (tactile)
	local longPressActive = false
	local longPressStartTime = 0

	-- Événements style Minecraft
	clickButton.MouseButton1Down:Connect(function()
		-- Démarrer le timer pour le long press (tactile)
		longPressActive = true
		longPressStartTime = tick()
		
		-- Détecter le long press après 0.5 secondes
		task.spawn(function()
			task.wait(0.5)
			if longPressActive then
				-- Long press détecté → ouvrir le sélecteur de quantité
				longPressActive = false
				showQuantitySelector(ingredientName, quantity, function(qty)
					pickupItem(ingredientName, qty)
					highlightEmptySlots(ingredientName)
					task.spawn(function()
						task.wait(3)
						clearSlotHighlights()
					end)
				end)
			end
		end)
	end)

	clickButton.MouseButton1Up:Connect(function()
		-- Si le long press n'a pas été déclenché, traiter comme un clic normal
		local pressDuration = tick() - longPressStartTime
		longPressActive = false
		
		-- Si l'appui était court (< 0.5s), traiter comme un clic normal
		if pressDuration < 0.5 then
			-- Modifieurs: Ctrl = choisir quantité, Shift = moitié, sinon tout
			local ctrl = isCtrlDown()
			local shift = isShiftDown()
			if ctrl then
				showQuantitySelector(ingredientName, quantity, function(qty)
					pickupItem(ingredientName, qty)
					highlightEmptySlots(ingredientName)
					task.spawn(function()
						task.wait(3)
						clearSlotHighlights()
					end)
				end)
				return
			elseif shift then
				local half = math.max(1, math.floor(quantity / 2))
				pickupItem(ingredientName, half)
				highlightEmptySlots(ingredientName)
				task.spawn(function()
					task.wait(3)
					clearSlotHighlights()
				end)
				return
			else
				-- Clic gauche = prendre tout le stack
				pickupItem(ingredientName, quantity)
				-- 💡 Surbrillance des slots vides pour le tutoriel
				highlightEmptySlots(ingredientName)
				-- Effacer la surbrillance après 3 secondes
				task.spawn(function()
					task.wait(3)
					clearSlotHighlights()
				end)
			end
		end
	end)

	clickButton.MouseButton2Click:Connect(function()
		-- Clic droit = prendre un par un
		pickupItem(ingredientName, 1)
	end)

	-- Effet de survol
	clickButton.MouseEnter:Connect(function()
		local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 150, 100)})
		tween:Play()
	end)

	clickButton.MouseLeave:Connect(function()
		local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(184, 133, 88)})
		tween:Play()
	end)

	return itemFrame
end

-- Fonction pour prendre un objet de l'inventaire (style Minecraft)
function pickupItem(ingredientName, quantityToTake)

    -- Si on a déjà un item en main et qu'on clique sur un autre → remplacer (fix miss-click)
    if draggedItem then
        stopCursorFollow()
    end

	-- Vérifier qu'on a assez d'ingrédients
	local availableIngredients = getAvailableIngredients()
	local availableQuantity = availableIngredients[ingredientName] or 0

	if availableQuantity <= 0 then 
		return 
	end

	-- Prendre la quantité demandée (ou ce qui est disponible)
	local actualQuantity = math.min(quantityToTake, availableQuantity)

	-- Créer l'objet en main
	draggedItem = {
		ingredient = ingredientName,
		quantity = actualQuantity
	}

	-- Créer le frame qui suit le curseur
	createCursorItem(ingredientName, actualQuantity)

	-- Démarrer le suivi du curseur
	startCursorFollow()
end

-- Fonction pour créer l'objet qui suit le curseur (responsive)
function createCursorItem(ingredientName, quantity)
	local ingredientIcons = {
		Sucre = "🍬",
		Sirop = "🍯",
		Lait = "🥛",
		Fraise = "🍓",
		Vanille = "🍦",
		Chocolat = "🍫",
		Noisette = "🌰"
	}

	-- Détection de la plateforme pour taille responsive
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
    local _isDesktop = (not isMobile) and (not isSmallScreen) -- réservé pour usage futur
	local textSizeMultiplier = (isMobile or isSmallScreen) and 0.75 or 1

	-- Taille du curseur responsive
	local cursorSize = (isMobile or isSmallScreen) and 44 or 60

    dragFrame = Instance.new("Frame")
	dragFrame.Name = "CursorItem"
	dragFrame.Size = UDim2.new(0, cursorSize, 0, cursorSize)
	dragFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	dragFrame.BorderSizePixel = 0
    dragFrame.ZIndex = 3000
	dragFrame.Parent = gui

	local corner = Instance.new("UICorner", dragFrame)
	corner.CornerRadius = UDim.new(0, math.max(5, math.floor(8 * textSizeMultiplier)))
	local stroke = Instance.new("UIStroke", dragFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = math.max(1, math.floor(2 * textSizeMultiplier))

	-- Viewport 3D de l'objet (comme le Pokédex)
    local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
    viewport.ZIndex = 3001
	viewport.Parent = dragFrame

	local usedViewport = false
	local toolsFolder = rep:FindFirstChild("IngredientTools")
	if toolsFolder then
		local toolTpl = toolsFolder:FindFirstChild(ingredientName)
		if toolTpl and UIUtils and UIUtils.setupViewportFrame then
			local handle = toolTpl:FindFirstChild("Handle")
			if handle then
				UIUtils.setupViewportFrame(viewport, handle)
				usedViewport = true
			end
		end
	end

	-- Fallback icône emoji si pas de modèle 3D
	if not usedViewport then
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 1, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = ingredientIcons[ingredientName] or "📦"
		iconLabel.TextColor3 = Color3.new(1, 1, 1)
		iconLabel.TextSize = math.floor(22 * textSizeMultiplier)
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextScaled = textSizeMultiplier < 1
		iconLabel.Parent = dragFrame
	end

	-- Quantité (responsive)
    local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "QtyLabel"
	quantityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	quantityLabel.Position = UDim2.new(0, 0, 0.7, 0)
	quantityLabel.BackgroundTransparency = 1
	quantityLabel.Text = tostring(quantity)
	quantityLabel.TextColor3 = Color3.new(1, 1, 1)
    quantityLabel.ZIndex = 3002
	quantityLabel.TextSize = math.floor(12 * textSizeMultiplier)
	quantityLabel.Font = Enum.Font.SourceSansBold
	quantityLabel.TextScaled = textSizeMultiplier < 1  -- Auto-resize sur mobile
	quantityLabel.Parent = dragFrame


end

-- Sélecteur de quantité (overlay + slider)
showQuantitySelector = function(ingredientName, maxQuantity, onConfirm)
    if maxQuantity == nil or maxQuantity <= 0 then return end
    if quantitySelectorOverlay and quantitySelectorOverlay.Parent then
        quantitySelectorOverlay:Destroy()
        quantitySelectorOverlay = nil
    end

    if not gui then return end
    local overlay = Instance.new("Frame")
    overlay.Name = "QtySelectorOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 3500
    overlay.Active = true
    overlay.Parent = gui

    local panel = Instance.new("Frame")
    panel.Name = "QtyPanel"
    panel.Size = UDim2.new(0, 320, 0, 160)
    panel.Position = UDim2.new(0.5, -160, 0.5, -80)
    panel.BackgroundColor3 = Color3.fromRGB(60, 44, 28)
    panel.BorderSizePixel = 0
    panel.ZIndex = 3600
    panel.Parent = overlay
    local pc = Instance.new("UICorner", panel); pc.CornerRadius = UDim.new(0, 10)
    local ps = Instance.new("UIStroke", panel); ps.Thickness = 2; ps.Color = Color3.fromRGB(87, 60, 34)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 30)
    title.Position = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Sélection quantité: " .. tostring(ingredientName)
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextScaled = true
    title.ZIndex = 3610
    title.Parent = panel

    local amountLabel = Instance.new("TextLabel")
    amountLabel.Size = UDim2.new(1, -16, 0, 26)
    amountLabel.Position = UDim2.new(0, 8, 0, 48)
    amountLabel.BackgroundTransparency = 1
    amountLabel.Text = "1 / " .. tostring(maxQuantity)
    amountLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
    amountLabel.Font = Enum.Font.Gotham
    amountLabel.TextScaled = true
    amountLabel.ZIndex = 3610
    amountLabel.Parent = panel

    local bar = Instance.new("Frame")
    bar.Name = "SliderBar"
    bar.Size = UDim2.new(1, -40, 0, 16)
    bar.Position = UDim2.new(0, 20, 0, 90)
    bar.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
    bar.BorderSizePixel = 0
    bar.ZIndex = 3610
    bar.Parent = panel
    local bc = Instance.new("UICorner", bar); bc.CornerRadius = UDim.new(0, 8)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Position = UDim2.new(0, 0, 0, 0)
    fill.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    fill.BorderSizePixel = 0
    fill.ZIndex = 3620
    fill.Parent = bar
    local fc = Instance.new("UICorner", fill); fc.CornerRadius = UDim.new(0, 8)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(235, 210, 140)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3630
    knob.Parent = bar
    local kc = Instance.new("UICorner", knob); kc.CornerRadius = UDim.new(1, 0)
    local ks = Instance.new("UIStroke", knob); ks.Thickness = 1; ks.Color = Color3.fromRGB(66, 40, 20)

    local buttons = Instance.new("Frame")
    buttons.Size = UDim2.new(1, -16, 0, 32)
    buttons.Position = UDim2.new(0, 8, 1, -40)
    buttons.BackgroundTransparency = 1
    buttons.ZIndex = 3610
    buttons.Parent = panel

    local okBtn = Instance.new("TextButton")
    okBtn.Size = UDim2.new(0.48, 0, 1, 0)
    okBtn.Position = UDim2.new(0, 0, 0, 0)
    okBtn.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    okBtn.Text = "Valider"
    okBtn.TextColor3 = Color3.new(1,1,1)
    okBtn.Font = Enum.Font.GothamBold
    okBtn.TextScaled = true
    okBtn.ZIndex = 3620
    okBtn.Parent = buttons
    local okc = Instance.new("UICorner", okBtn); okc.CornerRadius = UDim.new(0, 8)

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.48, 0, 1, 0)
    cancelBtn.Position = UDim2.new(0.52, 0, 0, 0)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
    cancelBtn.Text = "Annuler"
    cancelBtn.TextColor3 = Color3.new(1,1,1)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextScaled = true
    cancelBtn.ZIndex = 3620
    cancelBtn.Parent = buttons
    local cc = Instance.new("UICorner", cancelBtn); cc.CornerRadius = UDim.new(0, 8)

    local selected = math.max(1, math.floor(maxQuantity / 2))
    local dragging = false

    local function round(n)
        return math.floor(n + 0.5)
    end

    local function updateUI()
        local pct = (selected / maxQuantity)
        pct = math.clamp(pct, 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        amountLabel.Text = tostring(selected) .. " / " .. tostring(maxQuantity)
    end

    local function setFromMouse()
        local mousePos = UserInputService:GetMouseLocation()
        local barPos = bar.AbsolutePosition
        local barSize = bar.AbsoluteSize
        local relX = math.clamp(mousePos.X - barPos.X, 0, barSize.X)
        local pct = (barSize.X > 0) and (relX / barSize.X) or 0
        selected = math.clamp(round(pct * maxQuantity), 1, maxQuantity)
        updateUI()
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromMouse()
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    overlay.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromMouse()
        end
    end)

    -- Bloquer le drag de la fenêtre principale pendant l'overlay
    local mainFrame = gui:FindFirstChild("MainFrame")
    local wasDraggable = false
    if mainFrame and mainFrame:IsA("Frame") then
        wasDraggable = mainFrame.Draggable
        mainFrame.Draggable = false
    end

    -- Empêcher l'interaction avec l'arrière-plan
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            -- Consommer l'événement pour ne pas scroller derrière
            return
        end
    end)

    local function cleanup()
        if mainFrame and mainFrame:IsA("Frame") then
            mainFrame.Draggable = wasDraggable
        end
        if overlay and overlay.Parent then overlay:Destroy() end
        quantitySelectorOverlay = nil
    end

    okBtn.MouseButton1Click:Connect(function()
        local qty = math.clamp(selected, 1, maxQuantity)
        cleanup()
        if typeof(onConfirm) == "function" then
            onConfirm(qty)
        end
    end)
    cancelBtn.MouseButton1Click:Connect(cleanup)

    quantitySelectorOverlay = overlay
    updateUI()
end

-- Fonction pour démarrer le suivi du curseur (compatible mobile)
function startCursorFollow()
	if cursorFollowConnection then return end

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	cursorFollowConnection = UserInputService.InputChanged:Connect(function(input)
		-- PROTECTION : Si le menu n'est plus ouvert, déconnecter automatiquement
		if not isMenuOpen or not dragFrame then
			if cursorFollowConnection then
				cursorFollowConnection:Disconnect()
				cursorFollowConnection = nil
			end
			return
		end

		if dragFrame then
			-- Support souris ET tactile
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local mousePos = UserInputService:GetMouseLocation()
				local offsetSize = isMobile and 25 or 30  -- Offset plus petit sur mobile
				dragFrame.Position = UDim2.new(0, mousePos.X - offsetSize, 0, mousePos.Y - offsetSize)
			elseif input.UserInputType == Enum.UserInputType.Touch then
				-- Position pour le tactile (position fixe pratique sur mobile)
				dragFrame.Position = UDim2.new(0.5, -25, 0.3, 0)  -- Position fixe pratique sur mobile
			end
		end
	end)

	-- Double-clic désactivé
end

-- Fonction pour arrêter le suivi du curseur
function stopCursorFollow()
	if cursorFollowConnection then
		cursorFollowConnection:Disconnect()
		cursorFollowConnection = nil
	end

	-- Double-clic désactivé

	if dragFrame then
		dragFrame:Destroy()
		dragFrame = nil
	end

	draggedItem = nil
	lastGlobalClickTime = 0
end

-- Fonction pour placer l'objet dans un slot
function placeItemInSlot(slotIndex, placeAll, quantityOverride)

    -- Si production en cours, empêcher toute modification locale et notifier
    if isCraftingActive then
        return
    end

	if not draggedItem then 
		return 
	end

	local quantityToPlace
	if typeof(quantityOverride) == "number" and quantityOverride > 0 then
		quantityToPlace = math.min(quantityOverride, draggedItem.quantity)
	else
		quantityToPlace = placeAll and draggedItem.quantity or 1
	end

	-- IMPORTANT : Sauvegarder les infos AVANT de modifier draggedItem
	local ingredientName = draggedItem.ingredient
	local _originalQuantity = draggedItem.quantity

	-- Envoyer au serveur en une seule fois (quantité agrégée)
	placeIngredientEvt:FireServer(currentIncID, slotIndex, ingredientName, quantityToPlace)

	-- Mettre à jour l'objet en main
	draggedItem.quantity = draggedItem.quantity - quantityToPlace

	if draggedItem.quantity <= 0 then
		-- Plus rien en main
		stopCursorFollow() -- Cette fonction met draggedItem = nil !
	else
		-- Mettre à jour l'affichage
        if dragFrame then
            local qty = dragFrame:FindFirstChild("QtyLabel")
            if qty and qty:IsA("TextLabel") then
                qty.Text = tostring(draggedItem.quantity)
            end
        end
	end

	-- Rafraîchir depuis le serveur pour refléter la réalité (délai un peu augmenté pour laisser répliquer les Count)
	task.wait(0.3)
    local okSlots, resp = pcall(function()
        return _getSlotsEvt:InvokeServer(currentIncID)
    end)
    if okSlots and resp and resp.slots then
        slots = { resp.slots[1], resp.slots[2], resp.slots[3], resp.slots[4] }
    end
    updateSlotDisplay()
    updateOutputSlot()
    updateInventoryDisplay()
end

-- Fonction pour mettre en surbrillance les slots vides (pour le tutoriel)
function highlightEmptySlots(ingredientName)
	if not gui then return end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end

	local craftingArea = mainFrame:FindFirstChild("CraftingArea")
	if not craftingArea then return end

	local inputContainer = craftingArea:FindFirstChild("InputContainer")
	if not inputContainer then return end


	-- Parcourir tous les slots d'entrée
	for i = 1, NUM_INPUT_SLOTS do
		local slot = inputContainer:FindFirstChild("InputSlot" .. i)
		if slot then
			-- Vérifier si le slot est vide
			if not slots[i] then
				-- Slot vide - ajouter la surbrillance
				local highlight = slot:FindFirstChild("TutorialHighlight")
				if not highlight then
					highlight = Instance.new("Frame")
					highlight.Name = "TutorialHighlight"
					highlight.Size = UDim2.new(1, 0, 1, 0)
					highlight.Position = UDim2.new(0, 0, 0, 0)
					highlight.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Or
					highlight.BackgroundTransparency = 0.7
					highlight.BorderSizePixel = 3
					highlight.BorderColor3 = Color3.fromRGB(255, 215, 0)
					highlight.ZIndex = 10
					highlight.Parent = slot

					-- Ajouter des coins arrondis
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 8)
					corner.Parent = highlight

				end
				highlight.Visible = true
			else
				-- Slot occupé - retirer la surbrillance
				local highlight = slot:FindFirstChild("TutorialHighlight")
				if highlight then
					highlight.Visible = false
				end
			end
		end
	end
end

-- Fonction pour retirer toutes les surbrillances
function clearSlotHighlights()
	if not gui then return end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end

	local craftingArea = mainFrame:FindFirstChild("CraftingArea")
	if not craftingArea then return end

	local inputContainer = craftingArea:FindFirstChild("InputContainer")
	if not inputContainer then return end

	for i = 1, NUM_INPUT_SLOTS do
		local slot = inputContainer:FindFirstChild("InputSlot" .. i)
		if slot then
			local highlight = slot:FindFirstChild("TutorialHighlight")
			if highlight then
				highlight.Visible = false
			end
		end
	end

end

-- Fonction pour mettre à jour l'affichage de l'inventaire
function updateInventoryDisplay()
	if not gui then return end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end

	local inventoryArea = mainFrame:FindFirstChild("InventoryArea")
	if not inventoryArea then return end

    local scrollFrame = inventoryArea:FindFirstChild("InventoryScroll") or inventoryArea:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end

	-- Nettoyer l'inventaire existant
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child.Name:match("^InventoryItem_") then
			child:Destroy()
		end
	end

	-- Récupérer les ingrédients disponibles
	local availableIngredients = getAvailableIngredients()

	-- Détection de la plateforme pour les éléments responsifs
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
	local textSizeMultiplier = (isMobile or isSmallScreen) and 0.7 or 1
	local cornerRadius = (isMobile or isSmallScreen) and 10 or 15

	-- Créer les éléments d'interface pour chaque ingrédient (responsive)
	for ingredientName, quantity in pairs(availableIngredients) do
		createInventoryItem(scrollFrame, ingredientName, quantity, isMobile or isSmallScreen, textSizeMultiplier, cornerRadius - 3)
	end
end

local function calculateRecipe()
	-- Calcule la recette localement avec les ingrédients actuels

	if not currentIncID then 
		return nil, nil 
	end

	-- Créer la liste des ingrédients à partir des slots locaux
	local ingredients = {}
	for i = 1, NUM_INPUT_SLOTS do
		local slotData = slots[i]
		if slotData and slotData.ingredient then
			-- NORMALISER EN MINUSCULES comme le serveur
			local ingredientName = slotData.ingredient:lower()
			local quantity = slotData.quantity or 1
			ingredients[ingredientName] = (ingredients[ingredientName] or 0) + quantity
		end
	end


	-- Chercher une recette qui correspond (version simplifiée côté client)
	if RecipeManagerClient and RecipeManagerClient.Recettes then
		for recipeName, recipeData in pairs(RecipeManagerClient.Recettes) do

			if recipeData.ingredients then
				local matches = true
				local canCraft = true

				-- Vérifier si tous les ingrédients requis sont présents
				for requiredIngredient, requiredQuantity in pairs(recipeData.ingredients) do
					local availableQuantity = ingredients[requiredIngredient] or 0

					if availableQuantity < requiredQuantity then
						matches = false
						canCraft = false
						break
					end
				end

				-- Vérifier qu'il n'y a pas d'ingrédients en trop
				if matches then
					for availableIngredient, availableQuantity in pairs(ingredients) do
						if not recipeData.ingredients[availableIngredient] then
							matches = false
							break
						end
					end
				end

				if matches and canCraft then
					-- Calculer combien de fois on peut faire la recette
					local maxCrafts = math.huge
					for requiredIngredient, requiredQuantity in pairs(recipeData.ingredients) do
						local availableQuantity = ingredients[requiredIngredient] or 0
						maxCrafts = math.min(maxCrafts, math.floor(availableQuantity / requiredQuantity))
					end
					return recipeName, recipeData, maxCrafts
				end
			end
		end
	end

	return nil, nil, 0
end

updateOutputSlot = function()
	-- Met à jour le slot de sortie avec la recette calculée

	if not gui then 
		return 
	end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then 
		return 
	end

	-- Le slot de sortie est dans craftingArea, pas directement dans mainFrame
	local craftingArea = mainFrame:FindFirstChild("CraftingArea")
	if not craftingArea then
		return
	end

	local outputSlot = craftingArea:FindFirstChild("OutputSlot")
	if not outputSlot then 
		-- DEBUGg : Lister tous les enfants de CraftingArea
		for _, child in pairs(craftingArea:GetChildren()) do
		end
		return 
	end


	local recipeName, recipeDef, quantity = calculateRecipe()
	currentRecipe = recipeName

	if recipeName and recipeDef and quantity > 0 then
		-- Afficher la recette possible
		outputSlot.BackgroundColor3 = Color3.fromRGB(85, 170, 85) -- Vert = possible
		local recipeLabel = outputSlot:FindFirstChild("RecipeLabel")
		if recipeLabel then
			-- Utiliser recipeDef.nom au lieu de recipeName pour afficher le bon nom
			local displayName = recipeDef.nom or recipeName
			if quantity > 1 then
				recipeLabel.Text = "🍬 " .. quantity .. "x " .. displayName
			else
				recipeLabel.Text = "🍬 " .. displayName
			end
			recipeLabel.TextColor3 = Color3.new(1, 1, 1)
		end

		-- Afficher l'icône si disponible
		local iconFrame = outputSlot:FindFirstChild("IconFrame")
		if iconFrame then
			iconFrame.Visible = true
			iconFrame.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
			-- Rendu 3D dans un ViewportFrame
			local viewport = iconFrame:FindFirstChild("ViewportFrame")
			if not viewport then
				viewport = Instance.new("ViewportFrame")
				viewport.Name = "ViewportFrame"
				viewport.Size = UDim2.new(1, 0, 1, 0)
				viewport.BackgroundTransparency = 1
				viewport.Ambient = Color3.fromRGB(200, 200, 200)
				viewport.LightDirection = Vector3.new(0, -1, -0.5)
				viewport.Parent = iconFrame
			end
			updateOutputViewport(viewport, recipeDef)
		end

		-- Highlight + texte "CLICK !" pour indiquer l'action à faire
		local highlight = outputSlot:FindFirstChild("OutputHighlight")
		if not highlight then
			highlight = Instance.new("UIStroke")
			highlight.Name = "OutputHighlight"
			highlight.Thickness = 4
			highlight.Color = Color3.fromRGB(255, 225, 90)
			highlight.Enabled = true
			highlight.LineJoinMode = Enum.LineJoinMode.Round
			highlight.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			highlight.Parent = outputSlot
		end
		highlight.Enabled = true
		pcall(function()
			TweenService:Create(highlight, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Thickness = 8}):Play()
		end)

		-- Overlay lumineux pulsant (non bloquant)
		local glow = outputSlot:FindFirstChild("OutputGlow")
		if not glow then
			glow = Instance.new("Frame")
			glow.Name = "OutputGlow"
			glow.BackgroundColor3 = Color3.fromRGB(255, 230, 120)
			glow.BackgroundTransparency = 0.5
			glow.BorderSizePixel = 0
			glow.Size = UDim2.new(1.15, 0, 1.15, 0)
			glow.Position = UDim2.new(-0.075, 0, -0.075, 0)
			glow.ZIndex = 50
			glow.Parent = outputSlot
			local c = Instance.new("UICorner", glow)
			c.CornerRadius = UDim.new(0, 12)
		end
		glow.Visible = true
		pcall(function()
			TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.2}):Play()
		end)

		local clickHint = outputSlot:FindFirstChild("ClickHint")
		if not clickHint then
			clickHint = Instance.new("TextLabel")
			clickHint.Name = "ClickHint"
			clickHint.Size = UDim2.new(1.2, 0, 0, 22)
			clickHint.Position = UDim2.new(-0.1, 0, 1, 4)
			clickHint.BackgroundTransparency = 1
			clickHint.Text = "CLICK !"
			clickHint.TextColor3 = Color3.fromRGB(255, 240, 160)
			clickHint.Font = Enum.Font.GothamBlack
			clickHint.TextScaled = true
			clickHint.ZIndex = 60
			clickHint.Parent = outputSlot
			-- Ombre du texte pour lisibilité
			local shadow = Instance.new("TextLabel")
			shadow.Name = "Shadow"
			shadow.Size = UDim2.new(1, 0, 1, 0)
			shadow.Position = UDim2.new(0, 1, 0, 1)
			shadow.BackgroundTransparency = 1
			shadow.Text = "CLICK !"
			shadow.TextColor3 = Color3.fromRGB(0,0,0)
			shadow.TextTransparency = 0.6
			shadow.Font = Enum.Font.GothamBlack
			shadow.TextScaled = true
			shadow.ZIndex = 59
			shadow.Parent = clickHint
		end
		clickHint.Visible = true
		pcall(function()
			TweenService:Create(clickHint, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextTransparency = 0.1}):Play()
		end)


	else
		-- Pas de recette possible
		outputSlot.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron = pas possible
		local recipeLabel = outputSlot:FindFirstChild("RecipeLabel")
		if recipeLabel then
			recipeLabel.Text = "❌ No recipe"
			recipeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end

		local iconFrame = outputSlot:FindFirstChild("IconFrame")
		if iconFrame then
			iconFrame.Visible = false
			local viewport = iconFrame:FindFirstChild("ViewportFrame")
			if viewport then viewport:ClearAllChildren() end
		end

		-- Masquer le highlight et le hint si présents
		local highlight = outputSlot:FindFirstChild("OutputHighlight")
		if highlight then
			highlight.Enabled = false
		end
		local glow = outputSlot:FindFirstChild("OutputGlow")
		if glow then
			glow.Visible = false
		end
		local clickHint = outputSlot:FindFirstChild("ClickHint")
		if clickHint then
			clickHint.Visible = false
		end


	end
end

-- Met à jour la viewport du slot de sortie avec un rendu 3D
updateOutputViewport = function(viewport: ViewportFrame, recipeDef)
    if not viewport then return end
    viewport:ClearAllChildren()
    if not recipeDef or not recipeDef.modele then return end
    local folder = game:GetService("ReplicatedStorage"):FindFirstChild("CandyModels")
    if not folder then return end
    local tpl = folder:FindFirstChild(tostring(recipeDef.modele))
    if not tpl then return end

    -- Reproduire EXACTEMENT le rendu Pokédex: clone → UIUtils.setupViewportFrame(viewport, clone)
    local clone = tpl:Clone()
    if clone:IsA("Tool") then
        local m = Instance.new("Model")
        for _, ch in ipairs(clone:GetChildren()) do ch.Parent = m end
        clone:Destroy()
        clone = m
    end

    if UIUtils and UIUtils.setupViewportFrame then
        UIUtils.setupViewportFrame(viewport, clone)
    else
        -- Fallback minimal si UIUtils indisponible
        local cam = Instance.new("Camera")
        cam.Parent = viewport
        viewport.CurrentCamera = cam
        clone.Parent = viewport
        local cf, sz = clone:GetBoundingBox()
        local radius = sz.Magnitude * 0.5
        local dist = (radius / math.tan(math.rad(40 * 0.5))) * 1.25
        local dir = Vector3.new(1, 0.8, 1).Unit
        cam.FieldOfView = 40
        cam.CFrame = CFrame.new(cf.Position + dir * dist, cf.Position)
    end

    -- Démarrer la rotation comme Pokédex
    startViewportSpinner(viewport, clone)
end

----------------------------------------------------------------------
-- CRÉATION DE L'UI MODERNE AVEC SLOTS
----------------------------------------------------------------------
local function createSlotUI(parent, slotIndex, isOutputSlot, slotSize, textSizeMultiplier, cornerRadius)
	-- Utiliser les valeurs par défaut si non fournies (rétrocompatibilité)
	slotSize = slotSize or 80
	textSizeMultiplier = textSizeMultiplier or 1
	cornerRadius = cornerRadius or 10

	local slot = Instance.new("Frame")
	slot.Name = isOutputSlot and "OutputSlot" or ("InputSlot" .. slotIndex)
	slot.Size = UDim2.new(0, slotSize, 0, slotSize)
	slot.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local corner = Instance.new("UICorner", slot)
	corner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 5))
	local stroke = Instance.new("UIStroke", slot)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = math.max(2, math.floor(3 * textSizeMultiplier))

	-- Zone d'icône pour l'ingrédient (permet de recevoir un ViewportFrame)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconFrame"
	iconFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
	iconFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
	iconFrame.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	iconFrame.BorderSizePixel = 0
	iconFrame.Visible = false
	iconFrame.Parent = slot

	local iconCorner = Instance.new("UICorner", iconFrame)
	iconCorner.CornerRadius = UDim.new(0, 5)

	-- Label optionnel (garde place si pas de viewport)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "IconLabel"
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = ""
	iconLabel.TextColor3 = Color3.new(1, 1, 1)
	iconLabel.TextSize = math.floor(20 * textSizeMultiplier)
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextScaled = textSizeMultiplier < 1
	iconLabel.Parent = iconFrame

	-- Label pour le nom de l'ingrédient/recette (responsive)
	local label = Instance.new("TextLabel")
	label.Name = isOutputSlot and "RecipeLabel" or "IngredientLabel"
	label.Size = UDim2.new(1, 0, 0.3, 0)
	label.Position = UDim2.new(0, 0, 0.7, 0)
	label.BackgroundTransparency = 1
	label.Text = isOutputSlot and "Result" or "Empty"
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = math.floor(12 * textSizeMultiplier)
	label.Font = Enum.Font.SourceSans
	label.TextScaled = true  -- Toujours activé pour le label
	label.Parent = slot

	-- Bouton pour interaction (seulement pour les slots d'entrée)
	if not isOutputSlot then
		local button = Instance.new("TextButton")
		button.Name = "SlotButton"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = slot

		-- Variables pour le long press (tactile)
		local slotLongPressActive = false
		local slotLongPressStartTime = 0

		-- Événements de clic (style Minecraft)
		button.MouseButton1Down:Connect(function()
			-- Démarrer le timer pour le long press (tactile)
			slotLongPressActive = true
			slotLongPressStartTime = tick()
			
			-- Détecter le long press après 0.5 secondes
			task.spawn(function()
				task.wait(0.5)
				if slotLongPressActive and draggedItem then
					-- Long press détecté → ouvrir le sélecteur de quantité
					slotLongPressActive = false
					local maxQty = draggedItem and draggedItem.quantity or 1
					showQuantitySelector(draggedItem.ingredient, maxQty, function(qty)
						placeItemInSlot(slotIndex, false, qty)
					end)
				end
			end)
		end)

		button.MouseButton1Up:Connect(function()
			-- Si le long press n'a pas été déclenché, traiter comme un clic normal
			local pressDuration = tick() - slotLongPressStartTime
			slotLongPressActive = false
			
			-- Si l'appui était court (< 0.5s), traiter comme un clic normal
			if pressDuration < 0.5 then
				if draggedItem then
					-- Modifieurs: Ctrl = choisir quantité à déposer, Shift = déposer moitié, sinon tout
					local ctrl = isCtrlDown()
					local shift = isShiftDown()
					if ctrl then
						local maxQty = draggedItem and draggedItem.quantity or 1
						showQuantitySelector(draggedItem.ingredient, maxQty, function(qty)
							placeItemInSlot(slotIndex, false, qty)
						end)
					elseif shift then
						local half = math.max(1, math.floor((draggedItem and draggedItem.quantity or 1) / 2))
						placeItemInSlot(slotIndex, false, half)
					else
						-- Placer tout le stack
						placeItemInSlot(slotIndex, true)
					end
				elseif slots[slotIndex] then
					-- Retirer l'ingrédient du slot et le remettre dans l'inventaire
					local slotData = slots[slotIndex]
					local ingredientName = slotData.ingredient or slotData
					removeIngredientEvt:FireServer(currentIncID, slotIndex, ingredientName)
					-- Re-synchroniser depuis le serveur pour éviter les désyncs
					task.wait(0.25)
					local okSlots, resp = pcall(function()
						return _getSlotsEvt:InvokeServer(currentIncID)
					end)
					if okSlots and resp and resp.slots then
						slots = { resp.slots[1], resp.slots[2], resp.slots[3], resp.slots[4] }
					end
					updateSlotDisplay()
					if updateOutputSlot then updateOutputSlot() end
					updateInventoryDisplay()
				end
			end
		end)

		button.MouseButton2Click:Connect(function()
			if draggedItem then
				-- Placer un par un
				placeItemInSlot(slotIndex, false, 1)
			end
		end)

		-- Effets visuels
		button.MouseEnter:Connect(function()
			local tween = TweenService:Create(slot, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(160, 115, 70)})
			tween:Play()
		end)

		button.MouseLeave:Connect(function()
			local tween = TweenService:Create(slot, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(139, 99, 58)})
			tween:Play()
		end)
	else
		-- Bouton pour le slot de sortie (démarrer le crafting)
        local button = Instance.new("TextButton")
		button.Name = "CraftButton"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = slot

		button.MouseButton1Click:Connect(function()
			if currentRecipe then
				startCraftingEvt:FireServer(currentIncID, currentRecipe)
				-- Réinitialiser les slots après crafting
				for i = 1, NUM_INPUT_SLOTS do
					slots[i] = nil
				end
				updateSlotDisplay()
				updateOutputSlot()
				-- Fermer automatiquement le menu après lancement
				if gui then gui.Enabled = false end
				isMenuOpen = false
			end
		end)

        -- Bouton STOP PRODUCTION (s'affiche seulement si une production est en cours)
        local stopBtn = Instance.new("TextButton")
        stopBtn.Name = "StopButton"
        stopBtn.Size = UDim2.new(0, math.floor(slotSize*1.2), 0, math.floor(slotSize*0.4))
        stopBtn.Position = UDim2.new(0.5, -math.floor(slotSize*0.6), 1, 6)
        stopBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        stopBtn.Text = "STOP"
        stopBtn.TextColor3 = Color3.new(1,1,1)
        stopBtn.Font = Enum.Font.GothamBold
        stopBtn.Visible = false
        stopBtn.Parent = parent  -- parent = craftingArea
        local sbc = Instance.new("UICorner", stopBtn); sbc.CornerRadius = UDim.new(0, 8)
        local sbs = Instance.new("UIStroke", stopBtn); sbs.Thickness = 2; sbs.Color = Color3.fromRGB(66, 20, 20)

        local stopCraftingEvt = rep:FindFirstChild("StopCrafting")
        stopBtn.MouseButton1Click:Connect(function()
            if stopCraftingEvt then
                stopCraftingEvt:FireServer(currentIncID)
                -- Après stop, réactiver l'UI et rafraîchir
                task.delay(0.2, function()
                    updateSlotDisplay()
                    updateOutputSlot()
                    updateInventoryDisplay()
                end)
            end
        end)

        -- Exposer une fonction utilitaire locale pour piloter la visibilité depuis ailleurs si besoin
        slot:SetAttribute("BindStopButton", true)
	end

	return slot
end



function updateSlotDisplay()
	-- Met à jour l'affichage de tous les slots

	if not gui then 
		return 
	end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then 
		return 
	end


	-- DEBUGg: Lister tous les enfants de MainFrame
	for _, child in pairs(mainFrame:GetChildren()) do
		if child.Name == "CraftingArea" then
			for _, grandChild in pairs(child:GetChildren()) do
				if grandChild.Name == "InputContainer" then
					for _, slot in pairs(grandChild:GetChildren()) do
					end
				end
			end
		end
	end

	local ingredientIcons = {
		sucre = "🍬",
		sirop = "🍯",
		aromefruit = "🍓"
	}

	for i = 1, NUM_INPUT_SLOTS do

		-- Chercher le slot dans InputContainer, pas directement dans MainFrame
		local inputContainer = mainFrame:FindFirstChild("CraftingArea")
		if inputContainer then
			inputContainer = inputContainer:FindFirstChild("InputContainer")
		end

		local slot = inputContainer and inputContainer:FindFirstChild("InputSlot" .. i)
		if slot then

			local iconFrame = slot:FindFirstChild("IconFrame")
			local label = slot:FindFirstChild("IngredientLabel")
			local iconLabel = iconFrame and iconFrame:FindFirstChild("IconLabel")


			if slots[i] then
				-- Slot occupé (nouveau système avec quantités)
				local slotData = slots[i]
				local ingredientName = slotData.ingredient or slotData
				local quantity = slotData.quantity or 1

				if iconFrame then
					iconFrame.Visible = true
					-- ViewportFrame 3D
					local viewport = iconFrame:FindFirstChild("ViewportFrame")
					if not viewport then
						viewport = Instance.new("ViewportFrame")
						viewport.Name = "ViewportFrame"
						viewport.Size = UDim2.new(1,0,1,0)
						viewport.BackgroundTransparency = 1
						viewport.Ambient = Color3.fromRGB(200,200,200)
						viewport.LightDirection = Vector3.new(0,-1,-0.5)
						viewport.Parent = iconFrame
					end
				viewport:ClearAllChildren()
				local worldModel, model = buildIngredientModelForViewport(ingredientName)
				if worldModel and model then
					worldModel.Parent = viewport
					-- Caméra
					local cam = Instance.new("Camera")
					cam.FieldOfView = 28
					cam.Parent = viewport
					viewport.CurrentCamera = cam
					-- NORMALISATION : Taille visuelle uniforme pour tous les ingrédients dans les slots
					local size = getObjectSizeForViewport(model)
					local maxDim = math.max(size.X, size.Y, size.Z)
					if maxDim == 0 then maxDim = 1 end
					-- Taille cible normalisée : tous les objets rempliront ~70% du slot
					local targetSize = 2.0  -- Taille de référence (même que l'inventaire)
					local scaleFactor = maxDim / targetSize
					-- Distance fixe ajustée par le facteur d'échelle pour uniformiser
					local dist = 4.0 * scaleFactor
					cam.CFrame = CFrame.new(Vector3.new(0, maxDim*0.15, dist), Vector3.new(0, 0, 0))
					-- Rotation lente pour les ingrédients
					startViewportSpinner(viewport, model)
					else
						-- Fallback emoji
						if iconLabel then iconLabel.Text = ingredientIcons[ingredientName] or "📦" end
					end
				end
				if label then
					-- Utiliser le champ 'nom' du RecipeManager si disponible
					local displayName = ingredientName
					if RecipeManagerClient and RecipeManagerClient.Ingredients and RecipeManagerClient.Ingredients[ingredientName] then
						displayName = RecipeManagerClient.Ingredients[ingredientName].nom or ingredientName
					end
					label.Text = displayName .. " x" .. quantity
					label.TextColor3 = Color3.new(1, 1, 1)
				end
			else
				-- Slot vide
				if iconFrame then
					iconFrame.Visible = false
					local viewport = iconFrame:FindFirstChild("ViewportFrame")
					if viewport then viewport:ClearAllChildren() end
				end
				if label then
					label.Text = "Empty"
					label.TextColor3 = Color3.fromRGB(200, 200, 200)
				end
			end
		else
		end
	end

end

local function createModernGUI()
	-- Détection de la plateforme AVANT de créer l'interface
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

    local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IncubatorMenu_v4"
	screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 2500
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	-- Pas d'IgnoreGuiInset sur mobile pour éviter les problèmes de centrage
	screenGui.IgnoreGuiInset = not (isMobile or isSmallScreen)
	screenGui.Parent = guiParent

	-- Dimensions responsives
	local frameWidth, frameHeight
	local textSizeMultiplier = 1
	local strokeThickness = 6
	local cornerRadius = 15

	if isMobile or isSmallScreen then
		-- Mode mobile/petit écran : interface compacte
		frameWidth = math.min(viewportSize.X * 0.92, 560)
		frameHeight = math.min(viewportSize.Y * 0.82, 520)
		textSizeMultiplier = 0.6
		strokeThickness = 3
		cornerRadius = 10
	else
		-- Mode desktop : taille fixe
		frameWidth = 800
		frameHeight = 600
	end

	-- Frame principale (responsive)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = not isMobile -- Désactiver le drag sur mobile
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner", mainFrame)
	corner.CornerRadius = UDim.new(0, cornerRadius)
	local stroke = Instance.new("UIStroke", mainFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = strokeThickness

	-- Header (responsive)
	local headerHeight = isMobile and 14 or 50
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, headerHeight)
	header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	header.BorderSizePixel = 0
	header.Parent = mainFrame
	local hCorner = Instance.new("UICorner", header)
	hCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 5))
	local hStroke = Instance.new("UIStroke", header)
	hStroke.Thickness = math.max(2, strokeThickness - 2)
	hStroke.Color = Color3.fromRGB(66, 103, 38)

	local titre = Instance.new("TextLabel", header)
	titre.Size = UDim2.new(0.7, 0, 1, 0)
	titre.Position = UDim2.new(0.02, 0, 0, 0)  -- Moins de marge sur mobile
	titre.BackgroundTransparency = 1
	titre.Text = isMobile and "🧪 INCUBATOR" or "🧪 INCUBATOR - SYSTÈME DE SLOTS"  -- Texte plus court sur mobile
	titre.TextColor3 = Color3.new(1, 1, 1)
	titre.TextSize = math.floor(24 * textSizeMultiplier)
	titre.Font = Enum.Font.GothamBold
	titre.TextXAlignment = Enum.TextXAlignment.Left
	titre.TextScaled = isMobile  -- Auto-resize sur mobile

	local buttonSize = isMobile and 14 or 38  -- Bouton plus petit sur mobile
	local boutonFermer = Instance.new("TextButton", header)
	boutonFermer.Size = UDim2.new(0, buttonSize, 0, buttonSize)
	boutonFermer.Position = UDim2.new(1, -buttonSize - 5, 0.5, -buttonSize/2)
	boutonFermer.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	boutonFermer.Text = "X"
	boutonFermer.TextColor3 = Color3.new(1, 1, 1)
	boutonFermer.TextSize = math.floor(24 * textSizeMultiplier)
	boutonFermer.Font = Enum.Font.GothamBold
	local xCorner = Instance.new("UICorner", boutonFermer)
	xCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 5))

	-- Bouton Reset supprimé

	-- Zone de crafting (responsive)
	local craftingTopMargin = isMobile and (headerHeight + 4) or 45
	local craftingArea = Instance.new("Frame")
	craftingArea.Name = "CraftingArea"
	craftingArea.Size = UDim2.new(1, -20, 0.55, -20)  -- Moins de marge sur mobile
	craftingArea.Position = UDim2.new(0, 10, 0, craftingTopMargin)
	craftingArea.BackgroundTransparency = 1
	craftingArea.Parent = mainFrame

	-- Slots d'entrée (adaptés pour mobile)
	local inputContainer = Instance.new("Frame")
	inputContainer.Name = "InputContainer"
	inputContainer.Size = UDim2.new(isMobile and 0.75 or 0.65, 0, 1, 0)  -- Plus large sur mobile
	inputContainer.Position = UDim2.new(0, isMobile and 3 or 0, 0, isMobile and -4 or 0)
	inputContainer.BackgroundTransparency = 1
	inputContainer.Parent = craftingArea

	-- Disposition horizontale des slots (UIListLayout)
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Padding = UDim.new(0, isMobile and 6 or 10)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Parent = inputContainer

	-- Taille des slots d'entrée (responsive)
    -- Agrandit les slots uniquement sur PC (desktop grand écran)
    local inputSlotSize = isMobile and 34 or (isSmallScreen and 60 or 90)

	for i = 1, NUM_INPUT_SLOTS do
		local slot = createSlotUI(inputContainer, i, false, inputSlotSize, textSizeMultiplier, cornerRadius)
	end

	-- Flèche vers le résultat (responsive)
    local arrowSize = isMobile and 26 or (isSmallScreen and 40 or 60)
    local arrow = Instance.new("TextLabel")
    arrow.Name = "ArrowLabel"
	arrow.Size = UDim2.new(0, arrowSize, 0, arrowSize)
	arrow.Position = UDim2.new(isMobile and 0.80 or 0.75, -arrowSize/2, 0.5, -arrowSize/2)
	arrow.BackgroundTransparency = 1
	arrow.Text = "➡️"
	arrow.TextSize = math.floor(30 * textSizeMultiplier)
	arrow.Parent = craftingArea

    -- Slot de sortie (responsive)
    local outputSlotSize = isMobile and 46 or (isSmallScreen and 80 or 120)  -- Proportionnel aux slots d'entrée, plus grand sur PC
	local outputSlot = createSlotUI(craftingArea, 0, true, outputSlotSize, textSizeMultiplier, cornerRadius)
	outputSlot.Position = UDim2.new(isMobile and 0.90 or 0.88, -outputSlotSize/2, 0.5, -outputSlotSize/2)

	-- (Barre de progression UI retirée; on utilisera un BillboardGui au-dessus de l'incubateur)

    -- Zone d'inventaire (responsive)
	local inventoryArea = Instance.new("Frame")
	inventoryArea.Name = "InventoryArea"
	inventoryArea.Size = UDim2.new(1, -20, isMobile and 0.42 or 0.4, -10)  -- Plus grande sur mobile
	inventoryArea.Position = UDim2.new(0, 10, isMobile and 0.58 or 0.58, 5)
	inventoryArea.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
	inventoryArea.BorderSizePixel = 0
	inventoryArea.Parent = mainFrame

	local invCorner = Instance.new("UICorner", inventoryArea)
	invCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 5))
	local invStroke = Instance.new("UIStroke", inventoryArea)
	invStroke.Color = Color3.fromRGB(87, 60, 34)
	invStroke.Thickness = math.max(2, strokeThickness - 3)

	-- Titre de l'inventaire (responsive)
	local titleHeight = isMobile and 18 or 25
	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(1, 0, 0, titleHeight)
	invTitle.Position = UDim2.new(0, 0, 0, 3)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = isMobile and "📦 INVENTORY" or "📦 INVENTORY - Drag the ingredients to the slots"  -- Texte plus court sur mobile
	invTitle.TextColor3 = Color3.new(1, 1, 1)
	invTitle.TextSize = math.floor(14 * textSizeMultiplier)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextScaled = isMobile  -- Auto-resize sur mobile
	invTitle.Parent = inventoryArea

	-- Zone de scroll pour l'inventaire (responsive)
	local scrollMargin = isMobile and titleHeight + 5 or 30
	local invScrollFrame = Instance.new("ScrollingFrame")
	invScrollFrame.Name = "InventoryScroll"
	invScrollFrame.Size = UDim2.new(1, -6, 1, -scrollMargin - 5)
	invScrollFrame.Position = UDim2.new(0, 3, 0, scrollMargin)
	invScrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
	invScrollFrame.BorderSizePixel = 0
	invScrollFrame.ScrollBarThickness = isMobile and 5 or 8  -- Barre plus fine sur mobile
	invScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
	invScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	invScrollFrame.Parent = inventoryArea

	local scrollCorner = Instance.new("UICorner", invScrollFrame)
	scrollCorner.CornerRadius = UDim.new(0, 5)

	-- Layout horizontal pour les ingrédients
	local invLayout = Instance.new("UIListLayout", invScrollFrame)
	invLayout.FillDirection = Enum.FillDirection.Horizontal
	invLayout.Padding = UDim.new(0, 10)
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Panneau de déblocage (affiché si l'incubateur n'est pas débloqué)
	local unlockPanel = Instance.new("Frame", inventoryArea)
	unlockPanel.Name = "UnlockPanel"
	unlockPanel.BackgroundTransparency = 0.15
	unlockPanel.BackgroundColor3 = Color3.fromRGB(100, 70, 40)
	unlockPanel.Size = UDim2.new(1, -10, 0, isMobile and 60 or 80)
	unlockPanel.Position = UDim2.new(0, 5, 0, titleHeight + 6)
	unlockPanel.Visible = false
	local upCorner = Instance.new("UICorner", unlockPanel); upCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 6))
	local upStroke = Instance.new("UIStroke", unlockPanel); upStroke.Thickness = math.max(2, strokeThickness - 3); upStroke.Color = Color3.fromRGB(66, 46, 26)

	local unlockLabel = Instance.new("TextLabel", unlockPanel)
	unlockLabel.Size = UDim2.new(1, -10, 0, isMobile and 18 or 22)
	unlockLabel.Position = UDim2.new(0, 5, 0, 4)
	unlockLabel.BackgroundTransparency = 1
	unlockLabel.Text = ""
	unlockLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
	unlockLabel.Font = Enum.Font.GothamBold
	unlockLabel.TextScaled = true

	local unlockMoneyBtn = Instance.new("TextButton", unlockPanel)
	unlockMoneyBtn.Name = "UnlockMoneyBtn"
	unlockMoneyBtn.Size = UDim2.new(0.48, -6, 0, isMobile and 26 or 36)
	unlockMoneyBtn.Position = UDim2.new(0, 5, 0, isMobile and 30 or 38)
	unlockMoneyBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
	unlockMoneyBtn.Text = ""
	unlockMoneyBtn.TextColor3 = Color3.new(1,1,1)
	unlockMoneyBtn.Font = Enum.Font.GothamBold
	unlockMoneyBtn.TextScaled = true
	local umbC = Instance.new("UICorner", unlockMoneyBtn); umbC.CornerRadius = UDim.new(0, 8)
	local umbS = Instance.new("UIStroke", unlockMoneyBtn); umbS.Thickness = 2; umbS.Color = Color3.fromRGB(40, 80, 40)

	local unlockRobuxBtn = Instance.new("TextButton", unlockPanel)
	unlockRobuxBtn.Name = "UnlockRobuxBtn"
	unlockRobuxBtn.Size = UDim2.new(0.48, -6, 0, isMobile and 26 or 36)
	unlockRobuxBtn.Position = UDim2.new(0.52, 1, 0, isMobile and 30 or 38)
	unlockRobuxBtn.BackgroundColor3 = Color3.fromRGB(65, 130, 200)
	unlockRobuxBtn.Text = "Unlock (R$)"
	unlockRobuxBtn.TextColor3 = Color3.new(1,1,1)
	unlockRobuxBtn.Font = Enum.Font.GothamBold
	unlockRobuxBtn.TextScaled = true
	local urbC = Instance.new("UICorner", unlockRobuxBtn); urbC.CornerRadius = UDim.new(0, 8)
	local urbS = Instance.new("UIStroke", unlockRobuxBtn); urbS.Thickness = 2; urbS.Color = Color3.fromRGB(30, 60, 90)

	return screenGui, boutonFermer
end

----------------------------------------------------------------------
-- FONCTIONS PRINCIPALES
----------------------------------------------------------------------
local function closeMenu()

	-- CORRECTION CRITIQUE : Nettoyer les connexions de souris AVANT de fermer
	stopCursorFollow()

	-- S'assurer qu'aucun objet n'est en cours de drag
	if draggedItem then
		draggedItem = nil
	end

	if gui and isMenuOpen then
		local mainFrame = gui:FindFirstChild("MainFrame")
		if mainFrame then
			local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
			tween:Play()
			tween.Completed:Connect(function()
				gui.Enabled = false
				isMenuOpen = false
				currentIncID = nil
				currentRecipe = nil
				-- Réinitialiser les slots
				for i = 1, NUM_INPUT_SLOTS do
					slots[i] = nil
				end

				-- Double vérification du nettoyage des connexions
				if cursorFollowConnection then
					cursorFollowConnection:Disconnect()
					cursorFollowConnection = nil
				end
			end)
		end
	end
end

----------------------------------------------------------------------
-- INITIALISATION ET ÉVÉNEMENTS
----------------------------------------------------------------------
local function initializeGUI()
	local screenGui, closeButton = createModernGUI()

	gui = screenGui
	gui.Enabled = false

	-- Événement fermeture
	closeButton.MouseButton1Click:Connect(closeMenu)

	return gui
end

-- Initialisation
gui = initializeGUI()
if gui then

	-- Vérifier que MainFrame existe
	local mainFrame = gui:FindFirstChild("MainFrame")
	if mainFrame then
	else
	end
else
end

-- Fermer avec Escape et gérer les clics dans le vide
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isMenuOpen then
		-- Lâcher l'objet en main si il y en a un
		if draggedItem then
			stopCursorFollow()
		else
			closeMenu()
		end
	end
end)

-- Gérer les clics dans le vide pour lâcher l'objet
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not isMenuOpen or gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and draggedItem then
		-- Clic dans le vide = lâcher l'objet
		stopCursorFollow()
	end
end)

----------------------------------------------------------------------
-- 🎮 CONTRÔLES MANETTE - Variables
----------------------------------------------------------------------
local selectedSlotIndex = 1 -- 1-4 pour les slots d'ingrédients
local selectedInventoryIndex = 1
local inventoryItems = {}

-- Mettre à jour la liste des items d'inventaire de l'UI
local function updateInventoryItems()
	inventoryItems = {}
	
	if not gui or not gui.Enabled then return end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local inventoryArea = mainFrame:FindFirstChild("InventoryArea")
	if not inventoryArea then return end
	
	local scrollFrame = inventoryArea:FindFirstChild("InventoryScroll") or inventoryArea:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end
	
	-- Récupérer tous les items d'inventaire
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^InventoryItem_") then
			local ingredientName = child.Name:gsub("^InventoryItem_", "")
			table.insert(inventoryItems, {
				name = ingredientName,
				frame = child
			})
		end
	end
end

-- Mettre à jour le highlight des slots ET de l'inventaire
local function updateGamepadHighlight()
	if not gui or not gui.Enabled then return end
	
	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local craftingArea = mainFrame:FindFirstChild("CraftingArea")
	if craftingArea then
		-- Highlight des slots d'ingrédients (chercher dans InputContainer)
		local inputContainer = craftingArea:FindFirstChild("InputContainer")
		if inputContainer then
			for i = 1, NUM_INPUT_SLOTS do
				local slotFrame = inputContainer:FindFirstChild("InputSlot" .. i)
				if slotFrame then
					local highlight = slotFrame:FindFirstChild("GamepadHighlight")
					
					if i == selectedSlotIndex then
						-- Créer le highlight s'il n'existe pas
						if not highlight then
							highlight = Instance.new("Frame")
							highlight.Name = "GamepadHighlight"
							highlight.Size = UDim2.new(1, 12, 1, 12)
							highlight.Position = UDim2.new(0.5, 0, 0.5, 0)
							highlight.AnchorPoint = Vector2.new(0.5, 0.5)
							highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
							highlight.BackgroundTransparency = 0.3
							highlight.BorderSizePixel = 0
							highlight.ZIndex = slotFrame.ZIndex - 1
							highlight.Parent = slotFrame
							
							local corner = Instance.new("UICorner")
							corner.CornerRadius = UDim.new(0, 12)
							corner.Parent = highlight
							
							-- Animation
							local tween = TweenService:Create(highlight, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
								BackgroundTransparency = 0.6,
								Size = UDim2.new(1, 16, 1, 16)
							})
							tween:Play()
						end
					else
						-- Supprimer le highlight
						if highlight then
							highlight:Destroy()
						end
					end
				end
			end
		end
	end
	
	-- Highlight de l'item d'inventaire sélectionné
	for i, item in ipairs(inventoryItems) do
		if item.frame then
			local highlight = item.frame:FindFirstChild("GamepadHighlight")
			
			if i == selectedInventoryIndex then
				-- Créer le highlight
				if not highlight then
					highlight = Instance.new("Frame")
					highlight.Name = "GamepadHighlight"
					highlight.Size = UDim2.new(1, 8, 1, 8)
					highlight.Position = UDim2.new(0.5, 0, 0.5, 0)
					highlight.AnchorPoint = Vector2.new(0.5, 0.5)
					highlight.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					highlight.BackgroundTransparency = 0.3
					highlight.BorderSizePixel = 0
					highlight.ZIndex = item.frame.ZIndex - 1
					highlight.Parent = item.frame
					
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 8)
					corner.Parent = highlight
					
					-- Animation
					local tween = TweenService:Create(highlight, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
						BackgroundTransparency = 0.6,
						Size = UDim2.new(1, 12, 1, 12)
					})
					tween:Play()
				end
			else
				-- Supprimer le highlight
				if highlight then
					highlight:Destroy()
				end
			end
		end
	end
end

-- Test de l'événement d'ouverture
if openEvt and openEvt.OnClientEvent then

	-- Événement d'ouverture avec DEBUGg (responsive)
	openEvt.OnClientEvent:Connect(function(incID)

		if not gui then
			return
		end

		currentIncID = incID

		-- RECALCULER LES DIMENSIONS RESPONSIVE À CHAQUE OUVERTURE
		local viewportSize = workspace.CurrentCamera.ViewportSize
		local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

		local frameWidth, frameHeight
		if isMobile or isSmallScreen then
			-- Mobile : Taille compacte pour éviter la hotbar
			frameWidth = math.min(viewportSize.X * 0.82, 520)
			frameHeight = math.min(viewportSize.Y * 0.68, 480)
		else
			-- Desktop : Taille normale
			frameWidth = 800
			frameHeight = 600
		end

		local mainFrame = gui:FindFirstChild("MainFrame")
		if mainFrame then

			-- Appliquer les nouvelles dimensions
			mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)

			-- Recalculer la position selon la plateforme
			if isMobile or isSmallScreen then
				-- Mobile : Centrer mais plus haut pour éviter la hotbar
				local posX = (viewportSize.X - frameWidth) / 2
				local posY = math.max(10, (viewportSize.Y - frameHeight) / 2 - 50)  -- 50px plus haut que le menu vente
				mainFrame.Position = UDim2.new(0, posX, 0, posY)
				mainFrame.AnchorPoint = Vector2.new(0, 0)
			else
				-- Desktop : Centrage normal
				mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
				mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			end

		else
		end

		-- Demander l'état courant au serveur (production en cours ou non)
        local state = nil
        local okState, errState = pcall(function()
            state = _getStateEvt:InvokeServer(currentIncID)
        end)
        if not okState then
            state = { isCrafting = false }
        end
		isCraftingActive = state.isCrafting == true

		-- UI lock si crafting en cours + Affichage éventuel du panneau d'unlock
        local mainFrame2 = gui:FindFirstChild("MainFrame")
        if mainFrame2 then
            local craftingArea = mainFrame2:FindFirstChild("CraftingArea")
            if craftingArea then
                local overlay = craftingArea:FindFirstChild("CraftLockOverlay")
                if not overlay then
                    overlay = Instance.new("Frame")
                    overlay.Name = "CraftLockOverlay"
                    overlay.BackgroundColor3 = Color3.new(0,0,0)
                    overlay.BackgroundTransparency = 0.35
                    overlay.BorderSizePixel = 0
                    overlay.Size = UDim2.new(1, 0, 1, 0)
                    overlay.Position = UDim2.new(0, 0, 0, 0)
                    overlay.ZIndex = 40
                    overlay.Visible = false
                    overlay.Parent = craftingArea
                    local msg = Instance.new("TextLabel", overlay)
                    msg.Size = UDim2.new(1, 0, 0, 20)
                    msg.Position = UDim2.new(0, 0, 0, -24)
                    msg.AnchorPoint = Vector2.new(0, 0)
                    msg.BackgroundTransparency = 1
                    msg.Text = "PRODUCTION IN PROGRESS"
                    msg.TextColor3 = Color3.fromRGB(255, 230, 120)
                    msg.Font = Enum.Font.GothamBold
                    msg.TextScaled = true
                end
                overlay.Visible = isCraftingActive
                -- HIDE slots + gros bouton STOP via overlay dédié
				setProductionUIActive(isCraftingActive)
            end

			-- Déterminer l'index d'incubateur pour ce menu
			local incIdx = 1
			do
				local m = tostring(currentIncID or "")
				local n = tonumber(string.match(m, "_(%d+)$"))
				if n then incIdx = n end
			end
			-- Vérifier le nombre d'incubateurs débloqués via PlayerData client
			local pd = plr:FindFirstChild("PlayerData")
			local iu = pd and pd:FindFirstChild("IncubatorsUnlocked")
			local unlocked = iu and iu.Value or 1
			local inventoryArea = mainFrame2:FindFirstChild("InventoryArea")
			local unlockPanel = inventoryArea and inventoryArea:FindFirstChild("UnlockPanel")
			local invScroll = inventoryArea and inventoryArea:FindFirstChild("InventoryScroll")
			local unlockMoneyBtn = unlockPanel and unlockPanel:FindFirstChild("UnlockMoneyBtn")
			local unlockRobuxBtn = unlockPanel and unlockPanel:FindFirstChild("UnlockRobuxBtn")
			local unlockLabel = unlockPanel and unlockPanel:FindFirstChildOfClass("TextLabel")
			if inventoryArea and unlockPanel and invScroll then
				if incIdx > unlocked then
					-- Afficher panneau d'unlock avec prix
					local cost = (incIdx == 2) and 100000000000 or 1000000000000
					unlockPanel.Visible = true
					invScroll.Visible = false
					if unlockLabel then
						unlockLabel.Text = (incIdx == 2) and "Unlock 100,000,000,000$" or "Unlock 1,000,000,000,000$"
					end
                    if unlockMoneyBtn then
                        unlockMoneyBtn.Text = (incIdx == 2) and "Unlock 100B" or "Unlock 1T"
                        unlockMoneyBtn.MouseButton1Click:Connect(function()
                            local ev = rep:FindFirstChild("RequestUnlockIncubatorMoney")
                            if ev and ev:IsA("RemoteEvent") then
                                ev:FireServer(incIdx)
                            end
                        end)
                    end
                    if unlockRobuxBtn then
                        unlockRobuxBtn.MouseButton1Click:Connect(function()
                            local ev = rep:FindFirstChild("RequestUnlockIncubator")
                            if ev and ev:IsA("RemoteEvent") then
                                ev:FireServer(incIdx)
                            end
                        end)
                    end
				else
					-- Masquer panneau d'unlock
					if unlockPanel then unlockPanel.Visible = false end
					if invScroll then invScroll.Visible = true end
				end
			end
        end

        -- Récupérer les slots actuels (si on veut recharger après stop)
        local resp = nil
        local okSlots, _errSlots = pcall(function()
            resp = _getSlotsEvt:InvokeServer(currentIncID)
        end)
        if okSlots and resp and resp.slots then
            slots = { resp.slots[1], resp.slots[2], resp.slots[3], resp.slots[4] }
        else
            slots = {nil, nil, nil, nil}
        end

		-- Réactivation progressive des fonctions de mise à jour
		local ok3, err3 = pcall(function()
			updateInventoryDisplay()
		end)
		if not ok3 then 
		end

		local ok1, err1 = pcall(function()
			updateSlotDisplay()
		end)
		if not ok1 then 
		end

		local ok2, err2 = pcall(function()
			updateOutputSlot()
		end)
		if not ok2 then 
		end


		gui.Enabled = true
		isMenuOpen = true

		-- Initialiser les contrôles gamepad (avec délai pour que les fonctions soient définies)
		task.spawn(function()
			task.wait(0.15) -- Attendre que l'UI soit créée et les fonctions définies
			selectedSlotIndex = 1
			selectedInventoryIndex = 1
			if updateInventoryItems then updateInventoryItems() end
			if updateGamepadHighlight then updateGamepadHighlight() end
		end)

		-- Animation d'ouverture simplifiée (pas de resize animé)
		if mainFrame then
			mainFrame.BackgroundTransparency = 1
			local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 0
			})
			tween:Play()
		else
		end
	end)
else
end

-- Mise à jour de la barre de progression
-- Affichage de la barre de progression au-dessus de l'incubateur (BillboardGui)
local incubatorBillboards = {}
local function getIncubatorModelByID(incID)
	-- Recherche simple côté client
	for _, p in ipairs(workspace:GetDescendants()) do
		if p:IsA("StringValue") and p.Name == "ParcelID" and p.Value == incID then
			local part = p.Parent
			if part then
				return part:FindFirstAncestorOfClass("Model")
			end
		end
	end
	return nil
end

local function ensureBillboard(incID)
	local incModel = getIncubatorModelByID(incID)
	if not incModel then return nil end
	
	-- Utiliser la BillboardPart existante dans le modèle
	local billboardPart = incModel:FindFirstChild("BillboardPart")
	if not billboardPart then return nil end
	
  	local bb = incubatorBillboards[incID]
	if bb and bb.Parent then return bb end
	bb = Instance.new("BillboardGui")
	bb.Name = "IncubatorProgress"
	bb.Adornee = billboardPart
	bb.AlwaysOnTop = true
	bb.MaxDistance = 100  -- Distance d'affichage augmentée
  	bb.Size = UDim2.new(0, 240, 0, 60)
  	-- Pas besoin de StudsOffset car la part est déjà bien positionnée
  	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.Parent = incModel

	local title = Instance.new("TextLabel", bb)
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Production"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true

  	local bg = Instance.new("Frame", bb)
	bg.Name = "BG"
	bg.Size = UDim2.new(0, 180, 0.45, 0)
  	bg.Position = UDim2.new(0, 0, 0.6, 0)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	local bgCorner = Instance.new("UICorner", bg)
	bgCorner.CornerRadius = UDim.new(0, 6)

	local fill = Instance.new("Frame", bg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner", fill)
	fillCorner.CornerRadius = UDim.new(0, 6)

	-- Tweener pour fluidifier la progression
	local uiStroke = Instance.new("UIStroke", bg)
	uiStroke.Thickness = 1
	uiStroke.Color = Color3.fromRGB(20,20,20)

	local count = Instance.new("TextLabel", bb)
	count.Name = "Count"
	count.Size = UDim2.new(0, 50, 0.45, 0)
	count.Position = UDim2.new(0, 200, 0.55, 0)
	count.BackgroundTransparency = 1
	count.TextColor3 = Color3.new(1,1,1)
	count.TextScaled = true
	count.Font = Enum.Font.GothamBold
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.Text = ""

	-- Ajout du timer sous la barre de progression
	local timer = Instance.new("TextLabel", bb)
	timer.Name = "Timer"
	timer.Size = UDim2.new(0, 180, 0, 16)
	timer.Position = UDim2.new(0, 0, 0.95, 0)
	timer.BackgroundTransparency = 1
	timer.TextColor3 = Color3.fromRGB(230,230,230)
	timer.Font = Enum.Font.GothamBold
	timer.TextScaled = false
	timer.TextSize = 14
	timer.TextWrapped = false
	timer.TextXAlignment = Enum.TextXAlignment.Left
	timer.Text = "--:--"

	incubatorBillboards[incID] = bb
	return bb
end

if craftProgressEvt then
	craftProgressEvt.OnClientEvent:Connect(function(incID, currentIndex, total, progress, remainCurrent, remainTotal)
		local bb = ensureBillboard(incID)
		if not bb then return end
		local bg = bb:FindFirstChild("BG")
		local fill = bg and bg:FindFirstChild("Fill")
		local count = bb:FindFirstChild("Count")
		local timer = bb:FindFirstChild("Timer")
		if not fill or not count then return end
		if timer then timer.Visible = true end
		local target = math.clamp(progress, 0, 1)
		-- Tween fluide
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(target, 0, 1, 0)}):Play()

        -- Calcul des restants (corrigé pour le cas reset: total <= 0 → rien à afficher)
        local left = 0
        if typeof(total) == "number" and typeof(currentIndex) == "number" and total > 0 then
            local prog = typeof(progress) == "number" and progress or 0
            left = math.max(0, total - currentIndex + ((prog < 1) and 1 or 0))
        end
		-- Mise à jour visuelle
        if left > 0 then
			count.Text = "x" .. tostring(left)
			count.Visible = true
			bb.Enabled = true
			-- Timer total sous la barre (format mm:ss)
			if timer then
				local seconds = tonumber(remainTotal) or 0
				local minutes = math.floor(seconds / 60)
				local secs = seconds % 60
				timer.Text = string.format("%02d:%02d", minutes, secs)
				timer.Visible = true
			end
            -- Afficher le bouton STOP si l'UI de cet incubateur est ouverte
            if gui and isMenuOpen and currentIncID == incID then
                local mainFrame = gui:FindFirstChild("MainFrame")
                local craftingArea = mainFrame and mainFrame:FindFirstChild("CraftingArea")
                if craftingArea then
                    local stopBtn = craftingArea:FindFirstChild("StopButton", true) or craftingArea:FindFirstChild("StopButton")
                    if stopBtn and stopBtn:IsA("TextButton") then
                        stopBtn.Visible = true
                        -- Animer légèrement pour attirer l'attention
                        pcall(function()
                            TweenService:Create(stopBtn, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundColor3 = Color3.fromRGB(220, 80, 80)}):Play()
                        end)
                    end
                end
            end
        else
			-- Production terminée → cacher la barre et le titre
            count.Text = ""
			count.Visible = false
			bb.Enabled = false
            -- Masquer le bouton STOP si l'UI est ouverte
            if gui and isMenuOpen and currentIncID == incID then
                local mainFrame = gui:FindFirstChild("MainFrame")
                local craftingArea = mainFrame and mainFrame:FindFirstChild("CraftingArea")
                if craftingArea then
                    local stopBtn = craftingArea:FindFirstChild("StopButton", true) or craftingArea:FindFirstChild("StopButton")
                    if stopBtn and stopBtn:IsA("TextButton") then
                        stopBtn.Visible = false
                    end
                end
            end
            isCraftingActive = false
		end
	end)
end



-- Inputs manette (les fonctions sont définies plus haut)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not isMenuOpen or not gui or not gui.Enabled then return end
	
	-- Bloquer R1/L1 pour éviter de changer de slot hotbar
	if input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonL1 then
		return -- Ignorer complètement
	end
	
	-- D-pad Haut/Bas : Changer d'ingrédient dans l'inventaire
	if input.KeyCode == Enum.KeyCode.DPadUp then
		updateInventoryItems() -- Rafraîchir la liste
		if #inventoryItems > 0 then
			selectedInventoryIndex = selectedInventoryIndex - 1
			if selectedInventoryIndex < 1 then selectedInventoryIndex = #inventoryItems end
			updateGamepadHighlight()
			print("🎮 Ingrédient:", inventoryItems[selectedInventoryIndex].name, "(" .. selectedInventoryIndex .. "/" .. #inventoryItems .. ")")
		end
	elseif input.KeyCode == Enum.KeyCode.DPadDown then
		updateInventoryItems() -- Rafraîchir la liste
		if #inventoryItems > 0 then
			selectedInventoryIndex = selectedInventoryIndex + 1
			if selectedInventoryIndex > #inventoryItems then selectedInventoryIndex = 1 end
			updateGamepadHighlight()
			print("🎮 Ingrédient:", inventoryItems[selectedInventoryIndex].name, "(" .. selectedInventoryIndex .. "/" .. #inventoryItems .. ")")
		end
	end
	
	-- D-pad Gauche/Droite : Changer de slot
	if input.KeyCode == Enum.KeyCode.DPadLeft then
		selectedSlotIndex = selectedSlotIndex - 1
		if selectedSlotIndex < 1 then selectedSlotIndex = NUM_INPUT_SLOTS end
		updateGamepadHighlight()
		print("🎮 Slot:", selectedSlotIndex)
	elseif input.KeyCode == Enum.KeyCode.DPadRight then
		selectedSlotIndex = selectedSlotIndex + 1
		if selectedSlotIndex > NUM_INPUT_SLOTS then selectedSlotIndex = 1 end
		updateGamepadHighlight()
		print("🎮 Slot:", selectedSlotIndex)
	end
	
	-- X : Placer l'ingrédient sélectionné dans le slot sélectionné
	if input.KeyCode == Enum.KeyCode.ButtonX then
		if #inventoryItems > 0 and selectedInventoryIndex <= #inventoryItems and currentIncID then
			local ingredientName = inventoryItems[selectedInventoryIndex].name
			placeIngredientEvt:FireServer(currentIncID, selectedSlotIndex, ingredientName)
			print("✅ Placé:", ingredientName, "→ Slot", selectedSlotIndex)
			
			-- Rafraîchir après un court délai
			task.delay(0.3, function()
				updateInventoryItems()
				updateGamepadHighlight()
			end)
		end
	end
	
	-- Y : Retirer l'ingrédient du slot sélectionné
	if input.KeyCode == Enum.KeyCode.ButtonY then
		if currentIncID then
			removeIngredientEvt:FireServer(currentIncID, selectedSlotIndex)
			print("🗑️ Retiré du Slot", selectedSlotIndex)
		end
	end
	
	-- A : Lancer la production
	if input.KeyCode == Enum.KeyCode.ButtonA then
		if currentIncID and not isCraftingActive then
			startCraftingEvt:FireServer(currentIncID)
			print("🚀 Production lancée!")
		end
	end
end)

-- Désactiver les contrôles de la hotbar quand l'incubateur est ouvert
local hotbarControlsEnabled = true

local function setHotbarControlsEnabled(enabled)
	hotbarControlsEnabled = enabled
	-- Informer CustomBackpack de désactiver/activer les contrôles
	if _G.CustomBackpack then
		_G.CustomBackpack.gamepadEnabled = enabled
	end
end

-- Surveiller l'ouverture/fermeture du menu
task.spawn(function()
	while true do
		task.wait(0.5)
		
		if gui and gui.Enabled and isMenuOpen then
			-- Menu ouvert : désactiver hotbar
			if hotbarControlsEnabled then
				setHotbarControlsEnabled(false)
				print("🎮 [INCUBATOR] Hotbar désactivée")
			end
			
			-- Mettre à jour l'inventaire et le highlight
			updateInventoryItems()
			updateGamepadHighlight()
		else
			-- Menu fermé : réactiver hotbar
			if not hotbarControlsEnabled then
				setHotbarControlsEnabled(true)
				print("🎮 [INCUBATOR] Hotbar réactivée")
			end
		end
	end
end)

print("✅ [INCUBATOR] Contrôles manette activés")
print("🎮 Dans l'incubateur:")
print("  • D-pad ↔ : Choisir slot (1-4)")
print("  • D-pad ↕ : Choisir ingrédient")
print("  • X : Placer ingrédient")
print("  • Y : Retirer ingrédient")
print("  • A : Lancer production")
