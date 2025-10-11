--[[
SaveTestUI.lua - Interface de test simple pour le système de sauvegarde
Ce script client crée une interface basique pour tester les fonctions de sauvegarde.

À placer dans StarterPlayerScripts ou comme LocalScript
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Interface variables
local saveTestGui = nil
local mainFrame = nil
local isInterfaceOpen = false

-- Détection mobile
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Attendre les événements
local manualSaveEvent = ReplicatedStorage:WaitForChild("ManualSaveEvent", 10)
local saveStatsEvent = ReplicatedStorage:WaitForChild("SaveStatsEvent", 10)

-- Statistiques locales
local localStats = {
    lastSaveTime = 0,
    saveCount = 0,
}

--[[
CRÉATION DE L'INTERFACE
--]]
local function createSaveTestUI()
    -- GUI principal
    saveTestGui = Instance.new("ScreenGui")
    saveTestGui.Name = "SaveTestUI"
    saveTestGui.ResetOnSpawn = false
    saveTestGui.Parent = playerGui
    
    -- Bouton pour ouvrir l'interface (en haut à droite)
    local openButton = Instance.new("TextButton")
    openButton.Name = "OpenButton"
    openButton.Size = UDim2.new(0, 100, 0, 35)
    openButton.Position = UDim2.new(1, -110, 0, 10)
    openButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    openButton.BorderSizePixel = 0
    openButton.Text = "💾 Save"
    openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    openButton.TextSize = 14
    openButton.Font = Enum.Font.GothamBold
    openButton.Parent = saveTestGui
    
    local openCorner = Instance.new("UICorner", openButton)
    openCorner.CornerRadius = UDim.new(0, 8)
    
    -- Frame principal (caché au début)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 300)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = saveTestGui
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = Color3.fromRGB(100, 100, 100)
    mainStroke.Thickness = 2
    
    -- Titre
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "💾 Système de Sauvegarde - Test"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = mainFrame
    
    -- Bouton de fermeture
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner", closeButton)
    closeCorner.CornerRadius = UDim.new(0, 6)
    
    -- Bouton Sauvegarder
    local saveButton = Instance.new("TextButton")
    saveButton.Name = "SaveButton"
    saveButton.Size = UDim2.new(0, 150, 0, 40)
    saveButton.Position = UDim2.new(0, 20, 0, 70)
    saveButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    saveButton.BorderSizePixel = 0
    saveButton.Text = "💾 Sauvegarder"
    saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveButton.TextSize = 16
    saveButton.Font = Enum.Font.GothamBold
    saveButton.Parent = mainFrame
    
    local saveCorner = Instance.new("UICorner", saveButton)
    saveCorner.CornerRadius = UDim.new(0, 8)
    
    -- Bouton Statistiques
    local statsButton = Instance.new("TextButton")
    statsButton.Name = "StatsButton"
    statsButton.Size = UDim2.new(0, 150, 0, 40)
    statsButton.Position = UDim2.new(0, 190, 0, 70)
    statsButton.BackgroundColor3 = Color3.fromRGB(54, 162, 235)
    statsButton.BorderSizePixel = 0
    statsButton.Text = "📊 Statistiques"
    statsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    statsButton.TextSize = 16
    statsButton.Font = Enum.Font.GothamBold
    statsButton.Parent = mainFrame
    
    local statsCorner = Instance.new("UICorner", statsButton)
    statsCorner.CornerRadius = UDim.new(0, 8)
    
    -- Zone d'information
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, -40, 0, 160)
    infoFrame.Position = UDim2.new(0, 20, 0, 120)
    infoFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = mainFrame
    
    local infoCorner = Instance.new("UICorner", infoFrame)
    infoCorner.CornerRadius = UDim.new(0, 8)
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, -20, 1, -20)
    infoLabel.Position = UDim2.new(0, 10, 0, 10)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Cliquez sur 'Sauvegarder' pour tester le système de sauvegarde."
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 14
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.TextWrapped = true
    infoLabel.Parent = infoFrame
    
    -- Connexions des boutons
    openButton.MouseButton1Click:Connect(function()
        toggleInterface()
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        closeInterface()
    end)
    
    saveButton.MouseButton1Click:Connect(function()
        requestManualSave()
    end)
    
    statsButton.MouseButton1Click:Connect(function()
        requestSaveStats()
    end)
    
    print("✅ [SAVE TEST] Interface de test de sauvegarde créée")
end

--[[
FONCTIONS D'INTERFACE
--]]
function toggleInterface()
    if isInterfaceOpen then
        closeInterface()
    else
        openInterface()
    end
end

function openInterface()
    if isInterfaceOpen then return end
    
    isInterfaceOpen = true
    mainFrame.Visible = true
    
    -- Animation d'ouverture
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 400, 0, 300)
    })
    
    tween:Play()
    
    -- Afficher les informations initiales
    showCurrentDataSummary()
end

function closeInterface()
    if not isInterfaceOpen then return end
    
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    
    tween:Play()
    
    tween.Completed:Connect(function()
        mainFrame.Visible = false
        isInterfaceOpen = false
    end)
end

--[[
FONCTIONS DE SAUVEGARDE
--]]
function requestManualSave()
    if not manualSaveEvent then
        updateInfo("❌ Événement de sauvegarde non disponible")
        return
    end
    
    updateInfo("💾 Demande de sauvegarde en cours...")
    
    -- Envoyer la demande au serveur
    manualSaveEvent:FireServer()
    
    localStats.saveCount = localStats.saveCount + 1
    localStats.lastSaveTime = os.time()
end

-- Écouter la réponse de sauvegarde
if manualSaveEvent then
    manualSaveEvent.OnClientEvent:Connect(function(success, message)
        if success then
            updateInfo("✅ " .. (message or "Sauvegarde réussie!"))
        else
            updateInfo("❌ " .. (message or "Échec de la sauvegarde"))
        end
    end)
end

function requestSaveStats()
    if not saveStatsEvent then
        updateInfo("❌ Événement de statistiques non disponible")
        return
    end
    
    updateInfo("📊 Récupération des statistiques...")
    
    -- Demander les statistiques au serveur
    saveStatsEvent:FireServer()
end

-- Écouter les statistiques
if saveStatsEvent then
    saveStatsEvent.OnClientEvent:Connect(function(stats)
        showSaveStats(stats)
    end)
end

function showSaveStats(stats)
    if not stats then
        updateInfo("❌ Aucune statistique reçue")
        return
    end
    
    local infoText = "📊 STATISTIQUES DE SAUVEGARDE\\n\\n"
    
    if stats.global then
        infoText = infoText .. "🌍 SERVEUR:\\n"
        infoText = infoText .. "   • Total sauvegardes: " .. stats.global.totalSaves .. "\\n"
        infoText = infoText .. "   • Réussies: " .. stats.global.successfulSaves .. "\\n"
        infoText = infoText .. "   • Échouées: " .. stats.global.failedSaves .. "\\n"
        infoText = infoText .. "   • Joueurs actifs: " .. stats.activePlayers .. "\\n\\n"
    end
    
    if stats.player then
        infoText = infoText .. "👤 VOTRE COMPTE:\\n"
        if stats.player.lastSaveTime then
            local timeDiff = os.time() - stats.player.lastSaveTime
            infoText = infoText .. "   • Dernière sauvegarde: il y a " .. timeDiff .. "s\\n"
        else
            infoText = infoText .. "   • Dernière sauvegarde: Jamais\\n"
        end
        infoText = infoText .. "   • Cache disponible: " .. (stats.player.hasCachedData and "Oui" or "Non") .. "\\n"
    end
    
    infoText = infoText .. "\\n💻 CLIENT:\\n"
    infoText = infoText .. "   • Demandes: " .. localStats.saveCount .. "\\n"
    
    updateInfo(infoText)
end

function showCurrentDataSummary()
    local playerData = player:FindFirstChild("PlayerData")
    
    if not playerData then
        updateInfo("❌ PlayerData non trouvé")
        return
    end
    
    local infoText = "🧪 RÉSUMÉ DE VOS DONNÉES\\n\\n"
    
    -- Argent
    local argent = playerData:FindFirstChild("Argent")
    if argent then
        local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
        local formattedMoney = UIUtils.formatMoneyShort(argent.Value)
        infoText = infoText .. "💰 Argent: " .. formattedMoney .. "$\\n"
    end
    
    -- Inventaire
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        local toolCount = 0
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                toolCount = toolCount + 1
            end
        end
        infoText = infoText .. "📦 Inventaire: " .. toolCount .. " objets\\n"
    end
    
    -- Niveaux
    local merchantLevel = playerData:FindFirstChild("MerchantLevel")
    if merchantLevel then
        infoText = infoText .. "🏪 Niveau marchand: " .. merchantLevel.Value .. "\\n"
    end
    
    -- Tutoriel
    local tutorialCompleted = playerData:FindFirstChild("TutorialCompleted")
    if tutorialCompleted then
        infoText = infoText .. "🎓 Tutoriel: " .. (tutorialCompleted.Value and "Terminé" or "En cours") .. "\\n"
    else
        infoText = infoText .. "🎓 Tutoriel: Pas commencé\\n"
    end
    
    infoText = infoText .. "\\n⏰ Mise à jour: " .. os.date("%H:%M:%S")
    
    updateInfo(infoText)
end

function updateInfo(text)
    if mainFrame and mainFrame:FindFirstChild("InfoFrame") then
        local infoLabel = mainFrame.InfoFrame:FindFirstChild("InfoLabel")
        if infoLabel then
            infoLabel.Text = text
        end
    end
end

--[[
RACCOURCI CLAVIER
--]]
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- F8 pour ouvrir/fermer l'interface
    if input.KeyCode == Enum.KeyCode.F8 then
        toggleInterface()
    end
    
    -- Ctrl+S pour sauvegarder rapidement
    if input.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        requestManualSave()
    end
end)

--[[
INITIALISATION
--]]
-- Attendre que le joueur soit chargé
if player.Character then
    createSaveTestUI()
else
    player.CharacterAdded:Wait()
    task.wait(2) -- Laisser le temps aux autres systèmes de se charger
    createSaveTestUI()
end

print("✅ [SAVE TEST] Interface de test de sauvegarde prête")
print("💡 [SAVE TEST] Appuyez sur F8 pour ouvrir l'interface")
print("💡 [SAVE TEST] Ctrl+S pour sauvegarder rapidement")