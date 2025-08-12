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

print("🔍 IncubatorMenuClient v4.0 - Système de slots - Début du chargement")

-- RemoteEvents avec gestion d'erreurs
print("📡 Recherche des RemoteEvents...")

local openEvt = rep:WaitForChild("OpenIncubatorMenu")
print("✅ OpenIncubatorMenu trouvé:", openEvt.Name, openEvt.ClassName)

print("📝 Débug: Liste des objets dans ReplicatedStorage:")
for _, child in pairs(rep:GetChildren()) do
	print("  - ", child.Name, "(", child.ClassName, ")")
end

-- Création ou récupération des RemoteEvents avec fallback sécurisé
local function getOrCreateRemoteEvent(name)
	local existing = rep:FindFirstChild(name)
	if not existing then
		warn("⚠️ RemoteEvent '" .. name .. "' manquant - tentative de création")
		local newEvent = Instance.new("RemoteEvent")
		newEvent.Name = name
		newEvent.Parent = rep
		print("🔧 RemoteEvent '" .. name .. "' créé automatiquement")
		return newEvent
	end
	return existing
end

local function getOrCreateRemoteFunction(name)
	local existing = rep:FindFirstChild(name)
	if not existing then
		warn("⚠️ RemoteFunction '" .. name .. "' manquant - tentative de création")
		local newFunction = Instance.new("RemoteFunction")
		newFunction.Name = name
		newFunction.Parent = rep
		print("🔧 RemoteFunction '" .. name .. "' créé automatiquement")
		return newFunction
	end
	return existing
end

local placeIngredientEvt = getOrCreateRemoteEvent("PlaceIngredientInSlot")
print("✅ PlaceIngredientInSlot disponible")

local removeIngredientEvt = getOrCreateRemoteEvent("RemoveIngredientFromSlot")
print("✅ RemoveIngredientFromSlot disponible")

local startCraftingEvt = getOrCreateRemoteEvent("StartCrafting")
print("✅ StartCrafting disponible")

local _getSlotsEvt = getOrCreateRemoteFunction("GetIncubatorSlots")
print("✅ GetIncubatorSlots disponible")

local craftProgressEvt = getOrCreateRemoteEvent("IncubatorCraftProgress")
print("✅ IncubatorCraftProgress disponible")

local guiParent = plr:WaitForChild("PlayerGui")

print("✅ Tous les RemoteEvents trouvés et connectés")

----------------------------------------------------------------------
-- VARIABLES GLOBALES
----------------------------------------------------------------------
local NUM_INPUT_SLOTS = 4
local gui = nil
local currentIncID = nil
local slots = {nil, nil, nil, nil} -- 4 slots d'entrée
local currentRecipe = nil
local isMenuOpen = false

----------------------------------------------------------------------
-- FONCTIONS UTILITAIRES
----------------------------------------------------------------------

-- Variables pour le drag and drop (style Minecraft)
local draggedItem = nil
local dragFrame = nil
local cursorFollowConnection = nil

-- Déclarations forward des fonctions
local updateOutputSlot = nil
local updateOutputViewport = nil
-- Accès direct au RecipeManager côté client pour les mappages 'modele'
local RecipeManagerClient = nil
do
	local m = rep:FindFirstChild("RecipeManager")
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then RecipeManagerClient = mod end
	end
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

	-- 🔥 NOUVEAU : Soustraire les ingrédients déjà utilisés dans les slots
	print("🔍 DEBUGg - getAvailableIngredients AVANT soustraction:", ingredients)
	for i = 1, NUM_INPUT_SLOTS do
		local slotData = slots[i]
		if slotData and slotData.ingredient then
			local ingredientName = slotData.ingredient
			local quantityUsed = slotData.quantity or 1
			if ingredients[ingredientName] then
				ingredients[ingredientName] = math.max(0, ingredients[ingredientName] - quantityUsed)
				print("🔍 DEBUGg - Soustraction slot", i, ":", ingredientName, "x", quantityUsed, "reste:", ingredients[ingredientName])

				-- Si plus rien, supprimer complètement de la liste
				if ingredients[ingredientName] <= 0 then
					ingredients[ingredientName] = nil
				end
			end
		end
	end
	print("🔍 DEBUGg - getAvailableIngredients APRÈS soustraction:", ingredients)

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
			local size = getObjectSizeForViewport(model)
			local maxDim = math.max(size.X, size.Y, size.Z)
			if maxDim == 0 then maxDim = 1 end
			local dist = math.max(2.5, maxDim * 1.25)
			cam.CFrame = CFrame.new(Vector3.new(0, maxDim*0.3, dist), Vector3.new(0, 0, 0))
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
	nameLabel.Text = isMobile and (ingredientName .. "\nx" .. quantity) or (ingredientName .. "\n" .. quantity)
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

	-- Événements style Minecraft
	clickButton.MouseButton1Click:Connect(function()
		-- Clic gauche = prendre tout le stack
		pickupItem(ingredientName, quantity)

		-- 💡 NOUVEAU : Surbrillance des slots vides pour le tutoriel
		print("🎯 [TUTORIAL] Clic sur ingrédient:", ingredientName)
		highlightEmptySlots(ingredientName)

		-- Effacer la surbrillance après 3 secondes
		task.spawn(function()
			task.wait(3)
			clearSlotHighlights()
		end)
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
	print("🎯 DEBUGg - pickupItem appelée:", ingredientName, "quantité:", quantityToTake)

	if draggedItem then
		print("❌ DEBUGg - Item déjà en main:", draggedItem.ingredient)
		-- Si on a déjà quelque chose en main, essayer de le placer
		return
	end

	-- Vérifier qu'on a assez d'ingrédients
	local availableIngredients = getAvailableIngredients()
	local availableQuantity = availableIngredients[ingredientName] or 0
	print("🔍 DEBUGg - Quantité disponible:", availableQuantity)

	if availableQuantity <= 0 then 
		print("❌ DEBUGg - Aucune quantité disponible")
		return 
	end

	-- Prendre la quantité demandée (ou ce qui est disponible)
	local actualQuantity = math.min(quantityToTake, availableQuantity)
	print("✅ DEBUGg - Quantité prise:", actualQuantity)

	-- Créer l'objet en main
	draggedItem = {
		ingredient = ingredientName,
		quantity = actualQuantity
	}

	-- Créer le frame qui suit le curseur
	print("🔍 DEBUGg - Création du cursor item...")
	createCursorItem(ingredientName, actualQuantity)

	-- Démarrer le suivi du curseur
	print("🔍 DEBUGg - Démarrage du suivi curseur...")
	startCursorFollow()
	print("✅ DEBUGg - Item pris en main:", ingredientName, "x", actualQuantity)
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
	local textSizeMultiplier = (isMobile or isSmallScreen) and 0.75 or 1

	-- Taille du curseur responsive
	local cursorSize = (isMobile or isSmallScreen) and 44 or 60

	dragFrame = Instance.new("Frame")
	dragFrame.Name = "CursorItem"
	dragFrame.Size = UDim2.new(0, cursorSize, 0, cursorSize)
	dragFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	dragFrame.BorderSizePixel = 0
	dragFrame.ZIndex = 1000
	dragFrame.Parent = gui

	local corner = Instance.new("UICorner", dragFrame)
	corner.CornerRadius = UDim.new(0, math.max(5, math.floor(8 * textSizeMultiplier)))
	local stroke = Instance.new("UIStroke", dragFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = math.max(1, math.floor(2 * textSizeMultiplier))

	-- Icône (responsive)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 0.7, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = ingredientIcons[ingredientName] or "📦"
	iconLabel.TextColor3 = Color3.new(1, 1, 1)
	iconLabel.TextSize = math.floor(20 * textSizeMultiplier)
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextScaled = textSizeMultiplier < 1  -- Auto-resize sur mobile
	iconLabel.Parent = dragFrame

	-- Quantité (responsive)
	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	quantityLabel.Position = UDim2.new(0, 0, 0.7, 0)
	quantityLabel.BackgroundTransparency = 1
	quantityLabel.Text = tostring(quantity)
	quantityLabel.TextColor3 = Color3.new(1, 1, 1)
	quantityLabel.TextSize = math.floor(12 * textSizeMultiplier)
	quantityLabel.Font = Enum.Font.SourceSansBold
	quantityLabel.TextScaled = textSizeMultiplier < 1  -- Auto-resize sur mobile
	quantityLabel.Parent = dragFrame
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
end

-- Fonction pour arrêter le suivi du curseur
function stopCursorFollow()
	if cursorFollowConnection then
		cursorFollowConnection:Disconnect()
		cursorFollowConnection = nil
	end

	if dragFrame then
		dragFrame:Destroy()
		dragFrame = nil
	end

	draggedItem = nil
end

-- Fonction pour placer l'objet dans un slot
function placeItemInSlot(slotIndex, placeAll)
	print("🎯 DEBUGg - placeItemInSlot appelée:", "slot", slotIndex, "placeAll", placeAll)

	if not draggedItem then 
		print("❌ DEBUGg - Aucun item en main")
		return 
	end

	print("🔍 DEBUGg - Item en main:", draggedItem.ingredient, "quantité:", draggedItem.quantity)
	local quantityToPlace = placeAll and draggedItem.quantity or 1
	print("🔍 DEBUGg - Quantité à placer:", quantityToPlace)

	-- IMPORTANT : Sauvegarder les infos AVANT de modifier draggedItem
	local ingredientName = draggedItem.ingredient
	local _originalQuantity = draggedItem.quantity

	-- Envoyer au serveur en une seule fois (quantité agrégée)
	print("🔍 DEBUGg - Envoi au serveur...")
	print("🔍 DEBUGg - Paramètres:", "incID:", currentIncID, "slot:", slotIndex, "ingredient:", ingredientName, "quantité:", quantityToPlace)
	placeIngredientEvt:FireServer(currentIncID, slotIndex, ingredientName, quantityToPlace)
	print("✅ DEBUGg - Envoyé au serveur")

	-- Mettre à jour l'objet en main
	draggedItem.quantity = draggedItem.quantity - quantityToPlace

	if draggedItem.quantity <= 0 then
		-- Plus rien en main
		print("🔍 DEBUGg - Plus d'item en main, arrêt du suivi curseur...")
		stopCursorFollow() -- Cette fonction met draggedItem = nil !
		print("🔍 DEBUGg - Suivi curseur arrêté, draggedItem = nil")
	else
		-- Mettre à jour l'affichage
		print("🔍 DEBUGg - Mise à jour affichage, reste:", draggedItem.quantity)
		if dragFrame then
			local quantityLabel = dragFrame:FindFirstChild("TextLabel")
			if quantityLabel and quantityLabel.Name ~= "TextLabel" then
				quantityLabel.Text = tostring(draggedItem.quantity)
			end
		end
	end

	-- Mettre à jour l'interface (CONTOURNEMENT: pas d'appel serveur qui plante)
	task.wait(0.2)
	print("🔍 DEBUGg - placeItemInSlot: Mise à jour locale des slots")
	print("🔍 DEBUGg - slotIndex:", slotIndex, "ingredientName:", ingredientName, "quantityToPlace:", quantityToPlace)

	-- Simuler la mise à jour locale du slot (temporairement)
	if slotIndex >= 1 and slotIndex <= NUM_INPUT_SLOTS then
		print("🔍 DEBUGg - Mise à jour du slot", slotIndex, "avec", ingredientName)
		slots[slotIndex] = {
			ingredient = ingredientName,
			quantity = quantityToPlace
		}
		print("✅ DEBUGg - Slot", slotIndex, "mis à jour localement avec", ingredientName)
		print("🔍 DEBUGg - Contenu slots après mise à jour:", slots[slotIndex])
	else
		print("❌ DEBUGg - slotIndex invalide:", slotIndex)
	end

	print("🔍 DEBUGg - Avant updateSlotDisplay...")
	local ok1 = pcall(function()
		updateSlotDisplay()
	end)
	print("🔍 DEBUGg - updateSlotDisplay ok:", ok1)

	print("🔍 DEBUGg - Avant updateOutputSlot...")
	local ok2 = pcall(function()
		updateOutputSlot()
	end)
	print("🔍 DEBUGg - updateOutputSlot ok:", ok2)

	print("🔍 DEBUGg - Avant updateInventoryDisplay...")
	local ok3 = pcall(function()
		updateInventoryDisplay()
	end)
	print("🔍 DEBUGg - updateInventoryDisplay ok:", ok3)

	print("✅ DEBUGg - placeItemInSlot terminée!")
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

	print("💡 [TUTORIAL] Surbrillance des slots pour ingédient:", ingredientName)

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

					print("✨ [TUTORIAL] Surbrillance ajoutée au slot", i)
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

	print("💫 [TUTORIAL] Toutes les surbrillances effacées")
end

-- Fonction pour mettre à jour l'affichage de l'inventaire
function updateInventoryDisplay()
	if not gui then return end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end

	local inventoryArea = mainFrame:FindFirstChild("InventoryArea")
	if not inventoryArea then return end

	local scrollFrame = inventoryArea:FindFirstChild("ScrollingFrame")
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
	print("🔍 DEBUGg calculateRecipe - Début avec slots:", slots)

	if not currentIncID then 
		print("❌ DEBUGg calculateRecipe - currentIncID nil")
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
			print("🔍 DEBUGg calculateRecipe - Ingrédient:", ingredientName, "quantité:", quantity)
		end
	end

	print("🔍 DEBUGg calculateRecipe - Ingrédients totaux:", ingredients)

	-- Chercher une recette qui correspond (version simplifiée côté client)
	if RecipeManagerClient and RecipeManagerClient.Recettes then
		for recipeName, recipeData in pairs(RecipeManagerClient.Recettes) do
			print("🔍 DEBUGg calculateRecipe - Test recette:", recipeName)

			if recipeData.ingredients then
				local matches = true
				local canCraft = true

				-- Vérifier si tous les ingrédients requis sont présents
				for requiredIngredient, requiredQuantity in pairs(recipeData.ingredients) do
					local availableQuantity = ingredients[requiredIngredient] or 0
					print("🔍 DEBUGg calculateRecipe - Requis:", requiredIngredient, "x", requiredQuantity, "disponible:", availableQuantity)

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
							print("🔍 DEBUGg calculateRecipe - Ingrédient en trop:", availableIngredient)
							matches = false
							break
						end
					end
				end

				if matches and canCraft then
					print("✅ DEBUGg calculateRecipe - Recette trouvée:", recipeName)
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

	print("❌ DEBUGg calculateRecipe - Aucune recette trouvée")
	return nil, nil, 0
end

updateOutputSlot = function()
	-- Met à jour le slot de sortie avec la recette calculée
	print("🔍 DEBUGg updateOutputSlot - Début")

	if not gui then 
		print("❌ DEBUGg updateOutputSlot - GUI non trouvé!")
		return 
	end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then 
		print("❌ DEBUGg updateOutputSlot - MainFrame non trouvé!")
		return 
	end

	-- Le slot de sortie est dans craftingArea, pas directement dans mainFrame
	local craftingArea = mainFrame:FindFirstChild("CraftingArea")
	if not craftingArea then
		print("❌ DEBUGg updateOutputSlot - CraftingArea non trouvé!")
		return
	end

	local outputSlot = craftingArea:FindFirstChild("OutputSlot")
	if not outputSlot then 
		print("❌ DEBUGg updateOutputSlot - OutputSlot non trouvé!")
		-- DEBUGg : Lister tous les enfants de CraftingArea
		print("🔍 DEBUGg - Enfants de CraftingArea:")
		for _, child in pairs(craftingArea:GetChildren()) do
			print("  -", child.Name, ":", child.ClassName)
		end
		return 
	end

	print("✅ DEBUGg updateOutputSlot - OutputSlot trouvé")

	local recipeName, recipeDef, quantity = calculateRecipe()
	currentRecipe = recipeName

	if recipeName and recipeDef and quantity > 0 then
		-- Afficher la recette possible
		outputSlot.BackgroundColor3 = Color3.fromRGB(85, 170, 85) -- Vert = possible
		local recipeLabel = outputSlot:FindFirstChild("RecipeLabel")
		if recipeLabel then
			if quantity > 1 then
				recipeLabel.Text = "🍬 " .. quantity .. "x " .. recipeName
			else
				recipeLabel.Text = "🍬 " .. recipeName
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


	else
		-- Pas de recette possible
		outputSlot.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron = pas possible
		local recipeLabel = outputSlot:FindFirstChild("RecipeLabel")
		if recipeLabel then
			recipeLabel.Text = "❌ Aucune recette"
			recipeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end

		local iconFrame = outputSlot:FindFirstChild("IconFrame")
		if iconFrame then
			iconFrame.Visible = false
			local viewport = iconFrame:FindFirstChild("ViewportFrame")
			if viewport then viewport:ClearAllChildren() end
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

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local clone = tpl:Clone()
	clone.Parent = worldModel

	-- Convertir Tool en Model si besoin
	if clone:IsA("Tool") then
		local m = Instance.new("Model")
		for _, ch in ipairs(clone:GetChildren()) do ch.Parent = m end
		clone:Destroy()
		clone = m
		clone.Parent = worldModel
	end

	-- Trouver une basepart pour focus
	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		-- Créer une petite caméra de fallback
		local cam = Instance.new("Camera")
		cam.Parent = viewport
		viewport.CurrentCamera = cam
		return
	end

	-- Positionner le modèle à l'origine (léger offset pour centrage)
	if clone:IsA("Model") then clone:PivotTo(CFrame.new(0,0,0)) end
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end

	-- Caméra
	local cam = Instance.new("Camera")
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	-- Cadre: reculer la caméra selon la taille
	local _cf, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim == 0 then maxDim = 1 end
	-- Zoom encore plus proche pour bien remplir la case
	local camDist = math.max(2.5, maxDim * 0.65)
	cam.FieldOfView = 24
	cam.CFrame = CFrame.new(Vector3.new(0, maxDim*0.12, camDist), Vector3.new(0, 0, 0))

	-- Éclairage simple
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 12
	light.Color = Color3.fromRGB(255, 240, 220)
	light.Parent = primary

	-- Rotation en continu dans la viewport (faire tourner tout le modèle)
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
	label.Text = isOutputSlot and "Résultat" or "Vide"
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

		-- Événements de clic (style Minecraft)
		button.MouseButton1Click:Connect(function()
			if draggedItem then
				-- Placer tout le stack
				placeItemInSlot(slotIndex, true)
			elseif slots[slotIndex] then
				-- Retirer l'ingrédient du slot et le remettre dans l'inventaire
				local slotData = slots[slotIndex]
				local ingredientName = slotData.ingredient or slotData
				removeIngredientEvt:FireServer(currentIncID, slotIndex, ingredientName)

				-- Mettre à jour l'interface après un délai (CONTOURNEMENT)
				task.wait(0.1)
				print("🔍 DEBUGg - Retrait d'ingrédient du slot", slotIndex)

				-- Simuler la suppression locale du slot (temporairement)
				slots[slotIndex] = nil
				print("✅ DEBUGg - Slot", slotIndex, "vidé localement")

				updateSlotDisplay()
				-- updateOutputSlot() -- Temporairement désactivé car plante
				updateInventoryDisplay()
			end
		end)

		button.MouseButton2Click:Connect(function()
			if draggedItem then
				-- Placer un par un
				placeItemInSlot(slotIndex, false)
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
	end

	return slot
end



function updateSlotDisplay()
	-- Met à jour l'affichage de tous les slots
	print("🔍 DEBUGg updateSlotDisplay - Début")

	if not gui then 
		print("❌ DEBUGg updateSlotDisplay - GUI non trouvé!")
		return 
	end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then 
		print("❌ DEBUGg updateSlotDisplay - MainFrame non trouvé!")
		return 
	end

	print("✅ DEBUGg updateSlotDisplay - MainFrame trouvé")

	-- DEBUGg: Lister tous les enfants de MainFrame
	print("🔍 DEBUGg - Enfants de MainFrame:")
	for _, child in pairs(mainFrame:GetChildren()) do
		print("  -", child.Name, ":", child.ClassName)
		if child.Name == "CraftingArea" then
			print("    Enfants de CraftingArea:")
			for _, grandChild in pairs(child:GetChildren()) do
				print("      -", grandChild.Name, ":", grandChild.ClassName)
				if grandChild.Name == "InputContainer" then
					print("        Enfants de InputContainer:")
					for _, slot in pairs(grandChild:GetChildren()) do
						print("          -", slot.Name, ":", slot.ClassName)
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
		print("🔍 DEBUGg updateSlotDisplay - Traitement slot", i, "contenu:", slots[i])

		-- Chercher le slot dans InputContainer, pas directement dans MainFrame
		local inputContainer = mainFrame:FindFirstChild("CraftingArea")
		if inputContainer then
			inputContainer = inputContainer:FindFirstChild("InputContainer")
		end

		local slot = inputContainer and inputContainer:FindFirstChild("InputSlot" .. i)
		if slot then
			print("✅ DEBUGg updateSlotDisplay - Slot", i, "trouvé")

			local iconFrame = slot:FindFirstChild("IconFrame")
			local label = slot:FindFirstChild("IngredientLabel")
			local iconLabel = iconFrame and iconFrame:FindFirstChild("IconLabel")

			print("🔍 DEBUGg updateSlotDisplay - Éléments trouvés - iconFrame:", iconFrame ~= nil, "label:", label ~= nil, "iconLabel:", iconLabel ~= nil)

			if slots[i] then
				-- Slot occupé (nouveau système avec quantités)
				local slotData = slots[i]
				local ingredientName = slotData.ingredient or slotData
				local quantity = slotData.quantity or 1

				print("✅ DEBUGg updateSlotDisplay - Slot", i, "occupé avec:", ingredientName, "quantité:", quantity)
				if iconFrame then
					iconFrame.Visible = true
					print("✅ DEBUGg updateSlotDisplay - IconFrame rendu visible")
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
						local size = getObjectSizeForViewport(model)
						local maxDim = math.max(size.X, size.Y, size.Z)
						if maxDim == 0 then maxDim = 1 end
						local dist = math.max(2.2, maxDim * 0.9)
						cam.CFrame = CFrame.new(Vector3.new(0, maxDim*0.2, dist), Vector3.new(0, 0, 0))
						-- Rotation lente pour les ingrédients
						startViewportSpinner(viewport, model)
					else
						-- Fallback emoji
						if iconLabel then iconLabel.Text = ingredientIcons[ingredientName] or "📦" end
					end
				end
				if label then
					label.Text = ingredientName .. " x" .. quantity
					label.TextColor3 = Color3.new(1, 1, 1)
					print("✅ DEBUGg updateSlotDisplay - Label mis à jour:", label.Text)
				end
			else
				-- Slot vide
				print("🔍 DEBUGg updateSlotDisplay - Slot", i, "vide")
				if iconFrame then
					iconFrame.Visible = false
					local viewport = iconFrame:FindFirstChild("ViewportFrame")
					if viewport then viewport:ClearAllChildren() end
				end
				if label then
					label.Text = "Vide"
					label.TextColor3 = Color3.fromRGB(200, 200, 200)
				end
			end
		else
			print("❌ DEBUGg updateSlotDisplay - Slot", i, "non trouvé!")
		end
	end

	print("✅ DEBUGg updateSlotDisplay - Fin")
end

local function createModernGUI()
	-- Détection de la plateforme AVANT de créer l'interface
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IncubatorMenu_v4"
	screenGui.ResetOnSpawn = false
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
	titre.Text = isMobile and "🧪 INCUBATEUR" or "🧪 INCUBATEUR - SYSTÈME DE SLOTS"  -- Texte plus court sur mobile
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
	local inputSlotSize = isMobile and 34 or 60 -- Slots plus petits sur mobile

	for i = 1, NUM_INPUT_SLOTS do
		local slot = createSlotUI(inputContainer, i, false, inputSlotSize, textSizeMultiplier, cornerRadius)
		print("🔍 DEBUGg - Slot créé:", slot.Name, "dans", inputContainer.Name)
	end

	-- Flèche vers le résultat (responsive)
	local arrowSize = isMobile and 26 or 50
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(0, arrowSize, 0, arrowSize)
	arrow.Position = UDim2.new(isMobile and 0.80 or 0.75, -arrowSize/2, 0.5, -arrowSize/2)
	arrow.BackgroundTransparency = 1
	arrow.Text = "➡️"
	arrow.TextSize = math.floor(30 * textSizeMultiplier)
	arrow.Parent = craftingArea

	-- Slot de sortie (responsive)
	local outputSlotSize = isMobile and 46 or 80  -- Proportionnel aux slots d'entrée
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
	invTitle.Text = isMobile and "📦 INVENTAIRE" or "📦 INVENTAIRE - Glissez les ingrédients vers les slots"  -- Texte plus court sur mobile
	invTitle.TextColor3 = Color3.new(1, 1, 1)
	invTitle.TextSize = math.floor(14 * textSizeMultiplier)
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextScaled = isMobile  -- Auto-resize sur mobile
	invTitle.Parent = inventoryArea

	-- Zone de scroll pour l'inventaire (responsive)
	local scrollMargin = isMobile and titleHeight + 5 or 30
	local invScrollFrame = Instance.new("ScrollingFrame")
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

	return screenGui, boutonFermer
end

----------------------------------------------------------------------
-- FONCTIONS PRINCIPALES
----------------------------------------------------------------------
local function closeMenu()
	print("🖼️ DEBUGgg - closeMenu() appelée - isMenuOpen:", isMenuOpen)

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
					print("✅ Connexion de souris déconnectée")
				end
			end)
		end
	end
end

----------------------------------------------------------------------
-- INITIALISATION ET ÉVÉNEMENTS
----------------------------------------------------------------------
local function initializeGUI()
	print("🔍 DEBUGg - Création de l'interface avec slots...")
	local screenGui, closeButton = createModernGUI()

	gui = screenGui
	gui.Enabled = false

	-- Événement fermeture
	closeButton.MouseButton1Click:Connect(closeMenu)

	return gui
end

-- Initialisation
print("🔍 DEBUGgG Client - Initialisation de l'interface...")
gui = initializeGUI()
if gui then
	print("✅ DEBUGgg Client - GUI créé avec succès")
	print("🔍 DEBUGgg - GUI Name:", gui.Name)
	print("🔍 DEBUGgg - GUI Parent:", gui.Parent and gui.Parent.Name or "nil")
	print("🔍 DEBUGgg - GUI Enabled:", gui.Enabled)

	-- Vérifier que MainFrame existe
	local mainFrame = gui:FindFirstChild("MainFrame")
	if mainFrame then
		print("✅ DEBUGgg - MainFrame existe dans le GUI")
		print("🔍 DEBUGgg - MainFrame Size:", mainFrame.Size)
		print("🔍 DEBUGgg - MainFrame Position:", mainFrame.Position)
	else
		print("❌ DEBUGgg - MainFrame manquant dans le GUI!")
	end
else
	print("❌ DEBUGgg Client - Échec de création du GUI")
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

-- Test de l'événement d'ouverture
print("🔍 DEBUGgg - Tentative de connexion à OpenIncubatorMenu...")
if openEvt and openEvt.OnClientEvent then
	print("✅ DEBUGgg - OnClientEvent existe, connexion...")

	-- Événement d'ouverture avec DEBUGg (responsive)
	openEvt.OnClientEvent:Connect(function(incID)
		print("🔍 DEBUGg - OnClientEvent reçu:", incID)

		if not gui then
			print("❌ DEBUGg - GUI est nil!")
			return
		end

		print("✅ DEBUGg - GUI existe:", gui.Name)
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
			print("✅ DEBUGgg - MainFrame trouvé:", mainFrame.Name)
			print("🔍 DEBUGgg - Taille AVANT:", mainFrame.Size)

			-- Appliquer les nouvelles dimensions
			mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
			print("🔧 DEBUGg - Taille appliquée:", frameWidth .. "x" .. frameHeight)
			print("🔍 DEBUGgg - Taille APRÈS:", mainFrame.Size)

			-- Recalculer la position selon la plateforme
			print("🔍 DEBUGgg - Calcul position...")
			if isMobile or isSmallScreen then
				-- Mobile : Centrer mais plus haut pour éviter la hotbar
				local posX = (viewportSize.X - frameWidth) / 2
				local posY = math.max(10, (viewportSize.Y - frameHeight) / 2 - 50)  -- 50px plus haut que le menu vente
				mainFrame.Position = UDim2.new(0, posX, 0, posY)
				mainFrame.AnchorPoint = Vector2.new(0, 0)
				print("📱 DEBUGgg - Position mobile:", posX, posY)
			else
				-- Desktop : Centrage normal
				mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
				mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
				print("💻 DEBUGgg - Position desktop centré")
			end
			print("✅ DEBUGgg - Position appliquée!")

			print("📱 INCUBATEUR - Dimensions appliquées:", frameWidth .. "x" .. frameHeight)
		else
			print("❌ DEBUGgg - MainFrame NON TROUVÉ!")
		end

		-- Récupérer l'état actuel des slots (TEMPORAIREMENT DÉSACTIVÉ POUR DEBUGg)
		print("🔍 DEBUGgg - CONTOURNEMENT: Utilisation de slots vides (serveur plante)")
		-- TEMPORAIRE: Le serveur GetIncubatorSlots plante - on utilise des slots vides
		slots = {nil, nil, nil, nil}
		print("✅ DEBUGgg - Slots initialisés (contournement)")

		-- Réactivation progressive des fonctions de mise à jour
		print("🔍 DEBUGgg - Test updateInventoryDisplay...")
		local ok3, err3 = pcall(function()
			updateInventoryDisplay()
		end)
		print("🔍 DEBUGgg - updateInventoryDisplay résultat:", ok3)
		if not ok3 then 
			warn("❌ DEBUGgg - Erreur updateInventoryDisplay:", err3) 
		end

		print("🔍 DEBUGgg - Test updateSlotDisplay...")  
		local ok1, err1 = pcall(function()
			updateSlotDisplay()
		end)
		print("🔍 DEBUGgg - updateSlotDisplay résultat:", ok1)
		if not ok1 then 
			warn("❌ DEBUGgg - Erreur updateSlotDisplay:", err1) 
		end

		print("🔍 DEBUGgg - Test updateOutputSlot...")
		local ok2, err2 = pcall(function()
			updateOutputSlot()
		end)
		print("🔍 DEBUGgg - updateOutputSlot résultat:", ok2)
		if not ok2 then 
			warn("❌ DEBUGgg - Erreur updateOutputSlot:", err2) 
		end

		print("✅ DEBUGgg - Toutes les mises à jour testées!")

		print("🔍 DEBUGgg - Activation du GUI...")
		gui.Enabled = true
		isMenuOpen = true
		print("✅ DEBUGgg - GUI activé! gui.Enabled =", gui.Enabled)

		-- Animation d'ouverture simplifiée (pas de resize animé)
		if mainFrame then
			print("🔍 DEBUGg - Démarrage animation d'ouverture...")
			mainFrame.BackgroundTransparency = 1
			local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 0
			})
			tween:Play()
			print("✅ DEBUGg - Animation lancée!")
		else
			warn("❌ MainFrame non trouvé pour l'animation!")
		end
	end)
else
	print("❌ DEBUGg - OpenIncubatorMenu ou OnClientEvent n'existe pas!")
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
	local primary = incModel.PrimaryPart or incModel:FindFirstChildWhichIsA("BasePart", true)
	if not primary then return nil end
	local bb = incubatorBillboards[incID]
	if bb and bb.Parent then return bb end
	bb = Instance.new("BillboardGui")
	bb.Name = "IncubatorProgress"
	bb.Adornee = primary
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 240, 0, 40)
	bb.StudsOffset = Vector3.new(0, 6.5, 0)
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
	bg.Position = UDim2.new(0, 0, 0.55, 0)
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
		if not fill or not count then return end
		local target = math.clamp(progress, 0, 1)
		-- Tween fluide
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(target, 0, 1, 0)}):Play()

		-- Calcul des restants
		local left = 0
		if total and currentIndex then
			left = math.max(0, total - currentIndex + (progress < 1 and 1 or 0))
		end
		-- Mise à jour visuelle
		if left > 0 then
			count.Text = "x" .. tostring(left)
			count.Visible = true
			bb.Enabled = true
		else
			-- Production terminée → cacher la barre et le titre
			count.Text = "x0"
			count.Visible = false
			bb.Enabled = false
		end
	end)
end

print("🔧 IncubatorMenuClient v4.0 (Système de slots avec crafting automatique) - Script chargé et prêt!")
