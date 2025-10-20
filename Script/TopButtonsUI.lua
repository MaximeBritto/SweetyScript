-- TopButtonsUI.lua
-- 3 gros boutons en haut de l'écran : VENTE, SHOP, ISLAND
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =========================================================
-- CONFIG GLOBALE : RÉGLAGES LIVE
-- =========================================================
-- FACTEUR D’ÉCHELLE GLOBAL (largeur + hauteur)
local SCALE = 1
-- FACTEUR D’ÉPAISSEUR (uniquement la hauteur)
local HEIGHT_SCALE = 1.25
-- Override optionnel de la distance depuis le haut (pixels). Laisse nil pour utiliser la valeur BASE.
local TOP_OFFSET_OVERRIDE = nil

-- Tailles de base (avant SCALE, HEIGHT_SCALE)
local BASE = {
	-- TopOffset : valeur négative = au-dessus du bord supérieur (peut être caché partiellement)
	-- 0 = tout en haut visible, positif = descend
	Mobile  = { ButtonW = 120, ButtonH = 110, FrameH = 130, TopOffset = -20,   Padding = 8  },
	Desktop = { ButtonW = 300, ButtonH = 220, FrameH = 260, TopOffset = -30,  Padding = 15 },
	FrameWidthDesktop = 1000, -- largeur visuelle de la rangée (avant SCALE)
}

-- =========================================================
-- IMAGES (remplace par tes IDs)
-- =========================================================
local IMAGE_VENTE  = "rbxassetid://96306073103711"
local IMAGE_ISLAND = "rbxassetid://103492943983688"
local IMAGE_SHOP   = "rbxassetid://103288135524131"

-- =========================================================
-- DÉTECTION PLATEFORME / RESPONSIVE
-- =========================================================
local function getScreenInfo()
	local cam = Workspace.CurrentCamera
	local viewportSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600
	return isMobile or isSmallScreen, viewportSize
end

local isCompact, _viewportSize = getScreenInfo()

-- =========================================================
-- TÉLÉPORTATION
-- =========================================================
local function teleportPlayer(destinationCFrame)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = destinationCFrame * CFrame.new(0, 4, 0)
end

-- Helpers de recherche
local function getValidPart(obj)
	if obj:IsA("BasePart") then
		return obj
	end
	if obj:IsA("Model") then
		return obj:FindFirstChild("HumanoidRootPart")
			or obj:FindFirstChild("Torso")
			or obj:FindFirstChild("UpperTorso")
			or obj:FindFirstChild("Head")
			or obj.PrimaryPart
			or (function()
				for _, d in ipairs(obj:GetDescendants()) do
					if d:IsA("BasePart") then return d end
				end
				return nil
			end)()
	end
	return nil
end

local function findTeleportTargetByName(name)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local nearest, bestDist
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == name then
			local part = getValidPart(obj)
			if part then
				if hrp then
					local d = (hrp.Position - part.Position).Magnitude
					if not bestDist or d < bestDist then
						nearest, bestDist = part, d
					end
				else
					return part
				end
			end
		end
	end
	return nearest
end

local function findVendor()
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj.Name == "Vendeur" or obj.Name == "VendeurPNJ" then
			local p = getValidPart(obj)
			if p then return p end
		end
	end
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj:IsA("ClickDetector") then
			local parent = obj.Parent
			if parent and parent:IsA("BasePart") then
				local gp = parent.Parent
				if gp and (
					gp.Name:lower():find("vendeur") or
						gp.Name:lower():find("vendor") or
						gp.Name:lower():find("shop")   or
						gp.Name:lower():find("pnj")
					) then
					return getValidPart(gp) or parent
				end
			end
		end
	end
	for _, obj in pairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChildOfClass("ClickDetector") then
			local p = getValidPart(obj)
			if p then return p end
		end
	end
	return nil
end

-- =========================================================
-- INTERFACE
-- =========================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TopButtonsUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

local buttonsFrame = Instance.new("Frame")
buttonsFrame.Name = "ButtonsFrame"
buttonsFrame.BackgroundTransparency = 1
buttonsFrame.AnchorPoint = Vector2.new(0.5, 0)
buttonsFrame.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Parent = buttonsFrame

-- Références pour redimensionner
local ButtonRefs = {}  -- { {instance = ImageButton}, ... }

-- Applique l'échelle au layout et aux boutons
local function applyScale()
	isCompact, _viewportSize = getScreenInfo()

	local base = isCompact and BASE.Mobile or BASE.Desktop
	local btnW = math.floor(base.ButtonW * SCALE)                    -- largeur commune
	local btnH = math.floor(base.ButtonH * SCALE * HEIGHT_SCALE)     -- hauteur épaissie
	local pad  = math.floor(base.Padding * SCALE)
	local frameH = math.floor(base.FrameH * SCALE * HEIGHT_SCALE)
	-- Garder les valeurs négatives pour TopOffset
	local topOffset = ((TOP_OFFSET_OVERRIDE ~= nil) and TOP_OFFSET_OVERRIDE or base.TopOffset) * SCALE

	listLayout.Padding = UDim.new(0, pad)

	if isCompact then
		buttonsFrame.Size = UDim2.new(0.95, 0, 0, frameH)
	else
		local fW = math.floor(BASE.FrameWidthDesktop * SCALE)
		buttonsFrame.Size = UDim2.new(0, fW, 0, frameH)
	end
	buttonsFrame.Position = UDim2.new(0.5, 0, 0, topOffset)

	for _, info in ipairs(ButtonRefs) do
		info.instance.Size = UDim2.new(0, btnW, 0, btnH)
	end
end

-- Création d’un bouton (même taille pour tous)
local function createTopButton(name, imageId, onClick, fallbackText, fallbackColor)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	-- IMPORTANT : respecte les proportions de l'image (pas de déformation)
	button.ScaleType = Enum.ScaleType.Fit
	button.Parent = buttonsFrame

	if imageId and imageId ~= "" then
		button.Image = imageId
	else
		-- Fallback (si pas d’image)
		button.BackgroundTransparency = 0
		button.BackgroundColor3 = fallbackColor or Color3.fromRGB(60, 120, 255)
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = fallbackText or name
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.Parent = button
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = button
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), { ImageTransparency = 0.15 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), { ImageTransparency = 0 }):Play()
	end)
	button.MouseButton1Click:Connect(onClick)

	table.insert(ButtonRefs, { instance = button })
	return button
end

-- =========================================================
-- BOUTONS (même taille + ordre VENTE - SHOP - ISLAND)
-- =========================================================
-- VENTE
createTopButton(
	"VenteButton",
	IMAGE_VENTE,
	function()
		print("🛍️ Ouverture du menu de vente...")
		if _G.openSellMenu then
			_G.openSellMenu()
		else
			warn("⚠️ Menu de vente non encore chargé")
		end
	end,
	"VENTE",
	Color3.fromRGB(40, 167, 69)
)

-- SHOP (au milieu)
createTopButton(
	"ShopButton",
	IMAGE_SHOP,
	function()
		print("🛒 Téléportation au shop...")
		local tp = findTeleportTargetByName("TeleportSeller")
		if tp then
			teleportPlayer(tp.CFrame)
			return
		end

		local vendor = findVendor()
		if vendor then
			local cf = vendor.CFrame
			local teleportPosition = cf + (cf.LookVector * -5)
			teleportPlayer(teleportPosition)
		else
			warn("⚠️ Vendeur non trouvé et 'TeleportSeller' absent du Workspace.")
		end
	end,
	"SHOP",
	Color3.fromRGB(220, 160, 60)
)

-- ISLAND (à droite)
createTopButton(
	"IslandButton",
	IMAGE_ISLAND,
	function()
		print("🏠 Téléportation à l'île...")
		local respawnLocation = player.RespawnLocation
		if respawnLocation then
			teleportPlayer(respawnLocation.CFrame)
		else
			warn("⚠️ RespawnLocation non trouvée.")
		end
	end,
	"ISLAND",
	Color3.fromRGB(100, 150, 255)
)

-- Première application de l’échelle
applyScale()

-- =========================================================
-- API PUBLIQUE : réglages live 🔧
-- =========================================================
_G.SetTopButtonsScale = function(newScale)
	if typeof(newScale) == "number" and newScale > 0 then
		SCALE = newScale
		applyScale()
	else
		warn("SetTopButtonsScale: valeur invalide ->", newScale)
	end
end

_G.SetTopButtonsHeightScale = function(newHeightScale)
	if typeof(newHeightScale) == "number" and newHeightScale > 0 then
		HEIGHT_SCALE = newHeightScale
		applyScale()
	else
		warn("SetTopButtonsHeightScale: valeur invalide ->", newHeightScale)
	end
end

-- Réglage live de la distance depuis le haut (pixels). nil pour revenir au défaut.
_G.SetTopButtonsTopOffset = function(pixels)
	if pixels == nil or typeof(pixels) == "number" then
		TOP_OFFSET_OVERRIDE = pixels
		applyScale()
	else
		warn("SetTopButtonsTopOffset: valeur invalide ->", pixels)
	end
end

-- Redimensionner automatiquement si la fenêtre change
local cam = Workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		applyScale()
	end)
end

print("✅ TopButtonsUI chargé ! Ordre: VENTE - SHOP - ISLAND.")
print("   Réglages live: _G.SetTopButtonsScale(1.2), _G.SetTopButtonsHeightScale(1.4), _G.SetTopButtonsTopOffset(20)")
