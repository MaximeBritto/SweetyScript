-- IncubatorMenuClient.lua v4.0 - Système de slots avec crafting automatique
-- Interface Incubateur avec 5 slots d'entrée + 1 slot de sortie

----------------------------------------------------------------------
-- SERVICES & MODULES
----------------------------------------------------------------------
local plr = game:GetService("Players").LocalPlayer
local rep = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

print("🔍 IncubatorMenuClient v4.0 - Système de slots - Début du chargement")

-- RemoteEvents avec gestion d'erreurs
print("📡 Recherche des RemoteEvents...")

local openEvt = rep:WaitForChild("OpenIncubatorMenu")
print("✅ OpenIncubatorMenu trouvé")

local placeIngredientEvt = rep:WaitForChild("PlaceIngredientInSlot", 10)
if not placeIngredientEvt then
    warn("❌ PlaceIngredientInSlot non trouvé!")
    return
end
print("✅ PlaceIngredientInSlot trouvé")

local removeIngredientEvt = rep:WaitForChild("RemoveIngredientFromSlot", 10)
if not removeIngredientEvt then
    warn("❌ RemoveIngredientFromSlot non trouvé!")
    return
end
print("✅ RemoveIngredientFromSlot trouvé")

local startCraftingEvt = rep:WaitForChild("StartCrafting", 10)
if not startCraftingEvt then
    warn("❌ StartCrafting non trouvé!")
    return
end
print("✅ StartCrafting trouvé")

local getSlotsEvt = rep:WaitForChild("GetIncubatorSlots", 10)
if not getSlotsEvt then
    warn("❌ GetIncubatorSlots non trouvé!")
    return
end
print("✅ GetIncubatorSlots trouvé")

local guiParent = plr:WaitForChild("PlayerGui")

print("✅ Tous les RemoteEvents trouvés et connectés")

----------------------------------------------------------------------
-- VARIABLES GLOBALES
----------------------------------------------------------------------
local gui = nil
local currentIncID = nil
local slots = {nil, nil, nil, nil, nil} -- 5 slots d'entrée
local currentRecipe = nil
local isMenuOpen = false

----------------------------------------------------------------------
-- FONCTIONS UTILITAIRES
----------------------------------------------------------------------

-- Variables pour le drag and drop (style Minecraft)
local draggedItem = nil
local dragFrame = nil
local cursorFollowConnection = nil

-- Déclarations forward des fonctions
local updateOutputSlot = nil

local function getAvailableIngredients()
    -- Récupère les ingrédients disponibles dans l'inventaire du joueur
    local ingredients = {}
    local backpack = plr:FindFirstChildOfClass("Backpack")
    local character = plr.Character
    
    -- Vérifier les outils équipés
    if character then
        for _, tool in pairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = tool:GetAttribute("BaseName")
                if baseName then
                    local count = tool:FindFirstChild("Count")
                    if count and count.Value > 0 then
                        ingredients[baseName] = (ingredients[baseName] or 0) + count.Value
                    end
                end
            end
        end
    end
    
    -- Vérifier le sac
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = tool:GetAttribute("BaseName")
                if baseName then
                    local count = tool:FindFirstChild("Count")
                    if count and count.Value > 0 then
                        ingredients[baseName] = (ingredients[baseName] or 0) + count.Value
                    end
                end
            end
        end
    end
    
    return ingredients
end

-- Fonction pour créer un élément d'inventaire (style Minecraft)
local function createInventoryItem(parent, ingredientName, quantity)
    local ingredientIcons = {
        Sucre = "🍬",
        Sirop = "🍯",
        Lait = "🥛",
        Fraise = "🍓",
        Vanille = "🍦",
        Chocolat = "🍫",
        Noisette = "🌰"
    }
    
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = "InventoryItem_" .. ingredientName
    itemFrame.Size = UDim2.new(0, 90, 1, -10)
    itemFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = parent
    
    local itemCorner = Instance.new("UICorner", itemFrame)
    itemCorner.CornerRadius = UDim.new(0, 8)
    local itemStroke = Instance.new("UIStroke", itemFrame)
    itemStroke.Color = Color3.fromRGB(87, 60, 34)
    itemStroke.Thickness = 2
    
    -- Icône de l'ingrédient
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 0.6, 0)
    iconLabel.Position = UDim2.new(0, 0, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = ingredientIcons[ingredientName] or "📦"
    iconLabel.TextColor3 = Color3.new(1, 1, 1)
    iconLabel.TextSize = 28
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.Parent = itemFrame
    
    -- Label du nom et quantité
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = ingredientName .. "\n" .. quantity
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextScaled = true
    nameLabel.Parent = itemFrame
    
    -- Bouton invisible pour les interactions
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.Parent = itemFrame
    
    -- Événements style Minecraft
    clickButton.MouseButton1Click:Connect(function()
        -- Clic gauche = prendre tout le stack
        pickupItem(ingredientName, quantity)
    end)
    
    clickButton.MouseButton2Click:Connect(function()
        -- Clic droit = prendre un par un
        pickupItem(ingredientName, 1)
    end)
    
    -- Effet de survol
    clickButton.MouseEnter:Connect(function()
        local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 150, 100)})
        tween:Play()
    end)
    
    clickButton.MouseLeave:Connect(function()
        local tween = TweenService:Create(itemFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(184, 133, 88)})
        tween:Play()
    end)
    
    return itemFrame
end

-- Fonction pour prendre un objet de l'inventaire (style Minecraft)
function pickupItem(ingredientName, quantityToTake)
    if draggedItem then
        -- Si on a déjà quelque chose en main, essayer de le placer
        return
    end
    
    -- Vérifier qu'on a assez d'ingrédients
    local availableIngredients = getAvailableIngredients()
    local availableQuantity = availableIngredients[ingredientName] or 0
    
    if availableQuantity <= 0 then return end
    
    -- Prendre la quantité demandée (ou ce qui est disponible)
    local actualQuantity = math.min(quantityToTake, availableQuantity)
    
    -- Créer l'objet en main
    draggedItem = {
        ingredient = ingredientName,
        quantity = actualQuantity
    }
    
    -- Créer le frame qui suit le curseur
    createCursorItem(ingredientName, actualQuantity)
    
    -- Démarrer le suivi du curseur
    startCursorFollow()
end

-- Fonction pour créer l'objet qui suit le curseur
function createCursorItem(ingredientName, quantity)
    local ingredientIcons = {
        Sucre = "🍬",
        Sirop = "🍯",
        Lait = "🥛",
        Fraise = "🍓",
        Vanille = "🍦",
        Chocolat = "🍫",
        Noisette = "🌰"
    }
    
    dragFrame = Instance.new("Frame")
    dragFrame.Name = "CursorItem"
    dragFrame.Size = UDim2.new(0, 60, 0, 60)
    dragFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
    dragFrame.BorderSizePixel = 0
    dragFrame.ZIndex = 1000
    dragFrame.Parent = gui
    
    local corner = Instance.new("UICorner", dragFrame)
    corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", dragFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34)
    stroke.Thickness = 2
    
    -- Icône
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 0.7, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = ingredientIcons[ingredientName] or "📦"
    iconLabel.TextColor3 = Color3.new(1, 1, 1)
    iconLabel.TextSize = 20
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.Parent = dragFrame
    
    -- Quantité
    local quantityLabel = Instance.new("TextLabel")
    quantityLabel.Size = UDim2.new(1, 0, 0.3, 0)
    quantityLabel.Position = UDim2.new(0, 0, 0.7, 0)
    quantityLabel.BackgroundTransparency = 1
    quantityLabel.Text = tostring(quantity)
    quantityLabel.TextColor3 = Color3.new(1, 1, 1)
    quantityLabel.TextSize = 12
    quantityLabel.Font = Enum.Font.SourceSansBold
    quantityLabel.Parent = dragFrame
end

-- Fonction pour démarrer le suivi du curseur
function startCursorFollow()
    if cursorFollowConnection then return end
    
    cursorFollowConnection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragFrame then
            local mousePos = UserInputService:GetMouseLocation()
            dragFrame.Position = UDim2.new(0, mousePos.X - 30, 0, mousePos.Y - 30)
        end
    end)
end

-- Fonction pour arrêter le suivi du curseur
function stopCursorFollow()
    if cursorFollowConnection then
        cursorFollowConnection:Disconnect()
        cursorFollowConnection = nil
    end
    
    if dragFrame then
        dragFrame:Destroy()
        dragFrame = nil
    end
    
    draggedItem = nil
end

-- Fonction pour placer l'objet dans un slot
function placeItemInSlot(slotIndex, placeAll)
    if not draggedItem then return end
    
    local quantityToPlace = placeAll and draggedItem.quantity or 1
    
    -- Envoyer au serveur
    for i = 1, quantityToPlace do
        placeIngredientEvt:FireServer(currentIncID, slotIndex, draggedItem.ingredient)
        task.wait(0.05) -- Petit délai pour éviter le spam
    end
    
    -- Mettre à jour l'objet en main
    draggedItem.quantity = draggedItem.quantity - quantityToPlace
    
    if draggedItem.quantity <= 0 then
        -- Plus rien en main
        stopCursorFollow()
    else
        -- Mettre à jour l'affichage
        if dragFrame then
            local quantityLabel = dragFrame:FindFirstChild("TextLabel")
            if quantityLabel and quantityLabel.Name ~= "TextLabel" then
                quantityLabel.Text = tostring(draggedItem.quantity)
            end
        end
    end
    
    -- Mettre à jour l'interface
    task.wait(0.2)
    local ok, serverData = pcall(function()
        return getSlotsEvt:InvokeServer(currentIncID)
    end)
    
    if ok and serverData then
        if serverData.slots then
            slots = serverData.slots
        end
    end
    
    updateSlotDisplay()
    updateOutputSlot()
    updateInventoryDisplay()
end

-- Fonction pour mettre à jour l'affichage de l'inventaire
function updateInventoryDisplay()
    if not gui then return end
    
    local mainFrame = gui:FindFirstChild("MainFrame")
    if not mainFrame then return end
    
    local inventoryArea = mainFrame:FindFirstChild("InventoryArea")
    if not inventoryArea then return end
    
    local scrollFrame = inventoryArea:FindFirstChild("ScrollingFrame")
    if not scrollFrame then return end
    
    -- Nettoyer l'inventaire existant
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child.Name:match("^InventoryItem_") then
            child:Destroy()
        end
    end
    
    -- Récupérer les ingrédients disponibles
    local availableIngredients = getAvailableIngredients()
    
    -- Créer les éléments d'inventaire
    for ingredientName, quantity in pairs(availableIngredients) do
        createInventoryItem(scrollFrame, ingredientName, quantity)
    end
end

local function calculateRecipe()
    -- Demande au serveur de calculer la recette avec les ingrédients actuels
    if not currentIncID then 
        return nil, nil 
    end
    
    local ok, result = pcall(function()
        return getSlotsEvt:InvokeServer(currentIncID)
    end)
    
    if not ok then
        warn("❌ Erreur lors de la récupération des slots:", result)
        return nil, nil
    end
    
    -- Le serveur retourne les slots et la recette possible
    if result and result.recipe then
        return result.recipe, result.recipeDef, result.quantity
    end
    
    return nil, nil, 0
end

updateOutputSlot = function()
    -- Met à jour le slot de sortie avec la recette calculée
    print("🔍 DEBUG updateOutputSlot - Début")
    
    if not gui then 
        print("❌ DEBUG updateOutputSlot - GUI non trouvé!")
        return 
    end
    
    local mainFrame = gui:FindFirstChild("MainFrame")
    if not mainFrame then 
        print("❌ DEBUG updateOutputSlot - MainFrame non trouvé!")
        return 
    end
    
    -- Le slot de sortie est dans craftingArea, pas directement dans mainFrame
    local craftingArea = mainFrame:FindFirstChild("CraftingArea")
    if not craftingArea then
        print("❌ DEBUG updateOutputSlot - CraftingArea non trouvé!")
        return
    end
    
    local outputSlot = craftingArea:FindFirstChild("OutputSlot")
    if not outputSlot then 
        print("❌ DEBUG updateOutputSlot - OutputSlot non trouvé!")
        -- Debug : Lister tous les enfants de CraftingArea
        print("🔍 DEBUG - Enfants de CraftingArea:")
        for _, child in pairs(craftingArea:GetChildren()) do
            print("  -", child.Name, ":", child.ClassName)
        end
        return 
    end
    
    print("✅ DEBUG updateOutputSlot - OutputSlot trouvé")
    
    local recipeName, recipeDef, quantity = calculateRecipe()
    currentRecipe = recipeName
    
    if recipeName and recipeDef and quantity > 0 then
        -- Afficher la recette possible
        outputSlot.BackgroundColor3 = Color3.fromRGB(85, 170, 85) -- Vert = possible
        local recipeLabel = outputSlot:FindFirstChild("RecipeLabel")
        if recipeLabel then
            if quantity > 1 then
                recipeLabel.Text = "🍬 " .. quantity .. "x " .. recipeName
            else
                recipeLabel.Text = "🍬 " .. recipeName
            end
            recipeLabel.TextColor3 = Color3.new(1, 1, 1)
        end
        
        -- Afficher l'icône si disponible
        local iconFrame = outputSlot:FindFirstChild("IconFrame")
        if iconFrame then
            iconFrame.Visible = true
            iconFrame.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
        end
        

    else
        -- Pas de recette possible
        outputSlot.BackgroundColor3 = Color3.fromRGB(139, 99, 58) -- Marron = pas possible
        local recipeLabel = outputSlot:FindFirstChild("RecipeLabel")
        if recipeLabel then
            recipeLabel.Text = "❌ Aucune recette"
            recipeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        
        local iconFrame = outputSlot:FindFirstChild("IconFrame")
        if iconFrame then
            iconFrame.Visible = false
        end
        

    end
end

----------------------------------------------------------------------
-- CRÉATION DE L'UI MODERNE AVEC SLOTS
----------------------------------------------------------------------
local function createSlotUI(parent, slotIndex, isOutputSlot)
    local slot = Instance.new("Frame")
    slot.Name = isOutputSlot and "OutputSlot" or ("InputSlot" .. slotIndex)
    slot.Size = UDim2.new(0, 80, 0, 80)
    slot.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
    slot.BorderSizePixel = 0
    slot.Parent = parent
    
    local corner = Instance.new("UICorner", slot)
    corner.CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", slot)
    stroke.Color = Color3.fromRGB(87, 60, 34)
    stroke.Thickness = 3
    
    -- Zone d'icône pour l'ingrédient
    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "IconFrame"
    iconFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
    iconFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
    iconFrame.BackgroundColor3 = Color3.fromRGB(212, 163, 115)
    iconFrame.BorderSizePixel = 0
    iconFrame.Visible = false
    iconFrame.Parent = slot
    
    local iconCorner = Instance.new("UICorner", iconFrame)
    iconCorner.CornerRadius = UDim.new(0, 5)
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = ""
    iconLabel.TextColor3 = Color3.new(1, 1, 1)
    iconLabel.TextSize = 20
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.Parent = iconFrame
    
    -- Label pour le nom de l'ingrédient/recette
    local label = Instance.new("TextLabel")
    label.Name = isOutputSlot and "RecipeLabel" or "IngredientLabel"
    label.Size = UDim2.new(1, 0, 0.3, 0)
    label.Position = UDim2.new(0, 0, 0.7, 0)
    label.BackgroundTransparency = 1
    label.Text = isOutputSlot and "Résultat" or "Vide"
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 12
    label.Font = Enum.Font.SourceSans
    label.TextScaled = true
    label.Parent = slot
    
    -- Bouton pour interaction (seulement pour les slots d'entrée)
    if not isOutputSlot then
        local button = Instance.new("TextButton")
        button.Name = "SlotButton"
        button.Size = UDim2.new(1, 0, 1, 0)
        button.BackgroundTransparency = 1
        button.Text = ""
        button.Parent = slot
        
        -- Événements de clic (style Minecraft)
        button.MouseButton1Click:Connect(function()
            if draggedItem then
                -- Placer tout le stack
                placeItemInSlot(slotIndex, true)
            elseif slots[slotIndex] then
                -- Retirer l'ingrédient du slot et le remettre dans l'inventaire
                local slotData = slots[slotIndex]
                local ingredientName = slotData.ingredient or slotData
                removeIngredientEvt:FireServer(currentIncID, slotIndex, ingredientName)
                
                -- Mettre à jour l'interface après un délai
                task.wait(0.1)
                local ok, serverData = pcall(function()
                    return getSlotsEvt:InvokeServer(currentIncID)
                end)
                
                if ok and serverData then
                    if serverData.slots then
                        slots = serverData.slots
                    end
                end
                
                updateSlotDisplay()
                updateOutputSlot()
                updateInventoryDisplay()
            end
        end)
        
        button.MouseButton2Click:Connect(function()
            if draggedItem then
                -- Placer un par un
                placeItemInSlot(slotIndex, false)
            end
        end)
        
        -- Effets visuels
        button.MouseEnter:Connect(function()
            local tween = TweenService:Create(slot, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(160, 115, 70)})
            tween:Play()
        end)
        
        button.MouseLeave:Connect(function()
            local tween = TweenService:Create(slot, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(139, 99, 58)})
            tween:Play()
        end)
    else
        -- Bouton pour le slot de sortie (démarrer le crafting)
        local button = Instance.new("TextButton")
        button.Name = "CraftButton"
        button.Size = UDim2.new(1, 0, 1, 0)
        button.BackgroundTransparency = 1
        button.Text = ""
        button.Parent = slot
        
        button.MouseButton1Click:Connect(function()
            if currentRecipe then
                startCraftingEvt:FireServer(currentIncID, currentRecipe)
                -- Réinitialiser les slots après crafting
                for i = 1, 5 do
                    slots[i] = nil
                end
                updateSlotDisplay()
                updateOutputSlot()
            end
        end)
    end
    
    return slot
end



function updateSlotDisplay()
    -- Met à jour l'affichage de tous les slots
    print("🔍 DEBUG updateSlotDisplay - Début")
    
    if not gui then 
        print("❌ DEBUG updateSlotDisplay - GUI non trouvé!")
        return 
    end
    
    local mainFrame = gui:FindFirstChild("MainFrame")
    if not mainFrame then 
        print("❌ DEBUG updateSlotDisplay - MainFrame non trouvé!")
        return 
    end
    
    print("✅ DEBUG updateSlotDisplay - MainFrame trouvé")
    
    -- Debug: Lister tous les enfants de MainFrame
    print("🔍 DEBUG - Enfants de MainFrame:")
    for _, child in pairs(mainFrame:GetChildren()) do
        print("  -", child.Name, ":", child.ClassName)
        if child.Name == "CraftingArea" then
            print("    Enfants de CraftingArea:")
            for _, grandChild in pairs(child:GetChildren()) do
                print("      -", grandChild.Name, ":", grandChild.ClassName)
                if grandChild.Name == "InputContainer" then
                    print("        Enfants de InputContainer:")
                    for _, slot in pairs(grandChild:GetChildren()) do
                        print("          -", slot.Name, ":", slot.ClassName)
                    end
                end
            end
        end
    end
    
    local ingredientIcons = {
        sucre = "🍬",
        sirop = "🍯",
        aromefruit = "🍓"
    }
    
    for i = 1, 5 do
        print("🔍 DEBUG updateSlotDisplay - Traitement slot", i, "contenu:", slots[i])
        
        -- Chercher le slot dans InputContainer, pas directement dans MainFrame
        local inputContainer = mainFrame:FindFirstChild("CraftingArea")
        if inputContainer then
            inputContainer = inputContainer:FindFirstChild("InputContainer")
        end
        
        local slot = inputContainer and inputContainer:FindFirstChild("InputSlot" .. i)
        if slot then
            print("✅ DEBUG updateSlotDisplay - Slot", i, "trouvé")
            
            local iconFrame = slot:FindFirstChild("IconFrame")
            local label = slot:FindFirstChild("IngredientLabel")
            local iconLabel = iconFrame and iconFrame:FindFirstChild("IconLabel")
            
            print("🔍 DEBUG updateSlotDisplay - Éléments trouvés - iconFrame:", iconFrame ~= nil, "label:", label ~= nil, "iconLabel:", iconLabel ~= nil)
            
            if slots[i] then
                -- Slot occupé (nouveau système avec quantités)
                local slotData = slots[i]
                local ingredientName = slotData.ingredient or slotData
                local quantity = slotData.quantity or 1
                
                print("✅ DEBUG updateSlotDisplay - Slot", i, "occupé avec:", ingredientName, "quantité:", quantity)
                if iconFrame then 
                    iconFrame.Visible = true 
                    print("✅ DEBUG updateSlotDisplay - IconFrame rendu visible")
                end
                if iconLabel then 
                    iconLabel.Text = ingredientIcons[ingredientName] or "📦" 
                    print("✅ DEBUG updateSlotDisplay - IconLabel mis à jour:", iconLabel.Text)
                end
                if label then
                    label.Text = ingredientName .. " x" .. quantity
                    label.TextColor3 = Color3.new(1, 1, 1)
                    print("✅ DEBUG updateSlotDisplay - Label mis à jour:", label.Text)
                end
            else
                -- Slot vide
                print("🔍 DEBUG updateSlotDisplay - Slot", i, "vide")
                if iconFrame then iconFrame.Visible = false end
                if label then
                    label.Text = "Vide"
                    label.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end
        else
            print("❌ DEBUG updateSlotDisplay - Slot", i, "non trouvé!")
        end
    end
    
    print("✅ DEBUG updateSlotDisplay - Fin")
end

local function createModernGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "IncubatorMenu_v4"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = guiParent

    -- Frame principale (plus grande et mieux espacée)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 800, 0, 600)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(184, 133, 88)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 15)
    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(87, 60, 34)
    stroke.Thickness = 6

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 70)
    header.BackgroundColor3 = Color3.fromRGB(111, 168, 66)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    local hCorner = Instance.new("UICorner", header)
    hCorner.CornerRadius = UDim.new(0, 10)
    local hStroke = Instance.new("UIStroke", header)
    hStroke.Thickness = 4
    hStroke.Color = Color3.fromRGB(66, 103, 38)

    local titre = Instance.new("TextLabel", header)
    titre.Size = UDim2.new(0.7, 0, 1, 0)
    titre.Position = UDim2.new(0.05, 0, 0, 0)
    titre.BackgroundTransparency = 1
    titre.Text = "🧪 INCUBATEUR - SYSTÈME DE SLOTS"
    titre.TextColor3 = Color3.new(1, 1, 1)
    titre.TextSize = 24
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
    local xCorner = Instance.new("UICorner", boutonFermer)
    xCorner.CornerRadius = UDim.new(0, 10)

    -- Zone de crafting (mieux espacée)
    local craftingArea = Instance.new("Frame")
    craftingArea.Name = "CraftingArea"
    craftingArea.Size = UDim2.new(1, -40, 0.55, -20)
    craftingArea.Position = UDim2.new(0, 20, 0, 90)
    craftingArea.BackgroundTransparency = 1
    craftingArea.Parent = mainFrame

    -- Slots d'entrée (3x3 grid, mais on n'utilise que 5 slots)
    local inputContainer = Instance.new("Frame")
    inputContainer.Name = "InputContainer"
    inputContainer.Size = UDim2.new(0.6, 0, 1, 0)
    inputContainer.Position = UDim2.new(0, 0, 0, 0)
    inputContainer.BackgroundTransparency = 1
    inputContainer.Parent = craftingArea

    -- Disposition des 5 slots d'entrée en croix
    local slotPositions = {
        {0.5, -40, 0.2, -40}, -- Slot 1 (haut)
        {0.2, -40, 0.5, -40}, -- Slot 2 (gauche)
        {0.5, -40, 0.5, -40}, -- Slot 3 (centre)
        {0.8, -40, 0.5, -40}, -- Slot 4 (droite)
        {0.5, -40, 0.8, -40}, -- Slot 5 (bas)
    }

    for i = 1, 5 do
        local slot = createSlotUI(inputContainer, i, false)
        local pos = slotPositions[i]
        slot.Position = UDim2.new(pos[1], pos[2], pos[3], pos[4])
        print("🔍 DEBUG - Slot créé:", slot.Name, "dans", inputContainer.Name)
    end

    -- Flèche vers le résultat
    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 50, 0, 50)
    arrow.Position = UDim2.new(0.7, -25, 0.5, -25)
    arrow.BackgroundTransparency = 1
    arrow.Text = "➡️"
    arrow.TextSize = 30
    arrow.Parent = craftingArea

    -- Slot de sortie
    local outputSlot = createSlotUI(craftingArea, 0, true)
    outputSlot.Position = UDim2.new(0.85, -40, 0.5, -40)
    outputSlot.Size = UDim2.new(0, 100, 0, 100)

    -- Zone d'inventaire (en bas, plus grande)
    local inventoryArea = Instance.new("Frame")
    inventoryArea.Name = "InventoryArea"
    inventoryArea.Size = UDim2.new(1, -40, 0.4, -20)
    inventoryArea.Position = UDim2.new(0, 20, 0.58, 10)
    inventoryArea.BackgroundColor3 = Color3.fromRGB(139, 99, 58)
    inventoryArea.BorderSizePixel = 0
    inventoryArea.Parent = mainFrame
    
    local invCorner = Instance.new("UICorner", inventoryArea)
    invCorner.CornerRadius = UDim.new(0, 10)
    local invStroke = Instance.new("UIStroke", inventoryArea)
    invStroke.Color = Color3.fromRGB(87, 60, 34)
    invStroke.Thickness = 3

    -- Titre de l'inventaire
    local invTitle = Instance.new("TextLabel")
    invTitle.Size = UDim2.new(1, 0, 0, 25)
    invTitle.Position = UDim2.new(0, 0, 0, 5)
    invTitle.BackgroundTransparency = 1
    invTitle.Text = "📦 INVENTAIRE - Glissez les ingrédients vers les slots"
    invTitle.TextColor3 = Color3.new(1, 1, 1)
    invTitle.TextSize = 14
    invTitle.Font = Enum.Font.GothamBold
    invTitle.Parent = inventoryArea

    -- Zone de scroll pour l'inventaire
    local invScrollFrame = Instance.new("ScrollingFrame")
    invScrollFrame.Size = UDim2.new(1, -10, 1, -35)
    invScrollFrame.Position = UDim2.new(0, 5, 0, 30)
    invScrollFrame.BackgroundColor3 = Color3.fromRGB(87, 60, 34)
    invScrollFrame.BorderSizePixel = 0
    invScrollFrame.ScrollBarThickness = 8
    invScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
    invScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    invScrollFrame.Parent = inventoryArea
    
    local scrollCorner = Instance.new("UICorner", invScrollFrame)
    scrollCorner.CornerRadius = UDim.new(0, 5)
    
    -- Layout horizontal pour les ingrédients
    local invLayout = Instance.new("UIListLayout", invScrollFrame)
    invLayout.FillDirection = Enum.FillDirection.Horizontal
    invLayout.Padding = UDim.new(0, 10)
    invLayout.SortOrder = Enum.SortOrder.LayoutOrder

    return screenGui, boutonFermer
end

----------------------------------------------------------------------
-- FONCTIONS PRINCIPALES
----------------------------------------------------------------------
local function closeMenu()
    if gui and isMenuOpen then
        local mainFrame = gui:FindFirstChild("MainFrame")
        if mainFrame then
            local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
            tween:Play()
            tween.Completed:Connect(function()
                gui.Enabled = false
                isMenuOpen = false
                currentIncID = nil
                currentRecipe = nil
                -- Réinitialiser les slots
                for i = 1, 5 do
                    slots[i] = nil
                end
            end)
        end
    end
end

----------------------------------------------------------------------
-- INITIALISATION ET ÉVÉNEMENTS
----------------------------------------------------------------------
local function initializeGUI()
    print("🔍 DEBUG - Création de l'interface avec slots...")
    local screenGui, closeButton = createModernGUI()
    
    gui = screenGui
    gui.Enabled = false

    -- Événement fermeture
    closeButton.MouseButton1Click:Connect(closeMenu)

    return gui
end

-- Initialisation
print("🔍 DEBUG Client - Initialisation de l'interface...")
gui = initializeGUI()
if gui then
    print("✅ DEBUG Client - GUI créé avec succès")
else
    print("❌ DEBUG Client - Échec de création du GUI")
end

-- Fermer avec Escape et gérer les clics dans le vide
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Escape and isMenuOpen then
        -- Lâcher l'objet en main si il y en a un
        if draggedItem then
            stopCursorFollow()
        else
            closeMenu()
        end
    end
end)

-- Gérer les clics dans le vide pour lâcher l'objet
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isMenuOpen or gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and draggedItem then
        -- Clic dans le vide = lâcher l'objet
        stopCursorFollow()
    end
end)

-- Événement d'ouverture avec debug
openEvt.OnClientEvent:Connect(function(incID)
    if not gui then
        return
    end
    
    currentIncID = incID
    
    -- Récupérer l'état actuel des slots
    local ok, serverSlots = pcall(function()
        return getSlotsEvt:InvokeServer(incID)
    end)
    
    if ok and serverSlots then
        if serverSlots.slots then
            slots = serverSlots.slots
            updateSlotDisplay()
            updateOutputSlot()
            updateInventoryDisplay()
        end
    else
        warn("❌ Erreur lors de la récupération des slots:", serverSlots)
    end
    
    gui.Enabled = true
    isMenuOpen = true
    
    -- Animation d'ouverture
    local mainFrame = gui:FindFirstChild("MainFrame")
    if mainFrame then
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 800, 0, 600)})
        tween:Play()
    else
        warn("❌ MainFrame non trouvé!")
    end
end)

print("🔧 IncubatorMenuClient v4.0 (Système de slots avec crafting automatique) - Script chargé et prêt!")
