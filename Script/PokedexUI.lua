-- PokedexUI.lua v3.0
-- Interface Pokédex moderne style "simulateur"
-- À placer dans ScreenGui

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Modules
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local RECETTES = RecipeManager.Recettes
local RARETES = RecipeManager.Raretes
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

-- Variables
local pokedexFrame = nil
local isPokedexOpen = false
local currentFilter = nil

-- Déclarations préalables
local fermerPokedex

-- Crée une carte de recette moderne
local function createRecipeCard(parent, recetteNom, recetteData, estDecouverte)
    local cardFrame = Instance.new("Frame")
    cardFrame.Name = "Card_" .. recetteNom
    cardFrame.Size = UDim2.new(1, 0, 0, 140)
    cardFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron clair
    cardFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", cardFrame)
    corner.CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke", cardFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34) -- Marron foncé
    stroke.Thickness = 4

    -- ViewportFrame pour le modèle 3D
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(0, 120, 0, 120)
    viewport.Position = UDim2.new(0, 10, 0.5, -60)
    viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
    viewport.BorderSizePixel = 0
    viewport.Parent = cardFrame
    
    local vpCorner = Instance.new("UICorner", viewport)
    vpCorner.CornerRadius = UDim.new(0, 8)
    local vpStroke = Instance.new("UIStroke", viewport)
    vpStroke.Color = Color3.fromRGB(87, 60, 34)
    vpStroke.Thickness = 3

    if estDecouverte then
        -- Modèle 3D découvert
        local candyModelsFolder = ReplicatedStorage:FindFirstChild("CandyModels")
        if candyModelsFolder then
            local candyModel = candyModelsFolder:FindFirstChild(recetteData.modele)
            if candyModel then
                UIUtils.setupViewportFrame(viewport, candyModel)
            else
                -- Fallback emoji
                local emojiLabel = Instance.new("TextLabel", viewport)
                emojiLabel.Size = UDim2.new(1, 0, 1, 0)
                emojiLabel.BackgroundTransparency = 1
                emojiLabel.Text = recetteData.emoji
                emojiLabel.TextScaled = true
                emojiLabel.Font = Enum.Font.GothamBold
            end
        end
    else
        -- Mystère
        local mysteryLabel = Instance.new("TextLabel", viewport)
        mysteryLabel.Size = UDim2.new(1, 0, 1, 0)
        mysteryLabel.BackgroundTransparency = 1
        mysteryLabel.Text = "🔒\n???"
        mysteryLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        mysteryLabel.TextSize = 32
        mysteryLabel.Font = Enum.Font.GothamBold
    end

    -- Nom de la recette
    local nomLabel = Instance.new("TextLabel")
    nomLabel.Size = UDim2.new(0.6, 0, 0, 35)
    nomLabel.Position = UDim2.new(0, 140, 0, 10)
    nomLabel.BackgroundTransparency = 1
    nomLabel.Text = estDecouverte and recetteData.nom or "Recette Mystérieuse"
    nomLabel.TextColor3 = Color3.new(1, 1, 1)
    nomLabel.TextSize = 24
    nomLabel.Font = Enum.Font.GothamBold
    nomLabel.TextXAlignment = Enum.TextXAlignment.Left
    nomLabel.Parent = cardFrame

    -- Badge de rareté
    local rareteLabel = Instance.new("TextLabel")
    rareteLabel.Size = UDim2.new(0, 120, 0, 30)
    rareteLabel.Position = UDim2.new(1, -130, 0, 10)
    rareteLabel.BackgroundColor3 = recetteData.couleurRarete
    rareteLabel.Text = recetteData.rarete
    rareteLabel.TextColor3 = Color3.new(1, 1, 1)
    rareteLabel.TextSize = 18
    rareteLabel.Font = Enum.Font.GothamBold
    rareteLabel.Parent = cardFrame
    local rCorner = Instance.new("UICorner", rareteLabel)
    rCorner.CornerRadius = UDim.new(0, 8)
    local rStroke = Instance.new("UIStroke", rareteLabel)
    rStroke.Thickness = 2
    rStroke.Color = Color3.fromHSV(0, 0, 0.2)

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(0.75, 0, 0, 25)
    descLabel.Position = UDim2.new(0, 140, 0, 50)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = estDecouverte and recetteData.description or "Une délicieuse recette attend d'être découverte..."
    descLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    descLabel.TextSize = 16
    descLabel.Font = Enum.Font.SourceSans
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = cardFrame

    if estDecouverte then
        -- Ingrédients
        local ingredientsLabel = Instance.new("TextLabel")
        ingredientsLabel.Size = UDim2.new(0.75, 0, 0, 25)
        ingredientsLabel.Position = UDim2.new(0, 140, 0, 80)
        ingredientsLabel.BackgroundTransparency = 1
        
        local ingredientsText = "Ingrédients: "
        for ingredient, quantite in pairs(recetteData.ingredients) do
            ingredientsText = ingredientsText .. ingredient .. " x" .. quantite .. "  "
        end
        
        ingredientsLabel.Text = ingredientsText
        ingredientsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        ingredientsLabel.TextSize = 14
        ingredientsLabel.Font = Enum.Font.SourceSans
        ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
        ingredientsLabel.Parent = cardFrame

        -- Stats (valeur et temps)
        local statsFrame = Instance.new("Frame")
        statsFrame.Size = UDim2.new(0.4, 0, 0, 25)
        statsFrame.Position = UDim2.new(0, 140, 1, -35)
        statsFrame.BackgroundTransparency = 1
        statsFrame.Parent = cardFrame

        local layout = Instance.new("UIListLayout", statsFrame)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 20)

        -- Valeur
        local valeurLabel = Instance.new("TextLabel")
        valeurLabel.Size = UDim2.new(0, 100, 1, 0)
        valeurLabel.BackgroundColor3 = Color3.fromRGB(85, 170, 85)
        valeurLabel.Text = recetteData.valeur .. "$"
        valeurLabel.TextColor3 = Color3.new(1, 1, 1)
        valeurLabel.TextSize = 16
        valeurLabel.Font = Enum.Font.GothamBold
        valeurLabel.Parent = statsFrame
        local vCorner = Instance.new("UICorner", valeurLabel)
        vCorner.CornerRadius = UDim.new(0, 6)

        -- Temps
        local tempsLabel = Instance.new("TextLabel")
        tempsLabel.Size = UDim2.new(0, 80, 1, 0)
        tempsLabel.BackgroundColor3 = Color3.fromRGB(65, 130, 200)
        tempsLabel.Text = recetteData.temps .. "s"
        tempsLabel.TextColor3 = Color3.new(1, 1, 1)
        tempsLabel.TextSize = 16
        tempsLabel.Font = Enum.Font.GothamBold
        tempsLabel.Parent = statsFrame
        local tCorner = Instance.new("UICorner", tempsLabel)
        tCorner.CornerRadius = UDim.new(0, 6)
    else
        -- Message mystère
        local mystereLabel = Instance.new("TextLabel")
        mystereLabel.Size = UDim2.new(0.4, 0, 0, 30)
        mystereLabel.Position = UDim2.new(0, 140, 1, -40)
        mystereLabel.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
        mystereLabel.Text = "À DÉCOUVRIR"
        mystereLabel.TextColor3 = Color3.new(1, 1, 1)
        mystereLabel.TextSize = 18
        mystereLabel.Font = Enum.Font.GothamBold
        mystereLabel.Parent = cardFrame
        local mCorner = Instance.new("UICorner", mystereLabel)
        mCorner.CornerRadius = UDim.new(0, 8)
    end

    return cardFrame
end

-- Met à jour le contenu du Pokédex
local function updatePokedexContent()
    if not pokedexFrame then return end

    local scrollFrame = pokedexFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end

    -- Nettoyer
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^Card_") then
            child:Destroy()
        end
    end

    -- Données du joueur
    local playerData = player:WaitForChild("PlayerData")
    local recettesDecouvertes = playerData:WaitForChild("RecettesDecouvertes")

    local recettesListe = {}

    -- Collecter et filtrer
    for nomRecette, donneesRecette in pairs(RECETTES) do
        if not currentFilter or donneesRecette.rarete == currentFilter then
            table.insert(recettesListe, {nom = nomRecette, donnees = donneesRecette})
        end
    end

    -- Trier par rareté puis par nom
    table.sort(recettesListe, function(a, b)
        local ordreA = RARETES[a.donnees.rarete].ordre
        local ordreB = RARETES[b.donnees.rarete].ordre
        if ordreA == ordreB then
            return a.nom < b.nom
        end
        return ordreA < ordreB
    end)

    -- Créer les cartes
    for i, recetteInfo in ipairs(recettesListe) do
        local estDecouverte = recettesDecouvertes:FindFirstChild(recetteInfo.nom) ~= nil
        local card = createRecipeCard(scrollFrame, recetteInfo.nom, recetteInfo.donnees, estDecouverte)
        card.LayoutOrder = i
        card.Parent = scrollFrame
    end
end

-- Crée l'interface principale du Pokédx
local function createPokedexInterface()
    if pokedexFrame then fermerPokedex() end

    isPokedexOpen = true
    pokedexFrame = Instance.new("Frame")
    pokedexFrame.Name = "PokedexFrame"
    pokedexFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
    pokedexFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    pokedexFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    pokedexFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
    pokedexFrame.BorderSizePixel = 0
    pokedexFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner", pokedexFrame)
    corner.CornerRadius = UDim.new(0, 15)
    local stroke = Instance.new("UIStroke", pokedexFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34)
    stroke.Thickness = 6

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 70)
    header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    header.BorderSizePixel = 0
    header.Parent = pokedexFrame
    local hCorner = Instance.new("UICorner", header)
    hCorner.CornerRadius = UDim.new(0, 10)
    local hStroke = Instance.new("UIStroke", header)
    hStroke.Thickness = 4
    hStroke.Color = Color3.fromRGB(66, 103, 38)

    local titre = Instance.new("TextLabel", header)
    titre.Size = UDim2.new(0.6, 0, 1, 0)
    titre.Position = UDim2.new(0.05, 0, 0, 0)
    titre.BackgroundTransparency = 1
    titre.Text = "📖 POKÉDEX DES RECETTES"
    titre.TextColor3 = Color3.new(1, 1, 1)
    titre.TextSize = 32
    titre.Font = Enum.Font.GothamBold
    titre.TextXAlignment = Enum.TextXAlignment.Left

    local boutonFermer = Instance.new("TextButton", header)
    boutonFermer.Size = UDim2.new(0, 50, 0, 50)
    boutonFermer.Position = UDim2.new(1, -60, 0.5, -25)
    boutonFermer.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    boutonFermer.Text = "X"
    boutonFermer.TextColor3 = Color3.new(1, 1, 1)
    boutonFermer.TextSize = 24
    boutonFermer.Font = Enum.Font.GothamBold
    boutonFermer.MouseButton1Click:Connect(fermerPokedex)
    local xCorner = Instance.new("UICorner", boutonFermer)
    xCorner.CornerRadius = UDim.new(0, 10)
    local xStroke = Instance.new("UIStroke", boutonFermer)
    xStroke.Thickness = 3
    xStroke.Color = Color3.fromHSV(0, 0, 0.2)

    -- Barre de filtres
    local filtresFrame = Instance.new("Frame")
    filtresFrame.Size = UDim2.new(1, -20, 0, 50)
    filtresFrame.Position = UDim2.new(0, 10, 0, 80)
    filtresFrame.BackgroundTransparency = 1
    filtresFrame.Parent = pokedexFrame

    local layout = Instance.new("UIListLayout", filtresFrame)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 15)

    -- Bouton "Toutes"
    local boutonTous = Instance.new("TextButton")
    boutonTous.Size = UDim2.new(0, 100, 0, 40)
    boutonTous.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    boutonTous.Text = "TOUTES"
    boutonTous.TextColor3 = Color3.new(1, 1, 1)
    boutonTous.TextSize = 16
    boutonTous.Font = Enum.Font.GothamBold
    boutonTous.Parent = filtresFrame
    local tCorner = Instance.new("UICorner", boutonTous)
    tCorner.CornerRadius = UDim.new(0, 8)
    local tStroke = Instance.new("UIStroke", boutonTous)
    tStroke.Thickness = 3
    tStroke.Color = Color3.fromHSV(0, 0, 0.2)

    boutonTous.MouseButton1Click:Connect(function()
        currentFilter = nil
        updatePokedexContent()
    end)

    -- Boutons de rareté
    for _, rareteInfo in pairs(RARETES) do
        local boutonRarete = Instance.new("TextButton")
        boutonRarete.Size = UDim2.new(0, 120, 0, 40)
        boutonRarete.BackgroundColor3 = rareteInfo.couleur
        boutonRarete.Text = rareteInfo.nom:upper()
        boutonRarete.TextColor3 = Color3.new(1, 1, 1)
        boutonRarete.TextSize = 14
        boutonRarete.Font = Enum.Font.GothamBold
        boutonRarete.Parent = filtresFrame
        local rCorner = Instance.new("UICorner", boutonRarete)
        rCorner.CornerRadius = UDim.new(0, 8)
        local rStroke = Instance.new("UIStroke", boutonRarete)
        rStroke.Thickness = 3
        rStroke.Color = Color3.fromHSV(0, 0, 0.2)

        boutonRarete.MouseButton1Click:Connect(function()
            currentFilter = rareteInfo.nom
            updatePokedexContent()
        end)
    end

    -- Zone de défilement
    local scrollFrame = Instance.new("ScrollingFrame", pokedexFrame)
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -20, 1, -150)
    scrollFrame.Position = UDim2.new(0, 10, 0, 140)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 12
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local sCorner = Instance.new("UICorner", scrollFrame)
    sCorner.CornerRadius = UDim.new(0, 8)

    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, 15)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Animation d'ouverture
    pokedexFrame.Size = UDim2.new(0, 0, 0, 0)
    local finalSize = UDim2.new(0.8, 0, 0.8, 0)
    local tween = TweenService:Create(pokedexFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = finalSize})
    tween:Play()

    -- Charger le contenu
    updatePokedexContent()
end

-- Fonction de fermeture
fermerPokedex = function()
    if pokedexFrame then
        local tween = TweenService:Create(pokedexFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function()
            pokedexFrame:Destroy()
            pokedexFrame = nil
            isPokedexOpen = false
        end)
    end
end

-- Fonction d'ouverture
local function ouvrirPokedex()
    if not isPokedexOpen then
        createPokedexInterface()
    end
end

-- Crée le bouton d'accès permanent
local function createPokedexButton()
    local boutonPokedex = screenGui:FindFirstChild("BoutonPokedex")
    if boutonPokedex then return end

    boutonPokedex = Instance.new("TextButton")
    boutonPokedex.Name = "BoutonPokedex"
    boutonPokedex.Size = UDim2.new(0, 80, 0, 80)
    boutonPokedex.Position = UDim2.new(0.02, 0, 0.25, 0)
    boutonPokedex.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    boutonPokedex.Text = "📖"
    boutonPokedex.TextColor3 = Color3.new(1, 1, 1)
    boutonPokedex.TextSize = 32
    boutonPokedex.Font = Enum.Font.GothamBold
    boutonPokedex.BorderSizePixel = 0
    boutonPokedex.Parent = screenGui
    
    local bCorner = Instance.new("UICorner", boutonPokedex)
    bCorner.CornerRadius = UDim.new(0, 12)
    local bStroke = Instance.new("UIStroke", boutonPokedex)
    bStroke.Color = Color3.fromRGB(66, 103, 38)
    bStroke.Thickness = 4

    -- Effet de survol
    boutonPokedex.MouseEnter:Connect(function()
        local tween = TweenService:Create(boutonPokedex, TweenInfo.new(0.2), {Size = UDim2.new(0, 85, 0, 85)})
        tween:Play()
    end)

    boutonPokedex.MouseLeave:Connect(function()
        local tween = TweenService:Create(boutonPokedex, TweenInfo.new(0.2), {Size = UDim2.new(0, 80, 0, 80)})
        tween:Play()
    end)

    -- Connexion du clic
    boutonPokedex.MouseButton1Click:Connect(function()
        if isPokedexOpen then
            fermerPokedex()
        else
            ouvrirPokedex()
        end
    end)
end

-- Initialisation
createPokedexButton()

print("✅ Pokédex v3.0 (Style Simulateur) chargé !") 