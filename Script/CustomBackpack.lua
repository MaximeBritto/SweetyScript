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

-- Dossier des modèles d'ingrédients
local ingredientToolsFolder = ReplicatedStorage:WaitForChild("IngredientTools")

-- Variables du backpack personnalisé
local customBackpack = nil
local hotbarFrame = nil
local inventoryFrame = nil
local isInventoryOpen = false
local equippedTool = nil
local selectedSlot = 1 -- Slot sélectionné dans la hotbar (1-9)

-- Liste stable des tools pour la hotbar (garde les positions)
local hotbarTools = {}

-- Désactiver le backpack par défaut de Roblox
local function disableDefaultBackpack()
    print("🚫 Désactivation du backpack par défaut...")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    print("✅ Backpack par défaut désactivé !")
end

-- Créer l'interface du backpack personnalisé
local function createCustomBackpack()
    print("🎨 Création du backpack personnalisé...")
    
    -- ScreenGui principal
    customBackpack = Instance.new("ScreenGui")
    customBackpack.Name = "CustomBackpack"
    customBackpack.ResetOnSpawn = false
    customBackpack.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    customBackpack.Parent = playerGui
    
    -- HOTBAR PERMANENTE (9 slots comme Minecraft)
    hotbarFrame = Instance.new("Frame")
    hotbarFrame.Name = "HotbarFrame"
    hotbarFrame.Size = UDim2.new(0, 450, 0, 60) -- 9 slots de 50px + espacement
    hotbarFrame.Position = UDim2.new(0.5, -225, 1, -80)
    hotbarFrame.AnchorPoint = Vector2.new(0.5, 0)
    hotbarFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron bois
    hotbarFrame.BorderSizePixel = 0
    hotbarFrame.Parent = customBackpack
    
    -- Bordures de la hotbar
    local hotbarCorner = Instance.new("UICorner", hotbarFrame)
    hotbarCorner.CornerRadius = UDim.new(0, 10)
    
    local hotbarStroke = Instance.new("UIStroke", hotbarFrame)
    hotbarStroke.Color = Color3.fromRGB(87, 60, 34)
    hotbarStroke.Thickness = 3
    
    -- Layout pour les 9 slots de la hotbar
    local hotbarLayout = Instance.new("UIListLayout")
    hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
    hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    hotbarLayout.Padding = UDim.new(0, 5)
    hotbarLayout.Parent = hotbarFrame
    
    -- Créer les 9 slots de la hotbar
    for i = 1, 9 do
        createHotbarSlot(i)
    end
    
    -- BOUTON POUR OUVRIR L'INVENTAIRE COMPLET (à droite de la hotbar)
    local inventoryButton = Instance.new("TextButton")
    inventoryButton.Name = "InventoryButton"
    inventoryButton.Size = UDim2.new(0, 45, 0, 45) -- Même taille qu'un slot de hotbar
    inventoryButton.Position = UDim2.new(0.5, 230, 1, -80) -- À droite de la hotbar
    inventoryButton.AnchorPoint = Vector2.new(0.5, 0)
    inventoryButton.BackgroundColor3 = Color3.fromRGB(180, 140, 100) -- Même couleur que les slots
    inventoryButton.BorderSizePixel = 0
    inventoryButton.Text = "↑" -- Flèche vers le haut
    inventoryButton.TextSize = 24
    inventoryButton.TextColor3 = Color3.new(1, 1, 1)
    inventoryButton.Font = Enum.Font.GothamBold
    inventoryButton.Parent = customBackpack
    
    local invCorner = Instance.new("UICorner", inventoryButton)
    invCorner.CornerRadius = UDim.new(0, 8) -- Même arrondi que les slots
    
    local invStroke = Instance.new("UIStroke", inventoryButton)
    invStroke.Color = Color3.fromRGB(87, 60, 34) -- Même bordure que les slots
    invStroke.Thickness = 2
    
    -- INVENTAIRE COMPLET (caché au début)
    inventoryFrame = Instance.new("Frame")
    inventoryFrame.Name = "InventoryFrame"
    inventoryFrame.Size = UDim2.new(0, 600, 0, 400)
    inventoryFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    inventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    inventoryFrame.BackgroundColor3 = Color3.fromRGB(212, 163, 115) -- Bois clair
    inventoryFrame.BorderSizePixel = 0
    inventoryFrame.Visible = false
    inventoryFrame.Parent = customBackpack
    
    -- Bordures de l'inventaire
    local invFrameCorner = Instance.new("UICorner", inventoryFrame)
    invFrameCorner.CornerRadius = UDim.new(0, 15)
    
    local invFrameStroke = Instance.new("UIStroke", inventoryFrame)
    invFrameStroke.Color = Color3.fromRGB(87, 60, 34)
    invFrameStroke.Thickness = 4
    
    -- Titre de l'inventaire
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 0, 40)
    titleLabel.Position = UDim2.new(0, 20, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🎒 Inventaire"
    titleLabel.TextColor3 = Color3.fromRGB(87, 60, 34)
    titleLabel.TextSize = 24
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = inventoryFrame
    
    -- Bouton fermer l'inventaire
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextSize = 18
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = inventoryFrame
    
    local closeCorner = Instance.new("UICorner", closeButton)
    closeCorner.CornerRadius = UDim.new(0, 8)
    
    -- ScrollingFrame pour tous les tools
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "AllToolsContainer"
    scrollFrame.Size = UDim2.new(1, -40, 1, -80)
    scrollFrame.Position = UDim2.new(0, 20, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 10
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = inventoryFrame
    
    -- Grid layout pour l'inventaire
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 80, 0, 80)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
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
    
    print("✅ Interface du backpack créée !")
end

-- Créer un slot de la hotbar
function createHotbarSlot(slotNumber)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "HotbarSlot_" .. slotNumber
    slotFrame.Size = UDim2.new(0, 45, 0, 45)
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
    
    -- Plus d'étiquette de quantité
    
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
            
            -- Ajouter le modèle 3D
            local ingredientModel = ingredientToolsFolder:FindFirstChild(baseName)
            if ingredientModel and ingredientModel:FindFirstChild("Handle") then
                UIUtils.setupViewportFrame(viewport, ingredientModel.Handle)
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
            
                            -- Plus d'affichage de quantité
        else
            -- Slot vide
            for _, child in pairs(viewport:GetChildren()) do
                child:Destroy()
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
    
    -- Ajouter le tool équipé s'il y en a un
    if equippedTool and equippedTool.Parent == player.Character then
        table.insert(tools, equippedTool)
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
                local baseName = (tool and tool:GetAttribute("BaseName")) or (tool and tool.Name) or "TOOL_DETRUIT"
                print("   - Retrait du slot", i, ":", baseName)
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

-- Basculer l'inventaire complet
function toggleInventory()
    isInventoryOpen = not isInventoryOpen
    
    if isInventoryOpen then
        inventoryFrame.Visible = true
        
        -- Animation d'apparition
        inventoryFrame.Size = UDim2.new(0, 0, 0, 0)
        local tween = TweenService:Create(inventoryFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 600, 0, 400)
        })
        tween:Play()
        
        -- Mettre à jour le contenu
        updateInventoryContent()
    else
        -- Animation de disparition
        local tween = TweenService:Create(inventoryFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        tween:Play()
        
        tween.Completed:Connect(function()
            inventoryFrame.Visible = false
        end)
    end
end

-- Créer un slot d'inventaire complet
local function createInventorySlot(tool, layoutOrder)
    local baseName = tool:GetAttribute("BaseName") or tool.Name
    local count = tool:FindFirstChild("Count")
    local quantity = count and count.Value or 1
    
    -- Frame du slot
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "InventorySlot_" .. tool.Name
    slotFrame.Size = UDim2.new(0, 80, 0, 80)
    slotFrame.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
    slotFrame.BorderSizePixel = 0
    slotFrame.LayoutOrder = layoutOrder
    
    local slotCorner = Instance.new("UICorner", slotFrame)
    slotCorner.CornerRadius = UDim.new(0, 8)
    
    local slotStroke = Instance.new("UIStroke", slotFrame)
    slotStroke.Color = Color3.fromRGB(87, 60, 34)
    slotStroke.Thickness = 2
    
    -- ViewportFrame pour le modèle 3D
    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, -10, 1, -20)
    viewport.Position = UDim2.new(0, 5, 0, 5)
    viewport.BackgroundTransparency = 1
    viewport.BorderSizePixel = 0
    viewport.Parent = slotFrame
    
    -- Chercher et afficher le modèle 3D
    local ingredientModel = ingredientToolsFolder:FindFirstChild(baseName)
    if ingredientModel and ingredientModel:FindFirstChild("Handle") then
        UIUtils.setupViewportFrame(viewport, ingredientModel.Handle)
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
    
    -- Plus d'étiquette de quantité dans l'inventaire
    
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

-- Mettre à jour le contenu de l'inventaire complet
function updateInventoryContent()
    if not inventoryFrame then return end
    
    local scrollFrame = inventoryFrame:FindFirstChild("AllToolsContainer")
    if not scrollFrame then return end
    
    -- Nettoyer les slots existants
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child.Name:find("InventorySlot_") then
            child:Destroy()
        end
    end
    
    -- Obtenir tous les tools disponibles
    local allTools = getBackpackTools()
    
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
        end
    end
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
        print("🎒 Tool déséquipé:", equippedTool.Name)
    end
    
    equippedTool = nil
    
    -- Mettre à jour l'affichage
    updateAllHotbarSlots()
    if isInventoryOpen then
        updateInventoryContent()
    end
end

-- Surveiller les changements dans le backpack
local function setupBackpackWatcher()
    local backpack = player:WaitForChild("Backpack")
    
    backpack.ChildAdded:Connect(function(tool)
        if tool:IsA("Tool") then
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            local count = tool:FindFirstChild("Count")
            local quantity = count and count.Value or 1
            
            print("➕ INGRÉDIENT AJOUTÉ:", tool.Name)
            print("   - BaseName:", baseName)
            print("   - Quantité:", quantity)
            print("   - Type:", tool.ClassName)
            
            -- Attendre un peu que tout se synchronise
            wait(0.2)
            
            print("🔄 Mise à jour de la hotbar après ajout...")
            updateAllHotbarSlots()
            
            if isInventoryOpen then
                updateInventoryContent()
            end
        end
    end)
    
    backpack.ChildRemoved:Connect(function(tool)
        if tool:IsA("Tool") then
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            print("➖ INGRÉDIENT RETIRÉ:", tool.Name, "BaseName:", baseName)
            
            wait(0.1)
            updateAllHotbarSlots()
            if isInventoryOpen then
                updateInventoryContent()
            end
        end
    end)
    
    -- Surveillance des changements de Count dans les tools existants
    local function watchToolCount(tool)
        local count = tool:FindFirstChild("Count")
        if count then
            print("🔍 Surveillance du Count pour", tool.Name, "- Valeur actuelle:", count.Value)
            
            count.Changed:Connect(function(newValue)
                print("📊 Quantité changée pour", tool.Name, ":", newValue)
                
                -- Si la quantité tombe à 0 ou moins, le tool va être détruit
                if newValue <= 0 then
                    print("⚠️ Tool", tool.Name, "va être détruit (quantité = 0)")
                    
                    -- Programmer un nettoyage forcé dans un court délai
                    task.spawn(function()
                        wait(0.3) -- Laisser plus de temps au tool d'être détruit
                        print("🧹 Nettoyage forcé de la hotbar après destruction du tool", tool.Name)
                        updateAllHotbarSlots()
                        if isInventoryOpen then
                            updateInventoryContent()
                        end
                    end)
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
                    print("💀 Tool", tool.Name, "a été complètement détruit (AncestryChanged)")
                    task.spawn(function()
                        wait(0.1)
                        print("🧹 Nettoyage forcé après destruction directe")
                        updateAllHotbarSlots()
                        if isInventoryOpen then
                            updateInventoryContent()
                        end
                    end)
                end
            end)
        else
            print("⚠️ Pas de Count trouvé pour", tool.Name)
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
            wait(0.1) -- Attendre que le Count soit ajouté
            watchToolCount(tool)
        end
    end)
end

-- Gestion des raccourcis clavier
local function setupHotkeys()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local keyCode = input.KeyCode
        
        -- Touches 1-9 pour sélectionner les slots de la hotbar
        if keyCode == Enum.KeyCode.One or keyCode == Enum.KeyCode.Two or keyCode == Enum.KeyCode.Three or 
           keyCode == Enum.KeyCode.Four or keyCode == Enum.KeyCode.Five or keyCode == Enum.KeyCode.Six or
           keyCode == Enum.KeyCode.Seven or keyCode == Enum.KeyCode.Eight or keyCode == Enum.KeyCode.Nine then
            
            local numbers = {
                [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
                [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
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
    print("🚀 INITIALISATION DU BACKPACK PERSONNALISÉ (STYLE MINECRAFT)")
    
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
    print("🔄 DÉTECTION INITIALE DES INGRÉDIENTS...")
    
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