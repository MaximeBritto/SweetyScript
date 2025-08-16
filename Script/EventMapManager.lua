--------------------------------------------------------------------
-- EventMapManager.lua - Système d'events aléatoires par île
-- Gère les tempêtes de bonbons, pluies d'ingrédients, et autres events
--------------------------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

--------------------------------------------------------------------
-- CONFIGURATION DES EVENTS
--------------------------------------------------------------------
local EVENT_CONFIG = {
    -- Fréquence de vérification pour spawner des events (en secondes)
    CHECK_INTERVAL = 10, -- Réduit à 2 minutes pour éviter les conflits
    
    -- Chance de spawner un event à chaque vérification (par île)
    EVENT_SPAWN_CHANCE = 1, -- Réduit à 2% pour éviter les spam d'events
    
    -- Types d'events disponibles
    EVENT_TYPES = {
        ["TempeteBonbons"] = {
            nom = "🍬 TEMPÊTE DE BONBONS",
            description = "TRIPLE LA PRODUCTION DE BONBONS !",
            duree = {60, 60}, -- Durée fixe de 1 minute
            multiplicateur = 3,
            rarete = 100, -- 40% de chance relative
            couleur = Color3.fromRGB(255, 100, 100), -- Rouge plus vif pour plus de visibilité
            effets = {"production_multiplicateur"},
            showDuration = true, -- Afficher la durée restante
            persistentNotification = true -- Garder la notification à l'écran
        },
        ["PluieIngredients"] = {
            nom = "🌈 Pluie d'Ingrédients Rares",
            description = "Les bonbons deviennent plus rares !",
            duree = {120, 240}, -- Entre 2 et 4 minutes
            bonus_rarete = 1, -- Augmente la rareté de 1 niveau
            rarete = 0, -- 25% de chance relative
            couleur = Color3.fromRGB(150, 255, 150),
            effets = {"rarete_bonus"}
        },
        ["BoostVitesse"] = {
            nom = "⚡ Boost de Vitesse",
            description = "Production 2x plus rapide !",
            duree = {240, 480}, -- Entre 4 et 8 minutes (augmenté pour test)
            vitesse_multiplicateur = 2,
            rarete = 0, -- 30% de chance relative
            couleur = Color3.fromRGB(100, 200, 255),
            effets = {"vitesse_multiplicateur"}
        },
        ["EventLegendaire"] = {
            nom = "💎 Bénédiction Légendaire",
            description = "Tous les bonbons deviennent légendaires !",
            duree = {60, 120}, -- Entre 1 et 2 minutes
            rarete_forcee = "Legendary",
            rarete = 0, -- 5% de chance relative (très rare)
            couleur = Color3.fromRGB(255, 100, 255),
            effets = {"rarete_forcee"}
        }
    }
}

--------------------------------------------------------------------
-- VARIABLES GLOBALES
--------------------------------------------------------------------
local activeEvents = {} -- [slotNumber] = {type, endTime, data}
local lastEventCheck = 0

--------------------------------------------------------------------
-- FONCTIONS UTILITAIRES DE BASE
--------------------------------------------------------------------
local function getRandomEventType()
    local totalWeight = 0
    for _, eventData in pairs(EVENT_CONFIG.EVENT_TYPES) do
        totalWeight = totalWeight + eventData.rarete
    end
    
    local random = math.random() * totalWeight
    local currentWeight = 0
    
    for eventType, eventData in pairs(EVENT_CONFIG.EVENT_TYPES) do
        currentWeight = currentWeight + eventData.rarete
        if random <= currentWeight then
            return eventType, eventData
        end
    end
    
    return "TempeteBonbons", EVENT_CONFIG.EVENT_TYPES["TempeteBonbons"]
end

local function getRandomDuration(eventData)
    local minDuree, maxDuree = eventData.duree[1], eventData.duree[2]
    return math.random(minDuree, maxDuree)
end

local function getPlayerNameBySlot(slot)
    -- Vérifier d'abord si un joueur a cet attribut IslandSlot
    for _, player in pairs(Players:GetPlayers()) do
        if player:GetAttribute("IslandSlot") == slot then
            print("🔍 [DEBUG] Joueur trouvé par attribut IslandSlot:", player.Name, "dans le slot", slot)
            return player.Name
        end
    end
    
    -- Si aucun joueur n'a l'attribut, vérifier les îles nommées "Ile_Slot_X"
    local island = Workspace:FindFirstChild("Ile_Slot_" .. slot)
    if island then
        print("🔍 [DEBUG] Île trouvée pour le slot", slot, "mais pas de joueur attribué")
        return nil
    end
    
    -- Si l'île n'existe pas, vérifier si elle a été renommée avec le nom d'un joueur
    for _, player in pairs(Players:GetPlayers()) do
        if Workspace:FindFirstChild("Ile_" .. player.Name) then
            local playerSlot = player:GetAttribute("IslandSlot")
            if playerSlot == slot then
                print("🔍 [DEBUG] Joueur trouvé par nom d'île:", player.Name, "dans le slot", slot)
                return player.Name
            end
        end
    end
    
    print("⚠️ [DEBUG] Aucun joueur trouvé pour le slot", slot)
    return nil
end

local function getAllIslands()
    local islands = {}
    for i = 1, 6 do -- MAX_ISLANDS dans IslandManager
        local island = Workspace:FindFirstChild("Ile_Slot_" .. i) or Workspace:FindFirstChild("Ile_" .. getPlayerNameBySlot(i))
        if island then
            islands[i] = island
        end
    end
    return islands
end

local function getIslandOwner(slot)
    local playerName = getPlayerNameBySlot(slot)
    if not playerName then
        print("⚠️ [DEBUG] Aucun propriétaire trouvé pour le slot", slot)
        return nil
    end
    local player = Players:FindFirstChild(playerName)
    if not player then
        print("⚠️ [DEBUG] Joueur", playerName, "non trouvé dans Players")
    end
    return player
end

--------------------------------------------------------------------
-- GESTION DES EVENTS - DÉFINIES AVANT UTILISATION
--------------------------------------------------------------------
local function startEvent(slot, eventType, eventData)
    print("🌪️ [SERVER] startEvent appelé - slot:", slot, "type:", eventType)
    
    local duration = getRandomDuration(eventData)
    local startTime = tick() -- Retour à tick() mais géré différemment
    
    print("🌪️ [SERVER] Durée de l'event:", duration, "secondes")
    
    activeEvents[slot] = {
        type = eventType,
        startTime = startTime,
        duration = duration,
        data = eventData
    }
    
    print("🌪️ [SERVER] Event ajouté dans activeEvents pour slot:", slot)
    
    -- Marquer l'île avec des attributs
    local island = getAllIslands()[slot]
    if island then
        island:SetAttribute("ActiveEventType", eventType)
        island:SetAttribute("EventStartTime", startTime)
        island:SetAttribute("EventDuration", duration)
        island:SetAttribute("EventMultiplier", eventData.multiplicateur or 1)
        island:SetAttribute("EventVitesseMultiplier", eventData.vitesse_multiplicateur or 1)
        island:SetAttribute("EventBonusRarete", eventData.bonus_rarete or 0)
        island:SetAttribute("EventRareteForce", eventData.rarete_forcee or "")
    end
    
    -- Notifier le joueur si présent
    local owner = getIslandOwner(slot)
    if owner then
        local eventNotif = ReplicatedStorage:FindFirstChild("EventNotificationRemote")
        if eventNotif then
            eventNotif:FireClient(owner, {
                type = eventType,
                nom = eventData.nom,
                description = eventData.description,
                duree = duration,
                couleur = eventData.couleur
            })
        end
    end
    
    -- Notifier le client pour les effets visuels
    local eventVisual = ReplicatedStorage:FindFirstChild("EventVisualUpdateRemote")
    if eventVisual then
        -- Notifier tous les clients pour qu'ils voient les effets visuels sur l'île
        eventVisual:FireAllClients(slot, eventType, eventData, duration)
    end
    
    print("🌪️ Event démarré sur l'île " .. slot .. ": " .. eventData.nom .. " (" .. duration .. "s)")
end

local function endEvent(slot)
    local event = activeEvents[slot]
    if not event then return end
    
    -- Nettoyer les attributs de l'île
    local island = getAllIslands()[slot]
    if island then
        island:SetAttribute("ActiveEventType", nil)
        island:SetAttribute("EventStartTime", nil)
        island:SetAttribute("EventDuration", nil)
        island:SetAttribute("EventMultiplier", nil)
        island:SetAttribute("EventVitesseMultiplier", nil)
        island:SetAttribute("EventBonusRarete", nil)
        island:SetAttribute("EventRareteForce", nil)
    end
    
    -- Notifier la fin de l'event
    local eventNotif = ReplicatedStorage:FindFirstChild("EventNotificationRemote")
    if eventNotif then
        -- Notifier tous les clients avec un message vide pour effacer la notification
        eventNotif:FireAllClients(slot, "", "")
        
        -- Notifier le propriétaire avec un message de fin
        local owner = getIslandOwner(slot)
        if owner then
            eventNotif:FireClient(owner, {
                type = "end",
                nom = "Fin de " .. (event.data.nom or "l'événement"),
                description = "L'événement est terminé.",
                duree = 0,
                couleur = Color3.fromRGB(200, 200, 200)
            })
        end
    end
    
    -- Nettoyer l'event
    activeEvents[slot] = nil
    
    -- Notifier les clients de la fin de l'event
    local eventVisual = ReplicatedStorage:FindFirstChild("EventVisualUpdateRemote")
    if eventVisual then
        eventVisual:FireAllClients(slot, "EventFini", {}, 0)
    end
    
    print("🌪️ Event terminé sur l'île " .. slot .. ": " .. event.data.nom)
end

-- Fonction pour forcer un event (pour les tests) - MAINTENANT DÉFINIE APRÈS startEvent et endEvent
local function forceEvent(slot, eventType)
    local eventData = EVENT_CONFIG.EVENT_TYPES[eventType]
    if not eventData then
        warn("Type d'event inconnu:", eventType)
        return false
    end
    
    if activeEvents[slot] then
        print("⚠️ Event déjà actif sur l'île " .. slot .. " (" .. activeEvents[slot].data.nom .. ") - Arrêt forcé")
        endEvent(slot) -- Terminer l'event actuel
        task.wait(0.5) -- Petit délai pour éviter les conflits
    end
    
    print("🎯 Forçage d'event " .. eventType .. " sur l'île " .. slot)
    startEvent(slot, eventType, eventData)
    return true
end

--------------------------------------------------------------------
-- FONCTIONS PUBLIQUES POUR LES AUTRES SCRIPTS
--------------------------------------------------------------------
local function getEventMultiplier(islandSlot)
    local event = activeEvents[islandSlot]
    if not event then return 1 end
    
    return event.data.multiplicateur or 1
end

local function getEventVitesseMultiplier(islandSlot)
    local event = activeEvents[islandSlot]
    if not event then return 1 end
    
    return event.data.vitesse_multiplicateur or 1
end

local function getEventBonusRarete(islandSlot)
    local event = activeEvents[islandSlot]
    if not event then return 0 end
    
    return event.data.bonus_rarete or 0
end

local function getEventRareteForce(islandSlot)
    local event = activeEvents[islandSlot]
    if not event then return nil end
    
    return event.data.rarete_forcee
end

local function getActiveEventForIsland(islandSlot)
    return activeEvents[islandSlot]
end

-- Fonction pour obtenir le slot d'une île depuis un incubateur
local function getIslandSlotFromIncubator(incubatorID)
    -- Format de l'ID: "Ile_PlayerName_1" ou "Ile_Slot_1_1" 
    local slotMatch = incubatorID:match("Slot_(%d+)_") or incubatorID:match("_(%d+)_") or incubatorID:match("(%d+)$")
    if slotMatch then
        local slot = tonumber(slotMatch)
        return slot
    end
    
    -- Fallback: chercher dans le workspace
    local allIslands = getAllIslands()
    for slot, island in pairs(allIslands) do
        local found = false
        for _, descendant in pairs(island:GetDescendants()) do
            if descendant:IsA("StringValue") and descendant.Name == "ParcelID" and descendant.Value == incubatorID then
                return slot
            end
        end
        if found then
            return slot
        end
    end
    
    -- Log seulement en cas d'échec
    warn("❌ Aucun slot trouvé pour incubatorID:", incubatorID)
    return nil
end

--------------------------------------------------------------------
-- BOUCLE PRINCIPALE
--------------------------------------------------------------------
local function mainEventLoop()
    local currentTime = tick()
    
    -- Vérifier les events existants (fin)
    for slot, event in pairs(activeEvents) do
        local timeElapsed = currentTime - event.startTime
        local timeRemaining = event.duration - timeElapsed
        
        if timeElapsed >= event.duration then
            print("🕐 Event expiré sur l'île " .. slot .. " (" .. event.data.nom .. ") - Durée: " .. math.floor(timeElapsed) .. "s")
            endEvent(slot)
        end
    end
    
    -- Vérifier si on doit spawner de nouveaux events
    if currentTime - lastEventCheck >= EVENT_CONFIG.CHECK_INTERVAL then
        lastEventCheck = currentTime
        
        local islands = getAllIslands()
        for slot, island in pairs(islands) do
            -- Ne pas spawner d'event s'il y en a déjà un actif
            if not activeEvents[slot] then
                if math.random() < EVENT_CONFIG.EVENT_SPAWN_CHANCE then
                    local eventType, eventData = getRandomEventType()
                    startEvent(slot, eventType, eventData)
                end
            end
        end
    end
end

--------------------------------------------------------------------
-- CONFIGURATION DES REMOTEEVENTS
--------------------------------------------------------------------
-- RemoteFunctions pour la communication client-serveur
local getEventDataRF = ReplicatedStorage:FindFirstChild("GetEventDataRemote")
if not getEventDataRF then
    getEventDataRF = Instance.new("RemoteFunction")
    getEventDataRF.Name = "GetEventDataRemote"
    getEventDataRF.Parent = ReplicatedStorage
    print("🔧 [SERVER] GetEventDataRemote créé")
else
    print("🔧 [SERVER] GetEventDataRemote trouvé")
end

getEventDataRF.OnServerInvoke = function(player, requestType, data)
    print("🔧 [SERVER] RemoteFunction appelée:", requestType, "par", player.Name)
    
    if requestType == "GetMultiplier" then
        return getEventMultiplier(data)
    elseif requestType == "GetVitesseMultiplier" then
        return getEventVitesseMultiplier(data)
    elseif requestType == "GetBonusRarete" then
        return getEventBonusRarete(data)
    elseif requestType == "GetRareteForce" then
        return getEventRareteForce(data)
    elseif requestType == "GetActiveEvent" then
        local result = getActiveEventForIsland(data)
        print("🔧 [SERVER] Event actuel île", data, ":", result)
        return result
    elseif requestType == "GetSlotFromIncubator" then
        return getIslandSlotFromIncubator(data)
    elseif requestType == "ForceEvent" then
        -- Commande de test pour forcer un event
        local slot = data.slot
        local eventType = data.eventType
        print("🧪 [SERVER] Test: Forçage d'event " .. eventType .. " sur l'île " .. slot)
        local success = forceEvent(slot, eventType)
        print("🧪 [SERVER] Résultat forceEvent:", success)
        return success
    elseif requestType == "StopEvent" then
        -- Commande de test pour arrêter un event
        local slot = data.slot
        print("🧪 [SERVER] Test: Arrêt d'event sur l'île " .. slot)
        endEvent(slot)
        return true
    end
    
    warn("🔧 [SERVER] Type de requête non reconnu:", requestType)
    return nil
end

--------------------------------------------------------------------
-- BOUCLE PRINCIPALE DES EVENTS
--------------------------------------------------------------------
-- La fonction mainEventLoop est définie plus bas dans le fichier

--------------------------------------------------------------------
-- INITIALISATION
--------------------------------------------------------------------
-- Démarrer la boucle principale
task.spawn(function()
    print("🚀 [SERVER] Démarrage du système d'events automatiques")
    print("⚙️ [SERVER] Intervalle:", EVENT_CONFIG.CHECK_INTERVAL, "secondes")
    print("🎲 [SERVER] Chance de spawn:", EVENT_CONFIG.EVENT_SPAWN_CHANCE * 100, "%")
    
    while true do
        mainEventLoop()
        task.wait(1) -- Vérification chaque seconde
    end
end)

-- Stocker les fonctions globalement pour accès direct
_G.EventMapManager = {
    getEventMultiplier = getEventMultiplier,
    getEventVitesseMultiplier = getEventVitesseMultiplier,
    getEventBonusRarete = getEventBonusRarete,
    getEventRareteForce = getEventRareteForce,
    getActiveEventForIsland = getActiveEventForIsland,
    getIslandSlotFromIncubator = getIslandSlotFromIncubator,
    forceEvent = forceEvent -- Pour les tests
}

print("🌪️ EventMapManager initialisé - Events aléatoires activés!") 