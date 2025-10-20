-- TestCandyPricing.lua
-- Script de test pour vérifier que les bonbons valent toujours au minimum 1$

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Attendre que les modules soient chargés
local CandySizeManager = require(ReplicatedStorage:WaitForChild("CandySizeManager"))
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- Fonction pour tester le calcul de prix
local function testCandyPricing()
    print("🧪 [TEST] Test du système de prix des bonbons...")
    
    -- Tester avec le bonbon basique (prix de base = 1$)
    local candyName = "Basique Gelatine"
    
    -- Tester différentes tailles
    local testSizes = {
        {size = 0.5, rarity = "Tiny"},
        {size = 0.75, rarity = "Small"}, 
        {size = 1.0, rarity = "Normal"},
        {size = 1.5, rarity = "Large"},
        {size = 2.0, rarity = "Giant"}
    }
    
    for i, sizeData in ipairs(testSizes) do
        local price = CandySizeManager.calculatePrice(candyName, sizeData)
        print("  " .. candyName .. " (taille " .. sizeData.size .. ", " .. sizeData.rarity .. "): " .. price .. "$")
        
        if price < 1 then
            warn("❌ ERREUR: Prix inférieur à 1$ !")
        else
            print("  ✅ Prix correct (≥ 1$)")
        end
    end
    
    print("\n✅ [TEST] Test terminé ! Tous les bonbons devraient valoir au minimum 1$.")
end

-- Exécuter le test quand un joueur rejoint
Players.PlayerAdded:Connect(function(player)
    wait(2) -- Attendre que tout soit chargé
    testCandyPricing()
end)

-- Si on est déjà en jeu, exécuter le test immédiatement
if #Players:GetPlayers() > 0 then
    wait(2)
    testCandyPricing()
end

