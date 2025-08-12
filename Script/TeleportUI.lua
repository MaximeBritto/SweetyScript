-- TeleportUI.lua - Interface de téléportation responsive
-- Ce script crée des boutons pour se téléporter à son île et au vendeur.
-- À PLACER DANS : StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Détection plateforme pour interface responsive
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- =============================================
-- FONCTION DE TÉLÉPORTATION
-- =============================================
local function teleportPlayer(destinationCFrame)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- On téléporte le joueur un peu au-dessus pour ne pas rester coincé
    humanoidRootPart.CFrame = destinationCFrame * CFrame.new(0, 4, 0)
end

-- =============================================
-- CRÉATION DE L'INTERFACE
-- =============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "TeleportFrame"

-- Taille et position responsives
if isMobile or isSmallScreen then
    mainFrame.Size = UDim2.new(0, 120, 0, 70)
    mainFrame.Position = UDim2.new(0, 10, 0.35, 0)  -- Plus haut sur mobile pour éviter les conflits
else
    mainFrame.Size = UDim2.new(0, 150, 0, 85)
    mainFrame.Position = UDim2.new(0, 20, 0.5, -42.5)
end

mainFrame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
mainFrame.BackgroundTransparency = (isMobile or isSmallScreen) and 0.1 or 0.2  -- Plus opaque sur mobile
mainFrame.BorderSizePixel = (isMobile or isSmallScreen) and 0 or 1
mainFrame.BorderColor3 = Color3.fromRGB(150, 150, 150)
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)
uiCorner.Parent = mainFrame

-- Stroke pour mobile
if isMobile or isSmallScreen then
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 1
    stroke.Parent = mainFrame
end

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"

local titleHeight = (isMobile or isSmallScreen) and 16 or 20
titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
titleLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
titleLabel.BackgroundTransparency = 0.3
titleLabel.BorderSizePixel = 0
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.Text = (isMobile or isSmallScreen) and "TELEPORT" or "Téléportation"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = (isMobile or isSmallScreen) and 10 or 12
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.TextScaled = (isMobile or isSmallScreen)
titleLabel.Parent = mainFrame

-- Coins arrondis du titre sur mobile
if isMobile or isSmallScreen then
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleLabel
end

local homeButton = Instance.new("TextButton")
homeButton.Name = "HomeButton"

local buttonHeight = (isMobile or isSmallScreen) and 24 or 30
homeButton.Size = UDim2.new(1, -10, 0, buttonHeight)
homeButton.Position = UDim2.new(0, 5, 0, titleHeight + 3)
homeButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
homeButton.BackgroundTransparency = 0.1
homeButton.Text = (isMobile or isSmallScreen) and "🏠 ILE" or "🏠 Mon île"
homeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
homeButton.TextSize = (isMobile or isSmallScreen) and 11 or 14
homeButton.Font = Enum.Font.SourceSansBold
homeButton.BorderSizePixel = (isMobile or isSmallScreen) and 0 or 1
homeButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
homeButton.TextScaled = (isMobile or isSmallScreen)
homeButton.Parent = mainFrame

-- Coins arrondis du bouton sur mobile
if isMobile or isSmallScreen then
    local homeCorner = Instance.new("UICorner")
    homeCorner.CornerRadius = UDim.new(0, 8)
    homeCorner.Parent = homeButton
end

local vendorButton = Instance.new("TextButton")
vendorButton.Name = "VendorButton"

vendorButton.Size = UDim2.new(1, -10, 0, buttonHeight)
vendorButton.Position = UDim2.new(0, 5, 0, titleHeight + buttonHeight + 6)
vendorButton.BackgroundColor3 = Color3.fromRGB(220, 160, 60)
vendorButton.BackgroundTransparency = 0.1
vendorButton.Text = (isMobile or isSmallScreen) and "🛒 VENDEUR" or "🛒 Vendeur"
vendorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
vendorButton.TextSize = (isMobile or isSmallScreen) and 11 or 14
vendorButton.Font = Enum.Font.SourceSansBold
vendorButton.BorderSizePixel = (isMobile or isSmallScreen) and 0 or 1
vendorButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
vendorButton.TextScaled = (isMobile or isSmallScreen)
vendorButton.Parent = mainFrame

-- Coins arrondis du bouton sur mobile
if isMobile or isSmallScreen then
    local vendorCorner = Instance.new("UICorner")
    vendorCorner.CornerRadius = UDim.new(0, 8)
    vendorCorner.Parent = vendorButton
end

local function applyHoverEffect(button)
    local originalColor = button.BackgroundColor3
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor:Lerp(Color3.new(1,1,1), 0.2)}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
    end)
end

applyHoverEffect(homeButton)
applyHoverEffect(vendorButton)


-- =============================================
-- LOGIQUE DES BOUTONS
-- =============================================
homeButton.MouseButton1Click:Connect(function()
    -- Le RespawnLocation est défini par IslandManager.lua
    local respawnLocation = player.RespawnLocation
    if respawnLocation then
        teleportPlayer(respawnLocation.CFrame)
    else
        warn("TeleportUI: RespawnLocation non trouvée pour le joueur. L'île n'est peut-être pas encore assignée.")
    end
end)

-- Helpers pour la recherche d'une cible de téléportation
local function getValidPart(obj)
    if obj:IsA("BasePart") then
        return obj
    end
    if obj:IsA("Model") then
        local torso = obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
        if torso then return torso end
        local head = obj:FindFirstChild("Head")
        if head then return head end
        local humanoidRootPart = obj:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then return humanoidRootPart end
        if obj.PrimaryPart then return obj.PrimaryPart end
        for _, child in pairs(obj:GetDescendants()) do
            if child:IsA("BasePart") then return child end
        end
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

vendorButton.MouseButton1Click:Connect(function()
    -- 1) Priorité au point manuel 'TeleportSeller'
    local tp = findTeleportTargetByName("TeleportSeller")
    if tp then
        teleportPlayer(tp.CFrame)
        return
    end

    -- 2) Fallback: recherche du vendeur comme avant
    local function findVendor()
        -- Chercher par nom exact
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "Vendeur" or obj.Name == "VendeurPNJ" then
                local validPart = getValidPart(obj)
                if validPart then return validPart end
            end
        end
        -- Chercher par ClickDetector
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ClickDetector") then
                local parent = obj.Parent
                if parent and parent:IsA("BasePart") then
                    local grandParent = parent.Parent
                    if grandParent and (grandParent.Name:lower():find("vendeur") or 
                                       grandParent.Name:lower():find("vendor") or 
                                       grandParent.Name:lower():find("shop") or
                                       grandParent.Name:lower():find("pnj")) then
                        return getValidPart(grandParent) or parent
                    end
                end
            end
        end
        -- Recherche élargie : modèles avec Humanoid + ClickDetector
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChildOfClass("ClickDetector") then
                local validPart = getValidPart(obj)
                if validPart then return validPart end
            end
        end
        return nil
    end
    
    local vendor = findVendor()
    if vendor then
        -- Reculer de 5 studs devant le vendeur pour une approche confortable
        local vendorCFrame = vendor.CFrame
        local backwardOffset = vendorCFrame.LookVector * -5 -- 5 studs en arrière
        local teleportPosition = vendorCFrame + backwardOffset
        teleportPlayer(teleportPosition)
    else
        warn("⚠️ Vendeur non trouvé et 'TeleportSeller' absent du Workspace.")
    end
end)

 