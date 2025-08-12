-- Ce script (local) gère l'interface du sac à bonbons responsive
-- À placer dans ScreenGui

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Détection plateforme pour interface responsive
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Module de recettes
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local RECETTES = RecipeManager.Recettes
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

-- RemoteEvents
local ouvrirSacEvent = ReplicatedStorage:WaitForChild("OuvrirSacEvent")
-- local vendreUnBonbonEvent = ReplicatedStorage:WaitForChild("VendreUnBonbonEvent") -- SUPPRIMÉ - ancien système

-- Variables du sac
local sacFrame = nil
local isSacOpen = false

-- Déclaration des fonctions locales (pour éviter les erreurs)
local updateSacContent
local createBonbonSlot
local ouvrirSac
local fermerSac

-- Fonction pour créer le bouton du sac (responsive)
local function createSacButton()
    local boutonSac = screenGui:FindFirstChild("BoutonSac")
    if boutonSac then return end

    boutonSac = Instance.new("TextButton")
    boutonSac.Name = "BoutonSac"
    
    -- Taille et position responsives
    if isMobile or isSmallScreen then
        boutonSac.Size = UDim2.new(0, 50, 0, 50)  -- Plus petit sur mobile
        boutonSac.Position = UDim2.new(0.02, 0, 0.25, 0)  -- Plus bas pour éviter le HUD
    else
        boutonSac.Size = UDim2.new(0, 60, 0, 60)
        boutonSac.Position = UDim2.new(0.02, 0, 0.15, 0)
    end
    
    boutonSac.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
    boutonSac.Text = "🎒"
    boutonSac.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonSac.TextSize = (isMobile or isSmallScreen) and 20 or 24
    boutonSac.Font = Enum.Font.SourceSansBold
    boutonSac.BorderSizePixel = (isMobile or isSmallScreen) and 1 or 2
    boutonSac.BorderColor3 = Color3.fromRGB(101, 67, 33)
    boutonSac.Parent = screenGui
    
    -- Coins arrondis sur mobile
    if isMobile or isSmallScreen then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = boutonSac
    end

    -- Effet de survol
    boutonSac.MouseEnter:Connect(function()
        local tween = TweenService:Create(boutonSac, TweenInfo.new(0.2), {Size = UDim2.new(0, 65, 0, 65)})
        tween:Play()
    end)

    boutonSac.MouseLeave:Connect(function()
        local tween = TweenService:Create(boutonSac, TweenInfo.new(0.2), {Size = UDim2.new(0, 60, 0, 60)})
        tween:Play()
    end)

    -- Connexion du clic
    boutonSac.MouseButton1Click:Connect(function()
        if isSacOpen then
            fermerSac()
        else
            ouvrirSac()
        end
    end)
end

-- Fonction pour créer l'interface du sac (responsive)
local function createSacInterface()
    if sacFrame then
        sacFrame:Destroy()
    end

    -- Frame principale du sac (responsive)
    sacFrame = Instance.new("Frame")
    sacFrame.Name = "SacFrame"
    
    -- Taille et position responsives
    if isMobile or isSmallScreen then
        sacFrame.Size = UDim2.new(0.9, 0, 0.7, 0)  -- 90% largeur, 70% hauteur sur mobile
        sacFrame.Position = UDim2.new(0.05, 0, 0.15, 0)  -- Centré sur mobile
    else
        sacFrame.Size = UDim2.new(0, 500, 0, 400)
        sacFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    end
    
    sacFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sacFrame.BorderSizePixel = (isMobile or isSmallScreen) and 2 or 3
    sacFrame.BorderColor3 = Color3.fromRGB(139, 69, 19)
    sacFrame.Parent = screenGui
    
    -- Coins arrondis sur mobile
    if isMobile or isSmallScreen then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = sacFrame
    end

    -- Titre du sac (responsive)
    local titre = Instance.new("TextLabel")
    titre.Name = "Titre"
    
    local titleHeight = (isMobile or isSmallScreen) and 40 or 50
    titre.Size = UDim2.new(1, 0, 0, titleHeight)
    titre.Position = UDim2.new(0, 0, 0, 0)
    titre.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
    titre.Text = (isMobile or isSmallScreen) and "🎒 SAC" or "🎒 Sac à Bonbons"
    titre.TextColor3 = Color3.fromRGB(255, 255, 255)
    titre.TextSize = (isMobile or isSmallScreen) and 16 or 20
    titre.Font = Enum.Font.SourceSansBold
    titre.TextScaled = (isMobile or isSmallScreen)
    titre.Parent = sacFrame
    
    -- Coins arrondis du titre sur mobile
    if isMobile or isSmallScreen then
        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 12)
        titleCorner.Parent = titre
    end

    -- Bouton de fermeture (responsive)
    local boutonFermer = Instance.new("TextButton")
    boutonFermer.Name = "BoutonFermer"
    
    local closeSize = (isMobile or isSmallScreen) and 35 or 30
    boutonFermer.Size = UDim2.new(0, closeSize, 0, closeSize)
    boutonFermer.Position = UDim2.new(1, -(closeSize + 5), 0, (isMobile or isSmallScreen) and 2 or 10)
    boutonFermer.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    boutonFermer.Text = "X"
    boutonFermer.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonFermer.TextSize = (isMobile or isSmallScreen) and 18 or 14
    boutonFermer.Font = Enum.Font.SourceSansBold
    boutonFermer.Parent = sacFrame
    
    -- Coins arrondis du bouton fermer sur mobile
    if isMobile or isSmallScreen then
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 8)
        closeCorner.Parent = boutonFermer
    end

    -- Zone de défilement pour les bonbons (responsive)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    
    local scrollMargin = (isMobile or isSmallScreen) and 10 or 20
    local scrollTopOffset = titleHeight + 10
    scrollFrame.Size = UDim2.new(1, -scrollMargin, 1, -(scrollTopOffset + 10))
    scrollFrame.Position = UDim2.new(0, scrollMargin/2, 0, scrollTopOffset)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    scrollFrame.BorderSizePixel = (isMobile or isSmallScreen) and 0 or 1
    scrollFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.ScrollBarThickness = (isMobile or isSmallScreen) and 6 or 8
    scrollFrame.Parent = sacFrame
    
    -- Coins arrondis de la zone de scroll sur mobile
    if isMobile or isSmallScreen then
        local scrollCorner = Instance.new("UICorner")
        scrollCorner.CornerRadius = UDim.new(0, 8)
        scrollCorner.Parent = scrollFrame
    end

    -- Connexion du bouton de fermeture
    boutonFermer.MouseButton1Click:Connect(function()
        fermerSac()
    end)

    -- Animation d'ouverture
    sacFrame.Size = UDim2.new(0, 0, 0, 0)
    local tween = TweenService:Create(sacFrame, TweenInfo.new(0.3), {Size = UDim2.new(0, 500, 0, 400)})
    tween:Play()

    -- Mettre à jour le contenu
    updateSacContent()
end

-- Fonction pour mettre à jour le contenu du sac
updateSacContent = function()
    if not sacFrame then return end

    local scrollFrame = sacFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end

    -- Nettoyer le contenu existant
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Récupérer les données du joueur
    local playerData = player:WaitForChild("PlayerData")
    local sacBonbons = playerData:WaitForChild("SacBonbons")



    local yPosition = 0
    local bonbonsListe = {}

    -- Collecter tous les bonbons
    for _, bonbon in pairs(sacBonbons:GetChildren()) do
        if bonbon:IsA("IntValue") and bonbon.Value > 0 then
            table.insert(bonbonsListe, {nom = bonbon.Name, quantite = bonbon.Value})
        end
    end

    -- Trier par rareté (valeur)
    table.sort(bonbonsListe, function(a, b)
        local recetteA = RECETTES[a.nom]
        local recetteB = RECETTES[b.nom]
        if recetteA and recetteB then
            return recetteA.valeur > recetteB.valeur
        end
        return false
    end)

    -- Créer les éléments d'interface
    for i, bonbonData in ipairs(bonbonsListe) do
        local recette = RECETTES[bonbonData.nom]
        if recette then
            createBonbonSlot(scrollFrame, bonbonData, recette, yPosition)
            yPosition = yPosition + 80
        end
    end

    -- Ajuster la taille du ScrollFrame
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition)

    -- Message si le sac est vide
    if #bonbonsListe == 0 then
        local messageVide = Instance.new("TextLabel")
        messageVide.Name = "MessageVide"
        messageVide.Size = UDim2.new(1, -20, 0, 50)
        messageVide.Position = UDim2.new(0, 10, 0, 10)
        messageVide.BackgroundTransparency = 1
        messageVide.Text = "Votre sac est vide ! Allez produire des bonbons !"
        messageVide.TextColor3 = Color3.fromRGB(200, 200, 200)
        messageVide.TextSize = 16
        messageVide.Font = Enum.Font.SourceSansItalic
        messageVide.TextWrapped = true
        messageVide.Parent = scrollFrame
    end
end

-- Fonction pour créer un slot de bonbon
createBonbonSlot = function(parent, bonbonData, recette, yPos)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "Slot_" .. bonbonData.nom
    slotFrame.Size = UDim2.new(1, -20, 0, 70)
    slotFrame.Position = UDim2.new(0, 10, 0, yPos)
    slotFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    slotFrame.BorderSizePixel = 1
    slotFrame.BorderColor3 = Color3.fromRGB(120, 120, 120)
    slotFrame.Parent = parent

    -- ViewportFrame pour le modèle 3D
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "ModelView"
    viewport.Size = UDim2.new(0, 60, 0, 60)
    viewport.Position = UDim2.new(0, 5, 0, 5)
    viewport.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    viewport.Parent = slotFrame

    local candyModelsFolder = ReplicatedStorage:FindFirstChild("CandyModels")
    if candyModelsFolder then
        local candyModel = candyModelsFolder:FindFirstChild(recette.modele)
        if candyModel then
            UIUtils.setupViewportFrame(viewport, candyModel)
        else
            warn("Modèle 3D introuvable pour le bonbon : " .. recette.modele)
            local emojiLabel = Instance.new("TextLabel", viewport)
            emojiLabel.Size = UDim2.new(1, 0, 1, 0)
            emojiLabel.BackgroundTransparency = 1
            emojiLabel.TextScaled = true
            emojiLabel.Text = recette.emoji
        end
    end

    -- Informations du bonbon
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(0, 200, 0, 50)
    infoLabel.Position = UDim2.new(0, 70, 0, 10)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = recette.nom .. " x" .. bonbonData.quantite .. "\nValeur: " .. recette.valeur .. "$ chacun"
    infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoLabel.TextSize = 14
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.Parent = slotFrame

    -- ANCIEN SYSTÈME DE VENTE SUPPRIMÉ
    -- Utilisez maintenant le nouveau système de vente (touche V ou bouton 💰 VENTE)
end

-- Fonction pour ouvrir le sac
ouvrirSac = function()
    if not isSacOpen then
        isSacOpen = true
        createSacInterface()
        
        -- Notifier le tutoriel que le sac a été ouvert
        local tutorialRemote = ReplicatedStorage:FindFirstChild("TutorialRemote")
        if tutorialRemote then
            tutorialRemote:FireServer("bag_opened")
        end
    end
end

-- Fonction pour fermer le sac
fermerSac = function()
    if sacFrame then
        local tween = TweenService:Create(sacFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function()
            sacFrame:Destroy()
            sacFrame = nil
            isSacOpen = false
        end)
    end
end

-- Écouter les changements dans le sac pour mettre à jour l'interface
local function setupSacListener()
    local playerData = player:WaitForChild("PlayerData")
    local sacBonbons = playerData:WaitForChild("SacBonbons")

    -- Fonction pour connecter l'événement .Changed
    local function connectChangedEvent(bonbon)
        if bonbon:IsA("IntValue") then
            bonbon.Changed:Connect(function()
                if isSacOpen then
                    wait(0.1) -- Petit délai pour éviter les problèmes de timing
                    updateSacContent()
                end
            end)
        end
    end

    -- Mettre à jour quand des bonbons sont ajoutés/supprimés
    sacBonbons.ChildAdded:Connect(function(newBonbon)
        if isSacOpen then
            wait(0.1)
            updateSacContent()
        end
        -- Connecter l'événement pour le nouvel objet
        connectChangedEvent(newBonbon)
    end)

    sacBonbons.ChildRemoved:Connect(function()
        if isSacOpen then
            wait(0.1)
            updateSacContent()
        end
    end)

    -- Connecter les événements pour les objets déjà présents au démarrage
    for _, bonbon in pairs(sacBonbons:GetChildren()) do
        connectChangedEvent(bonbon)
    end
end

-- Initialisation
createSacButton()
setupSacListener()

-- Connexion à l'événement d'ouverture du sac (si nécessaire)
ouvrirSacEvent.OnClientEvent:Connect(ouvrirSac) 