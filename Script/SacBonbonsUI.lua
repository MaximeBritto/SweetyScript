-- Ce script (local) gère l'interface du sac à bonbons
-- À placer dans ScreenGui

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Module de recettes
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local RECETTES = RecipeManager.Recettes
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

-- RemoteEvents
local ouvrirSacEvent = ReplicatedStorage:WaitForChild("OuvrirSacEvent")
local vendreUnBonbonEvent = ReplicatedStorage:WaitForChild("VendreUnBonbonEvent")

-- Variables du sac
local sacFrame = nil
local isSacOpen = false

-- Déclaration des fonctions locales (pour éviter les erreurs)
local updateSacContent
local createBonbonSlot
local ouvrirSac
local fermerSac

-- Fonction pour créer le bouton du sac
local function createSacButton()
    local boutonSac = screenGui:FindFirstChild("BoutonSac")
    if boutonSac then return end

    boutonSac = Instance.new("TextButton")
    boutonSac.Name = "BoutonSac"
    boutonSac.Size = UDim2.new(0, 60, 0, 60)
    boutonSac.Position = UDim2.new(0.02, 0, 0.15, 0)
    boutonSac.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
    boutonSac.Text = "🎒"
    boutonSac.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonSac.TextSize = 24
    boutonSac.Font = Enum.Font.SourceSansBold
    boutonSac.BorderSizePixel = 2
    boutonSac.BorderColor3 = Color3.fromRGB(101, 67, 33)
    boutonSac.Parent = screenGui

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

-- Fonction pour créer l'interface du sac
local function createSacInterface()
    if sacFrame then
        sacFrame:Destroy()
    end

    -- Frame principale du sac
    sacFrame = Instance.new("Frame")
    sacFrame.Name = "SacFrame"
    sacFrame.Size = UDim2.new(0, 500, 0, 400)
    sacFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    sacFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sacFrame.BorderSizePixel = 3
    sacFrame.BorderColor3 = Color3.fromRGB(139, 69, 19)
    sacFrame.Parent = screenGui

    -- Titre du sac
    local titre = Instance.new("TextLabel")
    titre.Name = "Titre"
    titre.Size = UDim2.new(1, 0, 0, 50)
    titre.Position = UDim2.new(0, 0, 0, 0)
    titre.BackgroundColor3 = Color3.fromRGB(139, 69, 19)
    titre.Text = "🎒 Sac à Bonbons"
    titre.TextColor3 = Color3.fromRGB(255, 255, 255)
    titre.TextSize = 20
    titre.Font = Enum.Font.SourceSansBold
    titre.Parent = sacFrame

    -- Bouton de fermeture
    local boutonFermer = Instance.new("TextButton")
    boutonFermer.Name = "BoutonFermer"
    boutonFermer.Size = UDim2.new(0, 30, 0, 30)
    boutonFermer.Position = UDim2.new(1, -35, 0, 10)
    boutonFermer.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    boutonFermer.Text = "X"
    boutonFermer.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonFermer.TextSize = 14
    boutonFermer.Font = Enum.Font.SourceSansBold
    boutonFermer.Parent = sacFrame

    -- Zone de défilement pour les bonbons
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -20, 1, -70)
    scrollFrame.Position = UDim2.new(0, 10, 0, 60)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    scrollFrame.BorderSizePixel = 1
    scrollFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.Parent = sacFrame

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

    -- Bouton vendre 1
    local boutonVendre1 = Instance.new("TextButton")
    boutonVendre1.Name = "VendreUn"
    boutonVendre1.Size = UDim2.new(0, 80, 0, 25)
    boutonVendre1.Position = UDim2.new(1, -170, 0, 10)
    boutonVendre1.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    boutonVendre1.Text = "Vendre 1"
    boutonVendre1.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonVendre1.TextSize = 12
    boutonVendre1.Font = Enum.Font.SourceSansBold
    boutonVendre1.Parent = slotFrame

    -- Bouton vendre tout
    local boutonVendreTout = Instance.new("TextButton")
    boutonVendreTout.Name = "VendreTout"
    boutonVendreTout.Size = UDim2.new(0, 80, 0, 25)
    boutonVendreTout.Position = UDim2.new(1, -170, 0, 40)
    boutonVendreTout.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    boutonVendreTout.Text = "Vendre Tout"
    boutonVendreTout.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonVendreTout.TextSize = 12
    boutonVendreTout.Font = Enum.Font.SourceSansBold
    boutonVendreTout.Parent = slotFrame

    -- Connexions des boutons
    boutonVendre1.MouseButton1Click:Connect(function()
        vendreUnBonbonEvent:FireServer(bonbonData.nom, 1)
        wait(0.1) -- Petit délai pour que le serveur traite
        updateSacContent()
    end)

    boutonVendreTout.MouseButton1Click:Connect(function()
        vendreUnBonbonEvent:FireServer(bonbonData.nom, bonbonData.quantite)
        wait(0.1)
        updateSacContent()
    end)
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