-- Ce script (local) gère le menu d'achat d'ingrédients responsive.
-- Version 3.0 : Refonte visuelle inspirée du style "simulateur" avec adaptation mobile.
-- À placer dans une ScreenGui dans StarterGui.

local player = game:GetService("Players").LocalPlayer
local _playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Détection plateforme pour interface responsive (mobile = tactile uniquement)
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Modules
local RecipeManager do
    local modInst = ReplicatedStorage:FindFirstChild("RecipeManager")
    if modInst and modInst:IsA("ModuleScript") then
        local ok, mod = pcall(require, modInst)
        if ok and type(mod) == "table" then
            RecipeManager = mod
        else
            RecipeManager = { Ingredients = {}, IngredientOrder = {} }
        end
    else
        RecipeManager = { Ingredients = {}, IngredientOrder = {} }
    end
end

local UIUtils do
    local modInst = ReplicatedStorage:FindFirstChild("UIUtils")
    if modInst and modInst:IsA("ModuleScript") then
        local ok, mod = pcall(require, modInst)
        if ok and type(mod) == "table" then
            UIUtils = mod
        else
            UIUtils = nil
        end
    else
        UIUtils = nil
    end
end

-- Dossier de stock partagé
local shopStockFolder = ReplicatedStorage:WaitForChild("ShopStock")

-- RemoteEvents
local ouvrirMenuEvent = ReplicatedStorage:WaitForChild("OuvrirMenuEvent")
local achatIngredientEvent = ReplicatedStorage:WaitForChild("AchatIngredientEvent_V2")
local forceRestockEvent = ReplicatedStorage:WaitForChild("ForceRestockEvent")
-- Temporaire: pas de GetMoneyFunction pour éviter les erreurs
-- local getMoneyFunction = ReplicatedStorage:WaitForChild("GetMoneyFunction")

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

    -- Utiliser leaderstats.Argent (se réplique automatiquement du serveur)
    local leaderstats = player:FindFirstChild("leaderstats")
    local currentMoney = leaderstats and leaderstats:FindFirstChild("Argent") and leaderstats.Argent.Value or 0
    local canAfford = currentMoney >= ingredientData.prix
    print("💰 [BOUTIQUE] Argent leaderstats:", currentMoney, "| Prix:", ingredientData.prix, "| Peut acheter:", canAfford)
    
    local buttonContainer = slot:FindFirstChild("ButtonContainer", true)
    local noStockLabel = slot:FindFirstChild("NoStockLabel", true)
    local acheterUnBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterUnBtn")
    local acheterCinqBtn = buttonContainer and buttonContainer:FindFirstChild("AcheterCinqBtn")

    if not (buttonContainer and noStockLabel and acheterUnBtn and acheterCinqBtn) then return end

    local hasStock = stockActuel > 0
    buttonContainer.Visible = hasStock
    noStockLabel.Visible = not hasStock

    if hasStock then
        -- Gérer le bouton "Acheter 1" (utiliser leaderstats)
        local canAfford1 = currentMoney >= ingredientData.prix
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


-- Crée un slot d'ingrédient (responsive)
local function createIngredientSlot(parent, ingredientNom, ingredientData)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = ingredientNom
    
    -- Hauteur responsive (grand changement mobile: cartes plus compactes)
    local slotHeight = (isMobile or isSmallScreen) and 72 or 120
    slotFrame.Size = UDim2.new(1, 0, 0, slotHeight)
    slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
    slotFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", slotFrame)
    corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)
    
    local stroke = Instance.new("UIStroke", slotFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34)
    stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3

    local viewport = Instance.new("ViewportFrame")
    -- Viewport responsive (réduit sur mobile)
    local vpSize = (isMobile or isSmallScreen) and 48 or 100
    viewport.Size = UDim2.new(0, vpSize, 0, vpSize)
    viewport.Position = UDim2.new(0, 10, 0.5, -(vpSize/2))
    viewport.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
    viewport.BorderSizePixel = 0
    viewport.Parent = slotFrame
    
    local vpCorner = Instance.new("UICorner", viewport)
    vpCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 6)
    
    local vpStroke = Instance.new("UIStroke", viewport)
    vpStroke.Color = Color3.fromRGB(87, 60, 34)
    vpStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
    
    local ingredientToolFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
    local ingredientTool = ingredientToolFolder and ingredientToolFolder:FindFirstChild(ingredientNom)
    if UIUtils and ingredientTool and ingredientTool:FindFirstChild("Handle") then
        UIUtils.setupViewportFrame(viewport, ingredientTool.Handle)
    end

    local nomLabel = Instance.new("TextLabel")
    local labelStartX = vpSize + 20
    nomLabel.Size = UDim2.new(0.5, 0, 0, (isMobile or isSmallScreen) and 20 or 30)
    nomLabel.Position = UDim2.new(0, labelStartX, 0, (isMobile or isSmallScreen) and 5 or 10)
    nomLabel.BackgroundTransparency = 1
    nomLabel.Text = ingredientData.nom
    nomLabel.TextColor3 = Color3.new(1,1,1)
    nomLabel.TextSize = (isMobile or isSmallScreen) and 16 or 28
    nomLabel.Font = Enum.Font.GothamBold
    nomLabel.TextXAlignment = Enum.TextXAlignment.Left
    nomLabel.TextScaled = (isMobile or isSmallScreen)
    nomLabel.Parent = slotFrame

    local stockLabel = Instance.new("TextLabel")
    stockLabel.Name = "StockLabel"
    stockLabel.Size = UDim2.new(0.4, 0, 0, (isMobile or isSmallScreen) and 16 or 25)
    stockLabel.Position = UDim2.new(0, labelStartX + 5, 0, (isMobile or isSmallScreen) and 25 or 40)
    stockLabel.BackgroundTransparency = 1
    stockLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
    stockLabel.TextSize = (isMobile or isSmallScreen) and 12 or 22
    stockLabel.Font = Enum.Font.GothamBold
    stockLabel.TextXAlignment = Enum.TextXAlignment.Left
    stockLabel.TextScaled = (isMobile or isSmallScreen)
    stockLabel.Parent = slotFrame

    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "PriceLabel"
    priceLabel.Size = UDim2.new(0.3, 0, 0, (isMobile or isSmallScreen) and 18 or 30)
    priceLabel.Position = UDim2.new(0, labelStartX + 5, 0, (isMobile or isSmallScreen) and 45 or 70)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = (isMobile or isSmallScreen) and (ingredientData.prix .. "$") or ("Prix: " .. ingredientData.prix .. "$")
    priceLabel.TextColor3 = Color3.fromRGB(130, 255, 130)
    priceLabel.TextSize = (isMobile or isSmallScreen) and 12 or 22
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.TextScaled = (isMobile or isSmallScreen)
    priceLabel.Parent = slotFrame
    
    local rareteLabel = Instance.new("TextLabel")
    local rareteWidth = (isMobile or isSmallScreen) and 60 or 100
    local rareteHeight = (isMobile or isSmallScreen) and 16 or 25
    rareteLabel.Size = UDim2.new(0, rareteWidth, 0, rareteHeight)
    rareteLabel.Position = UDim2.new(1, -(rareteWidth + 10), 0, (isMobile or isSmallScreen) and 5 or 10)
    rareteLabel.BackgroundColor3 = ingredientData.couleurRarete
    rareteLabel.Text = ingredientData.rarete
    rareteLabel.TextColor3 = Color3.new(1,1,1)
    rareteLabel.TextSize = (isMobile or isSmallScreen) and 10 or 16
    rareteLabel.Font = Enum.Font.SourceSansBold
    rareteLabel.TextScaled = (isMobile or isSmallScreen)
    rareteLabel.Parent = slotFrame
    
    local rCorner = Instance.new("UICorner", rareteLabel)
    rCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 6)
    
    local rStroke = Instance.new("UIStroke", rareteLabel)
    rStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
    rStroke.Color = Color3.fromHSV(0,0,0.2)

    -- Conteneur pour les boutons
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(0.42, 0, 0.28, 0)
    buttonContainer.Position = UDim2.new(1, -20, 1, -15)
    buttonContainer.AnchorPoint = Vector2.new(1, 1)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = slotFrame
    
    local layout = Instance.new("UIListLayout", buttonContainer)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 6 or 10)

    -- Bouton "Acheter 5"
    local acheterCinqBtn = Instance.new("TextButton")
    acheterCinqBtn.Name = "AcheterCinqBtn"
    acheterCinqBtn.LayoutOrder = 1
    acheterCinqBtn.Size = UDim2.new(0.48, 0, 1, 0)
    acheterCinqBtn.Text = "ACHETER x5"
    acheterCinqBtn.Font = Enum.Font.GothamBold
    acheterCinqBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
    acheterCinqBtn.TextColor3 = Color3.new(1,1,1)
    acheterCinqBtn.BackgroundColor3 = Color3.fromRGB(65, 130, 200) -- Bleu
    acheterCinqBtn.Parent = buttonContainer
    local b5Corner = Instance.new("UICorner", acheterCinqBtn); b5Corner.CornerRadius = UDim.new(0, 8)
    local b5Stroke = Instance.new("UIStroke", acheterCinqBtn); b5Stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; b5Stroke.Color = Color3.fromHSV(0,0,0.2)
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
    acheterUnBtn.TextSize = (isMobile or isSmallScreen) and 12 or 16
    acheterUnBtn.TextColor3 = Color3.new(1,1,1)
    acheterUnBtn.BackgroundColor3 = Color3.fromRGB(85, 170, 85) -- Vert
    acheterUnBtn.Parent = buttonContainer
    local b1Corner = Instance.new("UICorner", acheterUnBtn); b1Corner.CornerRadius = UDim.new(0, 8)
    local b1Stroke = Instance.new("UIStroke", acheterUnBtn); b1Stroke.Thickness = (isMobile or isSmallScreen) and 2 or 3; b1Stroke.Color = Color3.fromHSV(0,0,0.2)
    acheterUnBtn.MouseButton1Click:Connect(function() 
        if acheterUnBtn.Active then achatIngredientEvent:FireServer(ingredientNom, 1) end
    end)
    
    local noStockLabel = Instance.new("TextLabel")
    noStockLabel.Name = "NoStockLabel"
    noStockLabel.Size = UDim2.new(0.42, 0, 0.30, 0)
    noStockLabel.Position = UDim2.new(1, -20, 1, -15)
    noStockLabel.AnchorPoint = Vector2.new(1, 1)
    noStockLabel.Text = "RUPTURE DE STOCK"
    noStockLabel.Font = Enum.Font.GothamBold
    noStockLabel.TextSize = (isMobile or isSmallScreen) and 12 or 18
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

-- Création du menu principal (responsive)
local function createMenuAchat()
    if menuFrame then fermerMenu() end

    isMenuOpen = true
    menuFrame = Instance.new("Frame")
    menuFrame.Name = "MenuAchat"
    
    -- Taille et position responsives
    if isMobile or isSmallScreen then
        -- Grand changement mobile: menu plus grand
        menuFrame.Size = UDim2.new(1, -12, 0.92, 0)
        menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    else
        menuFrame.Size = UDim2.new(0.6, 0, 0.7, 0)
        menuFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
    
    menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    menuFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
    menuFrame.BorderSizePixel = 0
    menuFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner", menuFrame)
    corner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 16 or 12)
    
    local stroke = Instance.new("UIStroke", menuFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34)
    stroke.Thickness = (isMobile or isSmallScreen) and 3 or 5

    -- Header (responsive)
    local header = Instance.new("Frame")
    local headerHeight = (isMobile or isSmallScreen) and 40 or 60
    header.Size = UDim2.new(1, 0, 0, headerHeight)
    header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    header.BorderSizePixel = 0
    header.Parent = menuFrame
    
    local hCorner = Instance.new("UICorner", header)
    hCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 12 or 8)
    
    local hStroke = Instance.new("UIStroke", header)
    hStroke.Thickness = (isMobile or isSmallScreen) and 2 or 4
    hStroke.Color = Color3.fromRGB(66, 103, 38)
    
    local timerLabel = Instance.new("TextLabel", header)
    timerLabel.Name = "TimerLabel"
    timerLabel.Size = UDim2.new((isMobile or isSmallScreen) and 0.6 or 0.5, 0, 1, 0)
    timerLabel.Position = UDim2.new(0.05, 0, 0, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = (isMobile or isSmallScreen) and 14 or 24
    timerLabel.TextColor3 = Color3.new(1,1,1)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left
    timerLabel.TextScaled = (isMobile or isSmallScreen)

    local boutonFermer = Instance.new("TextButton", header)
    local closeSize = (isMobile or isSmallScreen) and 40 or 40
    boutonFermer.Size = UDim2.new(0, closeSize, 0, closeSize)
    boutonFermer.Position = UDim2.new(1, -(closeSize + 10), 0.5, -(closeSize/2))
    boutonFermer.BackgroundColor3 = Color3.fromRGB(200,50,50)
    boutonFermer.Text = "X"
    boutonFermer.TextColor3 = Color3.new(1,1,1)
    boutonFermer.TextSize = (isMobile or isSmallScreen) and 24 or 22
    boutonFermer.Font = Enum.Font.GothamBold
    boutonFermer.MouseButton1Click:Connect(fermerMenu)
    
    local xCorner = Instance.new("UICorner", boutonFermer)
    xCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)
    
    local xStroke = Instance.new("UIStroke", boutonFermer)
    xStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
    xStroke.Color = Color3.fromHSV(0,0,0.2)
    
    local boutonRestock = Instance.new("TextButton", header)
    local restockWidth = (isMobile or isSmallScreen) and 72 or 120
    local restockHeight = (isMobile or isSmallScreen) and 30 or 40
    boutonRestock.Size = UDim2.new(0, restockWidth, 0, restockHeight)
    boutonRestock.Position = UDim2.new(1, -(restockWidth + closeSize + 20), 0.5, -(restockHeight/2))
    boutonRestock.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
    boutonRestock.Text = (isMobile or isSmallScreen) and "STOCK" or "RESTOCK"
    boutonRestock.TextColor3 = Color3.new(1,1,1)
    boutonRestock.TextSize = (isMobile or isSmallScreen) and 12 or 18
    boutonRestock.Font = Enum.Font.GothamBold
    boutonRestock.TextScaled = (isMobile or isSmallScreen)
    boutonRestock.MouseButton1Click:Connect(function() forceRestockEvent:FireServer() end)
    
    local reCorner = Instance.new("UICorner", boutonRestock)
    reCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 8)
    
    local reStroke = Instance.new("UIStroke", boutonRestock)
    reStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
    reStroke.Color = Color3.fromHSV(0,0,0.2)


    local restockTimeValue = shopStockFolder:WaitForChild("RestockTime")
    local function updateTimer() timerLabel.Text = "Nouveau stock dans " .. formatTime(restockTimeValue.Value) end
    table.insert(connections, restockTimeValue.Changed:Connect(updateTimer))
    updateTimer()

    -- Scrolling Frame (responsive)
    local scrollFrame = Instance.new("ScrollingFrame", menuFrame)
    local scrollMargin = (isMobile or isSmallScreen) and 6 or 20
    local scrollTopOffset = headerHeight + ((isMobile or isSmallScreen) and 8 or 10)
    scrollFrame.Size = UDim2.new(1, -scrollMargin, 1, -(scrollTopOffset + ((isMobile or isSmallScreen) and 8 or 10)))
    scrollFrame.Position = UDim2.new(0, scrollMargin/2, 0, scrollTopOffset)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = (isMobile or isSmallScreen) and 5 or 10
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    -- Coins arrondis sur mobile
    if isMobile or isSmallScreen then
        local scrollCorner = Instance.new("UICorner", scrollFrame)
        scrollCorner.CornerRadius = UDim.new(0, 8)
    end
    
    local listLayout = Instance.new("UIListLayout", scrollFrame)
    listLayout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 8 or 10)
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
    
    -- Animation d'ouverture (responsive)
    menuFrame.Size = UDim2.new(0,0,0,0)
    
    local finalSize
    if isMobile or isSmallScreen then
        finalSize = UDim2.new(1, -12, 0.92, 0)
    else
        finalSize = UDim2.new(0.6, 0, 0.7, 0)
    end
    
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