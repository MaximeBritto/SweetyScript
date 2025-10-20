-- TestRandomizedShop.lua
-- Script de test pour vérifier le système de randomisation du shop

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Attendre que les modules soient chargés
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))
local StockManager = require(ReplicatedStorage:WaitForChild("StockManager"))

-- Fonction pour tester la randomisation
local function testRandomizedRestock()
    print("🧪 [TEST] Test du système de randomisation du shop...")
    
    -- Simuler plusieurs restocks pour voir la variabilité
    for i = 1, 5 do
        print("\n--- RESTOCK #" .. i .. " ---")
        StockManager.restock()
        
        -- Afficher quelques exemples d'ingrédients par rareté
        local examples = {
            ["Common"] = "Sucre",
            ["Rare"] = "Framboise", 
            ["Epic"] = "CremeFouettee",
            ["Legendary"] = "EssenceArcEnCiel",
            ["Mythic"] = "SouffleCeleste"
        }
        
        -- Vérifier les ingrédients essentiels
        local sucreStock = StockManager.getIngredientStock("Sucre")
        local gelatineStock = StockManager.getIngredientStock("Gelatine")
        print("  🍯 Sucre (essentiel): " .. sucreStock .. " (minimum garanti: 3)")
        print("  🍮 Gelatine (essentiel): " .. gelatineStock .. " (minimum garanti: 3)")
        
        for rarity, ingredientName in pairs(examples) do
            local stock = StockManager.getIngredientStock(ingredientName)
            local config = RecipeManager.RestockRanges[rarity]
            print("  " .. ingredientName .. " (" .. rarity .. "): " .. stock .. " (plage: " .. config.minQuantity .. "-" .. config.maxQuantity .. ")")
        end
    end
    
    print("\n✅ [TEST] Test terminé ! Vérifiez les logs ci-dessus pour voir la randomisation.")
end

-- Exécuter le test quand un joueur rejoint
Players.PlayerAdded:Connect(function(player)
    wait(2) -- Attendre que tout soit chargé
    testRandomizedRestock()
end)

-- Si on est déjà en jeu, exécuter le test immédiatement
if #Players:GetPlayers() > 0 then
    wait(2)
    testRandomizedRestock()
end
