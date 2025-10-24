--------------------------------------------------------------------
-- TutorialManager.lua - Système de tutoriel pour nouveaux joueurs
-- Gère toutes les étapes du tutoriel de base
--------------------------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService") -- Added for proximity detection
local UserInputService = game:GetService("UserInputService") -- For mobile detection

--------------------------------------------------------------------
-- CONFIGURATION DU TUTORIEL
--------------------------------------------------------------------
local TUTORIAL_CONFIG = {
    -- Étapes du tutoriel
    STEPS = {
        "WELCOME",              -- Bienvenue
        "GO_TO_VENDOR",         -- Aller au vendeur
        "TALK_TO_VENDOR",       -- Parler au vendeur
        "BUY_SUGAR",            -- Buy 1 Sugar + 1 Gelatin (name kept for compatibility)
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
        "GO_TO_PLATFORM",       -- 🆕 Aller à la première plateforme
        "UNLOCK_PLATFORM",      -- 🆕 Débloquer la plateforme
        "PLACE_CANDY_ON_PLATFORM", -- 🆕 Placer un bonbon sur la plateforme
        "COLLECT_MONEY",        -- 🆕 Récupérer l'argent généré
        "COMPLETED"             -- Tutoriel terminé
    },
    
    -- Positions importantes
    VENDOR_POSITION = Vector3.new(0, 5, 0), -- À ajuster selon votre jeu
    INCUBATOR_POSITION = Vector3.new(10, 5, 10), -- À ajuster selon votre jeu
    
    -- Argent de départ pour le tutoriel
    STARTING_MONEY = 30,
    
    -- Récompense de fin de tutoriel
    COMPLETION_REWARD = 60
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
startProximityDetection = startProximityDetection or nil

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
local _startEquipSugarStep, startPlaceIngredientsStep

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
            highlight_target = vendor
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
    setTutorialStep(player, "BUY_SUGAR", {sugar_bought = 0, gelatine_bought = 0, target_sugar = 1, target_gelatine = 1})

    tutorialStepRemote:FireClient(player, "BUY_SUGAR", {
        title = "🛒 Buy ingredients",
        message = "Buy 1 'Sugar' and 1 'Gelatin' in the shop.\n\n📋 Progress:\n- Sugar: (0/1)\n- Gelatin: (0/1)\n\n💡 Both items are highlighted!",
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
        message = "Now that you have sugar and gelatin, go to your incubator to create your first candy!\n\n🎯 Follow the golden arrow!",
        arrow_target = incubator,
        highlight_target = incubator
    })
    
    -- Activer la détection de proximité
    startProximityDetection(player)
end

startPlaceIngredientsStep = function(player)
    -- Simplifier: rester sur "Open the incubator" puis passer directement à l'UI guide
    startOpenIncubatorStep(player)
end

startOpenIncubatorStep = function(player)
    setTutorialStep(player, "OPEN_INCUBATOR")
    
    local incubator = findPlayerIncubator(player)
    tutorialStepRemote:FireClient(player, "OPEN_INCUBATOR", {
        title = "🔧 Open the incubator",
        message = "Click the incubator to open the production menu!\n\nOr press E to open the incubator menu.",
        arrow_target = nil,
        highlight_target = incubator
    })
end

-- 💡 NOUVEAU: Guide pour utiliser l'interface incubateur
startIncubatorUIGuideStep = function(player)
    setTutorialStep(player, "INCUBATOR_UI_GUIDE")
    
    -- Détecter si mobile ou PC
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local splitInstructions = isMobile and "📱 Hold = Choose quantity" or "🖱️ Ctrl+Click = Choose qty\n🖱️ Shift+Click = Half"
    
    tutorialStepRemote:FireClient(player, "INCUBATOR_UI_GUIDE", {
        title = "🎯 Interface guide",
        message = "Great! The incubator is open.\n\n1️⃣ Click SUGAR in your inventory.\n2️⃣ Then click GELATIN.\n\n💡 " .. splitInstructions .. "\n\n✨ Empty slots will light up!",
        arrow_target = "incubator_sugar",
        highlight_target = "incubator_inventory",
        tutorial_phase = "click_ingredient"
    })
end

-- 💡 NOUVEAU: Étape pour placer les ingrédients dans les slots
startPlaceInSlotsStep = function(player)
    setTutorialStep(player, "PLACE_IN_SLOTS")
    
    -- Détecter si mobile ou PC
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local splitInstructions = isMobile and "📱 Hold to choose quantity" or "🖱️ Ctrl+Click = Choose quantity\n🖱️ Shift+Click = Half stack"
    
    tutorialStepRemote:FireClient(player, "PLACE_IN_SLOTS", {
        title = "🎯 Place your ingredients",
        message = "Great! Now:\n\n1️⃣ Place 1 'Sugar'\n2️⃣ Place 1 'Gelatin'\n\n💡 TIP: " .. splitInstructions .. "\n\n✨ Empty slots will light up!",
        arrow_target = nil,
        highlight_target = "incubator_slots"
    })
end

startSelectRecipeStep = function(player)
    setTutorialStep(player, "SELECT_RECIPE")
    
    tutorialStepRemote:FireClient(player, "SELECT_RECIPE", {
        title = "📋 Select a recipe",
        message = "In the menu, look for the 'Basic Gelatin' recipe and click it!\n\n💡 It requires 1 'Sugar' + 1 'Gelatin'.",
        arrow_target = nil,
        highlight_target = "recipe_basique_gelatine"
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
        message = "Nice! The candy is in your bag.\n\nNow open your candy bag to see it and sell it!\n\n💡 Click the 💰 CandySell button to open the sell screen.",
        arrow_target = "sell_button_v2",
        highlight_target = "sell_button_v2"
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

-- 🆕 NOUVELLES ÉTAPES: PLATEFORMES
local function findFirstPlatform(player)
    -- Chercher l'île du joueur (plusieurs formats possibles)
    local island = nil
    local slot = player:GetAttribute("IslandSlot")
    
    -- Essayer différents formats de nom d'île
    if slot then
        island = Workspace:FindFirstChild("Ile_Slot_" .. slot)
    end
    
    if not island then
        island = Workspace:FindFirstChild("Ile_" .. player.Name)
    end
    
    if not island then
        print("❌ [TUTORIAL] Île non trouvée pour:", player.Name, "Slot:", slot)
        -- Lister toutes les îles pour debug
        print("   Îles disponibles dans Workspace:")
        for _, obj in pairs(Workspace:GetChildren()) do
            if obj.Name:find("Ile") then
                print("     -", obj.Name)
            end
        end
        return nil
    end
    
    print("✅ [TUTORIAL] Île trouvée:", island.Name)
    
    -- Lister tous les objets contenant "Platform" pour debug
    print("   Objets Platform dans l'île:")
    for _, obj in pairs(island:GetDescendants()) do
        if obj.Name:find("Platform") or obj.Name:find("platform") then
            print("     -", obj.Name, "Type:", obj.ClassName, "Parent:", obj.Parent.Name)
        end
    end
    
    -- Chercher la première plateforme (Platform_1 ou similaire)
    for _, obj in pairs(island:GetDescendants()) do
        local isFirstPlatform = obj.Name == "Platform_1" or 
                               obj.Name == "Platform1" or
                               obj.Name == "platform_1" or
                               obj.Name == "platform1" or
                               (obj.Name:lower():find("platform") and obj.Name:find("1"))
        
        if isFirstPlatform then
            print("✅ [TUTORIAL] Plateforme trouvée:", obj.Name, "Type:", obj.ClassName)
            if obj:IsA("BasePart") then
                return obj
            elseif obj:IsA("Model") and obj.PrimaryPart then
                return obj.PrimaryPart
            elseif obj:IsA("Model") then
                local part = obj:FindFirstChildOfClass("BasePart")
                if part then
                    return part
                end
            end
        end
    end
    
    print("❌ [TUTORIAL] Aucune plateforme trouvée dans:", island.Name)
    print("   Vérifiez que la plateforme s'appelle 'Platform_1' ou similaire")
    return nil
end

startGoToPlatformStep = function(player)
    setTutorialStep(player, "GO_TO_PLATFORM")
    
    local platform = findFirstPlatform(player)
    
    if platform then
        print("✅ [TUTORIAL] Plateforme trouvée:", platform:GetFullName())
    else
        print("❌ [TUTORIAL] Plateforme NON trouvée pour:", player.Name)
        print("   IslandSlot:", player:GetAttribute("IslandSlot"))
    end
    
    tutorialStepRemote:FireClient(player, "GO_TO_PLATFORM", {
        title = "🏗️ Go to your platform",
        message = "Excellent! Now let's place your candy on a platform to make it grow!\n\n🎯 Follow the golden arrow to your first platform!",
        arrow_target = platform,
        highlight_target = platform
    })
    
    -- Activer la détection de proximité
    if platform then
        startProximityDetection(player)
    else
        print("⚠️ [TUTORIAL] Impossible d'activer la détection de proximité - plateforme non trouvée")
    end
end

startUnlockPlatformStep = function(player)
    -- Vérifier si la plateforme est déjà débloquée
    local playerData = player:FindFirstChild("PlayerData")
    local platformsUnlocked = playerData and playerData:FindFirstChild("PlatformsUnlocked")
    
    if platformsUnlocked and platformsUnlocked.Value >= 1 then
        -- La plateforme est déjà débloquée, passer directement à l'étape suivante
        print("✅ [TUTORIAL] Plateforme déjà débloquée, passage direct à PLACE_CANDY_ON_PLATFORM")
        startPlaceCandyOnPlatformStep(player)
        return
    end
    
    setTutorialStep(player, "UNLOCK_PLATFORM")
    
    local platform = findFirstPlatform(player)
    tutorialStepRemote:FireClient(player, "UNLOCK_PLATFORM", {
        title = "🔓 Unlock the platform",
        message = "Great! You're at the platform.\n\nClick on it to unlock it (it's free for the first one)!",
        arrow_target = nil,
        highlight_target = platform
    })
end

startPlaceCandyOnPlatformStep = function(player)
    setTutorialStep(player, "PLACE_CANDY_ON_PLATFORM")
    
    local platform = findFirstPlatform(player)
    tutorialStepRemote:FireClient(player, "PLACE_CANDY_ON_PLATFORM", {
        title = "🍭 Place your candy",
        message = "Perfect! The platform is unlocked.\n\nNow click on the platform again and place your candy on it!\n\n💡 Your candy will grow over time and earn you money!",
        arrow_target = nil,
        highlight_target = platform
    })
end

startCollectMoneyStep = function(player)
    setTutorialStep(player, "COLLECT_MONEY")
    
    local platform = findFirstPlatform(player)
    tutorialStepRemote:FireClient(player, "COLLECT_MONEY", {
        title = "💰 Collect your money!",
        message = "Excellent! Your candy is now on the platform and generating money!\n\nWait a few seconds, then walk close to the platform to collect the money automatically!\n\n✨ The money will appear as a golden sphere above the platform.",
        arrow_target = nil,
        highlight_target = platform
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

        -- Init data si absente
        if not activeTutorials[player].data then
            activeTutorials[player].data = {sugar_bought = 0, gelatine_bought = 0, target_sugar = 1, target_gelatine = 1}
        end
        local data = activeTutorials[player].data

        if ingredient == "Sucre" then
            data.sugar_bought = (data.sugar_bought or 0) + quantity
            print("🛒 [TUTORIAL] Sugar bought: " .. tostring(data.sugar_bought) .. "/" .. tostring(data.target_sugar))
        elseif ingredient == "Gelatine" then
            data.gelatine_bought = (data.gelatine_bought or 0) + quantity
            print("🛒 [TUTORIAL] Gelatin bought: " .. tostring(data.gelatine_bought) .. "/" .. tostring(data.target_gelatine))
        else
            print("🛒 [TUTORIAL] Ingrédient acheté (" .. ingredient .. ") non suivi pour cette étape")
        end

        if (data.sugar_bought or 0) >= (data.target_sugar or 1) and (data.gelatine_bought or 0) >= (data.target_gelatine or 1) then
            print("🛒 [TUTORIAL] Goal reached (Sugar + Gelatin)! Closing menu and going to incubator")
            fermerMenuEvent:FireClient(player)
            task.spawn(function()
                task.wait(1.5)
                startGoToIncubatorStep(player)
            end)
        else
            local s = data.sugar_bought or 0
            local g = data.gelatine_bought or 0
            -- Ne pas envoyer de nouveau highlight, juste mettre à jour le message
            tutorialStepRemote:FireClient(player, "BUY_SUGAR", {
                title = "🛒 Buy ingredients",
                message = "Keep buying!\n\n📋 Progress:\n- Sugar: ("..s.."/1)\n- Gelatin: ("..g.."/1)",
                no_sound = true,
                keep_highlights = true -- Ne pas nettoyer les highlights existants
            })
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
    if step == "PLACE_INGREDIENTS" and (ingredient == "Sucre" or ingredient == "Gelatine") then
        local data = activeTutorials[player] or {}
        data.placed_sucre = data.placed_sucre or 0
        data.placed_gelatine = data.placed_gelatine or 0
        if ingredient == "Sucre" then data.placed_sucre += 1 end
        if ingredient == "Gelatine" then data.placed_gelatine += 1 end
        activeTutorials[player] = data

        print("🧪 [TUTORIAL] Placements → Sugar:", data.placed_sucre or 0, "Gelatin:", data.placed_gelatine or 0)

        if (data.placed_sucre >= 1) and (data.placed_gelatine >= 1) then
            startOpenIncubatorStep(player)
        else
            local msg = "Place the missing ingredient:\n"
            if (data.placed_sucre or 0) < 1 then msg ..= "- Sucre (0/1)\n" end
            if (data.placed_gelatine or 0) < 1 then msg ..= "- Gelatine (0/1)\n" end
            tutorialStepRemote:FireClient(player, "PLACE_INGREDIENTS", {
                title = "📦 Place your ingredients",
                message = msg,
                highlight_target = findPlayerIncubator(player)
            })
        end
    end
end

-- Détecter quand le joueur utilise l'incubateur (ouvre le menu)
local function onIncubatorUsed(player)
    local step = getTutorialStep(player)
    if step == "OPEN_INCUBATOR" then
        -- Ouvrir → directement guide UI
        startIncubatorUIGuideStep(player)
    elseif step == "INCUBATOR_UI_GUIDE" then
        startPlaceInSlotsStep(player)
    elseif step == "PLACE_IN_SLOTS" then
        startSelectRecipeStep(player)
    end
end

-- Détecter la sélection d'une recette
local function onRecipeSelected(player, recipeName)
    local step = getTutorialStep(player)
    -- Tolérance: accepter "Basique" ou "Basique Gelatine"
    if step == "SELECT_RECIPE" and (recipeName == "Basique Gelatine" or recipeName == "Basique") then
        startConfirmProductionStep(player)
    end
end

-- Détecter le démarrage de production
local function onProductionStarted(player)
    local step = getTutorialStep(player)
    -- Tolérance: si l'étape n'a pas bougé (ex: pas passé par CONFIRM), on avance quand même
    if step == "CONFIRM_PRODUCTION" or step == "SELECT_RECIPE" then
        startCreateCandyStep(player)
    end
end

-- Détecter la création de bonbons
local function onCandyCreated(player)
    local step = getTutorialStep(player)
    print("🍭 [TUTORIAL] onCandyCreated appelé pour:", player.Name, "- Étape actuelle:", step)
    -- Tolérance: avancer si on est proche de l'étape attendue
    if step == "CREATE_CANDY" or step == "CONFIRM_PRODUCTION" or step == "SELECT_RECIPE" then
        print("🍭 [TUTORIAL] Passage à PICKUP_CANDY")
        startPickupCandyStep(player)
    else
        print("🍭 [TUTORIAL] Étape incorrecte pour création. Attendu: CREATE_CANDY/CONFIRM_PRODUCTION/SELECT_RECIPE, Actuel:", step)
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
        startGoToPlatformStep(player)
    end
end

-- 🆕 Détecter l'approche de la plateforme
local function onPlatformApproached(player)
    local step = getTutorialStep(player)
    if step == "GO_TO_PLATFORM" then
        startUnlockPlatformStep(player)
    end
end

-- 🆕 Détecter le déblocage de la plateforme
local function onPlatformUnlocked(player, platformName)
    print("🔓 [TUTORIAL] onPlatformUnlocked appelé - Joueur:", player.Name, "Plateforme:", platformName, "Étape:", getTutorialStep(player))
    local step = getTutorialStep(player)
    if step == "UNLOCK_PLATFORM" and (platformName:find("Platform1") or platformName:find("Platform_1")) then
        print("✅ [TUTORIAL] Conditions remplies, passage à PLACE_CANDY_ON_PLATFORM")
        startPlaceCandyOnPlatformStep(player)
    else
        print("❌ [TUTORIAL] Conditions non remplies - Étape:", step, "Nom plateforme:", platformName)
    end
end

-- 🆕 Détecter le placement d'un bonbon sur la plateforme
local function onCandyPlacedOnPlatform(player, platformName)
    print("🍬 [TUTORIAL] onCandyPlacedOnPlatform appelé - Joueur:", player.Name, "Plateforme:", platformName, "Étape:", getTutorialStep(player))
    local step = getTutorialStep(player)
    
    -- Si le joueur place un bonbon alors qu'il est à UNLOCK_PLATFORM, on passe d'abord à PLACE_CANDY_ON_PLATFORM
    if step == "UNLOCK_PLATFORM" and (platformName:find("Platform1") or platformName:find("Platform_1")) then
        print("⚡ [TUTORIAL] Bonbon placé pendant UNLOCK_PLATFORM, passage rapide à PLACE_CANDY_ON_PLATFORM puis COLLECT_MONEY")
        startPlaceCandyOnPlatformStep(player)
        task.wait(0.5) -- Petit délai pour que le joueur voie le message
        startCollectMoneyStep(player)
        return
    end
    
    if step == "PLACE_CANDY_ON_PLATFORM" and (platformName:find("Platform1") or platformName:find("Platform_1")) then
        print("✅ [TUTORIAL] Bonbon placé correctement, passage à COLLECT_MONEY")
        startCollectMoneyStep(player)
    else
        print("⚠️ [TUTORIAL] Étape incorrecte ou mauvaise plateforme - Étape:", step, "Attendu: PLACE_CANDY_ON_PLATFORM")
    end
end

-- 🆕 Détecter la collecte d'argent
local function onMoneyCollected(player)
    print("💰 [TUTORIAL] onMoneyCollected appelé - Joueur:", player.Name, "Étape:", getTutorialStep(player))
    local step = getTutorialStep(player)
    if step == "COLLECT_MONEY" then
        print("🎉 [TUTORIAL] Argent collecté ! Complétion du tutoriel")
        completeTutorialStep(player)
    else
        print("⚠️ [TUTORIAL] Étape incorrecte pour collecte d'argent - Étape:", step, "Attendu: COLLECT_MONEY")
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
-- Remarque: table réutilisée, ne pas redéclarer plus bas
-- Eviter shadow: ne pas redéclarer si elle existe déjà
proximityConnections = proximityConnections or {} -- [player] = {connection, lastDistance}

startProximityDetection = function(player)
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
                
                if distance <= 50 then -- 50 studs de proximité (increased for large incubators)
                    print("🏭 [TUTORIAL] Joueur proche de l'incubateur, étape suivante")
                    onIncubatorApproached(player)
                end
            end
        
        -- 🆕 Détection de la plateforme
        elseif step == "GO_TO_PLATFORM" then
            local platform = findFirstPlatform(player)
            if platform then
                local platformPosition = platform.Position
                local distance = (playerPosition - platformPosition).Magnitude
                
                if distance <= 15 then -- 15 studs de proximité
                    print("🏗️ [TUTORIAL] Joueur proche de la plateforme, étape suivante")
                    onPlatformApproached(player)
                end
            end
        end
    end)
    
    proximityConnections[player] = {connection = connection}
end

--------------------------------------------------------------------
-- INITIALISATION DU TUTORIEL POUR NOUVEAUX JOUEURS
--------------------------------------------------------------------
local _function_unused_checkIfNeedsTutorial
_function_unused_checkIfNeedsTutorial = function(player)
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
    elseif action == "platform_approached" then
        onPlatformApproached(player)
    elseif action == "platform_unlocked" then
        onPlatformUnlocked(player, data.platform)
    elseif action == "candy_placed_on_platform" then
        onCandyPlacedOnPlatform(player, data.platform)
    elseif action == "money_collected" then
        onMoneyCollected(player)
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
    onCandySold = onCandySold,
    
    -- 🆕 Événements des plateformes
    onPlatformApproached = onPlatformApproached,
    onPlatformUnlocked = onPlatformUnlocked,
    onCandyPlacedOnPlatform = onCandyPlacedOnPlatform,
    onMoneyCollected = onMoneyCollected
}

print("🎓 TutorialManager initialisé - Prêt pour les nouveaux joueurs!") 