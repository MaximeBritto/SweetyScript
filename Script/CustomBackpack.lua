-- CustomBackpack.lua
-- Backpack personnalisé avec hotbar (style Minecraft) et modèles 3D
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 30) -- Timeout de 30 secondes

if not playerGui then
	error("❌ [BACKPACK] PlayerGui introuvable après 30 secondes")
end

print("✅ [BACKPACK] PlayerGui chargé")

-- Modules
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- Dossiers des modèles 3D
local ingredientToolsFolder = ReplicatedStorage:WaitForChild("IngredientTools")
local candyModelsFolder = ReplicatedStorage:WaitForChild("CandyModels")

-- Import du gestionnaire de tailles (si disponible)
local CandySizeManager
local success, result = pcall(function()
	return require(ReplicatedStorage:WaitForChild("CandySizeManager"))
end)
if success then
	CandySizeManager = result
end

-- Variables du backpack personnalisé
local customBackpack = nil
local hotbarFrame = nil
local inventoryFrame = nil
local isInventoryOpen = false
local equippedTool = nil
local selectedSlot = 1 -- Slot sélectionné dans la hotbar (1-9)

-- Variables pour le tooltip
local tooltipFrame = nil
local tooltipLabel = nil

-- Variables pour optimiser les rafraîchissements
local inventoryUpdateScheduled = false
local inventoryUpdateDebounce = 0.1  -- Délai minimum entre 2 mises à jour

-- Liste stable des tools pour la hotbar (garde les positions)
local hotbarTools = {}

-- Variables pour le drag and drop (style Minecraft)
local draggedItem = nil -- {tool = Tool, sourceSlot = number or nil, quantity = number}
local dragFrame = nil
local cursorFollowConnection = nil
local quantitySelectorOverlay = nil

-- Variables globales pour détection responsive (partagées entre fonctions)
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Fonction pour mettre à jour la détection responsive
local function updateResponsiveDetection()
	viewportSize = workspace.CurrentCamera.ViewportSize
	isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
end

-- Fonction pour obtenir le nom d'affichage d'un tool (bonbon ou ingrédient)
local function getToolDisplayName(tool)
	if not tool then return "Inconnu" end

	-- Pour les ingrédients (ont l'attribut BaseName)
	if tool:GetAttribute("BaseName") then
		local baseName = tool:GetAttribute("BaseName")
		local ingredientData = RecipeManager.Ingredients[baseName]
		if ingredientData and ingredientData.nom then
			return ingredientData.nom
		end
		return baseName
	end

	-- Pour les bonbons (chercher dans les recettes)
	local candyName = tool.Name
	for recipeName, recipeData in pairs(RecipeManager.Recettes) do
		if recipeData.modele == candyName or recipeName == candyName then
			return recipeData.nom or recipeName
		end
	end

	return tool.Name
end

-- Fonction pour créer le tooltip
local function createTooltip()
	if tooltipFrame then return end

	tooltipFrame = Instance.new("Frame")
	tooltipFrame.Name = "Tooltip"
	tooltipFrame.Size = UDim2.new(0, 200, 0, 40)
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.Visible = false
	tooltipFrame.ZIndex = 10000  -- Très élevé pour être au-dessus de tout
	tooltipFrame.Parent = customBackpack

	local corner = Instance.new("UICorner", tooltipFrame)
	corner.CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke", tooltipFrame)
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 2

	tooltipLabel = Instance.new("TextLabel")
	tooltipLabel.Size = UDim2.new(1, -10, 1, -10)
	tooltipLabel.Position = UDim2.new(0, 5, 0, 5)
	tooltipLabel.BackgroundTransparency = 1
	tooltipLabel.Text = ""
	tooltipLabel.TextColor3 = Color3.new(1, 1, 1)
	tooltipLabel.TextSize = 14
	tooltipLabel.Font = Enum.Font.GothamBold
	tooltipLabel.TextScaled = true
	tooltipLabel.TextXAlignment = Enum.TextXAlignment.Center
	tooltipLabel.TextYAlignment = Enum.TextYAlignment.Center
	tooltipLabel.Parent = tooltipFrame
end

-- Fonction pour afficher le tooltip
local function showTooltip(tool, position)
	if not tooltipFrame then createTooltip() end
	if not tool then return end

	local displayName = getToolDisplayName(tool)
	tooltipLabel.Text = displayName

	-- Positionner le tooltip au-dessus de l'item
	tooltipFrame.Position = UDim2.new(0, position.X - 100, 0, position.Y - 50)
	tooltipFrame.Visible = true
end

-- Fonction pour cacher le tooltip
local function hideTooltip()
	if tooltipFrame then
		tooltipFrame.Visible = false
	end
end

----------------------------------------------------------------------
-- FONCTIONS UTILITAIRES POUR DRAG AND DROP
----------------------------------------------------------------------

-- Déclarations forward
local showQuantitySelector
local pickupItemFromTool
local pickupItemFromSlot
local createCursorItem
local startCursorFollow
local stopCursorFollow
local placeItemInHotbarSlot
local scheduleInventoryUpdate
local updateInventoryContent

-- Helpers pour touches modificatrices
local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function isCtrlDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

-- Obtenir la quantité totale d'un tool
local function getToolQuantity(tool)
	if not tool then return 0 end
	local count = tool:FindFirstChild("Count")
	return count and count.Value or 1
end

-- Désactiver le backpack par défaut de Roblox (avec retry robuste)
local function disableDefaultBackpack()
	-- Essayer plusieurs fois pour s'assurer que ça fonctionne
	local maxAttempts = 10
	local attempt = 0
	
	local function tryDisable()
		attempt = attempt + 1
		local success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		
		if success then
			print("✅ [BACKPACK] Hotbar par défaut désactivée (tentative", attempt, ")")
			return true
		else
			warn("⚠️ [BACKPACK] Échec désactivation hotbar (tentative", attempt, ")")
			return false
		end
	end
	
	-- Première tentative immédiate
	if tryDisable() then return end
	
	-- Retry avec délais croissants
	for i = 1, maxAttempts - 1 do
		task.wait(0.5 * i) -- Délai croissant: 0.5s, 1s, 1.5s, etc.
		if tryDisable() then return end
	end
	
	warn("❌ [BACKPACK] Impossible de désactiver la hotbar par défaut après", maxAttempts, "tentatives")
end

----------------------------------------------------------------------
-- FONCTIONS DRAG AND DROP
----------------------------------------------------------------------

-- Fonction pour prendre un tool depuis l'inventaire
pickupItemFromTool = function(tool, quantityToTake)

	-- Si on a déjà un item en main, le reposer d'abord
	if draggedItem then
		stopCursorFollow()
	end

	local totalQuantity = getToolQuantity(tool)

	if totalQuantity <= 0 then 
		return 
	end

	-- Prendre la quantité demandée (ou ce qui est disponible)
	local actualQuantity = math.min(quantityToTake, totalQuantity)

	-- Créer l'objet en main
	draggedItem = {
		tool = tool,
		sourceSlot = nil,  -- Vient de l'inventaire, pas d'un slot
		sourceIsInventory = true,  -- 🔧 NOUVEAU: Marquer qu'il vient de l'inventaire
		quantity = actualQuantity,
		totalAvailable = totalQuantity
	}

	-- Créer le frame qui suit le curseur
	createCursorItem(tool, actualQuantity)

	-- Démarrer le suivi du curseur
	startCursorFollow()
end

-- Fonction pour prendre un tool depuis un slot de la hotbar
pickupItemFromSlot = function(slotNumber, quantityToTake)
	local tool = hotbarTools[slotNumber]
	if not tool then return end


	-- Si on a déjà un item en main, le reposer d'abord
	if draggedItem then
		stopCursorFollow()
	end

	local totalQuantity = getToolQuantity(tool)

	if totalQuantity <= 0 then 
		return 
	end

	local actualQuantity = math.min(quantityToTake, totalQuantity)

	draggedItem = {
		tool = tool,
		sourceSlot = slotNumber,
		sourceIsInventory = false,  -- 🔧 NOUVEAU: Vient d'un slot, pas de l'inventaire
		quantity = actualQuantity,
		totalAvailable = totalQuantity
	}

	createCursorItem(tool, actualQuantity)
	startCursorFollow()
end

-- Fonction pour créer l'objet qui suit le curseur (responsive)
createCursorItem = function(tool, quantity)
	if dragFrame then
		dragFrame:Destroy()
	end

	-- Taille du curseur responsive
	local cursorSize = (isMobile or isSmallScreen) and 50 or 60

	dragFrame = Instance.new("Frame")
	dragFrame.Name = "CursorItem"
	dragFrame.Size = UDim2.new(0, cursorSize, 0, cursorSize)
	dragFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	dragFrame.BorderSizePixel = 0
	dragFrame.ZIndex = 5000  -- Très élevé pour être au-dessus de tout
	dragFrame.Parent = customBackpack

	local corner = Instance.new("UICorner", dragFrame)
	corner.CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", dragFrame)
	stroke.Color = Color3.fromRGB(255, 215, 0)  -- Bordure dorée
	stroke.Thickness = 3

	-- Viewport 3D de l'objet
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -10, 1, -20)
	viewport.Position = UDim2.new(0, 5, 0, 5)
	viewport.BackgroundTransparency = 1
	viewport.ZIndex = 5001
	viewport.Parent = dragFrame

	-- Afficher le modèle 3D
	local baseName = tool:GetAttribute("BaseName") or tool.Name
	local toolModel = ingredientToolsFolder:FindFirstChild(baseName) or candyModelsFolder:FindFirstChild(tool.Name)

	if toolModel then
		local visualPart = toolModel:FindFirstChild("BonbonSkin") or toolModel:FindFirstChild("Handle")
		if visualPart then
			UIUtils.setupViewportFrame(viewport, visualPart)
		end
	end

	-- Label de quantité
	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "QtyLabel"
	quantityLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
	quantityLabel.Position = UDim2.new(0.6, 0, 0.7, 0)
	quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	quantityLabel.BackgroundTransparency = 0.3
	quantityLabel.Text = tostring(quantity)
	quantityLabel.TextColor3 = Color3.new(1, 1, 1)
	quantityLabel.ZIndex = 5002
	quantityLabel.TextSize = 14
	quantityLabel.Font = Enum.Font.GothamBold
	quantityLabel.TextScaled = true
	quantityLabel.Parent = dragFrame

	local qCorner = Instance.new("UICorner", quantityLabel)
	qCorner.CornerRadius = UDim.new(0, 4)
end

-- Sélecteur de quantité (overlay + slider)
showQuantitySelector = function(tool, maxQuantity, onConfirm)
	if maxQuantity == nil or maxQuantity <= 0 then return end
	if quantitySelectorOverlay and quantitySelectorOverlay.Parent then
		quantitySelectorOverlay:Destroy()
		quantitySelectorOverlay = nil
	end

	if not customBackpack then return end
	local overlay = Instance.new("Frame")
	overlay.Name = "QtySelectorOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 4500
	overlay.Active = true
	overlay.Parent = customBackpack

	local panel = Instance.new("Frame")
	panel.Name = "QtyPanel"
	panel.Size = UDim2.new(0, 320, 0, 160)
	panel.Position = UDim2.new(0.5, -160, 0.5, -80)
	panel.BackgroundColor3 = Color3.fromRGB(60, 44, 28)
	panel.BorderSizePixel = 0
	panel.ZIndex = 4600
	panel.Parent = overlay
	local pc = Instance.new("UICorner", panel); pc.CornerRadius = UDim.new(0, 10)
	local ps = Instance.new("UIStroke", panel); ps.Thickness = 2; ps.Color = Color3.fromRGB(87, 60, 34)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 30)
	title.Position = UDim2.new(0, 8, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "Sélection quantité: " .. (tool:GetAttribute("BaseName") or tool.Name)
	title.TextColor3 = Color3.new(1,1,1)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.ZIndex = 4610
	title.Parent = panel

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Size = UDim2.new(1, -16, 0, 26)
	amountLabel.Position = UDim2.new(0, 8, 0, 48)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = "1 / " .. tostring(maxQuantity)
	amountLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
	amountLabel.Font = Enum.Font.Gotham
	amountLabel.TextScaled = true
	amountLabel.ZIndex = 4610
	amountLabel.Parent = panel

	local bar = Instance.new("Frame")
	bar.Name = "SliderBar"
	bar.Size = UDim2.new(1, -40, 0, 16)
	bar.Position = UDim2.new(0, 20, 0, 90)
	bar.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
	bar.BorderSizePixel = 0
	bar.ZIndex = 4610
	bar.Parent = panel
	local bc = Instance.new("UICorner", bar); bc.CornerRadius = UDim.new(0, 8)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Position = UDim2.new(0, 0, 0, 0)
	fill.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	fill.BorderSizePixel = 0
	fill.ZIndex = 4620
	fill.Parent = bar
	local fc = Instance.new("UICorner", fill); fc.CornerRadius = UDim.new(0, 8)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(235, 210, 140)
	knob.BorderSizePixel = 0
	knob.ZIndex = 4630
	knob.Parent = bar
	local kc = Instance.new("UICorner", knob); kc.CornerRadius = UDim.new(1, 0)
	local ks = Instance.new("UIStroke", knob); ks.Thickness = 1; ks.Color = Color3.fromRGB(66, 40, 20)

	local buttons = Instance.new("Frame")
	buttons.Size = UDim2.new(1, -16, 0, 32)
	buttons.Position = UDim2.new(0, 8, 1, -40)
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = 4610
	buttons.Parent = panel

	local okBtn = Instance.new("TextButton")
	okBtn.Size = UDim2.new(0.48, 0, 1, 0)
	okBtn.Position = UDim2.new(0, 0, 0, 0)
	okBtn.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	okBtn.Text = "Valider"
	okBtn.TextColor3 = Color3.new(1,1,1)
	okBtn.Font = Enum.Font.GothamBold
	okBtn.TextScaled = true
	okBtn.ZIndex = 4620
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
	cancelBtn.ZIndex = 4620
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

	local function cleanup()
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
startCursorFollow = function()
	if cursorFollowConnection then return end

	local currentIsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	cursorFollowConnection = UserInputService.InputChanged:Connect(function(input)
		if dragFrame then
			-- Support souris ET tactile
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local mousePos = UserInputService:GetMouseLocation()
				local offsetSize = currentIsMobile and 25 or 30
				dragFrame.Position = UDim2.new(0, mousePos.X - offsetSize, 0, mousePos.Y - offsetSize)
			elseif input.UserInputType == Enum.UserInputType.Touch then
				dragFrame.Position = UDim2.new(0.5, -25, 0.3, 0)
			end
		end
	end)
end

-- Fonction pour arrêter le suivi du curseur
stopCursorFollow = function()
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

-- Fonction pour placer un item dans un slot de la hotbar
placeItemInHotbarSlot = function(slotNumber, placeAll, quantityOverride)

	if not draggedItem then 
		return 
	end

	local tool = draggedItem.tool
	local quantityToPlace

	if typeof(quantityOverride) == "number" and quantityOverride > 0 then
		quantityToPlace = math.min(quantityOverride, draggedItem.quantity)
	else
		quantityToPlace = placeAll and draggedItem.quantity or 1
	end


	-- 🔧 CORRECTION: Vérifier si ce tool est déjà dans un autre slot de la hotbar
	local toolCurrentSlot = nil
	for i = 1, 9 do
		if hotbarTools[i] == tool then
			toolCurrentSlot = i
			break
		end
	end

	-- Vérifier s'il y a déjà un tool dans ce slot de destination
	local existingTool = hotbarTools[slotNumber]

	if existingTool and existingTool ~= tool then
		-- Remplacement : échanger les tools

		-- Si le tool vient d'un autre slot, faire un swap
		if toolCurrentSlot then
			hotbarTools[toolCurrentSlot] = existingTool
			hotbarTools[slotNumber] = tool
		else
			-- Le tool vient de l'inventaire, juste remplacer
			hotbarTools[slotNumber] = tool
		end
	else
		-- Placement simple ou déplacement dans le même slot
		if toolCurrentSlot and toolCurrentSlot ~= slotNumber then
			-- Déplacement d'un slot à un autre (pas de swap)
			hotbarTools[toolCurrentSlot] = nil
		end

		hotbarTools[slotNumber] = tool
	end

	-- Mettre à jour l'affichage
	stopCursorFollow()
	updateAllHotbarSlots()

	-- 🔧 CORRECTION CRITIQUE: Forcer la mise à jour IMMÉDIATE de l'inventaire
	if isInventoryOpen then
		-- Mise à jour immédiate sans délai
		updateInventoryContent()
		-- Puis une mise à jour planifiée pour être sûr
		task.delay(0.1, function()
			if isInventoryOpen then
				updateInventoryContent()
			end
		end)
	end


	-- 🔧 DEBUG: Afficher l'état de la hotbar après placement
	for i = 1, 9 do
		if hotbarTools[i] then
		end
	end
end

-- Créer l'interface du backpack personnalisé
local function createCustomBackpack()

	-- IMPORTANT : Mettre à jour la détection responsive au début
	updateResponsiveDetection()

	-- ScreenGui principal (configuration minimale pour éviter conflits)
	customBackpack = Instance.new("ScreenGui")
	customBackpack.Name = "CustomBackpack"
	customBackpack.ResetOnSpawn = false
	customBackpack.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- SUPPRESSION temporaire des propriétés qui peuvent causer des conflits
	-- customBackpack.IgnoreGuiInset = true
	-- customBackpack.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	customBackpack.Parent = playerGui

	-- Variables responsive déjà définies globalement

	-- HOTBAR PERMANENTE (9 slots comme Minecraft) - Responsive
	hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "CustomHotbar"

	-- Taille responsive de la hotbar
	if isMobile or isSmallScreen then
		-- Mobile : 7 slots × 50px = 350px + padding
		hotbarFrame.Size = UDim2.new(0, 380, 0, 55)
		hotbarFrame.Position = UDim2.new(0.5, -190, 1, -65)
	else
		-- Desktop : 9 slots × 70px = 630px + padding
		hotbarFrame.Size = UDim2.new(0, 630, 0, 70)
		hotbarFrame.Position = UDim2.new(0.5, -315, 1, -80)
	end

	hotbarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	hotbarFrame.BorderSizePixel = 0
	hotbarFrame.Parent = customBackpack

	-- Bouton de vente rapide à côté de la hotbar (DÉSACTIVÉ - remplacé par TopButtonsUI)
	do
		local ENABLE_SELL_BUTTON = false
		if ENABLE_SELL_BUTTON then
			local sellButton = Instance.new("TextButton")
			sellButton.Name = "SellButton"
			if isMobile or isSmallScreen then
				sellButton.Size = UDim2.new(0, 50, 0, 55)
				sellButton.Position = UDim2.new(0.5, 250, 1, -65)
				sellButton.Text = "💰"
				sellButton.TextSize = 16
			else
				sellButton.Size = UDim2.new(0, 60, 0, 70)
				sellButton.Position = UDim2.new(0.5, 400, 1, -80)
				sellButton.Text = "💰\nVENTE"
				sellButton.TextSize = 12
			end
			sellButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			sellButton.BorderSizePixel = 0
			sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			sellButton.Font = Enum.Font.GothamBold
			sellButton.TextScaled = (isMobile or isSmallScreen)
			sellButton.Parent = customBackpack
			local sellCorner = Instance.new("UICorner")
			sellCorner.CornerRadius = UDim.new(0, 8)
			sellCorner.Parent = sellButton
			sellButton.MouseButton1Click:Connect(function()
				if _G.openSellMenu then _G.openSellMenu() end
			end)
			-- Petit highlight intégré (désactivé par défaut; activé seulement via tutoriel overlay)
			local SHOW_SELL_HIGHLIGHT_ALWAYS = false
			if SHOW_SELL_HIGHLIGHT_ALWAYS then
				local baseHighlight = Instance.new("Frame")
				baseHighlight.Name = "BaseHighlight"
				baseHighlight.Size = UDim2.new(1, 12, 1, 12)
				baseHighlight.Position = UDim2.new(0, -6, 0, -6)
				baseHighlight.BackgroundColor3 = Color3.fromRGB(255, 235, 120)
				baseHighlight.BackgroundTransparency = 0.65
				baseHighlight.BorderSizePixel = 0
				baseHighlight.ZIndex = (sellButton.ZIndex or 1) + 1
				baseHighlight.Parent = sellButton
				local bhCorner = Instance.new("UICorner", baseHighlight)
				bhCorner.CornerRadius = UDim.new(0, 10)
				local bhStroke = Instance.new("UIStroke", baseHighlight)
				bhStroke.Color = Color3.fromRGB(255, 250, 160)
				bhStroke.Thickness = 3
				bhStroke.Transparency = 0.35
				TweenService:Create(baseHighlight, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					BackgroundTransparency = 0.35,
					Size = UDim2.new(1, 18, 1, 18),
					Position = UDim2.new(0, -9, 0, -9)
				}):Play()
			end
			-- Exposer référence
			local uiRefs = playerGui:FindFirstChild("UIRefs")
			if not uiRefs then uiRefs = Instance.new("Folder"); uiRefs.Name = "UIRefs"; uiRefs.Parent = playerGui end
			local sellRef = uiRefs:FindFirstChild("SellButtonRef")
			if not sellRef then sellRef = Instance.new("ObjectValue"); sellRef.Name = "SellButtonRef"; sellRef.Parent = uiRefs end
			sellRef.Value = sellButton
		else
			-- Nettoyer la référence si le bouton n'existe pas
			local uiRefs = playerGui:FindFirstChild("UIRefs")
			if uiRefs then
				local ref = uiRefs:FindFirstChild("SellButtonRef")
				if ref then ref.Value = nil end
			end
		end
	end

	-- Coins arrondis pour l'esthétique la hotbar (responsive)
	local hotbarCorner = Instance.new("UICorner", hotbarFrame)
	hotbarCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 10)

	local hotbarStroke = Instance.new("UIStroke", hotbarFrame)
	hotbarStroke.Color = Color3.fromRGB(87, 60, 34)
	hotbarStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3

	-- Layout pour les slots de la hotbar (responsive)
	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hotbarLayout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 3 or 5)
	hotbarLayout.Parent = hotbarFrame

	-- Créer les slots de la hotbar (toujours 9 slots, taille responsive)
	local maxSlots = 9  -- Toujours 9 slots comme demandé
	local slotSize = (isMobile or isSmallScreen) and 50 or 70

	for i = 1, maxSlots do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "HotbarSlot_" .. i
		slotFrame.Size = UDim2.new(0, slotSize, 0, slotSize)  -- Taille responsive
		slotFrame.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
		slotFrame.BorderSizePixel = 0
		slotFrame.LayoutOrder = i
		slotFrame.Parent = hotbarFrame

		-- Coins arrondis (responsive)
		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)
		slotCorner.Parent = slotFrame

		-- Bordure du slot (responsive)
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = Color3.fromRGB(87, 60, 34)
		slotStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
		slotStroke.Parent = slotFrame

		-- ViewportFrame pour afficher le modèle 3D (responsive)
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Viewport"
		local viewportPadding = (isMobile or isSmallScreen) and 6 or 10
		local viewportBottom = (isMobile or isSmallScreen) and 10 or 15
		viewport.Size = UDim2.new(1, -viewportPadding, 1, -viewportBottom)
		viewport.Position = UDim2.new(0, viewportPadding/2, 0, viewportPadding/2)
		viewport.BackgroundTransparency = 1
		viewport.BorderSizePixel = 0
		viewport.Parent = slotFrame

		-- Label pour la quantité (responsive)
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "CountLabel"
		local countSize = (isMobile or isSmallScreen) and 16 or 20
		local countHeight = (isMobile or isSmallScreen) and 12 or 15
		countLabel.Size = UDim2.new(0, countSize, 0, countHeight)
		countLabel.Position = UDim2.new(1, -(countSize + 2), 1, -(countHeight + 2))
		countLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		countLabel.BackgroundTransparency = 0.3
		countLabel.BorderSizePixel = 0
		countLabel.Text = ""
		countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		countLabel.TextSize = (isMobile or isSmallScreen) and 10 or 12
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextXAlignment = Enum.TextXAlignment.Center
		countLabel.TextYAlignment = Enum.TextYAlignment.Center
		countLabel.TextScaled = (isMobile or isSmallScreen)  -- Auto-resize sur mobile
		countLabel.Visible = false
		countLabel.Parent = slotFrame

		-- Coins arrondis pour le label (responsive)
		local countCorner = Instance.new("UICorner")
		countCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 3 or 4)
		countCorner.Parent = countLabel

		-- Label pour la rareté (bonbons) - responsive
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "RarityLabel"
		local rarityWidth = (isMobile or isSmallScreen) and 35 or 50
		local rarityHeight = (isMobile or isSmallScreen) and 10 or 12
		rarityLabel.Size = UDim2.new(0, rarityWidth, 0, rarityHeight)
		rarityLabel.Position = UDim2.new(0, 2, 0, 2)
		rarityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		rarityLabel.BackgroundTransparency = 0.4
		rarityLabel.BorderSizePixel = 0
		rarityLabel.Text = ""
		rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		rarityLabel.TextSize = (isMobile or isSmallScreen) and 7 or 8
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
		rarityLabel.TextYAlignment = Enum.TextYAlignment.Center
		rarityLabel.TextScaled = (isMobile or isSmallScreen)  -- Auto-resize sur mobile
		rarityLabel.Visible = false
		rarityLabel.Parent = slotFrame

		-- Coins arrondis pour le label de rareté (responsive)
		local rarityCorner = Instance.new("UICorner")
		rarityCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 2 or 3)
		rarityCorner.Parent = rarityLabel

		-- Bouton invisible pour les interactions
		local slotButton = Instance.new("TextButton")
		slotButton.Size = UDim2.new(1, 0, 1, 0)
		slotButton.BackgroundTransparency = 1
		slotButton.Text = ""
		slotButton.ZIndex = 2
		slotButton.Parent = slotFrame

		-- Événement de clic gauche pour drag and drop / sélection
		slotButton.MouseButton1Click:Connect(function()
			if draggedItem then
				-- On a un item en main : le placer dans ce slot
				local ctrl = isCtrlDown()
				local shift = isShiftDown()

				if ctrl then
					-- Ctrl : Choisir la quantité à placer
					local maxQty = draggedItem.quantity
					showQuantitySelector(draggedItem.tool, maxQty, function(qty)
						placeItemInHotbarSlot(i, false, qty)
					end)
				elseif shift then
					-- Shift : Placer la moitié
					local half = math.max(1, math.floor(draggedItem.quantity / 2))
					placeItemInHotbarSlot(i, false, half)
				else
					-- Clic simple : Placer tout
					placeItemInHotbarSlot(i, true)
				end
			else
				-- Pas d'item en main : prendre depuis le slot (ou juste sélectionner)
				if hotbarTools[i] then
					local ctrl = isCtrlDown()
					local shift = isShiftDown()

					if ctrl or shift then
						-- Prendre avec modificateur
						local tool = hotbarTools[i]
						local maxQty = getToolQuantity(tool)

						if ctrl then
							-- Ctrl : Choisir la quantité
							showQuantitySelector(tool, maxQty, function(qty)
								pickupItemFromSlot(i, qty)
							end)
						elseif shift then
							-- Shift : Prendre la moitié
							local half = math.max(1, math.floor(maxQty / 2))
							pickupItemFromSlot(i, half)
						end
					else
						-- Clic simple : juste sélectionner le slot
						selectHotbarSlot(i)
					end
				else
					-- Slot vide : juste le sélectionner
					selectHotbarSlot(i)
				end
			end
		end)

		-- Événement clic droit pour prendre 1 par 1
		slotButton.MouseButton2Click:Connect(function()
			if draggedItem then
				-- Placer 1 seul
				placeItemInHotbarSlot(i, false, 1)
			else
				-- Prendre 1 seul
				if hotbarTools[i] then
					pickupItemFromSlot(i, 1)
				end
			end
		end)

		-- Événements pour le tooltip (survol PC)
		slotButton.MouseEnter:Connect(function()
			if hotbarTools[i] and not isMobile then
				local absolutePos = slotButton.AbsolutePosition
				local absoluteSize = slotButton.AbsoluteSize
				local centerX = absolutePos.X + absoluteSize.X / 2
				local topY = absolutePos.Y
				showTooltip(hotbarTools[i], Vector2.new(centerX, topY))
			end
		end)

		slotButton.MouseLeave:Connect(function()
			if not isMobile then
				hideTooltip()
			end
		end)

		-- Support mobile : afficher tooltip au toucher (appui long)
		local _touchStartTime = 0
		local touchConnection = nil

		slotButton.InputBegan:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.Touch) and hotbarTools[i] then
				_touchStartTime = tick()

				-- Démarrer un timer pour l'appui long (0.5 secondes)
				touchConnection = task.delay(0.5, function()
					if hotbarTools[i] then
						local absolutePos = slotButton.AbsolutePosition
						local absoluteSize = slotButton.AbsoluteSize
						local centerX = absolutePos.X + absoluteSize.X / 2
						local topY = absolutePos.Y
						showTooltip(hotbarTools[i], Vector2.new(centerX, topY))
					end
				end)
			end
		end)

		slotButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				if touchConnection then
					task.cancel(touchConnection)
					touchConnection = nil
				end
				-- Masquer le tooltip après un court délai
				task.delay(2, function()
					hideTooltip()
				end)
			end
		end)
	end

	-- BOUTON POUR OUVRIR L'INVENTAIRE COMPLET (centré au-dessus de la hotbar) - Responsive
	local inventoryButton = Instance.new("TextButton")
	inventoryButton.Name = "InventoryButton"
	local buttonSize = (isMobile or isSmallScreen) and 40 or 45
	inventoryButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
	-- Centré au-dessus de la hotbar (offset = 0)
	local buttonY = (isMobile or isSmallScreen) and -110 or -125  -- Au-dessus de la hotbar
	inventoryButton.Position = UDim2.new(0.5, 0, 1, buttonY)  -- Centré horizontalement
	inventoryButton.AnchorPoint = Vector2.new(0.5, 0)
	inventoryButton.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
	inventoryButton.BorderSizePixel = 0
	inventoryButton.Text = "↑"
	inventoryButton.TextSize = (isMobile or isSmallScreen) and 18 or 24
	inventoryButton.TextColor3 = Color3.new(1, 1, 1)
	inventoryButton.Font = Enum.Font.GothamBold
	inventoryButton.TextScaled = (isMobile or isSmallScreen)
	inventoryButton.Parent = customBackpack

	local invCorner = Instance.new("UICorner", inventoryButton)
	invCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)

	local invStroke = Instance.new("UIStroke", inventoryButton)
	invStroke.Color = Color3.fromRGB(87, 60, 34)
	invStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2

	-- INVENTAIRE COMPLET (caché au début) - Taille initiale (sera resize dynamiquement)
	inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	local invWidth = (isMobile or isSmallScreen) and 500 or 600
	local invHeight = (isMobile or isSmallScreen) and 550 or 400
	inventoryFrame.Size = UDim2.new(0, invWidth, 0, invHeight)
	inventoryFrame.Position = UDim2.new(0.5, -invWidth/2, 0.5, -invHeight/2)
	inventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	inventoryFrame.BorderSizePixel = 0
	inventoryFrame.Visible = false
	inventoryFrame.Parent = customBackpack

	-- Bordures de l'inventaire (responsive) - Plus clean
	local invFrameCorner = Instance.new("UICorner", inventoryFrame)
	invFrameCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 12)

	local invFrameStroke = Instance.new("UIStroke", inventoryFrame)
	invFrameStroke.Color = Color3.fromRGB(87, 60, 34)
	invFrameStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3  -- Bordure plus fine
	invFrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border  -- Bordure externe uniquement

	-- Titre de l'inventaire (responsive)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -50, 0, (isMobile or isSmallScreen) and 30 or 40)
	titleLabel.Position = UDim2.new(0, (isMobile or isSmallScreen) and 15 or 20, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = (isMobile or isSmallScreen) and "🎒 INV" or "🎒 Inventory"
	titleLabel.TextColor3 = Color3.fromRGB(87, 60, 34)
	titleLabel.TextSize = (isMobile or isSmallScreen) and 18 or 24
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextScaled = (isMobile or isSmallScreen)
	titleLabel.Parent = inventoryFrame

	-- Bouton fermer l'inventaire (responsive)
	local closeButton = Instance.new("TextButton")
	local closeSize = (isMobile or isSmallScreen) and 25 or 30
	closeButton.Size = UDim2.new(0, closeSize, 0, closeSize)
	closeButton.Position = UDim2.new(1, -(closeSize + 10), 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "✕"
	closeButton.TextSize = (isMobile or isSmallScreen) and 14 or 18
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = (isMobile or isSmallScreen)
	closeButton.Parent = inventoryFrame

	local closeCorner = Instance.new("UICorner", closeButton)
	closeCorner.CornerRadius = UDim.new(0, 8)

	-- ScrollingFrame pour tous les tools (responsive)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "AllToolsContainer"
	local scrollMargin = (isMobile or isSmallScreen) and 20 or 40
	local scrollTop = (isMobile or isSmallScreen) and 50 or 60
	scrollFrame.Size = UDim2.new(1, -scrollMargin, 1, -(scrollTop + 20))
	scrollFrame.Position = UDim2.new(0, scrollMargin/2, 0, scrollTop)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(180, 130, 95)
	scrollFrame.BackgroundTransparency = 0.3  -- Légèrement visible
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = (isMobile or isSmallScreen) and 6 or 10
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = inventoryFrame

	-- Coins arrondis et bordure pour le scrollFrame
	local scrollCorner = Instance.new("UICorner", scrollFrame)
	scrollCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)

	local scrollStroke = Instance.new("UIStroke", scrollFrame)
	scrollStroke.Color = Color3.fromRGB(87, 60, 34)
	scrollStroke.Thickness = 1
	scrollStroke.Transparency = 0.5
	scrollStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- Grid layout pour l'inventaire (responsive)
	local gridLayout = Instance.new("UIGridLayout")
	local cellSize = (isMobile or isSmallScreen) and 60 or 80
	local cellPadding = (isMobile or isSmallScreen) and 8 or 12  -- Padding augmenté pour plus d'espace
	gridLayout.CellSize = UDim2.new(0, cellSize, 0, cellSize)
	gridLayout.CellPadding = UDim2.new(0, cellPadding, 0, cellPadding)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center  -- Centrer les items
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame

	-- Padding intérieur pour le scrollFrame
	local scrollPadding = Instance.new("UIPadding")
	scrollPadding.PaddingTop = UDim.new(0, (isMobile or isSmallScreen) and 8 or 12)
	scrollPadding.PaddingBottom = UDim.new(0, (isMobile or isSmallScreen) and 8 or 12)
	scrollPadding.PaddingLeft = UDim.new(0, (isMobile or isSmallScreen) and 8 or 12)
	scrollPadding.PaddingRight = UDim.new(0, (isMobile or isSmallScreen) and 8 or 12)
	scrollPadding.Parent = scrollFrame

	-- Événements
	inventoryButton.MouseButton1Click:Connect(function()
		toggleInventory()
	end)

	closeButton.MouseButton1Click:Connect(function()
		toggleInventory()
	end)


end

-- Créer un slot de la hotbar (Fonction legacy non utilisée)
local function _createHotbarSlot(slotNumber)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "HotbarSlot_" .. slotNumber
	slotFrame.Size = UDim2.new(0, 70, 0, 70) -- Taille plus grosse (70px au lieu de 45px)
	slotFrame.Position = UDim2.new(0, (slotNumber - 1) * 70, 0, 0) -- Espacement ajusté
	slotFrame.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
	slotFrame.BorderSizePixel = 0
	slotFrame.LayoutOrder = slotNumber
	slotFrame.Parent = hotbarFrame

	local slotCorner = Instance.new("UICorner", slotFrame)
	slotCorner.CornerRadius = UDim.new(0, 8)

	local slotStroke = Instance.new("UIStroke", slotFrame)
	slotStroke.Color = Color3.fromRGB(87, 60, 34)
	slotStroke.Thickness = 2

	-- ViewportFrame pour le modèle 3D (plus grand pour les modèles)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, -4, 1, -8) -- Plus grand
	viewport.Position = UDim2.new(0, 2, 0, 2)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Parent = slotFrame

	-- Numéro du slot
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.new(0, 12, 0, 12)
	numberLabel.Position = UDim2.new(0, 2, 0, 2)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(slotNumber)
	numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	numberLabel.TextSize = 8
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.Parent = slotFrame

	-- Label pour afficher la quantité
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 20, 0, 12)
	countLabel.Position = UDim2.new(1, -22, 1, -14) -- Coin bas-droit
	countLabel.BackgroundTransparency = 1
	countLabel.Text = ""
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Jaune pour bien voir
	countLabel.TextSize = 10
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = slotFrame

	-- Label pour afficher la rareté/taille
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, -4, 0, 10)
	rarityLabel.Position = UDim2.new(0, 2, 0, 2) -- Coin haut-gauche
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = ""
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.TextSize = 8
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.TextStrokeTransparency = 0
	rarityLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	rarityLabel.Parent = slotFrame

	-- Bouton invisible pour la détection des clics
	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = slotFrame

	-- Gestion du clic
	clickButton.MouseButton1Click:Connect(function()
		selectHotbarSlot(slotNumber)
	end)

	-- Effet de survol
	clickButton.MouseEnter:Connect(function()
		if selectedSlot ~= slotNumber then
			slotStroke.Color = Color3.fromRGB(255, 200, 100)
			slotStroke.Thickness = 3
		end
	end)

	clickButton.MouseLeave:Connect(function()
		updateHotbarSlotAppearance(slotNumber)
	end)

	return slotFrame
end

-- Sélectionner un slot de la hotbar
function selectHotbarSlot(slotNumber)
	selectedSlot = slotNumber

	-- Vérifier si le tool dans ce slot existe encore
	if hotbarTools[slotNumber] then
		local tool = hotbarTools[slotNumber]
		local toolExists = tool and tool.Parent and (tool.Parent == player.Backpack or tool.Parent == player.Character)
		local count = tool:FindFirstChild("Count")
		local quantity = count and count.Value or 0

		if not toolExists or quantity <= 0 then
			hotbarTools[slotNumber] = nil
			updateAllHotbarSlots()
			return
		end

		-- Équiper le tool correspondant
		if equippedTool == tool then
			unequipTool()
		else
			equipTool(tool)
		end
	else
		unequipTool()
	end

	updateAllHotbarSlots()
end

-- Mettre à jour l'apparence d'un slot de la hotbar
function updateHotbarSlotAppearance(slotNumber)
	local slotFrame = hotbarFrame:FindFirstChild("HotbarSlot_" .. slotNumber)
	if not slotFrame then return end

	local stroke = slotFrame:FindFirstChild("UIStroke")
	if not stroke then return end

	local tool = hotbarTools[slotNumber]
	local isEquipped = (tool and equippedTool == tool)

	if selectedSlot == slotNumber then
		-- Slot sélectionné - bordure dorée épaisse
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Thickness = 4
		slotFrame.BackgroundColor3 = Color3.fromRGB(200, 160, 120)
	elseif isEquipped then
		-- Tool équipé - bordure verte luisante
		stroke.Color = Color3.fromRGB(0, 255, 100)
		stroke.Thickness = 3
		slotFrame.BackgroundColor3 = Color3.fromRGB(160, 190, 140)
	else
		-- Slot normal
		stroke.Color = Color3.fromRGB(87, 60, 34)
		stroke.Thickness = 2
		slotFrame.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
	end
end

-- Mettre à jour tous les slots de la hotbar
function updateAllHotbarSlots()
	-- Vérification de la hotbarFrame
	if not hotbarFrame then
		return
	end

	-- Mettre à jour la liste stable des tools
	updateHotbarToolsList()

	-- Vérification de sécurité
	if not hotbarTools then
		return
	end

	for i = 1, 9 do
		local slotFrame = hotbarFrame:FindFirstChild("HotbarSlot_" .. i)
		if not slotFrame then
			continue
		end

		local viewport = slotFrame:FindFirstChild("Viewport")

		if not viewport then
			continue
		end

		if hotbarTools[i] then
			-- Il y a un tool pour ce slot
			local tool = hotbarTools[i]
			local baseName = tool:GetAttribute("BaseName") or tool.Name
			local count = tool:FindFirstChild("Count")
			local quantity = count and count.Value or 1

			-- Nettoyer le viewport
			for _, child in pairs(viewport:GetChildren()) do
				child:Destroy()
			end

			-- Ajouter le modèle 3D (ingrédients OU candies)
			-- Les Tools utilisent maintenant le nom du modèle directement
			local toolModel = ingredientToolsFolder:FindFirstChild(baseName) or candyModelsFolder:FindFirstChild(tool.Name)
			if toolModel then
				-- Pour les bonbons, utiliser BonbonSkin ou Handle selon disponibilité
				local visualPart = toolModel:FindFirstChild("BonbonSkin") or toolModel:FindFirstChild("Handle")
				if visualPart then
					UIUtils.setupViewportFrame(viewport, visualPart)
				end
			else
				-- Fallback amélioré
				local fallbackLabel = Instance.new("TextLabel")
				fallbackLabel.Size = UDim2.new(1, 0, 1, 0)
				fallbackLabel.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Fond coloré
				fallbackLabel.BackgroundTransparency = 0.3
				fallbackLabel.BorderSizePixel = 0
				fallbackLabel.Text = baseName:sub(1, 2):upper()
				fallbackLabel.TextColor3 = Color3.new(1, 1, 1)
				fallbackLabel.TextSize = 18 -- Plus gros
				fallbackLabel.Font = Enum.Font.GothamBold
				fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
				fallbackLabel.TextYAlignment = Enum.TextYAlignment.Center
				fallbackLabel.Parent = viewport

				-- Bordures arrondies
				local fbCorner = Instance.new("UICorner", fallbackLabel)
				fbCorner.CornerRadius = UDim.new(0, 6)

				-- Contour du texte
				local fbStroke = Instance.new("UIStroke", fallbackLabel)
				fbStroke.Color = Color3.fromRGB(0, 0, 0)
				fbStroke.Thickness = 2
			end

			-- Afficher la quantité dans le label (pour tous les cas)
			local countLabel = slotFrame:FindFirstChild("CountLabel")
			if countLabel then
				if quantity > 1 then
					countLabel.Text = tostring(quantity)
					countLabel.Visible = true
				else
					countLabel.Visible = false -- Cacher si quantité = 1
				end
			end

			-- Afficher les infos de rareté (bonbons ET ingrédients)
			local rarityLabel = slotFrame:FindFirstChild("RarityLabel")
			if rarityLabel and tool then
				local sizeData = nil
				local rarityInfo = nil

				-- Pour les bonbons : utiliser CandySizeManager
				if CandySizeManager and tool:GetAttribute("IsCandy") then
					sizeData = CandySizeManager.getSizeDataFromTool(tool)
					if sizeData then
						rarityInfo = {
							text = sizeData.rarity,
							color = sizeData.color
						}
					end
				end

				-- Pour les ingrédients : utiliser RecipeManager
				if not rarityInfo and tool:GetAttribute("BaseName") then
					local ingredientBaseName = tool:GetAttribute("BaseName")
					-- Essayer de récupérer la rareté depuis RecipeManager
					local recipeManager = nil
					local success, result = pcall(function()
						return require(ReplicatedStorage:FindFirstChild("RecipeManager"))
					end)
					if success and result then
						recipeManager = result
					end

					if recipeManager and recipeManager.Ingredients and recipeManager.Ingredients[ingredientBaseName] then
						local ingredientData = recipeManager.Ingredients[ingredientBaseName]
						rarityInfo = {
							text = ingredientData.rarete or "Commune",
							color = ingredientData.couleurRarete or Color3.fromRGB(150, 150, 150)
						}
					end
				end

				-- Afficher la rareté si disponible
				if rarityInfo then
					rarityLabel.Text = rarityInfo.text
					rarityLabel.TextColor3 = rarityInfo.color
					rarityLabel.Visible = true
				else
					rarityLabel.Visible = false
				end
			elseif rarityLabel then
				rarityLabel.Visible = false
			end
		else
			-- Slot vide
			for _, child in pairs(viewport:GetChildren()) do
				child:Destroy()
			end

			-- Cacher les labels pour les slots vides
			local countLabel = slotFrame:FindFirstChild("CountLabel")
			if countLabel then
				countLabel.Visible = false
			end

			local rarityLabel = slotFrame:FindFirstChild("RarityLabel")
			if rarityLabel then
				rarityLabel.Visible = false
			end
		end

		updateHotbarSlotAppearance(i)
	end
end

-- Obtenir la liste des tools du backpack + équipé
function getBackpackTools()
	local tools = {}

	-- Ajouter les tools du backpack
	for _, tool in pairs(player.Backpack:GetChildren()) do
		if tool:IsA("Tool") then
			table.insert(tools, tool)
		end
	end

	-- 🔧 CORRECTION: Ajouter TOUS les tools équipés dans le character (plus fiable)
	if player.Character then
		for _, tool in pairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	return tools
end

-- Mettre à jour la liste stable de la hotbar
function updateHotbarToolsList()
	local allTools = getBackpackTools()

	-- Conserver les tools existants à leur position
	for i = 1, 9 do
		if hotbarTools[i] then
			local toolStillExists = false
			local tool = hotbarTools[i]

			-- Vérification STRICTE : le tool doit encore exister ET avoir un parent valide
			if tool and tool.Parent and (tool.Parent == player.Backpack or tool.Parent == player.Character) then
				-- Vérifier aussi que le Count est valide (> 0)
				local count = tool:FindFirstChild("Count")
				local quantity = count and count.Value or 1

				if quantity > 0 then
					-- Vérifier qu'il est dans la liste des tools actifs
					for _, activeTool in pairs(allTools) do
						if activeTool == tool then
							toolStillExists = true
							break
						end
					end
				else
				end
			end

			-- Si le tool n'existe plus, le retirer de la hotbar
			if not toolStillExists then
				hotbarTools[i] = nil
			end
		end
	end

	-- Ajouter les nouveaux tools aux slots libres
	for _, tool in pairs(allTools) do
		local alreadyInHotbar = false
		for i = 1, 9 do
			if hotbarTools[i] == tool then
				alreadyInHotbar = true
				break
			end
		end

		-- Si le tool n'est pas encore dans la hotbar, l'ajouter au premier slot libre
		if not alreadyInHotbar then
			for i = 1, 9 do
				if not hotbarTools[i] then
					hotbarTools[i] = tool
					break
				end
			end
		end
	end
end

-- Basculer l'inventaire complet (responsive)
function toggleInventory()
	isInventoryOpen = not isInventoryOpen

	if isInventoryOpen then
		inventoryFrame.Visible = true

		-- S'assurer que le masque est visible aussi
		if inventoryFrame.Parent and inventoryFrame.Parent.Name == "InventoryMask" then
			inventoryFrame.Parent.Visible = true
		end

		-- RECALCULER et SYNCHRONISER la détection de plateforme à chaque ouverture
		updateResponsiveDetection()

		-- Calculer les dimensions de l'inventaire avec effet masque
		local targetWidth = (isMobile or isSmallScreen) and math.min(viewportSize.X * 0.85, 420) or 500
		local targetHeight = (isMobile or isSmallScreen) and math.min(viewportSize.Y * 0.6, 350) or 400

		-- Position du masque aligné avec la hotbar (même rail)
		local hotbarY = (isMobile or isSmallScreen) and -65 or -80
		local maskY = hotbarY - targetHeight - 5  -- 5px au-dessus de la hotbar

		-- Alignement horizontal avec la hotbar (même rail)
		local hotbarX = (isMobile or isSmallScreen) and -190 or -315  -- Même position X que la hotbar

		-- Créer/mettre à jour le ClipFrame (masque) aligné avec la hotbar
		if not inventoryFrame.Parent or inventoryFrame.Parent.Name ~= "InventoryMask" then
			local maskFrame = Instance.new("Frame")
			maskFrame.Name = "InventoryMask"
			maskFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
			maskFrame.Position = UDim2.new(0.5, hotbarX, 1, maskY)  -- Même rail que hotbar
			maskFrame.AnchorPoint = Vector2.new(0, 0)
			maskFrame.BackgroundTransparency = 1  -- Invisible, juste pour le clipping
			maskFrame.ClipsDescendants = true  -- EFFET MASQUE !
			maskFrame.Parent = customBackpack

			-- Reparenter l'inventaire dans le masque
			inventoryFrame.Parent = maskFrame
		else
			-- Mettre à jour la position du masque existant
			local maskFrame = inventoryFrame.Parent
			maskFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
			maskFrame.Position = UDim2.new(0.5, hotbarX, 1, maskY)  -- Même rail que hotbar
			maskFrame.ClipsDescendants = true  -- EFFET MASQUE !
		end

		-- Position de l'inventaire DANS le masque
		inventoryFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
		inventoryFrame.AnchorPoint = Vector2.new(0, 0)

		-- Sur mobile, positionner directement visible (sans animation de glissement)
		-- Sur PC, démarrer caché en bas pour l'animation
		if isMobile then
			inventoryFrame.Position = UDim2.new(0, 0, 0, 0)  -- Position visible directement
		else
			inventoryFrame.Position = UDim2.new(0, 0, 0, targetHeight)  -- Caché en-dessous du masque
		end

		-- Animation de coulissement vertical (de BAS en HAUT dans le masque) - UNIQUEMENT SUR PC
		if not isMobile then
			local tween = TweenService:Create(inventoryFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0)  -- Glisse depuis le bas vers la position visible
			})
			tween:Play()
		end

		-- Mettre à jour le contenu
		updateInventoryContent()
	else
		-- Fermeture de l'inventaire
		if isMobile then
			-- Sur mobile, cacher directement sans animation
			inventoryFrame.Visible = false
			if inventoryFrame.Parent and inventoryFrame.Parent.Name == "InventoryMask" then
				inventoryFrame.Parent.Visible = false
			end
		else
			-- Animation de coulissement vers le bas (disparition dans le masque) - UNIQUEMENT PC
			local tween = TweenService:Create(inventoryFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Position = UDim2.new(0, 0, 0, inventoryFrame.Size.Y.Offset)  -- Glisse vers le bas du masque
			})
			tween:Play()

			tween.Completed:Connect(function()
				inventoryFrame.Visible = false
				-- Optionnel : cacher aussi le masque
				if inventoryFrame.Parent and inventoryFrame.Parent.Name == "InventoryMask" then
					inventoryFrame.Parent.Visible = false
				end
			end)
		end
	end
end

-- Créer un slot d'inventaire complet (responsive)
local function createInventorySlot(tool, layoutOrder)
	local baseName = tool:GetAttribute("BaseName") or tool.Name
	local count = tool:FindFirstChild("Count")
	local _quantity = count and count.Value or 1

	-- Frame du slot (responsive - taille gérée par le grid layout)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "InventorySlot_" .. tool.Name
	slotFrame.Size = UDim2.new(0, 50, 0, 50)  -- Taille minimale, sera remplacée par le grid layout
	slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
	slotFrame.BorderSizePixel = 0
	slotFrame.LayoutOrder = layoutOrder

	-- 🔧 CORRECTION: Stocker la référence du tool dans le slot pour identification unique
	local toolRef = Instance.new("ObjectValue")
	toolRef.Name = "ToolReference"
	toolRef.Value = tool
	toolRef.Parent = slotFrame

	local slotCorner = Instance.new("UICorner", slotFrame)
	slotCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)

	local slotStroke = Instance.new("UIStroke", slotFrame)
	slotStroke.Color = Color3.fromRGB(87, 60, 34)
	slotStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
	slotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border  -- Bordure externe seulement

	-- ViewportFrame pour le modèle 3D (responsive - marges réduites)
	local viewport = Instance.new("ViewportFrame")
	-- Marges réduites pour mieux afficher les items
	local vpMargin = (isMobile or isSmallScreen) and 3 or 4
	viewport.Size = UDim2.new(1, -vpMargin*2, 1, -vpMargin*2)
	viewport.Position = UDim2.new(0, vpMargin, 0, vpMargin)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Parent = slotFrame

	-- Chercher et afficher le modèle 3D (ingrédients OU candies)
	-- Les Tools utilisent maintenant le nom du modèle directement
	local toolModel = ingredientToolsFolder:FindFirstChild(baseName) or candyModelsFolder:FindFirstChild(tool.Name)
	if toolModel then
		-- Pour les bonbons, utiliser BonbonSkin ou Handle selon disponibilité
		local visualPart = toolModel:FindFirstChild("BonbonSkin") or toolModel:FindFirstChild("Handle")
		if visualPart then
			UIUtils.setupViewportFrame(viewport, visualPart)
		else
			-- Fallback amélioré pour l'inventaire (avec marges)
			local fallbackLabel = Instance.new("TextLabel")
			fallbackLabel.Size = UDim2.new(1, -8, 1, -8)
			fallbackLabel.Position = UDim2.new(0, 4, 0, 4)
			fallbackLabel.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Fond coloré
			fallbackLabel.BackgroundTransparency = 0.3
			fallbackLabel.BorderSizePixel = 0
			fallbackLabel.Text = baseName:sub(1, 2):upper()
			fallbackLabel.TextColor3 = Color3.new(1, 1, 1)
			fallbackLabel.TextSize = (isMobile or isSmallScreen) and 16 or 20
			fallbackLabel.Font = Enum.Font.GothamBold
			fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
			fallbackLabel.TextYAlignment = Enum.TextYAlignment.Center
			fallbackLabel.Parent = viewport

			-- Bordures arrondies
			local fbCorner = Instance.new("UICorner", fallbackLabel)
			fbCorner.CornerRadius = UDim.new(0, 6)

			-- Contour du texte
			local fbStroke = Instance.new("UIStroke", fallbackLabel)
			fbStroke.Color = Color3.fromRGB(0, 0, 0)
			fbStroke.Thickness = 1
		end
	else
		-- Fallback amélioré pour l'inventaire (avec marges)
		local fallbackLabel = Instance.new("TextLabel")
		fallbackLabel.Size = UDim2.new(1, -8, 1, -8)
		fallbackLabel.Position = UDim2.new(0, 4, 0, 4)
		fallbackLabel.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Fond coloré
		fallbackLabel.BackgroundTransparency = 0.3
		fallbackLabel.BorderSizePixel = 0
		fallbackLabel.Text = baseName:sub(1, 2):upper()
		fallbackLabel.TextColor3 = Color3.new(1, 1, 1)
		fallbackLabel.TextSize = (isMobile or isSmallScreen) and 16 or 20
		fallbackLabel.Font = Enum.Font.GothamBold
		fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
		fallbackLabel.TextYAlignment = Enum.TextYAlignment.Center
		fallbackLabel.Parent = viewport

		-- Bordures arrondies
		local fbCorner = Instance.new("UICorner", fallbackLabel)
		fbCorner.CornerRadius = UDim.new(0, 6)

		-- Contour du texte
		local fbStroke = Instance.new("UIStroke", fallbackLabel)
		fbStroke.Color = Color3.fromRGB(0, 0, 0)
		fbStroke.Thickness = 1
	end

	-- Label de quantité responsive dans l'inventaire (TOUJOURS visible)
	local displayQuantity = getToolQuantity(tool)

	-- Créer le label de quantité (visible même pour quantité = 1)
	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "QuantityLabel"
	quantityLabel.Size = UDim2.new(0, (isMobile or isSmallScreen) and 25 or 30, 0, (isMobile or isSmallScreen) and 16 or 20)
	quantityLabel.Position = UDim2.new(1, -((isMobile or isSmallScreen) and 27 or 32), 1, -((isMobile or isSmallScreen) and 18 or 22))
	quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	quantityLabel.BackgroundTransparency = 0.3
	quantityLabel.BorderSizePixel = 0
	quantityLabel.Text = "x" .. tostring(displayQuantity)
	quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	quantityLabel.TextSize = (isMobile or isSmallScreen) and 10 or 12
	quantityLabel.Font = Enum.Font.GothamBold
	quantityLabel.TextXAlignment = Enum.TextXAlignment.Center
	quantityLabel.TextYAlignment = Enum.TextYAlignment.Center
	quantityLabel.TextScaled = false
	quantityLabel.ZIndex = 3  -- Au-dessus du viewport
	quantityLabel.Parent = slotFrame

	local qCorner = Instance.new("UICorner", quantityLabel)
	qCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 4 or 6)

	local qStroke = Instance.new("UIStroke", quantityLabel)
	qStroke.Color = Color3.fromRGB(87, 60, 34)
	qStroke.Thickness = 1

	-- Label pour la rareté/taille (bonbons ET ingrédients) - responsive
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	local rarityWidth = (isMobile or isSmallScreen) and 40 or 55
	local rarityHeight = (isMobile or isSmallScreen) and 12 or 14
	rarityLabel.Size = UDim2.new(0, rarityWidth, 0, rarityHeight)
	rarityLabel.Position = UDim2.new(0, 2, 0, 2)
	rarityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	rarityLabel.BackgroundTransparency = 0.4
	rarityLabel.BorderSizePixel = 0
	rarityLabel.Text = ""
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.TextSize = (isMobile or isSmallScreen) and 8 or 9
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
	rarityLabel.TextYAlignment = Enum.TextYAlignment.Center
	rarityLabel.TextScaled = (isMobile or isSmallScreen)
	rarityLabel.ZIndex = 3
	rarityLabel.Visible = false
	rarityLabel.Parent = slotFrame

	-- Coins arrondis pour le label de rareté
	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 3 or 4)
	rarityCorner.Parent = rarityLabel

	-- Récupérer et afficher les infos de rareté/taille
	local sizeData = nil
	local rarityInfo = nil

	-- Pour les bonbons : utiliser CandySizeManager
	if CandySizeManager and tool:GetAttribute("IsCandy") then
		sizeData = CandySizeManager.getSizeDataFromTool(tool)
		if sizeData then
			rarityInfo = {
				text = sizeData.rarity,
				color = sizeData.color
			}
		end
	end

	-- Pour les ingrédients : utiliser RecipeManager
	if not rarityInfo and tool:GetAttribute("BaseName") then
		local ingredientBaseName = tool:GetAttribute("BaseName")
		-- Essayer de récupérer la rareté depuis RecipeManager
		local recipeManager = nil
		local success, result = pcall(function()
			return require(ReplicatedStorage:FindFirstChild("RecipeManager"))
		end)
		if success and result then
			recipeManager = result
		end

		if recipeManager and recipeManager.Ingredients and recipeManager.Ingredients[ingredientBaseName] then
			local ingredientData = recipeManager.Ingredients[ingredientBaseName]
			rarityInfo = {
				text = ingredientData.rarete or "Commune",
				color = ingredientData.couleurRarete or Color3.fromRGB(150, 150, 150)
			}
		end
	end

	-- Afficher la rareté si disponible
	if rarityInfo then
		rarityLabel.Text = rarityInfo.text
		rarityLabel.TextColor3 = rarityInfo.color
		rarityLabel.Visible = true
	else
		rarityLabel.Visible = false
	end

	-- Bouton invisible pour la détection des clics
	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = slotFrame

	-- Gestion du clic gauche pour drag and drop
	clickButton.MouseButton1Click:Connect(function()
		if draggedItem then
			-- Si on a un item en main et qu'on clique sur un slot d'inventaire, l'item retourne dans l'inventaire
			stopCursorFollow()
		else
			-- Prendre l'item de l'inventaire
			local ctrl = isCtrlDown()
			local shift = isShiftDown()
			local totalQty = getToolQuantity(tool)

			if ctrl then
				-- Ctrl : Choisir la quantité
				showQuantitySelector(tool, totalQty, function(qty)
					pickupItemFromTool(tool, qty)
				end)
			elseif shift then
				-- Shift : Prendre la moitié
				local half = math.max(1, math.floor(totalQty / 2))
				pickupItemFromTool(tool, half)
			else
				-- Clic simple : Prendre tout
				pickupItemFromTool(tool, totalQty)
			end
		end
	end)

	-- Gestion du clic droit pour prendre 1 par 1
	clickButton.MouseButton2Click:Connect(function()
		if not draggedItem then
			pickupItemFromTool(tool, 1)
		else
			-- Si on a déjà un item, le relâcher
			stopCursorFollow()
		end
	end)

	-- Événements pour le tooltip (survol PC)
	clickButton.MouseEnter:Connect(function()
		if not isMobile then
			local absolutePos = clickButton.AbsolutePosition
			local absoluteSize = clickButton.AbsoluteSize
			local centerX = absolutePos.X + absoluteSize.X / 2
			local topY = absolutePos.Y
			showTooltip(tool, Vector2.new(centerX, topY))
		end
	end)

	clickButton.MouseLeave:Connect(function()
		if not isMobile then
			hideTooltip()
		end
	end)

	-- Support mobile : afficher tooltip au toucher (appui long)
	local _touchStartTime = 0
	local touchConnection = nil

	clickButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			_touchStartTime = tick()

			-- Démarrer un timer pour l'appui long (0.5 secondes)
			touchConnection = task.delay(0.5, function()
				local absolutePos = clickButton.AbsolutePosition
				local absoluteSize = clickButton.AbsoluteSize
				local centerX = absolutePos.X + absoluteSize.X / 2
				local topY = absolutePos.Y
				showTooltip(tool, Vector2.new(centerX, topY))
			end)
		end
	end)

	clickButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if touchConnection then
				task.cancel(touchConnection)
				touchConnection = nil
			end
			-- Masquer le tooltip après un court délai
			task.delay(2, function()
				hideTooltip()
			end)
		end
	end)

	return slotFrame
end

-- Planifier une mise à jour de l'inventaire avec debounce (évite les appels multiples)
scheduleInventoryUpdate = function()
	if inventoryUpdateScheduled then return end  -- Déjà planifié

	inventoryUpdateScheduled = true
	task.delay(inventoryUpdateDebounce, function()
		inventoryUpdateScheduled = false
		updateInventoryContent()
	end)
end

-- Mettre à jour le contenu de l'inventaire complet (optimisé - ne recharge QUE si nécessaire)
updateInventoryContent = function()
	if not inventoryFrame then return end
	if not isInventoryOpen then return end  -- Ne rien faire si l'inventaire est fermé

	-- IMPORTANT : Mettre à jour la détection responsive avant de créer les slots
	updateResponsiveDetection()

	local scrollFrame = inventoryFrame:FindFirstChild("AllToolsContainer")
	if not scrollFrame then return end

	-- Mettre à jour le grid layout avec les bonnes dimensions (5 items par ligne)
	local gridLayout = scrollFrame:FindFirstChild("UIGridLayout")
	if gridLayout then
		-- Calculer la taille pour avoir 5 items par ligne
		local scrollWidth = scrollFrame.AbsoluteSize.X
		local cellPadding = (isMobile or isSmallScreen) and 6 or 8
		local totalPadding = cellPadding * 6  -- 5 items = 6 espaces (gauche + 4 entre + droite)
		local cellSize = math.floor((scrollWidth - totalPadding) / 5)

		gridLayout.CellSize = UDim2.new(0, cellSize, 0, cellSize)
		gridLayout.CellPadding = UDim2.new(0, cellPadding, 0, cellPadding)
	end

	-- Obtenir tous les tools disponibles
	local allTools = getBackpackTools()

	-- 🔧 CORRECTION: Créer un index des tools qui NE DOIVENT PAS apparaître dans l'inventaire
	local toolsInHotbar = {}
	for i = 1, 9 do
		if hotbarTools[i] then
			toolsInHotbar[hotbarTools[i]] = true
		end
	end

	-- Créer un index des tools actuels pour comparaison rapide (SANS ceux dans la hotbar)
	local currentToolsIndex = {}
	for _, tool in pairs(allTools) do
		-- 🔧 CORRECTION: Ignorer STRICTEMENT les tools dans la hotbar
		if not toolsInHotbar[tool] then
			currentToolsIndex[tool] = true
		end
	end

	-- 🔧 CORRECTION: Créer un mapping des slots existants vers leurs tools réels (par référence unique)
	local slotToTool = {}
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:find("InventorySlot_") then
			-- 🔧 CORRECTION: Utiliser la référence ObjectValue au lieu du nom
			local toolRef = child:FindFirstChild("ToolReference")
			if toolRef and toolRef:IsA("ObjectValue") and toolRef.Value then
				slotToTool[child] = toolRef.Value
			end
		end
	end

	-- Supprimer les slots dont les tools n'existent plus OU sont maintenant dans la hotbar
	for slot, tool in pairs(slotToTool) do
		-- Vérifier si ce tool spécifique existe encore dans currentToolsIndex
		if not currentToolsIndex[tool] then
			-- Le tool n'existe plus OU est dans la hotbar
			slot:Destroy()
		end
	end

	-- 🔧 CORRECTION: Créer un index des tools qui ont déjà un slot (par référence unique)
	local toolsWithSlots = {}
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:find("InventorySlot_") then
			-- 🔧 CORRECTION: Utiliser la référence ObjectValue au lieu du nom
			local toolRef = child:FindFirstChild("ToolReference")
			if toolRef and toolRef:IsA("ObjectValue") and toolRef.Value then
				local tool = toolRef.Value
				-- Vérifier que ce tool est toujours dans currentToolsIndex
				if currentToolsIndex[tool] then
					toolsWithSlots[tool] = true
				end
			end
		end
	end

	local layoutOrder = #scrollFrame:GetChildren()

	for tool, _ in pairs(currentToolsIndex) do
		-- Si le tool n'a pas encore de slot, en créer un
		if not toolsWithSlots[tool] then
			layoutOrder = layoutOrder + 1
			local slot = createInventorySlot(tool, layoutOrder)
			if slot then
				slot.Parent = scrollFrame
			end
		end
	end

	-- Compter le nombre de tools dans la hotbar
	local hotbarCount = 0
	for _ in pairs(toolsInHotbar) do
		hotbarCount = hotbarCount + 1
	end
end

-- Équiper un tool
function equipTool(tool)
	if equippedTool then
		unequipTool()
	end

	equippedTool = tool
	tool.Parent = player.Character

	-- Mettre à jour l'affichage
	updateAllHotbarSlots()
	if isInventoryOpen then
		scheduleInventoryUpdate()
	end
end

-- Déséquiper le tool actuel
function unequipTool()
	if equippedTool and equippedTool.Parent == player.Character then
		equippedTool.Parent = player.Backpack

	end

	equippedTool = nil

	-- Mettre à jour l'affichage
	updateAllHotbarSlots()
	if isInventoryOpen then
		scheduleInventoryUpdate()
	end
end

-- Surveiller les changements dans le backpack ET character
local function setupBackpackWatcher()
	local backpack = player:WaitForChild("Backpack")

	backpack.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			local baseName = tool:GetAttribute("BaseName") or tool.Name
			local count = tool:FindFirstChild("Count")
			local _quantity = count and count.Value or 1

			-- Si ce tool était équipé et revient dans le backpack, mettre à jour equippedTool
			if equippedTool == tool then
				equippedTool = nil
			end

			-- Mise à jour immédiate sans délai
			updateAllHotbarSlots()

			if isInventoryOpen then
				scheduleInventoryUpdate()
			end
		end
	end)

	backpack.ChildRemoved:Connect(function(tool)
		if tool:IsA("Tool") then
			local _baseName = tool:GetAttribute("BaseName") or tool.Name

			-- Mise à jour immédiate
			updateAllHotbarSlots()
			if isInventoryOpen then
				scheduleInventoryUpdate()
			end
		end
	end)

	-- 🔧 NOUVEAU: Surveiller les changements dans le Character pour synchroniser equippedTool
	local function setupCharacterWatcher(character)
		if not character then return end

		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				local baseName = child:GetAttribute("BaseName") or child.Name
				equippedTool = child

				-- Mettre à jour l'affichage
				updateAllHotbarSlots()
				if isInventoryOpen then
					scheduleInventoryUpdate()
				end
			end
		end)

		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and equippedTool == child then
				local baseName = child:GetAttribute("BaseName") or child.Name
				equippedTool = nil

				-- Mettre à jour l'affichage
				updateAllHotbarSlots()
				if isInventoryOpen then
					scheduleInventoryUpdate()
				end
			end
		end)
	end

	-- Surveiller le character actuel et futurs
	if player.Character then
		setupCharacterWatcher(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacterWatcher)

	-- Surveillance des changements de Count dans les tools existants
	local function watchToolCount(tool)
		local count = tool:FindFirstChild("Count")
		if count then
			-- 🔧 CORRECTION: Utiliser un debounce pour éviter les boucles infinies
			local lastUpdate = 0
			count.Changed:Connect(function(newValue)
				local now = tick()
				if now - lastUpdate < 0.1 then return end -- Ignorer les changements trop rapides
				lastUpdate = now

				-- Mise à jour avec délai pour éviter les boucles
				task.delay(0.05, function()
					updateAllHotbarSlots()
					if isInventoryOpen then
						scheduleInventoryUpdate()
					end
				end)
			end)

			-- Surveiller aussi la destruction directe du tool
			tool.AncestryChanged:Connect(function()
				if tool.Parent == nil then
					task.delay(0.05, function()
						updateAllHotbarSlots()
						if isInventoryOpen then
							scheduleInventoryUpdate()
						end
					end)
				end
			end)
		end
	end

	-- Surveiller les tools déjà présents
	for _, existingTool in pairs(backpack:GetChildren()) do
		if existingTool:IsA("Tool") then
			watchToolCount(existingTool)
		end
	end

	-- Surveiller les nouveaux tools pour leurs changements de Count
	backpack.ChildAdded:Connect(function(tool)
		if tool:IsA("Tool") then
			-- Tentative sans délai; si Count manque, on mettra à jour sur le prochain Changed
			watchToolCount(tool)
		end
	end)
end

-- Gestion des raccourcis clavier - REACTIVÉ
local function setupHotkeys()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Vérifier que le jeu n'a pas déjà traité l'input ET que c'est bien un clavier
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		-- Vérifier qu'aucun chat/GUI modal n'est actif
		if UserInputService:GetFocusedTextBox() then return end

		local keyCode = input.KeyCode

		-- Touche Escape pour annuler le drag
		if keyCode == Enum.KeyCode.Escape then
			if draggedItem then
				stopCursorFollow()
				return
			end
		end

		-- Touches 1-6 pour sélectionner les slots de la hotbar (focus sur 1-6)
		if keyCode == Enum.KeyCode.One or keyCode == Enum.KeyCode.Two or keyCode == Enum.KeyCode.Three or 
			keyCode == Enum.KeyCode.Four or keyCode == Enum.KeyCode.Five or keyCode == Enum.KeyCode.Six then

			local numbers = {
				[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
				[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6
			}

			local slotNumber = numbers[keyCode]
			selectHotbarSlot(slotNumber)

			-- Touches 7-9 pour d'autres slots si nécessaire
		elseif keyCode == Enum.KeyCode.Seven or keyCode == Enum.KeyCode.Eight or keyCode == Enum.KeyCode.Nine then
			local numbers = {
				[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9
			}

			local slotNumber = numbers[keyCode]
			selectHotbarSlot(slotNumber)
		end

		-- Touche TAB pour ouvrir/fermer l'inventaire complet
		if keyCode == Enum.KeyCode.Tab then
			toggleInventory()
		end
	end)
end

-- Initialisation
local function initialize()


	-- Attendre que le joueur soit chargé
	player.CharacterAdded:Wait()
	wait(2) -- Laisser le temps à tout de se charger

	print("🎒 [BACKPACK] Initialisation du backpack personnalisé...")

	-- Désactiver le backpack par défaut
	disableDefaultBackpack()

	-- Créer le backpack personnalisé
	createCustomBackpack()
	
	-- Vérifier que l'UI a bien été créée
	if not customBackpack or not hotbarFrame then
		warn("❌ [BACKPACK] Échec de création de l'UI, retry dans 2 secondes...")
		task.wait(2)
		createCustomBackpack()
		
		-- Dernière vérification
		if not customBackpack or not hotbarFrame then
			error("❌ [BACKPACK] Impossible de créer l'UI après retry")
		end
	end
	
	print("✅ [BACKPACK] UI créée avec succès")

	-- Configurer la surveillance
	setupBackpackWatcher()
	setupHotkeys()

	-- Gérer le clic dans le vide pour relâcher l'item
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Clic gauche dans le vide = relâcher l'objet
		if input.UserInputType == Enum.UserInputType.MouseButton1 and draggedItem and not gameProcessed then
			stopCursorFollow()
		end
	end)

	-- Mise à jour initiale avec debug


	-- Forcer la détection immédiate des tools existants
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local baseName = tool:GetAttribute("BaseName") or tool.Name
				local count = tool:FindFirstChild("Count")
				local quantity = count and count.Value or 1
			end
		end
	end

	updateAllHotbarSlots()

	-- Nettoyage périodique pour éliminer les tools fantômes
	task.spawn(function()
		while true do
			wait(2) -- Vérifier toutes les 2 secondes

			local needsUpdate = false
			for i = 1, 9 do
				if hotbarTools[i] then
					local tool = hotbarTools[i]
					local toolExists = tool and tool.Parent and (tool.Parent == player.Backpack or tool.Parent == player.Character)
					local count = tool:FindFirstChild("Count")
					local quantity = count and count.Value or 0

					if not toolExists or quantity <= 0 then
						hotbarTools[i] = nil
						needsUpdate = true
					end
				end
			end

			if needsUpdate then
				updateAllHotbarSlots()
				if isInventoryOpen then
					scheduleInventoryUpdate()
				end
			end
		end
	end)

end

-- Exposer les fonctions nécessaires pour la synchronisation avec les plateformes
-- 🎮 Fonctions pour navigation manette
local function selectNextSlot()
	local nextSlot = selectedSlot + 1
	if nextSlot > 9 then nextSlot = 1 end
	selectHotbarSlot(nextSlot)
end

local function selectPreviousSlot()
	local prevSlot = selectedSlot - 1
	if prevSlot < 1 then prevSlot = 9 end
	selectHotbarSlot(prevSlot)
end

-- 🎮 Écouter les inputs manette pour R1/L1
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Vérifier si les contrôles gamepad sont activés
	if _G.CustomBackpack and _G.CustomBackpack.gamepadEnabled == false then
		return -- Désactivé (ex: menu incubateur ouvert)
	end
	
	-- R1 pour slot suivant
	if input.KeyCode == Enum.KeyCode.ButtonR1 then
		selectNextSlot()
	end
	
	-- L1 pour slot précédent
	if input.KeyCode == Enum.KeyCode.ButtonL1 then
		selectPreviousSlot()
	end
end)

_G.CustomBackpack = {
	updateAllHotbarSlots = updateAllHotbarSlots,
	scheduleInventoryUpdate = scheduleInventoryUpdate,
	updateHotbarToolsList = updateHotbarToolsList,
	selectNextSlot = selectNextSlot,
	selectPreviousSlot = selectPreviousSlot,
	gamepadEnabled = true -- Flag pour activer/désactiver les contrôles gamepad
}

-- Démarrage
initialize() 