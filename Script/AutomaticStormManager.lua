-- AutomaticStormManager.lua - Gère automatiquement les tempêtes de bonbons
-- Placez ce script dans ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Configuration
local STORM_INTERVAL = 10 -- Vérification toutes les 10 secondes
local ACTIVE_SLOTS = {1, 2, 3, 4, 5, 6} -- Slots d'îles actifs
local STORM_CHANCE = 0.3 -- 30% de chance qu'une tempête se déclenche sur une île à chaque vérification
local STORM_DURATION = 60 -- Durée de la tempête en secondes

-- Table pour suivre les tempêtes actives
local activeStorms = {}

-- Fonction pour vérifier si une tempête est active sur un slot
local function isStormActive(slot)
    return activeStorms[slot] and (tick() - activeStorms[slot].startTime) < STORM_DURATION
end

-- Attendre que le jeu soit complètement chargé
local function waitForGameLoaded()
    -- Attendre que EventMapManager soit disponible dans _G
    local startTime = tick()
    while not _G.EventMapManager do
        if tick() - startTime > 30 then
            warn("❌ [AutomaticStorm] Timeout: EventMapManager non trouvé après 30 secondes")
            return false
        end
        
        RunService.Heartbeat:Wait()
    end
    
    -- Vérifier si les RemoteEvents sont disponibles
    startTime = tick()
    while not ReplicatedStorage:FindFirstChild("GetEventDataRemote") do
        if tick() - startTime > 10 then
            warn("❌ [AutomaticStorm] Impossible de trouver GetEventDataRemote après 10 secondes")
            return false
        end
        RunService.Heartbeat:Wait()
    end
    
    
    return true
end

-- Fonction pour déclencher une tempête sur une île
local function triggerStormOnIsland(slot)
    -- Vérifier si le gestionnaire d'événements est disponible
    if not _G.EventMapManager then
        warn("⚠️ [AutomaticStorm] EventMapManager non trouvé dans _G")
        return false
    end
    
    -- Vérifier si la fonction forceEvent existe
    if not _G.EventMapManager.forceEvent then
        warn("⚠️ [AutomaticStorm] La fonction forceEvent n'existe pas dans EventMapManager")
        return false
    end
    
    -- Déclencher la tempête
    local success, result = pcall(function()
        return _G.EventMapManager.forceEvent(slot, "TempeteBonbons")
    end)
    
    if success then
        
        return true
    else
        warn("❌ [AutomaticStorm] Erreur lors du déclenchement de la tempête sur l'île", slot, "-", result)
        return false
    end
end

-- Boucle principale
local function startStormManager()
    
    
    if not waitForGameLoaded() then
        warn("❌ [AutomaticStorm] Impossible de démarrer le gestionnaire de tempêtes")
        return
    end
    
    
    
    -- Mélanger aléatoirement l'ordre des slots pour éviter un motif prévisible
    local shuffledSlots = {}
    for _, slot in ipairs(ACTIVE_SLOTS) do
        table.insert(shuffledSlots, slot)
    end
    
    -- Fonction pour mélanger le tableau
    local function shuffleArray(t)
        for i = #t, 2, -1 do
            local j = math.random(i)
            t[i], t[j] = t[j], t[i]
        end
        return t
    end
    
    while true do
        -- Mélanger les slots à chaque itération
        shuffleArray(shuffledSlots)
        
        -- Parcourir les slots dans un ordre aléatoire
        for _, slot in ipairs(shuffledSlots) do
            -- Vérifier si une tempête est déjà active sur ce slot
            if not isStormActive(slot) and math.random() < STORM_CHANCE then
                
                if triggerStormOnIsland(slot) then
                    -- Enregistrer la tempête
                    activeStorms[slot] = {
                        startTime = tick(),
                        slot = slot
                    }
                    
                    
                    -- Ajouter un petit délai entre chaque déclenchement de tempête
                    task.wait(2)
                end
            end
        end
        
        -- Attendre avant la prochaine vérification
        task.wait(STORM_INTERVAL)
    end
end

-- Fonction principale
local function startAutomaticStorms()
    task.spawn(startStormManager)
end

-- Démarrer le gestionnaire de tempêtes avec un léger délai aléatoire
local function delayedStart()
    -- Délai aléatoire entre 0 et 5 secondes pour éviter que toutes les tempêtes ne commencent en même temps
    local randomDelay = math.random(0, 5)
    task.wait(randomDelay)
    startAutomaticStorms()
end

delayedStart()
