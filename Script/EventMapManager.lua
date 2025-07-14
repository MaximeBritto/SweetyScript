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
    CHECK_INTERVAL = 120, -- Réduit à 2 minutes pour éviter les conflits
    
    -- Chance de spawner un event à chaque vérification (par île)
    EVENT_SPAWN_CHANCE = 0.02, -- Réduit à 2% pour éviter les spam d'events
    
    -- Types d'events disponibles
    EVENT_TYPES = {
        ["TempeteBonbons"] = {
            nom = "🍬 Tempête de Bonbons",
            description = "Triple la production de bonbons !",
            duree = {300, 600}, -- Entre 5 et 10 minutes (augmenté pour test)
            multiplicateur = 3,
            rarete = 40, -- 40% de chance relative
            couleur = Color3.fromRGB(255, 200, 100),
            effets = {"production_multiplicateur"}
        },
        ["PluieIngredients"] = {
            nom = "🌈 Pluie d'Ingrédients Rares",
            description = "Les bonbons deviennent plus rares !",
            duree = {120, 240}, -- Entre 2 et 4 minutes
            bonus_rarete = 1, -- Augmente la rareté de 1 niveau
            rarete = 25, -- 25% de chance relative
            couleur = Color3.fromRGB(150, 255, 150),
            effets = {"rarete_bonus"}
        },
        ["BoostVitesse"] = {
            nom = "⚡ Boost de Vitesse",
            description = "Production 2x plus rapide !",
            duree = {240, 480}, -- Entre 4 et 8 minutes (augmenté pour test)
            vitesse_multiplicateur = 2,
            rarete = 30, -- 30% de chance relative
            couleur = Color3.fromRGB(100, 200, 255),
            effets = {"vitesse_multiplicateur"}
        },
        ["EventLegendaire"] = {
            nom = "💎 Bénédiction Légendaire",
            description = "Tous les bonbons deviennent légendaires !",
            duree = {60, 120}, -- Entre 1 et 2 minutes
            rarete_forcee = "Légendaire",
            rarete = 5, -- 5% de chance relative (très rare)
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
    for _, player in pairs(Players:GetPlayers()) do
        if player:GetAttribute("IslandSlot") == slot then
            return player.Name
        end
    end
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
    return Players:FindFirstChild(getPlayerNameBySlot(slot) or "")
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
    local owner = getIslandOwner(slot)
    if owner then
        local eventNotif = ReplicatedStorage:FindFirstChild("EventNotificationRemote")
        if eventNotif then
            eventNotif:FireClient(owner, {
                type = "EventFini",
                nom = "Event terminé",
                description = event.data.nom .. " s'est terminé sur votre île.",
                duree = 0,
                couleur = Color3.fromRGB(200, 200, 200)
            })
        end
    end
    
    -- Notifier les clients pour arrêter les effets visuels
    local eventVisual = ReplicatedStorage:FindFirstChild("EventVisualUpdateRemote")
    if eventVisual then
        eventVisual:FireAllClients(slot, "EventFini", {}, 0)
    end
    
    activeEvents[slot] = nil
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
-- INITIALISATION
--------------------------------------------------------------------
-- Démarrer la boucle principale
task.spawn(function()
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