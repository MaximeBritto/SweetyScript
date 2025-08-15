-- Script utilitaire pour créer tous les RemoteEvents nécessaires
-- À exécuter UNE SEULE FOIS dans ServerScriptService pour créer les RemoteEvents
-- Vous pouvez supprimer ce script après l'avoir exécuté

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Liste de tous les RemoteEvents nécessaires pour la V0.3
local remoteEvents = {
    -- Événements de base (V0.1)
    "VenteEvent",
    "UpgradeEvent",
    -- Robux upgrade marchand (NOUVEAU)
    "RequestMerchantUpgradeRobux",
    
    -- Événements d'ingrédients (V0.2)
    "AchatIngredientEvent",
    "AchatIngredientEvent_V2",
    "OuvrirMenuEvent",
    -- Achat ingrédient via Robux (NOUVEAU)
    "RequestIngredientPurchaseRobux",
    
    -- Événements du sac à bonbons (V0.3)
    "OuvrirSacEvent",
    "VendreUnBonbonEvent",
    
    -- Événements de production (V0.3)
    "DemarrerProductionEvent",
    "OuvrirRecettesEvent",
    
    -- Événements d'incubateurs (NOUVEAU)
    "OpenIncubatorMenu",
    "DropIngredient",
    "StartIncubationEvent",
    -- v4.0 Incubateur (UI slots)
    "PlaceIngredientInSlot",
    "RemoveIngredientFromSlot",
    "StartCrafting",
    "IncubatorCraftProgress",
    
    -- Événements de ramassage (NOUVEAU)
    "PickupCandyEvent",
    
    -- Événement de rafraîchissement du sac visuel (NOUVEAU)
    "BackpackRefreshEvent",
    
    -- Événements pour le système d'events map (NOUVEAU)
    "EventNotificationRemote",
    "EventVisualUpdateRemote",
    
    -- Événements pour le système de tutoriel (NOUVEAU)
    "TutorialRemote",
    "TutorialStepRemote"
}

-- Créer chaque RemoteEvent s'il n'existe pas déjà
for _, eventName in ipairs(remoteEvents) do
    local existingEvent = ReplicatedStorage:FindFirstChild(eventName)
    
    if not existingEvent then
        local newEvent = Instance.new("RemoteEvent")
        newEvent.Name = eventName
        newEvent.Parent = ReplicatedStorage
        
    else
        
    end
end

-- Liste des RemoteFunctions nécessaires
local remoteFunctions = {
    "GetAvailableRecipes",
    "GetEventDataRemote",
    -- v4.0 Incubateur (UI slots)
    "GetIncubatorSlots"
}

-- Créer chaque RemoteFunction s'il n'existe pas déjà
for _, functionName in ipairs(remoteFunctions) do
    local existingFunction = ReplicatedStorage:FindFirstChild(functionName)
    
    if not existingFunction then
        local newFunction = Instance.new("RemoteFunction")
        newFunction.Name = functionName
        newFunction.Parent = ReplicatedStorage
        
    else
        
    end
end




-- Auto-suppression du script après 5 secondes (optionnel)
wait(5)
script:Destroy() 