--------------------------------------------------------------------
-- TutorialManager.lua - Système de tutoriel pour nouveaux joueurs
-- Gère toutes les étapes du tutoriel de base
--------------------------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService") -- Added for proximity detection

--------------------------------------------------------------------
-- CONFIGURATION DU TUTORIEL
--------------------------------------------------------------------
local TUTORIAL_CONFIG = {
    -- Étapes du tutoriel
    STEPS = {
        "WELCOME",              -- Bienvenue
        "GO_TO_VENDOR",         -- Aller au vendeur
        "TALK_TO_VENDOR",       -- Parler au vendeur
        "BUY_SUGAR",            -- Acheter 2 sucres
        "GO_TO_INCUBATOR",      -- Aller à l'incubateur
        "EQUIP_SUGAR",          -- Équiper le sucre dans le backpack
        "PLACE_INGREDIENTS",    -- Placer les ingrédients sur l'incubateur
        "OPEN_INCUBATOR",       -- Ouvrir le menu de l'incubateur
        "SELECT_RECIPE",        -- Sélectionner une recette
        "CONFIRM_PRODUCTION",   -- Confirmer la production
        "CREATE_CANDY",         -- Créer le premier bonbon
        "PICKUP_CANDY",         -- Ramasser le bonbon
        "OPEN_BAG",             -- Ouvrir le sac à bonbons
        "SELL_CANDY",           -- Vendre le bonbon
        "COMPLETED"             -- Tutoriel terminé
    },
    
    -- Positions importantes
    VENDOR_POSITION = Vector3.new(0, 5, 0), -- À ajuster selon votre jeu
    INCUBATOR_POSITION = Vector3.new(10, 5, 10), -- À ajuster selon votre jeu
    
    -- Argent de départ pour le tutoriel
    STARTING_MONEY = 100,
    
    -- Récompense de fin de tutoriel
    COMPLETION_REWARD = 500
}

--------------------------------------------------------------------
-- VARIABLES GLOBALES
--------------------------------------------------------------------
local activeTutorials = {} -- [player] = {step, data}
local proximityConnections = {} -- [player] = {connection}

--------------------------------------------------------------------
-- DÉCLARATIONS PRÉALABLES DES FONCTIONS
--------------------------------------------------------------------
local stopProximityDetection, startProximityDetection -- Déclarations préalables

--------------------------------------------------------------------
-- FONCTIONS UTILITAIRES
--------------------------------------------------------------------
local function getTutorialStep(player)
    return activeTutorials[player] and activeTutorials[player].step or nil
end

local function setTutorialStep(player, newStep, stepData)
    if not activeTutorials[player] then
        activeTutorials[player] = {}
    end
    
    local oldStep = activeTutorials[player].step
    activeTutorials[player].step = newStep
    
    -- Ajouter les données spécifiques à l'étape si fournies
    if stepData then
        activeTutorials[player].data = stepData
    end
    
    print("🎓 [TUTORIAL]", player.Name, "passe de l'étape", oldStep or "aucune", "à", newStep)
    
    -- Arrêter la détection de proximité lors du changement d'étape
    -- sauf si on va vers une étape qui nécessite la proximité
    if newStep ~= "GO_TO_VENDOR" and newStep ~= "GO_TO_INCUBATOR" then
        stopProximityDetection(player)
    end
end

local function isPlayerInTutorial(player)
    return activeTutorials[player] ~= nil
end

stopProximityDetection = function(player)
    if proximityConnections[player] then
        proximityConnections[player].connection:Disconnect()
        proximityConnections[player] = nil
    end
end

local function completeTutorial(player)
    activeTutorials[player] = nil
    
    -- Marquer le tutoriel comme terminé dans les données du joueur
    if player:FindFirstChild("PlayerData") then
        local tutorialCompleted = Instance.new("BoolValue")
        tutorialCompleted.Name = "TutorialCompleted"
        tutorialCompleted.Value = true
        tutorialCompleted.Parent = player.PlayerData
        
        -- Donner la récompense
        if player.PlayerData:FindFirstChild("Argent") then
            player.PlayerData.Argent.Value = player.PlayerData.Argent.Value + TUTORIAL_CONFIG.COMPLETION_REWARD
        end
    end
    
    print("🎉 [TUTORIAL] " .. player.Name .. " a terminé le tutoriel!")
end

local function findVendor()
    local function getValidPart(obj)
        if obj:IsA("BasePart") then
            return obj
        end
        
        if obj:IsA("Model") then
            -- Pour un personnage/NPC, prioriser le Torso (centre visuel du corps)
            local torso = obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
            if torso then
                return torso
            end
            
            -- Essayer la tête comme point de référence visuel
            local head = obj:FindFirstChild("Head")
            if head then
                return head
            end
            
            -- Si pas de Torso ni Head, essayer HumanoidRootPart
            local humanoidRootPart = obj:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                return humanoidRootPart
            end
            
            -- Si PrimaryPart est défini
            if obj.PrimaryPart then
                return obj.PrimaryPart
            end
            
            -- En dernier recours, chercher une partie au centre
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("BasePart") and 
                   (child.Name:lower():find("torso") or 
                    child.Name:lower():find("body") or 
                    child.Name:lower():find("center") or
                    child.Name:lower():find("main")) then
                    return child
                end
            end
            
            -- Absolument dernier recours - première partie trouvée
            for _, child in pairs(obj:GetDescendants()) do
                if child:IsA("BasePart") then
                    return child
                end
            end
        end
        
        return nil
    end
    
    -- Chercher par nom exact (Vendeur, VendeurPNJ)
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "Vendeur" or obj.Name == "VendeurPNJ" then
            local validPart = getValidPart(obj)
            if validPart then
                return validPart
            end
        end
    end
    
    -- Chercher par ClickDetector (pour les NPCs avec système d'achat)
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local grandParent = parent.Parent
                if grandParent and (grandParent.Name:lower():find("vendeur") or 
                                   grandParent.Name:lower():find("vendor") or 
                                   grandParent.Name:lower():find("shop") or
                                   grandParent.Name:lower():find("pnj")) then
                    return getValidPart(grandParent) or parent
                end
            end
        end
    end
    
    -- Chercher des modèles avec des noms qui pourraient être le vendeur
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and (obj.Name:lower():find("vendeur") or 
                                obj.Name:lower():find("vendor") or 
                                obj.Name:lower():find("shop") or
                                obj.Name:lower():find("pnj") or
                                obj.Name:lower():find("npc")) then
            local validPart = getValidPart(obj)
            if validPart then
                return validPart
            end
        end
    end
    
    -- Recherche élargie : chercher des modèles de personnages avec ClickDetector
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChildOfClass("ClickDetector") then
            local validPart = getValidPart(obj)
            if validPart then
                return validPart
            end
        end
    end
    
    return nil
end

local function findPlayerIncubator(player)
    local function getValidPart(obj)
        if obj:IsA("BasePart") then
            return obj
        end
        
        if obj:IsA("Model") then
            -- Pour les incubateurs, chercher les parties principales
            local main = obj:FindFirstChild("Main") or obj:FindFirstChild("Base") or obj:FindFirstChild("Center")
            if main then
                return main
            end
            
            if obj.PrimaryPart then
                return obj.PrimaryPart
            end
            
            -- Chercher une partie au centre
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("BasePart") and 
                   (child.Name:lower():find("main") or 
                    child.Name:lower():find("base") or 
                    child.Name:lower():find("center") or
                    child.Name:lower():find("body")) then
                    return child
                end
            end
            
            for _, child in pairs(obj:GetDescendants()) do
                if child:IsA("BasePart") then
                    return child
                end
            end
        end
        
        return nil
    end
    
    local slot = player:GetAttribute("IslandSlot")
    if not slot then 
        return nil 
    end
    
    local island = Workspace:FindFirstChild("Ile_Slot_" .. slot) or Workspace:FindFirstChild("Ile_" .. player.Name)
    if not island then 
        return nil 
    end
    
    for _, obj in pairs(island:GetDescendants()) do
        if (obj.Name == "Incubator" or obj.Name:lower():find("incubat")) then
            local validPart = getValidPart(obj)
            if validPart then
                return validPart
            end
        end
    end
    
    return nil
end

--------------------------------------------------------------------
-- REMOTEEVENTS POUR COMMUNICATION CLIENT-SERVEUR
--------------------------------------------------------------------
local tutorialRemote = ReplicatedStorage:FindFirstChild("TutorialRemote")
if not tutorialRemote then
    tutorialRemote = Instance.new("RemoteEvent")
    tutorialRemote.Name = "TutorialRemote"
    tutorialRemote.Parent = ReplicatedStorage
end

local tutorialStepRemote = ReplicatedStorage:FindFirstChild("TutorialStepRemote")
if not tutorialStepRemote then
    tutorialStepRemote = Instance.new("RemoteEvent")
    tutorialStepRemote.Name = "TutorialStepRemote"
    tutorialStepRemote.Parent = ReplicatedStorage
end

local fermerMenuEvent = ReplicatedStorage:FindFirstChild("FermerMenuEvent")
if not fermerMenuEvent then
    fermerMenuEvent = Instance.new("RemoteEvent")
    fermerMenuEvent.Name = "FermerMenuEvent"
    fermerMenuEvent.Parent = ReplicatedStorage
end

--------------------------------------------------------------------
-- DÉCLARATIONS PRÉALABLES DES FONCTIONS (pour éviter les erreurs d'ordre)
--------------------------------------------------------------------
local startWelcomeStep, startGoToVendorStep, startTalkToVendorStep, startBuySugarStep
local startGoToIncubatorStep, startOpenIncubatorStep, startSelectRecipeStep, startConfirmProductionStep
local startCreateCandyStep, startPickupCandyStep, startOpenBagStep, startSellCandyStep, completeTutorialStep
local startEquipSugarStep, startPlaceIngredientsStep

--------------------------------------------------------------------
-- GESTION DES ÉTAPES DU TUTORIEL
--------------------------------------------------------------------
startWelcomeStep = function(player)
    setTutorialStep(player, "WELCOME")
    
    -- Vérifier que les RemoteEvents existent
    if not tutorialStepRemote then
        warn("❌ [TUTORIAL] TutorialStepRemote non trouvé!")
        return
    end
    
    -- Envoyer les instructions au client
    tutorialStepRemote:FireClient(player, "WELCOME", {
        title = "🎉 Bienvenue dans le jeu!",
        message = "Salut " .. player.Name .. "! Je vais t'apprendre les bases.\nCommençons par acheter des ingrédients!",
        arrow_target = "vendor",
        highlight_target = nil
    })
    
    -- Passer à l'étape suivante après 3 secondes
    task.spawn(function()
        task.wait(3)
        startGoToVendorStep(player)
    end)
end

startGoToVendorStep = function(player)
    setTutorialStep(player, "GO_TO_VENDOR")
    
    local vendor = findVendor()
    if vendor then
        tutorialStepRemote:FireClient(player, "GO_TO_VENDOR", {
            title = "🛒 Va voir le vendeur",
            message = "Parfait! Maintenant va voir le vendeur pour acheter des ingrédients.\n\n🎯 Suis la flèche dorée!",
            arrow_target = vendor,
            highlight_target = vendor,
            lock_camera = true
        })
    else
        tutorialStepRemote:FireClient(player, "GO_TO_VENDOR", {
            title = "🛒 Cherche le vendeur",
            message = "Cherche le vendeur sur ton île pour acheter des ingrédients!\n\n⚠️ Vendeur non détecté automatiquement",
            arrow_target = nil,
            highlight_target = nil
        })
    end
    
    -- Activer la détection de proximité
    startProximityDetection(player)
end

startTalkToVendorStep = function(player)
    setTutorialStep(player, "TALK_TO_VENDOR")
    
    tutorialStepRemote:FireClient(player, "TALK_TO_VENDOR", {
        title = "💬 Parle au vendeur",
        message = "Parfait! Maintenant clique sur le vendeur pour ouvrir le menu d'achat!\n\n💭 Vendeur: \"Hey tu veux acheter quoi ?\"\n\n👆 Clique sur le personnage du vendeur!",
        arrow_target = nil,
        highlight_target = findVendor()
    })
end

startBuySugarStep = function(player)
    setTutorialStep(player, "BUY_SUGAR", {sugar_bought = 0, target_amount = 2})
    
    tutorialStepRemote:FireClient(player, "BUY_SUGAR", {
        title = "🍯 Achète du sucre",
        message = "Cherche l'ingrédient 'Sucre' dans la liste et clique sur 'ACHETER' 2 fois!\n\n📋 Progression: (0/2 achetés)\n\n💡 Le sucre devrait être surligné en or!",
        arrow_target = nil,
        highlight_target = "Sucre",
        highlight_shop_item = "Sucre"
    })
end

startGoToIncubatorStep = function(player)
    setTutorialStep(player, "GO_TO_INCUBATOR")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "GO_TO_INCUBATOR", {
        title = "🏭 Va à ton incubateur",
        message = "Maintenant que tu as du sucre, va à ton incubateur pour créer ton premier bonbon!\n\n🎯 Suis la flèche dorée!",
        arrow_target = incubator,
        highlight_target = incubator,
        lock_camera = true
    })
    
    -- Activer la détection de proximité
    startProximityDetection(player)
end

startEquipSugarStep = function(player)
    setTutorialStep(player, "EQUIP_SUGAR")
    
    tutorialStepRemote:FireClient(player, "EQUIP_SUGAR", {
        title = "🎒 Équipe ton sucre",
        message = "Parfait! Maintenant tu dois équiper le sucre de ton backpack.\n\n👆 Ouvre ton inventaire (touche 'I' ou clique sur l'icône) et clique sur le sucre pour l'équiper!",
        arrow_target = nil,
        highlight_target = "backpack",
        lock_camera = false
    })
end

startPlaceIngredientsStep = function(player)
    setTutorialStep(player, "PLACE_INGREDIENTS")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "PLACE_INGREDIENTS", {
        title = "📦 Place tes ingrédients",
        message = "Excellent! Tu as le sucre en main.\n\nMaintenant clique sur l'incubateur pour y déposer tes ingrédients!\n\n💡 Tu dois déposer 2 sucres pour la recette Bonbon Basique.",
        arrow_target = incubator,
        highlight_target = incubator,
        lock_camera = true
    })
end

startOpenIncubatorStep = function(player)
    setTutorialStep(player, "OPEN_INCUBATOR")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "OPEN_INCUBATOR", {
        title = "🔧 Ouvre l'incubateur",
        message = "Clique sur l'incubateur pour ouvrir le menu de production!\n\n👆 La caméra reste verrouillée pour t'aider.",
        arrow_target = nil,
        highlight_target = incubator,
        lock_camera = true -- Verrouillage permanent jusqu'à action
    })
end

startSelectRecipeStep = function(player)
    setTutorialStep(player, "SELECT_RECIPE")
    
    tutorialStepRemote:FireClient(player, "SELECT_RECIPE", {
        title = "📋 Sélectionne une recette",
        message = "Dans le menu, cherche la recette 'Bonbon Basique' et clique dessus!\n\n💡 Elle a besoin de 2 sucres (que tu viens d'acheter).",
        arrow_target = nil,
        highlight_target = "recipe_basique"
    })
end

startConfirmProductionStep = function(player)
    setTutorialStep(player, "CONFIRM_PRODUCTION")
    
    tutorialStepRemote:FireClient(player, "CONFIRM_PRODUCTION", {
        title = "⚙️ Lance la production",
        message = "Maintenant clique sur le bouton 'PRODUIRE' ou 'CONSTRUIRE' pour lancer la création!\n\n⏱️ La production va prendre quelques secondes.",
        arrow_target = nil,
        highlight_target = "produce_button"
    })
end

startCreateCandyStep = function(player)
    setTutorialStep(player, "CREATE_CANDY")
    
    tutorialStepRemote:FireClient(player, "CREATE_CANDY", {
        title = "⏳ Production en cours",
        message = "Parfait! La production de ton bonbon a commencé.\n\nAttends que le bonbon apparaisse puis ramasse-le!",
        arrow_target = nil,
        highlight_target = nil
    })
end

startPickupCandyStep = function(player)
    setTutorialStep(player, "PICKUP_CANDY")
    
    tutorialStepRemote:FireClient(player, "PICKUP_CANDY", {
        title = "📦 Ramasse ton bonbon",
        message = "Excellent! Un bonbon vient d'apparaître!\n\nClique dessus pour le ramasser et l'ajouter à ton sac.",
        arrow_target = nil,
        highlight_target = "candy"
    })
end

startOpenBagStep = function(player)
    setTutorialStep(player, "OPEN_BAG")
    
    tutorialStepRemote:FireClient(player, "OPEN_BAG", {
        title = "🎒 Ouvre ton sac",
        message = "Super! Le bonbon est dans ton sac.\n\nMaintenant ouvre ton sac à bonbons pour le voir et le vendre!\n\n💡 Cherche l'interface ou le bouton 'Sac' dans ton écran.",
        arrow_target = nil,
        highlight_target = "bag_button"
    })
end

startSellCandyStep = function(player)
    setTutorialStep(player, "SELL_CANDY")
    
    tutorialStepRemote:FireClient(player, "SELL_CANDY", {
        title = "💰 Vends ton bonbon",
        message = "Parfait! Tu peux voir ton bonbon dans le sac.\n\nClique sur le bouton 'VENDRE' à côté de ton bonbon pour le vendre et gagner de l'argent!",
        arrow_target = nil,
        highlight_target = "sell_button"
    })
end

completeTutorialStep = function(player)
    setTutorialStep(player, "COMPLETED")
    
    tutorialStepRemote:FireClient(player, "COMPLETED", {
        title = "🎉 Tutoriel terminé!",
        message = "Félicitations! Tu maîtrises maintenant les bases du jeu.\nVoici " .. TUTORIAL_CONFIG.COMPLETION_REWARD .. "$ de récompense!",
        arrow_target = nil,
        highlight_target = nil
    })
    
    task.spawn(function()
        task.wait(5)
        completeTutorial(player)
    end)
end

--------------------------------------------------------------------
-- DÉTECTION DES ACTIONS DU JOUEUR
--------------------------------------------------------------------
-- Détecter quand le joueur clique sur le vendeur
local function onVendorClicked(player)
    local step = getTutorialStep(player)
    if step == "GO_TO_VENDOR" then
        startTalkToVendorStep(player)
    elseif step == "TALK_TO_VENDOR" then
        startBuySugarStep(player)
    end
end

-- Détecter les achats d'ingrédients
local function onIngredientBought(player, ingredient, quantity)
    local step = getTutorialStep(player)
    print("🛒 [TUTORIAL] onIngredientBought appelé - Joueur:", player.Name, "Ingrédient:", ingredient, "Quantité:", quantity, "Étape actuelle:", step)
    
    if step == "BUY_SUGAR" then
        print("🛒 [TUTORIAL] Joueur en étape BUY_SUGAR")
        
        if ingredient == "Sucre" then
            print("🛒 [TUTORIAL] Achat de sucre détecté!")
            
            -- S'assurer que les données du tutoriel existent
            if not activeTutorials[player].data then
                activeTutorials[player].data = {sugar_bought = 0, target_amount = 2}
            end
            
            local data = activeTutorials[player].data
            local ancienneQuantite = data.sugar_bought or 0
            data.sugar_bought = ancienneQuantite + quantity
            
            print("🛒 [TUTORIAL] Sucre acheté: " .. ancienneQuantite .. " + " .. quantity .. " = " .. data.sugar_bought .. "/" .. data.target_amount)
            
            if data.sugar_bought >= data.target_amount then
                print("🛒 [TUTORIAL] Objectif atteint! Fermeture du menu et passage à l'incubateur")
                
                -- Fermer le menu du vendeur automatiquement côté client
                fermerMenuEvent:FireClient(player)
                
                -- Assez de sucre acheté
                task.spawn(function()
                    task.wait(1.5) -- Un peu plus de temps pour que le menu se ferme
                    startGoToIncubatorStep(player)
                end)
            else
                print("🛒 [TUTORIAL] Mise à jour du message de progression")
                -- Mettre à jour le message
                tutorialStepRemote:FireClient(player, "BUY_SUGAR", {
                    title = "🍯 Achète du sucre",
                    message = "Bien joué! Continue d'acheter du sucre.\n\n📋 Progression: (" .. data.sugar_bought .. "/2 achetés)\n\n💡 Clique encore sur 'ACHETER' dans la section sucre!",
                    highlight_shop_item = "Sucre"
                })
            end
        else
            print("🛒 [TUTORIAL] Ingrédient acheté (" .. ingredient .. ") mais pas du sucre - ignoré")
        end
    else
        print("🛒 [TUTORIAL] Joueur pas en étape BUY_SUGAR - ignoré")
    end
end

-- Détecter quand le joueur s'approche de l'incubateur
local function onIncubatorApproached(player)
    local step = getTutorialStep(player)
    if step == "GO_TO_INCUBATOR" then
        startEquipSugarStep(player)
    end
end

-- Détecter quand le joueur équipe le sucre
local function onSugarEquipped(player)
    local step = getTutorialStep(player)
    if step == "EQUIP_SUGAR" then
        startPlaceIngredientsStep(player)
    end
end

-- Détecter quand le joueur place des ingrédients
local function onIngredientsPlaced(player, ingredient)
    local step = getTutorialStep(player)
    if step == "PLACE_INGREDIENTS" and ingredient == "Sucre" then
        local data = activeTutorials[player] or {}
        data.ingredients_placed = (data.ingredients_placed or 0) + 1
        activeTutorials[player] = data
        
        print("🧪 [TUTORIAL] Ingrédient placé:", ingredient, "Total:", data.ingredients_placed)
        
        if data.ingredients_placed >= 2 then
            -- Assez d'ingrédients placés, passer à l'ouverture du menu
            startOpenIncubatorStep(player)
        else
            -- Mettre à jour le message
            tutorialStepRemote:FireClient(player, "PLACE_INGREDIENTS", {
                title = "📦 Place tes ingrédients",
                message = "Bien! Continue de déposer du sucre.\n\n📋 Progression: (" .. data.ingredients_placed .. "/2 déposés)\n\n💡 Clique encore sur l'incubateur avec le sucre équipé!",
                highlight_target = findPlayerIncubator(player)
            })
        end
    end
end

-- Détecter quand le joueur utilise l'incubateur (ouvre le menu)
local function onIncubatorUsed(player)
    local step = getTutorialStep(player)
    if step == "OPEN_INCUBATOR" then
        startSelectRecipeStep(player)
    end
end

-- Détecter la sélection d'une recette
local function onRecipeSelected(player, recipeName)
    local step = getTutorialStep(player)
    if step == "SELECT_RECIPE" and recipeName == "Basique" then
        startConfirmProductionStep(player)
    end
end

-- Détecter le démarrage de production
local function onProductionStarted(player)
    local step = getTutorialStep(player)
    if step == "CONFIRM_PRODUCTION" then
        startCreateCandyStep(player)
    end
end

-- Détecter la création de bonbons
local function onCandyCreated(player)
    local step = getTutorialStep(player)
    if step == "CREATE_CANDY" then
        startPickupCandyStep(player)
    end
end

-- Détecter le ramassage de bonbons
local function onCandyPickedUp(player)
    local step = getTutorialStep(player)
    if step == "PICKUP_CANDY" then
        startOpenBagStep(player)
    end
end

-- Détecter l'ouverture du sac
local function onBagOpened(player)
    local step = getTutorialStep(player)
    if step == "OPEN_BAG" then
        startSellCandyStep(player)
    end
end

-- Détecter la vente de bonbons
local function onCandySold(player)
    local step = getTutorialStep(player)
    if step == "SELL_CANDY" then
        completeTutorialStep(player)
    end
end

--------------------------------------------------------------------
-- SURVEILLANCE DE L'ÉQUIPEMENT
--------------------------------------------------------------------
local function setupPlayerEquipmentWatcher(player)
    local function onCharacterAdded(character)
        -- Surveiller les changements d'outils équipés
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and isPlayerInTutorial(player) then
                local toolName = child:GetAttribute("BaseName") or child.Name
                print("🔧 [TUTORIAL] Outil équipé:", toolName)
                
                if toolName:match("Sucre") or toolName:match("sucre") then
                    onSugarEquipped(player)
                end
            end
        end)
    end
    
    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

--------------------------------------------------------------------
-- SYSTÈME DE DÉTECTION DE PROXIMITÉ
--------------------------------------------------------------------
local proximityConnections = {} -- [player] = {connection, lastDistance}

local function startProximityDetection(player)
    if proximityConnections[player] then
        proximityConnections[player].connection:Disconnect()
    end
    
    local connection = RunService.Heartbeat:Connect(function()
        if not isPlayerInTutorial(player) then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        local playerPosition = humanoidRootPart.Position
        local step = getTutorialStep(player)
        
        -- Détection du vendeur
        if step == "GO_TO_VENDOR" then
            local vendor = findVendor()
            if vendor then
                local vendorPosition = vendor:IsA("Model") and vendor:GetPivot().Position or vendor.Position
                local distance = (playerPosition - vendorPosition).Magnitude
                
                if distance <= 8 then -- 8 studs de proximité
                    print("🛒 [TUTORIAL] Joueur proche du vendeur, étape suivante")
                    onVendorClicked(player)
                end
            end
        
        -- Détection de l'incubateur
        elseif step == "GO_TO_INCUBATOR" then
            local incubator = findPlayerIncubator(player)
            if incubator then
                local incubatorPosition = incubator:GetPivot().Position
                local distance = (playerPosition - incubatorPosition).Magnitude
                
                if distance <= 10 then -- 10 studs de proximité
                    print("🏭 [TUTORIAL] Joueur proche de l'incubateur, étape suivante")
                    onIncubatorApproached(player)
                end
            end
        end
    end)
    
    proximityConnections[player] = {connection = connection}
end

--------------------------------------------------------------------
-- INITIALISATION DU TUTORIEL POUR NOUVEAUX JOUEURS
--------------------------------------------------------------------
local function checkIfNeedsTutorial(player)
    -- Attendre que les données du joueur soient chargées
    local playerData = player:WaitForChild("PlayerData", 10)
    if not playerData then return end
    
    -- Vérifier si le tutoriel a déjà été fait
    local tutorialCompleted = playerData:FindFirstChild("TutorialCompleted")
    if tutorialCompleted and tutorialCompleted.Value then
        print("🎓 [TUTORIAL] " .. player.Name .. " a déjà fait le tutoriel")
        return
    end
    
    -- Nouveau joueur - commencer le tutoriel
    print("🎓 [TUTORIAL] Nouveau joueur détecté: " .. player.Name)
    
    -- S'assurer qu'il a assez d'argent pour le tutoriel
    local argent = playerData:FindFirstChild("Argent")
    if argent and argent.Value < TUTORIAL_CONFIG.STARTING_MONEY then
        argent.Value = TUTORIAL_CONFIG.STARTING_MONEY
    end
    
    -- Attendre un peu que le joueur soit bien spawné
    task.wait(3)
    startWelcomeStep(player)
end

--------------------------------------------------------------------
-- GESTION DES JOUEURS
--------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    print("👋 [TUTORIAL] Joueur connecté:", player.Name)
    
    -- Attendre que le joueur soit complètement chargé
    player.CharacterAdded:Connect(function()
        task.wait(2) -- Délai pour que tout soit initialisé
        
        -- Vérifier si le joueur doit commencer le tutoriel
        local playerData = player:WaitForChild("PlayerData", 10)
        if playerData then
            local tutorialCompleted = playerData:FindFirstChild("TutorialCompleted")
            if not tutorialCompleted or not tutorialCompleted.Value then
                print("🎓 [TUTORIAL] Démarrage du tutoriel pour", player.Name)
                startWelcomeStep(player)
            else
                print("ℹ️ [TUTORIAL] Joueur", player.Name, "a déjà terminé le tutoriel")
            end
        end
    end)
    
    -- Configurer la surveillance de l'équipement
    setupPlayerEquipmentWatcher(player)
    startProximityDetection(player) -- Démarrer la détection de proximité pour le nouveau joueur
end)

-- Joueur quitte
Players.PlayerRemoving:Connect(function(player)
    activeTutorials[player] = nil
    stopProximityDetection(player) -- Arrêter la détection de proximité lors de la suppression du joueur
end)

-- Écouter les événements du jeu pour détecter les actions du tutoriel
tutorialRemote.OnServerEvent:Connect(function(player, action, data)
    if action == "vendor_clicked" then
        onVendorClicked(player)
    elseif action == "ingredient_bought" then
        onIngredientBought(player, data.ingredient, data.quantity)
    elseif action == "incubator_approached" then
        onIncubatorApproached(player)
    elseif action == "incubator_used" then
        onIncubatorUsed(player)
    elseif action == "recipe_selected" then
        onRecipeSelected(player, data.recipe)
    elseif action == "production_started" then
        onProductionStarted(player)
    elseif action == "candy_created" then
        onCandyCreated(player)
    elseif action == "candy_picked_up" then
        onCandyPickedUp(player)
    elseif action == "bag_opened" then
        onBagOpened(player)
    elseif action == "candy_sold" then
        onCandySold(player)
    end
end)

--------------------------------------------------------------------
-- INTÉGRATION AVEC LES SCRIPTS EXISTANTS
--------------------------------------------------------------------
-- Hook dans le système d'achat existant - IMPORTANT: Connexion avec priorité différée
local achatEvent = ReplicatedStorage:FindFirstChild("AchatIngredientEvent_V2")
if achatEvent then
    achatEvent.OnServerEvent:Connect(function(player, ingredient, quantity)
        -- Attendre que le GameManager traite l'achat d'abord
        task.spawn(function()
            task.wait(0.1) -- Petit délai pour laisser le GameManager agir
            print("🛒 [TUTORIAL] Achat détecté (différé):", player.Name, "a acheté", quantity, ingredient)
            if isPlayerInTutorial(player) then
                onIngredientBought(player, ingredient, quantity)
            end
        end)
    end)
end

-- Hook dans le menu d'achat pour détecter l'ouverture
local ouvrirMenuEvent = ReplicatedStorage:FindFirstChild("OuvrirMenuEvent")
if ouvrirMenuEvent then
    ouvrirMenuEvent.OnServerEvent:Connect(function(player)
        print("🏪 [TUTORIAL] Menu d'achat ouvert par", player.Name)
        if isPlayerInTutorial(player) then
            onVendorClicked(player)
        end
    end)
end

-- Hook dans le système de vente existant
local venteEvent = ReplicatedStorage:FindFirstChild("VendreUnBonbonEvent")
if venteEvent then
    venteEvent.OnServerEvent:Connect(function(player, typeB, q)
        if isPlayerInTutorial(player) then
            print("💰 [TUTORIAL] Vente détectée:", player.Name, "a vendu", q, typeB)
            onCandySold(player)
        end
    end)
end

-- Hook dans le système de ramassage existant
local pickupEvent = ReplicatedStorage:FindFirstChild("PickupCandyEvent")
if pickupEvent then
    pickupEvent.OnServerEvent:Connect(function(player, candy)
        if isPlayerInTutorial(player) then
            onCandyPickedUp(player)
        end
    end)
end

--------------------------------------------------------------------
-- EXPOSITION DES FONCTIONS (pour les autres scripts)
--------------------------------------------------------------------
_G.TutorialManager = {
    -- Fonctions d'état
    isPlayerInTutorial = isPlayerInTutorial,
    getTutorialStep = getTutorialStep,
    startTutorial = startWelcomeStep,
    completeTutorial = completeTutorial,
    
    -- Événements du vendeur
    onVendorApproached = onVendorClicked, -- fonction qui gère le clic/approche du vendeur
    onVendorTalked = onVendorClicked, -- même fonction pour l'instant
    onIngredientPurchased = onIngredientBought,
    
    -- Événements de l'incubateur
    onIncubatorApproached = onIncubatorApproached,
    onSugarEquipped = onSugarEquipped,
    onIngredientsPlaced = onIngredientsPlaced,
    onIncubatorUsed = onIncubatorUsed,
    onRecipeSelected = onRecipeSelected,
    onProductionStarted = onProductionStarted,
    onCandyCreated = onCandyCreated,
    
    -- Événements des bonbons
    onCandyPickedUp = onCandyPickedUp,
    onBagOpened = onBagOpened,
    onCandySold = onCandySold
}

print("🎓 TutorialManager initialisé - Prêt pour les nouveaux joueurs!") 