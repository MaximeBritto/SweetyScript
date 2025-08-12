--[[
    🏭 PRODUCTION PLATFORM SERVER
    Gère les plateformes de production de bonbons automatique
    
    Fonctionnalités:
    - Placement de bonbons sur plateformes
    - Génération automatique d'argent
    - Ramassage d'argent par proximité
    - Effets visuels de lévitation et rotation
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Configuration
local PRODUCTION_CONFIG = {
    GENERATION_INTERVAL = 5, -- Génère de l'argent toutes les 5 secondes
    BASE_GENERATION = 10, -- Argent de base généré
    PICKUP_DISTANCE = 8, -- Distance pour ramasser l'argent
    MAX_PLATFORMS = 6, -- Maximum de plateformes par joueur
    LEVITATION_HEIGHT = 3, -- Hauteur de lévitation du bonbon
    ROTATION_SPEED = 45, -- Degrés par seconde de rotation
}

-- Variables
local activePlatforms = {} -- [player] = {[platformId] = platformData}
local moneyDrops = {} -- Argent au sol en attente de ramassage

-- Events
local placeCandyEvent = ReplicatedStorage:WaitForChild("PlaceCandyOnPlatformEvent", 5)
if not placeCandyEvent then
    placeCandyEvent = Instance.new("RemoteEvent")
    placeCandyEvent.Name = "PlaceCandyOnPlatformEvent"
    placeCandyEvent.Parent = ReplicatedStorage
end

local pickupMoneyEvent = ReplicatedStorage:WaitForChild("PickupPlatformMoneyEvent", 5)
if not pickupMoneyEvent then
    pickupMoneyEvent = Instance.new("RemoteEvent")
    pickupMoneyEvent.Name = "PickupPlatformMoneyEvent"
    pickupMoneyEvent.Parent = ReplicatedStorage
end

-- Modules (commenté car pas utilisé actuellement)
-- local CandyTools = require(ReplicatedStorage:WaitForChild("CandyTools"))

-- 🏗️ Création d'une plateforme de production
local function createProductionPlatform(player, position, platformId)
    local character = player.Character
    if not character then return nil end
    
    -- Créer la plateforme
    local platform = Instance.new("Part")
    platform.Name = "ProductionPlatform_" .. platformId
    platform.Material = Enum.Material.Neon
    platform.BrickColor = BrickColor.new("Bright blue")
    platform.Shape = Enum.PartType.Cylinder
    platform.Size = Vector3.new(0.5, 6, 6)
    platform.Position = position
    platform.Rotation = Vector3.new(0, 0, 90) -- Couché comme une dalle
    platform.Anchored = true
    platform.CanCollide = true
    platform.Parent = workspace
    
    -- Ajouter un effet lumineux
    local pointLight = Instance.new("PointLight")
    pointLight.Color = Color3.fromRGB(0, 162, 255)
    pointLight.Brightness = 2
    pointLight.Range = 15
    pointLight.Parent = platform
    
    -- Zone de détection pour placement
    local detector = Instance.new("Part")
    detector.Name = "CandyDetector"
    detector.Material = Enum.Material.ForceField
    detector.BrickColor = BrickColor.new("Bright green")
    detector.Shape = Enum.PartType.Cylinder
    detector.Size = Vector3.new(0.1, 7, 7)
    detector.Position = position + Vector3.new(0, 1, 0)
    detector.Rotation = Vector3.new(0, 0, 90)
    detector.Anchored = true
    detector.CanCollide = false
    detector.Transparency = 0.8
    detector.Parent = platform
    
    print("🏭 [PLATFORM] Plateforme créée pour", player.Name, "ID:", platformId)
    return platform
end

-- 🍬 Placer un bonbon sur une plateforme
local function placeCandyOnPlatform(player, platformId, candyName)
    print("🍬 [PLATFORM] Tentative placement bonbon:", candyName, "Platform:", platformId)
    
    -- Vérifier si le joueur a le bonbon en main
    local character = player.Character
    if not character then 
        print("❌ [PLATFORM] Pas de personnage")
        return false 
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then 
        print("❌ [PLATFORM] Pas d'humanoïde")
        return false 
    end
    
    local equippedTool = humanoid:FindFirstChildOfClass("Tool")
    if not equippedTool or equippedTool.Name ~= candyName then
        print("❌ [PLATFORM] Bonbon non équipé ou nom incorrect:", equippedTool and equippedTool.Name or "nil")
        return false
    end
    
    -- Vérifier que c'est bien un bonbon
    if not equippedTool:GetAttribute("IsCandy") then
        print("❌ [PLATFORM] L'objet n'est pas un bonbon")
        return false
    end
    
    -- Initialiser les plateformes du joueur si nécessaire
    if not activePlatforms[player] then
        activePlatforms[player] = {}
    end
    
    -- Vérifier si la plateforme existe et est libre
    local platformData = activePlatforms[player][platformId]
    if platformData and platformData.candy then
        print("❌ [PLATFORM] Plateforme déjà occupée")
        return false
    end
    
    -- Créer la plateforme si elle n'existe pas
    local platform
    if not platformData then
        local spawnPosition = character.HumanoidRootPart.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
        platform = createProductionPlatform(player, spawnPosition, platformId)
        if not platform then
            print("❌ [PLATFORM] Échec création plateforme")
            return false
        end
        
        platformData = {
            platform = platform,
            candy = nil,
            candyModel = nil,
            lastGeneration = tick(),
            totalGenerated = 0
        }
        activePlatforms[player][platformId] = platformData
    else
        platform = platformData.platform
    end
    
    -- Retirer le bonbon de l'inventaire du joueur
    equippedTool.Parent = nil
    
    -- Créer le modèle de bonbon en lévitation
    local candyModel = Instance.new("Part")
    candyModel.Name = "FloatingCandy"
    candyModel.Material = Enum.Material.Neon
    candyModel.Shape = Enum.PartType.Ball
    candyModel.Size = Vector3.new(2, 2, 2)
    candyModel.Position = platform.Position + Vector3.new(0, PRODUCTION_CONFIG.LEVITATION_HEIGHT, 0)
    candyModel.Anchored = true
    candyModel.CanCollide = false
    candyModel.Parent = platform
    
    -- Couleur selon le type de bonbon
    local candyColors = {
        ["Bonbon Rouge"] = Color3.fromRGB(255, 0, 0),
        ["Bonbon Bleu"] = Color3.fromRGB(0, 0, 255),
        ["Bonbon Vert"] = Color3.fromRGB(0, 255, 0),
        ["Bonbon Jaune"] = Color3.fromRGB(255, 255, 0),
        ["Bonbon Violet"] = Color3.fromRGB(128, 0, 128),
    }
    candyModel.Color = candyColors[candyName] or Color3.fromRGB(255, 192, 203) -- Rose par défaut
    
    -- Ajouter un effet lumineux au bonbon
    local candyLight = Instance.new("PointLight")
    candyLight.Color = candyModel.Color
    candyLight.Brightness = 1.5
    candyLight.Range = 10
    candyLight.Parent = candyModel
    
    -- Ajouter des particules
    local attachment = Instance.new("Attachment")
    attachment.Parent = candyModel
    
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(candyModel.Color)
    particles.Size = NumberSequence.new(0.2, 0.5)
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Rate = 20
    particles.SpreadAngle = Vector2.new(45, 45)
    particles.Speed = NumberRange.new(2, 5)
    particles.Parent = attachment
    
    -- Sauvegarder les données
    platformData.candy = candyName
    platformData.candyModel = candyModel
    platformData.stackSize = equippedTool:GetAttribute("StackSize") or 1
    
    print("✅ [PLATFORM] Bonbon placé avec succès:", candyName, "Stack:", platformData.stackSize)
    return true
end

-- 💰 Générer de l'argent automatiquement
local function generateMoney(player, platformId, platformData)
    if not platformData.candy or not platformData.candyModel then return end
    
    local currentTime = tick()
    if currentTime - platformData.lastGeneration < PRODUCTION_CONFIG.GENERATION_INTERVAL then
        return
    end
    
    -- Calculer la génération basée sur la taille du stack
    local baseAmount = PRODUCTION_CONFIG.BASE_GENERATION
    local stackMultiplier = platformData.stackSize or 1
    local moneyAmount = baseAmount * stackMultiplier
    
    -- Créer l'argent au sol
    local moneyPart = Instance.new("Part")
    moneyPart.Name = "MoneyDrop"
    moneyPart.Material = Enum.Material.Neon
    moneyPart.BrickColor = BrickColor.new("Bright yellow")
    moneyPart.Shape = Enum.PartType.Ball
    moneyPart.Size = Vector3.new(1, 1, 1)
    moneyPart.Position = platformData.platform.Position + Vector3.new(
        math.random(-3, 3), 
        2, 
        math.random(-3, 3)
    )
    moneyPart.Anchored = true
    moneyPart.CanCollide = false
    moneyPart.Parent = workspace
    
    -- Ajouter un effet lumineux
    local moneyLight = Instance.new("PointLight")
    moneyLight.Color = Color3.fromRGB(255, 255, 0)
    moneyLight.Brightness = 2
    moneyLight.Range = 8
    moneyLight.Parent = moneyPart
    
    -- Ajouter un GUI avec le montant
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 100, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2, 0)
    billboardGui.Parent = moneyPart
    
    local moneyLabel = Instance.new("TextLabel")
    moneyLabel.Size = UDim2.new(1, 0, 1, 0)
    moneyLabel.BackgroundTransparency = 1
    moneyLabel.Text = "💰 +" .. moneyAmount .. "$"
    moneyLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    moneyLabel.TextScaled = true
    moneyLabel.Font = Enum.Font.GothamBold
    moneyLabel.Parent = billboardGui
    
    -- Animation de bobbing
    local bobTween = TweenService:Create(moneyPart, 
        TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = moneyPart.Position + Vector3.new(0, 1, 0)}
    )
    bobTween:Play()
    
    -- Sauvegarder les données de l'argent
    moneyDrops[moneyPart] = {
        player = player,
        amount = moneyAmount,
        created = currentTime
    }
    
    -- Supprimer l'argent après 30 secondes
    game:GetService("Debris"):AddItem(moneyPart, 30)
    task.spawn(function()
        wait(30)
        if moneyDrops[moneyPart] then
            moneyDrops[moneyPart] = nil
        end
    end)
    
    platformData.lastGeneration = currentTime
    platformData.totalGenerated = platformData.totalGenerated + moneyAmount
    
    print("💰 [PLATFORM] Argent généré:", moneyAmount, "$ pour", player.Name, "Total:", platformData.totalGenerated)
end

-- 🚶 Ramasser l'argent par proximité
local function checkMoneyPickup(player)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local playerPosition = humanoidRootPart.Position
    
    for moneyPart, moneyData in pairs(moneyDrops) do
        if moneyData.player == player and moneyPart.Parent then
            local distance = (playerPosition - moneyPart.Position).Magnitude
            if distance <= PRODUCTION_CONFIG.PICKUP_DISTANCE then
                -- Ramasser l'argent
                if _G.GameManager and _G.GameManager.ajouterArgent then
                    _G.GameManager.ajouterArgent(player, moneyData.amount)
                else
                    -- Fallback si GameManager pas disponible
                    local playerData = player:FindFirstChild("PlayerData")
                    if playerData and playerData:FindFirstChild("Argent") then
                        playerData.Argent.Value = playerData.Argent.Value + moneyData.amount
                    end
                end
                
                -- Effet de ramassage
                local pickupEffect = moneyPart:Clone()
                pickupEffect.Parent = workspace
                
                local pickupTween = TweenService:Create(pickupEffect,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {
                        Position = playerPosition + Vector3.new(0, 5, 0),
                        Size = Vector3.new(0.1, 0.1, 0.1),
                        Transparency = 1
                    }
                )
                pickupTween:Play()
                game:GetService("Debris"):AddItem(pickupEffect, 0.5)
                
                -- Supprimer l'argent
                moneyPart:Destroy()
                moneyDrops[moneyPart] = nil
                
                print("💰 [PICKUP] Argent ramassé:", moneyData.amount, "$ par", player.Name)
            end
        end
    end
end

-- 🔄 Rotation continue des bonbons
local function rotateCandies()
    for player, platforms in pairs(activePlatforms) do
        for platformId, platformData in pairs(platforms) do
            if platformData.candyModel and platformData.candyModel.Parent then
                local currentRotation = platformData.candyModel.Rotation
                platformData.candyModel.Rotation = Vector3.new(
                    currentRotation.X,
                    currentRotation.Y + PRODUCTION_CONFIG.ROTATION_SPEED * (1/30), -- 30 FPS
                    currentRotation.Z
                )
            end
        end
    end
end

-- 🎮 Gestion des événements
placeCandyEvent.OnServerEvent:Connect(function(player, platformId, candyName)
    placeCandyOnPlatform(player, platformId, candyName)
end)

-- 🔄 Boucle principale de production
RunService.Heartbeat:Connect(function()
    -- Rotation des bonbons
    rotateCandies()
    
    -- Génération d'argent et vérification de ramassage
    for player, platforms in pairs(activePlatforms) do
        if player.Parent then -- Vérifier que le joueur est encore connecté
            for platformId, platformData in pairs(platforms) do
                generateMoney(player, platformId, platformData)
            end
            checkMoneyPickup(player)
        else
            -- Nettoyer les plateformes des joueurs déconnectés
            for platformId, platformData in pairs(platforms) do
                if platformData.platform then
                    platformData.platform:Destroy()
                end
            end
            activePlatforms[player] = nil
        end
    end
end)

-- 🧹 Nettoyage à la déconnexion
Players.PlayerRemoving:Connect(function(player)
    if activePlatforms[player] then
        for platformId, platformData in pairs(activePlatforms[player]) do
            if platformData.platform then
                platformData.platform:Destroy()
            end
        end
        activePlatforms[player] = nil
    end
    
    -- Supprimer l'argent du joueur
    for moneyPart, moneyData in pairs(moneyDrops) do
        if moneyData.player == player then
            if moneyPart.Parent then
                moneyPart:Destroy()
            end
            moneyDrops[moneyPart] = nil
        end
    end
end)

print("🏭 [PLATFORM] Production Platform Server initialisé!")
