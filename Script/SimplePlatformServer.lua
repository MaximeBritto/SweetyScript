--[[
    🏭 PLATEFORMES SIMPLES - SERVEUR
    Plateformes physiques sur l'île pour poser directement les bonbons
    
    Utilisation: Cliquez sur une plateforme vide avec un bonbon en main
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Configuration
local CONFIG = {
    GENERATION_INTERVAL = 5,
    BASE_GENERATION = 10,
    PICKUP_DISTANCE = 8,
    LEVITATION_HEIGHT = 3,
    ROTATION_SPEED = 45,
}

-- Variables
local activePlatforms = {}
local moneyDrops = {}

-- 🏗️ Créer une plateforme physique sur l'île
local function createPhysicalPlatform(position)
    local platform = Instance.new("Part")
    platform.Name = "CandyProductionPlatform"
    platform.Material = Enum.Material.Neon
    platform.BrickColor = BrickColor.new("Bright blue")
    platform.Shape = Enum.PartType.Cylinder
    platform.Size = Vector3.new(0.5, 4, 4)
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
    
    -- ClickDetector pour interaction directe
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 10
    clickDetector.Parent = platform
    
    -- Gestion du clic - déclaration inline pour éviter erreur de scope
    clickDetector.MouseClick:Connect(function(player)
        print("🕱️ [PLATFORM] Clic sur plateforme par", player.Name)
        
        -- Vérifier si la plateforme est déjà occupée
        if activePlatforms[platform] then
            print("❌ [PLATFORM] Plateforme déjà occupée")
            return
        end
        
        -- Vérifier qu'un bonbon est équipé
        local character = player.Character
        if not character then 
            print("❌ [PLATFORM] Pas de personnage")
            return 
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then 
            print("❌ [PLATFORM] Pas d'humanoïde")
            return 
        end
        
        local equippedTool = humanoid:FindFirstChildOfClass("Tool")
        if not equippedTool then
            print("💡 [PLATFORM] Équipez un bonbon d'abord!")
            return
        end
        
        -- Vérifier que c'est bien un bonbon
        if not equippedTool:GetAttribute("IsCandy") then
            print("❌ [PLATFORM] Seuls les bonbons peuvent être placés!")
            return
        end
        
        -- Placer le bonbon sur la plateforme
        local candyName = equippedTool.Name
        local stackSize = equippedTool:GetAttribute("StackSize") or 1
        
        -- Retirer le bonbon de l'inventaire du joueur
        equippedTool.Parent = nil
        
        -- Créer le modèle de bonbon en lévitation
        local candyModel = Instance.new("Part")
        candyModel.Name = "FloatingCandy"
        candyModel.Material = Enum.Material.Neon
        candyModel.Shape = Enum.PartType.Ball
        candyModel.Size = Vector3.new(2, 2, 2)
        candyModel.Position = platform.Position + Vector3.new(0, CONFIG.LEVITATION_HEIGHT, 0)
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
        
        -- ClickDetector pour retirer le bonbon
        local removeDetector = Instance.new("ClickDetector")
        removeDetector.MaxActivationDistance = 10
        removeDetector.Parent = candyModel
        
        removeDetector.MouseClick:Connect(function(clickingPlayer)
            if clickingPlayer == player then
                -- Supprimer le modèle de bonbon
                if candyModel then
                    candyModel:Destroy()
                end
                
                -- Nettoyer les données
                activePlatforms[platform] = nil
                
                print("🗑️ [PLATFORM] Bonbon retiré de la plateforme")
            end
        end)
        
        -- Sauvegarder les données de la plateforme
        activePlatforms[platform] = {
            player = player,
            candy = candyName,
            candyModel = candyModel,
            lastGeneration = tick(),
            stackSize = stackSize,
            totalGenerated = 0
        }
        
        print("✅ [PLATFORM] Bonbon placé:", candyName, "Stack:", stackSize, "par", player.Name)
    end)
    
    print(" [PLATFORM] Plateforme physique créée à", position)
    return platform
end


    local candyName = tool.Name
    local stackSize = tool:GetAttribute("StackSize") or 1
    
    -- Retirer le bonbon de l'inventaire du joueur
    tool.Parent = nil
    
    -- Créer le modèle de bonbon en lévitation
    local candyModel = Instance.new("Part")
    candyModel.Name = "FloatingCandy"
    candyModel.Material = Enum.Material.Neon
    candyModel.Shape = Enum.PartType.Ball
    candyModel.Size = Vector3.new(2, 2, 2)
    candyModel.Position = platform.Position + Vector3.new(0, CONFIG.LEVITATION_HEIGHT, 0)
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
    
    -- ClickDetector pour retirer le bonbon
    local removeDetector = Instance.new("ClickDetector")
    removeDetector.MaxActivationDistance = 10
    removeDetector.Parent = candyModel
    
    removeDetector.MouseClick:Connect(function(clickingPlayer)
        if clickingPlayer == player then
            removeCandyFromPlatform(platform)
        end
    end)
    
    -- Sauvegarder les données de la plateforme
    activePlatforms[platform] = {
        player = player,
        candy = candyName,
        candyModel = candyModel,
        lastGeneration = tick(),
        stackSize = stackSize,
        totalGenerated = 0
    }
    
    print("✅ [PLATFORM] Bonbon placé:", candyName, "Stack:", stackSize, "par", player.Name)
end



-- 💰 Générer de l'argent automatiquement
local function generateMoney(platform, platformData)
    local currentTime = tick()
    if currentTime - platformData.lastGeneration < CONFIG.GENERATION_INTERVAL then
        return
    end
    
    -- Calculer la génération basée sur la taille du stack
    local baseAmount = CONFIG.BASE_GENERATION
    local stackMultiplier = platformData.stackSize or 1
    local moneyAmount = baseAmount * stackMultiplier
    
    -- Créer l'argent au sol
    local moneyPart = Instance.new("Part")
    moneyPart.Name = "MoneyDrop"
    moneyPart.Material = Enum.Material.Neon
    moneyPart.BrickColor = BrickColor.new("Bright yellow")
    moneyPart.Shape = Enum.PartType.Ball
    moneyPart.Size = Vector3.new(1, 1, 1)
    moneyPart.Position = platform.Position + Vector3.new(
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
        player = platformData.player,
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
    
    print("💰 [PLATFORM] Argent généré:", moneyAmount, "$ Total:", platformData.totalGenerated)
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
            if distance <= CONFIG.PICKUP_DISTANCE then
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
    for platform, platformData in pairs(activePlatforms) do
        if platformData.candyModel and platformData.candyModel.Parent then
            local currentRotation = platformData.candyModel.Rotation
            platformData.candyModel.Rotation = Vector3.new(
                currentRotation.X,
                currentRotation.Y + CONFIG.ROTATION_SPEED * (1/30), -- 30 FPS
                currentRotation.Z
            )
        end
    end
end

-- 🔄 Boucle principale de production
RunService.Heartbeat:Connect(function()
    -- Rotation des bonbons
    rotateCandies()
    
    -- Génération d'argent et vérification de ramassage
    for platform, platformData in pairs(activePlatforms) do
        if platformData.player.Parent then -- Vérifier que le joueur est encore connecté
            generateMoney(platform, platformData)
            checkMoneyPickup(platformData.player)
        else
            -- Nettoyer les plateformes des joueurs déconnectés
            removeCandyFromPlatform(platform)
        end
    end
end)

-- 🧹 Nettoyage à la déconnexion
Players.PlayerRemoving:Connect(function(player)
    for platform, platformData in pairs(activePlatforms) do
        if platformData.player == player then
            if platformData.candyModel then
                platformData.candyModel:Destroy()
            end
            activePlatforms[platform] = nil
        end
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

-- 🏭 Créer quelques plateformes d'exemple sur l'île
local function createExamplePlatforms()
    -- Créer 3 plateformes d'exemple près du spawn
    local spawnLocation = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
    local basePosition = spawnLocation and spawnLocation.Position or Vector3.new(0, 5, 0)
    
    for i = 1, 3 do
        local position = basePosition + Vector3.new(i * 8 - 12, 2, 10)
        createPhysicalPlatform(position)
    end
end

-- Créer les plateformes d'exemple au démarrage
createExamplePlatforms()

print("🏭 [PLATFORM] Système de plateformes simples initialisé!")
print("💡 Cliquez sur une plateforme bleue avec un bonbon en main pour le placer!")
print("💡 Cliquez sur le bonbon flottant pour le retirer!")
