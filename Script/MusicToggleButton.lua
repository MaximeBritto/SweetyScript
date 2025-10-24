-- MusicToggleButton.lua
-- Petit bouton discret pour activer/désactiver la musique
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =========================================================
-- CONFIG
-- =========================================================
local BUTTON_SIZE_DESKTOP = 50  -- Taille du bouton sur desktop (pixels)
local BUTTON_SIZE_MOBILE = 30   -- Taille du bouton sur mobile (pixels) - encore plus petit
local ICON_MUSIC_ON = "🔊"  -- Icône quand la musique est activée
local ICON_MUSIC_OFF = "🔇"  -- Icône quand la musique est désactivée

-- =========================================================
-- DÉTECTION MOBILE
-- =========================================================
local function isMobile()
	-- Vérifier le tactile ET la taille d'écran
	local hasTouchNoKeyboard = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	
	-- Vérifier aussi la taille d'écran (petit écran = mobile)
	local camera = workspace.CurrentCamera
	local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local isSmallScreen = viewportSize.X < 900 or viewportSize.Y < 500
	
	return hasTouchNoKeyboard or isSmallScreen
end

local BUTTON_SIZE = isMobile() and BUTTON_SIZE_MOBILE or BUTTON_SIZE_DESKTOP
local IS_MOBILE = isMobile()

-- =========================================================
-- ÉTAT DE LA MUSIQUE
-- =========================================================
local musicEnabled = true  -- Par défaut, la musique est activée

-- =========================================================
-- INTERFACE
-- =========================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MusicToggleUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 150  -- Au-dessus des autres UI
screenGui.Parent = playerGui

-- Bouton
local button = Instance.new("TextButton")
button.Name = "MusicToggleButton"
button.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
-- Position différente selon la plateforme
if IS_MOBILE then
	-- Mobile : en haut à droite avec petite marge
	button.Position = UDim2.new(1, -BUTTON_SIZE - 5, 0, 5)
	button.AnchorPoint = Vector2.new(1, 0)
else
	-- Desktop : en bas à droite
	button.Position = UDim2.new(1, -BUTTON_SIZE - 10, 1, -BUTTON_SIZE - 10)
	button.AnchorPoint = Vector2.new(1, 1)
end
button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
button.BackgroundTransparency = 0.3
button.BorderSizePixel = 0
button.Text = ICON_MUSIC_ON
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextScaled = true
button.AutoButtonColor = false
button.Parent = screenGui

-- Coins arrondis
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.2, 0)
corner.Parent = button

-- Padding pour le texte
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0.1, 0)
padding.PaddingBottom = UDim.new(0.1, 0)
padding.PaddingLeft = UDim.new(0.1, 0)
padding.PaddingRight = UDim.new(0.1, 0)
padding.Parent = button

-- =========================================================
-- FONCTION TOGGLE
-- =========================================================
local function toggleMusic()
	musicEnabled = not musicEnabled
	
	-- Appeler la fonction globale pour toggle la musique
	if _G.ToggleBackgroundMusic then
		_G.ToggleBackgroundMusic()
	else
		warn("⚠️ [MUSIC TOGGLE] _G.ToggleBackgroundMusic non trouvé")
	end
	
	-- Mettre à jour l'icône
	button.Text = musicEnabled and ICON_MUSIC_ON or ICON_MUSIC_OFF
	
	-- Animation de feedback
	local originalSize = button.Size
	TweenService:Create(button, TweenInfo.new(0.1), { Size = UDim2.new(0, BUTTON_SIZE * 1.2, 0, BUTTON_SIZE * 1.2) }):Play()
	task.wait(0.1)
	TweenService:Create(button, TweenInfo.new(0.1), { Size = originalSize }):Play()
	
	print(musicEnabled and "🔊 [MUSIC] Musique activée" or "🔇 [MUSIC] Musique désactivée")
end

-- =========================================================
-- ÉVÉNEMENTS
-- =========================================================
button.MouseEnter:Connect(function()
	TweenService:Create(button, TweenInfo.new(0.15), { BackgroundTransparency = 0.1 }):Play()
end)

button.MouseLeave:Connect(function()
	TweenService:Create(button, TweenInfo.new(0.15), { BackgroundTransparency = 0.3 }):Play()
end)

button.MouseButton1Click:Connect(toggleMusic)

print("✅ [MUSIC TOGGLE] Bouton de musique chargé en bas à droite !")
