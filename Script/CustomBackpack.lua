-- CustomBackpack.lua
-- Backpack personnalisé avec hotbar (style Minecraft) et modèles 3D
-- À placer dans StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Modules
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

-- Dossiers des modèles 3D
local ingredientToolsFolder = ReplicatedStorage:WaitForChild("IngredientTools")
local candyModelsFolder = ReplicatedStorage:WaitForChild("CandyModels")

-- Import du gestionnaire de tailles (si disponible)
local CandySizeManager
local success, result = pcall(function()
    return require(ReplicatedStorage:WaitForChild("CandySizeManager"))
end)
if success then
    CandySizeManager = result
end

-- Variables du backpack personnalisé
local customBackpack = nil
local hotbarFrame = nil
local inventoryFrame = nil
local isInventoryOpen = false
local equippedTool = nil
local selectedSlot = 1 -- Slot sélectionné dans la hotbar (1-9)

-- Liste stable des tools pour la hotbar (garde les positions)
local hotbarTools = {}

-- Variables globales pour détection responsive (partagées entre fonctions)
local viewportSize = workspace.CurrentCamera.ViewportSize
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- Désactiver le backpack par défaut de Roblox
local function disableDefaultBackpack()
    
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    
end

-- Créer l'interface du backpack personnalisé
local function createCustomBackpack()
    
    
    -- ScreenGui principal (configuration minimale pour éviter conflits)
    customBackpack = Instance.new("ScreenGui")
    customBackpack.Name = "CustomBackpack"
    customBackpack.ResetOnSpawn = false
    customBackpack.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    -- SUPPRESSION temporaire des propriétés qui peuvent causer des conflits
    -- customBackpack.IgnoreGuiInset = true
    -- customBackpack.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    customBackpack.Parent = playerGui
    
    -- Variables responsive déjà définies globalement
    
    -- HOTBAR PERMANENTE (9 slots comme Minecraft) - Responsive
    hotbarFrame = Instance.new("Frame")
    hotbarFrame.Name = "CustomHotbar"
    
    -- Taille responsive de la hotbar
    if isMobile or isSmallScreen then
        -- Mobile : 7 slots × 50px = 350px + padding
        hotbarFrame.Size = UDim2.new(0, 380, 0, 55)
        hotbarFrame.Position = UDim2.new(0.5, -190, 1, -65)
    else
        -- Desktop : 9 slots × 70px = 630px + padding
        hotbarFrame.Size = UDim2.new(0, 630, 0, 70)
        hotbarFrame.Position = UDim2.new(0.5, -315, 1, -80)
    end
    
    hotbarFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hotbarFrame.BorderSizePixel = 0
    hotbarFrame.Parent = customBackpack
    
    -- Bouton de vente rapide à côté de la hotbar (DÉSACTIVÉ volontairement)
    do
        local ENABLE_SELL_BUTTON = true
        if ENABLE_SELL_BUTTON then
            local sellButton = Instance.new("TextButton")
            sellButton.Name = "SellButton"
            if isMobile or isSmallScreen then
                sellButton.Size = UDim2.new(0, 50, 0, 55)
                sellButton.Position = UDim2.new(0.5, 250, 1, -65)
                sellButton.Text = "💰"
                sellButton.TextSize = 16
            else
                sellButton.Size = UDim2.new(0, 60, 0, 70)
                sellButton.Position = UDim2.new(0.5, 400, 1, -80)
                sellButton.Text = "💰\nVENTE"
                sellButton.TextSize = 12
            end
            sellButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            sellButton.BorderSizePixel = 0
            sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            sellButton.Font = Enum.Font.GothamBold
            sellButton.TextScaled = (isMobile or isSmallScreen)
            sellButton.Parent = customBackpack
            local sellCorner = Instance.new("UICorner")
            sellCorner.CornerRadius = UDim.new(0, 8)
            sellCorner.Parent = sellButton
            sellButton.MouseButton1Click:Connect(function()
                if _G.openSellMenu then _G.openSellMenu() else print("💡 Appuyez sur V pour ouvrir le menu de vente!") end
            end)
            -- Petit highlight intégré (désactivé par défaut; activé seulement via tutoriel overlay)
            local SHOW_SELL_HIGHLIGHT_ALWAYS = false
            if SHOW_SELL_HIGHLIGHT_ALWAYS then
                local baseHighlight = Instance.new("Frame")
                baseHighlight.Name = "BaseHighlight"
                baseHighlight.Size = UDim2.new(1, 12, 1, 12)
                baseHighlight.Position = UDim2.new(0, -6, 0, -6)
                baseHighlight.BackgroundColor3 = Color3.fromRGB(255, 235, 120)
                baseHighlight.BackgroundTransparency = 0.65
                baseHighlight.BorderSizePixel = 0
                baseHighlight.ZIndex = (sellButton.ZIndex or 1) + 1
                baseHighlight.Parent = sellButton
                local bhCorner = Instance.new("UICorner", baseHighlight)
                bhCorner.CornerRadius = UDim.new(0, 10)
                local bhStroke = Instance.new("UIStroke", baseHighlight)
                bhStroke.Color = Color3.fromRGB(255, 250, 160)
                bhStroke.Thickness = 3
                bhStroke.Transparency = 0.35
                TweenService:Create(baseHighlight, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                    BackgroundTransparency = 0.35,
                    Size = UDim2.new(1, 18, 1, 18),
                    Position = UDim2.new(0, -9, 0, -9)
                }):Play()
            end
            -- Exposer référence
            local uiRefs = playerGui:FindFirstChild("UIRefs")
            if not uiRefs then uiRefs = Instance.new("Folder"); uiRefs.Name = "UIRefs"; uiRefs.Parent = playerGui end
            local sellRef = uiRefs:FindFirstChild("SellButtonRef")
            if not sellRef then sellRef = Instance.new("ObjectValue"); sellRef.Name = "SellButtonRef"; sellRef.Parent = uiRefs end
            sellRef.Value = sellButton
        else
            -- Nettoyer la référence si le bouton n'existe pas
            local uiRefs = playerGui:FindFirstChild("UIRefs")
            if uiRefs then
                local ref = uiRefs:FindFirstChild("SellButtonRef")
                if ref then ref.Value = nil end
            end
        end
    end
    
-- Coins arrondis pour l'esthétique la hotbar (responsive)
    local hotbarCorner = Instance.new("UICorner", hotbarFrame)
    hotbarCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 8 or 10)
    
    local hotbarStroke = Instance.new("UIStroke", hotbarFrame)
    hotbarStroke.Color = Color3.fromRGB(87, 60, 34)
    hotbarStroke.Thickness = (isMobile or isSmallScreen) and 2 or 3
    
    -- Layout pour les slots de la hotbar (responsive)
    local hotbarLayout = Instance.new("UIListLayout")
    hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
    hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    hotbarLayout.Padding = UDim.new(0, (isMobile or isSmallScreen) and 3 or 5)
    hotbarLayout.Parent = hotbarFrame
    
    -- Créer les slots de la hotbar (toujours 9 slots, taille responsive)
    local maxSlots = 9  -- Toujours 9 slots comme demandé
    local slotSize = (isMobile or isSmallScreen) and 50 or 70
    
    for i = 1, maxSlots do
        local slotFrame = Instance.new("Frame")
        slotFrame.Name = "HotbarSlot_" .. i
        slotFrame.Size = UDim2.new(0, slotSize, 0, slotSize)  -- Taille responsive
        slotFrame.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
        slotFrame.BorderSizePixel = 0
        slotFrame.LayoutOrder = i
        slotFrame.Parent = hotbarFrame
        
        -- Coins arrondis (responsive)
        local slotCorner = Instance.new("UICorner")
        slotCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)
        slotCorner.Parent = slotFrame
        
        -- Bordure du slot (responsive)
        local slotStroke = Instance.new("UIStroke")
        slotStroke.Color = Color3.fromRGB(87, 60, 34)
        slotStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
        slotStroke.Parent = slotFrame
        
        -- ViewportFrame pour afficher le modèle 3D (responsive)
        local viewport = Instance.new("ViewportFrame")
        viewport.Name = "Viewport"
        local viewportPadding = (isMobile or isSmallScreen) and 6 or 10
        local viewportBottom = (isMobile or isSmallScreen) and 10 or 15
        viewport.Size = UDim2.new(1, -viewportPadding, 1, -viewportBottom)
        viewport.Position = UDim2.new(0, viewportPadding/2, 0, viewportPadding/2)
        viewport.BackgroundTransparency = 1
        viewport.BorderSizePixel = 0
        viewport.Parent = slotFrame
        
        -- Label pour la quantité (responsive)
        local countLabel = Instance.new("TextLabel")
        countLabel.Name = "CountLabel"
        local countSize = (isMobile or isSmallScreen) and 16 or 20
        local countHeight = (isMobile or isSmallScreen) and 12 or 15
        countLabel.Size = UDim2.new(0, countSize, 0, countHeight)
        countLabel.Position = UDim2.new(1, -(countSize + 2), 1, -(countHeight + 2))
        countLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        countLabel.BackgroundTransparency = 0.3
        countLabel.BorderSizePixel = 0
        countLabel.Text = ""
        countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        countLabel.TextSize = (isMobile or isSmallScreen) and 10 or 12
        countLabel.Font = Enum.Font.GothamBold
        countLabel.TextXAlignment = Enum.TextXAlignment.Center
        countLabel.TextYAlignment = Enum.TextYAlignment.Center
        countLabel.TextScaled = (isMobile or isSmallScreen)  -- Auto-resize sur mobile
        countLabel.Visible = false
        countLabel.Parent = slotFrame
        
        -- Coins arrondis pour le label (responsive)
        local countCorner = Instance.new("UICorner")
        countCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 3 or 4)
        countCorner.Parent = countLabel
        
        -- Label pour la rareté (bonbons) - responsive
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Name = "RarityLabel"
        local rarityWidth = (isMobile or isSmallScreen) and 35 or 50
        local rarityHeight = (isMobile or isSmallScreen) and 10 or 12
        rarityLabel.Size = UDim2.new(0, rarityWidth, 0, rarityHeight)
        rarityLabel.Position = UDim2.new(0, 2, 0, 2)
        rarityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        rarityLabel.BackgroundTransparency = 0.4
        rarityLabel.BorderSizePixel = 0
        rarityLabel.Text = ""
        rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        rarityLabel.TextSize = (isMobile or isSmallScreen) and 7 or 8
        rarityLabel.Font = Enum.Font.GothamBold
        rarityLabel.TextXAlignment = Enum.TextXAlignment.Center
        rarityLabel.TextYAlignment = Enum.TextYAlignment.Center
        rarityLabel.TextScaled = (isMobile or isSmallScreen)  -- Auto-resize sur mobile
        rarityLabel.Visible = false
        rarityLabel.Parent = slotFrame
        
        -- Coins arrondis pour le label de rareté (responsive)
        local rarityCorner = Instance.new("UICorner")
        rarityCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 2 or 3)
        rarityCorner.Parent = rarityLabel
        
        -- Événement de clic pour sélectionner
        slotFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                selectHotbarSlot(i)
            end
        end)
    end
    
    -- BOUTON POUR OUVRIR L'INVENTAIRE COMPLET (centré au-dessus de la hotbar) - Responsive
    local inventoryButton = Instance.new("TextButton")
    inventoryButton.Name = "InventoryButton"
    local buttonSize = (isMobile or isSmallScreen) and 40 or 45
    inventoryButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
    -- Centré au-dessus de la hotbar (offset = 0)
    local buttonY = (isMobile or isSmallScreen) and -110 or -125  -- Au-dessus de la hotbar
    inventoryButton.Position = UDim2.new(0.5, 0, 1, buttonY)  -- Centré horizontalement
    inventoryButton.AnchorPoint = Vector2.new(0.5, 0)
    inventoryButton.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
    inventoryButton.BorderSizePixel = 0
    inventoryButton.Text = "↑"
    inventoryButton.TextSize = (isMobile or isSmallScreen) and 18 or 24
    inventoryButton.TextColor3 = Color3.new(1, 1, 1)
    inventoryButton.Font = Enum.Font.GothamBold
    inventoryButton.TextScaled = (isMobile or isSmallScreen)
    inventoryButton.Parent = customBackpack
    
    local invCorner = Instance.new("UICorner", inventoryButton)
    invCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 6 or 8)
    
    local invStroke = Instance.new("UIStroke", inventoryButton)
    invStroke.Color = Color3.fromRGB(87, 60, 34)
    invStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
    
    -- INVENTAIRE COMPLET (caché au début) - Taille initiale (sera resize dynamiquement)
    inventoryFrame = Instance.new("Frame")
    inventoryFrame.Name = "InventoryFrame"
    local invWidth = (isMobile or isSmallScreen) and 500 or 600
    local invHeight = (isMobile or isSmallScreen) and 550 or 400
    inventoryFrame.Size = UDim2.new(0, invWidth, 0, invHeight)
    inventoryFrame.Position = UDim2.new(0.5, -invWidth/2, 0.5, -invHeight/2)
    inventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    inventoryFrame.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
    inventoryFrame.BorderSizePixel = 0
    inventoryFrame.Visible = false
    inventoryFrame.Parent = customBackpack
    
    -- Bordures de l'inventaire (responsive)
    local invFrameCorner = Instance.new("UICorner", inventoryFrame)
    invFrameCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 10 or 15)
    
    local invFrameStroke = Instance.new("UIStroke", inventoryFrame)
    invFrameStroke.Color = Color3.fromRGB(87, 60, 34)
    invFrameStroke.Thickness = (isMobile or isSmallScreen) and 2 or 4
    
    -- Titre de l'inventaire (responsive)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 0, (isMobile or isSmallScreen) and 30 or 40)
    titleLabel.Position = UDim2.new(0, (isMobile or isSmallScreen) and 15 or 20, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = (isMobile or isSmallScreen) and "🎒 INV" or "🎒 Inventaire"
    titleLabel.TextColor3 = Color3.fromRGB(87, 60, 34)
    titleLabel.TextSize = (isMobile or isSmallScreen) and 18 or 24
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextScaled = (isMobile or isSmallScreen)
    titleLabel.Parent = inventoryFrame
    
    -- Bouton fermer l'inventaire (responsive)
    local closeButton = Instance.new("TextButton")
    local closeSize = (isMobile or isSmallScreen) and 25 or 30
    closeButton.Size = UDim2.new(0, closeSize, 0, closeSize)
    closeButton.Position = UDim2.new(1, -(closeSize + 10), 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextSize = (isMobile or isSmallScreen) and 14 or 18
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextScaled = (isMobile or isSmallScreen)
    closeButton.Parent = inventoryFrame
    
    local closeCorner = Instance.new("UICorner", closeButton)
    closeCorner.CornerRadius = UDim.new(0, 8)
    
    -- ScrollingFrame pour tous les tools (responsive)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "AllToolsContainer"
    local scrollMargin = (isMobile or isSmallScreen) and 20 or 40
    local scrollTop = (isMobile or isSmallScreen) and 50 or 60
    scrollFrame.Size = UDim2.new(1, -scrollMargin, 1, -(scrollTop + 20))
    scrollFrame.Position = UDim2.new(0, scrollMargin/2, 0, scrollTop)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = (isMobile or isSmallScreen) and 6 or 10
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = inventoryFrame
    
    -- Grid layout pour l'inventaire (responsive)
    local gridLayout = Instance.new("UIGridLayout")
    local cellSize = (isMobile or isSmallScreen) and 60 or 80
    local cellPadding = (isMobile or isSmallScreen) and 5 or 10
    gridLayout.CellSize = UDim2.new(0, cellSize, 0, cellSize)
    gridLayout.CellPadding = UDim2.new(0, cellPadding, 0, cellPadding)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame
    
    -- Événements
    inventoryButton.MouseButton1Click:Connect(function()
        toggleInventory()
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        toggleInventory()
    end)
    
    
end

-- Créer un slot de la hotbar
local function createHotbarSlot(slotNumber)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "HotbarSlot_" .. slotNumber
    slotFrame.Size = UDim2.new(0, 70, 0, 70) -- Taille plus grosse (70px au lieu de 45px)
    slotFrame.Position = UDim2.new(0, (slotNumber - 1) * 70, 0, 0) -- Espacement ajusté
    slotFrame.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
    slotFrame.BorderSizePixel = 0
    slotFrame.LayoutOrder = slotNumber
    slotFrame.Parent = hotbarFrame
    
    local slotCorner = Instance.new("UICorner", slotFrame)
    slotCorner.CornerRadius = UDim.new(0, 8)
    
    local slotStroke = Instance.new("UIStroke", slotFrame)
    slotStroke.Color = Color3.fromRGB(87, 60, 34)
    slotStroke.Thickness = 2
    
    -- ViewportFrame pour le modèle 3D (plus grand pour les modèles)
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "Viewport"
    viewport.Size = UDim2.new(1, -4, 1, -8) -- Plus grand
    viewport.Position = UDim2.new(0, 2, 0, 2)
    viewport.BackgroundTransparency = 1
    viewport.BorderSizePixel = 0
    viewport.Parent = slotFrame
    
    -- Numéro du slot
    local numberLabel = Instance.new("TextLabel")
    numberLabel.Size = UDim2.new(0, 12, 0, 12)
    numberLabel.Position = UDim2.new(0, 2, 0, 2)
    numberLabel.BackgroundTransparency = 1
    numberLabel.Text = tostring(slotNumber)
    numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    numberLabel.TextSize = 8
    numberLabel.Font = Enum.Font.GothamBold
    numberLabel.Parent = slotFrame
    
    -- Label pour afficher la quantité
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(0, 20, 0, 12)
    countLabel.Position = UDim2.new(1, -22, 1, -14) -- Coin bas-droit
    countLabel.BackgroundTransparency = 1
    countLabel.Text = ""
    countLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Jaune pour bien voir
    countLabel.TextSize = 10
    countLabel.Font = Enum.Font.GothamBold
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    countLabel.Parent = slotFrame
    
    -- Label pour afficher la rareté/taille
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Name = "RarityLabel"
    rarityLabel.Size = UDim2.new(1, -4, 0, 10)
    rarityLabel.Position = UDim2.new(0, 2, 0, 2) -- Coin haut-gauche
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = ""
    rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    rarityLabel.TextSize = 8
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
    rarityLabel.TextStrokeTransparency = 0
    rarityLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    rarityLabel.Parent = slotFrame
    
    -- Bouton invisible pour la détection des clics
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.Parent = slotFrame
    
    -- Gestion du clic
    clickButton.MouseButton1Click:Connect(function()
        selectHotbarSlot(slotNumber)
    end)
    
    -- Effet de survol
    clickButton.MouseEnter:Connect(function()
        if selectedSlot ~= slotNumber then
            slotStroke.Color = Color3.fromRGB(255, 200, 100)
            slotStroke.Thickness = 3
        end
    end)
    
    clickButton.MouseLeave:Connect(function()
        updateHotbarSlotAppearance(slotNumber)
    end)
    
    return slotFrame
end

-- Sélectionner un slot de la hotbar
function selectHotbarSlot(slotNumber)
    selectedSlot = slotNumber
    
    -- Vérifier si le tool dans ce slot existe encore
    if hotbarTools[slotNumber] then
        local tool = hotbarTools[slotNumber]
        local toolExists = tool and tool.Parent and (tool.Parent == player.Backpack or tool.Parent == player.Character)
        local count = tool:FindFirstChild("Count")
        local quantity = count and count.Value or 0
        
        if not toolExists or quantity <= 0 then
            hotbarTools[slotNumber] = nil
            updateAllHotbarSlots()
            return
        end
        
        -- Équiper le tool correspondant
        if equippedTool == tool then
            unequipTool()
        else
            equipTool(tool)
        end
    else
        unequipTool()
    end
    
    updateAllHotbarSlots()
end

-- Mettre à jour l'apparence d'un slot de la hotbar
function updateHotbarSlotAppearance(slotNumber)
    local slotFrame = hotbarFrame:FindFirstChild("HotbarSlot_" .. slotNumber)
    if not slotFrame then return end
    
    local stroke = slotFrame:FindFirstChild("UIStroke")
    if not stroke then return end
    
    local tool = hotbarTools[slotNumber]
    local isEquipped = (tool and equippedTool == tool)
    
    if selectedSlot == slotNumber then
        -- Slot sélectionné - bordure dorée épaisse
        stroke.Color = Color3.fromRGB(255, 215, 0)
        stroke.Thickness = 4
        slotFrame.BackgroundColor3 = Color3.fromRGB(200, 160, 120)
    elseif isEquipped then
        -- Tool équipé - bordure verte luisante
        stroke.Color = Color3.fromRGB(0, 255, 100)
        stroke.Thickness = 3
        slotFrame.BackgroundColor3 = Color3.fromRGB(160, 190, 140)
    else
        -- Slot normal
        stroke.Color = Color3.fromRGB(87, 60, 34)
        stroke.Thickness = 2
        slotFrame.BackgroundColor3 = Color3.fromRGB(180, 140, 100)
    end
end

-- Mettre à jour tous les slots de la hotbar
function updateAllHotbarSlots()
    -- Vérification de la hotbarFrame
    if not hotbarFrame then
        return
    end
    
    -- Mettre à jour la liste stable des tools
    updateHotbarToolsList()
    
    -- Vérification de sécurité
    if not hotbarTools then
        return
    end
    
    for i = 1, 9 do
        local slotFrame = hotbarFrame:FindFirstChild("HotbarSlot_" .. i)
        if not slotFrame then
            continue
        end
        
        local viewport = slotFrame:FindFirstChild("Viewport")
        
        if not viewport then
            continue
        end
        
        if hotbarTools[i] then
            -- Il y a un tool pour ce slot
            local tool = hotbarTools[i]
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            local count = tool:FindFirstChild("Count")
            local quantity = count and count.Value or 1
            
            -- Nettoyer le viewport
            for _, child in pairs(viewport:GetChildren()) do
                child:Destroy()
            end
            
            -- Ajouter le modèle 3D (ingrédients OU candies)
            -- Les Tools utilisent maintenant le nom du modèle directement
            local toolModel = ingredientToolsFolder:FindFirstChild(baseName) or candyModelsFolder:FindFirstChild(tool.Name)
            if toolModel then
                -- Pour les bonbons, utiliser BonbonSkin ou Handle selon disponibilité
                local visualPart = toolModel:FindFirstChild("BonbonSkin") or toolModel:FindFirstChild("Handle")
                if visualPart then
                    UIUtils.setupViewportFrame(viewport, visualPart)
                end
            else
                -- Fallback amélioré
                local fallbackLabel = Instance.new("TextLabel")
                fallbackLabel.Size = UDim2.new(1, 0, 1, 0)
                fallbackLabel.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Fond coloré
                fallbackLabel.BackgroundTransparency = 0.3
                fallbackLabel.BorderSizePixel = 0
                fallbackLabel.Text = baseName:sub(1, 2):upper()
                fallbackLabel.TextColor3 = Color3.new(1, 1, 1)
                fallbackLabel.TextSize = 18 -- Plus gros
                fallbackLabel.Font = Enum.Font.GothamBold
                fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
                fallbackLabel.TextYAlignment = Enum.TextYAlignment.Center
                fallbackLabel.Parent = viewport
                
                -- Bordures arrondies
                local fbCorner = Instance.new("UICorner", fallbackLabel)
                fbCorner.CornerRadius = UDim.new(0, 6)
                
                -- Contour du texte
                local fbStroke = Instance.new("UIStroke", fallbackLabel)
                fbStroke.Color = Color3.fromRGB(0, 0, 0)
                fbStroke.Thickness = 2
            end
            
            -- Afficher la quantité dans le label (pour tous les cas)
            local countLabel = slotFrame:FindFirstChild("CountLabel")
            if countLabel then
                if quantity > 1 then
                    countLabel.Text = tostring(quantity)
                    countLabel.Visible = true
                else
                    countLabel.Visible = false -- Cacher si quantité = 1
                end
            end
            
            -- Afficher les infos de rareté (bonbons ET ingrédients)
            local rarityLabel = slotFrame:FindFirstChild("RarityLabel")
            if rarityLabel and tool then
                local sizeData = nil
                local rarityInfo = nil
                
                -- Pour les bonbons : utiliser CandySizeManager
                if CandySizeManager and tool:GetAttribute("IsCandy") then
                    sizeData = CandySizeManager.getSizeDataFromTool(tool)
                    if sizeData then
                        rarityInfo = {
                            text = sizeData.rarity,
                            color = sizeData.color
                        }
                    end
                end
                
                -- Pour les ingrédients : utiliser RecipeManager
                if not rarityInfo and tool:GetAttribute("BaseName") then
                    local baseName = tool:GetAttribute("BaseName")
                    -- Essayer de récupérer la rareté depuis RecipeManager
                    local recipeManager = nil
                    local success, result = pcall(function()
                        return require(ReplicatedStorage:FindFirstChild("RecipeManager"))
                    end)
                    if success and result then
                        recipeManager = result
                    end
                    
                    if recipeManager and recipeManager.Ingredients and recipeManager.Ingredients[baseName] then
                        local ingredientData = recipeManager.Ingredients[baseName]
                        rarityInfo = {
                            text = ingredientData.rarete or "Commune",
                            color = ingredientData.couleurRarete or Color3.fromRGB(150, 150, 150)
                        }
                    end
                end
                
                -- Afficher la rareté si disponible
                if rarityInfo then
                    print("📱 HOTBAR - Tool:", tool.Name, "| Rareté:", rarityInfo.text, "| Type:", tool:GetAttribute("IsCandy") and "Bonbon" or "Ingrédient")
                    rarityLabel.Text = rarityInfo.text
                    rarityLabel.TextColor3 = rarityInfo.color
                    rarityLabel.Visible = true
                else
                    rarityLabel.Visible = false
                    print("❌ HOTBAR - Pas de données de rareté pour:", tool.Name, "| IsCandy:", tool:GetAttribute("IsCandy"), "| BaseName:", tool:GetAttribute("BaseName"))
                end
            elseif rarityLabel then
                rarityLabel.Visible = false
            end
        else
            -- Slot vide
            for _, child in pairs(viewport:GetChildren()) do
                child:Destroy()
            end
            
            -- Cacher les labels pour les slots vides
            local countLabel = slotFrame:FindFirstChild("CountLabel")
            if countLabel then
                countLabel.Visible = false
            end
            
            local rarityLabel = slotFrame:FindFirstChild("RarityLabel")
            if rarityLabel then
                rarityLabel.Visible = false
            end
        end
        
        updateHotbarSlotAppearance(i)
    end
end

-- Obtenir la liste des tools du backpack + équipé
function getBackpackTools()
    local tools = {}
    
    -- Ajouter les tools du backpack
    for _, tool in pairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(tools, tool)
        end
    end
    
    -- 🔧 CORRECTION: Ajouter TOUS les tools équipés dans le character (plus fiable)
    if player.Character then
        for _, tool in pairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(tools, tool)
                print("🔍 Tool équipé détecté:", tool:GetAttribute("BaseName") or tool.Name)
            end
        end
    end
    
    return tools
end

-- Mettre à jour la liste stable de la hotbar
function updateHotbarToolsList()
    local allTools = getBackpackTools()
    
    -- Conserver les tools existants à leur position
    for i = 1, 9 do
        if hotbarTools[i] then
            local toolStillExists = false
            local tool = hotbarTools[i]
            
            -- Vérification STRICTE : le tool doit encore exister ET avoir un parent valide
            if tool and tool.Parent and (tool.Parent == player.Backpack or tool.Parent == player.Character) then
                -- Vérifier aussi que le Count est valide (> 0)
                local count = tool:FindFirstChild("Count")
                local quantity = count and count.Value or 1
                
                if quantity > 0 then
                    -- Vérifier qu'il est dans la liste des tools actifs
                    for _, activeTool in pairs(allTools) do
                        if activeTool == tool then
                            toolStillExists = true
                            break
                        end
                    end
                else
                end
            end
            
            -- Si le tool n'existe plus, le retirer de la hotbar
            if not toolStillExists then
                hotbarTools[i] = nil
            end
        end
    end
    
    -- Ajouter les nouveaux tools aux slots libres
    for _, tool in pairs(allTools) do
        local alreadyInHotbar = false
        for i = 1, 9 do
            if hotbarTools[i] == tool then
                alreadyInHotbar = true
                break
            end
        end
        
        -- Si le tool n'est pas encore dans la hotbar, l'ajouter au premier slot libre
        if not alreadyInHotbar then
            for i = 1, 9 do
                if not hotbarTools[i] then
                    hotbarTools[i] = tool
                    break
                end
            end
        end
    end
end

-- Basculer l'inventaire complet (responsive)
function toggleInventory()
    isInventoryOpen = not isInventoryOpen
    
    if isInventoryOpen then
        inventoryFrame.Visible = true
        
        -- S'assurer que le masque est visible aussi
        if inventoryFrame.Parent and inventoryFrame.Parent.Name == "InventoryMask" then
            inventoryFrame.Parent.Visible = true
        end
        
        -- RECALCULER la détection de plateforme à chaque ouverture
        local currentViewportSize = workspace.CurrentCamera.ViewportSize
        local currentIsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        local currentIsSmallScreen = currentViewportSize.X < 800 or currentViewportSize.Y < 600
        
        -- Calculer les dimensions de l'inventaire avec effet masque
        local targetWidth = (currentIsMobile or currentIsSmallScreen) and math.min(currentViewportSize.X * 0.85, 420) or 500
        local targetHeight = (currentIsMobile or currentIsSmallScreen) and math.min(currentViewportSize.Y * 0.6, 350) or 400
        
        -- Position du masque aligné avec la hotbar (même rail)
        local hotbarY = (currentIsMobile or currentIsSmallScreen) and -65 or -80
        local maskY = hotbarY - targetHeight - 5  -- 5px au-dessus de la hotbar
        
        -- Alignement horizontal avec la hotbar (même rail)
        local hotbarX = (currentIsMobile or currentIsSmallScreen) and -190 or -315  -- Même position X que la hotbar
        
        -- Créer/mettre à jour le ClipFrame (masque) aligné avec la hotbar
        if not inventoryFrame.Parent or inventoryFrame.Parent.Name ~= "InventoryMask" then
            local maskFrame = Instance.new("Frame")
            maskFrame.Name = "InventoryMask"
            maskFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
            maskFrame.Position = UDim2.new(0.5, hotbarX, 1, maskY)  -- Même rail que hotbar
            maskFrame.AnchorPoint = Vector2.new(0, 0)
            maskFrame.BackgroundTransparency = 1  -- Invisible, juste pour le clipping
            maskFrame.ClipsDescendants = true  -- EFFET MASQUE !
            maskFrame.Parent = customBackpack
            
            -- Reparenter l'inventaire dans le masque
            inventoryFrame.Parent = maskFrame
        else
            -- Mettre à jour la position du masque existant
            local maskFrame = inventoryFrame.Parent
            maskFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
            maskFrame.Position = UDim2.new(0.5, hotbarX, 1, maskY)  -- Même rail que hotbar
        end
        
        -- Position de l'inventaire DANS le masque : caché en BAS (inversé !)
        inventoryFrame.Size = UDim2.new(0, targetWidth, 0, targetHeight)
        inventoryFrame.Position = UDim2.new(0, 0, 0, targetHeight)  -- Caché en-dessous du masque
        inventoryFrame.AnchorPoint = Vector2.new(0, 0)
        
        print("📦 INVENTAIRE TIROIR - Écran:", currentViewportSize.X .. "x" .. currentViewportSize.Y)
        print("📦 INVENTAIRE TIROIR - Taille:", targetWidth .. "x" .. targetHeight)
        print("📦 INVENTAIRE TIROIR - Masque Y:", maskY, "| Hotbar X:", hotbarX)
        
        -- Animation de coulissement vertical (de BAS en HAUT dans le masque) INVERSÉE !
        local tween = TweenService:Create(inventoryFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)  -- Glisse depuis le bas vers la position visible
        })
        tween:Play()
        
        -- Mettre à jour le contenu
        updateInventoryContent()
    else
        -- Animation de coulissement vers le bas (disparition dans le masque) INVERSÉE !
        local tween = TweenService:Create(inventoryFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 0, 0, inventoryFrame.Size.Y.Offset)  -- Glisse vers le bas du masque
        })
        tween:Play()
        
        tween.Completed:Connect(function()
            inventoryFrame.Visible = false
            -- Optionnel : cacher aussi le masque
            if inventoryFrame.Parent and inventoryFrame.Parent.Name == "InventoryMask" then
                inventoryFrame.Parent.Visible = false
            end
        end)
    end
end

-- Créer un slot d'inventaire complet (responsive)
local function createInventorySlot(tool, layoutOrder)
    local baseName = tool:GetAttribute("BaseName") or tool.Name
    local count = tool:FindFirstChild("Count")
    local quantity = count and count.Value or 1
    
    -- Frame du slot (responsive - taille synchronisée avec le grid layout)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "InventorySlot_" .. tool.Name
    local slotSize = (isMobile or isSmallScreen) and 60 or 80  -- Même taille que le grid layout
    slotFrame.Size = UDim2.new(0, slotSize, 0, slotSize)  -- Mais le grid layout remplacera cette taille
    slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
    slotFrame.BorderSizePixel = 0
    slotFrame.LayoutOrder = layoutOrder
    
    local slotCorner = Instance.new("UICorner", slotFrame)
    slotCorner.CornerRadius = UDim.new(0, 8)
    
    local slotStroke = Instance.new("UIStroke", slotFrame)
    slotStroke.Color = Color3.fromRGB(87, 60, 34)
    slotStroke.Thickness = 2
    
    -- ViewportFrame pour le modèle 3D (responsive)
    local viewport = Instance.new("ViewportFrame")
    local vpMargin = (isMobile or isSmallScreen) and 6 or 10
    local vpBottomMargin = (isMobile or isSmallScreen) and 12 or 20  -- Plus d'espace pour le texte sur mobile
    viewport.Size = UDim2.new(1, -vpMargin, 1, -vpBottomMargin)
    viewport.Position = UDim2.new(0, vpMargin/2, 0, vpMargin/2)
    viewport.BackgroundTransparency = 1
    viewport.BorderSizePixel = 0
    viewport.Parent = slotFrame
    
    -- Chercher et afficher le modèle 3D (ingrédients OU candies)
    -- Les Tools utilisent maintenant le nom du modèle directement
    local toolModel = ingredientToolsFolder:FindFirstChild(baseName) or candyModelsFolder:FindFirstChild(tool.Name)
    if toolModel then
        -- Pour les bonbons, utiliser BonbonSkin ou Handle selon disponibilité
        local visualPart = toolModel:FindFirstChild("BonbonSkin") or toolModel:FindFirstChild("Handle")
        if visualPart then
            UIUtils.setupViewportFrame(viewport, visualPart)
        else
            -- Fallback amélioré pour l'inventaire
            local fallbackLabel = Instance.new("TextLabel")
            fallbackLabel.Size = UDim2.new(1, 0, 1, 0)
            fallbackLabel.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Fond coloré
            fallbackLabel.BackgroundTransparency = 0.3
            fallbackLabel.BorderSizePixel = 0
            fallbackLabel.Text = baseName:sub(1, 2):upper()
            fallbackLabel.TextColor3 = Color3.new(1, 1, 1)
            fallbackLabel.TextSize = 20 -- Plus gros pour l'inventaire
            fallbackLabel.Font = Enum.Font.GothamBold
            fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
            fallbackLabel.TextYAlignment = Enum.TextYAlignment.Center
            fallbackLabel.Parent = viewport
            
            -- Bordures arrondies
            local fbCorner = Instance.new("UICorner", fallbackLabel)
            fbCorner.CornerRadius = UDim.new(0, 8)
            
            -- Contour du texte
            local fbStroke = Instance.new("UIStroke", fallbackLabel)
            fbStroke.Color = Color3.fromRGB(0, 0, 0)
            fbStroke.Thickness = 2
        end
    else
        -- Fallback amélioré pour l'inventaire
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Size = UDim2.new(1, 0, 1, 0)
        fallbackLabel.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Fond coloré
        fallbackLabel.BackgroundTransparency = 0.3
        fallbackLabel.BorderSizePixel = 0
        fallbackLabel.Text = baseName:sub(1, 2):upper()
        fallbackLabel.TextColor3 = Color3.new(1, 1, 1)
        fallbackLabel.TextSize = 20 -- Plus gros pour l'inventaire
        fallbackLabel.Font = Enum.Font.GothamBold
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Center
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Center
        fallbackLabel.Parent = viewport
        
        -- Bordures arrondies
        local fbCorner = Instance.new("UICorner", fallbackLabel)
        fbCorner.CornerRadius = UDim.new(0, 8)
        
        -- Contour du texte
        local fbStroke = Instance.new("UIStroke", fallbackLabel)
        fbStroke.Color = Color3.fromRGB(0, 0, 0)
        fbStroke.Thickness = 2
    end
    
    -- Label de quantité responsive dans l'inventaire
    if quantity > 1 then
        local quantityLabel = Instance.new("TextLabel")
        quantityLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
        quantityLabel.Position = UDim2.new(0.4, 0, 0.7, 0)
        quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        quantityLabel.BackgroundTransparency = (isMobile or isSmallScreen) and 0.3 or 0.4
        quantityLabel.BorderSizePixel = 0
        quantityLabel.Text = tostring(quantity)
        quantityLabel.TextColor3 = Color3.new(1, 1, 1)
        quantityLabel.TextSize = (isMobile or isSmallScreen) and 10 or 12
        quantityLabel.Font = Enum.Font.GothamBold
        quantityLabel.TextXAlignment = Enum.TextXAlignment.Center
        quantityLabel.TextYAlignment = Enum.TextYAlignment.Center
        quantityLabel.TextScaled = (isMobile or isSmallScreen)
        quantityLabel.Parent = slotFrame
        
        local qCorner = Instance.new("UICorner", quantityLabel)
        qCorner.CornerRadius = UDim.new(0, (isMobile or isSmallScreen) and 4 or 6)
        
        local qStroke = Instance.new("UIStroke", quantityLabel)
        qStroke.Color = Color3.fromRGB(87, 60, 34)
        qStroke.Thickness = (isMobile or isSmallScreen) and 1 or 2
    end
    
    -- Bouton invisible pour la détection des clics
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.Parent = slotFrame
    
    -- Gestion du clic (équiper/déséquiper)
    clickButton.MouseButton1Click:Connect(function()
        if equippedTool == tool then
            unequipTool()
        else
            equipTool(tool)
        end
    end)
    
    return slotFrame
end

-- Mettre à jour le contenu de l'inventaire complet (avec debug)
function updateInventoryContent()
    if not inventoryFrame then 
        print("❌ Inventaire: inventoryFrame manquant")
        return 
    end
    
    local scrollFrame = inventoryFrame:FindFirstChild("AllToolsContainer")
    if not scrollFrame then 
        print("❌ Inventaire: scrollFrame manquant")
        return 
    end
    
    -- Nettoyer les slots existants
    local cleanedCount = 0
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child.Name:find("InventorySlot_") then
            child:Destroy()
            cleanedCount = cleanedCount + 1
        end
    end
    
    -- Obtenir tous les tools disponibles
    local allTools = getBackpackTools()
    print("📦 Inventaire: ", #allTools, "tools totaux,", cleanedCount, "slots nettoyés")
    
    -- Créer les nouveaux slots SEULEMENT pour les tools qui ne sont PAS dans la hotbar
    local layoutOrder = 0
    for _, tool in pairs(allTools) do
        local isInHotbar = false
        
        -- Vérifier si ce tool est déjà dans la hotbar (slots 1-9)
        for i = 1, 9 do
            if hotbarTools[i] == tool then
                isInHotbar = true
                break
            end
        end
        
        -- Si le tool n'est pas dans la hotbar, l'afficher dans l'inventaire complet
        if not isInHotbar then
            layoutOrder = layoutOrder + 1
            local slot = createInventorySlot(tool, layoutOrder)
            slot.Parent = scrollFrame
            print("✅ Slot créé pour:", tool.Name, "(ordre:", layoutOrder, ")")
        else
            print("⏭️ Tool déjà dans hotbar:", tool.Name)
        end
    end
    print("🏁 Inventaire: ", layoutOrder, "slots créés au total")
end

-- Équiper un tool
function equipTool(tool)
    if equippedTool then
        unequipTool()
    end
    
    equippedTool = tool
    tool.Parent = player.Character
    
    -- Mettre à jour l'affichage
    updateAllHotbarSlots()
    if isInventoryOpen then
        updateInventoryContent()
    end
end

-- Déséquiper le tool actuel
function unequipTool()
    if equippedTool and equippedTool.Parent == player.Character then
        equippedTool.Parent = player.Backpack
        
    end
    
    equippedTool = nil
    
    -- Mettre à jour l'affichage
    updateAllHotbarSlots()
    if isInventoryOpen then
        updateInventoryContent()
    end
end

-- Surveiller les changements dans le backpack ET character
local function setupBackpackWatcher()
    local backpack = player:WaitForChild("Backpack")
    
    backpack.ChildAdded:Connect(function(tool)
        if tool:IsA("Tool") then
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            local count = tool:FindFirstChild("Count")
            local quantity = count and count.Value or 1
            
            -- Si ce tool était équipé et revient dans le backpack, mettre à jour equippedTool
            if equippedTool == tool then
                print("🔄 Tool revenu dans backpack:", baseName)
                equippedTool = nil
            end
            
            -- Mise à jour immédiate sans délai
            updateAllHotbarSlots()
            
            if isInventoryOpen then
                updateInventoryContent()
            end
        end
    end)
    
    backpack.ChildRemoved:Connect(function(tool)
        if tool:IsA("Tool") then
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            
            -- Mise à jour immédiate
            updateAllHotbarSlots()
            if isInventoryOpen then
                updateInventoryContent()
            end
        end
    end)
    
    -- 🔧 NOUVEAU: Surveiller les changements dans le Character pour synchroniser equippedTool
    local function setupCharacterWatcher(character)
        if not character then return end
        
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                local baseName = child:GetAttribute("BaseName") or child.Name
                print("🎯 Tool équipé par Roblox:", baseName)
                equippedTool = child
                
                -- Mettre à jour l'affichage
                updateAllHotbarSlots()
                if isInventoryOpen then
                    updateInventoryContent()
                end
            end
        end)
        
        character.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") and equippedTool == child then
                local baseName = child:GetAttribute("BaseName") or child.Name
                print("🎯 Tool déséquipé par Roblox:", baseName)
                equippedTool = nil
                
                -- Mettre à jour l'affichage
                updateAllHotbarSlots()
                if isInventoryOpen then
                    updateInventoryContent()
                end
            end
        end)
    end
    
    -- Surveiller le character actuel et futurs
    if player.Character then
        setupCharacterWatcher(player.Character)
    end
    player.CharacterAdded:Connect(setupCharacterWatcher)
    
    -- Surveillance des changements de Count dans les tools existants
    local function watchToolCount(tool)
        local count = tool:FindFirstChild("Count")
        if count then
            
            
            count.Changed:Connect(function(newValue)
                
                
                -- Si la quantité tombe à 0 ou moins, le tool va être détruit
                if newValue <= 0 then
                    
                    
                    -- Programmer un nettoyage forcé dans un court délai
                    updateAllHotbarSlots()
                    if isInventoryOpen then
                        updateInventoryContent()
                    end
                end
                
                -- Mise à jour immédiate normale
                updateAllHotbarSlots()
                if isInventoryOpen then
                    updateInventoryContent()
                end
            end)
            
            -- Surveiller aussi la destruction directe du tool
            tool.AncestryChanged:Connect(function()
                if tool.Parent == nil then
                    updateAllHotbarSlots()
                    if isInventoryOpen then
                        updateInventoryContent()
                    end
                end
            end)
        else
            
        end
    end
    
    -- Surveiller les tools déjà présents
    for _, existingTool in pairs(backpack:GetChildren()) do
        if existingTool:IsA("Tool") then
            watchToolCount(existingTool)
        end
    end
    
    -- Surveiller les nouveaux tools pour leurs changements de Count
    backpack.ChildAdded:Connect(function(tool)
        if tool:IsA("Tool") then
            -- Tentative sans délai; si Count manque, on mettra à jour sur le prochain Changed
            watchToolCount(tool)
        end
    end)
end

-- Gestion des raccourcis clavier - REACTIVÉ
local function setupHotkeys()
    print("🎮 Gestionnaire clavier REACTIVÉ - Navigation hotbar 1-6 disponible")
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        -- Vérifier que le jeu n'a pas déjà traité l'input ET que c'est bien un clavier
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        
        -- Vérifier qu'aucun chat/GUI modal n'est actif
        if UserInputService:GetFocusedTextBox() then return end
        
        local keyCode = input.KeyCode
        
        -- Touches 1-6 pour sélectionner les slots de la hotbar (focus sur 1-6)
        if keyCode == Enum.KeyCode.One or keyCode == Enum.KeyCode.Two or keyCode == Enum.KeyCode.Three or 
           keyCode == Enum.KeyCode.Four or keyCode == Enum.KeyCode.Five or keyCode == Enum.KeyCode.Six then
            
            local numbers = {
                [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
                [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6
            }
            
            local slotNumber = numbers[keyCode]
            print("🎮 [HOTBAR] Sélection slot", slotNumber)
            selectHotbarSlot(slotNumber)
            
        -- Touches 7-9 pour d'autres slots si nécessaire
        elseif keyCode == Enum.KeyCode.Seven or keyCode == Enum.KeyCode.Eight or keyCode == Enum.KeyCode.Nine then
            local numbers = {
                [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9
            }
            
            local slotNumber = numbers[keyCode]
            selectHotbarSlot(slotNumber)
        end
        
        -- Touche TAB pour ouvrir/fermer l'inventaire complet
        if keyCode == Enum.KeyCode.Tab then
            toggleInventory()
        end
    end)
end

-- Initialisation
local function initialize()
    
    
    -- Attendre que le joueur soit chargé
    player.CharacterAdded:Wait()
    wait(2) -- Laisser le temps à tout de se charger
    
    -- Désactiver le backpack par défaut
    disableDefaultBackpack()
    
    -- Créer le backpack personnalisé
    createCustomBackpack()
    
    -- Configurer la surveillance
    setupBackpackWatcher()
    setupHotkeys()
    
    -- Mise à jour initiale avec debug
    
    
    -- Forcer la détection immédiate des tools existants
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        print("📦 Backpack trouvé, scan des tools existants...")
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = tool:GetAttribute("BaseName") or tool.Name
                local count = tool:FindFirstChild("Count")
                local quantity = count and count.Value or 1
                print("   🔍 Tool existant détecté:", baseName, "Quantité:", quantity)
            end
        end
    end
    
    updateAllHotbarSlots()
    
    -- Nettoyage périodique pour éliminer les tools fantômes
    task.spawn(function()
        while true do
            wait(2) -- Vérifier toutes les 2 secondes
            
            local needsUpdate = false
            for i = 1, 9 do
                if hotbarTools[i] then
                    local tool = hotbarTools[i]
                    local toolExists = tool and tool.Parent and (tool.Parent == player.Backpack or tool.Parent == player.Character)
                    local count = tool:FindFirstChild("Count")
                    local quantity = count and count.Value or 0
                    
                    if not toolExists or quantity <= 0 then
                        print("🔧 NETTOYAGE PÉRIODIQUE: Suppression du tool fantôme", tool and tool.Name or "INCONNU", "du slot", i)
                        hotbarTools[i] = nil
                        needsUpdate = true
                    end
                end
            end
            
            if needsUpdate then
                print("🔄 Mise à jour après nettoyage périodique")
                updateAllHotbarSlots()
                if isInventoryOpen then
                    updateInventoryContent()
                end
            end
        end
    end)
    
    print("✅ BACKPACK PERSONNALISÉ PRÊT !")
    print("💡 Hotbar permanente en bas avec 9 slots")
    print("💡 Touches 1-9 pour sélectionner les slots")
    print("💡 Touche TAB pour ouvrir l'inventaire complet")
    print("💡 Bouton ↑ pour ouvrir l'inventaire complet")
    print("🧹 Nettoyage automatique activé toutes les 2 secondes")
end

-- Démarrage
initialize() 