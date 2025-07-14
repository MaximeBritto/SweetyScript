-- EventMapTestUI.lua - Interface de test pour les events map
-- À PLACER EN : LocalScript dans StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("🧪 [TEST] Script de test démarré")

-- Attendre que les RemoteEvents soient créés
local getEventDataRemote
local success, err = pcall(function()
    getEventDataRemote = ReplicatedStorage:WaitForChild("GetEventDataRemote", 10)
end)

if not success or not getEventDataRemote then
    warn("❌ [TEST] GetEventDataRemote non trouvé ! Vérifiez CreateRemoteEvents.lua")
    return
end

print("✅ [TEST] GetEventDataRemote trouvé")

-- Interface de test
local function createTestUI()
    print("🧪 [TEST] Création de l'interface...")
    
    -- Vérifier si l'interface existe déjà
    local existingGui = playerGui:FindFirstChild("EventTestGui")
    if existingGui then
        existingGui:Destroy()
        print("🧪 [TEST] Interface existante supprimée")
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EventTestGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Frame principale
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "TestFrame"
    mainFrame.Size = UDim2.new(0, 250, 0, 300)
    mainFrame.Position = UDim2.new(0, 20, 0, 100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    mainFrame.Parent = screenGui
    
    -- Coins arrondis
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Titre
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    titleLabel.Text = "🧪 Test Events Map"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleLabel
    
    -- Infos du joueur
    local playerInfoLabel = Instance.new("TextLabel")
    playerInfoLabel.Size = UDim2.new(1, -20, 0, 40)
    playerInfoLabel.Position = UDim2.new(0, 10, 0, 40)
    playerInfoLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    playerInfoLabel.Text = "Events se déclencheront sur TON île automatiquement"
    playerInfoLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    playerInfoLabel.TextSize = 11
    playerInfoLabel.Font = Enum.Font.Gotham
    playerInfoLabel.TextWrapped = true
    playerInfoLabel.Parent = mainFrame
    
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 4)
    infoCorner.Parent = playerInfoLabel
    
    -- Mettre à jour l'info avec le slot du joueur
    task.spawn(function()
        while true do
            local playerSlot = player:GetAttribute("IslandSlot")
            if playerSlot then
                playerInfoLabel.Text = "🏝️ Ton île: Slot " .. playerSlot .. "\n(Events se déclencheront ici)"
                playerInfoLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                playerInfoLabel.Text = "⏳ Attente d'attribution d'île..."
                playerInfoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            end
            task.wait(1)
        end
    end)
    
    -- Fonction pour créer un bouton de test
    local function createTestButton(name, eventType, emoji, color, yPos)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -20, 0, 35)
        button.Position = UDim2.new(0, 10, 0, yPos)
        button.BackgroundColor3 = color
        button.Text = emoji .. " " .. name
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextSize = 12
        button.Font = Enum.Font.GothamBold
        button.Parent = mainFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            print("🧪 [TEST] Bouton cliqué:", name)
            
            -- Récupérer automatiquement le slot de l'île du joueur
            local playerSlot = player:GetAttribute("IslandSlot")
            if not playerSlot then
                warn("⚠️ [TEST] Tu n'as pas encore d'île assignée ! Attends un peu...")
                return
            end
            
            print("🧪 [TEST] Slot du joueur détecté:", playerSlot)
            print("🧪 [TEST] Envoi de la requête ForceEvent avec slot:", playerSlot, "eventType:", eventType)
            
            -- Utiliser RemoteFunction pour déclencher l'event
            local success, result = pcall(function()
                return getEventDataRemote:InvokeServer("ForceEvent", {slot = playerSlot, eventType = eventType})
            end)
            
            if success then
                if result then
                    print("✅ [TEST] Event " .. name .. " déclenché sur TON île (slot " .. playerSlot .. ")")
                else
                    warn("❌ [TEST] Le serveur a retourné false pour l'event " .. name)
                end
            else
                warn("💥 [TEST] Erreur lors de l'appel RemoteFunction:", result)
            end
        end)
        
        return button
    end
    
    -- Boutons de test pour chaque type d'event
    createTestButton("Tempête Bonbons", "TempeteBonbons", "🍬", Color3.fromRGB(255, 150, 50), 95)
    createTestButton("Pluie Ingrédients", "PluieIngredients", "🌈", Color3.fromRGB(100, 200, 100), 140)
    createTestButton("Boost Vitesse", "BoostVitesse", "⚡", Color3.fromRGB(100, 150, 255), 185)
    createTestButton("Event Légendaire", "EventLegendaire", "💎", Color3.fromRGB(200, 100, 255), 230)
    
    -- Bouton pour arrêter les events
    local stopButton = Instance.new("TextButton")
    stopButton.Size = UDim2.new(1, -20, 0, 25)
    stopButton.Position = UDim2.new(0, 10, 0, 270)
    stopButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    stopButton.Text = "🛑 Arrêter Event"
    stopButton.TextColor3 = Color3.new(1, 1, 1)
    stopButton.TextSize = 11
    stopButton.Font = Enum.Font.Gotham
    stopButton.Parent = mainFrame
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 4)
    stopCorner.Parent = stopButton
    
    stopButton.MouseButton1Click:Connect(function()
        print("🧪 [TEST] Bouton d'arrêt cliqué")
        
        -- Récupérer automatiquement le slot de l'île du joueur
        local playerSlot = player:GetAttribute("IslandSlot")
        if not playerSlot then
            warn("⚠️ [TEST] Tu n'as pas encore d'île assignée ! Attends un peu...")
            return
        end
        
        local success, result = pcall(function()
            return getEventDataRemote:InvokeServer("StopEvent", {slot = playerSlot})
        end)
        
        if success and result then
            print("🛑 [TEST] Event arrêté sur TON île (slot " .. playerSlot .. ")")
        else
            warn("❌ [TEST] Échec de l'arrêt d'event")
        end
    end)
    
    print("✅ [TEST] Interface créée avec succès")
end

-- Test de communication serveur
task.spawn(function()
    task.wait(3) -- Attendre que le serveur soit prêt
    print("🧪 [TEST] Test de communication avec le serveur...")
    
    local success, result = pcall(function()
        return getEventDataRemote:InvokeServer("GetActiveEvent", 1)
    end)
    
    if success then
        print("✅ [TEST] Communication serveur OK. Event actuel île 1:", result)
    else
        warn("❌ [TEST] Échec de communication serveur:", result)
    end
end)

-- Créer l'interface quand le joueur spawn
createTestUI()

print("🧪 [TEST] Interface de test des events chargée !") 