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
local function createMessageBox(title, message)
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
    -- Plus haut et légèrement plus à droite
    messageFrame.Position = isMobile and UDim2.new(0.68, 0, 0.028, 0) or UDim2.new(0.5, 0, 0.095, 0)
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
    
    -- 🚑 BOUTON DE SECOURS pour étapes PICKUP_CANDY et CREATE_CANDY
    if title:find("Ramasse") or title:find("Production in progress") or title:find("Wait") then
        local emergencyButton = Instance.new("TextButton")
        emergencyButton.Name = "EmergencyButton"
        emergencyButton.Size = UDim2.new(0, 200, 0, 30)
        emergencyButton.Position = UDim2.new(0.5, -100, 1, -35)
        emergencyButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        emergencyButton.Text = "J'AI DÉJÀ LE BONBON !"
        emergencyButton.TextColor3 = Color3.new(1, 1, 1)
        emergencyButton.TextSize = 12
        emergencyButton.Font = Enum.Font.GothamBold
        emergencyButton.Parent = messageFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = emergencyButton
        
        emergencyButton.MouseButton1Click:Connect(function()
            print("🚑 [TUTORIAL] Bouton secours activé - Force passage à l'étape suivante")
            
            -- Détecter l'étape et envoyer la bonne action
            if title:find("Production in progress") or title:find("Attends") then
                -- On est à l'étape CREATE_CANDY, il faut d'abord passer à PICKUP_CANDY
                print("🚑 [TUTORIAL] Force transition CREATE_CANDY -> PICKUP_CANDY")
                tutorialRemote:FireServer("candy_created")
                task.wait(0.5) -- Petite attente
                tutorialRemote:FireServer("candy_picked_up")
            else
                -- On est déjà à PICKUP_CANDY, juste passer à la suite
                print("🚑 [TUTORIAL] Force transition PICKUP_CANDY -> OPEN_BAG")
                tutorialRemote:FireServer("candy_picked_up")
            end
            
            emergencyButton:Destroy()
        end)
        
        -- Petit effet de clignotement
        local blinkTween = TweenService:Create(emergencyButton, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundColor3 = Color3.fromRGB(255, 150, 150)
        })
        blinkTween:Play()
    end
    
    return messageFrame
end



--------------------------------------------------------------------
-- SYSTÈME DE FLÈCHES
--------------------------------------------------------------------
local function createArrow(targetPosition)
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
    
    -- Positionner la flèche
    local camera = workspace.CurrentCamera
    if camera and targetPosition then
        local screenPoint, onScreen = camera:WorldToScreenPoint(targetPosition)
        
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
    -- Chercher l'interface de l'incubateur ouverte
    local incubatorGui = playerGui:FindFirstChild("IncubatorMenuGUI")
    if not incubatorGui then
        print("🎯 [TUTORIAL] Interface incubateur non trouvée")
        return
    end
    
    local mainFrame = incubatorGui:FindFirstChild("MainFrame")
    if not mainFrame then
        print("🎯 [TUTORIAL] MainFrame incubateur non trouvé")
        return
    end
    
    -- Chercher la zone d'inventaire (gauche)
    local inventoryArea = mainFrame:FindFirstChild("InventoryArea")
    local inventoryScroll = inventoryArea and inventoryArea:FindFirstChild("InventoryScrollFrame")
    
    if inventoryScroll then
        -- Chercher l'élément sucre dans l'inventaire
        local sugarItem = nil
        for _, child in pairs(inventoryScroll:GetChildren()) do
            if child.Name:find("InventoryItem_Sucre") then
                sugarItem = child
                break
            end
        end
        
        if sugarItem then
            -- Créer une flèche pointant vers le sucre
            local sugarArrow = Instance.new("TextLabel")
            sugarArrow.Name = "TutorialSugarArrow"
            sugarArrow.Size = UDim2.new(0, 120, 0, 40)
            sugarArrow.Position = UDim2.new(1, 10, 0.5, -20) -- À droite du sucre
            sugarArrow.BackgroundTransparency = 1
            sugarArrow.Text = "👈 CLICK HERE!"
            sugarArrow.TextColor3 = Color3.fromRGB(255, 255, 0)
            sugarArrow.TextSize = 18
            sugarArrow.Font = Enum.Font.GothamBold
            sugarArrow.TextStrokeTransparency = 0
            sugarArrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            sugarArrow.ZIndex = 20
            sugarArrow.Parent = sugarItem
            
            -- Animation de rebond
            local bounce = TweenService:Create(sugarArrow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Position = UDim2.new(1, 15, 0.5, -20),
                TextSize = 20
            })
            bounce:Play()
            
            print("🎯 [TUTORIAL] Flèche sucre créée")
        else
            print("🎯 [TUTORIAL] Élément sucre non trouvé dans l'inventaire")
        end
    end
    
    -- Créer une seconde flèche vers la zone des slots (après 2 secondes)
    task.spawn(function()
        task.wait(2)
        
        local craftingArea = mainFrame:FindFirstChild("CraftingArea")
        if craftingArea then
            local slotsArrow = Instance.new("TextLabel")
            slotsArrow.Name = "TutorialSlotsArrow"
            slotsArrow.Size = UDim2.new(0, 200, 0, 50)
            slotsArrow.Position = UDim2.new(0, -210, 0, 20)
            slotsArrow.BackgroundTransparency = 1
            slotsArrow.Text = "👉 THEN CLICK ON A SLOT!"
            slotsArrow.TextColor3 = Color3.fromRGB(0, 255, 255)
            slotsArrow.TextSize = 16
            slotsArrow.Font = Enum.Font.GothamBold
            slotsArrow.TextStrokeTransparency = 0
            slotsArrow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            slotsArrow.ZIndex = 20
            slotsArrow.Parent = craftingArea
            
            -- Animation de brillance
            local glow = TweenService:Create(slotsArrow, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                TextTransparency = 0.3,
                TextSize = 18
            })
            glow:Play()
            
            print("🎯 [TUTORIAL] Flèche slots créée")
        end
    end)
end

--------------------------------------------------------------------
-- SYSTÈME DE ROTATION DE CAMÉRA
--------------------------------------------------------------------
local lockedCameraConnection = nil
local originalCameraType = nil
local _originalCFrame = nil
local unlockCamera -- Pré-déclaration pour éviter l'appel d'une globale avant définition
local currentTargetObject = nil

local function lockCameraOnTarget(targetPosition, lockDuration, targetObject)
    lockDuration = lockDuration or 0 -- 0 = verrouillage permanent jusqu'à déverrouillage manuel
    
    local camera = workspace.CurrentCamera
    
    -- Sauvegarder les paramètres originaux
    if not originalCameraType then
        originalCameraType = camera.CameraType
        _originalCFrame = camera.CFrame
    end
    
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    
    -- Rester en mode Custom pour garder le suivi du joueur
    -- Mais forcer l'orientation vers la cible
    
    -- Sauvegarder la cible
    currentTargetObject = targetObject
    
    -- Maintenir la caméra orientée vers la cible tout en suivant le joueur
    if lockedCameraConnection then
        lockedCameraConnection:Disconnect()
    end
    
    lockedCameraConnection = RunService.Heartbeat:Connect(function()
        if camera and camera.Parent and character and humanoidRootPart and humanoidRootPart.Parent then
            -- Position de la caméra : suivre le joueur avec un offset
            local playerPosition = humanoidRootPart.Position
            local offset = Vector3.new(0, 6, 8) -- Derrière et légèrement au-dessus du joueur
            local cameraPosition = playerPosition + offset
            
            -- Mettre à jour la position de la cible si c'est un objet mobile
            local currentTargetPos = targetPosition
            if currentTargetObject and currentTargetObject.Parent and currentTargetObject:IsA("BasePart") then
                currentTargetPos = currentTargetObject.Position
            end
            
            -- Orientation : regarder vers la cible du tutoriel
            local targetCFrame = cameraPosition
            if currentTargetPos and typeof(currentTargetPos) == "Vector3" then
                targetCFrame = CFrame.lookAt(cameraPosition, currentTargetPos)
            else
                targetCFrame = CFrame.new(cameraPosition)
            end
            
            -- Appliquer en douceur pour éviter les saccades
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, 0.05)
        end
    end)
    
    print("🎥 [TUTORIAL] Caméra focalisée sur la cible (suit le joueur)")
    
    -- Déverrouillage automatique après un délai (si spécifié)
    if lockDuration > 0 then
        task.spawn(function()
            task.wait(lockDuration)
            unlockCamera()
        end)
    end
    
    return nil -- Pas d'animation initiale, juste le suivi continu
end

unlockCamera = function()
    -- Déconnecter le verrouillage d'orientation
    if lockedCameraConnection then
        lockedCameraConnection:Disconnect()
        lockedCameraConnection = nil
    end
    
    -- Nettoyer les variables
    currentTargetObject = nil
    originalCameraType = nil
    _originalCFrame = nil
    
    print("🎥 [TUTORIAL] Caméra déverrouillée - contrôle rendu au joueur")
end

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
    -- Chercher l'élément dans tous les ScreenGui possibles
    local shopHighlight = nil
    
    -- Fonction pour trouver et surligner l'item
    local function findAndHighlightItem()
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                -- Chercher récursivement dans tous les frames
                local function searchInFrame(frame)
                    if frame.Name == itemName then
                        -- Trouvé l'item! Créer la surbrillance subtile
                        if frame:FindFirstChild("ShopItemHighlight") then
                            frame.ShopItemHighlight:Destroy()
                        end
                        
                        -- Contour doré subtil seulement
                        local highlight = Instance.new("Frame")
                        highlight.Name = "ShopItemHighlight"
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
                                Position = UDim2.new(0, -5, 0, -5)
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
                    shopHighlight = result
                    break 
                end
            end
        end
    end
    
    -- Essayer de trouver immédiatement
    findAndHighlightItem()
    
    -- Si pas trouvé, réessayer périodiquement (le menu peut s'ouvrir plus tard)
    if not shopHighlight then
        local attempts = 0
        local maxAttempts = 20
        
        local retryConnection
        retryConnection = RunService.Heartbeat:Connect(function()
            attempts = attempts + 1
            if attempts > maxAttempts then
                retryConnection:Disconnect()
                return
            end
            
            findAndHighlightItem()
            if shopHighlight then
                retryConnection:Disconnect()
            end
        end)
    end
    
    return shopHighlight
end

-- Fonction pour surbrillancer le bouton de vente
local function highlightSellButton()
    print("💰 [TUTORIAL] Recherche du bouton de vente...")
    
    -- Chercher le bouton de vente dans la hotbar (robuste)
    local function findSellButton()
        local candidate = nil
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
        -- Essayer via référence directe exposée par le backpack
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
        -- Créer un highlight compact en tant qu'enfant du bouton
        local h = Instance.new("Frame")
        h.Name = "BaseHighlightTutorial"
        h.Size = UDim2.new(1, 12, 1, 12)
        h.Position = UDim2.new(0, -6, 0, -6)
        h.BackgroundColor3 = Color3.fromRGB(255, 235, 120)
        h.BackgroundTransparency = 0.65
        h.BorderSizePixel = 0
        h.ZIndex = (btn.ZIndex or 1) + 1
        h.Parent = btn
        local c = Instance.new("UICorner", h); c.CornerRadius = UDim.new(0, 10)
        local s = Instance.new("UIStroke", h); s.Color = Color3.fromRGB(255, 250, 160); s.Thickness = 3; s.Transparency = 0.35
        TweenService:Create(h, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            BackgroundTransparency = 0.35,
            Size = UDim2.new(1, 18, 1, 18),
            Position = UDim2.new(0, -9, 0, -9)
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

--------------------------------------------------------------------
-- GESTION DES ÉTAPES DU TUTORIEL
--------------------------------------------------------------------
local function cleanupTutorialElements()
    -- Supprimer les éléments existants
    if currentMessage then
        currentMessage:Destroy()
        currentMessage = nil
    end
    
    if currentArrow then
        currentArrow:Destroy()
        currentArrow = nil
    end
    
    if currentHighlight then
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
                if obj.Name == "ShopItemHighlight" or obj.Name == "ButtonHighlight" or obj.Name == "PurchaseArrow" or 
                   obj.Name == "TutorialSugarArrow" or obj.Name == "TutorialSlotsArrow" then
                    obj:Destroy()
                end
            end
        end
    end
    

    
    -- Déverrouiller la caméra
    unlockCamera()
    
    -- Déconnecter les connexions
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    connections = {}
end

local function handleTutorialStep(step, data)
    cleanupTutorialElements()
    currentStep = step
    
    -- Créer le message
    currentMessage = createMessageBox(data.title, data.message)
    
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
            currentArrow = createArrow(targetPos)
            
            -- Verrouiller la caméra sur la cible si spécifié
            if data.lock_camera then
                lockCameraOnTarget(targetPos, data.lock_duration or 0, targetObject)
            end
            

            
            -- Mettre à jour la position de la flèche en continu si l'objet bouge
            if targetObject then
                connections[#connections + 1] = RunService.Heartbeat:Connect(function()
                    if targetObject and targetObject.Parent then
                        updateArrowPosition(currentArrow, targetObject.Position)
                    end
                end)
            else
                -- Position fixe
                connections[#connections + 1] = RunService.Heartbeat:Connect(function()
                    updateArrowPosition(currentArrow, targetPos)
                end)
            end
        end
    end
    
    -- Créer la surbrillance si nécessaire
    if data.highlight_target then
        if typeof(data.highlight_target) == "Instance" then
            currentHighlight = createHighlight(data.highlight_target)
        elseif data.highlight_target == "Sucre" or data.highlight_target == "sucre" or data.highlight_shop_item then
            local itemToHighlight = data.highlight_target or data.highlight_shop_item
            currentHighlight = highlightShopItem(itemToHighlight)
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
            -- Pas de surbrillance car c'est dans l'interface du vendeur
            
        elseif step == "GO_TO_INCUBATOR" then
            handleTutorialStep(step, data)
            if data.arrow_target then
                createArrow(data.arrow_target)
            end
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            if data.lock_camera then
                lockCameraOnTarget(data.highlight_target)
            end
            
        elseif step == "EQUIP_SUGAR" then
            handleTutorialStep(step, data)
            -- Pas de surbrillance spécifique car c'est dans l'interface du backpack
            if data.lock_camera == false then
                unlockCamera() -- Restaurer le contrôle de la caméra
            end
            
        elseif step == "PLACE_INGREDIENTS" then
            handleTutorialStep(step, data)
            if data.arrow_target then
                createArrow(data.arrow_target)
            end
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            if data.lock_camera then
                lockCameraOnTarget(data.highlight_target)
            end
            
        elseif step == "OPEN_INCUBATOR" then
            handleTutorialStep(step, data)
            if data.highlight_target then
                createHighlight(data.highlight_target)
            end
            if data.lock_camera then
                lockCameraOnTarget(data.highlight_target)
            end
            
        -- 💡 NOUVEAU: Guide spécialisé interface incubateur
        elseif step == "INCUBATOR_UI_GUIDE" then
            handleTutorialStep(step, data)
            
            -- Libérer la caméra pour voir l'interface
            if data.lock_camera == false then
                unlockCamera()
            end
            
            -- Créer des flèches spécialisées pour l'interface incubateur
            if data.tutorial_phase == "click_ingredient" then
                createIncubatorUIArrows()
            end
            
        -- 💡 NOUVEAU: Étape placement ingrédients dans slots
        elseif step == "PLACE_IN_SLOTS" then
            handleTutorialStep(step, data)
            
            -- Libérer la caméra pour permettre l'interaction
            if data.lock_camera == false then
                unlockCamera()
            end
            
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
            
        elseif step == "COMPLETED" then
            handleTutorialStep(step, data)
            task.wait(5)
            cleanupTutorialElements()
            unlockCamera()
        end
    end)
    
    -- Hooks dans les scripts existants
    hookVendorScript()
    hookIncubatorScript()
    
    -- Détection des interactions
    detectCandyCreation()
    detectCandyPickup()
    
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