-- Ce script (local) gère le menu d'achat d'ingrédients.
-- Version 3.0 : Refonte visuelle inspirée du style "simulateur".
-- À placer dans une ScreenGui dans StarterGui.

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Modules
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

-- Dossier de stock partagé
local shopStockFolder = ReplicatedStorage:WaitForChild("ShopStock")

-- RemoteEvents
local ouvrirMenuEvent = ReplicatedStorage:WaitForChild("OuvrirMenuEvent")
local achatIngredientEvent = ReplicatedStorage:WaitForChild("AchatIngredientEvent_V2")
local forceRestockEvent = ReplicatedStorage:WaitForChild("ForceRestockEvent")

-- Variables du menu
local menuFrame = nil
local isMenuOpen = false
local connections = {}

-- Déclaration préalable
local fermerMenu

-- Formater le temps
local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", minutes, secs)
end

-- Met à jour un slot d'ingrédient
local function updateIngredientSlot(slot, stockActuel)
    local ingredientNom = slot.Name
    local ingredientData = RecipeManager.Ingredients[ingredientNom]
    if not ingredientData then return end
    
    local stockLabel = slot:FindFirstChild("StockLabel", true)
    if stockLabel then
        stockLabel.Text = "x" .. stockActuel .. " en Stock"
    end

    local canAfford = player.PlayerData.Argent.Value >= ingredientData.prix
    
    local buttonContainer = slot:FindFirstChild("ButtonContainer", true)
    local noStockLabel = slot:FindFirstChild("NoStockLabel", true)
    local acheterUnBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterUnBtn")
    local acheterCinqBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterCinqBtn")

    if not (buttonContainer and noStockLabel and acheterUnBtn and acheterCinqBtn) then return end

    local hasStock = stockActuel > 0
    buttonContainer.Visible = hasStock
    noStockLabel.Visible = not hasStock

    if hasStock then
        -- Gérer le bouton "Acheter 1"
        local canAfford1 = player.PlayerData.Argent.Value >= ingredientData.prix
        acheterUnBtn.Active = canAfford1
        acheterUnBtn.BackgroundColor3 = canAfford1 and Color3.fromRGB(85, 170, 85) or Color3.fromRGB(150, 80, 80)
        acheterUnBtn.Text = canAfford1 and "ACHETER" or "TROP CHER"
        
        -- Gérer le bouton "Acheter 5"
        local canAfford5 = player.PlayerData.Argent.Value >= (ingredientData.prix * 5)
        local hasEnoughStock5 = stockActuel >= 5
        acheterCinqBtn.Active = canAfford5 and hasEnoughStock5
        acheterCinqBtn.Visible = hasEnoughStock5
        
        if hasEnoughStock5 then
             acheterCinqBtn.BackgroundColor3 = canAfford5 and Color3.fromRGB(65, 130, 200) or Color3.fromRGB(150, 80, 80)
             acheterCinqBtn.Text = canAfford5 and "ACHETER x5" or "TROP CHER"
        end
    end
end


-- Crée un slot d'ingrédient
local function createIngredientSlot(parent, ingredientNom, ingredientData)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = ingredientNom
    slotFrame.Size = UDim2.new(1, 0, 0, 120)
    slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron plus clair
    slotFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", slotFrame)
    corner.CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke", slotFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34) -- Marron foncé
    stroke.Thickness = 3

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(0, 100, 0, 100)
    viewport.Position = UDim2.new(0, 10, 0.5, -50)
    viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
    viewport.BorderSizePixel = 0
    viewport.Parent = slotFrame
    
    local vpCorner = Instance.new("UICorner", viewport)
    vpCorner.CornerRadius = UDim.new(0, 6)
    local vpStroke = Instance.new("UIStroke", viewport)
    vpStroke.Color = Color3.fromRGB(87, 60, 34)
    vpStroke.Thickness = 2
    
    local ingredientTool = ReplicatedStorage.IngredientTools:FindFirstChild(ingredientNom)
    if ingredientTool and ingredientTool:FindFirstChild("Handle") then
        UIUtils.setupViewportFrame(viewport, ingredientTool.Handle)
    end

    local nomLabel = Instance.new("TextLabel")
    nomLabel.Size = UDim2.new(0.5, 0, 0, 30)
    nomLabel.Position = UDim2.new(0, 120, 0, 10)
    nomLabel.BackgroundTransparency = 1
    nomLabel.Text = ingredientData.nom
    nomLabel.TextColor3 = Color3.new(1,1,1)
    nomLabel.TextSize = 28
    nomLabel.Font = Enum.Font.GothamBold
    nomLabel.TextXAlignment = Enum.TextXAlignment.Left
    nomLabel.Parent = slotFrame

    local stockLabel = Instance.new("TextLabel")
    stockLabel.Name = "StockLabel"
    stockLabel.Size = UDim2.new(0.4, 0, 0, 25)
    stockLabel.Position = UDim2.new(0, 125, 0, 40)
    stockLabel.BackgroundTransparency = 1
    stockLabel.TextColor3 = Color3.fromRGB(255, 240, 200) -- Jaune pâle pour la visibilité
    stockLabel.TextSize = 22 -- Plus grand
    stockLabel.Font = Enum.Font.GothamBold -- Plus gras
    stockLabel.TextXAlignment = Enum.TextXAlignment.Left
    stockLabel.Parent = slotFrame

    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "PriceLabel"
    priceLabel.Size = UDim2.new(0.3, 0, 0, 30)
    priceLabel.Position = UDim2.new(0, 125, 0, 70) -- Décalé vers le bas
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "Prix: " .. ingredientData.prix .. "$"
    priceLabel.TextColor3 = Color3.fromRGB(130, 255, 130) -- Vert clair
    priceLabel.TextSize = 22
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.Parent = slotFrame
    
    local rareteLabel = Instance.new("TextLabel")
    rareteLabel.Size = UDim2.new(0, 100, 0, 25)
    rareteLabel.Position = UDim2.new(1, -110, 0, 10)
    rareteLabel.BackgroundColor3 = ingredientData.couleurRarete
    rareteLabel.Text = ingredientData.rarete
    rareteLabel.TextColor3 = Color3.new(1,1,1)
    rareteLabel.TextSize = 16
    rareteLabel.Font = Enum.Font.SourceSansBold
    rareteLabel.Parent = slotFrame
    local rCorner = Instance.new("UICorner", rareteLabel); rCorner.CornerRadius = UDim.new(0, 6)
    local rStroke = Instance.new("UIStroke", rareteLabel); rStroke.Thickness = 2; rStroke.Color = Color3.fromHSV(0,0,0.2)

    -- Conteneur pour les boutons
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(0.45, 0, 0.35, 0)
    buttonContainer.Position = UDim2.new(1, -20, 1, -15)
    buttonContainer.AnchorPoint = Vector2.new(1, 1)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = slotFrame
    
    local layout = Instance.new("UIListLayout", buttonContainer)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)

    -- Bouton "Acheter 5"
    local acheterCinqBtn = Instance.new("TextButton")
    acheterCinqBtn.Name = "AcheterCinqBtn"
    acheterCinqBtn.LayoutOrder = 1
    acheterCinqBtn.Size = UDim2.new(0.48, 0, 1, 0)
    acheterCinqBtn.Text = "ACHETER x5"
    acheterCinqBtn.Font = Enum.Font.GothamBold
    acheterCinqBtn.TextSize = 16
    acheterCinqBtn.TextColor3 = Color3.new(1,1,1)
    acheterCinqBtn.BackgroundColor3 = Color3.fromRGB(65, 130, 200) -- Bleu
    acheterCinqBtn.Parent = buttonContainer
    local b5Corner = Instance.new("UICorner", acheterCinqBtn); b5Corner.CornerRadius = UDim.new(0, 8)
    local b5Stroke = Instance.new("UIStroke", acheterCinqBtn); b5Stroke.Thickness = 3; b5Stroke.Color = Color3.fromHSV(0,0,0.2)
    acheterCinqBtn.MouseButton1Click:Connect(function() 
        if acheterCinqBtn.Active then achatIngredientEvent:FireServer(ingredientNom, 5) end
    end)
    
    -- Bouton "Acheter 1"
    local acheterUnBtn = Instance.new("TextButton")
    acheterUnBtn.Name = "AcheterUnBtn"
    acheterUnBtn.LayoutOrder = 2
    acheterUnBtn.Size = UDim2.new(0.48, 0, 1, 0)
    acheterUnBtn.Text = "ACHETER"
    acheterUnBtn.Font = Enum.Font.GothamBold
    acheterUnBtn.TextSize = 16
    acheterUnBtn.TextColor3 = Color3.new(1,1,1)
    acheterUnBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 85) -- Vert
    acheterUnBtn.Parent = buttonContainer
    local b1Corner = Instance.new("UICorner", acheterUnBtn); b1Corner.CornerRadius = UDim.new(0, 8)
    local b1Stroke = Instance.new("UIStroke", acheterUnBtn); b1Stroke.Thickness = 3; b1Stroke.Color = Color3.fromHSV(0,0,0.2)
    acheterUnBtn.MouseButton1Click:Connect(function() 
        if acheterUnBtn.Active then achatIngredientEvent:FireServer(ingredientNom, 1) end
    end)
    
    local noStockLabel = Instance.new("TextLabel")
    noStockLabel.Name = "NoStockLabel"
    noStockLabel.Size = UDim2.new(0.45, 0, 0.35, 0)
    noStockLabel.Position = UDim2.new(1, -20, 1, -15)
    noStockLabel.AnchorPoint = Vector2.new(1, 1)
    noStockLabel.Text = "RUPTURE DE STOCK"
    noStockLabel.Font = Enum.Font.GothamBold
    noStockLabel.TextSize = 18
    noStockLabel.TextColor3 = Color3.new(1,1,1)
    noStockLabel.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Rouge
    noStockLabel.Visible = false
    noStockLabel.Parent = slotFrame
    local nsCorner = Instance.new("UICorner", noStockLabel); nsCorner.CornerRadius = UDim.new(0, 8)
    local nsStroke = Instance.new("UIStroke", noStockLabel); nsStroke.Thickness = 3; nsStroke.Color = Color3.fromHSV(0,0,0.2)
    
    -- Connexion au changement de stock
    local stockValue = shopStockFolder:FindFirstChild(ingredientNom)
    if stockValue then
        updateIngredientSlot(slotFrame, stockValue.Value)
        table.insert(connections, stockValue.Changed:Connect(function(newStock)
            updateIngredientSlot(slotFrame, newStock)
        end))
    end
    table.insert(connections, player.PlayerData.Argent.Changed:Connect(function()
        updateIngredientSlot(slotFrame, stockValue.Value)
    end))

    return slotFrame
end

-- Création du menu principal
local function createMenuAchat()
    if menuFrame then fermerMenu() end

    isMenuOpen = true
    menuFrame = Instance.new("Frame")
    menuFrame.Name = "MenuAchat"
    menuFrame.Size = UDim2.new(0.6, 0, 0.7, 0)
    menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    menuFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
    menuFrame.BorderSizePixel = 0
    menuFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner", menuFrame); corner.CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", menuFrame); stroke.Color = Color3.fromRGB(87, 60, 34); stroke.Thickness = 5

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    header.BorderSizePixel = 0
    header.Parent = menuFrame
    local hCorner = Instance.new("UICorner", header); hCorner.CornerRadius = UDim.new(0, 8)
    local hStroke = Instance.new("UIStroke", header); hStroke.Thickness = 4; hStroke.Color = Color3.fromRGB(66, 103, 38)
    
    local timerLabel = Instance.new("TextLabel", header)
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new(0.5, 0, 1, 0)
    timerLabel.Position = UDim2.new(0.05, 0, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 24
    timerLabel.TextColor3 = Color3.new(1,1,1)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left

    local boutonFermer = Instance.new("TextButton", header)
    boutonFermer.Size=UDim2.new(0,40,0,40); boutonFermer.Position=UDim2.new(1,-50,0.5,-20); boutonFermer.BackgroundColor3=Color3.fromRGB(200,50,50)
    boutonFermer.Text="X"; boutonFermer.TextColor3=Color3.new(1,1,1); boutonFermer.TextSize=22; boutonFermer.Font=Enum.Font.GothamBold
    boutonFermer.MouseButton1Click:Connect(fermerMenu)
    local xCorner = Instance.new("UICorner", boutonFermer); xCorner.CornerRadius = UDim.new(0, 8)
    local xStroke = Instance.new("UIStroke", boutonFermer); xStroke.Thickness = 3; xStroke.Color = Color3.fromHSV(0,0,0.2)
    
    local boutonRestock = Instance.new("TextButton", header)
    boutonRestock.Size=UDim2.new(0,120,0,40); boutonRestock.Position=UDim2.new(1,-180,0.5,-20); boutonRestock.BackgroundColor3=Color3.fromRGB(255, 220, 50)
    boutonRestock.Text="RESTOCK"; boutonRestock.TextColor3=Color3.new(1,1,1); boutonRestock.TextSize=18; boutonRestock.Font=Enum.Font.GothamBold
    boutonRestock.MouseButton1Click:Connect(function() forceRestockEvent:FireServer() end)
    local reCorner = Instance.new("UICorner", boutonRestock); reCorner.CornerRadius = UDim.new(0, 8)
    local reStroke = Instance.new("UIStroke", boutonRestock); reStroke.Thickness = 3; reStroke.Color = Color3.fromHSV(0,0,0.2)


    local restockTimeValue = shopStockFolder:WaitForChild("RestockTime")
    local function updateTimer() timerLabel.Text = "Nouveau stock dans " .. formatTime(restockTimeValue.Value) end
    table.insert(connections, restockTimeValue.Changed:Connect(updateTimer))
    updateTimer()

    -- Scrolling Frame
    local scrollFrame = Instance.new("ScrollingFrame", menuFrame)
    scrollFrame.Size=UDim2.new(1,-20,1,-80); scrollFrame.Position=UDim2.new(0,10,0,70)
    scrollFrame.BackgroundColor3=Color3.fromRGB(87, 60, 34); scrollFrame.BorderSizePixel=0
    scrollFrame.ScrollBarThickness=10
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y -- Correction pour le scrolling
    
    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Création des slots
    local ingredientOrder = RecipeManager.IngredientOrder or {}
    for i, ingredientNom in ipairs(ingredientOrder) do
        local ingredientData = RecipeManager.Ingredients[ingredientNom]
        if ingredientData then
            local slot = createIngredientSlot(scrollFrame, ingredientNom, ingredientData)
            slot.LayoutOrder = i
            slot.Parent = scrollFrame
        end
    end
    
    -- Animation d'ouverture
    menuFrame.Size = UDim2.new(0,0,0,0)
    local finalSize = UDim2.new(0.6, 0, 0.7, 0)
    local tween = TweenService:Create(menuFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = finalSize})
    tween:Play()
end

-- Fonction de fermeture
fermerMenu = function()
    if menuFrame then
        for _, conn in ipairs(connections) do conn:Disconnect() end
        connections = {}
        
        local tween = TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)})
        tween:Play()
        tween.Completed:Connect(function()
            menuFrame:Destroy()
            menuFrame = nil
            isMenuOpen = false
        end)
    end
end

-- Fonction d'ouverture
local function ouvrirMenu()
    if not isMenuOpen then
        createMenuAchat()
    end
end

-- Connexions
ouvrirMenuEvent.OnClientEvent:Connect(ouvrirMenu)

-- Connexion pour fermer le menu (pour le tutoriel)
task.spawn(function()
    -- Attendre que le TutorialManager crée l'événement
    while not ReplicatedStorage:FindFirstChild("FermerMenuEvent") do
        task.wait(0.5)
    end
    
    local fermerMenuEvent = ReplicatedStorage:FindFirstChild("FermerMenuEvent")
    if fermerMenuEvent then
        fermerMenuEvent.OnClientEvent:Connect(function()
            print("📋 [MENU ACHAT] Fermeture automatique demandée (tutoriel)")
            if isMenuOpen then
                fermerMenu()
            end
        end)
        print("✅ [MENU ACHAT] Événement fermeture tutoriel connecté")
    end
end)

print("✅ Menu d'achat v3.0 (Style Simulateur) chargé !") 