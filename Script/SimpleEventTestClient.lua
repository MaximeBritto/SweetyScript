-- SimpleEventTestClient.lua - LocalScript simple pour tester les events
-- À placer dans StarterPlayer > StarterPlayerScripts

print("🧪 [CLIENT] SimpleEventTestClient démarré")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Attendre que les RemoteEvents soient créés
wait(3)

local getEventDataRF = ReplicatedStorage:WaitForChild("GetEventDataRemote", 10)

if not getEventDataRF then
    warn("🧪 [CLIENT] GetEventDataRemote non trouvé!")
    return
end

print("🧪 [CLIENT] GetEventDataRemote trouvé")

-- Fonction de test simple
local function testForceEvent(slot, eventType)
    print("🧪 [CLIENT] Test forceEvent - slot:", slot, "type:", eventType)
    
    local success, result = pcall(function()
        return getEventDataRF:InvokeServer("ForceEvent", {
            slot = slot,
            eventType = eventType
        })
    end)
    
    if success then
        print("🧪 [CLIENT] Résultat reçu:", result)
    else
        warn("🧪 [CLIENT] Erreur:", result)
    end
end

-- Fonction pour vérifier les events actifs
local function checkActiveEvents()
    print("🧪 [CLIENT] Vérification des events actifs...")
    
    for slot = 1, 6 do
        local success, result = pcall(function()
            return getEventDataRF:InvokeServer("GetActiveEvent", slot)
        end)
        
        if success and result then
            print("🧪 [CLIENT] Île", slot, "- Event:", result.type, "fin dans", result.endTime - tick(), "s")
        else
            print("🧪 [CLIENT] Île", slot, "- Pas d'event")
        end
    end
end

-- Test au démarrage
wait(2)
print("🧪 [CLIENT] === Test de communication ===")
testForceEvent(1, "TempeteBonbons")

wait(3)
checkActiveEvents()

-- Écouter les touches pour tester
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Appuyer sur "1" pour tester event île 1
    if input.KeyCode == Enum.KeyCode.One then
        testForceEvent(1, "TempeteBonbons")
        
    -- Appuyer sur "2" pour tester event île 2
    elseif input.KeyCode == Enum.KeyCode.Two then
        testForceEvent(2, "PluieIngredientsRares")
        
    -- Appuyer sur "C" pour vérifier les events actifs
    elseif input.KeyCode == Enum.KeyCode.C then
        checkActiveEvents()
        
    -- Appuyer sur "S" pour arrêter event sur île 1
    elseif input.KeyCode == Enum.KeyCode.S then
        local success, result = pcall(function()
            return getEventDataRF:InvokeServer("StopEvent", {slot = 1})
        end)
        print("🧪 [CLIENT] Arrêt event île 1:", success, result)
    end
end)

print("🧪 [CLIENT] Contrôles:")
print("  - Appuyez sur '1' pour event Tempête Bonbons île 1")
print("  - Appuyez sur '2' pour event Pluie Ingrédients île 2") 
print("  - Appuyez sur 'C' pour vérifier les events actifs")
print("  - Appuyez sur 'S' pour arrêter l'event île 1") 