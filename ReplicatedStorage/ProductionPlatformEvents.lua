--[[
    🎯 PRODUCTION PLATFORM EVENTS
    Gestionnaire centralisé des événements pour les plateformes de production
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductionPlatformEvents = {}

-- 📡 Créer ou récupérer les RemoteEvents
function ProductionPlatformEvents.getEvents()
    local events = {}
    
    -- Événement pour placer un bonbon sur une plateforme
    events.PlaceCandyOnPlatform = ReplicatedStorage:FindFirstChild("PlaceCandyOnPlatformEvent")
    if not events.PlaceCandyOnPlatform then
        events.PlaceCandyOnPlatform = Instance.new("RemoteEvent")
        events.PlaceCandyOnPlatform.Name = "PlaceCandyOnPlatformEvent"
        events.PlaceCandyOnPlatform.Parent = ReplicatedStorage
    end
    
    -- Événement pour ramasser l'argent généré
    events.PickupPlatformMoney = ReplicatedStorage:FindFirstChild("PickupPlatformMoneyEvent")
    if not events.PickupPlatformMoney then
        events.PickupPlatformMoney = Instance.new("RemoteEvent")
        events.PickupPlatformMoney.Name = "PickupPlatformMoneyEvent"
        events.PickupPlatformMoney.Parent = ReplicatedStorage
    end
    
    -- Événement pour retirer un bonbon d'une plateforme
    events.RemoveCandyFromPlatform = ReplicatedStorage:FindFirstChild("RemoveCandyFromPlatformEvent")
    if not events.RemoveCandyFromPlatform then
        events.RemoveCandyFromPlatform = Instance.new("RemoteEvent")
        events.RemoveCandyFromPlatform.Name = "RemoveCandyFromPlatformEvent"
        events.RemoveCandyFromPlatform.Parent = ReplicatedStorage
    end
    
    return events
end

return ProductionPlatformEvents
