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
        "PLACE_INGREDIENTS",    -- Placer les ingrédients sur l'incubateur
        "OPEN_INCUBATOR",       -- Ouvrir le menu de l'incubateur
        "INCUBATOR_UI_GUIDE",   -- 💡 NOUVEAU: Guide interface incubateur avec flèches
        "PLACE_IN_SLOTS",       -- 💡 NOUVEAU: Placer les ingrédients dans les slots
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
        
        -- Donner la récompense via GameManager (sync leaderstats)
        if _G.GameManager and _G.GameManager.ajouterArgent then
            _G.GameManager.ajouterArgent(player, TUTORIAL_CONFIG.COMPLETION_REWARD)
            print("💰 [TUTORIAL] Ajout", TUTORIAL_CONFIG.COMPLETION_REWARD, "$ via GameManager")
        elseif player.PlayerData:FindFirstChild("Argent") then
            -- Fallback si GameManager pas disponible
            player.PlayerData.Argent.Value = player.PlayerData.Argent.Value + TUTORIAL_CONFIG.COMPLETION_REWARD
            print("💰 [TUTORIAL] Ajout", TUTORIAL_CONFIG.COMPLETION_REWARD, "$ directement (fallback)")
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
        title = "🎉 Welcome to the game!",
        message = "Hi " .. player.Name .. "! I'll teach you the basics.\nLet's start by buying some ingredients!",
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
            title = "🛒 Go see the vendor",
            message = "Great! Now go to the vendor to buy ingredients.\n\n🎯 Follow the golden arrow!",
            arrow_target = vendor,
            highlight_target = vendor,
            lock_camera = true
        })
    else
        tutorialStepRemote:FireClient(player, "GO_TO_VENDOR", {
            title = "🛒 Find the vendor",
            message = "Find the vendor on your island to buy ingredients!\n\n⚠️ Vendor not detected automatically",
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
        title = "💬 Talk to the vendor",
        message = "Great! Now click on the vendor to open the shop menu!\n\n💭 Vendor: \"Hey, what do you want to buy?\"\n\n👆 Click on the vendor character!",
        arrow_target = nil,
        highlight_target = findVendor()
    })
end

startBuySugarStep = function(player)
    setTutorialStep(player, "BUY_SUGAR", {sugar_bought = 0, target_amount = 2})
    
    tutorialStepRemote:FireClient(player, "BUY_SUGAR", {
        title = "🍯 Buy sugar",
        message = "Find the ingredient 'Sucre' in the list and click 'BUY' 2 times!\n\n📋 Progress: (0/2 purchased)\n\n💡 'Sucre' should be highlighted in gold!",
        arrow_target = nil,
        highlight_target = "Sucre",
        highlight_shop_item = "Sucre"
    })
end

startGoToIncubatorStep = function(player)
    setTutorialStep(player, "GO_TO_INCUBATOR")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "GO_TO_INCUBATOR", {
        title = "🏭 Go to your incubator",
        message = "Now that you have some sugar, go to your incubator to create your first candy!\n\n🎯 Follow the golden arrow!",
        arrow_target = incubator,
        highlight_target = incubator,
        lock_camera = true
    })
    
    -- Activer la détection de proximité
    startProximityDetection(player)
end

startPlaceIngredientsStep = function(player)
    setTutorialStep(player, "PLACE_INGREDIENTS")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "PLACE_INGREDIENTS", {
        title = "📦 Use the incubator",
        message = "Great! You bought sugar.\n\nNow click the incubator to open it and place your ingredients!\n\n💡 The incubator slots will highlight when you click an ingredient.",
        arrow_target = incubator,
        highlight_target = incubator,
        lock_camera = true
    })
end

startOpenIncubatorStep = function(player)
    setTutorialStep(player, "OPEN_INCUBATOR")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "OPEN_INCUBATOR", {
        title = "🔧 Open the incubator",
        message = "Click the incubator to open the production menu!\n\n👆 The camera stays locked to help you.",
        arrow_target = nil,
        highlight_target = incubator,
        lock_camera = true -- Verrouillage permanent jusqu'à action
    })
end

-- 💡 NOUVEAU: Guide pour utiliser l'interface incubateur
startIncubatorUIGuideStep = function(player)
    setTutorialStep(player, "INCUBATOR_UI_GUIDE")
    
    tutorialStepRemote:FireClient(player, "INCUBATOR_UI_GUIDE", {
        title = "🎯 Interface guide",
        message = "Great! The incubator is open.\n\n👆 STEP 1: First click SUCRE in your inventory (left)\n\n✨ Empty slots will light up to show you where to place the sugar!",
        arrow_target = "incubator_sugar", -- Flèche vers le sucre dans l'inventaire
        highlight_target = "incubator_inventory",
        lock_camera = false, -- Libérer la caméra pour voir l'interface
        tutorial_phase = "click_ingredient" -- Phase spéciale pour les flèches
    })
end

-- 💡 NOUVEAU: Étape pour placer les ingrédients dans les slots
startPlaceInSlotsStep = function(player)
    setTutorialStep(player, "PLACE_IN_SLOTS")
    
    tutorialStepRemote:FireClient(player, "PLACE_IN_SLOTS", {
        title = "🎯 Place your ingredients",
        message = "Great! Now:\n\n1️⃣ Click SUCRE in your inventory (left)\n2️⃣ Click an EMPTY SLOT to place the sugar\n\n✨ Empty slots will light up to help you!\n\n🎯 Place 2 'Sucre' to make a candy!",
        arrow_target = nil,
        highlight_target = "incubator_slots",
        lock_camera = false
    })
end

startSelectRecipeStep = function(player)
    setTutorialStep(player, "SELECT_RECIPE")
    
    tutorialStepRemote:FireClient(player, "SELECT_RECIPE", {
        title = "📋 Select a recipe",
        message = "In the menu, look for the 'Bonbon Basique' recipe and click it!\n\n💡 It requires 2 'Sucre' (which you just bought).",
        arrow_target = nil,
        highlight_target = "recipe_basique"
    })
end

startConfirmProductionStep = function(player)
    setTutorialStep(player, "CONFIRM_PRODUCTION")
    
    tutorialStepRemote:FireClient(player, "CONFIRM_PRODUCTION", {
        title = "⚙️ Start production",
        message = "Now click the 'PRODUCE' or 'BUILD' button to start crafting!\n\n⏱️ Production will take a few seconds.",
        arrow_target = nil,
        highlight_target = "produce_button"
    })
end

startCreateCandyStep = function(player)
    setTutorialStep(player, "CREATE_CANDY")
    
    tutorialStepRemote:FireClient(player, "CREATE_CANDY", {
        title = "⏳ Production in progress",
        message = "Great! Your candy production has started.\n\nWait for the candy to appear then pick it up!",
        arrow_target = nil,
        highlight_target = nil
    })
end

startPickupCandyStep = function(player)
    setTutorialStep(player, "PICKUP_CANDY")
    
    tutorialStepRemote:FireClient(player, "PICKUP_CANDY", {
        title = "📦 Pick up your candy",
        message = "Excellent! A candy just appeared!\n\nClick it to pick it up and add it to your bag.",
        arrow_target = nil,
        highlight_target = "candy"
    })
end

startOpenBagStep = function(player)
    setTutorialStep(player, "OPEN_BAG")
    
    tutorialStepRemote:FireClient(player, "OPEN_BAG", {
        title = "🎒 Open your bag",
        message = "Nice! The candy is in your bag.\n\nNow open your candy bag to see it and sell it!\n\n💡 Look for the 'Bag' interface or button on your screen.",
        arrow_target = nil,
        highlight_target = "bag_button"
    })
end

startSellCandyStep = function(player)
    setTutorialStep(player, "SELL_CANDY")
    
    tutorialStepRemote:FireClient(player, "SELL_CANDY", {
        title = "💰 Sell your candy",
        message = "Great! Your candy is now in your inventory.\n\n🎮 Press 'V' or click the 💰 SALE button in the hotbar to open the sell menu!\n\n💡 You can sell your candies even if they are in your hand!",
        arrow_target = nil,
        highlight_target = "sell_button_v2"
    })
end

completeTutorialStep = function(player)
    setTutorialStep(player, "COMPLETED")
    
    tutorialStepRemote:FireClient(player, "COMPLETED", {
        title = "🎉 Tutorial completed!",
        message = "Congratulations! You now know the basics of the game.\nHere is " .. TUTORIAL_CONFIG.COMPLETION_REWARD .. "$ as a reward!",
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
                    title = "🍯 Buy sugar",
                    message = "Well done! Keep buying 'Sucre'.\n\n📋 Progress: (" .. data.sugar_bought .. "/2 purchased)\n\n💡 Click 'BUY' again in the 'Sucre' section!",
                    highlight_shop_item = "Sucre",
                    no_sound = true  -- Pas de son lors de la mise à jour de progression
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
                title = "📦 Place your ingredients",
                message = "Nice! Keep placing 'Sucre'.\n\n📋 Progress: (" .. data.ingredients_placed .. "/2 placed)\n\n💡 Click the incubator again with 'Sucre' equipped!",
                highlight_target = findPlayerIncubator(player)
            })
        end
    end
end

-- Détecter quand le joueur utilise l'incubateur (ouvre le menu)
local function onIncubatorUsed(player)
    local step = getTutorialStep(player)
    if step == "OPEN_INCUBATOR" then
        -- 💡 NOUVEAU: Passer d'abord par le guide interface
        startIncubatorUIGuideStep(player)
    elseif step == "INCUBATOR_UI_GUIDE" then
        -- Passer à l'étape de placement dans les slots
        startPlaceInSlotsStep(player)
    elseif step == "PLACE_IN_SLOTS" then
        -- Quand les ingrédients sont placés, passer aux recettes
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
    print("🍭 [TUTORIAL] onCandyCreated appelé pour:", player.Name, "- Étape actuelle:", step)
    
    if step == "CREATE_CANDY" then
        print("🍭 [TUTORIAL] Étape correcte! Passage à PICKUP_CANDY")
        startPickupCandyStep(player)
    else
        print("🍭 [TUTORIAL] Étape incorrecte pour création. Attendu: CREATE_CANDY, Actuel:", step)
    end
end

-- Détecter le ramassage de bonbons
local function onCandyPickedUp(player)
    local step = getTutorialStep(player)
    print("🍭 [TUTORIAL] onCandyPickedUp appelé pour:", player.Name, "- Étape actuelle:", step)
    
    if step == "PICKUP_CANDY" then
        print("🍭 [TUTORIAL] Étape correcte! Passage à OPEN_BAG")
        startOpenBagStep(player)
    elseif step == "CREATE_CANDY" then
        print("🍭 [TUTORIAL] Ramassage détecté pendant CREATE_CANDY - Passage direct à OPEN_BAG")
        -- Le bonbon a été créé ET ramassé rapidement, on passe directement à OPEN_BAG
        startOpenBagStep(player)
    else
        print("🍭 [TUTORIAL] Étape incorrecte pour ramassage. Attendu: PICKUP_CANDY ou CREATE_CANDY, Actuel:", step)
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
                
                -- Plus besoin de détecter l'équipement du sucre
                -- Le tutoriel passe directement à l'utilisation de l'incubateur
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