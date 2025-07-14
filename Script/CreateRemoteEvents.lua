-- Script utilitaire pour créer tous les RemoteEvents nécessaires
-- À exécuter UNE SEULE FOIS dans ServerScriptService pour créer les RemoteEvents
-- Vous pouvez supprimer ce script après l'avoir exécuté

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Liste de tous les RemoteEvents nécessaires pour la V0.3
local remoteEvents = {
    -- Événements de base (V0.1)
    "VenteEvent",
    "UpgradeEvent",
    
    -- Événements d'ingrédients (V0.2)
    "AchatIngredientEvent",
    "AchatIngredientEvent_V2",
    "OuvrirMenuEvent",
    
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
    
    -- Événements de ramassage (NOUVEAU)
    "PickupCandyEvent",
    
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
        print("✅ RemoteEvent créé : " .. eventName)
    else
        print("⚠️ RemoteEvent existe déjà : " .. eventName)
    end
end

-- Liste des RemoteFunctions nécessaires
local remoteFunctions = {
    "GetAvailableRecipes",
    "GetEventDataRemote"
}

-- Créer chaque RemoteFunction s'il n'existe pas déjà
for _, functionName in ipairs(remoteFunctions) do
    local existingFunction = ReplicatedStorage:FindFirstChild(functionName)
    
    if not existingFunction then
        local newFunction = Instance.new("RemoteFunction")
        newFunction.Name = functionName
        newFunction.Parent = ReplicatedStorage
        print("✅ RemoteFunction créé : " .. functionName)
    else
        print("⚠️ RemoteFunction existe déjà : " .. functionName)
    end
end

print("🎉 Tous les RemoteEvents ont été vérifiés/créés !")
print("💡 Vous pouvez maintenant supprimer ce script.")

-- Auto-suppression du script après 5 secondes (optionnel)
wait(5)
script:Destroy() 