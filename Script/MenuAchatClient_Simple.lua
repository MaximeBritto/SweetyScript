-- 🛒 MENU ACHAT SIMPLIFIÉ
-- Version minimaliste pour apprendre l'UI Roblox Studio
-- À placer dans StarterGui > ShopUI (LocalScript)

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- ========================================
-- 📦 CONFIGURATION
-- ========================================

-- Récupérer le ScreenGui et le MenuFrame que tu as créés dans Studio
local screenGui = script.Parent -- ShopUI
local menuFrame = screenGui:WaitForChild("MenuFrame")
local closeButton = menuFrame:WaitForChild("Header"):WaitForChild("CloseButton")
local scrollFrame = menuFrame:WaitForChild("ItemsScrollFrame")

-- RemoteEvents (assure-toi qu'ils existent dans ReplicatedStorage)
local ouvrirMenuEvent = ReplicatedStorage:WaitForChild("OuvrirMenuEvent")
local achatIngredientEvent = ReplicatedStorage:WaitForChild("AchatIngredientEvent_V2")

-- Module RecipeManager (pour récupérer la liste des ingrédients)
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- Variables
local isMenuOpen = false

-- ========================================
-- 🎨 FONCTIONS UI
-- ========================================

-- Créer un slot d'ingrédient
local function createItemSlot(ingredientName, ingredientData, layoutOrder)
	-- Créer le Frame principal
	local slot = Instance.new("Frame")
	slot.Name = ingredientName
	slot.Size = UDim2.new(1, 0, 0, 100)
	slot.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
	slot.BorderSizePixel = 0
	slot.LayoutOrder = layoutOrder
	
	-- Coins arrondis
	local corner = Instance.new("UICorner", slot)
	corner.CornerRadius = UDim.new(0, 8)
	
	-- Bordure
	local stroke = Instance.new("UIStroke", slot)
	stroke.Color = Color3.fromRGB(87, 60, 34)
	stroke.Thickness = 3
	
	-- Icône (Frame simple pour l'instant)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconFrame"
	iconFrame.Size = UDim2.new(0, 80, 0, 80)
	iconFrame.Position = UDim2.new(0, 10, 0, 10)
	iconFrame.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = slot
	
	local iconCorner = Instance.new("UICorner", iconFrame)
	iconCorner.CornerRadius = UDim.new(0, 8)
	
	-- Nom de l'ingrédient
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.5, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 100, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ingredientData.nom or ingredientName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 24
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = slot
	
	-- Prix
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(0.4, 0, 0, 25)
	priceLabel.Position = UDim2.new(0, 100, 0, 45)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = "Prix: " .. tostring(ingredientData.prix) .. "$"
	priceLabel.TextColor3 = Color3.fromRGB(130, 255, 130)
	priceLabel.TextSize = 20
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Parent = slot
	
	-- Bouton Acheter
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.Size = UDim2.new(0, 100, 0, 40)
	buyButton.Position = UDim2.new(1, -110, 1, -50)
	buyButton.Text = "ACHETER"
	buyButton.TextSize = 18
	buyButton.TextColor3 = Color3.new(1, 1, 1)
	buyButton.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
	buyButton.BorderSizePixel = 0
	buyButton.Parent = slot
	
	local btnCorner = Instance.new("UICorner", buyButton)
	btnCorner.CornerRadius = UDim.new(0, 8)
	
	local btnStroke = Instance.new("UIStroke", buyButton)
	btnStroke.Color = Color3.fromRGB(0, 0, 0)
	btnStroke.Thickness = 2
	
	-- Connexion du bouton
	buyButton.MouseButton1Click:Connect(function()
		print("🛒 Achat de:", ingredientName)
		achatIngredientEvent:FireServer(ingredientName, 1)
	end)
	
	return slot
end

-- Construire tous les slots
local function buildShop()
	-- Effacer les anciens slots
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Créer un slot pour chaque ingrédient
	local orderIndex = 0
	for _, ingredientName in ipairs(RecipeManager.IngredientOrder or {}) do
		local ingredientData = RecipeManager.Ingredients[ingredientName]
		if ingredientData then
			orderIndex = orderIndex + 1
			local slot = createItemSlot(ingredientName, ingredientData, orderIndex)
			slot.Parent = scrollFrame
		end
	end
	
	print("✅ Shop construit avec", orderIndex, "ingrédients")
end

-- ========================================
-- 🎬 ANIMATIONS
-- ========================================

-- Ouvrir le menu
local function openMenu()
	if isMenuOpen then return end
	isMenuOpen = true
	
	-- Construire le shop
	buildShop()
	
	-- Rendre visible
	menuFrame.Visible = true
	
	-- Animation d'ouverture (de 0 à taille normale)
	menuFrame.Size = UDim2.new(0, 0, 0, 0)
	local tween = TweenService:Create(
		menuFrame,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UDim2.new(0.6, 0, 0.7, 0)}
	)
	tween:Play()
	
	print("🛒 Menu ouvert")
end

-- Fermer le menu
local function closeMenu()
	if not isMenuOpen then return end
	
	-- Animation de fermeture
	local tween = TweenService:Create(
		menuFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Size = UDim2.new(0, 0, 0, 0)}
	)
	tween:Play()
	
	tween.Completed:Connect(function()
		menuFrame.Visible = false
		isMenuOpen = false
		print("🛒 Menu fermé")
	end)
end

-- ========================================
-- 🔌 CONNEXIONS
-- ========================================

-- Bouton fermer
closeButton.MouseButton1Click:Connect(closeMenu)

-- Événement d'ouverture depuis le serveur
ouvrirMenuEvent.OnClientEvent:Connect(openMenu)

-- Fermer avec Échap (optionnel)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isMenuOpen then
		closeMenu()
	end
end)

print("✅ Menu Achat Simplifié chargé !")
