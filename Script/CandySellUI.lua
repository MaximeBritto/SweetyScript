-- CandySellUI.lua
-- Interface de vente pour bonbons à tailles variables
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Chargement du RecipeManager pour obtenir les prix des recettes
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- Fonction pour obtenir le prix de base d'un bonbon depuis le RecipeManager
local function getBasePriceFromRecipeManager(candyName)
	if RecipeManager and RecipeManager.Recettes then
		for recipeName, recipeData in pairs(RecipeManager.Recettes) do
			if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
				return recipeData.valeur or 15
			end
		end
	end
	return 15 -- Fallback si recette non trouvée
end

-- Plus besoin de CandySellManager - vente gérée par CandySellServer
-- local CandySellManager = require(ReplicatedStorage:WaitForChild("CandySellManager"))

-- RemoteEvents pour communication serveur
local sellRemotes = ReplicatedStorage:WaitForChild("CandySellRemotes")
local sellCandyRemote = sellRemotes:WaitForChild("SellCandy")
-- local getCandyPriceRemote = sellRemotes:WaitForChild("GetCandyPrice")

-- Variables UI
local sellGui = nil
local sellFrame = nil
local sellList = nil
local isSellMenuOpen = false

-- Variables globales pour détection responsive (partagées)
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
local textSizeMultiplier = isMobile and 0.8 or 1
local cornerRadius = isMobile and 8 or 12

-- Créer l'interface de vente (responsive)
local function createSellInterface()
	-- Recalculer les variables responsive à chaque ouverture
	viewportSize = workspace.CurrentCamera.ViewportSize
	isMobile = UserInputService.TouchEnabled
	isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
	textSizeMultiplier = isMobile and 0.75 or 1
	cornerRadius = isMobile and 8 or 12

	print("🔄 RECALCUL RESPONSIVE:", viewportSize.X .. "x" .. viewportSize.Y, isMobile and "MOBILE" or "DESKTOP")

	-- GUI principal (responsive)
	sellGui = Instance.new("ScreenGui")
	sellGui.Name = "CandySellUI"
	sellGui.ResetOnSpawn = false
	-- Pas d'IgnoreGuiInset sur mobile pour éviter les problèmes de centrage
	sellGui.IgnoreGuiInset = not isMobile
	sellGui.DisplayOrder = 1000
	sellGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sellGui.Parent = playerGui

	-- Frame principale (responsive correctement dimensionnée)
	sellFrame = Instance.new("Frame")
	sellFrame.Name = "SellFrame"
	-- Dimensionnement responsive amélioré
	local frameWidth, frameHeight
	if isMobile then
		-- Mobile : Menu légèrement réduit en largeur/hauteur
		frameWidth = math.floor(viewportSize.X * 0.94)
		frameHeight = math.floor(viewportSize.Y * 0.78)
	else
		-- Desktop : Taille normale restaurée
		frameWidth = 600
		frameHeight = 400
	end
	sellFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
	-- Centrage adapté mobile vs desktop
	if isMobile then
		-- Mobile : centrer mais plus haut pour éviter la hotbar
		local posX = (viewportSize.X - frameWidth) / 2
		local posY = math.max(10, (viewportSize.Y - frameHeight) / 2 - 40)
		sellFrame.Position = UDim2.new(0, posX, 0, posY)
		sellFrame.AnchorPoint = Vector2.new(0, 0)
	else
		-- Desktop : centrage classique avec AnchorPoint
		sellFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		sellFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	-- Debug pour mobile
	if isMobile or isSmallScreen then
		print("📱 MENU VENTE MOBILE:")
		print("  - Taille calculée:", frameWidth .. "x" .. frameHeight)
		print("  - Viewport:", viewportSize.X .. "x" .. viewportSize.Y)
		print("  - Position X:", (viewportSize.X - frameWidth) / 2)
		print("  - Position Y:", (viewportSize.Y - frameHeight) / 2)
		print("  - IgnoreGuiInset:", sellGui.IgnoreGuiInset)
		print("  - AnchorPoint: 0, 0 (absolu)")
	end
	sellFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	sellFrame.BorderSizePixel = 0
	sellFrame.Visible = false
	sellFrame.Parent = sellGui

	-- Coins arrondis (responsive)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius)
	corner.Parent = sellFrame

	-- Titre (responsive)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	local titleHeight = isMobile and 32 or 50
	titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	titleLabel.BorderSizePixel = 0
	titleLabel.Text = isMobile and "SALE" or "🍭 CANDY SALE 💰"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = isMobile and 14 or 20
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = false
	titleLabel.Parent = sellFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, cornerRadius)
	titleCorner.Parent = titleLabel

	-- Bouton fermer (responsive)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	local buttonSize = isMobile and 28 or 35  -- Plus petit sur mobile
	closeButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
	closeButton.Position = UDim2.new(1, -buttonSize - 5, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = isMobile and 12 or 16
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = (isMobile or isSmallScreen)
	closeButton.Parent = sellFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 4))
	closeCorner.Parent = closeButton

	-- Info argent (responsive)
	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "MoneyLabel"
	local moneyHeight = isMobile and 18 or 30
	local moneyTop = titleHeight + 10
	moneyLabel.Size = UDim2.new(1, -20, 0, moneyHeight)
	moneyLabel.Position = UDim2.new(0, 10, 0, moneyTop)
	moneyLabel.BackgroundTransparency = 1
	-- Valeur initiale formatée
	do
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local uiMod = ReplicatedStorage:FindFirstChild("UIUtils")
		local UIUtils = nil
		if uiMod and uiMod:IsA("ModuleScript") then
			local ok, mod = pcall(require, uiMod)
			if ok then UIUtils = mod end
		end
		local pd = player:FindFirstChild("PlayerData")
		local v = 0
		if pd and pd:FindFirstChild("Argent") then v = pd.Argent.Value end
		local textVal = tostring(v)
		if UIUtils and UIUtils.formatMoneyShort then textVal = UIUtils.formatMoneyShort(v) end
		moneyLabel.Text = isMobile and ("💰 " .. textVal .. "$") or ("💰 Argent: " .. textVal .. "$")
	end
	moneyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	moneyLabel.TextSize = isMobile and 12 or 16
	moneyLabel.Font = Enum.Font.GothamBold
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.TextScaled = (isMobile or isSmallScreen)  -- Auto-resize sur mobile
	moneyLabel.Parent = sellFrame

	-- ScrollingFrame pour la liste des bonbons (responsive amélioré)
	sellList = Instance.new("ScrollingFrame")
	sellList.Name = "SellList"
	local listTop = moneyTop + moneyHeight + 10
	-- Calcul de l'espace pour les boutons en bas
	local buttonSpace = isMobile and 64 or 90  -- Plus d'espace pour boutons mobiles
	sellList.Size = UDim2.new(1, -20, 1, -(listTop + buttonSpace))
	sellList.Position = UDim2.new(0, 10, 0, listTop)
	sellList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	sellList.BorderSizePixel = 0
	sellList.ScrollBarThickness = isMobile and 4 or 8  -- Plus fin sur mobile
	sellList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	sellList.CanvasSize = UDim2.new(0, 0, 0, 0)
	sellList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sellList.Parent = sellFrame

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, math.max(5, cornerRadius - 4))
	listCorner.Parent = sellList

	-- Layout pour la liste (responsive)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, isMobile and 2 or 5)  -- Espacement plus petit sur mobile
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = sellList

	-- Boutons d'action (responsive fixés)
	local buttonHeight = isMobile and 32 or 40
	local buttonMargin = 10

	-- Bouton "Tout vendre" (responsive)
	local sellAllButton = Instance.new("TextButton")
	sellAllButton.Name = "SellAllButton"
	sellAllButton.Size = UDim2.new(1, -20, 0, buttonHeight)
	sellAllButton.Position = UDim2.new(0, 10, 1, -(buttonHeight + buttonMargin))
	sellAllButton.BackgroundColor3 = Color3.fromRGB(40, 167, 69)
	sellAllButton.BorderSizePixel = 0
	sellAllButton.Text = isMobile and "💰 EVERYTHING" or "💰 SELL EVERYTHING"
	sellAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellAllButton.TextSize = isMobile and 12 or 16
	sellAllButton.Font = Enum.Font.GothamBold
	sellAllButton.TextScaled = (isMobile or isSmallScreen)
	sellAllButton.Parent = sellFrame

	local sellAllCorner = Instance.new("UICorner")
	sellAllCorner.CornerRadius = UDim.new(0, cornerRadius)
	sellAllCorner.Parent = sellAllButton

	-- (Test) Bouton ajout d'argent retiré

	-- Événements
	closeButton.MouseButton1Click:Connect(function()
		toggleSellMenu()
	end)

	sellAllButton.MouseButton1Click:Connect(function()
		warn("🖭 [SELLALL] Bouton 'Tout Vendre' cliqué!")
		sellAllCandies()
	end)

	-- (Test) Handler retiré
end

-- Créer un élément de la liste de vente (responsive)
local function createSellItem(candyInfo, index, isMobile, textSizeMultiplier, cornerRadius)
	-- Paramètres par défaut pour la rétrocompatibilité
	isMobile = isMobile or false
	textSizeMultiplier = textSizeMultiplier or 1
	cornerRadius = cornerRadius or 6

	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "SellItem_" .. index
	local itemHeight = isMobile and 40 or 60  -- Plus compact sur mobile
	itemFrame.Size = UDim2.new(1, -10, 0, itemHeight)
	itemFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = index
	itemFrame.Parent = sellList

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, math.max(4, cornerRadius - 2))
	itemCorner.Parent = itemFrame

	-- Couleur de rareté (bande latérale)
	local rarityBar = Instance.new("Frame")
	rarityBar.Size = UDim2.new(0, 5, 1, 0)
	rarityBar.Position = UDim2.new(0, 0, 0, 0)
	rarityBar.BorderSizePixel = 0
	rarityBar.Parent = itemFrame

	-- Couleur selon rareté
	local rarityColors = {
		["Tiny"] = Color3.fromRGB(150, 150, 150),
		["Small"] = Color3.fromRGB(255, 200, 100),
		["Normal"] = Color3.fromRGB(255, 255, 255),
		["Large"] = Color3.fromRGB(100, 255, 100),
		["Giant"] = Color3.fromRGB(100, 200, 255),
		["Colossal"] = Color3.fromRGB(255, 100, 255),
		["LEGENDARY"] = Color3.fromRGB(255, 215, 0)
	}
	rarityBar.BackgroundColor3 = rarityColors[candyInfo.rarity] or Color3.fromRGB(255, 255, 255)

	-- Nom du bonbon (responsive)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(isMobile and 0.58 or 0.5, -10, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 15, 0, isMobile and 2 or 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = isMobile and 11 or 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextScaled = isMobile  -- Auto-resize sur mobile
	nameLabel.Parent = itemFrame

	-- Affichage simple du bonbon (responsive)
	local displayName = candyInfo.baseName .. " x" .. candyInfo.quantity
	local UIUtils_local
	do
		local uiMod = ReplicatedStorage:FindFirstChild("UIUtils")
		if uiMod and uiMod:IsA("ModuleScript") then
			local ok, mod = pcall(require, uiMod)
			if ok then UIUtils_local = mod end
		end
	end
	local priceText = (UIUtils_local and UIUtils_local.formatMoneyShort) and (UIUtils_local.formatMoneyShort(candyInfo.totalPrice) .. "$") or (candyInfo.totalPrice .. "$")
	nameLabel.Text = displayName

	-- Prix (responsive)
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(isMobile and 0.28 or 0.3, 0, 0.5, 0)
	priceLabel.Position = UDim2.new(isMobile and 0.58 or 0.5, 0, 0, isMobile and 1 or 5)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = priceText
	priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	priceLabel.TextSize = isMobile and 12 or 16
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.TextYAlignment = Enum.TextYAlignment.Center
	priceLabel.TextScaled = isMobile  -- Auto-resize sur mobile
	priceLabel.Parent = itemFrame

	-- Détails (rareté + taille) - responsive
	local detailLabel = Instance.new("TextLabel")
	detailLabel.Size = UDim2.new(1, isMobile and -90 or -105, 0.5, 0)  -- Laisser place au bouton
	detailLabel.Position = UDim2.new(0, 15, 0.5, 0)
	detailLabel.BackgroundTransparency = 1
	-- Texte plus compact sur mobile
	local unitShort = (UIUtils_local and UIUtils_local.formatMoneyShort) and UIUtils_local.formatMoneyShort(candyInfo.unitPrice) or tostring(candyInfo.unitPrice)
	local detailText = isMobile and (candyInfo.rarity .. " " .. unitShort .. "$") or (candyInfo.rarity .. " (" .. math.floor(candyInfo.size * 100) .. "%) • " .. unitShort .. "$ l'unité")
	detailLabel.Text = detailText
	detailLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	detailLabel.TextSize = isMobile and 10 or 12
	detailLabel.Font = Enum.Font.Gotham
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextYAlignment = Enum.TextYAlignment.Center
	detailLabel.TextScaled = isMobile  -- Auto-resize sur mobile
	detailLabel.Parent = itemFrame

	-- Bouton vendre (responsive)
	local sellButton = Instance.new("TextButton")
	local buttonWidth = isMobile and 60 or 80
	local buttonHeight = isMobile and 26 or 25
	sellButton.Size = UDim2.new(0, buttonWidth, 0, buttonHeight)
	sellButton.Position = UDim2.new(1, -(buttonWidth + 10), 0.5, -(buttonHeight/2))
	sellButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	sellButton.BorderSizePixel = 0
	sellButton.Text = isMobile and "$" or "SELL"
	sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellButton.TextSize = math.floor(12 * textSizeMultiplier)
	sellButton.Font = Enum.Font.GothamBold
	sellButton.TextScaled = isMobile  -- Auto-resize sur mobile
	sellButton.Parent = itemFrame

	local sellCorner = Instance.new("UICorner")
	sellCorner.CornerRadius = UDim.new(0, 4)
	sellCorner.Parent = sellButton

	-- Événement de vente
	sellButton.MouseButton1Click:Connect(function()
		sellCandy(candyInfo)
	end)

	return itemFrame
end

-- Mettre à jour la liste des bonbons à vendre (responsive)
function updateSellList()
	-- Variables responsives déjà définies globalement

	-- Nettoyer la liste existante
	for _, child in pairs(sellList:GetChildren()) do
		if child.Name:find("SellItem_") then
			child:Destroy()
		end
	end

	-- Récupérer tous les Tools du backpack ET du character (main)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	local tools = {}

	-- Tools dans le backpack
	if backpack then
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") == true then
				table.insert(tools, tool)
				print("🍬 BONBON BACKPACK:", tool.Name, "BaseName:", tool:GetAttribute("BaseName"))
			elseif tool:IsA("Tool") and tool:GetAttribute("BaseName") and not tool:GetAttribute("IsCandy") then
				print("🧑‍🍳 INGREDIENT IGNORÉ:", tool.Name, "BaseName:", tool:GetAttribute("BaseName"))
			end
		end
	end

	-- Tools dans la main (character)
	if character then
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("IsCandy") == true then
				table.insert(tools, tool)
				print("👍 BONBON EN MAIN:", tool.Name, "BaseName:", tool:GetAttribute("BaseName"))
			elseif tool:IsA("Tool") and tool:GetAttribute("BaseName") and not tool:GetAttribute("IsCandy") then
				print("🧑‍🍳 INGREDIENT EN MAIN IGNORÉ:", tool.Name, "BaseName:", tool:GetAttribute("BaseName"))
			end
		end
	end

	print("📊 TOTAL BONBONS VENDABLES:", #tools)

	-- Lire les vraies informations des bonbons
	local candyInfos = {}
	for _, tool in pairs(tools) do
		local stackSize = tool:GetAttribute("StackSize") or 1
		local baseName = tool:GetAttribute("BaseName") or tool.Name

		-- Lire les vraies données de taille et rareté
		local candySize = tool:GetAttribute("CandySize") or 1.0
		local candyRarity = tool:GetAttribute("CandyRarity") or "Normal"

		-- Obtenir le prix de base depuis le RecipeManager
		local basePrice = getBasePriceFromRecipeManager(baseName)
		local sizeMultiplier = candySize ^ 2.5 -- Progression exponentielle

		-- Bonus de rareté
		local rarityBonus = 1
		if candyRarity == "Grand" then rarityBonus = 1.1
		elseif candyRarity == "Géant" then rarityBonus = 1.2
		elseif candyRarity == "Colossal" then rarityBonus = 1.5
		elseif candyRarity == "LÉGENDAIRE" then rarityBonus = 2.0
		end

		local unitPrice = math.floor(basePrice * sizeMultiplier * rarityBonus)
		local totalPrice = math.max(unitPrice * stackSize, 1)

		table.insert(candyInfos, {
			tool = tool,
			baseName = baseName,
			quantity = stackSize,
			unitPrice = unitPrice,
			totalPrice = totalPrice,
			rarity = candyRarity,
			size = candySize
		})
	end

	-- Trier par prix total décroissant
	table.sort(candyInfos, function(a, b)
		return a.totalPrice > b.totalPrice
	end)

	-- Créer les éléments de liste (responsive)
	for i, candyInfo in ipairs(candyInfos) do
		createSellItem(candyInfo, i, isMobile or isSmallScreen, textSizeMultiplier, cornerRadius - 4)
	end

	-- Mettre à jour l'affichage de l'argent
	updateMoneyDisplay()
end

-- Mettre à jour l'affichage de l'argent
function updateMoneyDisplay()
	local playerData = player:FindFirstChild("PlayerData")
	local money = nil
	local moneyValue = 0

	-- Système PlayerData.Argent (priorité)
	if playerData then
		money = playerData:FindFirstChild("Argent")
		if money then
			moneyValue = money.Value
			print("💰 UI ARGENT DÉTECTÉ: PlayerData.Argent =", moneyValue)
		end
	end

	-- Fallback: leaderstats.Argent
	if not money then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			money = leaderstats:FindFirstChild("Argent")
			if money then
				moneyValue = money.Value
				print("💰 UI FALLBACK: leaderstats.Argent =", moneyValue)
			end
		end
	end

	-- Format abrégé via UIUtils (100k, 1.2m, 4t, ...)
	local UIUtils = nil
	local uiMod = ReplicatedStorage:FindFirstChild("UIUtils")
	if uiMod and uiMod:IsA("ModuleScript") then
		local ok, mod = pcall(require, uiMod)
		if ok then UIUtils = mod end
	end
	local formatted = tostring(moneyValue)
	if UIUtils and UIUtils.formatMoneyShort then
		formatted = UIUtils.formatMoneyShort(moneyValue)
	end
	sellFrame.MoneyLabel.Text = (isMobile and ("💰 " .. formatted .. "$") or ("💰 Money: " .. formatted .. "$"))

	if not money then
		print("❌ UI: AUCUN ARGENT DÉTECTÉ pour", player.Name)
	end
end

-- Vendre un bonbon spécifique via RemoteFunction
function sellCandy(candyInfo)
	if not candyInfo.tool then return end

	-- Pour identifier le bon bonbon de manière unique, on envoie plusieurs attributs
	local toolData = {
		name = candyInfo.tool.Name,
		size = candyInfo.tool:GetAttribute("CandySize") or 1.0,
		rarity = candyInfo.tool:GetAttribute("CandyRarity") or "Normal",
		stackSize = candyInfo.tool:GetAttribute("StackSize") or 1
	}
	
	warn("🚀 [UI-SELL] Appel vente pour:", toolData.name, "| Size:", toolData.size, "| Rarity:", toolData.rarity, "| Stack:", toolData.stackSize)
	
	-- Utiliser le RemoteFunction CandySellServer avec identification unique
	local success, message = sellCandyRemote:InvokeServer(toolData)

	if success then
		print("✅ " .. message)
		updateSellList() -- Rafraîchir la liste
	else
		warn("❌ Erreur de vente: " .. message)
	end
end

-- Vendre tous les bonbons
function sellAllCandies()
	warn("🔥 [SELLALL] DÉBUT de sellAllCandies()")

	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	
	if not backpack and not character then 
		warn("❌ [SELLALL] Ni backpack ni character trouvé!")
		return 
	end

	warn("✅ [SELLALL] Recherche des bonbons...")

	local totalEarned = 0
	local candiesSold = 0

	local tools = {}
	
	-- Récupérer les bonbons dans le backpack (même filtre que updateSellList)
	if backpack then
		warn("🔍 [SELLALL] Scan du BACKPACK...")
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				local isCandy = tool:GetAttribute("IsCandy")
				local baseName = tool:GetAttribute("BaseName")
				warn("  📦 [SELLALL] Tool:", tool.Name, "| IsCandy:", isCandy, "| BaseName:", baseName)
				
				if isCandy == true then
					warn("  ✅ [SELLALL] → Ajouté à la liste de vente (BACKPACK)")
					table.insert(tools, tool)
				elseif baseName and not isCandy then
					warn("  ⏭️ [SELLALL] → Ingrédient IGNORÉ")
				end
			end
		end
	end
	
	-- IMPORTANT : Récupérer aussi les bonbons équipés dans le character
	if character then
		warn("🔍 [SELLALL] Scan du CHARACTER (équipé)...")
		for _, tool in pairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				local isCandy = tool:GetAttribute("IsCandy")
				local baseName = tool:GetAttribute("BaseName")
				warn("  👤 [SELLALL] Tool:", tool.Name, "| IsCandy:", isCandy, "| BaseName:", baseName, "| Parent:", tool.Parent.Name)
				
				if isCandy == true then
					warn("  ✅ [SELLALL] → Ajouté à la liste de vente (CHARACTER)")
					table.insert(tools, tool)
				elseif baseName and not isCandy then
					warn("  ⏭️ [SELLALL] → Ingrédient IGNORÉ en main")
				end
			end
		end
	else
		warn("⚠️ [SELLALL] Pas de character trouvé!")
	end

	warn("📊 [SELLALL] Total bonbons à vendre:", #tools, "(backpack + équipés)")

	if #tools == 0 then
		warn("⚠️ [SELLALL] Aucun bonbon trouvé à vendre!")
		return
	end

	-- Vendre chaque bonbon individuellement
	for i, tool in pairs(tools) do
		warn("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		warn("🔄 [SELLALL] Traitement " .. i .. "/" .. #tools)
		
		-- Vérifier que l'outil existe encore (pas détruit)
		if not tool.Parent then
			warn("⚠️ [SELLALL] Outil déjà détruit:", tool.Name)
			continue
		end
		
		-- Debug : où est le tool maintenant ?
		local toolLocation = "INCONNU"
		if tool.Parent == backpack then
			toolLocation = "BACKPACK"
		elseif tool.Parent == character then
			toolLocation = "CHARACTER"
		else
			toolLocation = tool.Parent and tool.Parent.Name or "NIL"
		end
		warn("📍 [SELLALL] Tool:", tool.Name, "| Location:", toolLocation, "| Parent:", tool.Parent and tool.Parent.Name or "nil")

		local stackSize = tool:GetAttribute("StackSize") or 1

		-- Calculer le vrai prix comme dans updateSellList
		local baseName = tool:GetAttribute("BaseName") or tool.Name
		local candySize = tool:GetAttribute("CandySize") or 1.0
		local candyRarity = tool:GetAttribute("CandyRarity") or "Normal"

		local basePrice = getBasePriceFromRecipeManager(baseName)
		local sizeMultiplier = candySize ^ 2.5
		local rarityBonus = 1
		if candyRarity == "Grand" then rarityBonus = 1.1
		elseif candyRarity == "Géant" then rarityBonus = 1.2
		elseif candyRarity == "Colossal" then rarityBonus = 1.5
		elseif candyRarity == "LÉGENDAIRE" then rarityBonus = 2.0
		end

		local unitPrice = math.floor(basePrice * sizeMultiplier * rarityBonus)
		local totalPrice = math.max(unitPrice * stackSize, 1)

		-- Préparer les données d'identification unique du tool
		local toolData = {
			name = tool.Name,
			size = candySize,
			rarity = candyRarity,
			stackSize = stackSize
		}
		
		-- Vendre via RemoteFunction avec identification unique
		warn("🚀 [UI-SELLALL] Envoi au serveur:", toolData.name, "x" .. toolData.stackSize, "(", toolData.rarity, toolData.size .. "x) ->", totalPrice .. "$")

		local success, message = sellCandyRemote:InvokeServer(toolData)

		if success then
			totalEarned = totalEarned + totalPrice
			candiesSold = candiesSold + stackSize
			warn("✅ [SELLALL] Vendu avec succès:", tool.Name, "pour", totalPrice .. "$")
		else
			warn("❌ [SELLALL] Échec vente:", tool.Name, "Erreur:", message or "Inconnue")
		end

		-- Petite pause pour éviter la surcharge
		task.wait(0.1)
	end
	
	warn("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	print("🎉 VENTE MASSIVE: " .. candiesSold .. " bonbons vendus pour " .. totalEarned .. "$")
	updateSellList()
end

-- Basculer le menu de vente (responsive)
function toggleSellMenu()
	if not sellFrame then return end

	isSellMenuOpen = not isSellMenuOpen
	sellFrame.Visible = isSellMenuOpen

	if isSellMenuOpen then
		-- Recalculer les dimensions responsive à chaque ouverture
		viewportSize = workspace.CurrentCamera.ViewportSize
		isMobile = UserInputService.TouchEnabled
		isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

		local frameWidth, frameHeight
		if isMobile then
			-- Mobile : mêmes valeurs que la création
			frameWidth = math.floor(viewportSize.X * 0.94)
			frameHeight = math.floor(viewportSize.Y * 0.78)
		else
			-- Desktop : Taille normale
			frameWidth = 600
			frameHeight = 400
		end

		-- Appliquer les nouvelles dimensions au frame existant
		sellFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)

		-- Recalculer la position selon la plateforme
		if isMobile then
			-- Mobile : Centrer mais plus haut pour éviter la hotbar en bas
			local posX = (viewportSize.X - frameWidth) / 2
			local posY = math.max(10, (viewportSize.Y - frameHeight) / 2 - 40)  -- 40px plus haut
			sellFrame.Position = UDim2.new(0, posX, 0, posY)
			sellFrame.AnchorPoint = Vector2.new(0, 0)
		else
			-- Desktop : Centrage normal
			sellFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			sellFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		end

		print("📱 OUVERTURE MENU - Dimensions appliquées:", frameWidth .. "x" .. frameHeight)

		-- 🎓 TUTORIAL: Signaler l'ouverture du sac au tutoriel
		local tutorialRemote = ReplicatedStorage:FindFirstChild("TutorialRemote")
		if tutorialRemote then
			print("🎓 [TUTORIAL] Signalement ouverture sac au tutoriel")
			tutorialRemote:FireServer("bag_opened")
		end

		updateSellList()

		-- Animation d'ouverture simplifiée (pas de resize animé)
		sellFrame.BackgroundTransparency = 1
		TweenService:Create(sellFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 0
		}):Play()
	end
end

-- Initialisation
local function initialize()
	createSellInterface()

	-- Rendre la fonction accessible globalement pour le bouton hotbar
	_G.openSellMenu = toggleSellMenu

	-- Raccourci clavier (V pour Vendre)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.V then
			toggleSellMenu()
		end
	end)

	print("✅ INTERFACE DE VENTE PRÊTE !")
	print("💡 Appuyez sur V pour ouvrir le menu de vente")
	print("💡 Cliquez sur le bouton 💰 VENTE dans la hotbar")
end

-- Démarrage
initialize()
