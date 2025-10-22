-- Script client pour afficher une notification animée lors du restock de la boutique
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- IDs des assets
local RESTOCK_IMAGE_ID = "rbxassetid://71206637570963"
local RESTOCK_SOUND_ID = "rbxassetid://95882670447792"

-- Créer le ScreenGui pour la notification
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RestockNotification"
screenGui.DisplayOrder = 9999
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Détection de la plateforme pour taille responsive
local UserInputService = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize

-- Détection simplifiée basée UNIQUEMENT sur la largeur d'écran
local screenWidth = viewportSize.X

print("🛒 [RESTOCK] Largeur écran:", screenWidth, "px")

-- Tailles adaptatives basées sur la largeur
local buttonSize
local deviceType
if screenWidth < 600 then
	buttonSize = 70  -- Très petit mobile
	deviceType = "Petit Mobile"
elseif screenWidth < 900 then
	buttonSize = 90  -- Mobile normal
	deviceType = "Mobile"
elseif screenWidth < 1200 then
	buttonSize = 130  -- Tablette
	deviceType = "Tablette"
else
	buttonSize = 2500  -- Desktop
	deviceType = "Desktop"
end

print("🛒 [RESTOCK] Appareil:", deviceType, "| Taille:", buttonSize, "px")

-- Position d'arrêt adaptative
local stopPosition = (screenWidth < 900) and 0.4 or 0.3
local stopPosition = (isMobile or isSmallScreen) and 0.4 or 0.3

-- Créer l'image de notification
local notificationImage = Instance.new("ImageLabel")
notificationImage.Name = "RestockImage"
notificationImage.Size = UDim2.new(0, buttonSize, 0, buttonSize)
notificationImage.AnchorPoint = Vector2.new(0.5, 1) -- Ancre en bas de l'image
notificationImage.Position = UDim2.new(0.5, 0, 0, -50) -- Commence hors écran (le bas de l'image est à -50px)
notificationImage.BackgroundTransparency = 1
notificationImage.Image = RESTOCK_IMAGE_ID
notificationImage.ScaleType = Enum.ScaleType.Fit
notificationImage.ZIndex = 10000
notificationImage.Parent = screenGui

-- Créer le son de notification
local restockSound = Instance.new("Sound")
restockSound.Name = "RestockSound"
restockSound.SoundId = RESTOCK_SOUND_ID
restockSound.Volume = 0.5
restockSound.Parent = SoundService

-- Variable pour éviter les animations multiples
local isAnimating = false
local lastRestockTime = nil

-- Fonction pour jouer l'animation de restock
local function playRestockAnimation()
	if isAnimating then return end
	isAnimating = true
	
	print("🛒 [RESTOCK NOTIF] Animation de restock démarrée !")
	
	-- Position de départ (hors écran, le bas de l'image est au-dessus de l'écran)
	notificationImage.Position = UDim2.new(0.5, 0, 0, -50)
	notificationImage.Visible = true
	
	-- JOUER LE SON en même temps que l'animation commence
	restockSound:Play()
	
	-- Petit délai pour synchroniser (0.3 secondes)
	task.wait(0.3)
	
	-- Animation 1 : Descendre lentement vers le haut de l'écran
	-- Avec AnchorPoint (0.5, 1), on positionne le bas de l'image
	-- Position adaptative selon la plateforme
	local tweenDown = TweenService:Create(
		notificationImage,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, stopPosition, 0)} -- Position responsive
	)
	
	tweenDown:Play()
	tweenDown.Completed:Wait()
	
	-- Pause au centre (2.5 secondes)
	task.wait(2.5)
	
	-- Animation 2 : Remonter lentement hors de l'écran
	local tweenUp = TweenService:Create(
		notificationImage,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, 0, 0, -50)} -- Retour hors écran
	)
	
	tweenUp:Play()
	tweenUp.Completed:Wait()
	
	notificationImage.Visible = false
	isAnimating = false
	
	print("🛒 [RESTOCK NOTIF] Animation terminée !")
end

-- Créer un bouton de test en bas à droite (APRÈS la définition de la fonction)
-- Taille et position responsive
local testButtonWidth = (isMobile or isSmallScreen) and 120 or 150
local testButtonHeight = (isMobile or isSmallScreen) and 40 or 50
local testButtonOffset = (isMobile or isSmallScreen) and 10 or 10

local testButton = Instance.new("TextButton")
testButton.Name = "TestRestockButton"
testButton.Size = UDim2.new(0, testButtonWidth, 0, testButtonHeight)
testButton.Position = UDim2.new(1, -(testButtonWidth + testButtonOffset), 1, -(testButtonHeight + testButtonOffset))
testButton.AnchorPoint = Vector2.new(0, 0)
testButton.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
testButton.Text = (isMobile or isSmallScreen) and "🛒 Test" or "🛒 Test Restock"
testButton.TextColor3 = Color3.new(1, 1, 1)
testButton.Font = Enum.Font.GothamBold
testButton.TextSize = (isMobile or isSmallScreen) and 14 or 16
testButton.TextScaled = (isMobile or isSmallScreen)
testButton.ZIndex = 10000
testButton.Parent = screenGui

local testCorner = Instance.new("UICorner")
testCorner.CornerRadius = UDim.new(0, 8)
testCorner.Parent = testButton

local testStroke = Instance.new("UIStroke")
testStroke.Color = Color3.fromRGB(60, 120, 60)
testStroke.Thickness = 2
testStroke.Parent = testButton

-- Effet hover sur le bouton
testButton.MouseEnter:Connect(function()
	testButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
end)

testButton.MouseLeave:Connect(function()
	testButton.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
end)

-- Clic sur le bouton de test
testButton.MouseButton1Click:Connect(function()
	print("🛒 [TEST] Lancement manuel de l'animation de restock")
	task.spawn(playRestockAnimation)
end)

-- Surveiller le timer de restock
task.spawn(function()
	local shopStockFolder = ReplicatedStorage:WaitForChild("ShopStock", 30)
	if not shopStockFolder then
		warn("🛒 [RESTOCK NOTIF] ShopStock folder introuvable")
		return
	end
	
	local restockTimeValue = shopStockFolder:WaitForChild("RestockTime", 30)
	if not restockTimeValue then
		warn("🛒 [RESTOCK NOTIF] RestockTime value introuvable")
		return
	end
	
	print("🛒 [RESTOCK NOTIF] Surveillance du restock activée")
	
	-- Initialiser avec la valeur actuelle
	lastRestockTime = restockTimeValue.Value
	
	-- Surveiller les changements
	restockTimeValue.Changed:Connect(function(newValue)
		-- Détecter quand le timer passe de 1 à 300 (ou proche) = restock effectué
		if lastRestockTime and lastRestockTime <= 5 and newValue >= 290 then
			print("🛒 [RESTOCK NOTIF] Restock détecté ! (", lastRestockTime, "→", newValue, ")")
			playRestockAnimation()
		end
		
		lastRestockTime = newValue
	end)
end)

print("✅ [RESTOCK NOTIF] Script de notification de restock chargé")
