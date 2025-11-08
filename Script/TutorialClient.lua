--------------------------------------------------------------------
-- TutorialClient.lua - Interface utilisateur pour le tutoriel
-- Gère l'affichage des instructions, flèches et surbrillance
--------------------------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

-- MODULES
local TutorialArrowSystem = require(ReplicatedStorage:WaitForChild("TutorialArrowSystem"))

-- 🔒 BLOQUER LE MODE PORTRAIT SUR MOBILE
if UserInputService.TouchEnabled then
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
    print("📱 [TUTORIAL] Mode portrait bloqué - Landscape forcé")
end

-- VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- DÉTECTION PLATEFORME POUR INTERFACE RESPONSIVE
local viewportSize = workspace.CurrentCamera.ViewportSize
-- Détection mobile robuste: se base uniquement sur le tactile
local isMobile = UserInputService.TouchEnabled
local isSmallScreen = viewportSize.X < 800 or viewportSize.Y < 600

-- REMOTEEVENTS
local tutorialRemote = ReplicatedStorage:WaitForChild("TutorialRemote")
local tutorialStepRemote = ReplicatedStorage:WaitForChild("TutorialStepRemote")

-- VARIABLES DE L'INTERFACE
local tutorialGui = nil
local currentStep = nil
local currentHighlight = nil
local currentArrow = nil
local currentMessage = nil
local connections = {}
local current3DArrow = nil -- Pour les flèches 3D du TutorialArrowSystem

-- 🌐 EXPOSER L'ÉTAPE ACTUELLE GLOBALEMENT pour que d'autres scripts puissent y accéder
_G.CurrentTutorialStep = nil

--------------------------------------------------------------------
-- CONFIGURATION DE L'INTERFACE
--------------------------------------------------------------------
local UI_CONFIG = {
    -- Couleurs
    BACKGROUND_COLOR = Color3.fromRGB(20, 20, 20),
    TEXT_COLOR = Color3.fromRGB(255, 255, 255),
    HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0),
    ARROW_COLOR = Color3.fromRGB(255, 215, 0),
    
    -- Tailles responsives
    -- Taille par défaut (PC). Le mobile sera calculé dynamiquement pour garder la même forme mais plus petite
    MESSAGE_SIZE = UDim2.new(0, 420, 0, 150),
    ARROW_SIZE = isMobile and UDim2.new(0, 36, 0, 36) or UDim2.new(0, 60, 0, 60),
    
    -- Animations
    FADE_TIME = 0.3,
    BOUNCE_TIME = 0.8,
    HIGHLIGHT_PULSE_TIME = 1.5
}

--------------------------------------------------------------------
-- CRÉATION DE L'INTERFACE
--------------------------------------------------------------------
local function createTutorialGui()
    if tutorialGui then
        tutorialGui:Destroy()
    end
    
    tutorialGui = Instance.new("ScreenGui")
    tutorialGui.Name = "TutorialGui"
    -- Toujours au-dessus des autres UI
    tutorialGui.DisplayOrder = 4000
    tutorialGui.ResetOnSpawn = false
    tutorialGui.Parent = playerGui
    
    return tutorialGui
end

--------------------------------------------------------------------
-- SYSTÈME DE MESSAGES
--------------------------------------------------------------------
local function createMessageBox(title, message, stepName)
    local messageFrame = Instance.new("Frame")
    messageFrame.Name = "MessageFrame"
    -- Même forme PC/Mobile : on part d’une base PC et on scale pour mobile
    if isMobile then
        -- base 420x150 → réduire proportionnellement (un peu plus petit)
        local scale = 0.54
        messageFrame.Size = UDim2.new(0, math.floor(420 * scale), 0, math.floor(150 * scale))
    else
        messageFrame.Size = UI_CONFIG.MESSAGE_SIZE
    end
    -- Position responsive : appliquer le décalage uniquement sur mobile
    -- Sur mobile: position spéciale pour certaines étapes (à gauche)
    local isLeftStep = stepName and (
        stepName == "INCUBATOR_UI_GUIDE" or 
        stepName == "PLACE_IN_SLOTS" or 
        stepName == "SELECT_RECIPE" or
        stepName == "OPEN_BAG" or
        stepName == "SELL_CANDY"
    )
    
    -- Sur PC: PLACE_IN_SLOTS à droite, SELECT_RECIPE à gauche
    local isPCRightStep = stepName and stepName == "PLACE_IN_SLOTS"
    
    -- CAS SPÉCIAL: OPEN_INCUBATOR et CONFIRM_PRODUCTION sur mobile doivent être à GAUCHE pour ne pas cacher le bouton PRODUCE
    if isMobile and (stepName == "OPEN_INCUBATOR" or stepName == "CONFIRM_PRODUCTION") then
        messageFrame.Position = UDim2.new(0.25, 0, 0.18, 0)  -- Un peu plus à droite et plus haut
    elseif isMobile and isLeftStep then
        -- À GAUCHE pour ne pas cacher les boutons
        messageFrame.Position = UDim2.new(0.15, 0, 0.25, 0)
    elseif isMobile then
        -- Position normale (droite) pour les autres étapes (un peu plus bas)
        messageFrame.Position = UDim2.new(0.75, 0, 0.25, 0)
    elseif isPCRightStep then
        -- PC: À DROITE pour PLACE_IN_SLOTS (ne pas cacher l'inventaire à gauche)
        messageFrame.Position = UDim2.new(0.7, 0, 0.23, 0)
    else
        -- PC: À GAUCHE pour les autres étapes (sous le bouton ISLAND)
        messageFrame.Position = UDim2.new(0.3, 0, 0.23, 0)
    end
    messageFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    messageFrame.BackgroundColor3 = UI_CONFIG.BACKGROUND_COLOR
    messageFrame.BackgroundTransparency = isMobile and 0.05 or 0.1  -- Plus opaque sur mobile
    messageFrame.BorderSizePixel = 0
    messageFrame.Parent = tutorialGui
    
    -- Coins arrondis (plus arrondis sur mobile)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, isMobile and 20 or 15)
    corner.Parent = messageFrame
    
    -- Bordure dorée (plus fine sur mobile)
    local stroke = Instance.new("UIStroke")
    stroke.Color = UI_CONFIG.ARROW_COLOR
    stroke.Thickness = isMobile and 2 or 3
    stroke.Parent = messageFrame
    
    -- Titre (responsive)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    local titleHeight = isMobile and 24 or 40
    titleLabel.Size = UDim2.new(1, -20, 0, titleHeight)
    titleLabel.Position = UDim2.new(0, 10, 0, isMobile and 5 or 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = UI_CONFIG.ARROW_COLOR
    titleLabel.TextSize = isMobile and 14 or 24
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextScaled = false -- Forcer une taille fixe pour éviter qu'il empiète
    titleLabel.Parent = messageFrame
    
    -- Message (responsive)
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Name = "Message"
    local messageOffset = isMobile and -24 or -60
    local messageTopPosition = isMobile and 22 or 50
    messageLabel.Size = UDim2.new(1, -20, 1, messageOffset)
    messageLabel.Position = UDim2.new(0, 10, 0, messageTopPosition)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = UI_CONFIG.TEXT_COLOR
    messageLabel.TextSize = isMobile and 12 or 18
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top
    messageLabel.TextWrapped = true
    messageLabel.TextScaled = isMobile  -- Auto-resize sur mobile
    messageLabel.Parent = messageFrame
    
    -- Animation d'apparition
    messageFrame.BackgroundTransparency = 1
    stroke.Transparency = 1
    titleLabel.TextTransparency = 1
    messageLabel.TextTransparency = 1
    
    local fadeIn = TweenService:Create(messageFrame, TweenInfo.new(UI_CONFIG.FADE_TIME), {
        BackgroundTransparency = 0.1
    })
    local strokeFadeIn = TweenService:Create(stroke, TweenInfo.new(UI_CONFIG.FADE_TIME), {
        Transparency = 0
    })
    local titleFadeIn = TweenService:Create(titleLabel, TweenInfo.new(UI_CONFIG.FADE_TIME), {
        TextTransparency = 0
    })
    local messageFadeIn = TweenService:Create(messageLabel, TweenInfo.new(UI_CONFIG.FADE_TIME), {
        TextTransparency = 0
    })
    
    fadeIn:Play()
    strokeFadeIn:Play()
    titleFadeIn:Play()
    messageFadeIn:Play()
    
    return messageFrame
end



--------------------------------------------------------------------
-- SYSTÈME DE FLÈCHES
--------------------------------------------------------------------
local function createArrow(targetPosition, targetObject)
    local arrowFrame = Instance.new("Frame")
    arrowFrame.Name = "ArrowFrame"
    arrowFrame.Size = (isMobile or isSmallScreen) and UDim2.new(0, 48, 0, 48) or UDim2.new(0, 80, 0, 80)
    arrowFrame.BackgroundTransparency = 1
    arrowFrame.Parent = tutorialGui
    
    -- Flèche avec emoji
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.Size = UDim2.new(1, 0, 1, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "👇" -- Flèche emoji plus visible
    arrow.TextColor3 = UI_CONFIG.ARROW_COLOR
    arrow.TextSize = (isMobile or isSmallScreen) and 32 or 48
    arrow.Font = Enum.Font.GothamBold
    arrow.TextStrokeTransparency = 0
    arrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    arrow.Parent = arrowFrame
    
    -- Convertir targetPosition en Vector3 si c'est un objet
    local actualPosition = targetPosition
    if typeof(targetPosition) ~= "Vector3" then
        if targetPosition and targetPosition.Position then
            actualPosition = targetPosition.Position
        elseif targetObject and targetObject.Position then
            actualPosition = targetObject.Position
        else
            print("❌ [TUTORIAL] Impossible de déterminer la position de la cible")
            return nil
        end
    end
    
    -- Debug: afficher la cible
    if targetObject then
        print("🎯 [TUTORIAL] Flèche créée vers:", targetObject:GetFullName(), "Position:", actualPosition)
    else
        print("🎯 [TUTORIAL] Flèche créée vers position:", actualPosition)
    end
    
    -- Positionner la flèche
    local camera = workspace.CurrentCamera
    if camera and actualPosition then
        local screenPoint, onScreen = camera:WorldToScreenPoint(actualPosition)
        
        -- Vérifier que la position est valide et visible
        if onScreen and screenPoint.Z > 0 then
            arrowFrame.Position = UDim2.new(0, math.max(10, screenPoint.X - 40), 0, math.max(10, screenPoint.Y - 80))
        else
            -- Si pas visible, placer au centre de l'écran
            arrowFrame.Position = UDim2.new(0.5, -40, 0.5, -40)
            arrow.Text = "🎯" -- Icône différente si hors écran
        end
    else
        -- Position par défaut si problème
        arrowFrame.Position = UDim2.new(0.5, -40, 0.5, -40)
        arrow.Text = "🎯"
    end
    
    -- Animation de rebond
    local bounce = TweenService:Create(arrow, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        TextSize = 56,
        Rotation = 10
    })
    bounce:Play()
    
    -- Animation de brillance
    local glow = TweenService:Create(arrow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        TextTransparency = 0.3
    })
    glow:Play()
    
    return arrowFrame
end

local function updateArrowPosition(arrow, targetPosition)
    if not arrow or not arrow.Parent or not targetPosition then return end
    
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local screenPoint, onScreen = camera:WorldToScreenPoint(targetPosition)
    
    -- Vérifier que la position est valide et visible
    if onScreen and screenPoint.Z > 0 then
        local newPosition = UDim2.new(0, math.max(10, screenPoint.X - 40), 0, math.max(10, screenPoint.Y - 80))
        
        local tween = TweenService:Create(arrow, TweenInfo.new(0.3), {
            Position = newPosition
        })
        tween:Play()
        
        -- Changer l'icône si nécessaire
        local arrowLabel = arrow:FindFirstChild("Arrow")
        if arrowLabel and arrowLabel.Text ~= "👇" then
            arrowLabel.Text = "👇"
        end
    else
        -- Si la cible n'est pas visible, centrer la flèche et changer l'icône
        local centerPosition = UDim2.new(0.5, -40, 0.5, -40)
        
        local tween = TweenService:Create(arrow, TweenInfo.new(0.3), {
            Position = centerPosition
        })
        tween:Play()
        
        local arrowLabel = arrow:FindFirstChild("Arrow")
        if arrowLabel then
            arrowLabel.Text = "🎯"
        end
    end
end

--------------------------------------------------------------------
-- FLÈCHES SPÉCIALISÉES INTERFACE INCUBATEUR
--------------------------------------------------------------------
local function createIncubatorUIArrows()
    -- Attendre un peu que l'interface se charge complètement
    task.wait(0.5)
    
    -- Chercher l'interface de l'incubateur ouverte (nom correct: IncubatorMenu_v4)
    local incubatorGui = playerGui:FindFirstChild("IncubatorMenu_v4")
    if not incubatorGui then
        print("❌ [TUTORIAL] Interface incubateur non trouvée")
        -- Retry après un délai
        task.wait(0.5)
        incubatorGui = playerGui:FindFirstChild("IncubatorMenu_v4")
        if not incubatorGui then
            print("❌ [TUTORIAL] Interface incubateur toujours non trouvée après retry")
            return
        end
    end
    
    local mainFrame = incubatorGui:FindFirstChild("MainFrame")
    if not mainFrame then
        print("❌ [TUTORIAL] MainFrame incubateur non trouvé")
        return
    end
    
    print("✅ [TUTORIAL] Interface incubateur trouvée:", incubatorGui.Name)
    
    -- Fonction pour créer un highlight SUBTIL sur un item d'inventaire
    local function highlightInventoryItem(item, color, arrowText, ingredientName)
        if not item or not item.Parent then return end
        
        -- Créer un cadre de surbrillance SUBTIL
        local highlight = Instance.new("Frame")
        highlight.Name = "TutorialHighlight_" .. ingredientName
        highlight.Size = UDim2.new(1, 6, 1, 6)
        highlight.Position = UDim2.new(0, -3, 0, -3)
        highlight.BackgroundTransparency = 1  -- Complètement transparent
        highlight.BorderSizePixel = 0
        highlight.ZIndex = item.ZIndex + 1
        highlight.Parent = item
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = highlight
        
        -- Juste un contour subtil
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = 2
        stroke.Transparency = 0.5
        stroke.Parent = highlight
        
        -- Animation de pulsation DOUCE
        local strokePulse = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Thickness = 3,
            Transparency = 0.2
        })
        strokePulse:Play()
        
        -- Créer une petite flèche pointant vers l'item
        local arrow = Instance.new("TextLabel")
        arrow.Name = "TutorialArrow"
        arrow.Size = UDim2.new(0, 100, 0, 30)
        arrow.Position = UDim2.new(1, 5, 0.5, -15)
        arrow.BackgroundTransparency = 1
        arrow.Text = arrowText
        arrow.TextColor3 = color
        arrow.TextSize = 14
        arrow.Font = Enum.Font.GothamBold
        arrow.TextStrokeTransparency = 0.3
        arrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        arrow.ZIndex = 20
        arrow.Parent = highlight
        
        -- Animation de rebond DOUCE pour la flèche
        local bounce = TweenService:Create(arrow, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Position = UDim2.new(1, 8, 0.5, -15)
        })
        bounce:Play()
        
        -- Détecter le clic sur l'item pour afficher la flèche vers les slots
        local clickDetector = item:FindFirstChildOfClass("TextButton") or item:FindFirstChildOfClass("ImageButton")
        if clickDetector then
            clickDetector.MouseButton1Click:Connect(function()
                print("🖱️ [TUTORIAL] Clic détecté sur:", ingredientName)
                -- Créer une flèche vers les slots SANS décaler les slots
                local craftingArea = mainFrame:FindFirstChild("CraftingArea")
                if craftingArea then
                    local inputContainer = craftingArea:FindFirstChild("InputContainer")
                    if inputContainer then
                        -- Supprimer TOUTES les anciennes flèches (pas juste celle de cet ingrédient)
                        for _, child in pairs(craftingArea:GetChildren()) do
                            if child.Name:find("TutorialSlotArrow_") then
                                child:Destroy()
                                print("🗑️ [TUTORIAL] Suppression de l'ancienne flèche:", child.Name)
                            end
                        end
                        
                        -- Calculer la position de l'InputContainer pour positionner la flèche au-dessus
                        local inputPos = inputContainer.Position
                        local inputAbsSize = inputContainer.AbsoluteSize
                        
                        local slotArrow = Instance.new("TextLabel")
                        slotArrow.Name = "TutorialSlotArrow_" .. ingredientName
                        slotArrow.Size = UDim2.new(0, 280, 0, 40)  -- Plus large
                        -- Positionner ENCORE PLUS BAS et UN PEU À GAUCHE
                        slotArrow.Position = UDim2.new(
                            inputPos.X.Scale, 
                            inputPos.X.Offset + (inputAbsSize.X / 2) - 140 + 10,  -- Centré + décalage GAUCHE (10 au lieu de 30)
                            inputPos.Y.Scale, 
                            inputPos.Y.Offset + 40  -- 40px EN DESSOUS (encore plus bas)
                        )
                        slotArrow.BackgroundTransparency = 1
                        slotArrow.Text = "👇 PLACE HERE 👇"
                        slotArrow.TextColor3 = color
                        slotArrow.TextSize = 20  -- Plus gros (20 au lieu de 16)
                        slotArrow.Font = Enum.Font.GothamBold
                        slotArrow.TextStrokeTransparency = 0.2
                        slotArrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        slotArrow.ZIndex = 20
                        slotArrow.Parent = craftingArea  -- Parent = CraftingArea pour ne pas décaler
                        
                        -- Animation de brillance et rebond TRÈS DOUX
                        local glow = TweenService:Create(slotArrow, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                            TextTransparency = 0.3,
                            Position = UDim2.new(
                                inputPos.X.Scale, 
                                inputPos.X.Offset + (inputAbsSize.X / 2) - 140 + 10,
                                inputPos.Y.Scale, 
                                inputPos.Y.Offset + 35  -- Rebond vers +35px
                            ),
                            TextSize = 22  -- Animation vers 22
                        })
                        glow:Play()
                        
                        -- Highlight les slots vides
                        for i = 1, 4 do
                            local slot = inputContainer:FindFirstChild("Slot" .. i)
                            if slot then
                                -- Vérifier si le slot est vide (pas d'image d'ingrédient)
                                local isEmpty = true
                                for _, child in pairs(slot:GetChildren()) do
                                    if child:IsA("ImageLabel") and child.Name ~= "SlotBG" then
                                        isEmpty = false
                                        break
                                    end
                                end
                                
                                if isEmpty then
                                    -- Supprimer l'ancien highlight si existe
                                    local oldHighlight = slot:FindFirstChild("TutorialSlotHighlight")
                                    if oldHighlight then oldHighlight:Destroy() end
                                    
                                    -- Créer un highlight subtil sur le slot vide
                                    local slotHighlight = Instance.new("Frame")
                                    slotHighlight.Name = "TutorialSlotHighlight"
                                    slotHighlight.Size = UDim2.new(1, 4, 1, 4)
                                    slotHighlight.Position = UDim2.new(0, -2, 0, -2)
                                    slotHighlight.BackgroundTransparency = 1
                                    slotHighlight.BorderSizePixel = 0
                                    slotHighlight.ZIndex = slot.ZIndex + 1
                                    slotHighlight.Parent = slot
                                    
                                    local stroke = Instance.new("UIStroke")
                                    stroke.Color = color
                                    stroke.Thickness = 3
                                    stroke.Transparency = 0.3
                                    stroke.Parent = slotHighlight
                                    
                                    local corner = Instance.new("UICorner")
                                    corner.CornerRadius = UDim.new(0, 8)
                                    corner.Parent = slotHighlight
                                    
                                    -- Animation de pulsation
                                    local pulse = TweenService:Create(stroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                                        Thickness = 4,
                                        Transparency = 0.1
                                    })
                                    pulse:Play()
                                    
                                    print("✨ [TUTORIAL] Highlight ajouté sur Slot" .. i)
                                end
                            end
                        end
                        
                        print("✅ [TUTORIAL] Flèche vers slots créée pour:", ingredientName)
                        print("   Position InputContainer:", inputPos)
                        print("   Taille InputContainer:", inputAbsSize)
                    else
                        print("❌ [TUTORIAL] InputContainer non trouvé")
                    end
                end
            end)
        end
        
        return highlight
    end
    
    -- Chercher la zone d'inventaire (gauche)
    local inventoryArea = mainFrame:FindFirstChild("InventoryArea")
    local inventoryScroll = inventoryArea and inventoryArea:FindFirstChild("InventoryScroll")
    
    if not inventoryArea then
        print("❌ [TUTORIAL] InventoryArea non trouvée")
        return
    end
    
    if not inventoryScroll then
        print("❌ [TUTORIAL] InventoryScroll non trouvé")
        return
    end
    
    print("✅ [TUTORIAL] InventoryScroll trouvé avec", #inventoryScroll:GetChildren(), "enfants")
    
    if inventoryScroll then
        -- Debug: afficher tous les enfants
        print("🔍 [TUTORIAL] Enfants de InventoryScroll:")
        for _, child in pairs(inventoryScroll:GetChildren()) do
            print("  -", child.Name, child.ClassName)
        end
        
        -- Chercher et highlight le SUCRE
        local sugarItem = nil
        for _, child in pairs(inventoryScroll:GetChildren()) do
            if child:IsA("Frame") and child.Name:find("Sucre") then
                sugarItem = child
                print("✅ [TUTORIAL] Sucre trouvé:", child.Name)
                break
            end
        end
        
        if sugarItem then
            highlightInventoryItem(sugarItem, Color3.fromRGB(255, 215, 0), "👈 Click", "Sucre")
            print("🎯 [TUTORIAL] Sucre highlighted")
        else
            print("❌ [TUTORIAL] Élément sucre non trouvé dans l'inventaire")
        end
        
        -- Chercher et highlight la GÉLATINE
        local gelatineItem = nil
        for _, child in pairs(inventoryScroll:GetChildren()) do
            if child:IsA("Frame") and child.Name:find("Gelatine") then
                gelatineItem = child
                print("✅ [TUTORIAL] Gélatine trouvée:", child.Name)
                break
            end
        end
        
        if gelatineItem then
            highlightInventoryItem(gelatineItem, Color3.fromRGB(100, 200, 255), "👈 Click", "Gelatine")
            print("🎯 [TUTORIAL] Gélatine highlighted")
        else
            print("❌ [TUTORIAL] Élément gélatine non trouvé dans l'inventaire")
        end
    end
    
    -- La flèche vers les slots apparaîtra maintenant quand le joueur clique sur un ingrédient
    -- (géré dans highlightInventoryItem)
end

--------------------------------------------------------------------
-- SYSTÈME DE ROTATION DE CAMÉRA - SUPPRIMÉ
-- Le joueur garde le contrôle total de la caméra pendant le tutoriel
--------------------------------------------------------------------

--------------------------------------------------------------------
-- SYSTÈME DE SURBRILLANCE
--------------------------------------------------------------------
local function createHighlight(targetObject)
    if not targetObject or not targetObject:IsA("BasePart") then return end
    
    local highlight = Instance.new("SelectionBox")
    highlight.Name = "TutorialHighlight"
    highlight.Adornee = targetObject
    highlight.Color3 = UI_CONFIG.HIGHLIGHT_COLOR
    highlight.LineThickness = 0.2
    highlight.Transparency = 0.5
    highlight.Parent = targetObject
    
    -- Animation de pulsation
    local pulse = TweenService:Create(highlight, TweenInfo.new(UI_CONFIG.HIGHLIGHT_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Transparency = 0.1
    })
    pulse:Play()
    
    return highlight
end

local function highlightShopItem(itemName)
    -- Support pour plusieurs items (table ou string)
    local itemNames = {}
    if type(itemName) == "table" then
        itemNames = itemName
    else
        itemNames = {itemName}
    end
    
    -- Chercher l'élément dans tous les ScreenGui possibles
    local shopHighlights = {}
    
    -- Fonction pour trouver et surligner un item
    local function findAndHighlightItem(targetItemName)
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                -- Chercher récursivement dans tous les frames
                local function searchInFrame(frame)
                    if frame.Name == targetItemName then
                        -- Trouvé l'item! Créer la surbrillance subtile
                        -- Nettoyer uniquement l'ancien highlight de CET item spécifique
                        local oldHighlight = frame:FindFirstChild("ShopItemHighlight_" .. targetItemName)
                        if oldHighlight then
                            oldHighlight:Destroy()
                        end
                        
                        -- Contour doré subtil seulement
                        local highlight = Instance.new("Frame")
                        highlight.Name = "ShopItemHighlight_" .. targetItemName -- Nom unique par item
                        highlight.Size = UDim2.new(1, 8, 1, 8)
                        highlight.Position = UDim2.new(0, -4, 0, -4)
                        highlight.BackgroundTransparency = 1 -- Pas de remplissage
                        highlight.BorderSizePixel = 0
                        highlight.ZIndex = frame.ZIndex + 1
                        highlight.Parent = frame
                        
                        -- Juste un contour doré
                        local stroke = Instance.new("UIStroke")
                        stroke.Color = Color3.fromRGB(255, 215, 0)
                        stroke.Thickness = 3
                        stroke.Transparency = 0.3
                        stroke.Parent = highlight
                        
                        local corner = Instance.new("UICorner")
                        corner.CornerRadius = UDim.new(0, 8)
                        corner.Parent = highlight
                        
                        -- Animation de pulsation subtile du contour
                        local pulse = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                            Transparency = 0.1,
                            Thickness = 4
                        })
                        pulse:Play()
                        
                        -- Chercher spécifiquement le bouton ACHETER (prioriser le bouton simple)
                        local function findPurchaseButton(container)
                            local buttons = {}
                            
                            -- Collecter tous les boutons d'achat
                            for _, child in pairs(container:GetDescendants()) do
                                if child:IsA("TextButton") and (child.Text:upper():find("ACHETER") or child.Text:upper():find("ACHAT") or child.Text:upper():find("BUY")) then
                                    table.insert(buttons, child)
                                end
                            end
                            
                            -- Prioriser les boutons simples sans "x" ou nombres
                            for _, button in pairs(buttons) do
                                local text = button.Text:upper()
                                if (text == "ACHETER" or text == "ACHAT" or text == "BUY") then
                                    return button -- Bouton simple prioritaire
                                end
                            end
                            
                            -- Si pas de bouton simple, prendre le premier trouvé
                            return buttons[1]
                        end
                        
                        local buttonContainer = frame:FindFirstChild("ButtonContainer")
                        local purchaseButton = nil
                        
                        -- Chercher le bouton dans différents conteneurs possibles
                        if buttonContainer then
                            purchaseButton = findPurchaseButton(buttonContainer)
                        else
                            purchaseButton = findPurchaseButton(frame)
                        end
                        
                        if purchaseButton then
                            -- Highlight spécifique sur le bouton ACHETER
                            if purchaseButton:FindFirstChild("ButtonHighlight") then
                                purchaseButton.ButtonHighlight:Destroy()
                            end
                            
                            local buttonHighlight = Instance.new("Frame")
                            buttonHighlight.Name = "ButtonHighlight"
                            buttonHighlight.Size = UDim2.new(1, 6, 1, 6)
                            buttonHighlight.Position = UDim2.new(0, -3, 0, -3)
                            buttonHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
                            buttonHighlight.BackgroundTransparency = 0.7
                            buttonHighlight.BorderSizePixel = 0
                            buttonHighlight.ZIndex = purchaseButton.ZIndex + 1
                            buttonHighlight.Parent = purchaseButton
                            
                            local buttonCorner = Instance.new("UICorner")
                            buttonCorner.CornerRadius = UDim.new(0, 8)
                            buttonCorner.Parent = buttonHighlight
                            
                            local buttonStroke = Instance.new("UIStroke")
                            buttonStroke.Color = Color3.fromRGB(255, 255, 0)
                            buttonStroke.Thickness = 2
                            buttonStroke.Parent = buttonHighlight
                            
                            -- Animation du bouton
                            local buttonPulse = TweenService:Create(buttonHighlight, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                                BackgroundTransparency = 0.3,
                                Size = UDim2.new(1, 10, 1, 10),
                                Position = UDim2.new(0, 15, 0, 15)
                            })
                            buttonPulse:Play()
                            
                            -- Flèche pointant précisément vers le bouton
                            local arrow = Instance.new("TextLabel")
                            arrow.Name = "PurchaseArrow"
                            arrow.Size = UDim2.new(0, 150, 0, 40)
                            arrow.Position = UDim2.new(1, 10, 0.5, -20) -- À droite du bouton
                            arrow.BackgroundTransparency = 1
                            arrow.Text = "👈 CLIQUE ICI!"
                            arrow.TextColor3 = Color3.fromRGB(255, 255, 0)
                            arrow.TextSize = 16
                            arrow.Font = Enum.Font.GothamBold
                            arrow.TextStrokeTransparency = 0
                            arrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            arrow.ZIndex = 15
                            arrow.Parent = buttonHighlight
                            
                            -- Animation de rebond pour la flèche
                            local bounceArrow = TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut, -1, true), {
                                Position = UDim2.new(1, 15, 0.5, -20)
                            })
                            bounceArrow:Play()
                            
                            -- Détecter le clic sur le bouton pour retirer le highlight de cet item uniquement
                            local itemHighlight = highlight -- Capturer la référence locale
                            local itemFrame = frame -- Capturer le frame de l'item
                            
                            -- Vérifier qu'on n'a pas déjà connecté ce bouton
                            if not purchaseButton:GetAttribute("TutorialConnected_" .. targetItemName) then
                                purchaseButton:SetAttribute("TutorialConnected_" .. targetItemName, true)
                                
                                purchaseButton.MouseButton1Click:Connect(function()
                                    print("🛒 [TUTORIAL] Click detected on BUY button for:", targetItemName)
                                    print("🛒 [TUTORIAL] Item frame name:", itemFrame.Name)
                                    print("🛒 [TUTORIAL] Highlight name:", itemHighlight.Name)
                                    
                                    -- Retirer le highlight de cet item spécifique uniquement
                                    if itemHighlight and itemHighlight.Parent then
                                        print("🗑️ [TUTORIAL] Removing highlight for:", targetItemName)
                                        -- Fade out avec destruction
                                        local stroke = itemHighlight:FindFirstChildOfClass("UIStroke")
                                        if stroke then
                                            TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
                                        end
                                        task.wait(0.3)
                                        if itemHighlight and itemHighlight.Parent then
                                            itemHighlight:Destroy()
                                            print("✅ [TUTORIAL] Highlight destroyed for:", targetItemName)
                                        end
                                    end
                                end)
                            end
                        else
                            -- Si pas de bouton trouvé, flèche générale vers la zone des boutons
                            local arrow = Instance.new("TextLabel")
                            arrow.Name = "PurchaseArrow"
                            arrow.Size = UDim2.new(0, 150, 0, 30)
                            arrow.Position = UDim2.new(1, -30, 0.5, -15)
                            arrow.BackgroundTransparency = 1
                            arrow.Text = "👈 ACHÈTE ICI!"
                            arrow.TextColor3 = Color3.fromRGB(255, 255, 0)
                            arrow.TextSize = 16
                            arrow.Font = Enum.Font.GothamBold
                            arrow.TextStrokeTransparency = 0
                            arrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            arrow.ZIndex = 10
                            arrow.Parent = highlight
                            
                            -- Animation de rebond pour la flèche
                            local bounceArrow = TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.InOut, -1, true), {
                                Position = UDim2.new(1, -25, 0.5, -15)
                            })
                            bounceArrow:Play()
                        end
                        
                        return highlight
                    end
                    
                    -- Continuer la recherche dans les enfants
                    for _, child in pairs(frame:GetChildren()) do
                        if child:IsA("GuiObject") then
                            local result = searchInFrame(child)
                            if result then return result end
                        end
                    end
                return nil
                end
                
                -- Commencer la recherche dans ce ScreenGui
                local result = searchInFrame(gui)
                if result then 
                    return result
                end
            end
        end
        return nil
    end
    
    -- Essayer de trouver tous les items immédiatement
    for _, name in ipairs(itemNames) do
        local highlight = findAndHighlightItem(name)
        if highlight then
            table.insert(shopHighlights, highlight)
        end
    end
    
    -- Si certains items ne sont pas trouvés, réessayer périodiquement
    if #shopHighlights < #itemNames then
        local attempts = 0
        local maxAttempts = 20
        
        local retryConnection
        retryConnection = RunService.Heartbeat:Connect(function()
            attempts = attempts + 1
            if attempts > maxAttempts or #shopHighlights >= #itemNames then
                retryConnection:Disconnect()
                return
            end
            
            -- Réessayer pour chaque item manquant
            for _, name in ipairs(itemNames) do
                local alreadyHighlighted = false
                for _, existing in ipairs(shopHighlights) do
                    if existing and existing.Parent and existing.Parent.Name == name then
                        alreadyHighlighted = true
                        break
                    end
                end
                
                if not alreadyHighlighted then
                    local highlight = findAndHighlightItem(name)
                    if highlight then
                        table.insert(shopHighlights, highlight)
                    end
                end
            end
        end)
    end
    
    -- Retourner le premier highlight (pour compatibilité) ou tous si plusieurs
    return #shopHighlights > 0 and shopHighlights[1] or nil
end

-- Fonction pour surbrillancer le bouton de vente
local function highlightSellButton()
    print("💰 [TUTORIAL] Recherche du bouton de vente...")
    
    -- Chercher le bouton de vente dans la hotbar (robuste)
    local function findSellButton()
        local candidate = nil
        
        -- PRIORITÉ 1: Chercher dans TopButtonsUI (le plus fiable)
        local topButtonsUI = playerGui:FindFirstChild("TopButtonsUI")
        if topButtonsUI then
            local venteButton = topButtonsUI:FindFirstChild("ButtonsFrame")
            if venteButton then
                venteButton = venteButton:FindFirstChild("VenteButton")
                if venteButton then
                    print("✅ [TUTORIAL] Bouton VENTE trouvé dans TopButtonsUI")
                    return venteButton
                end
            end
        end
        
        -- PRIORITÉ 2: Recherche générale
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, obj in pairs(gui:GetDescendants()) do
                    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                        local name = tostring(obj.Name)
                        local text = tostring(obj.Text or "")
                        -- Conditions: nom 'SellButton'/'Vente', ou texte 'VENTE' ou l'emoji 💰
                        if name:find("Sell") or name:find("Vente") or text:find("VENTE") or text:find("💰") then
                            candidate = obj
                            break
                        end
                    end
                end
                if candidate then break end
            end
        end
        
        -- PRIORITÉ 3: Essayer via référence directe exposée par le backpack
        if not candidate then
            local uiRefs = playerGui:FindFirstChild("UIRefs")
            if uiRefs then
                local ref = uiRefs:FindFirstChild("SellButtonRef")
                if ref and ref:IsA("ObjectValue") and ref.Value then
                    candidate = ref.Value
                end
            end
        end
        
        return candidate
    end

    local function createEffect(btn)
        if not btn or not btn.Parent then return nil end
        -- Nettoyer un ancien highlight local
        local oldLocal = btn:FindFirstChild("BaseHighlightTutorial")
        if oldLocal then oldLocal:Destroy() end
        
        -- Créer un highlight TRÈS VISIBLE avec double contour
        local h = Instance.new("Frame")
        h.Name = "BaseHighlightTutorial"
        h.Size = UDim2.new(1, 20, 1, 20)
        h.Position = UDim2.new(0, -10, 0, -10)
        h.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        h.BackgroundTransparency = 0.7
        h.BorderSizePixel = 0
        h.ZIndex = (btn.ZIndex or 1) + 1
        h.Parent = btn
        
        local c = Instance.new("UICorner", h); c.CornerRadius = UDim.new(0, 15)
        
        -- Double contour pour plus de visibilité
        local s1 = Instance.new("UIStroke", h)
        s1.Color = Color3.fromRGB(255, 215, 0)
        s1.Thickness = 5
        s1.Transparency = 0.2
        
        -- Animation de pulsation FORTE
        TweenService:Create(h, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.3,
            Size = UDim2.new(1, 28, 1, 28),
            Position = UDim2.new(0, -14, 0, -14)
        }):Play()
        
        TweenService:Create(s1, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Thickness = 7,
            Transparency = 0
        }):Play()
        
        -- Ajouter une flèche "CLICK HERE TO SELL" en dessous du bouton
        local arrow = Instance.new("TextLabel")
        arrow.Name = "SellArrow"
        arrow.Size = UDim2.new(0, 300, 0, 50)
        arrow.Position = UDim2.new(0.5, -150, 1, 10)  -- En dessous du bouton
        arrow.BackgroundTransparency = 1
        arrow.Text = "👆 CLICK HERE TO SELL 👆"
        arrow.TextColor3 = Color3.fromRGB(255, 215, 0)
        arrow.TextSize = 24
        arrow.Font = Enum.Font.GothamBlack
        arrow.TextStrokeTransparency = 0.2
        arrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        arrow.ZIndex = (btn.ZIndex or 1) + 2
        arrow.Parent = h
        
        -- Animation de rebond pour la flèche
        TweenService:Create(arrow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Position = UDim2.new(0.5, -150, 1, 5),
            TextSize = 26
        }):Play()
        
        return h
    end

    local sellButton = findSellButton()
    if not sellButton then
        print("⚠️ [TUTORIAL] Bouton de vente non trouvé – retry programmé")
        -- Rechercher à intervalles jusqu'à ce que le bouton apparaisse ou que l'étape change
        task.spawn(function()
            for _ = 1, 20 do -- ~4s max avec 0.2s
                if currentStep ~= "OPEN_BAG" and currentStep ~= "SELL_CANDY" then return end
                local btn = findSellButton()
                if btn then
                    if currentStep == "OPEN_BAG" or currentStep == "SELL_CANDY" then
                        currentHighlight = createEffect(btn)
                    end
                    return
                end
                task.wait(0.2)
            end
            return
        end)
        -- Pas de retour immédiat de highlight (sera créé asynchrone si trouvé)
        return nil
    end
    
    print("✅ [TUTORIAL] Bouton de vente trouvé:", sellButton:GetFullName())
    return createEffect(sellButton)
end

-- Fonction pour surbrillancer les boutons SELL dans le CandySellUI
local function highlightSellButtonsInMenu()
    print("💰 [TUTORIAL] Recherche des boutons SELL dans le menu de vente...")
    
    local function findAndHighlightSellButtons()
        local candySellUI = playerGui:FindFirstChild("CandySellUI")
        if not candySellUI then
            print("⚠️ [TUTORIAL] CandySellUI non trouvé")
            return false
        end
        
        local sellFrame = candySellUI:FindFirstChild("SellFrame")
        if not sellFrame then
            print("⚠️ [TUTORIAL] SellFrame non trouvé")
            return false
        end
        
        local sellList = sellFrame:FindFirstChild("SellList")
        if not sellList then
            print("⚠️ [TUTORIAL] SellList non trouvé")
            return false
        end
        
        -- Chercher tous les boutons SELL dans la liste
        local highlightedCount = 0
        for _, itemFrame in pairs(sellList:GetChildren()) do
            if itemFrame:IsA("Frame") and itemFrame.Name:find("Item") then
                -- Chercher le bouton SELL dans cet item
                for _, child in pairs(itemFrame:GetChildren()) do
                    if child:IsA("TextButton") and (child.Text == "SELL" or child.Text == "$") then
                        -- Créer un highlight sur ce bouton
                        local oldHighlight = child:FindFirstChild("TutorialSellHighlight")
                        if oldHighlight then oldHighlight:Destroy() end
                        
                        local h = Instance.new("Frame")
                        h.Name = "TutorialSellHighlight"
                        h.Size = UDim2.new(1, 8, 1, 8)
                        h.Position = UDim2.new(0, -4, 0, -4)
                        h.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
                        h.BackgroundTransparency = 0.6
                        h.BorderSizePixel = 0
                        h.ZIndex = (child.ZIndex or 1) + 1
                        h.Parent = child
                        
                        local c = Instance.new("UICorner", h)
                        c.CornerRadius = UDim.new(0, 6)
                        
                        local s = Instance.new("UIStroke", h)
                        s.Color = Color3.fromRGB(255, 215, 0)
                        s.Thickness = 3
                        s.Transparency = 0.3
                        
                        -- Animation de pulsation
                        TweenService:Create(h, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                            BackgroundTransparency = 0.3,
                            Size = UDim2.new(1, 12, 1, 12),
                            Position = UDim2.new(0, -6, 0, -6)
                        }):Play()
                        
                        TweenService:Create(s, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                            Thickness = 4,
                            Transparency = 0.1
                        }):Play()
                        
                        highlightedCount = highlightedCount + 1
                        print("✅ [TUTORIAL] Bouton SELL highlighted dans:", itemFrame.Name)
                    end
                end
            end
        end
        
        if highlightedCount > 0 then
            print("✅ [TUTORIAL]", highlightedCount, "bouton(s) SELL highlighted dans le menu")
            return true
        else
            print("⚠️ [TUTORIAL] Aucun bouton SELL trouvé dans le menu")
            return false
        end
    end
    
    -- Essayer de trouver et highlight immédiatement
    if findAndHighlightSellButtons() then
        return true
    end
    
    -- Si pas trouvé, réessayer périodiquement
    print("⚠️ [TUTORIAL] Boutons SELL non trouvés – retry programmé")
    task.spawn(function()
        for i = 1, 20 do
            if currentStep ~= "SELL_CANDY" then return end
            task.wait(0.2)
            if findAndHighlightSellButtons() then
                return
            end
        end
    end)
    
    return false
end

-- Fonction pour surbrillancer le bouton SHOP
local function highlightShopButton()
    print("🏪 [TUTORIAL] Recherche du bouton SHOP...")
    
    -- Chercher le bouton SHOP dans l'interface
    local function findShopButton()
        local candidate = nil
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, obj in pairs(gui:GetDescendants()) do
                    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                        local name = tostring(obj.Name)
                        -- Pour ImageButton, chercher dans les TextLabels enfants
                        local text = ""
                        if obj:IsA("TextButton") then
                            text = tostring(obj.Text or "")
                        else
                            -- ImageButton: chercher un TextLabel enfant
                            local textLabel = obj:FindFirstChildOfClass("TextLabel")
                            if textLabel then
                                text = tostring(textLabel.Text or "")
                            end
                        end
                        -- Conditions: nom 'Shop'/'Boutique', ou texte 'SHOP'/'BOUTIQUE' ou l'emoji 🏪
                        if name:find("Shop") or name:find("Boutique") or text:find("SHOP") or text:find("BOUTIQUE") or text:find("🏪") then
                            candidate = obj
                            break
                        end
                    end
                end
                if candidate then break end
            end
        end
        return candidate
    end

    local function createShopEffect(btn)
        if not btn or not btn.Parent then return nil end
        -- Nettoyer un ancien highlight local
        local oldLocal = btn:FindFirstChild("ShopHighlightTutorial")
        if oldLocal then oldLocal:Destroy() end
        -- Créer un highlight compact en tant qu'enfant du bouton
        local h = Instance.new("Frame")
        h.Name = "ShopHighlightTutorial"
        h.Size = UDim2.new(1, 12, 1, 12)
        h.Position = UDim2.new(0, -6, 0, -6)
        h.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        h.BackgroundTransparency = 0.65
        h.BorderSizePixel = 0
        h.ZIndex = (btn.ZIndex or 1) + 1
        h.Parent = btn
        local c = Instance.new("UICorner", h); c.CornerRadius = UDim.new(0, 10)
        local s = Instance.new("UIStroke", h); s.Color = Color3.fromRGB(255, 215, 0); s.Thickness = 3; s.Transparency = 0.35
        TweenService:Create(h, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.35,
            Size = UDim2.new(1, 18, 1, 18),
            Position = UDim2.new(0, -9, 0, -9)
        }):Play()
        
        -- Pas de flèche pour le bouton SHOP (le highlight suffit)
        
        return h
    end

    local shopButton = findShopButton()
    if not shopButton then
        print("⚠️ [TUTORIAL] Bouton SHOP non trouvé – retry programmé")
        -- Rechercher à intervalles jusqu'à ce que le bouton apparaisse
        task.spawn(function()
            for _ = 1, 20 do
                if currentStep ~= "BUY_SUGAR" then return end
                local btn = findShopButton()
                if btn then
                    if currentStep == "BUY_SUGAR" then
                        -- Créer le highlight du bouton shop
                        local shopHighlight = createShopEffect(btn)
                        -- Attendre que le shop s'ouvre pour surligner l'item sucre
                        task.wait(0.5)
                        -- Vérifier si le shop est ouvert
                        local shopOpened = false
                        for i = 1, 10 do
                            local menuGui = playerGui:FindFirstChild("MenuAchatGUI")
                            if menuGui and menuGui.Enabled then
                                shopOpened = true
                                break
                            end
                            task.wait(0.2)
                        end
                        if shopOpened then
                            -- Nettoyer le highlight du bouton shop
                            if shopHighlight then shopHighlight:Destroy() end
                            -- Surligner les items sucre ET gélatine dans le shop
                            currentHighlight = highlightShopItem({"Sucre", "Gelatine"})
                        end
                    end
                    return
                end
                task.wait(0.2)
            end
        end)
        return nil
    end
    
    print("✅ [TUTORIAL] Bouton SHOP trouvé:", shopButton:GetFullName())
    return createShopEffect(shopButton)
end

--------------------------------------------------------------------
-- GESTION DES ÉTAPES DU TUTORIEL
--------------------------------------------------------------------
local function cleanupTutorialElements(keepIngredientHighlights)
    -- keepIngredientHighlights = true pour garder les highlights des ingrédients (Sucre/Gélatine)
    keepIngredientHighlights = keepIngredientHighlights or false
    
    -- Supprimer les éléments existants
    if currentMessage then
        currentMessage:Destroy()
        currentMessage = nil
    end
    
    if currentArrow then
        currentArrow:Destroy()
        currentArrow = nil
    end
    
    -- Nettoyer les flèches 3D
    if current3DArrow then
        current3DArrow:Destroy()
        current3DArrow = nil
    end
    
    -- Ne pas supprimer currentHighlight si on garde les highlights des ingrédients
    if currentHighlight and not keepIngredientHighlights then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    
    -- Nettoyage robuste : supprimer tous les éléments du tutoriel restants
    if tutorialGui then
        for _, child in pairs(tutorialGui:GetChildren()) do
            if child.Name == "MessageFrame" or child.Name == "ArrowFrame" or child.Name:find("Tutorial") then
                child:Destroy()
            end
        end
    end
    
    -- Nettoyer les surbrillances dans le workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "TutorialHighlight" then
            obj:Destroy()
        end
    end
    
    -- Nettoyer les surbrillances dans l'interface
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in pairs(gui:GetDescendants()) do
                -- Si on veut garder les highlights des ingrédients, ne pas les supprimer
                local isIngredientHighlight = obj.Name:find("TutorialHighlight_Sucre") or 
                                              obj.Name:find("TutorialHighlight_Gelatine") or
                                              obj.Name:find("TutorialSlotArrow_")
                
                if keepIngredientHighlights and isIngredientHighlight then
                    print("🔒 [TUTORIAL] Conservation de:", obj.Name)
                elseif not (keepIngredientHighlights and isIngredientHighlight) then
                    if obj.Name == "ShopItemHighlight" or obj.Name == "ButtonHighlight" or obj.Name == "PurchaseArrow" or 
                       obj.Name == "TutorialSugarArrow" or obj.Name == "TutorialSlotsArrow" or 
                       obj.Name == "TutorialHighlight" or obj.Name == "TutorialArrow" or obj.Name == "TutorialSlotHighlight" or
                       obj.Name:find("TutorialHighlight_") or obj.Name:find("TutorialSlotArrow_") then
                        print("🗑️ [TUTORIAL] Suppression de:", obj.Name)
                        obj:Destroy()
                    end
                end
            end
        end
    end
    

    
    -- Déconnecter les connexions
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    connections = {}
end

local function handleTutorialStep(step, data)
    -- Garder les highlights des ingrédients pendant les étapes de l'incubateur
    local incubatorSteps = {
        "INCUBATOR_UI_GUIDE",
        "PLACE_IN_SLOTS",
        "SELECT_RECIPE",
        "CONFIRM_PRODUCTION"
    }
    local keepHighlights = false
    for _, incStep in ipairs(incubatorSteps) do
        if step == incStep then
            keepHighlights = true
            break
        end
    end
    
    -- Respecter le flag keep_highlights envoyé par le serveur
    if data.keep_highlights then
        keepHighlights = true
    end
    
    if keepHighlights then
        print("🔒 [TUTORIAL] Étape", step, "- Highlights des ingrédients CONSERVÉS")
    else
        print("🧹 [TUTORIAL] Étape", step, "- Nettoyage complet")
    end
    
    cleanupTutorialElements(keepHighlights)
    currentStep = step
    
    -- Créer le message (passer le nom de l'étape pour positionnement spécial)
    currentMessage = createMessageBox(data.title, data.message, step)
    
    -- Créer la flèche si nécessaire
    if data.arrow_target then
        local targetPos
        local targetObject
        
        if typeof(data.arrow_target) == "Vector3" then
            targetPos = data.arrow_target
        elseif typeof(data.arrow_target) == "Instance" and data.arrow_target:IsA("BasePart") then
            targetPos = data.arrow_target.Position
            targetObject = data.arrow_target
        elseif data.arrow_target == "vendor" then
            -- Chercher le vendeur avec une recherche robuste
            local function findVendorPart()
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj.Name == "Vendeur" or obj.Name == "VendeurPNJ" then
                        if obj:IsA("BasePart") then
                            return obj, obj.Position
                        elseif obj:IsA("Model") and obj.PrimaryPart then
                            return obj.PrimaryPart, obj.PrimaryPart.Position
                        elseif obj:IsA("Model") then
                            local firstPart = obj:FindFirstChildOfClass("BasePart")
                            if firstPart then
                                return firstPart, firstPart.Position
                            end
                        end
                    end
                end
                
                -- Chercher via ClickDetector
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ClickDetector") and obj.Parent and obj.Parent:IsA("BasePart") then
                        local grandParent = obj.Parent.Parent
                        if grandParent and grandParent.Name:lower():find("vendeur") then
                            return obj.Parent, obj.Parent.Position
                        end
                    end
                end
                
                return nil, nil
            end
            
            targetObject, targetPos = findVendorPart()
        end
        
        if targetPos then
            currentArrow = createArrow(targetPos, targetObject)
            
            -- Mettre à jour la position de la flèche en continu si l'objet bouge
            if targetObject then
                connections[#connections + 1] = RunService.Heartbeat:Connect(function()
                    if targetObject and targetObject.Parent then
                        -- Pointer vers le sol près de l'objet, pas vers l'objet lui-même
                        local groundPos = Vector3.new(targetObject.Position.X, targetObject.Position.Y - 2, targetObject.Position.Z)
                        updateArrowPosition(currentArrow, groundPos)
                    end
                end)
            else
                -- Position fixe
                connections[#connections + 1] = RunService.Heartbeat:Connect(function()
                    updateArrowPosition(currentArrow, targetPos)
                end)
            end
        end
        
        -- 🎯 CRÉER AUSSI LES FLÈCHES 3D (chemin animé)
        if targetObject then
            local success, result = pcall(function()
                return TutorialArrowSystem.CreateArrowPath(player, targetObject)
            end)
            
            if success and result then
                current3DArrow = result
                print("✨ [TUTORIAL CLIENT] Flèches 3D créées localement")
            else
                warn("❌ [TUTORIAL CLIENT] Erreur création flèches 3D:", result)
            end
        end
    end
    
    -- Créer la surbrillance si nécessaire
    if data.highlight_target then
        if typeof(data.highlight_target) == "Instance" then
            currentHighlight = createHighlight(data.highlight_target)
        elseif data.highlight_target == "Sucre" or data.highlight_target == "sucre" or data.highlight_shop_item then
            -- Surligner Sucre ET Gélatine ensemble
            local itemToHighlight = data.highlight_target or data.highlight_shop_item
            if itemToHighlight == "Sucre" or itemToHighlight == "sucre" then
                currentHighlight = highlightShopItem({"Sucre", "Gelatine"})
            else
                currentHighlight = highlightShopItem(itemToHighlight)
            end
        elseif data.highlight_target == "sell_button_v2" then
            currentHighlight = highlightSellButton()
            -- Effet accentué: double glow + pulsation de taille
            if currentHighlight then
                local pulse = TweenService:Create(currentHighlight, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                    Size = UDim2.new(1, 18, 1, 18),
                    Position = UDim2.new(0, -9, 0, -9)
                })
                pulse:Play()
                local extra = Instance.new("UIStroke")
                extra.Color = Color3.fromRGB(255, 255, 180)
                extra.Thickness = 4
                extra.Transparency = 0.3
                extra.Parent = currentHighlight
                TweenService:Create(extra, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                    Thickness = 1,
                    Transparency = 0.7
                }):Play()
            end
        end
    end
    
    -- Jouer un son (sauf si désactivé)
    if not data.no_sound then
        task.spawn(function()
            -- Priorité 1: SoundService.TutorialPing (à créer dans Studio avec votre SoundId)
            local baseSound = SoundService:FindFirstChild("TutorialPing")
            local sound

            if baseSound and baseSound:IsA("Sound") then
                sound = baseSound:Clone()
            else
                -- Priorité 2: ReplicatedStorage/TutorialSoundId (StringValue avec rbxassetid://...)
                local cfg = ReplicatedStorage:FindFirstChild("TutorialSoundId")
                sound = Instance.new("Sound")
                if cfg and cfg:IsA("StringValue") and cfg.Value ~= "" then
                    sound.SoundId = cfg.Value
                else
                    -- Repli: son par défaut Roblox
                    sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
                end
                sound.Volume = 0.5
            end

            sound.Parent = SoundService
            sound:Play()
            sound.Ended:Connect(function()
                sound:Destroy()
            end)
        end)
    end
end

--------------------------------------------------------------------
-- HOOKS DANS LES SCRIPTS EXISTANTS
--------------------------------------------------------------------
local function hookVendorScript()
    -- Hook dans le script du vendeur
    local ouvrirMenuEvent = ReplicatedStorage:FindFirstChild("OuvrirMenuEvent")
    if ouvrirMenuEvent then
        ouvrirMenuEvent.OnClientEvent:Connect(function()
            if currentStep == "TALK_TO_VENDOR" then
                tutorialRemote:FireServer("vendor_clicked")
            end
        end)
    end
end

local function hookIncubatorScript()
    -- Hook dans le script de l'incubateur
    local incubatorEvent = ReplicatedStorage:FindFirstChild("IncubatorEvent")
    if incubatorEvent then
        incubatorEvent.OnClientEvent:Connect(function(action)
            if action == "menu_opened" and currentStep == "GO_TO_INCUBATOR" then
                tutorialRemote:FireServer("incubator_used")
            end
        end)
    end
end

--------------------------------------------------------------------
-- DÉTECTION DES INTERACTIONS
--------------------------------------------------------------------
local function detectCandyCreation()
    -- Surveiller la création de bonbons
    local candyFolder = workspace:FindFirstChild("Candies")
    if candyFolder then
        connections[#connections + 1] = candyFolder.ChildAdded:Connect(function(candy)
            if currentStep == "CREATE_CANDY" then
                task.wait(0.5) -- Attendre un peu pour que le bonbon soit bien créé
                tutorialRemote:FireServer("candy_created")
            end
        end)
    end
end

local function detectCandyPickup()
    -- Surveiller le ramassage de bonbons
    local pickupEvent = ReplicatedStorage:FindFirstChild("PickupCandyEvent")
    if pickupEvent then
        print("🍭 [TUTORIAL] Détection pickup configurée pour:", pickupEvent.Name)
        
        -- 🐛 BUG FIX: Pas besoin de détection client spéciale
        -- Le serveur gère déjà tout dans IncubatorServer.lua via PickupCandyEvent
        
        -- Garder l'écoute du RemoteEvent au cas où le serveur veut envoyer une confirmation
        connections[#connections + 1] = pickupEvent.OnClientEvent:Connect(function()
            print("🍭 [TUTORIAL] PickupCandyEvent reçu du serveur")
            print("🍭 [TUTORIAL] Étape client actuelle:", currentStep)
            if currentStep == "PICKUP_CANDY" then
                print("🍭 [TUTORIAL] Envoi confirmation ramassage au tutoriel")
                tutorialRemote:FireServer("candy_picked_up")
            else
                print("🍭 [TUTORIAL] Étape incorrecte pour ramassage. Attendu: PICKUP_CANDY, Actuel:", currentStep)
            end
        end)
        
        -- Détection robuste via inventaire + équipement
        local players = game:GetService("Players")
        local player = players.LocalPlayer
        
        -- 1. Vérifier immédiatement si un bonbon existe déjà
        local function checkExistingCandies()
            if currentStep ~= "PICKUP_CANDY" then return end
            
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, item in pairs(backpack:GetChildren()) do
                    if item:IsA("Tool") and item.Name:find("Bonbon") then
                        print("🍭 [TUTORIAL] Bonbon déjà présent dans inventaire:", item.Name)
                        tutorialRemote:FireServer("candy_picked_up")
                        return
                    end
                end
            end
            
            -- Vérifier aussi le personnage
            if player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    for _, item in pairs(humanoid:GetChildren()) do
                        if item:IsA("Tool") and item.Name:find("Bonbon") then
                            print("🍭 [TUTORIAL] Bonbon déjà équipé:", item.Name)
                            tutorialRemote:FireServer("candy_picked_up")
                            return
                        end
                    end
                end
            end
        end
        
        -- Vérification immédiate
        checkExistingCandies()
        
        -- 2. Écouter les nouveaux ajouts dans le sac
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            connections[#connections + 1] = backpack.ChildAdded:Connect(function(child)
                print("🍭 [TUTORIAL] Nouvel objet dans sac:", child.Name, "- Type:", child.ClassName)
                print("🍭 [TUTORIAL] Étape actuelle:", currentStep)
                if child:IsA("Tool") and child.Name:find("Bonbon") and currentStep == "PICKUP_CANDY" then
                    print("🍭 [TUTORIAL] Bonbon ajouté au sac (backup):", child.Name)
                    -- Pas d'attente, envoi immédiat
                    tutorialRemote:FireServer("candy_picked_up")
                elseif child:IsA("Tool") and child.Name:find("Bonbon") then
                    print("🍭 [TUTORIAL] Bonbon détecté mais mauvaise étape. Attendu: PICKUP_CANDY, Actuel:", currentStep)
                end
            end)
        end
        
        -- 3. Écouter les équipements sur le personnage
        local function setupCharacterListener(character)
            if not character then return end
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                connections[#connections + 1] = humanoid.ChildAdded:Connect(function(child)
                    if child:IsA("Tool") and child.Name:find("Bonbon") and currentStep == "PICKUP_CANDY" then
                        print("🍭 [TUTORIAL] Bonbon équipé (backup):", child.Name)
                        tutorialRemote:FireServer("candy_picked_up")
                    end
                end)
            end
        end
        
        if player.Character then
            setupCharacterListener(player.Character)
        end
        
        connections[#connections + 1] = player.CharacterAdded:Connect(setupCharacterListener)
    else
        warn("⚠️ [TUTORIAL] PickupCandyEvent non trouvé dans ReplicatedStorage")
    end
end

--------------------------------------------------------------------
-- INITIALISATION
--------------------------------------------------------------------
local function initialize()
    createTutorialGui()
    
    -- Écouter les étapes du tutoriel
    tutorialStepRemote.OnClientEvent:Connect(function(step, data)
        currentStep = step
        _G.CurrentTutorialStep = step -- 🌐 Exposer globalement
        print("📋 [TUTORIAL] Étape actuelle mise à jour:", step)
        
        -- Nettoyer les anciens éléments
        cleanupTutorialElements()
        
        if step == "WELCOME" then
            handleTutorialStep(step, data)
            
        elseif step == "GO_TO_VENDOR" then
            handleTutorialStep(step, data)
            if data.arrow_target then
                createArrow(data.arrow_target)
            end
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "TALK_TO_VENDOR" then
            handleTutorialStep(step, data)
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "BUY_SUGAR" then
            handleTutorialStep(step, data)
            -- Si keep_highlights est true, c'est une mise à jour après achat
            -- Ne pas recréer le highlight du bouton Shop, mais recréer les highlights des items
            if not data.keep_highlights then
                -- Premier affichage: highlight le bouton SHOP
                currentHighlight = highlightShopButton()
            else
                -- Mise à jour après achat: recréer les highlights UNIQUEMENT des items qui restent à acheter
                task.spawn(function()
                    task.wait(0.3) -- Attendre que le menu se rafraîchisse
                    local itemsToHighlight = data.items_to_highlight or {"Sucre", "Gelatine"}
                    if #itemsToHighlight > 0 then
                        currentHighlight = highlightShopItem(itemsToHighlight)
                    end
                end)
            end
            
        elseif step == "GO_TO_INCUBATOR" then
            handleTutorialStep(step, data)
            if data.arrow_target then
                createArrow(data.arrow_target)
            end
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "EQUIP_SUGAR" then
            handleTutorialStep(step, data)
            -- Pas de surbrillance spécifique car c'est dans l'interface du backpack
            
        elseif step == "PLACE_INGREDIENTS" then
            handleTutorialStep(step, data)
            if data.arrow_target then
                createArrow(data.arrow_target)
            end
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "OPEN_INCUBATOR" then
            handleTutorialStep(step, data)
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            -- Highlight du bouton PRODUCE directement (plus besoin d'UNLOCK)
            task.spawn(function()
                local maxAttempts = 20
                local attempt = 0
                local found = false
                
                while attempt < maxAttempts and not found do
                    attempt = attempt + 1
                    task.wait(0.2)
                    
                    local incubatorGui = playerGui:FindFirstChild("IncubatorMenuNew") or playerGui:FindFirstChild("IncubatorMenu_v4")
                    if incubatorGui then
                        local mainFrame = incubatorGui:FindFirstChild("MainFrame")
                        if mainFrame then
                            local recipeList = mainFrame:FindFirstChild("RecipeList")
                            if recipeList then
                                print("🔍 [TUTORIAL] Recherche PRODUCE (attempt " .. attempt .. "), RecipeList enfants:", #recipeList:GetChildren())
                                -- Chercher le bouton PRODUCE (peut être "▶ PRODUCE" ou "PRODUCE")
                                for _, descendant in pairs(recipeList:GetDescendants()) do
                                    if descendant:IsA("TextButton") then
                                        print("  🔘 Bouton trouvé:", descendant.Text)
                                    end
                                    if descendant:IsA("TextButton") and (descendant.Text:find("PRODUCE") or descendant.Name == "ProduceButton") then
                                        -- Supprimer l'ancien highlight si existe
                                        local oldHighlight = descendant:FindFirstChild("TutorialHighlight_PRODUCE")
                                        if oldHighlight then oldHighlight:Destroy() end
                                        
                                        -- Créer un highlight sur le bouton
                                        local highlight = Instance.new("Frame")
                                        highlight.Name = "TutorialHighlight_PRODUCE"
                                        highlight.Size = UDim2.new(1, 8, 1, 8)
                                        highlight.Position = UDim2.new(0, -4, 0, -4)
                                        highlight.BackgroundTransparency = 1
                                        highlight.BorderSizePixel = 0
                                        highlight.ZIndex = descendant.ZIndex + 1
                                        highlight.Parent = descendant
                                        
                                        local stroke = Instance.new("UIStroke")
                                        stroke.Color = Color3.fromRGB(255, 215, 0)
                                        stroke.Thickness = 4
                                        stroke.Transparency = 0.2
                                        stroke.Parent = highlight
                                        
                                        local corner = Instance.new("UICorner")
                                        corner.CornerRadius = UDim.new(0, 8)
                                        corner.Parent = highlight
                                        
                                        -- Animation de pulsation
                                        local pulse = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                                            Thickness = 5,
                                            Transparency = 0
                                        })
                                        pulse:Play()
                                        
                                        print("✅ [TUTORIAL] Bouton PRODUCE highlighted (attempt " .. attempt .. ")")
                                        found = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                
                if not found then
                    print("❌ [TUTORIAL] Bouton PRODUCE non trouvé après " .. maxAttempts .. " tentatives")
                end
            end)
            
        elseif step == "VIEW_RECIPE" then
            handleTutorialStep(step, data)
            -- Highlight du bouton PRODUCE dans l'interface incubateur
            task.spawn(function()
                local maxAttempts = 20
                local attempt = 0
                local found = false
                
                while attempt < maxAttempts and not found do
                    attempt = attempt + 1
                    task.wait(0.2)
                    
                    local incubatorGui = playerGui:FindFirstChild("IncubatorMenu_v4")
                    if incubatorGui then
                        local mainFrame = incubatorGui:FindFirstChild("MainFrame")
                        if mainFrame then
                            local recipeList = mainFrame:FindFirstChild("RecipeList")
                            if recipeList then
                                print("🔍 [TUTORIAL] Recherche PRODUCE (attempt " .. attempt .. "), RecipeList enfants:", #recipeList:GetChildren())
                                -- Chercher le bouton PRODUCE (peut être "▶ PRODUCE" ou "PRODUCE")
                                for _, descendant in pairs(recipeList:GetDescendants()) do
                                    if descendant:IsA("TextButton") then
                                        print("  🔘 Bouton trouvé:", descendant.Text)
                                    end
                                    if descendant:IsA("TextButton") and (descendant.Text:find("PRODUCE") or descendant.Text == "▶ PRODUCE") then
                                        -- Supprimer l'ancien highlight si existe
                                        local oldHighlight = descendant:FindFirstChild("TutorialHighlight_PRODUCE")
                                        if oldHighlight then oldHighlight:Destroy() end
                                        
                                        -- Créer un highlight sur le bouton
                                        local highlight = Instance.new("Frame")
                                        highlight.Name = "TutorialHighlight_PRODUCE"
                                        highlight.Size = UDim2.new(1, 8, 1, 8)
                                        highlight.Position = UDim2.new(0, -4, 0, -4)
                                        highlight.BackgroundTransparency = 1
                                        highlight.BorderSizePixel = 0
                                        highlight.ZIndex = descendant.ZIndex + 1
                                        highlight.Parent = descendant
                                        
                                        local stroke = Instance.new("UIStroke")
                                        stroke.Color = Color3.fromRGB(255, 215, 0)
                                        stroke.Thickness = 4
                                        stroke.Transparency = 0.2
                                        stroke.Parent = highlight
                                        
                                        local corner = Instance.new("UICorner")
                                        corner.CornerRadius = UDim.new(0, 8)
                                        corner.Parent = highlight
                                        
                                        -- Animation de pulsation
                                        local pulse = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                                            Thickness = 5,
                                            Transparency = 0
                                        })
                                        pulse:Play()
                                        
                                        print("✅ [TUTORIAL] Bouton PRODUCE highlighted (attempt " .. attempt .. ")")
                                        found = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                
                if not found then
                    print("❌ [TUTORIAL] Bouton PRODUCE non trouvé après " .. maxAttempts .. " tentatives")
                end
            end)
            
        elseif step == "WAIT_PRODUCTION" then
            handleTutorialStep(step, data)
            
        -- 💡 NOUVEAU: Guide spécialisé interface incubateur
        elseif step == "INCUBATOR_UI_GUIDE" then
            handleTutorialStep(step, data)
            
            -- Créer des flèches spécialisées pour l'interface incubateur
            if data.tutorial_phase == "click_ingredient" then
                task.spawn(createIncubatorUIArrows)
            end
            
        -- 💡 NOUVEAU: Étape placement ingrédients dans slots
        elseif step == "PLACE_IN_SLOTS" then
            handleTutorialStep(step, data)
            
            -- Cette étape utilise la surbrillance automatique des slots vides déjà implémentée
            
        elseif step == "SELECT_RECIPE" then
            handleTutorialStep(step, data)
            -- La surbrillance de la recette sera gérée par l'interface de l'incubateur
            
        elseif step == "CONFIRM_PRODUCTION" then
            handleTutorialStep(step, data)
            -- La surbrillance du bouton sera gérée par l'interface de l'incubateur
            
        elseif step == "CREATE_CANDY" then
            handleTutorialStep(step, data)
            
        elseif step == "PICKUP_CANDY" then
            handleTutorialStep(step, data)
            
        elseif step == "OPEN_BAG" then
            handleTutorialStep(step, data)
            
        elseif step == "SELL_CANDY" then
            handleTutorialStep(step, data)
            -- Highlight les boutons SELL dans le menu de vente (si ouvert)
            task.spawn(function()
                task.wait(0.5) -- Attendre que le menu s'ouvre
                highlightSellButtonsInMenu()
            end)
            
        -- 🆕 NOUVELLES ÉTAPES: PLATEFORMES
        elseif step == "GO_TO_PLATFORM" then
            handleTutorialStep(step, data)
            if data.arrow_target then
                createArrow(data.arrow_target)
            end
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "UNLOCK_PLATFORM" then
            handleTutorialStep(step, data)
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "PLACE_CANDY_ON_PLATFORM" then
            handleTutorialStep(step, data)
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "COLLECT_MONEY" then
            handleTutorialStep(step, data)
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            
        elseif step == "COMPLETED" then
            handleTutorialStep(step, data)
            task.wait(5)
            cleanupTutorialElements()
        end
    end)
    
    -- Hooks dans les scripts existants
    hookVendorScript()
    hookIncubatorScript()
    
    -- Détection des interactions
    detectCandyCreation()
    detectCandyPickup()
    
    -- Écouter les événements directs du tutoriel (comme candy_sold)
    local tutorialRemote = ReplicatedStorage:FindFirstChild("TutorialRemote")
    if tutorialRemote then
        tutorialRemote.OnClientEvent:Connect(function(eventName, data)
            if eventName == "candy_sold" then
                print("🎓 [TUTORIAL] Événement candy_sold reçu")
                -- Renvoyer au serveur pour traitement
                tutorialRemote:FireServer("candy_sold")
            elseif eventName == "candy_placed_on_platform" then
                print("🎓 [TUTORIAL] Événement candy_placed_on_platform reçu")
                tutorialRemote:FireServer("candy_placed_on_platform", data)
            end
        end)
    end
    
    -- Surveiller l'ouverture du CandySellUI pendant l'étape SELL_CANDY
    task.spawn(function()
        while true do
            task.wait(0.5)
            if currentStep == "SELL_CANDY" then
                local candySellUI = playerGui:FindFirstChild("CandySellUI")
                if candySellUI and candySellUI.Enabled then
                    -- Le menu est ouvert, créer les highlights
                    highlightSellButtonsInMenu()
                end
            end
        end
    end)
    
    print("🎓 TutorialClient initialisé")
end

-- Nettoyage à la déconnexion
Players.PlayerRemoving:Connect(function(leavingPlayer)
    if leavingPlayer == player then
        cleanupTutorialElements()
    end
end)

-- Initialiser quand le script se charge
initialize() 