-- Ce script (local) gère l'interface de sélection de recettes responsive et le timer de production
-- À placer dans ScreenGui

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Détection plateforme pour interface responsive
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Modules
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))
local RECETTES = RecipeManager.Recettes

-- RemoteEvents
local ouvrirRecettesEvent = ReplicatedStorage:WaitForChild("OuvrirRecettesEvent")
local demarrerProductionEvent = ReplicatedStorage:WaitForChild("DemarrerProductionEvent")

-- Variables de l'interface
local recettesFrame = nil
local isRecettesOpen = false
local timerFrame = nil

-- Déclaration des fonctions locales (pour éviter les erreurs UnknownGlobal)
local createRecetteSlot
local updateRecettesContent
local fermerRecettes
local creerTimerProduction
local updateTimerProduction

-- Fonction pour fermer l'interface de recettes
fermerRecettes = function()
    if recettesFrame then
        local tween = TweenService:Create(recettesFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function()
            recettesFrame:Destroy()
            recettesFrame = nil
            isRecettesOpen = false
        end)
    end
end

-- Fonction pour mettre à jour le timer
updateTimerProduction = function()
    if not timerFrame then return end

    local playerData = player:WaitForChild("PlayerData")
    local tempsRestant = playerData:WaitForChild("TempsProductionRestant")
    local recetteEnCours = playerData:WaitForChild("RecetteEnCours")
    local enProduction = playerData:WaitForChild("EnProduction")

    if not enProduction.Value then
        -- Production terminée
        timerFrame:Destroy()
        timerFrame = nil
        return
    end

    local temps = tempsRestant.Value
    local recette = RECETTES[recetteEnCours.Value]
    
    if recette then
        local tempsTotal = recette.temps
        local progression = 1 - (temps / tempsTotal)
        
        -- Mettre à jour la barre de progression
        local remplissage = timerFrame:FindFirstChild("BarreProgress"):FindFirstChild("Remplissage")
        local texteTemps = timerFrame:FindFirstChild("TexteTemps")
        
        if remplissage and texteTemps then
            remplissage.Size = UDim2.new(progression, 0, 1, 0)
            texteTemps.Text = math.ceil(temps) .. "s restantes"
        end
    end
end

-- Fonction pour créer le timer de production
creerTimerProduction = function(tempsTotal, nomRecette)
    if timerFrame then
        timerFrame:Destroy()
    end

    if tempsTotal == 0 then return end -- Pas de timer pour les productions instantanées

    -- Frame du timer
    timerFrame = Instance.new("Frame")
    timerFrame.Name = "TimerFrame"
    timerFrame.Size = UDim2.new(0, 300, 0, 80)
    timerFrame.Position = UDim2.new(0.5, -150, 0.1, 0)
    timerFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    timerFrame.BorderSizePixel = 2
    timerFrame.BorderColor3 = Color3.fromRGB(100, 100, 255)
    timerFrame.Parent = screenGui

    -- Titre du timer
    local titreTimer = Instance.new("TextLabel")
    titreTimer.Name = "TitreTimer"
    titreTimer.Size = UDim2.new(1, 0, 0, 30)
    titreTimer.Position = UDim2.new(0, 0, 0, 0)
    titreTimer.BackgroundTransparency = 1
    titreTimer.Text = "⚗️ Production in progress: " .. nomRecette
    titreTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
    titreTimer.TextSize = 14
    titreTimer.Font = Enum.Font.SourceSansBold
    titreTimer.Parent = timerFrame

    -- Barre de progression
    local barreProgress = Instance.new("Frame")
    barreProgress.Name = "BarreProgress"
    barreProgress.Size = UDim2.new(1, -20, 0, 20)
    barreProgress.Position = UDim2.new(0, 10, 0, 35)
    barreProgress.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    barreProgress.BorderSizePixel = 1
    barreProgress.BorderColor3 = Color3.fromRGB(150, 150, 150)
    barreProgress.Parent = timerFrame

    local remplissage = Instance.new("Frame")
    remplissage.Name = "Remplissage"
    remplissage.Size = UDim2.new(0, 0, 1, 0)
    remplissage.Position = UDim2.new(0, 0, 0, 0)
    remplissage.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    remplissage.BorderSizePixel = 0
    remplissage.Parent = barreProgress

    -- Texte du temps
    local texteTemps = Instance.new("TextLabel")
    texteTemps.Name = "TexteTemps"
    texteTemps.Size = UDim2.new(1, 0, 0, 20)
    texteTemps.Position = UDim2.new(0, 0, 0, 55)
    texteTemps.BackgroundTransparency = 1
    texteTemps.Text = tempsTotal .. "s restantes"
    texteTemps.TextColor3 = Color3.fromRGB(255, 255, 255)
    texteTemps.TextSize = 12
    texteTemps.Font = Enum.Font.SourceSans
    texteTemps.Parent = timerFrame

    -- Animation du timer
    updateTimerProduction()
end

-- Fonction pour créer un slot de recette
createRecetteSlot = function(parent, recetteNom, recetteData, yPos)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "Slot_" .. recetteNom
    slotFrame.Size = UDim2.new(1, -20, 0, 110)
    slotFrame.Position = UDim2.new(0, 10, 0, yPos)
    slotFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    slotFrame.BorderSizePixel = 2
    slotFrame.BorderColor3 = Color3.fromRGB(120, 120, 120)
    slotFrame.Parent = parent

    -- Emoji de la recette
    local emoji = Instance.new("TextLabel")
    emoji.Name = "Emoji"
    emoji.Size = UDim2.new(0, 60, 0, 60)
    emoji.Position = UDim2.new(0, 10, 0, 10)
    emoji.BackgroundTransparency = 1
    emoji.Text = recetteData.emoji
    emoji.TextSize = 40
    emoji.Parent = slotFrame

    -- Nom et description
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(0, 200, 0, 60)
    infoLabel.Position = UDim2.new(0, 80, 0, 10)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = recetteData.nom .. "\n" .. recetteData.description .. "\nValeur: " .. recetteData.valeur .. "$ • Temps: " .. recetteData.temps .. "s"
    infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoLabel.TextSize = 12
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.Parent = slotFrame

    -- Zone des ingrédients requis avec modèles 3D
    local ingredientsFrame = Instance.new("Frame")
    ingredientsFrame.Name = "IngredientsFrame"
    ingredientsFrame.Size = UDim2.new(0, 280, 0, 50)
    ingredientsFrame.Position = UDim2.new(0, 80, 0, 70)
    ingredientsFrame.BackgroundTransparency = 1
    ingredientsFrame.Parent = slotFrame
    
    -- Label "Requis:"
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 60, 0, 20)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Requis:"
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = ingredientsFrame
    
    -- Conteneur pour les icônes d'ingrédients
    local iconsContainer = Instance.new("Frame")
    iconsContainer.Size = UDim2.new(1, -60, 1, -20)
    iconsContainer.Position = UDim2.new(0, 65, 0, 20)
    iconsContainer.BackgroundTransparency = 1
    iconsContainer.Parent = ingredientsFrame
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = iconsContainer
    
    -- Créer une icône pour chaque ingrédient requis
    local iconIndex = 0
    for ingredientNom, quantite in pairs(recetteData.ingredients) do
        -- Frame conteneur pour l'icône + quantité
        local ingredientContainer = Instance.new("Frame")
        ingredientContainer.Size = UDim2.new(0, 40, 0, 30)
        ingredientContainer.BackgroundTransparency = 1
        ingredientContainer.LayoutOrder = iconIndex
        ingredientContainer.Parent = iconsContainer
        
        -- ViewportFrame avec modèle 3D
        local viewport = UIUtils.createIngredientIcon(ingredientContainer, ingredientNom, UDim2.new(0, 24, 0, 24), UDim2.new(0, 8, 0, 0))
        
        -- Label de quantité
        local quantityLabel = Instance.new("TextLabel")
        quantityLabel.Size = UDim2.new(0, 40, 0, 15)
        quantityLabel.Position = UDim2.new(0, 0, 1, -15)
        quantityLabel.BackgroundTransparency = 1
        quantityLabel.Text = "x" .. quantite
        quantityLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        quantityLabel.TextSize = 12
        quantityLabel.Font = Enum.Font.GothamBold
        quantityLabel.TextXAlignment = Enum.TextXAlignment.Center
        quantityLabel.Parent = ingredientContainer
        
        iconIndex = iconIndex + 1
    end

    -- Vérifier si on a assez d'ingrédients (dynamiquement)
    local peutProduire = true
    local playerData = player:WaitForChild("PlayerData")
    
    for ingredientNom, quantiteRequise in pairs(recetteData.ingredients) do
        local ingredientValue = playerData:FindFirstChild(ingredientNom)
        local quantiteDisponible = ingredientValue and ingredientValue.Value or 0
        
        if quantiteRequise > quantiteDisponible then
            peutProduire = false
            break
        end
    end

    -- Bouton de production
    local boutonProduire = Instance.new("TextButton")
    boutonProduire.Name = "BoutonProduire"
    boutonProduire.Size = UDim2.new(0, 120, 0, 40)
    boutonProduire.Position = UDim2.new(1, -140, 0, 35)
    
    if peutProduire then
        boutonProduire.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        boutonProduire.Text = "Produire"
    else
        boutonProduire.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        boutonProduire.Text = "Ingrédients manquants"
    end
    
    boutonProduire.TextColor3 = Color3.fromRGB(255, 255, 255)
    boutonProduire.TextSize = 12
    boutonProduire.Font = Enum.Font.SourceSansBold
    boutonProduire.Parent = slotFrame

    -- Connexion du bouton
    if peutProduire then
        boutonProduire.MouseButton1Click:Connect(function()
            demarrerProductionEvent:FireServer(recetteNom)
            -- Ne pas fermer l'interface automatiquement pour permettre plusieurs productions
            creerTimerProduction(recetteData.temps, recetteData.nom)
            -- Mettre à jour le contenu pour refléter les nouveaux ingrédients
            wait(0.1) -- Petit délai pour que le serveur traite
            updateRecettesContent()
        end)
    end
end

-- Fonction pour mettre à jour le contenu des recettes
updateRecettesContent = function()
    if not recettesFrame then return end

    local scrollFrame = recettesFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end

    -- Nettoyer le contenu existant
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    -- Récupérer les données du joueur
    local playerData = player:WaitForChild("PlayerData")
    local recettesDecouvertes = playerData:WaitForChild("RecettesDecouvertes")

    local yPosition = 0

    -- Créer les slots de recettes
    for recetteNom, recetteData in pairs(RECETTES) do
        -- Vérifier si la recette est découverte
        local estDecouverte = recettesDecouvertes:FindFirstChild(recetteNom)
        if estDecouverte and estDecouverte.Value then
            createRecetteSlot(scrollFrame, recetteNom, recetteData, yPosition)
            yPosition = yPosition + 120
        end
    end

    -- Ajuster la taille du ScrollFrame
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition)

    -- Message si aucune recette
    if yPosition == 0 then
        local messageVide = Instance.new("TextLabel")
        messageVide.Name = "MessageVide"
        messageVide.Size = UDim2.new(1, -20, 0, 50)
        messageVide.Position = UDim2.new(0, 10, 0, 10)
        messageVide.BackgroundTransparency = 1
        messageVide.Text = "Aucune recette découverte ! Produisez des bonbons pour débloquer de nouvelles recettes !"
        messageVide.TextColor3 = Color3.fromRGB(200, 200, 200)
        messageVide.TextSize = 16
        messageVide.Font = Enum.Font.SourceSansItalic
        messageVide.TextWrapped = true
        messageVide.Parent = scrollFrame
    end
end

-- Fonction pour créer l'interface de sélection de recettes (responsive)
local function createRecettesInterface()
    if recettesFrame then
        recettesFrame:Destroy()
    end

    -- Frame principale (responsive)
    recettesFrame = Instance.new("Frame")
    recettesFrame.Name = "RecettesFrame"
    
    -- Taille et position responsives
    if isMobile or isSmallScreen then
        recettesFrame.Size = UDim2.new(0.95, 0, 0.8, 0)  -- 95% largeur, 80% hauteur sur mobile
        recettesFrame.Position = UDim2.new(0.025, 0, 0.1, 0)  -- Centré sur mobile
    else
        recettesFrame.Size = UDim2.new(0, 600, 0, 450)
        recettesFrame.Position = UDim2.new(0.5, -300, 0.5, -225)
    end
    
    recettesFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    recettesFrame.BorderSizePixel = (isMobile or isSmallScreen) and 2 or 3
    recettesFrame.BorderColor3 = Color3.fromRGB(100, 100, 255)
    recettesFrame.Parent = screenGui
    
    -- Coins arrondis sur mobile
    if isMobile or isSmallScreen then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = recettesFrame
    end

    -- Titre (responsive)
    local titre = Instance.new("TextLabel")
    titre.Name = "Titre"
    
    local titleHeight = (isMobile or isSmallScreen) and 40 or 50
    titre.Size = UDim2.new(1, 0, 0, titleHeight)
    titre.Position = UDim2.new(0, 0, 0, 0)
    titre.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    titre.Text = (isMobile or isSmallScreen) and "⚗️ RECETTES" or "⚗️ Sélection de Recette"
    titre.TextColor3 = Color3.fromRGB(255, 255, 255)
    titre.TextSize = (isMobile or isSmallScreen) and 16 or 20
    titre.Font = Enum.Font.SourceSansBold
    titre.TextScaled = (isMobile or isSmallScreen)
    titre.Parent = recettesFrame
    
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
    boutonFermer.Parent = recettesFrame
    
    -- Coins arrondis du bouton fermer sur mobile
    if isMobile or isSmallScreen then
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 8)
        closeCorner.Parent = boutonFermer
    end

    -- Zone de défilement pour les recettes (responsive)
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
    scrollFrame.Parent = recettesFrame
    
    -- Coins arrondis de la zone de scroll sur mobile
    if isMobile or isSmallScreen then
        local scrollCorner = Instance.new("UICorner")
        scrollCorner.CornerRadius = UDim.new(0, 8)
        scrollCorner.Parent = scrollFrame
    end

    -- Connexion du bouton de fermeture
    boutonFermer.MouseButton1Click:Connect(function()
        fermerRecettes()
    end)

    -- Animation d'ouverture (responsive)
    recettesFrame.Size = UDim2.new(0, 0, 0, 0)
    
    local targetSize
    if isMobile or isSmallScreen then
        targetSize = UDim2.new(0.95, 0, 0.8, 0)
    else
        targetSize = UDim2.new(0, 600, 0, 450)
    end
    
    local tween = TweenService:Create(recettesFrame, TweenInfo.new(0.3), {Size = targetSize})
    tween:Play()

    -- Mettre à jour le contenu
    updateRecettesContent()
end

-- Fonction pour ouvrir l'interface de recettes
local function ouvrirRecettes()
    if not isRecettesOpen then
        isRecettesOpen = true
        createRecettesInterface()
    end
end

-- Connexion aux événements
ouvrirRecettesEvent.OnClientEvent:Connect(ouvrirRecettes)

-- Mettre à jour l'interface des recettes quand les ingrédients changent
local function setupIngredientListeners()
    local playerData = player:WaitForChild("PlayerData")
    local sucre = playerData:WaitForChild("Sucre")
    local sirop = playerData:WaitForChild("Sirop")
    local aromefruit = playerData:WaitForChild("AromeFruit")
    
    -- Mettre à jour l'interface quand les ingrédients changent
    sucre.Changed:Connect(function()
        if isRecettesOpen then
            updateRecettesContent()
        end
    end)
    
    sirop.Changed:Connect(function()
        if isRecettesOpen then
            updateRecettesContent()
        end
    end)
    
    aromefruit.Changed:Connect(function()
        if isRecettesOpen then
            updateRecettesContent()
        end
    end)
end

-- Initialiser les listeners
setupIngredientListeners()

-- Boucle de mise à jour du timer
RunService.Heartbeat:Connect(function()
    if timerFrame then
        updateTimerProduction()
    end
end) 