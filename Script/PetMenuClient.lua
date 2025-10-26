-- PetMenuClient.lua
-- Script client pour l'interface du menu PETs
-- À placer dans StarterGui > ScreenGui

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

-- Détection plateforme
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
local Z_BASE = 2000

-- Modules
local PetManager = require(ReplicatedStorage:WaitForChild("PetManager"))
print("🐾 [PET MENU] PetManager chargé, nombre de PETs:", #PetManager.PetOrder)
local UIUtils = ReplicatedStorage:FindFirstChild("UIUtils")
if UIUtils then UIUtils = require(UIUtils) end

-- RemoteEvents
local ouvrirMenuPetEvent = ReplicatedStorage:WaitForChild("OuvrirMenuPetEvent")
local achatPetEvent = ReplicatedStorage:FindFirstChild("AchatPetEvent")
if not achatPetEvent then
	achatPetEvent = Instance.new("RemoteEvent")
	achatPetEvent.Name = "AchatPetEvent"
	achatPetEvent.Parent = ReplicatedStorage
end

local achatPetRobuxEvent = ReplicatedStorage:FindFirstChild("AchatPetRobuxEvent")
if not achatPetRobuxEvent then
	achatPetRobuxEvent = Instance.new("RemoteEvent")
	achatPetRobuxEvent.Name = "AchatPetRobuxEvent"
	achatPetRobuxEvent.Parent = ReplicatedStorage
end

local equipPetEvent = ReplicatedStorage:FindFirstChild("EquipPetEvent")
if not equipPetEvent then
	equipPetEvent = Instance.new("RemoteEvent")
	equipPetEvent.Name = "EquipPetEvent"
	equipPetEvent.Parent = ReplicatedStorage
end

-- Variables
local menuFrame = nil
local isMenuOpen = false
local connections = {}

-- Bloquer/débloquer inputs
local function setGameInputsBlocked(blocked)
	if blocked then
		ContextActionService:BindAction("BlockJump", function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction("BlockJump")
	end
end

-- Obtenir les PETs possédés par le joueur
local function getPlayerPets()
	local playerData = player:FindFirstChild("PlayerData")
	local petsFolder = playerData and playerData:FindFirstChild("Pets")
	if not petsFolder then return {} end
	
	local pets = {}
	for _, petValue in ipairs(petsFolder:GetChildren()) do
		if petValue:IsA("StringValue") then
			table.insert(pets, petValue.Value)
		end
	end
	return pets
end

-- Obtenir les PETs équipés
local function getEquippedPets()
	local playerData = player:FindFirstChild("PlayerData")
	local equippedPetsFolder = playerData and playerData:FindFirstChild("EquippedPets")
	if not equippedPetsFolder then return {} end
	
	local pets = {}
	for _, petValue in ipairs(equippedPetsFolder:GetChildren()) do
		if petValue:IsA("StringValue") then
			pets[petValue.Value] = true
		end
	end
	return pets
end

-- Créer un slot de PET
local function createPetSlot(parent, petName, petData, isOwned)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = petName
	
	local slotHeight = (isMobile or isSmallScreen) and 100 or 140
	slotFrame.Size = UDim2.new(1, 0, 0, slotHeight)
	slotFrame.BackgroundColor3 = Color3.fromRGB(70, 50, 90)
	slotFrame.BorderSizePixel = 0
	slotFrame.ZIndex = Z_BASE + 1
	
	local corner = Instance.new("UICorner", slotFrame)
	corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 10)
	
	local stroke = Instance.new("UIStroke", slotFrame)
	stroke.Color = petData.couleurRarete
	stroke.Thickness = (isMobile or isSmallScreen) and 3 or 4
	
	-- Viewport pour le PET (placeholder)
	local viewport = Instance.new("ViewportFrame")
	local vpSize = (isMobile or isSmallScreen) and 60 or 110
	viewport.Size = UDim2.new(0, vpSize, 0, vpSize)
	viewport.Position = UDim2.new(0, 10, 0.5, -(vpSize/2))
	viewport.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
	viewport.BorderSizePixel = 0
	viewport.ZIndex = Z_BASE + 1
	viewport.Parent = slotFrame
	
	local vpCorner = Instance.new("UICorner", viewport)
	vpCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)
	
	local vpStroke = Instance.new("UIStroke", viewport)
	vpStroke.Color = petData.couleurRarete
	vpStroke.Thickness = 2
	
	-- Icône PET (emoji temporaire)
	local petIcon = Instance.new("TextLabel")
	petIcon.Size = UDim2.new(1, 0, 1, 0)
	petIcon.BackgroundTransparency = 1
	petIcon.Text = isOwned and "🐾" or "🔒"
	petIcon.TextColor3 = Color3.new(1, 1, 1)
	petIcon.TextSize = (isMobile or isSmallScreen) and 30 or 50
	petIcon.Font = Enum.Font.GothamBold
	petIcon.ZIndex = Z_BASE + 2
	petIcon.Parent = viewport
	
	-- Nom du PET
	local labelStartX = vpSize + 20
	local nomLabel = Instance.new("TextLabel")
	nomLabel.Size = UDim2.new(0.5, 0, 0, (isMobile or isSmallScreen) and 22 or 32)
	nomLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 5 or 10)
	nomLabel.BackgroundTransparency = 1
	nomLabel.Text = isOwned and petData.nom or "???"
	nomLabel.TextColor3 = Color3.new(1, 1, 1)
	nomLabel.TextSize = (isMobile or isSmallScreen) and 16 or 24
	nomLabel.Font = Enum.Font.GothamBold
	nomLabel.TextXAlignment = Enum.TextXAlignment.Left
	nomLabel.TextScaled = (isMobile or isSmallScreen)
	nomLabel.ZIndex = Z_BASE + 1
	nomLabel.Parent = slotFrame
	
	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.5, 0, 0, (isMobile or isSmallScreen) and 18 or 26)
	descLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 27 or 42)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = isOwned and petData.description or "Achetez pour débloquer"
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextSize = (isMobile or isSmallScreen) and 12 or 18
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextScaled = (isMobile or isSmallScreen)
	descLabel.ZIndex = Z_BASE + 1
	descLabel.Parent = slotFrame
	
	-- Boost info
	local boostLabel = Instance.new("TextLabel")
	boostLabel.Size = UDim2.new(0.5, 0, 0, (isMobile or isSmallScreen) and 16 or 24)
	boostLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 50 or 70)
	boostLabel.BackgroundTransparency = 1
	local boostText = isOwned and string.format("⚡ %s: +%.0f%%", petData.boostType, (petData.boostValue - 1) * 100) or "???"
	boostLabel.Text = boostText
	boostLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	boostLabel.TextSize = (isMobile or isSmallScreen) and 11 or 18
	boostLabel.Font = Enum.Font.GothamBold
	boostLabel.TextXAlignment = Enum.TextXAlignment.Left
	boostLabel.TextScaled = (isMobile or isSmallScreen)
	boostLabel.ZIndex = Z_BASE + 1
	boostLabel.Parent = slotFrame
	
	-- Prix
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(0.4, 0, 0, (isMobile or isSmallScreen) and 18 or 26)
	priceLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 70 or 98)
	priceLabel.BackgroundTransparency = 1
	local formattedPrice = UIUtils and UIUtils.formatMoneyShort and UIUtils.formatMoneyShort(petData.prix) or tostring(petData.prix)
	priceLabel.Text = isOwned and "✅ Possédé" or ("Prix: " .. formattedPrice .. "$")
	priceLabel.TextColor3 = isOwned and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 220, 100)
	priceLabel.TextSize = (isMobile or isSmallScreen) and 12 or 20
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.TextScaled = (isMobile or isSmallScreen)
	priceLabel.ZIndex = Z_BASE + 1
	priceLabel.Parent = slotFrame
	
	-- Badge rareté
	local rareteLabel = Instance.new("TextLabel")
	local rareteWidth = (isMobile or isSmallScreen) and 70 or 110
	local rareteHeight = (isMobile or isSmallScreen) and 18 or 28
	rareteLabel.Size = UDim2.new(0, rareteWidth, 0, rareteHeight)
	rareteLabel.Position = UDim2.new(1, -(rareteWidth + 10), 0, (isMobile or isSmallScreen) and 5 or 10)
	rareteLabel.BackgroundColor3 = petData.couleurRarete
	rareteLabel.Text = petData.rarete
	rareteLabel.TextColor3 = Color3.new(1, 1, 1)
	rareteLabel.TextSize = (isMobile or isSmallScreen) and 12 or 18
	rareteLabel.Font = Enum.Font.SourceSansBold
	rareteLabel.TextScaled = (isMobile or isSmallScreen)
	rareteLabel.ZIndex = Z_BASE + 2
	rareteLabel.Parent = slotFrame
	
	local rCorner = Instance.new("UICorner", rareteLabel)
	rCorner.CornerRadius = UDim.new(0, 8)
	
	-- Boutons (Acheter / Équiper)
	if not isOwned then
		-- Bouton Acheter (argent)
		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.new(0, (isMobile or isSmallScreen) and 80 or 120, 0, (isMobile or isSmallScreen) and 32 or 40)
		buyBtn.Position = UDim2.new(1, -((isMobile or isSmallScreen) and 90 or 135), 1, -((isMobile or isSmallScreen) and 40 or 50))
		buyBtn.Text = "ACHETER"
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
		buyBtn.ZIndex = Z_BASE + 3
		buyBtn.Parent = slotFrame
		
		local bCorner = Instance.new("UICorner", buyBtn)
		bCorner.CornerRadius = UDim.new(0, 8)
		
		local bStroke = Instance.new("UIStroke", buyBtn)
		bStroke.Thickness = 2
		bStroke.Color = Color3.fromRGB(50, 100, 50)
		
		buyBtn.MouseButton1Click:Connect(function()
			achatPetEvent:FireServer(petName, "Money")
		end)
		
		-- Bouton Acheter Robux
		local buyRobuxBtn = Instance.new("TextButton")
		buyRobuxBtn.Name = "BuyRobuxBtn"
		buyRobuxBtn.Size = UDim2.new(0, (isMobile or isSmallScreen) and 70 or 100, 0, (isMobile or isSmallScreen) and 32 or 40)
		buyRobuxBtn.Position = UDim2.new(1, -((isMobile or isSmallScreen) and 170 or 250), 1, -((isMobile or isSmallScreen) and 40 or 50))
		buyRobuxBtn.Text = "R$ " .. petData.prixRobux
		buyRobuxBtn.Font = Enum.Font.GothamBold
		buyRobuxBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
		buyRobuxBtn.TextColor3 = Color3.new(0, 0, 0)
		buyRobuxBtn.BackgroundColor3 = Color3.fromRGB(235, 200, 60)
		buyRobuxBtn.ZIndex = Z_BASE + 3
		buyRobuxBtn.Parent = slotFrame
		
		local brCorner = Instance.new("UICorner", buyRobuxBtn)
		brCorner.CornerRadius = UDim.new(0, 8)
		
		local brStroke = Instance.new("UIStroke", buyRobuxBtn)
		brStroke.Thickness = 2
		brStroke.Color = Color3.fromRGB(120, 90, 30)
		
		buyRobuxBtn.MouseButton1Click:Connect(function()
			achatPetRobuxEvent:FireServer(petName)
		end)
	else
		-- Bouton Équiper/Déséquiper
		local equippedPets = getEquippedPets()
		local isEquipped = equippedPets[petName] == true
		
		local equipBtn = Instance.new("TextButton")
		equipBtn.Name = "EquipBtn"
		equipBtn.Size = UDim2.new(0, (isMobile or isSmallScreen) and 90 or 130, 0, (isMobile or isSmallScreen) and 32 or 40)
		equipBtn.Position = UDim2.new(1, -((isMobile or isSmallScreen) and 100 or 145), 1, -((isMobile or isSmallScreen) and 40 or 50))
		equipBtn.Text = isEquipped and "✓ ÉQUIPÉ" or "ÉQUIPER"
		equipBtn.Font = Enum.Font.GothamBold
		equipBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
		equipBtn.TextColor3 = Color3.new(1, 1, 1)
		equipBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(150, 100, 200)
		equipBtn.ZIndex = Z_BASE + 3
		equipBtn.Parent = slotFrame
		
		local eCorner = Instance.new("UICorner", equipBtn)
		eCorner.CornerRadius = UDim.new(0, 8)
		
		local eStroke = Instance.new("UIStroke", equipBtn)
		eStroke.Thickness = 2
		eStroke.Color = isEquipped and Color3.fromRGB(50, 100, 150) or Color3.fromRGB(80, 50, 120)
		
		equipBtn.MouseButton1Click:Connect(function()
			equipPetEvent:FireServer(isEquipped and "" or petName)
		end)
	end
	
	-- Parenter le slot au ScrollFrame
	slotFrame.Parent = parent
	
	return slotFrame
end

-- Créer le menu
local function creerMenu()
	if menuFrame then return end
	
	-- Frame principale
	menuFrame = Instance.new("Frame")
	menuFrame.Name = "PetMenuFrame"
	menuFrame.Size = (isMobile or isSmallScreen) and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0.7, 0, 0.75, 0)
	menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	menuFrame.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
	menuFrame.BorderSizePixel = 0
	menuFrame.ZIndex = Z_BASE
	menuFrame.Parent = screenGui
	
	local mainCorner = Instance.new("UICorner", menuFrame)
	mainCorner.CornerRadius = UDim.new(0, 16)
	
	local mainStroke = Instance.new("UIStroke", menuFrame)
	mainStroke.Color = Color3.fromRGB(150, 100, 200)
	mainStroke.Thickness = 4
	
	-- Titre
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -100, 0, (isMobile or isSmallScreen) and 50 or 70)
	titleLabel.Position = UDim2.new(0, 0, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🐾 ANIMALERIE - PETs"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = (isMobile or isSmallScreen) and 24 or 36
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.ZIndex = Z_BASE + 1
	titleLabel.Parent = menuFrame
	
	-- Bouton fermer
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, (isMobile or isSmallScreen) and 50 or 60, 0, (isMobile or isSmallScreen) and 50 or 60)
	closeBtn.Position = UDim2.new(1, -((isMobile or isSmallScreen) and 60 or 70), 0, 10)
	closeBtn.Text = "✕"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = (isMobile or isSmallScreen) and 28 or 36
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.ZIndex = Z_BASE + 2
	closeBtn.Parent = menuFrame
	
	local closeCorner = Instance.new("UICorner", closeBtn)
	closeCorner.CornerRadius = UDim.new(0, 12)
	
	-- ScrollFrame pour les PETs
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "PetScrollFrame"
	scrollFrame.Size = UDim2.new(1, -40, 1, -((isMobile or isSmallScreen) and 90 or 110))
	scrollFrame.Position = UDim2.new(0, 20, 0, (isMobile or isSmallScreen) and 70 or 90)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = (isMobile or isSmallScreen) and 8 or 10
	scrollFrame.ZIndex = Z_BASE + 1
	scrollFrame.Parent = menuFrame
	
	local scrollCorner = Instance.new("UICorner", scrollFrame)
	scrollCorner.CornerRadius = UDim.new(0, 12)
	
	local listLayout = Instance.new("UIListLayout", scrollFrame)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 8 or 12)
	
	local padding = Instance.new("UIPadding", scrollFrame)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	
	-- Remplir avec les PETs
	local playerPets = getPlayerPets()
	local ownedPetsSet = {}
	for _, petName in ipairs(playerPets) do
		ownedPetsSet[petName] = true
	end
	
	-- Ajuster la taille du canvas automatiquement
	local function updateCanvasSize()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
	end
	
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
	
	print("🐾 [PET MENU] Création des slots, nombre de PETs:", #PetManager.PetOrder)
	for i, petName in ipairs(PetManager.PetOrder) do
		local petData = PetManager.Pets[petName]
		if petData then
			local isOwned = ownedPetsSet[petName] == true
			print("🐾 [PET MENU] Création slot:", petName, "Possédé:", isOwned)
			local slot = createPetSlot(scrollFrame, petName, petData, isOwned)
			slot.LayoutOrder = i
		else
			warn("🐾 [PET MENU] PET non trouvé:", petName)
		end
	end
	print("🐾 [PET MENU] Tous les slots créés!")
	
	-- Forcer la mise à jour du canvas après création (attendre que le layout calcule)
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.05)
			updateCanvasSize()
			if listLayout.AbsoluteContentSize.Y > 0 then
				print("🐾 [PET MENU] Canvas size:", scrollFrame.CanvasSize.Y.Offset, "Content:", listLayout.AbsoluteContentSize.Y)
				break
			end
		end
		if listLayout.AbsoluteContentSize.Y == 0 then
			warn("⚠️ [PET MENU] Le layout n'a pas calculé la taille!")
		end
	end)
	
	-- Fermer le menu
	closeBtn.MouseButton1Click:Connect(function()
		fermerMenu()
	end)
	
	-- Animation d'ouverture
	menuFrame.Size = UDim2.new(0, 0, 0, 0)
	local openTween = TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = (isMobile or isSmallScreen) and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0.7, 0, 0.75, 0)
	})
	openTween:Play()
end

-- Fermer le menu
function fermerMenu()
	if not menuFrame then return end
	
	local closeTween = TweenService:Create(menuFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0)
	})
	closeTween:Play()
	closeTween.Completed:Connect(function()
		menuFrame:Destroy()
		menuFrame = nil
		isMenuOpen = false
		setGameInputsBlocked(false)
	end)
end

-- Ouvrir le menu
ouvrirMenuPetEvent.OnClientEvent:Connect(function()
	print("🐾 [PET MENU] Événement reçu pour ouvrir le menu")
	if isMenuOpen then 
		print("🐾 [PET MENU] Menu déjà ouvert")
		return 
	end
	isMenuOpen = true
	setGameInputsBlocked(true)
	print("🐾 [PET MENU] Création du menu...")
	creerMenu()
	print("🐾 [PET MENU] Menu créé!")
end)

-- Rafraîchir le menu quand un PET est acheté/équipé
achatPetEvent.OnClientEvent:Connect(function(success)
	if success and menuFrame then
		-- Recréer le menu
		fermerMenu()
		task.wait(0.3)
		isMenuOpen = true
		creerMenu()
	end
end)

equipPetEvent.OnClientEvent:Connect(function()
	if menuFrame then
		-- Recréer le menu
		fermerMenu()
		task.wait(0.3)
		isMenuOpen = true
		creerMenu()
	end
end)

print("🐾 [PET MENU CLIENT] Initialisé!")
