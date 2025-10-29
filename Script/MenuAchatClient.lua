-- Ce script (local) gère le menu d'achat d'ingrédients responsive.
-- Version 3.0 : Refonte visuelle inspirée du style "simulateur" avec adaptation mobile.
-- À placer dans une ScreenGui dans StarterGui.

local player = game:GetService("Players").LocalPlayer
local _playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Forcer le ScreenGui du menu à passer devant tout
pcall(function()
	if screenGui and screenGui:IsA("ScreenGui") then
		screenGui.DisplayOrder = 1000
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	end
end)

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

-- Détection plateforme pour interface responsive (mobile = tactile uniquement)
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
-- Z-Index base pour s'assurer que tous les éléments du menu restent au-dessus
local Z_BASE = 1500

-- Modules
local RecipeManager do
	local modInst = ReplicatedStorage:FindFirstChild("RecipeManager")
	if modInst and modInst:IsA("ModuleScript") then
		local ok, mod = pcall(require, modInst)
		if ok and type(mod) == "table" then
			RecipeManager = mod
		else
			RecipeManager = { Ingredients = {}, IngredientOrder = {} }
		end
	else
		RecipeManager = { Ingredients = {}, IngredientOrder = {} }
	end
end

local UIUtils do
	local modInst = ReplicatedStorage:FindFirstChild("UIUtils")
	if modInst and modInst:IsA("ModuleScript") then
		local ok, mod = pcall(require, modInst)
		if ok and type(mod) == "table" then
			UIUtils = mod
		else
			UIUtils = nil
		end
	else
		UIUtils = nil
	end
end

-- 🔄 RemoteFunction pour récupérer le stock personnel du joueur
local getPlayerStockFunc = ReplicatedStorage:WaitForChild("GetPlayerStock")

-- 🔄 RemoteEvent pour recevoir les mises à jour de stock en temps réel
local updateStockEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerStock")
if not updateStockEvent then
	updateStockEvent = Instance.new("RemoteEvent")
	updateStockEvent.Name = "UpdatePlayerStock"
	updateStockEvent.Parent = ReplicatedStorage
end

-- 🔄 Cache local du stock personnel
local playerStock = {}

-- Dossier de stock pour le timer de restock (toujours global)
local shopStockFolder = ReplicatedStorage:WaitForChild("ShopStock")

-- RemoteEvents
local ouvrirMenuEvent = ReplicatedStorage:WaitForChild("OuvrirMenuEvent")
local achatIngredientEvent = ReplicatedStorage:WaitForChild("AchatIngredientEvent_V2")
local forceRestockEvent = ReplicatedStorage:WaitForChild("ForceRestockEvent")
local upgradeEvent = ReplicatedStorage:WaitForChild("UpgradeEvent")
local upgradeRobuxEvent = ReplicatedStorage:WaitForChild("RequestMerchantUpgradeRobux")
local buyIngredientRobuxEvent = ReplicatedStorage:WaitForChild("RequestIngredientPurchaseRobux")
local venteIngredientEvent = ReplicatedStorage:WaitForChild("VendreIngredientEvent")
-- Temporaire: pas de GetMoneyFunction pour éviter les erreurs
-- local getMoneyFunction = ReplicatedStorage:WaitForChild("GetMoneyFunction")

-- Variables du menu
local menuFrame = nil
local isMenuOpen = false
local connections = {}
local slotConnections = {}
local hiddenButtons = {}
local currentTab = "buy" -- "buy" ou "sell" - suivre l'onglet actuel

-- Déclaration préalable
local fermerMenu

-- Fonction pour bloquer/débloquer les inputs du jeu
local function setGameInputsBlocked(blocked)
	if blocked then
		-- Bloquer le saut (ButtonA/Space)
		ContextActionService:BindAction("BlockJump", function()
			return Enum.ContextActionResult.Sink -- Consommer l'input
		end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		
		-- Bloquer ButtonX qui pourrait être utilisé pour autre chose
		ContextActionService:BindAction("BlockButtonX", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonX)
	else
		-- Débloquer
		ContextActionService:UnbindAction("BlockJump")
		ContextActionService:UnbindAction("BlockButtonX")
	end
end

-- Récupérer les ingrédients disponibles dans le backpack du joueur
local function getPlayerIngredients()
	local ingredients = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return ingredients end

	-- Parcourir le backpack
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local baseName = tool:GetAttribute("BaseName")
			local isCandy = tool:GetAttribute("IsCandy")

			-- Ne prendre que les ingrédients (pas les bonbons)
			if baseName and not isCandy then
				local count = tool:FindFirstChild("Count")
				if count and count.Value > 0 then
					ingredients[baseName] = (ingredients[baseName] or 0) + count.Value
				end
			end
		end
	end

	return ingredients
end

-- 🔄 Récupérer le stock personnel du joueur depuis le serveur
local function refreshPlayerStock()
	local success, stock = pcall(function()
		return getPlayerStockFunc:InvokeServer()
	end)
	
	if success and stock then
		
		-- Vider et remplir le cache (sans recréer la table)
		for key in pairs(playerStock) do
			playerStock[key] = nil
		end
		for name, qty in pairs(stock) do
			playerStock[name] = qty
		end
		
		-- S'assurer que tous les ingrédients connus ont une valeur (même 0)
		for name, _ in pairs(RecipeManager.Ingredients) do
			if playerStock[name] == nil then
				playerStock[name] = 0
			end
		end
		
		return true
	else
		warn("🛒 [CLIENT] Erreur lors de la récupération du stock:", stock)
		return false
	end
end

-- 🔄 Obtenir le stock d'un ingrédient depuis le cache local
local function getIngredientStock(ingredientName)
	return playerStock[ingredientName] or 0
end

-- Formater le temps
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

-- Aide rareté → ordre (pour filtrage par niveau marchand)
local function normalizeRareteName(rarete)
	if type(rarete) ~= "string" then return "Common" end
	local s = rarete
	s = s:gsub("É", "e"):gsub("é", "e"):gsub("È", "e"):gsub("è", "e"):gsub("Ê", "e"):gsub("ê", "e")
	s = s:gsub("À", "a"):gsub("Â", "a"):gsub("Ä", "a"):gsub("à", "a"):gsub("â", "a"):gsub("ä", "a")
	s = s:gsub("Ï", "i"):gsub("î", "i"):gsub("ï", "i")
	s = s:gsub("Ô", "o"):gsub("ô", "o")
	s = s:gsub("Ù", "u"):gsub("Û", "u"):gsub("Ü", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
	s = string.lower(s)
	if string.find(s, "common", 1, true) then return "Common" end
	if string.find(s, "rare", 1, true) then return "Rare" end
	if string.find(s, "epic", 1, true) then return "Epic" end
	if string.find(s, "legendary", 1, true) then return "Legendary" end
	if string.find(s, "mythic", 1, true) then return "Mythic" end
	return "Common"
end

local function getRareteOrder(rarete)
	local key = normalizeRareteName(rarete)
	local R = RecipeManager and RecipeManager.Raretes or nil
	if R and R[key] and R[key].ordre then return R[key].ordre end
	local fallback = {Common = 1, ["Rare"] = 2, ["Epic"] = 3, ["Legendary"] = 4, ["Mythic"] = 5}
	return fallback[key] or 1
end

local MAX_MERCHANT_LEVEL = 5
local UPGRADE_COSTS = {
	[1] = 10000000,   -- → 2 (Rare) - 10M
	[2] = 200000000000,  -- → 3 (Epic) - 200B
	[3] = 500000000000000,  -- → 4 (Legendary) - 500T
	[4] = 10000000000000000, -- → 5 (Mythic) - 10Qa
}
-- Coûts Robux pour upgrade marchand
local UPGRADE_ROBUX_COSTS = {
	[1] = 50,   -- Niveau 1 → 2 : 50 Robux
	[2] = 100,  -- Niveau 2 → 3 : 100 Robux  
	[3] = 200,  -- Niveau 3 → 4 : 200 Robux
	[4] = 400,  -- Niveau 4 → 5 : 400 Robux
}

local function getMerchantLevel()
	local pd = player:FindFirstChild("PlayerData")
	local ml = pd and pd:FindFirstChild("MerchantLevel")
	return (ml and ml.Value) or 1
end

local function isIngredientUnlockedForCurrentLevel(ingredientName)
	local def = RecipeManager and RecipeManager.Ingredients and RecipeManager.Ingredients[ingredientName]
	if not def then return false end
	local order = getRareteOrder(def.rarete)
	return order <= math.clamp(getMerchantLevel(), 1, MAX_MERCHANT_LEVEL)
end

-- Met à jour un slot d'ingrédient
local function updateIngredientSlot(slot, stockActuel)
	local ingredientNom = slot.Name
	local ingredientData = RecipeManager.Ingredients[ingredientNom]
	if not ingredientData then return end

	local isUnlocked = slot:GetAttribute("Unlocked") == true

	local stockLabel = slot:FindFirstChild("StockLabel", true)
	if stockLabel then
		stockLabel.Text = isUnlocked and ("x" .. stockActuel .. " available") or "???"
	end

	-- Utiliser PlayerData.Argent (valeur numérique réelle)
	local playerData = player:FindFirstChild("PlayerData")
	local currentMoney = playerData and playerData:FindFirstChild("Argent") and playerData.Argent.Value or 0
	local canAfford = currentMoney >= ingredientData.prix

	local buttonContainer = slot:FindFirstChild("ButtonContainer", true)
	local noStockLabel = slot:FindFirstChild("NoStockLabel", true)
	local acheterUnBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterUnBtn")
	local acheterCinqBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterCinqBtn")
	local acheterRobuxBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterRobuxBtn")

	if not (buttonContainer and noStockLabel and acheterUnBtn and acheterCinqBtn) then return end

	local hasStock = stockActuel > 0
	if not isUnlocked then
		-- Style verrouillé
		buttonContainer.Visible = false
		noStockLabel.Text = "🔒 LOCKED"
		noStockLabel.Visible = true
		if acheterUnBtn then
			acheterUnBtn.Active = false
			acheterUnBtn.Text = "🔒"
			acheterUnBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		end
		if acheterCinqBtn then
			acheterCinqBtn.Active = false
			acheterCinqBtn.Text = "🔒"
			acheterCinqBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			acheterCinqBtn.Visible = false
		end
		if acheterRobuxBtn then
			acheterRobuxBtn.Active = false
			acheterRobuxBtn.Text = "🔒"
			acheterRobuxBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			acheterRobuxBtn.Visible = false
		end
		return
	end

	buttonContainer.Visible = hasStock
	noStockLabel.Visible = not hasStock

	if hasStock then
		-- Gérer le bouton "Acheter 1" (utiliser leaderstats)
		local canAfford1 = currentMoney >= ingredientData.prix
		acheterUnBtn.Active = canAfford1
		acheterUnBtn.BackgroundColor3 = canAfford1 and Color3.fromRGB(85, 170, 85) or Color3.fromRGB(150, 80, 80)
		acheterUnBtn.Text = canAfford1 and "BUY" or "💸 TOO EXPENSIVE"

		-- Gérer le bouton "Acheter 5"
		-- Utiliser PlayerData pour cohérence d'affichage
		local playerData2 = player:FindFirstChild("PlayerData")
		local currentMoney2 = playerData2 and playerData2:FindFirstChild("Argent") and playerData2.Argent.Value or 0
		local canAfford5 = currentMoney2 >= (ingredientData.prix * 5)
		local hasEnoughStock5 = stockActuel >= 5
		acheterCinqBtn.Active = canAfford5 and hasEnoughStock5
		acheterCinqBtn.Visible = hasEnoughStock5

		if hasEnoughStock5 then
			acheterCinqBtn.BackgroundColor3 = canAfford5 and Color3.fromRGB(65, 130, 200) or Color3.fromRGB(150, 80, 80)
			acheterCinqBtn.Text = canAfford5 and "BUY x5" or "💸 TOO EXPENSIVE"
		end

		-- Bouton Robux: visible si stock > 0
		if acheterRobuxBtn then
			acheterRobuxBtn.Active = hasStock
			acheterRobuxBtn.Visible = hasStock
			acheterRobuxBtn.BackgroundColor3 = hasStock and Color3.fromRGB(235, 200, 60) or Color3.fromRGB(120, 120, 120)
			acheterRobuxBtn.Text = "R$ BUY"
		end
	end
end


-- Crée un slot d'ingrédient (responsive)
local function createIngredientSlot(parent, ingredientNom, ingredientData)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = ingredientNom

	-- Hauteur responsive (grand changement mobile: cartes plus compactes)
	local slotHeight = (isMobile or isSmallScreen) and 72 or 120
	slotFrame.Size = UDim2.new(1, 0, 0, slotHeight)
	slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
	slotFrame.BorderSizePixel = 0
	slotFrame.ZIndex = Z_BASE + 1

	local corner = Instance.new("UICorner", slotFrame)
	corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)

	local stroke = Instance.new("UIStroke", slotFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3

	local viewport = Instance.new("ViewportFrame")
	-- Viewport responsive (réduit sur mobile)
	local vpSize = (isMobile or isSmallScreen) and 48 or 100
	viewport.Size = UDim2.new(0, vpSize, 0, vpSize)
	viewport.Position = UDim2.new(0, 10, 0.5, -(vpSize/2))
	viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	viewport.BorderSizePixel = 0
	viewport.ZIndex = Z_BASE + 1
	viewport.Parent = slotFrame

	local vpCorner = Instance.new("UICorner", viewport)
	vpCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 6)

	local vpStroke = Instance.new("UIStroke", viewport)
	vpStroke.Color = Color3.fromRGB(87, 60, 34)
	vpStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2

	local ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
	local ingredientTool = ingredientToolFolder and ingredientToolFolder:FindFirstChild(ingredientNom)
	local isUnlocked = isIngredientUnlockedForCurrentLevel(ingredientNom)
	if UIUtils and ingredientTool and ingredientTool:FindFirstChild("Handle") then
		if isUnlocked then
			UIUtils.setupViewportFrame(viewport, ingredientTool.Handle)
		else
			if UIUtils.setupViewportFrameGrayscale then
				UIUtils.setupViewportFrameGrayscale(viewport, ingredientTool.Handle)
			else
				UIUtils.setupViewportFrame(viewport, ingredientTool.Handle)
			end
		end
	end

	-- Retenir l'état de verrouillage sur le slot pour les mises à jour ultérieures
	slotFrame:SetAttribute("Unlocked", isUnlocked)

	local nomLabel = Instance.new("TextLabel")
	local labelStartX = vpSize + 20
	nomLabel.Size = UDim2.new(0.5, 0, 0, (isMobile or isSmallScreen) and 20 or 30)
	nomLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 5 or 10)
	nomLabel.BackgroundTransparency = 1
	nomLabel.Text = isUnlocked and ingredientData.nom or "???"
	nomLabel.TextColor3 = Color3.new(1,1,1)
	nomLabel.TextSize = (isMobile or isSmallScreen) and 16 or 28
	nomLabel.Font = Enum.Font.GothamBold
	nomLabel.TextXAlignment = Enum.TextXAlignment.Left
	nomLabel.TextScaled = (isMobile or isSmallScreen)
	nomLabel.ZIndex = Z_BASE + 1
	nomLabel.Parent = slotFrame

	local stockLabel = Instance.new("TextLabel")
	stockLabel.Name = "StockLabel"
	stockLabel.Size = UDim2.new(0.4, 0, 0, (isMobile or isSmallScreen) and 16 or 25)
	stockLabel.Position = UDim2.new(0, labelStartX + 5, 0, (isMobile or isSmallScreen) and 25 or 40)
	stockLabel.BackgroundTransparency = 1
	stockLabel.TextColor3 = isUnlocked and Color3.fromRGB(255, 240, 200) or Color3.fromRGB(180, 180, 180)
	stockLabel.TextSize = (isMobile or isSmallScreen) and 12 or 22
	stockLabel.Font = Enum.Font.GothamBold
	stockLabel.TextXAlignment = Enum.TextXAlignment.Left
	stockLabel.TextScaled = (isMobile or isSmallScreen)
	stockLabel.ZIndex = Z_BASE + 1
	stockLabel.Parent = slotFrame

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(0.3, 0, 0, (isMobile or isSmallScreen) and 18 or 30)
	priceLabel.Position = UDim2.new(0, labelStartX + 5, 0, (isMobile or isSmallScreen) and 45 or 70)
	priceLabel.BackgroundTransparency = 1
	-- Formater le prix avec UIUtils
	local formattedPrice = isUnlocked and (UIUtils and UIUtils.formatMoneyShort and UIUtils.formatMoneyShort(ingredientData.prix) or tostring(ingredientData.prix)) or "???"
	priceLabel.Text = isUnlocked and ((isMobile or isSmallScreen) and (formattedPrice .. "$") or ("Price: " .. formattedPrice .. "$")) or (isMobile or isSmallScreen) and "???" or "Price: ???"
	priceLabel.TextColor3 = isUnlocked and Color3.fromRGB(130, 255, 130) or Color3.fromRGB(150, 150, 150)
	priceLabel.TextSize = (isMobile or isSmallScreen) and 12 or 22
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.TextScaled = (isMobile or isSmallScreen)
	priceLabel.ZIndex = Z_BASE + 1
	priceLabel.Parent = slotFrame

	local rareteLabel = Instance.new("TextLabel")
	local rareteWidth = (isMobile or isSmallScreen) and 60 or 100
	local rareteHeight = (isMobile or isSmallScreen) and 16 or 25
	rareteLabel.Size = UDim2.new(0, rareteWidth, 0, rareteHeight)
	rareteLabel.Position = UDim2.new(1, -(rareteWidth + 10), 0, (isMobile or isSmallScreen) and 5 or 10)
	rareteLabel.BackgroundColor3 = isUnlocked and ingredientData.couleurRarete or Color3.fromRGB(120, 120, 120)
	rareteLabel.Text = isUnlocked and ingredientData.rarete or "?"
	rareteLabel.TextColor3 = isUnlocked and Color3.new(1,1,1) or Color3.fromRGB(220,220,220)
	rareteLabel.TextSize = (isMobile or isSmallScreen) and 10 or 16
	rareteLabel.Font = Enum.Font.SourceSansBold
	rareteLabel.TextScaled = (isMobile or isSmallScreen)
	rareteLabel.ZIndex = Z_BASE + 2
	rareteLabel.Parent = slotFrame

	local rCorner = Instance.new("UICorner", rareteLabel)
	rCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 6)

	local rStroke = Instance.new("UIStroke", rareteLabel)
	rStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
	rStroke.Color = Color3.fromHSV(0,0,0.2)

	-- Overlay "LOCK" si verrouillé (grise toute la carte)
	if not isUnlocked then
		local overlay = Instance.new("Frame")
		overlay.Name = "LockOverlay"
		overlay.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		overlay.BackgroundTransparency = 0.35
		overlay.BorderSizePixel = 0
		-- Laisser un anneau pour voir le cadre (UIStroke) autour de la carte
		overlay.Size = UDim2.new(1, -4, 1, -4)
		overlay.Position = UDim2.new(0, 2, 0, 2)
		overlay.ZIndex = Z_BASE + 5
		overlay.Parent = slotFrame

		local lockLabel = Instance.new("TextLabel")
		lockLabel.Size = UDim2.new(1, 0, 1, 0)
		lockLabel.BackgroundTransparency = 1
		lockLabel.Text = "🔒 LOCKED"
		lockLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
		lockLabel.Font = Enum.Font.GothamBlack
		lockLabel.TextScaled = true
		lockLabel.ZIndex = Z_BASE + 6
		lockLabel.Parent = overlay

		-- Coin arrondi identique pour l'overlay afin qu'il épouse le slot
		local overlayCorner = Instance.new("UICorner", overlay)
		overlayCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)
	end

	-- Conteneur pour les boutons
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ButtonContainer"
	buttonContainer.Size = UDim2.new(0.42, 0, 0.28, 0)
	buttonContainer.Position = UDim2.new(1, -20, 1, -15)
	buttonContainer.AnchorPoint = Vector2.new(1, 1)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = Z_BASE + 2
	buttonContainer.Parent = slotFrame

	local layout = Instance.new("UIListLayout", buttonContainer)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 6 or 10)

	-- Bouton "Acheter 5"
	local acheterCinqBtn = Instance.new("TextButton")
	acheterCinqBtn.Name = "AcheterCinqBtn"
	acheterCinqBtn.LayoutOrder = 1
	acheterCinqBtn.Size = UDim2.new(0.31, 0, 1, 0)
	acheterCinqBtn.Text = isUnlocked and "BUY x5" or "🔒"
	acheterCinqBtn.Font = Enum.Font.GothamBold
	acheterCinqBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
	acheterCinqBtn.TextColor3 = Color3.new(1,1,1)
	acheterCinqBtn.BackgroundColor3 = isUnlocked and Color3.fromRGB(65, 130, 200) or Color3.fromRGB(90, 90, 90)
	acheterCinqBtn.ZIndex = Z_BASE + 3
	acheterCinqBtn.Parent = buttonContainer
	local b5Corner = Instance.new("UICorner", acheterCinqBtn); b5Corner.CornerRadius = UDim.new(0, 8)
	local b5Stroke = Instance.new("UIStroke", acheterCinqBtn); b5Stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; b5Stroke.Color = Color3.fromHSV(0,0,0.2)
	acheterCinqBtn.MouseButton1Click:Connect(function() 
		if not isUnlocked then return end
		if acheterCinqBtn.Active then 
			achatIngredientEvent:FireServer(ingredientNom, 5)
			-- 🔄 Rafraîchir le stock après un court délai
			task.delay(0.3, function()
				if refreshPlayerStock() and menuFrame then
					-- Rafraîchir TOUS les slots
					local buyScrollFrame = menuFrame:FindFirstChild("BuyScrollFrame")
					if buyScrollFrame then
						for _, slot in ipairs(buyScrollFrame:GetChildren()) do
							if slot:IsA("Frame") and slot.Name ~= "UIListLayout" then
								local ingName = slot.Name
								local stock = playerStock[ingName] or 0
								updateIngredientSlot(slot, stock)
							end
						end
					end
				end
			end)
		end
	end)

	-- Bouton "Acheter 1"
	local acheterUnBtn = Instance.new("TextButton")
	acheterUnBtn.Name = "AcheterUnBtn"
	acheterUnBtn.LayoutOrder = 2
	acheterUnBtn.Size = UDim2.new(0.31, 0, 1, 0)
	acheterUnBtn.Text = isUnlocked and "BUY" or "🔒"
	acheterUnBtn.Font = Enum.Font.GothamBold
	acheterUnBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
	acheterUnBtn.TextColor3 = Color3.new(1,1,1)
	acheterUnBtn.BackgroundColor3 = isUnlocked and Color3.fromRGB(85, 170, 85) or Color3.fromRGB(90, 90, 90)
	acheterUnBtn.ZIndex = Z_BASE + 3
	acheterUnBtn.Parent = buttonContainer
	local b1Corner = Instance.new("UICorner", acheterUnBtn); b1Corner.CornerRadius = UDim.new(0, 8)
	local b1Stroke = Instance.new("UIStroke", acheterUnBtn); b1Stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; b1Stroke.Color = Color3.fromHSV(0,0,0.2)
	acheterUnBtn.MouseButton1Click:Connect(function() 
		if not isUnlocked then return end
		if acheterUnBtn.Active then 
			achatIngredientEvent:FireServer(ingredientNom, 1)
			-- 🔄 Rafraîchir le stock après un court délai
			task.delay(0.3, function()
				if refreshPlayerStock() and menuFrame then
					-- Rafraîchir TOUS les slots
					local buyScrollFrame = menuFrame:FindFirstChild("BuyScrollFrame")
					if buyScrollFrame then
						for _, slot in ipairs(buyScrollFrame:GetChildren()) do
							if slot:IsA("Frame") and slot.Name ~= "UIListLayout" then
								local ingName = slot.Name
								local stock = playerStock[ingName] or 0
								updateIngredientSlot(slot, stock)
							end
						end
					end
				end
			end)
		end
	end)

	-- Bouton "Acheter Robux" (x1)
	local acheterRobuxBtn = Instance.new("TextButton")
	acheterRobuxBtn.Name = "AcheterRobuxBtn"
	acheterRobuxBtn.LayoutOrder = 3
	acheterRobuxBtn.Size = UDim2.new(0.31, 0, 1, 0)
	acheterRobuxBtn.Text = isUnlocked and "R$ BUY" or "🔒"
	acheterRobuxBtn.Font = Enum.Font.GothamBold
	acheterRobuxBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
	acheterRobuxBtn.TextColor3 = Color3.new(0,0,0)
	acheterRobuxBtn.BackgroundColor3 = isUnlocked and Color3.fromRGB(235, 200, 60) or Color3.fromRGB(90, 90, 90)
	acheterRobuxBtn.ZIndex = Z_BASE + 3
	acheterRobuxBtn.Parent = buttonContainer
	local brCorner = Instance.new("UICorner", acheterRobuxBtn); brCorner.CornerRadius = UDim.new(0, 8)
	local brStroke = Instance.new("UIStroke", acheterRobuxBtn); brStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; brStroke.Color = Color3.fromRGB(120, 90, 30)
	acheterRobuxBtn.AutoButtonColor = true
	acheterRobuxBtn.Visible = isUnlocked
	acheterRobuxBtn.Active = isUnlocked
	acheterRobuxBtn.MouseButton1Click:Connect(function()
		if not isUnlocked then return end
		if acheterRobuxBtn.Active then
			buyIngredientRobuxEvent:FireServer(ingredientNom, 1)
			-- 🔄 Rafraîchir le stock après un court délai
			task.delay(0.5, function()
				if refreshPlayerStock() and menuFrame then
					-- Rafraîchir TOUS les slots
					local buyScrollFrame = menuFrame:FindFirstChild("BuyScrollFrame")
					if buyScrollFrame then
						for _, slot in ipairs(buyScrollFrame:GetChildren()) do
							if slot:IsA("Frame") and slot.Name ~= "UIListLayout" then
								local ingName = slot.Name
								local stock = playerStock[ingName] or 0
								updateIngredientSlot(slot, stock)
							end
						end
					end
				end
			end)
		end
	end)

	local noStockLabel = Instance.new("TextLabel")
	noStockLabel.Name = "NoStockLabel"
	noStockLabel.Size = UDim2.new(0.42, 0, 0.30, 0)
	noStockLabel.Position = UDim2.new(1, -20, 1, -15)
	noStockLabel.AnchorPoint = Vector2.new(1, 1)
	noStockLabel.Text = isUnlocked and "OUT OF STOCK" or "LOCKED"
	noStockLabel.Font = Enum.Font.GothamBold
	noStockLabel.TextSize = (isMobile or isSmallScreen) and 12 or 18
	noStockLabel.TextColor3 = Color3.new(1,1,1)
	noStockLabel.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Rouge
	noStockLabel.Visible = false
	noStockLabel.ZIndex = Z_BASE + 2
	noStockLabel.Parent = slotFrame
	local nsCorner = Instance.new("UICorner", noStockLabel); nsCorner.CornerRadius = UDim.new(0, 8)
	local nsStroke = Instance.new("UIStroke", noStockLabel); nsStroke.Thickness = 3; nsStroke.Color = Color3.fromHSV(0,0,0.2)

	-- 🔄 Utiliser le stock personnel du joueur
	local currentStock = getIngredientStock(ingredientNom)
	updateIngredientSlot(slotFrame, currentStock)
	-- Réagir au changement d'argent (PlayerData) - uniquement pour mettre à jour les boutons
	-- Le stock sera mis à jour par l'événement UpdatePlayerStock
	local playerData = player:FindFirstChild("PlayerData")
	if playerData and playerData:FindFirstChild("Argent") then
		table.insert(slotConnections, playerData.Argent.Changed:Connect(function()
			-- Ne pas changer le stock, juste rafraîchir l'affichage avec le stock actuel
			local stock = getIngredientStock(ingredientNom)
			updateIngredientSlot(slotFrame, stock)
		end))
	end

	return slotFrame
end

-- Crée un slot pour vendre un ingrédient (responsive)
local function createSellIngredientSlot(parent, ingredientNom, ingredientData, quantity)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "Sell_" .. ingredientNom

	-- Hauteur responsive
	local slotHeight = (isMobile or isSmallScreen) and 72 or 120
	slotFrame.Size = UDim2.new(1, 0, 0, slotHeight)
	slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
	slotFrame.BorderSizePixel = 0
	slotFrame.ZIndex = Z_BASE + 1

	local corner = Instance.new("UICorner", slotFrame)
	corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)

	local stroke = Instance.new("UIStroke", slotFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3

	-- Viewport pour l'ingrédient
	local viewport = Instance.new("ViewportFrame")
	local vpSize = (isMobile or isSmallScreen) and 48 or 100
	viewport.Size = UDim2.new(0, vpSize, 0, vpSize)
	viewport.Position = UDim2.new(0, 10, 0.5, -(vpSize/2))
	viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	viewport.BorderSizePixel = 0
	viewport.ZIndex = Z_BASE + 1
	viewport.Parent = slotFrame

	local vpCorner = Instance.new("UICorner", viewport)
	vpCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 6)

	local vpStroke = Instance.new("UIStroke", viewport)
	vpStroke.Color = Color3.fromRGB(87, 60, 34)
	vpStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2

	local ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
	local ingredientTool = ingredientToolFolder and ingredientToolFolder:FindFirstChild(ingredientNom)
	if UIUtils and ingredientTool and ingredientTool:FindFirstChild("Handle") then
		UIUtils.setupViewportFrame(viewport, ingredientTool.Handle)
	end

	-- Nom de l'ingrédient
	local nomLabel = Instance.new("TextLabel")
	local labelStartX = vpSize + 20
	nomLabel.Size = UDim2.new(0.5, 0, 0, (isMobile or isSmallScreen) and 20 or 30)
	nomLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 5 or 10)
	nomLabel.BackgroundTransparency = 1
	nomLabel.Text = ingredientData.nom
	nomLabel.TextColor3 = Color3.new(1,1,1)
	nomLabel.TextSize = (isMobile or isSmallScreen) and 16 or 28
	nomLabel.Font = Enum.Font.GothamBold
	nomLabel.TextXAlignment = Enum.TextXAlignment.Left
	nomLabel.TextScaled = (isMobile or isSmallScreen)
	nomLabel.ZIndex = Z_BASE + 1
	nomLabel.Parent = slotFrame

	-- Quantité possédée
	local qtyLabel = Instance.new("TextLabel")
	qtyLabel.Name = "QtyLabel"
	qtyLabel.Size = UDim2.new(0.4, 0, 0, (isMobile or isSmallScreen) and 16 or 25)
	qtyLabel.Position = UDim2.new(0, labelStartX + 5, 0, (isMobile or isSmallScreen) and 25 or 40)
	qtyLabel.BackgroundTransparency = 1
	qtyLabel.Text = "Possédé: x" .. quantity
	qtyLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
	qtyLabel.TextSize = (isMobile or isSmallScreen) and 12 or 22
	qtyLabel.Font = Enum.Font.GothamBold
	qtyLabel.TextXAlignment = Enum.TextXAlignment.Left
	qtyLabel.TextScaled = (isMobile or isSmallScreen)
	qtyLabel.ZIndex = Z_BASE + 1
	qtyLabel.Parent = slotFrame

	-- Prix de revente (100% du prix d'achat)
	local sellPrice = ingredientData.prix
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "SellPriceLabel"
	priceLabel.Size = UDim2.new(0.3, 0, 0, (isMobile or isSmallScreen) and 18 or 30)
	priceLabel.Position = UDim2.new(0, labelStartX + 5, 0, (isMobile or isSmallScreen) and 45 or 70)
	priceLabel.BackgroundTransparency = 1
	-- Formater le prix de revente avec UIUtils
	local formattedSellPrice = UIUtils and UIUtils.formatMoneyShort and UIUtils.formatMoneyShort(sellPrice) or tostring(sellPrice)
	priceLabel.Text = (isMobile or isSmallScreen) and (formattedSellPrice .. "$/u") or ("Revente: " .. formattedSellPrice .. "$ /unité")
	priceLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
	priceLabel.TextSize = (isMobile or isSmallScreen) and 12 or 22
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.TextScaled = (isMobile or isSmallScreen)
	priceLabel.ZIndex = Z_BASE + 1
	priceLabel.Parent = slotFrame

	-- Badge de rareté
	local rareteLabel = Instance.new("TextLabel")
	local rareteWidth = (isMobile or isSmallScreen) and 60 or 100
	local rareteHeight = (isMobile or isSmallScreen) and 16 or 25
	rareteLabel.Size = UDim2.new(0, rareteWidth, 0, rareteHeight)
	rareteLabel.Position = UDim2.new(1, -(rareteWidth + 10), 0, (isMobile or isSmallScreen) and 5 or 10)
	rareteLabel.BackgroundColor3 = ingredientData.couleurRarete
	rareteLabel.Text = ingredientData.rarete
	rareteLabel.TextColor3 = Color3.new(1,1,1)
	rareteLabel.TextSize = (isMobile or isSmallScreen) and 10 or 16
	rareteLabel.Font = Enum.Font.SourceSansBold
	rareteLabel.TextScaled = (isMobile or isSmallScreen)
	rareteLabel.ZIndex = Z_BASE + 2
	rareteLabel.Parent = slotFrame

	local rCorner = Instance.new("UICorner", rareteLabel)
	rCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 6)

	local rStroke = Instance.new("UIStroke", rareteLabel)
	rStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
	rStroke.Color = Color3.fromHSV(0,0,0.2)

	-- Conteneur pour les boutons de vente
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "SellButtonContainer"
	buttonContainer.Size = UDim2.new(0.42, 0, 0.28, 0)
	buttonContainer.Position = UDim2.new(1, -20, 1, -15)
	buttonContainer.AnchorPoint = Vector2.new(1, 1)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = Z_BASE + 2
	buttonContainer.Parent = slotFrame

	local layout = Instance.new("UIListLayout", buttonContainer)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 6 or 10)

	-- Bouton "Vendre Tout"
	local vendreAllBtn = Instance.new("TextButton")
	vendreAllBtn.Name = "VendreAllBtn"
	vendreAllBtn.LayoutOrder = 1
	vendreAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
	vendreAllBtn.Text = (isMobile or isSmallScreen) and "TOUT" or "VENDRE TOUT"
	vendreAllBtn.Font = Enum.Font.GothamBold
	vendreAllBtn.TextSize = (isMobile or isSmallScreen) and 10 or 16
	vendreAllBtn.TextColor3 = Color3.new(1,1,1)
	vendreAllBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
	vendreAllBtn.ZIndex = Z_BASE + 3
	vendreAllBtn.Parent = buttonContainer
	local ballCorner = Instance.new("UICorner", vendreAllBtn); ballCorner.CornerRadius = UDim.new(0, 8)
	local ballStroke = Instance.new("UIStroke", vendreAllBtn); ballStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; ballStroke.Color = Color3.fromHSV(0,0,0.2)
	vendreAllBtn.MouseButton1Click:Connect(function()
		venteIngredientEvent:FireServer(ingredientNom, quantity)
	end)

	-- Bouton "Vendre 1"
	local vendreUnBtn = Instance.new("TextButton")
	vendreUnBtn.Name = "VendreUnBtn"
	vendreUnBtn.LayoutOrder = 2
	vendreUnBtn.Size = UDim2.new(0.48, 0, 1, 0)
	vendreUnBtn.Text = (isMobile or isSmallScreen) and "x1" or "VENDRE 1"
	vendreUnBtn.Font = Enum.Font.GothamBold
	vendreUnBtn.TextSize = (isMobile or isSmallScreen) and 10 or 16
	vendreUnBtn.TextColor3 = Color3.new(1,1,1)
	vendreUnBtn.BackgroundColor3 = Color3.fromRGB(170, 85, 40)
	vendreUnBtn.ZIndex = Z_BASE + 3
	vendreUnBtn.Parent = buttonContainer
	local b1Corner = Instance.new("UICorner", vendreUnBtn); b1Corner.CornerRadius = UDim.new(0, 8)
	local b1Stroke = Instance.new("UIStroke", vendreUnBtn); b1Stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; b1Stroke.Color = Color3.fromHSV(0,0,0.2)
	vendreUnBtn.MouseButton1Click:Connect(function()
		venteIngredientEvent:FireServer(ingredientNom, 1)
	end)

	return slotFrame
end

-- Création du menu principal (responsive)
local function createMenuAchat()
	if menuFrame then fermerMenu() end

	isMenuOpen = true
	currentTab = "buy" -- Réinitialiser à l'onglet achat
	-- Masquer certains boutons flottants le temps que le menu d'achat est ouvert
	hiddenButtons = {}
	pcall(function()
		local pg = player:FindFirstChild("PlayerGui")
		if pg then
			for _, inst in ipairs(pg:GetDescendants()) do
				if inst:IsA("TextButton") and (inst.Name == "BoutonPokedex" or inst.Name == "BoutonRecettes") then
					table.insert(hiddenButtons, {btn = inst, prev = inst.Visible})
					inst.Visible = false
				end
			end
		end
	end)
	menuFrame = Instance.new("Frame")
	menuFrame.Name = "MenuAchat"
	menuFrame.ZIndex = Z_BASE

	-- Taille fixe de base (sera scalée automatiquement)
	menuFrame.Size = UDim2.new(0, 900, 0, 600)
	menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	menuFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
	menuFrame.BorderSizePixel = 0
	menuFrame.Parent = screenGui
	
	-- UIScale pour adapter automatiquement à la taille de l'écran
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = menuFrame
	
	-- UISizeConstraint pour limiter la taille min/max
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(350, 250)
	sizeConstraint.MaxSize = Vector2.new(1300, 900)
	sizeConstraint.Parent = menuFrame
	
	-- Fonction pour ajuster le scale selon la taille de l'écran
	local function updateMenuScale()
		local currentViewportSize = workspace.CurrentCamera.ViewportSize
		local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local isPortrait = currentViewportSize.Y > currentViewportSize.X
		
		-- Calcul du scale basé sur la résolution
		local scaleX = currentViewportSize.X / 1920 -- Référence 1920x1080
		local scaleY = currentViewportSize.Y / 1080
		local scale = math.min(scaleX, scaleY, 1.2) -- Max 120%
		
		-- Ajustements spécifiques pour mobile/tablette
		if isMobileDevice then
			if isPortrait then
				-- Téléphone en mode portrait : utiliser toute la largeur
				scale = math.max(scale, currentViewportSize.X / 950)
			else
				-- Téléphone/tablette en mode paysage
				scale = math.max(scale, 0.45)
			end
		end
		
		-- Limites finales
		scale = math.max(scale, 0.4) -- Min 40% pour très petits écrans
		scale = math.min(scale, 1.3) -- Max 130% pour très grands écrans
		
		uiScale.Scale = scale
	end
	
	-- Mettre à jour au démarrage
	updateMenuScale()
	
	-- Mettre à jour quand la taille de l'écran change
	local scaleConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuScale)
	table.insert(connections, scaleConnection)

	local corner = Instance.new("UICorner", menuFrame)
	corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 16 or 12)

	local stroke = Instance.new("UIStroke", menuFrame)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = (isMobile or isSmallScreen) and 3 or 5

	-- Header (responsive)
	local header = Instance.new("Frame")
	header.ZIndex = Z_BASE + 1
	local headerHeight = (isMobile or isSmallScreen) and 40 or 60
	header.Size = UDim2.new(1, 0, 0, headerHeight)
	header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
	header.BorderSizePixel = 0
	header.Parent = menuFrame

	local hCorner = Instance.new("UICorner", header)
	hCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)

	local hStroke = Instance.new("UIStroke", header)
	hStroke.Thickness = (isMobile or isSmallScreen) and 2 or 4
	hStroke.Color = Color3.fromRGB(66, 103, 38)

	-- Affichage de l'argent du joueur
	local moneyDisplayLabel = Instance.new("TextLabel", header)
	moneyDisplayLabel.Name = "MoneyDisplayLabel"
	moneyDisplayLabel.ZIndex = Z_BASE + 2
	moneyDisplayLabel.Size = UDim2.new((isMobile or isSmallScreen) and 0.35 or 0.25, 0, 0.5, 0)
	moneyDisplayLabel.Position = UDim2.new(0.05, 0, 0, 0)
	moneyDisplayLabel.BackgroundTransparency = 1
	moneyDisplayLabel.Font = Enum.Font.GothamBold
	moneyDisplayLabel.TextSize = isMobile and 14 or (isSmallScreen and 12 or 20)
	moneyDisplayLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	moneyDisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyDisplayLabel.TextScaled = false
	-- Initialiser avec l'argent actuel
	local playerData = player:FindFirstChild("PlayerData")
	local currentMoney = 0
	if playerData and playerData:FindFirstChild("Argent") then
		currentMoney = playerData.Argent.Value
	end
	local formattedMoney = (UIUtils and UIUtils.formatMoneyShort) and UIUtils.formatMoneyShort(currentMoney) or tostring(currentMoney)
	moneyDisplayLabel.Text = (isMobile or isSmallScreen) and ("💰 " .. formattedMoney .. "$") or ("💰 Money : " .. formattedMoney .. "$")

	local timerLabel = Instance.new("TextLabel", header)
	timerLabel.Name = "TimerLabel"
	timerLabel.ZIndex = Z_BASE + 2
	timerLabel.Size = UDim2.new((isMobile or isSmallScreen) and 0.6 or 0.5, 0, 0.5, 0)
	timerLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = isMobile and 14 or (isSmallScreen and 12 or 18)
	timerLabel.TextColor3 = Color3.new(1,1,1)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.TextScaled = false

	-- Conteneur pour les boutons à droite (avec layout automatique)
	local rightButtonsContainer = Instance.new("Frame")
	rightButtonsContainer.Name = "RightButtonsContainer"
	rightButtonsContainer.Size = UDim2.new(0.65, 0, 1, -10)
	rightButtonsContainer.Position = UDim2.new(1, -10, 0, 5)
	rightButtonsContainer.AnchorPoint = Vector2.new(1, 0)
	rightButtonsContainer.BackgroundTransparency = 1
	rightButtonsContainer.ZIndex = Z_BASE + 2
	rightButtonsContainer.ClipsDescendants = true -- Empêche le débordement
	rightButtonsContainer.Parent = header
	
	-- Layout horizontal pour organiser automatiquement les boutons
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Padding = UDim.new(0, 6)
	buttonLayout.Wraps = false -- Empêche le passage à la ligne
	buttonLayout.Parent = rightButtonsContainer
	
	local boutonFermer = Instance.new("TextButton")
	boutonFermer.Name = "CloseButton"
	boutonFermer.LayoutOrder = 5
	boutonFermer.ZIndex = Z_BASE + 2
	local closeSize = 38
	boutonFermer.Size = UDim2.new(0, closeSize, 0, closeSize)
	boutonFermer.Parent = rightButtonsContainer
	boutonFermer.BackgroundColor3 = Color3.fromRGB(200,50,50)
	boutonFermer.Text = "X"
	boutonFermer.TextColor3 = Color3.new(1,1,1)
	boutonFermer.TextSize = (isMobile or isSmallScreen) and 24 or 22
	boutonFermer.Font = Enum.Font.GothamBold
	boutonFermer.MouseButton1Click:Connect(fermerMenu)

	local xCorner = Instance.new("UICorner", boutonFermer)
	xCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)

	local xStroke = Instance.new("UIStroke", boutonFermer)
	xStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
	xStroke.Color = Color3.fromHSV(0,0,0.2)

	local boutonRestock = Instance.new("TextButton")
	boutonRestock.Name = "RestockButton"
	boutonRestock.LayoutOrder = 4
	boutonRestock.ZIndex = Z_BASE + 2
	local restockWidth = 100 -- Réduit pour tenir
	local restockHeight = 38
	boutonRestock.Size = UDim2.new(0, restockWidth, 0, restockHeight)
	boutonRestock.Parent = rightButtonsContainer
	boutonRestock.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
	boutonRestock.Text = "RESTOCK\n(30R$)"
	boutonRestock.TextColor3 = Color3.new(1,1,1)
	boutonRestock.TextSize = 14
	boutonRestock.Font = Enum.Font.GothamBold
	boutonRestock.TextScaled = false
	boutonRestock.MouseButton1Click:Connect(function() 
		forceRestockEvent:FireServer()
		-- 🔄 Rafraîchir le stock après le restock
		task.delay(1, function()
			if menuFrame and refreshPlayerStock() then
				-- Rafraîchir tous les slots
				local buyScrollFrame = menuFrame:FindFirstChild("BuyScrollFrame")
				if buyScrollFrame then
					for _, slot in ipairs(buyScrollFrame:GetChildren()) do
						if slot:IsA("Frame") and slot.Name ~= "UIListLayout" then
							local ingredientName = slot.Name
							local newStock = playerStock[ingredientName] or 0
							updateIngredientSlot(slot, newStock)
						end
					end
				end
			end
		end)
	end)

	local reCorner = Instance.new("UICorner", boutonRestock)
	reCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)

	local reStroke = Instance.new("UIStroke", boutonRestock)
	reStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
	reStroke.Color = Color3.fromHSV(0,0,0.2)


	-- Badge niveau marchand (centré, s'adapte automatiquement)
	local levelBadge = Instance.new("TextLabel")
	levelBadge.Name = "LevelBadge"
	levelBadge.ZIndex = Z_BASE + 2
	local badgeWidth = 130
	local badgeHeight = 32
	levelBadge.Size = UDim2.new(0, badgeWidth, 0, badgeHeight)
	levelBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	levelBadge.Position = UDim2.new(0.5, 0, 0.5, 0)
	levelBadge.BackgroundColor3 = Color3.fromRGB(66, 103, 38)
	levelBadge.TextColor3 = Color3.new(1,1,1)
	levelBadge.Font = Enum.Font.GothamBold
	levelBadge.TextSize = 16
	levelBadge.TextScaled = false
	levelBadge.Text = "Shop Lvl. " .. tostring(getMerchantLevel()) .. "/" .. tostring(MAX_MERCHANT_LEVEL)
	levelBadge.Parent = header
	local lbCorner = Instance.new("UICorner", levelBadge)
	lbCorner.CornerRadius = UDim.new(0, 8)
	local lbStroke = Instance.new("UIStroke", levelBadge)
	lbStroke.Thickness = 2
	lbStroke.Color = Color3.fromRGB(40, 60, 20)
	
	-- UISizeConstraint pour s'adapter à l'espace disponible
	local badgeSizeConstraint = Instance.new("UISizeConstraint")
	badgeSizeConstraint.MinSize = Vector2.new(80, 24)
	badgeSizeConstraint.MaxSize = Vector2.new(150, 40)
	badgeSizeConstraint.Parent = levelBadge

	-- Bouton upgrade avec argent
	local boutonUpgrade = Instance.new("TextButton")
	boutonUpgrade.Name = "UpgradeButton"
	boutonUpgrade.LayoutOrder = 2
	boutonUpgrade.ZIndex = Z_BASE + 2
	local upgWidth = 110 -- Réduit pour tenir sur petits écrans
	local upgHeight = 38
	boutonUpgrade.Size = UDim2.new(0, upgWidth, 0, upgHeight)
	boutonUpgrade.Parent = rightButtonsContainer
	boutonUpgrade.BackgroundColor3 = Color3.fromRGB(90, 130, 250)
	boutonUpgrade.TextColor3 = Color3.new(1,1,1)
	boutonUpgrade.Font = Enum.Font.GothamBold
	boutonUpgrade.TextScaled = false
	boutonUpgrade.TextSize = 14
	local upCorner = Instance.new("UICorner", boutonUpgrade)
	upCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)
	local upStroke = Instance.new("UIStroke", boutonUpgrade)
	upStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
	upStroke.Color = Color3.fromHSV(0,0,0.2)

	-- Bouton upgrade avec Robux
	local boutonUpgradeRobux = Instance.new("TextButton")
	boutonUpgradeRobux.Name = "UpgradeRobuxButton"
	boutonUpgradeRobux.LayoutOrder = 3
	boutonUpgradeRobux.ZIndex = Z_BASE + 2
	boutonUpgradeRobux.Size = UDim2.new(0, 110, 0, 38) -- Même taille que l'autre upgrade
	boutonUpgradeRobux.Parent = rightButtonsContainer
	boutonUpgradeRobux.BackgroundColor3 = Color3.fromRGB(0, 162, 255) -- Couleur Robux
	boutonUpgradeRobux.TextColor3 = Color3.new(1,1,1)
	boutonUpgradeRobux.Font = Enum.Font.GothamBold
	boutonUpgradeRobux.TextScaled = false
	boutonUpgradeRobux.TextSize = 14
	local upRobuxCorner = Instance.new("UICorner", boutonUpgradeRobux)
	upRobuxCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)
	local upRobuxStroke = Instance.new("UIStroke", boutonUpgradeRobux)
	upRobuxStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
	upRobuxStroke.Color = Color3.fromHSV(0,0,0.2)

	local function updateUpgradeUI()
		local lvl = getMerchantLevel()
		levelBadge.Text = "Shop Lvl. " .. tostring(lvl) .. "/" .. tostring(MAX_MERCHANT_LEVEL)
		if lvl >= MAX_MERCHANT_LEVEL then
			-- Bouton argent
			boutonUpgrade.Text = "MAX"
			boutonUpgrade.Active = false
			boutonUpgrade.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			-- Bouton Robux
			boutonUpgradeRobux.Text = "MAX"
			boutonUpgradeRobux.Active = false
			boutonUpgradeRobux.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		else
			-- Bouton argent
			local cost = UPGRADE_COSTS[lvl] or 0
			local formattedCost = UIUtils.formatMoneyShort(cost)
			boutonUpgrade.Text = "UPGRADE\n("..formattedCost.."$)"
			boutonUpgrade.Active = true
			boutonUpgrade.BackgroundColor3 = Color3.fromRGB(90, 130, 250)
			-- Bouton Robux
			local robuxCost = UPGRADE_ROBUX_COSTS[lvl] or 0
			boutonUpgradeRobux.Text = "UPGRADE\n("..robuxCost.."R$)"
			boutonUpgradeRobux.Active = true
			boutonUpgradeRobux.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
		end
	end
	updateUpgradeUI()

	boutonUpgrade.MouseButton1Click:Connect(function()
		upgradeEvent:FireServer()
	end)

	boutonUpgradeRobux.MouseButton1Click:Connect(function()
		upgradeRobuxEvent:FireServer()
	end)

	-- Timer de restock
	local restockTimeValue = shopStockFolder:WaitForChild("RestockTime")
	local function updateTimer()
		local t = formatTime(restockTimeValue.Value)
		if isMobile then
			timerLabel.Text = "New stock : " .. t -- Version courte sur mobile
		else
			timerLabel.Text = "New stock : " .. t
		end
	end
	table.insert(connections, restockTimeValue.Changed:Connect(updateTimer))
	updateTimer()
	
	-- 🔄 Rafraîchir le stock quand le timer atteint 0 (restock global)
	table.insert(connections, restockTimeValue.Changed:Connect(function(newTime)
		if newTime == 0 or newTime >= 299 then -- Restock vient de se produire
			task.delay(0.5, function()
				if refreshPlayerStock() and menuFrame then
					-- Rafraîchir tous les slots
					local buyScrollFrame = menuFrame:FindFirstChild("BuyScrollFrame")
					if buyScrollFrame then
						for _, slot in ipairs(buyScrollFrame:GetChildren()) do
							if slot:IsA("Frame") and slot.Name ~= "UIListLayout" then
								local ingredientName = slot.Name
								local newStock = getIngredientStock(ingredientName)
								updateIngredientSlot(slot, newStock)
							end
						end
					end
				end
			end)
		end
	end))

	-- Système d'onglets
	local tabHeight = (isMobile or isSmallScreen) and 35 or 45
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.ZIndex = Z_BASE + 1
	tabContainer.Size = UDim2.new(1, -20, 0, tabHeight)
	tabContainer.Position = UDim2.new(0, 10, 0, headerHeight + 10)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = menuFrame

	local tabLayout = Instance.new("UIListLayout", tabContainer)
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 10)

	-- Bouton onglet ACHETER
	local buyTab = Instance.new("TextButton")
	buyTab.Name = "BuyTab"
	buyTab.LayoutOrder = 1
	buyTab.Size = UDim2.new(0, 160, 1, 0)
	buyTab.Text = "🛒 BUY"
	buyTab.Font = Enum.Font.GothamBold
	buyTab.TextSize = 18
	buyTab.TextColor3 = Color3.new(1,1,1)
	buyTab.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
	buyTab.ZIndex = Z_BASE + 2
	buyTab.Parent = tabContainer
	local buyTabCorner = Instance.new("UICorner", buyTab); buyTabCorner.CornerRadius = UDim.new(0, 8)
	local buyTabStroke = Instance.new("UIStroke", buyTab); buyTabStroke.Thickness = 3; buyTabStroke.Color = Color3.fromHSV(0,0,0.2)

	-- Bouton onglet VENDRE
	local sellTab = Instance.new("TextButton")
	sellTab.Name = "SellTab"
	sellTab.LayoutOrder = 2
	sellTab.Size = UDim2.new(0, 160, 1, 0)
	sellTab.Text = "💰 SELL"
	sellTab.Font = Enum.Font.GothamBold
	sellTab.TextSize = 18
	sellTab.TextColor3 = Color3.new(1,1,1)
	sellTab.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	sellTab.ZIndex = Z_BASE + 2
	sellTab.Parent = tabContainer
	local sellTabCorner = Instance.new("UICorner", sellTab); sellTabCorner.CornerRadius = UDim.new(0, 8)
	local sellTabStroke = Instance.new("UIStroke", sellTab); sellTabStroke.Thickness = 3; sellTabStroke.Color = Color3.fromHSV(0,0,0.2)

	-- Scrolling Frame pour ACHETER (avec marges confortables)
	local buyScrollFrame = Instance.new("ScrollingFrame", menuFrame)
	buyScrollFrame.Name = "BuyScrollFrame"
	buyScrollFrame.ZIndex = Z_BASE + 1
	local scrollMargin = 30 -- Marge horizontale augmentée
	local scrollTopOffset = headerHeight + tabHeight + 25
	local scrollBottomMargin = 15
	buyScrollFrame.Size = UDim2.new(1, -(scrollMargin * 2), 1, -(scrollTopOffset + scrollBottomMargin))
	buyScrollFrame.Position = UDim2.new(0, scrollMargin, 0, scrollTopOffset)
	buyScrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
	buyScrollFrame.BorderSizePixel = 0
	buyScrollFrame.ScrollBarThickness = 12
	buyScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100) -- Couleur plus claire et visible
	buyScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	buyScrollFrame.Visible = true

	-- Coins arrondis
	local scrollCorner = Instance.new("UICorner", buyScrollFrame)
	scrollCorner.CornerRadius = UDim.new(0, 10)

	-- Padding interne pour éviter que le contenu touche les bords
	local buyPadding = Instance.new("UIPadding", buyScrollFrame)
	buyPadding.PaddingLeft = UDim.new(0, 10)
	buyPadding.PaddingRight = UDim.new(0, 10)
	buyPadding.PaddingTop = UDim.new(0, 10)
	buyPadding.PaddingBottom = UDim.new(0, 10)

	local buyListLayout = Instance.new("UIListLayout", buyScrollFrame)
	buyListLayout.Padding = UDim.new(0, 12)
	buyListLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Scrolling Frame pour VENDRE (avec marges confortables)
	local sellScrollFrame = Instance.new("ScrollingFrame", menuFrame)
	sellScrollFrame.Name = "SellScrollFrame"
	sellScrollFrame.ZIndex = Z_BASE + 1
	sellScrollFrame.Size = UDim2.new(1, -(scrollMargin * 2), 1, -(scrollTopOffset + scrollBottomMargin))
	sellScrollFrame.Position = UDim2.new(0, scrollMargin, 0, scrollTopOffset)
	sellScrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
	sellScrollFrame.BorderSizePixel = 0
	sellScrollFrame.ScrollBarThickness = 12
	sellScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 150, 100) -- Couleur plus claire et visible
	sellScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sellScrollFrame.Visible = false

	local scrollCorner2 = Instance.new("UICorner", sellScrollFrame)
	scrollCorner2.CornerRadius = UDim.new(0, 10)

	-- Padding interne pour éviter que le contenu touche les bords
	local sellPadding = Instance.new("UIPadding", sellScrollFrame)
	sellPadding.PaddingLeft = UDim.new(0, 10)
	sellPadding.PaddingRight = UDim.new(0, 10)
	sellPadding.PaddingTop = UDim.new(0, 10)
	sellPadding.PaddingBottom = UDim.new(0, 10)

	local sellListLayout = Instance.new("UIListLayout", sellScrollFrame)
	sellListLayout.Padding = UDim.new(0, 12)
	sellListLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Pour compatibilité avec le code existant
	local scrollFrame = buyScrollFrame
	local _listLayout = buyListLayout  -- Variable pour compatibilité (non utilisée directement)

	-- Fonction pour afficher les slots de vente
	local function buildSellSlots()
		-- Déconnecter les connexions
		for _, conn in ipairs(slotConnections) do
			pcall(function() conn:Disconnect() end)
		end
		slotConnections = {}
		-- Effacer les anciens slots
		for _, child in ipairs(sellScrollFrame:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		-- Récupérer les ingrédients du joueur
		local playerIngredients = getPlayerIngredients()
		local orderIndex = 0

		-- Trier par ordre d'affichage
		for _, ingredientNom in ipairs(RecipeManager.IngredientOrder or {}) do
			local quantity = playerIngredients[ingredientNom]
			if quantity and quantity > 0 then
				local ingredientData = RecipeManager.Ingredients[ingredientNom]
				if ingredientData then
					orderIndex += 1
					local slot = createSellIngredientSlot(sellScrollFrame, ingredientNom, ingredientData, quantity)
					slot.LayoutOrder = orderIndex
					slot.Parent = sellScrollFrame
				end
			end
		end

		-- Si aucun ingrédient, afficher un message
		if orderIndex == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Name = "EmptyLabel"
			emptyLabel.Size = UDim2.new(1, -20, 0, 100)
			emptyLabel.Position = UDim2.new(0, 10, 0, 20)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Text = "Aucun ingrédient à vendre\nAchetez des ingrédients d'abord !"
			emptyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			emptyLabel.TextSize = (isMobile or isSmallScreen) and 16 or 20
			emptyLabel.Font = Enum.Font.GothamBold
			emptyLabel.TextWrapped = true
			emptyLabel.ZIndex = Z_BASE + 2
			emptyLabel.Parent = sellScrollFrame
		end
	end

	-- Création des slots d'achat (filtrés par niveau marchand)
	local function buildSlots()
		-- Déconnecter les connexions des anciens slots
		for _, conn in ipairs(slotConnections) do
			pcall(function() conn:Disconnect() end)
		end
		slotConnections = {}
		-- Effacer les anciens slots (conserver layouts et décorations UI)
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		local orderIndex = 0
		local ingredientOrder = RecipeManager.IngredientOrder or {}
		for _, ingredientNom in ipairs(ingredientOrder) do
			local allowed = isIngredientUnlockedForCurrentLevel(ingredientNom)
			if ingredientNom == "Noisette" then
				local def = RecipeManager.Ingredients[ingredientNom]
				local lvl = getMerchantLevel()
				local ord = def and getRareteOrder(def.rarete) or -1
			end
			local ingredientData = RecipeManager.Ingredients[ingredientNom]
			if ingredientData then
				orderIndex += 1
				local slot = createIngredientSlot(scrollFrame, ingredientNom, ingredientData)
				slot.LayoutOrder = orderIndex
				slot.Parent = scrollFrame
			end
		end
	end
	buildSlots()

	-- Fonction pour basculer entre les onglets
	local function switchTab(tab)
		if tab == "buy" then
			currentTab = "buy"
			buyScrollFrame.Visible = true
			sellScrollFrame.Visible = false
			buyTab.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
			sellTab.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			buildSlots() -- Rafraîchir les slots d'achat
		elseif tab == "sell" then
			currentTab = "sell"
			buyScrollFrame.Visible = false
			sellScrollFrame.Visible = true
			buyTab.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			sellTab.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
			buildSellSlots() -- Construire les slots de vente
		end
	end

	-- Connecter les boutons d'onglets
	buyTab.MouseButton1Click:Connect(function()
		switchTab("buy")
	end)

	sellTab.MouseButton1Click:Connect(function()
		switchTab("sell")
	end)

	-- Animation d'ouverture (responsive)
	menuFrame.Size = UDim2.new(0,0,0,0)

	local finalSize
	if isMobile or isSmallScreen then
		finalSize = UDim2.new(1, -12, 0.92, 0)
	else
		finalSize = UDim2.new(0.6, 0, 0.7, 0)
	end

	local tween = TweenService:Create(menuFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = finalSize})
	tween:Play()

	-- Réagir aux changements de niveau marchand pour rafraîchir l'UI
	task.spawn(function()
		local pd = player:WaitForChild("PlayerData", 10)
		if pd then
			local ml = pd:WaitForChild("MerchantLevel", 10)
			if ml then
				table.insert(connections, ml.Changed:Connect(function()
					updateUpgradeUI()
					buildSlots()
				end))
			end
			-- Mise à jour automatique de l'affichage de l'argent
			local argent = pd:WaitForChild("Argent", 10)
			if argent and moneyDisplayLabel then
				table.insert(connections, argent.Changed:Connect(function(newValue)
					local formattedMoney = (UIUtils and UIUtils.formatMoneyShort) and UIUtils.formatMoneyShort(newValue) or tostring(newValue)
					moneyDisplayLabel.Text = (isMobile or isSmallScreen) and ("💰 " .. formattedMoney .. "$") or ("💰 Money : " .. formattedMoney .. "$")
				end))
			end
		end
	end)

	-- Surveiller le backpack pour rafraîchir l'onglet de vente
	task.spawn(function()
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			-- Fonction pour surveiller les changements de Count dans un tool
			local function watchToolCount(tool)
				if tool:IsA("Tool") then
					local count = tool:FindFirstChild("Count")
					if count and count:IsA("IntValue") then
						table.insert(connections, count.Changed:Connect(function()
							-- Rafraîchir l'onglet de vente si on est dessus
							if currentTab == "sell" then
								buildSellSlots()
							end
						end))
					end
				end
			end

			-- Surveiller les tools existants
			for _, tool in ipairs(backpack:GetChildren()) do
				watchToolCount(tool)
			end

			-- Surveiller les nouveaux tools ajoutés
			table.insert(connections, backpack.ChildAdded:Connect(function(child)
				watchToolCount(child)
				-- Rafraîchir l'onglet de vente si on est dessus
				if currentTab == "sell" then
					buildSellSlots()
				end
			end))

			-- Surveiller les tools supprimés
			table.insert(connections, backpack.ChildRemoved:Connect(function()
				-- Rafraîchir l'onglet de vente si on est dessus
				if currentTab == "sell" then
					buildSellSlots()
				end
			end))
		end
	end)
end

-- Fonction de fermeture
fermerMenu = function()
	if menuFrame then
		for _, conn in ipairs(connections) do conn:Disconnect() end
		for _, conn in ipairs(slotConnections) do pcall(function() conn:Disconnect() end) end
		slotConnections = {}
		connections = {}
		-- Restaurer la visibilité des boutons cachés
		for _, ref in ipairs(hiddenButtons) do
			pcall(function()
				if ref.btn then ref.btn.Visible = ref.prev end
			end)
		end
		hiddenButtons = {}

		local tween = TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)})
		tween:Play()
		tween.Completed:Connect(function()
			menuFrame:Destroy()
			menuFrame = nil
			isMenuOpen = false
			-- 🔓 Débloquer les inputs du jeu
			setGameInputsBlocked(false)
		end)
	end
end

-- Fonction d'ouverture
local function ouvrirMenu()
	if not isMenuOpen then
		-- 🔄 Charger le stock AVANT de créer le menu
		refreshPlayerStock()
		-- Petit délai pour s'assurer que le stock est chargé
		task.wait(0.1)
		createMenuAchat()
		-- 🔒 Bloquer les inputs du jeu
		setGameInputsBlocked(true)
	else
	end
end

-- 🔄 Écouter les mises à jour de stock en temps réel
updateStockEvent.OnClientEvent:Connect(function(ingredientName, newStock)
	-- Mettre à jour le cache local
	playerStock[ingredientName] = newStock
	
	-- Si le menu est ouvert, mettre à jour l'affichage
	if menuFrame and isMenuOpen then
		local buyScrollFrame = menuFrame:FindFirstChild("BuyScrollFrame")
		if buyScrollFrame then
			local slot = buyScrollFrame:FindFirstChild(ingredientName)
			if slot then
				updateIngredientSlot(slot, newStock)
			end
		end
	end
end)

-- Connexions
ouvrirMenuEvent.OnClientEvent:Connect(function()
	ouvrirMenu()
end)

-- Connexion pour fermer le menu (pour le tutoriel)
task.spawn(function()
	-- Attendre que le TutorialManager crée l'événement
	while not ReplicatedStorage:FindFirstChild("FermerMenuEvent") do
		task.wait(0.5)
	end

	local fermerMenuEvent = ReplicatedStorage:FindFirstChild("FermerMenuEvent")
	if fermerMenuEvent then
		fermerMenuEvent.OnClientEvent:Connect(function()
			if isMenuOpen then
				fermerMenu()
			end
		end)
	end
end)

-- 🎮 CONTRÔLES MANETTE (GAMEPAD)
local gamepadConnection = nil
local selectedSlotIndex = 1
local selectedButtonIndex = 1 -- 1 = x1, 2 = x5, 3 = Robux
local allSlots = {}

local function autoScrollToSelected()
	if not menuFrame or not isMenuOpen or #allSlots == 0 then return end
	
	local scrollFrame = currentTab == "buy" and menuFrame:FindFirstChild("BuyScrollFrame") or menuFrame:FindFirstChild("SellScrollFrame")
	if not scrollFrame then return end
	
	local selectedSlot = allSlots[selectedSlotIndex]
	if not selectedSlot then return end
	
	-- Calculer la position relative du slot dans le ScrollingFrame
	local slotPosition = selectedSlot.AbsolutePosition.Y
	local scrollPosition = scrollFrame.AbsolutePosition.Y
	local scrollSize = scrollFrame.AbsoluteSize.Y
	
	-- Si le slot est en dehors de la vue, ajuster le CanvasPosition
	local relativePosition = slotPosition - scrollPosition
	
	if relativePosition < 0 then
		-- Slot au-dessus de la vue
		scrollFrame.CanvasPosition = Vector2.new(0, math.max(0, scrollFrame.CanvasPosition.Y + relativePosition - 20))
	elseif relativePosition + selectedSlot.AbsoluteSize.Y > scrollSize then
		-- Slot en dessous de la vue
		local overflow = (relativePosition + selectedSlot.AbsoluteSize.Y) - scrollSize
		scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.CanvasPosition.Y + overflow + 20)
	end
end

local function updateGamepadSelection()
	if not menuFrame or not isMenuOpen then return end
	
	-- Récupérer tous les slots visibles selon l'onglet actuel
	allSlots = {}
	local scrollFrame = currentTab == "buy" and menuFrame:FindFirstChild("BuyScrollFrame") or menuFrame:FindFirstChild("SellScrollFrame")
	
	if scrollFrame then
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Visible then
				table.insert(allSlots, child)
			end
		end
	end
	
	-- Réinitialiser la sélection si nécessaire
	if selectedSlotIndex > #allSlots then
		selectedSlotIndex = 1
	end
	if selectedSlotIndex < 1 and #allSlots > 0 then
		selectedSlotIndex = 1
	end
	
	-- Auto-scroll vers le slot sélectionné
	autoScrollToSelected()
	
	-- Mettre en surbrillance le slot ET le bouton sélectionnés
	for i, slot in ipairs(allSlots) do
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			if i == selectedSlotIndex then
				stroke.Color = Color3.fromRGB(255, 255, 100) -- Jaune pour la sélection
				stroke.Thickness = 5
			else
				stroke.Color = Color3.fromRGB(87, 60, 34) -- Couleur normale
				stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
			end
		end
		
		-- Highlight des boutons (style tutoriel avec cadre externe)
		if i == selectedSlotIndex then
			local buttonContainer = slot:FindFirstChild("ButtonContainer", true)
			if buttonContainer then
				local buttons = {
					buttonContainer:FindFirstChild("AcheterCinqBtn") or buttonContainer:FindFirstChild("VendreCinqBtn"),
					buttonContainer:FindFirstChild("AcheterUnBtn") or buttonContainer:FindFirstChild("VendreUnBtn"),
					buttonContainer:FindFirstChild("AcheterRobuxBtn")
				}
				
				for btnIdx, btn in ipairs(buttons) do
					if btn and btn.Visible then
						-- Supprimer l'ancien highlight s'il existe
						local oldHighlight = btn:FindFirstChild("GamepadHighlight")
						if oldHighlight then oldHighlight:Destroy() end
						
						if btnIdx == selectedButtonIndex then
							-- Créer un cadre de highlight externe (style tutoriel)
							local highlight = Instance.new("Frame")
							highlight.Name = "GamepadHighlight"
							highlight.Size = UDim2.new(1, 12, 1, 12)
							highlight.Position = UDim2.new(0.5, 0, 0.5, 0)
							highlight.AnchorPoint = Vector2.new(0.5, 0.5)
							highlight.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
							highlight.BackgroundTransparency = 0.3
							highlight.BorderSizePixel = 0
							highlight.ZIndex = btn.ZIndex - 1
							highlight.Parent = btn
							
							local highlightCorner = Instance.new("UICorner")
							highlightCorner.CornerRadius = UDim.new(0, 10)
							highlightCorner.Parent = highlight
							
							-- Animation de pulsation
							local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
							local tween = TweenService:Create(highlight, tweenInfo, {
								BackgroundTransparency = 0.6,
								Size = UDim2.new(1, 16, 1, 16)
							})
							tween:Play()
						end
					end
				end
			end
		else
			-- Supprimer les highlights des autres slots
			local buttonContainer = slot:FindFirstChild("ButtonContainer", true)
			if buttonContainer then
				for _, btn in ipairs(buttonContainer:GetChildren()) do
					if btn:IsA("TextButton") then
						local oldHighlight = btn:FindFirstChild("GamepadHighlight")
						if oldHighlight then oldHighlight:Destroy() end
					end
				end
			end
		end
	end
end

local lastStickMove = 0
local function handleGamepadInput()
	if not isMenuOpen or not menuFrame then return end
	
	local gamepad = UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)[1]
	if not gamepad then return end
	
	local now = tick()
	if now - lastStickMove < 0.15 then return end -- Anti-rebond
	
	-- Navigation avec le stick gauche
	local leftStick = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, input in ipairs(leftStick) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local xAxis = input.Position.X
			local yAxis = input.Position.Y
			
			-- Navigation verticale (items)
			if math.abs(yAxis) > 0.5 then
				if yAxis > 0.5 then
					-- Haut
					selectedSlotIndex = math.max(1, selectedSlotIndex - 1)
					updateGamepadSelection()
					lastStickMove = now
				elseif yAxis < -0.5 then
					-- Bas
					selectedSlotIndex = math.min(#allSlots, selectedSlotIndex + 1)
					updateGamepadSelection()
					lastStickMove = now
				end
			end
			
			-- Navigation horizontale (boutons)
			if math.abs(xAxis) > 0.5 then
				if xAxis < -0.5 then
					-- Gauche
					selectedButtonIndex = math.max(1, selectedButtonIndex - 1)
					updateGamepadSelection()
					lastStickMove = now
				elseif xAxis > 0.5 then
					-- Droite
					selectedButtonIndex = math.min(3, selectedButtonIndex + 1)
					updateGamepadSelection()
					lastStickMove = now
				end
			end
		end
	end
end

-- Connexion des inputs manette
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- 🔒 Bloquer TOUS les inputs si le menu n'est pas ouvert
	if not isMenuOpen then return end
	
	-- 🔒 CRITIQUE: Empêcher le jeu de traiter les inputs manette
	-- Marquer l'input comme "traité" en retournant immédiatement
	
	-- Bouton A (Xbox) / X (PlayStation) pour valider l'achat du bouton sélectionné
	if input.KeyCode == Enum.KeyCode.ButtonA then
		if #allSlots > 0 and selectedSlotIndex >= 1 and selectedSlotIndex <= #allSlots then
			local selectedSlot = allSlots[selectedSlotIndex]
			local ingredientName = selectedSlot.Name
			local buttonContainer = selectedSlot:FindFirstChild("ButtonContainer", true)
			
			if buttonContainer then
				local buttons = {
					buttonContainer:FindFirstChild("AcheterCinqBtn") or buttonContainer:FindFirstChild("VendreCinqBtn"),
					buttonContainer:FindFirstChild("AcheterUnBtn") or buttonContainer:FindFirstChild("VendreUnBtn"),
					buttonContainer:FindFirstChild("AcheterRobuxBtn")
				}
				
				local selectedBtn = buttons[selectedButtonIndex]
				if selectedBtn and selectedBtn.Active and selectedBtn.Visible then
					-- Simuler le clic en appelant directement les événements
					if currentTab == "buy" then
						if selectedBtn.Name == "AcheterCinqBtn" then
							achatIngredientEvent:FireServer(ingredientName, 5)
						elseif selectedBtn.Name == "AcheterUnBtn" then
							achatIngredientEvent:FireServer(ingredientName, 1)
						elseif selectedBtn.Name == "AcheterRobuxBtn" then
							buyIngredientRobuxEvent:FireServer(ingredientName, 1)
						end
					else -- sell tab
						if selectedBtn.Name == "VendreCinqBtn" then
							venteIngredientEvent:FireServer(ingredientName, 5)
						elseif selectedBtn.Name == "VendreUnBtn" then
							venteIngredientEvent:FireServer(ingredientName, 1)
						end
					end
					
					-- 🔒 Bloquer temporairement les inputs pour éviter le saut
					setGameInputsBlocked(true)
					
					-- Rafraîchir après achat
					task.delay(0.3, function()
						if refreshPlayerStock() and menuFrame then
							local scrollFrame = currentTab == "buy" and menuFrame:FindFirstChild("BuyScrollFrame") or menuFrame:FindFirstChild("SellScrollFrame")
							if scrollFrame then
								for _, slot in ipairs(scrollFrame:GetChildren()) do
									if slot:IsA("Frame") and slot.Name ~= "UIListLayout" then
										local ingName = slot.Name
										local stock = playerStock[ingName] or 0
										updateIngredientSlot(slot, stock)
									end
								end
							end
						end
						
						-- 🔓 Débloquer après un court délai
						task.wait(0.2)
						if isMenuOpen then
							setGameInputsBlocked(true) -- Re-bloquer si le menu est toujours ouvert
						end
					end)
				end
			end
		end
	end
	
	-- D-pad Gauche/Droite pour changer de bouton (x5, x1, Robux)
	if input.KeyCode == Enum.KeyCode.DPadLeft then
		selectedButtonIndex = math.max(1, selectedButtonIndex - 1)
		updateGamepadSelection()
	elseif input.KeyCode == Enum.KeyCode.DPadRight then
		selectedButtonIndex = math.min(3, selectedButtonIndex + 1)
		updateGamepadSelection()
	end
	
	-- D-pad Haut/Bas pour navigation entre items
	if input.KeyCode == Enum.KeyCode.DPadUp then
		selectedSlotIndex = math.max(1, selectedSlotIndex - 1)
		updateGamepadSelection()
	elseif input.KeyCode == Enum.KeyCode.DPadDown then
		selectedSlotIndex = math.min(#allSlots, selectedSlotIndex + 1)
		updateGamepadSelection()
	end
	
	-- Bouton B (Xbox) / Cercle (PlayStation) pour fermer le menu
	if input.KeyCode == Enum.KeyCode.ButtonB then
		if isMenuOpen then
			fermerMenu()
		end
	end
	
	-- L2/R2 pour changer d'onglet (Acheter/Vendre)
	if input.KeyCode == Enum.KeyCode.ButtonL2 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		local tabContainer = menuFrame and menuFrame:FindFirstChild("TabContainer")
		if tabContainer then
			if currentTab == "buy" then
				local sellTab = tabContainer:FindFirstChild("SellTab")
				if sellTab then
					for _, connection in pairs(getconnections(sellTab.MouseButton1Click)) do
						connection:Fire()
					end
					selectedSlotIndex = 1
					selectedButtonIndex = 1
					task.wait(0.1)
					updateGamepadSelection()
				end
			else
				local buyTab = tabContainer:FindFirstChild("BuyTab")
				if buyTab then
					for _, connection in pairs(getconnections(buyTab.MouseButton1Click)) do
						connection:Fire()
					end
					selectedSlotIndex = 1
					selectedButtonIndex = 1
					task.wait(0.1)
					updateGamepadSelection()
				end
			end
		end
	end
end)

-- Boucle de mise à jour pour le stick analogique
RunService.Heartbeat:Connect(function()
	if isMenuOpen then
		handleGamepadInput()
	end
end)

-- Mettre à jour la sélection quand le menu s'ouvre
local originalOuvrirMenu = ouvrirMenu
ouvrirMenu = function()
	originalOuvrirMenu()
	task.wait(0.1)
	selectedSlotIndex = 1
	updateGamepadSelection()
end

print("✅ Menu d'achat v3.0 (Style Simulateur) chargé !")
print("🎮 Contrôles manette activés:")
print("  • Stick gauche (↕) / D-pad (↕) : Changer d'item")
print("  • Stick gauche (↔) / D-pad (↔) : Changer de bouton (x5/x1/R$)")
print("  • A : Valider l'achat")
print("  • B : Fermer le menu")
print("  • L2/R2 : Changer d'onglet (Acheter/Vendre)")
print("  • R1/L1 : Changer d'item dans la hotbar (géré par CustomBackpack)") 