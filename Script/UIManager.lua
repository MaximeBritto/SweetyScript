-- Ce script (local) affiche l'argent à côté de la hotbar
-- VERSION V0.5 : Interface argent simplifiée positionnée près de la hotbar
-- À placer dans ScreenGui

-- Services nécessaires
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerData = player:WaitForChild("PlayerData")

-- === DONNÉES ===
local argent = playerData:WaitForChild("Argent")

-- On trouve les labels dans le ScreenGui
local screenGui = script.Parent

-- Détection de la plateforme pour positionnement responsive
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Créer le label d'argent positionné près de la hotbar
local argentLabel = screenGui:FindFirstChild("ArgentLabel")
if not argentLabel then
    argentLabel = Instance.new("TextLabel")
    argentLabel.Name = "ArgentLabel"
    
    -- Taille et position responsive à droite de l'écran, centré verticalement
    if isMobile or isSmallScreen then
        -- Mobile : à droite de l'écran, centré au milieu
        argentLabel.Size = UDim2.new(0, 120, 0, 35)
        argentLabel.Position = UDim2.new(1, -10, 0.5, 0) -- Ancré à droite avec 10px de marge
        argentLabel.AnchorPoint = Vector2.new(1, 0.5) -- Ancre en haut-droite et centre vertical
    else
        -- Desktop : à droite de l'écran, centré au milieu
        argentLabel.Size = UDim2.new(0, 150, 0, 40)
        argentLabel.Position = UDim2.new(1, -10, 0.5, 0) -- Ancré à droite avec 10px de marge
        argentLabel.AnchorPoint = Vector2.new(1, 0.5) -- Ancre en haut-droite et centre vertical
    end
    
    argentLabel.BackgroundTransparency = 0.2
    argentLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    argentLabel.BorderSizePixel = 0
    argentLabel.Text = "$ 0"
    argentLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Or
    argentLabel.TextSize = (isMobile or isSmallScreen) and 18 or 22
    argentLabel.Font = Enum.Font.SourceSansBold
    argentLabel.TextXAlignment = Enum.TextXAlignment.Center
    argentLabel.Parent = screenGui
    
    -- Coins arrondis
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 10)
    corner.Parent = argentLabel
    
    -- Bordure dorée
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 2
    stroke.Parent = argentLabel
end

-- Fonction pour mettre à jour l'affichage de l'argent
local function updateArgentUI()
    argentLabel.Text = "$ " .. argent.Value
end

-- Nettoyer les anciens labels s'ils existent
if screenGui:FindFirstChild("HudFrame") then screenGui.HudFrame:Destroy() end
if screenGui:FindFirstChild("BonbonsLabel") then screenGui.BonbonsLabel:Destroy() end
if screenGui:FindFirstChild("ProductionLabel") then screenGui.ProductionLabel:Destroy() end
if screenGui:FindFirstChild("StockLabel") then screenGui.StockLabel:Destroy() end
if screenGui:FindFirstChild("IngredientsLabel") then screenGui.IngredientsLabel:Destroy() end

-- On met à jour l'affichage de l'argent une première fois au démarrage
updateArgentUI()

-- Son de gain d'argent (configurable)
local function playMoneyGainSound()
    local baseSound = SoundService:FindFirstChild("MoneyGain")
    local sound
    if baseSound and baseSound:IsA("Sound") then
        sound = baseSound:Clone()
    else
        local cfg = ReplicatedStorage:FindFirstChild("MoneyGainSoundId")
        sound = Instance.new("Sound")
        if cfg and cfg:IsA("StringValue") and cfg.Value ~= "" then
            sound.SoundId = cfg.Value
        else
            sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
        end
        sound.Volume = 0.6
    end
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- On met à jour l'affichage chaque fois que l'argent change
local lastArgentValue = argent.Value
argent.Changed:Connect(function(newValue)
    updateArgentUI()
    if typeof(newValue) == "number" and typeof(lastArgentValue) == "number" then
        if newValue > lastArgentValue then
            task.spawn(playMoneyGainSound)
        end
    end
    lastArgentValue = newValue
end)

print("✅ UIManager v0.5 (Argent simplifié près hotbar) chargé !") 