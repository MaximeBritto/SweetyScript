-- EventMapClient.lua - Gestion côté client des événements de l'île
-- A placer dans StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Références aux RemoteEvents
local GetEventDataRemote = ReplicatedStorage:WaitForChild("GetEventDataRemote")
local EventVisualUpdateRemote = ReplicatedStorage:WaitForChild("EventVisualUpdateRemote")
local EventNotificationRemote = ReplicatedStorage:WaitForChild("EventNotificationRemote")

-- Table pour stocker les effets visuels actifs
local activeVisualEffects = {}

-- Table pour stocker les notifications actives
local activeNotifications = {}

-- Fonction utilitaire pour obtenir une île par son numéro de slot
local function getIslandBySlot(slotNumber)
    print("🔍 Recherche de l'île pour le slot:", slotNumber)
    
    -- Vérifier d'abord dans le dossier Islands s'il existe
    local islandsFolder = workspace:FindFirstChild("Islands") or workspace
    
    -- 1. Essayer de trouver une île avec un nom correspondant exactement au slot
    local island = islandsFolder:FindFirstChild("Island"..tostring(slotNumber)) or
                  islandsFolder:FindFirstChild("Ile"..tostring(slotNumber)) or
                  islandsFolder:FindFirstChild("Slot"..tostring(slotNumber)) or
                  islandsFolder:FindFirstChild("Isle"..tostring(slotNumber))
    
    -- 2. Si non trouvé, essayer avec un espace
    if not island then
        island = islandsFolder:FindFirstChild("Island "..tostring(slotNumber)) or
                islandsFolder:FindFirstChild("Ile "..tostring(slotNumber)) or
                islandsFolder:FindFirstChild("Slot "..tostring(slotNumber))
    end
    
    -- 3. Si toujours pas trouvé, chercher récursivement
    if not island then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (string.find(string.lower(obj.Name), "island") or 
                                      string.find(string.lower(obj.Name), "ile") or
                                      string.find(string.lower(obj.Name), "slot")) then
                -- Vérifier si le nom contient le numéro de slot
                if string.find(tostring(obj), tostring(slotNumber)) then
                    island = obj
                    print("✅ Île trouvée par recherche de modèle (slot", slotNumber, "):", island:GetFullName())
                    return island
                end
            end
        end
    end
    
    -- 4. Dernier recours : essayer de trouver par position si les îles sont organisées de manière logique
    if not island then
        -- Cette partie dépend de la structure de votre jeu
        -- Ajustez selon comment vos îles sont organisées dans l'espace
        local basePos = Vector3.new((slotNumber - 3.5) * 200, 0, 0) -- Ajustez le multiplicateur selon l'espacement de vos îles
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChild("MainPart")) then
                local pos = obj.PrimaryPart and obj.PrimaryPart.Position or obj.MainPart.Position
                if (pos - basePos).Magnitude < 100 then -- Ajustez le rayon selon besoin
                    island = obj
                    print("✅ Île trouvée par position (slot", slotNumber, "):", island:GetFullName())
                    return island
                end
            end
        end
    end
    
    if island then
        print("✅ Île trouvée pour le slot", slotNumber, ":", island:GetFullName())
    else
        warn("⚠️ Aucune île trouvée pour le slot", slotNumber)
    end
    
    return island
end

-- Fonction pour créer un effet de nuage pour une tempête
local function createCloudEffect(island, eventType, eventData)
    print("🌩️ Création d'un effet de nuage pour l'événement:", eventType)
    print("   - Île:", island and island:GetFullName() or "NON TROUVÉE")
    print("   - Type d'île:", typeof(island))
    print("   - Données de l'événement:", tostring(eventData))
    
    if not island then
        warn("❌ Impossible de créer l'effet: aucune île spécifiée")
        return nil
    end
    
    -- Créer un modèle pour contenir les effets
    local effectModel = Instance.new("Model")
    effectModel.Name = eventType.."Effect_"..tick()
    
    -- Trouver le centre de l'île
    local center = island:FindFirstChild("SpawnLocation") or island.PrimaryPart or island:FindFirstChild("Center") or island:FindFirstChild("MainPart")
    
    if not center then
        -- Si aucun point central n'est trouvé, utiliser le centre de l'île
        local cf, size = island:GetBoundingBox()
        if cf and size then
            center = Instance.new("Part")
            center.Anchored = true
            center.CanCollide = false
            center.Transparency = 1
            center.Size = Vector3.new(1, 1, 1)
            center.CFrame = cf
            center.Parent = island
            print("ℹ️ Point central créé pour l'île")
        else
            warn("❌ Impossible de déterminer le centre de l'île")
            return nil
        end
    end
    
    print("   - Point central:", center:GetFullName())
    
    -- Créer un grand nuage sombre au-dessus de l'île
    local cloud = Instance.new("Part")
    cloud.Name = "StormCloud_"..tostring(slot or "unknown")
    cloud.Anchored = true
    cloud.CanCollide = false
    cloud.Transparency = 0.5
    cloud.Color = Color3.fromRGB(80, 80, 80)
    cloud.Material = Enum.Material.SmoothPlastic
    cloud.Size = Vector3.new(120, 8, 120)
    
    -- Calculer la position du nuage au-dessus de l'île
    local islandCFrame, islandSize = island:GetBoundingBox()
    if not islandCFrame then
        islandCFrame = center.CFrame
        islandSize = Vector3.new(50, 50, 50) -- Taille par défaut si GetBoundingBox échoue
    end
    
    -- Ajuster la taille du nuage en fonction de la taille de l'île
    local cloudWidth = math.max(islandSize.X, islandSize.Z) * 1.5
    cloud.Size = Vector3.new(cloudWidth, 8, cloudWidth)
    
    -- Positionner le nuage au-dessus du centre de l'île
    local cloudHeight = math.max(islandSize.X, islandSize.Z) * 0.8 + 20
    local cloudPos = islandCFrame.Position + Vector3.new(0, cloudHeight, 0)
    
    -- Créer un effet de rotation aléatoire
    local randomRotation = math.rad(math.random(0, 360))
    cloud.CFrame = CFrame.new(cloudPos) * CFrame.Angles(0, randomRotation, 0)
    cloud.Parent = effectModel
    
    -- Ajouter des particules de pluie de bonbons plus visibles
    local rain = Instance.new("ParticleEmitter")
    rain.Name = "CandyRain"
    rain.LightEmission = 1
    rain.LightInfluence = 1
    rain.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.5),
        NumberSequenceKeypoint.new(0.5, 1.0),
        NumberSequenceKeypoint.new(1, 0.3)
    })
    rain.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    rain.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 100)),   -- Rouge vif
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(100, 255, 100)), -- Vert vif
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(100, 150, 255)), -- Bleu clair
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 255, 100)), -- Jaune vif
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(200, 100, 255)), -- Violet
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 150))    -- Rose
    })
    rain.Lifetime = NumberRange.new(3, 5)
    rain.Rate = 200
    rain.Speed = NumberRange.new(30, 50)
    rain.SpreadAngle = Vector2.new(70, 70)
    rain.Drag = 5  -- Ajouter de la traînée pour un effet plus réaliste
    rain.Shape = Enum.ParticleEmitterShape.Box
    rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    rain.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
    rain.EmissionDirection = Enum.NormalId.Bottom
    rain.Parent = cloud
    
    -- Ajouter un effet de particules pour le nuage
    local cloudParticles = Instance.new("ParticleEmitter")
    cloudParticles.Name = "CloudParticles"
    cloudParticles.Texture = "rbxassetid://241539447" -- Texture de nuage
    cloudParticles.LightEmission = 0.5
    cloudParticles.LightInfluence = 0
    cloudParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 20),
        NumberSequenceKeypoint.new(0.5, 25),
        NumberSequenceKeypoint.new(1, 20)
    })
    cloudParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(1, 0.3)
    })
    cloudParticles.Lifetime = NumberRange.new(3, 5)
    cloudParticles.Rate = 20
    cloudParticles.Rotation = NumberRange.new(-180, 180)
    cloudParticles.RotSpeed = NumberRange.new(-20, 20)
    cloudParticles.Speed = NumberRange.new(2, 5)
    cloudParticles.SpreadAngle = Vector2.new(180, 180)
    cloudParticles.Parent = cloud
    
    -- Faire tourner lentement le nuage
    local spin = Instance.new("BodyGyro")
    spin.MaxTorque = Vector3.new(0, math.huge, 0)
    spin.D = 50
    spin.P = 1000
    spin.CFrame = cloud.CFrame
    spin.Parent = cloud
    
    -- Animation de rotation du nuage
    local rotationConnection
    rotationConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if not cloud or not cloud.Parent then 
            rotationConnection:Disconnect()
            return 
        end
        spin.CFrame = spin.CFrame * CFrame.Angles(0, math.rad(0.1), 0)
    end)
    
    -- Nettoyer la connexion lorsque l'effet est détruit
    effectModel.Destroying:Connect(function()
        if rotationConnection then
            rotationConnection:Disconnect()
        end
    end)
    
    -- Créer le dossier Effects s'il n'existe pas
    local effectsFolder = workspace:FindFirstChild("Effects")
    if not effectsFolder then
        effectsFolder = Instance.new("Folder")
        effectsFolder.Name = "Effects"
        effectsFolder.Parent = workspace
        print("📁 Dossier Effects créé dans le workspace")
    end
    effectModel.Parent = effectsFolder
    print("☁️ Effet créé avec succès dans:", effectModel:GetFullName())
    
    return effectModel
end

-- Fonction pour nettoyer les effets visuels d'une île
local function cleanupVisualEvent(islandSlot)
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

-- Fonction pour démarrer un événement visuel
local function startVisualEvent(islandSlot, eventType, eventData, duration)
    local island = getIslandBySlot(islandSlot)
    if not island then
        warn("⚠️ Île non trouvée pour le slot:", islandSlot)
        return
    end
    
    -- Nettoyer les effets existants sur cette île
    if activeVisualEffects[islandSlot] then
        cleanupVisualEvent(islandSlot)
    end
    
    -- Créer les nouveaux effets
    local cloudEffect = createCloudEffect(island, eventType, eventData)
    
    -- Créer une notification à l'écran
    local notification = Instance.new("ScreenGui")
    notification.Name = eventType.."Notification"
    notification.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.6, 0, 0.15, 0)
    frame.Position = UDim2.new(0.2, 0, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.3
    frame.Parent = notification
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.5, 0)
    title.Position = UDim2.new(0, 0, 0.1, 0)
    title.BackgroundTransparency = 1
    title.Text = eventData.nom or eventType
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = eventData.couleur or Color3.new(1, 1, 1)
    title.TextStrokeTransparency = 0.5
    title.TextStrokeColor3 = Color3.new(0, 0, 0)
    title.Parent = frame
    
    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -40, 0.3, 0)
    description.Position = UDim2.new(0, 20, 0.5, 0)
    description.BackgroundTransparency = 1
    description.Text = eventData.description or ""
    description.TextScaled = true
    description.Font = Enum.Font.Gotham
    description.TextColor3 = Color3.new(1, 1, 1)
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Parent = frame
    
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(1, -40, 0.2, 0)
    timerLabel.Position = UDim2.new(0, 20, 0.8, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "Temps restant: " .. tostring(math.floor(duration or 0)) .. "s"
    timerLabel.TextScaled = true
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextColor3 = Color3.new(1, 1, 0)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left
    timerLabel.Parent = frame
    
    notification.Parent = playerGui
    
    -- Stocker les informations sur l'effet
    activeVisualEffects[islandSlot] = {
        cloudEffect = cloudEffect,
        notification = notification,
        timerLabel = timerLabel,
        startTime = tick(),
        duration = duration,
        eventType = eventType
    }
    
    print("🌪️ Effets visuels démarrés sur l'île " .. islandSlot .. ": " .. eventType)
end

-- Mettre à jour le minuteur de notification
local function updateNotificationTimer()
    while true do
        for slot, effects in pairs(activeVisualEffects) do
            if effects.timerLabel and effects.timerLabel.Parent then
                local elapsed = tick() - effects.startTime
                local remaining = math.max(0, (effects.duration or 0) - elapsed)
                
                if remaining <= 0 then
                    effects.timerLabel.Text = "Terminé!"
                    effects.timerLabel.TextColor3 = Color3.new(1, 0, 0)
                else
                    effects.timerLabel.Text = string.format("Temps restant: %ds", math.ceil(remaining))
                    
                    -- Changer la couleur quand il reste peu de temps
                    if remaining < 10 then
                        effects.timerLabel.TextColor3 = Color3.new(1, 0.5, 0)
                    elseif remaining < 30 then
                        effects.timerLabel.TextColor3 = Color3.new(1, 1, 0)
                    end
                end
            end
        end
        wait(0.5) -- Mettre à jour toutes les 0.5 secondes
    end
end

-- Démarrer la boucle de mise à jour du minuteur
coroutine.wrap(updateNotificationTimer)()

-- Fonction pour obtenir le slot de l'île du joueur
local function getPlayerIslandSlot()
    -- À adapter selon votre système de gestion des îles
    -- Par exemple, si vous avez un système qui stocke l'île du joueur dans son PlayerData
    local playerData = player:FindFirstChild("PlayerData")
    if playerData and playerData:FindFirstChild("CurrentIsland") then
        return playerData.CurrentIsland.Value
    end
    
    -- Si pas de système de gestion d'île, retourner 1 par défaut
    return 1
end

-- Gérer les mises à jour d'événements
EventVisualUpdateRemote.OnClientEvent:Connect(function(islandSlot, eventType, eventData, duration)
    -- Afficher les informations de débogage
    print("🎬 Événement reçu - Slot:", islandSlot, "Type:", eventType, "Durée:", duration)
    print("   - Données:", tostring(eventData))
    
    -- Obtenir l'île actuelle du joueur
    local currentIsland = getPlayerIslandSlot()
    
    -- Vérifier si l'événement concerne l'île actuelle du joueur
    if islandSlot ~= currentIsland then
        print("ℹ️ [CLIENT] Événement ignoré - Pas sur l'île du joueur (actuelle:", currentIsland, "événement:", islandSlot, ")")
        return
    end
    
    -- Gérer le début ou la fin de l'événement
    if eventType and eventType ~= "" then
        print("🌪️ [CLIENT] Début d'événement sur l'île", islandSlot, "-", eventType)
        startVisualEvent(islandSlot, eventType, eventData, duration)
    else
        print("🌪️ [CLIENT] Fin d'événement sur l'île", islandSlot)
        cleanupVisualEvent(islandSlot)
    end
end)

-- Fonction pour supprimer une notification existante
local function removeNotification(notificationSlot)
    if activeNotifications[notificationSlot] then
        for _, notification in ipairs(activeNotifications[notificationSlot]) do
            if notification and notification.Parent then
                notification:Destroy()
            end
        end
        activeNotifications[notificationSlot] = nil
    end
end

-- Gérer les notifications d'événements
EventNotificationRemote.OnClientEvent:Connect(function(islandSlot, message, eventType)
    -- Obtenir l'île actuelle du joueur
    local currentIsland = getPlayerIslandSlot()
    
    -- Ne montrer la notification que si l'événement concerne l'île actuelle du joueur
    if islandSlot ~= currentIsland then
        print("ℹ️ [CLIENT] Notification ignorée - Pas sur l'île du joueur (actuelle:", currentIsland, "événement:", islandSlot, ")")
        return
    end
    
    -- Si le message est vide, cela signifie qu'il faut supprimer la notification
    if message == "" then
        removeNotification(islandSlot)
        return
    end
    
    print("📢 [CLIENT] Notification pour l'île", islandSlot, ":", message)
    
    -- Supprimer toute notification existante pour ce slot
    removeNotification(islandSlot)
    
    -- Créer une notification
    local notification = Instance.new("ScreenGui")
    notification.Name = "EventNotification_" .. tostring(islandSlot)
    notification.ResetOnSpawn = false
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.4, 0, 0.1, 0)
    frame.Position = UDim2.new(0.3, 0, 0.05, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.3
    frame.Parent = notification
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = frame
    
    -- Ajouter la notification à la liste des notifications actives
    activeNotifications[islandSlot] = {notification}
    notification.Parent = playerGui
    
    -- Si c'est une notification de fin, la faire disparaître après 5 secondes
    if not eventType or eventType == "" then
        delay(5, function()
            if notification and notification.Parent then
                local tween = TweenService:Create(
                    frame,
                    TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {BackgroundTransparency = 1}
                )
                
                local labelTween = TweenService:Create(
                    label,
                    TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {TextTransparency = 1}
                )
                
                tween:Play()
                labelTween:Play()
                
                tween.Completed:Wait()
                notification:Destroy()
                activeNotifications[islandSlot] = nil
            end
        end)
    end
end)

print("✅ [CLIENT] EventMapClient initialisé")
