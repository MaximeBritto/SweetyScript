-- StockManager.lua
-- Gère le stock global des ingrédients de la boutique et le timer de réassort.

local StockManager = {}
StockManager.__index = StockManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

local RESTOCK_INTERVAL = 300 -- 5 minutes en secondes
local stockData = {}

local stockValue = Instance.new("Folder")
stockValue.Name = "ShopStock"
stockValue.Parent = ReplicatedStorage

local restockTimeValue = Instance.new("IntValue")
restockTimeValue.Name = "RestockTime"
restockTimeValue.Parent = stockValue

-- Initialisation du stock
local function initializeStock()
    for name, ingredient in pairs(RecipeManager.Ingredients) do
        local maxStock = ingredient.quantiteMax or 50
        stockData[name] = maxStock

        local ingredientStock = Instance.new("IntValue")
        ingredientStock.Name = name
        ingredientStock.Value = maxStock
        ingredientStock.Parent = stockValue
    end
end

function StockManager.getIngredientStock(ingredientName)
    return stockData[ingredientName] or 0
end

function StockManager.decrementIngredientStock(ingredientName, quantity)
    local currentStock = stockData[ingredientName]
    if currentStock then
        local newStock = math.max(0, currentStock - (quantity or 1))
        stockData[ingredientName] = newStock
        if stockValue:FindFirstChild(ingredientName) then
            stockValue[ingredientName].Value = newStock
        end
    end
end

function StockManager.restock()
    print("Réassort de la boutique !")
    for name, ingredient in pairs(RecipeManager.Ingredients) do
        local maxStock = ingredient.quantiteMax or 50
        stockData[name] = maxStock
         if stockValue:FindFirstChild(name) then
            stockValue[name].Value = maxStock
        end
    end
end

-- Boucle de réassort (uniquement côté serveur)
if game:GetService("RunService"):IsServer() then
    coroutine.wrap(function()
        while true do
            for i = RESTOCK_INTERVAL, 1, -1 do
                restockTimeValue.Value = i
                task.wait(1)
            end
            StockManager.restock()
        end
    end)()

    initializeStock()

    -- Remote event pour le réassort forcé (ex: via Robux)
    local forceRestockEvent = Instance.new("RemoteEvent")
    forceRestockEvent.Name = "ForceRestockEvent"
    forceRestockEvent.Parent = ReplicatedStorage

    forceRestockEvent.OnServerEvent:Connect(function(player)
        -- NOTE: La logique de paiement Robux devrait être ici.
        -- Pour l'instant, on réassort directement.
        print(player.Name .. " a déclenché un réassort instantané.")
        StockManager.restock()
    end)
end

return StockManager 