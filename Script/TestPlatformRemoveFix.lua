--[[
    🧪 TEST: Vérification des corrections du système Remove des plateformes
    Ce script teste les corrections apportées au système de suppression des bonbons
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Attendre que les modules soient chargés
local function waitForModules()
    local modules = {
        "CandyPlatforms",
        "CustomBackpack"
    }
    
    for _, moduleName in ipairs(modules) do
        if not _G[moduleName] then
            print("⏳ Attente du module:", moduleName)
            repeat
                task.wait(0.1)
            until _G[moduleName]
        end
        print("✅ Module chargé:", moduleName)
    end
end

-- Test de la fonction de suppression
local function testRemoveSystem()
    print("🧪 === TEST DU SYSTÈME REMOVE ===")
    
    -- Vérifier que les fonctions sont exposées
    if _G.CustomBackpack then
        print("✅ CustomBackpack exposé dans _G")
        if _G.CustomBackpack.updateAllHotbarSlots then
            print("✅ updateAllHotbarSlots disponible")
        else
            print("❌ updateAllHotbarSlots manquant")
        end
        
        if _G.CustomBackpack.scheduleInventoryUpdate then
            print("✅ scheduleInventoryUpdate disponible")
        else
            print("❌ scheduleInventoryUpdate manquant")
        end
    else
        print("❌ CustomBackpack non exposé dans _G")
    end
    
    -- Vérifier que CandyPlatforms est disponible
    if _G.CandyPlatforms then
        print("✅ CandyPlatforms disponible")
    else
        print("❌ CandyPlatforms non disponible")
    end
    
    print("🧪 === FIN DU TEST ===")
end

-- Fonction principale
local function main()
    print("🚀 Démarrage du test des corrections Remove")
    
    -- Attendre que le joueur soit chargé
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    
    -- Attendre un peu pour que tout se charge
    task.wait(2)
    
    -- Attendre les modules
    waitForModules()
    
    -- Lancer le test
    testRemoveSystem()
    
    print("✅ Test terminé - Vérifiez les logs ci-dessus")
end

-- Démarrer le test
main()


