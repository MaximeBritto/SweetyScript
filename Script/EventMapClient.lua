--------------------------------------------------------------------
-- EventMapClient.lua - Effets visuels et notifications pour les events map
-- Gère l'affichage des tempêtes, nuages, et notifications d'events
-- À PLACER DANS : StarterPlayer > StarterPlayerScripts
--------------------------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------
-- VARIABLES GLOBALES
--------------------------------------------------------------------
local activeVisualEffects = {} -- [islandSlot] = {effects, gui, etc.}
local notificationGui = nil

--------------------------------------------------------------------
-- CONFIGURATION VISUELLE
--------------------------------------------------------------------
local VISUAL_CONFIG = {
    -- Couleurs des nuages par type d'event
    CLOUD_COLORS = {
        ["TempeteBonbons"] = Color3.fromRGB(255, 200, 100),
        ["PluieIngredients"] = Color3.fromRGB(150, 255, 150),
        ["BoostVitesse"] = Color3.fromRGB(100, 200, 255),
        ["EventLegendaire"] = Color3.fromRGB(255, 100, 255)
    },
    
    -- Taille et hauteur des nuages
    CLOUD_HEIGHT = 50,
    CLOUD_SIZE = Vector3.new(30, 15, 30),
    
    -- Particules
    PARTICLE_COUNT = 100,
    PARTICLE_LIFETIME = 3,
    
    -- Sons
    EVENT_START_SOUND = "rbxasset://sounds/electronicpingshort.wav",
    EVENT_END_SOUND = "rbxasset://sounds/button-3.wav"
}

--------------------------------------------------------------------
-- FONCTIONS UTILITAIRES
--------------------------------------------------------------------
local function getIslandBySlot(slot)
    -- Essayer plusieurs formats d'îles
    local island = Workspace:FindFirstChild("Ile_Slot_" .. slot) or 
                   Workspace:FindFirstChild("Ile_" .. player.Name)
    
    if island then
        print("✨ [CLIENT] Île trouvée pour slot", slot, ":", island.Name)
    else
        warn("⚠️ [CLIENT] Île non trouvée pour slot", slot)
        -- Debug: lister toutes les îles disponibles
        print("🔍 [CLIENT] Îles disponibles dans Workspace:")
        for _, child in pairs(Workspace:GetChildren()) do
            if child.Name:match("^Ile_") then
                print("  - " .. child.Name)
            end
        end
    end
    
    return island
end

local function createCloudEffect(island, eventType, eventData)
    if not island then return nil end
    
    -- Créer le modèle de nuage
    local cloudModel = Instance.new("Model")
    cloudModel.Name = "EventCloud_" .. eventType
    cloudModel.Parent = island
    
    -- Position du nuage au-dessus de l'île
    local islandCenter = island:GetPivot().Position
    local cloudPosition = islandCenter + Vector3.new(0, VISUAL_CONFIG.CLOUD_HEIGHT, 0)
    
    -- Nuage principal (invisible, sert de base)
    local cloudBase = Instance.new("Part")
    cloudBase.Name = "CloudBase"
    cloudBase.Size = VISUAL_CONFIG.CLOUD_SIZE
    cloudBase.Position = cloudPosition
    cloudBase.Anchored = true
    cloudBase.CanCollide = false
    cloudBase.Transparency = 1
    cloudBase.Parent = cloudModel
    
    -- Particules de nuage (plusieurs parts pour l'effet)
    for i = 1, 8 do
        local cloudPart = Instance.new("Part")
        cloudPart.Name = "CloudPart" .. i
        cloudPart.Size = Vector3.new(
            math.random(8, 15),
            math.random(5, 10),
            math.random(8, 15)
        )
        cloudPart.Position = cloudPosition + Vector3.new(
            math.random(-15, 15),
            math.random(-5, 5),
            math.random(-15, 15)
        )
        cloudPart.Anchored = true
        cloudPart.CanCollide = false
        cloudPart.Material = Enum.Material.ForceField
        cloudPart.Shape = Enum.PartType.Ball
        cloudPart.Color = VISUAL_CONFIG.CLOUD_COLORS[eventType] or Color3.new(1, 1, 1)
        cloudPart.Transparency = 0.3
        cloudPart.Parent = cloudModel
        
        -- Animation de rotation du nuage
        local rotationTween = TweenService:Create(
            cloudPart,
            TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
            {CFrame = cloudPart.CFrame * CFrame.Angles(0, math.rad(360), 0)}
        )
        rotationTween:Play()
    end
    
    -- Particules qui tombent
    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, -VISUAL_CONFIG.CLOUD_SIZE.Y/2, 0)
    attachment.Parent = cloudBase
    
    local particleEmitter = Instance.new("ParticleEmitter")
    particleEmitter.Parent = attachment
    
    -- Configuration des particules selon le type d'event
    if eventType == "TempeteBonbons" then
        particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100))
        particleEmitter.Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.5, 1),
            NumberSequenceKeypoint.new(1, 0.2)
        }
    elseif eventType == "PluieIngredients" then
        particleEmitter.Texture = "rbxasset://textures/particles/fire_main.dds"
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(150, 255, 150))
        particleEmitter.Size = NumberSequence.new(0.3, 0.8)
    elseif eventType == "BoostVitesse" then
        particleEmitter.Texture = "rbxasset://textures/particles/lightning_main.dds"
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
        particleEmitter.Size = NumberSequence.new(0.2, 1.2)
    elseif eventType == "EventLegendaire" then
        particleEmitter.Texture = "rbxasset://textures/particles/stars.dds"
        particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 100, 255))
        particleEmitter.Size = NumberSequence.new(0.8, 1.5)
    end
    
    particleEmitter.Lifetime = NumberRange.new(VISUAL_CONFIG.PARTICLE_LIFETIME)
    particleEmitter.Rate = VISUAL_CONFIG.PARTICLE_COUNT
    particleEmitter.SpreadAngle = Vector2.new(45, 45)
    particleEmitter.Speed = NumberRange.new(10, 20)
    particleEmitter.Acceleration = Vector3.new(0, -20, 0)
    
    -- Effet de pulsation pour le nuage
    local pulseTween = TweenService:Create(
        cloudModel.PrimaryPart or cloudBase,
        TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Size = VISUAL_CONFIG.CLOUD_SIZE * 1.2}
    )
    pulseTween:Play()
    
    return cloudModel
end

local function createNotificationGUI()
    if notificationGui then
        notificationGui:Destroy()
    end
    
    notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "EventNotificationGui"
    notificationGui.ResetOnSpawn = false
    notificationGui.Parent = playerGui
    
    return notificationGui
end

local function showEventNotification(eventInfo)
    local gui = notificationGui or createNotificationGUI()
    
    -- Frame principale de notification
    local notifFrame = Instance.new("Frame")
    notifFrame.Name = "EventNotification"
    notifFrame.Size = UDim2.new(0, 350, 0, 100)
    notifFrame.Position = UDim2.new(1, -370, 0, 20) -- Démarre hors écran à droite
    notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    notifFrame.BackgroundTransparency = 0.1
    notifFrame.BorderSizePixel = 2
    notifFrame.BorderColor3 = eventInfo.couleur or Color3.fromRGB(255, 255, 255)
    notifFrame.Parent = gui
    
    -- Coins arrondis
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notifFrame
    
    -- Effet de gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, eventInfo.couleur or Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30))
    }
    gradient.Rotation = 45
    gradient.Parent = notifFrame
    
    -- Titre de l'event
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = eventInfo.nom or "Event Inconnu"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = notifFrame
    
    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -20, 0, 40)
    descLabel.Position = UDim2.new(0, 10, 0, 30)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = eventInfo.description or "Description non disponible"
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextSize = 12
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = notifFrame
    
    -- Durée (si applicable)
    if eventInfo.duree and eventInfo.duree > 0 then
        local durationLabel = Instance.new("TextLabel")
        durationLabel.Size = UDim2.new(0, 100, 0, 20)
        durationLabel.Position = UDim2.new(1, -110, 0, 75)
        durationLabel.BackgroundTransparency = 1
        durationLabel.Text = "⏱️ " .. math.floor(eventInfo.duree) .. "s"
        durationLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        durationLabel.TextSize = 11
        durationLabel.Font = Enum.Font.GothamBold
        durationLabel.TextXAlignment = Enum.TextXAlignment.Right
        durationLabel.Parent = notifFrame
    end
    
    -- Animation d'entrée
    local slideInTween = TweenService:Create(
        notifFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -370, 0, 20)}
    )
    slideInTween:Play()
    
    -- Son de notification
    local sound = Instance.new("Sound")
    sound.SoundId = VISUAL_CONFIG.EVENT_START_SOUND
    sound.Volume = 0.5
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
    
    -- Animation de sortie et auto-suppression
    task.spawn(function()
        task.wait(4)
        local slideOutTween = TweenService:Create(
            notifFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 0, 0, 20)}
        )
        slideOutTween:Play()
        task.wait(0.5)
        if notifFrame and notifFrame.Parent then
            notifFrame:Destroy()
        end
    end)
end

--------------------------------------------------------------------
-- GESTION DES EVENTS VISUELS
--------------------------------------------------------------------
local function startVisualEvent(islandSlot, eventType, eventData, duration)
    local island = getIslandBySlot(islandSlot)
    if not island then
        warn("⚠️ Île non trouvée pour le slot:", islandSlot)
        return
    end
    
    -- Nettoyer les effets existants sur cette île
    if activeVisualEffects[islandSlot] then
        endVisualEvent(islandSlot)
    end
    
    -- Créer les nouveaux effets
    local cloudEffect = createCloudEffect(island, eventType, eventData)
    
    activeVisualEffects[islandSlot] = {
        cloudEffect = cloudEffect,
        eventType = eventType,
        startTime = tick(),
        duration = duration
    }
    
    print("🌪️ Effets visuels démarrés sur l'île " .. islandSlot .. ": " .. eventType)
end

local function endVisualEvent(islandSlot)
    local effects = activeVisualEffects[islandSlot]
    if not effects then return end
    
    -- Supprimer les effets visuels avec animation
    if effects.cloudEffect and effects.cloudEffect.Parent then
        local function fadeAllParts(obj)
            for _, child in ipairs(obj:GetDescendants()) do
                if child:IsA("BasePart") then
                    local fadeTween = TweenService:Create(
                        child,
                        TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Transparency = 1}
                    )
                    fadeTween:Play()
                end
            end
        end
        
        fadeAllParts(effects.cloudEffect)
        task.wait(2)
        effects.cloudEffect:Destroy()
    end
    
    activeVisualEffects[islandSlot] = nil
    print("🌪️ Effets visuels terminés sur l'île " .. islandSlot)
end

--------------------------------------------------------------------
-- CONNEXIONS AUX EVENTS DISTANTS
--------------------------------------------------------------------
-- Notifications d'events
local eventNotificationRemote = ReplicatedStorage:WaitForChild("EventNotificationRemote")
eventNotificationRemote.OnClientEvent:Connect(function(eventInfo)
    showEventNotification(eventInfo)
end)

-- Mises à jour visuelles
local eventVisualUpdateRemote = ReplicatedStorage:WaitForChild("EventVisualUpdateRemote")
eventVisualUpdateRemote.OnClientEvent:Connect(function(islandSlot, eventType, eventData, duration)
    if eventType == "EventFini" then
        endVisualEvent(islandSlot)
    else
        startVisualEvent(islandSlot, eventType, eventData, duration)
    end
end)

--------------------------------------------------------------------
-- INITIALISATION
--------------------------------------------------------------------
-- Créer l'interface de notifications
createNotificationGUI()

-- Nettoyer les effets visuels au déconnexion
game:BindToClose(function()
    for slot, _ in pairs(activeVisualEffects) do
        endVisualEvent(slot)
    end
end)

print("✨ EventMapClient initialisé - Effets visuels prêts!") 