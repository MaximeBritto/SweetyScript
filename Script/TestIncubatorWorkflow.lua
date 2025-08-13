-- Script de test pour vérifier le workflow complet de l'incubateur
-- À placer dans ServerScriptService pour tester

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("🧪 [TEST] Script de test du workflow incubateur - Démarrage")

-- Vérifier que tous les RemoteEvents existent
local requiredRemotes = {
    -- RemoteEvents
    "OpenIncubatorMenu",
    "PlaceIngredientInSlot", 
    "RemoveIngredientFromSlot",
    "StartCrafting",
    "IncubatorCraftProgress",
    "PickupCandyEvent",
    "AchatIngredientEvent_V2",
    "OuvrirMenuEvent",
    -- RemoteFunctions
    "GetIncubatorSlots"
}

print("🔍 [TEST] Vérification des RemoteEvents...")
local allFound = true
for _, remoteName in ipairs(requiredRemotes) do
    local remote = ReplicatedStorage:FindFirstChild(remoteName)
    if remote then
        print("✅ [TEST]", remoteName, ":", remote.ClassName)
    else
        print("❌ [TEST]", remoteName, ": MANQUANT!")
        allFound = false
    end
end

if allFound then
    print("🎉 [TEST] Tous les RemoteEvents requis sont présents!")
else
    print("⚠️ [TEST] Certains RemoteEvents manquent - exécuter CreateRemoteEvents.lua")
end

-- Vérifier RecipeManager
print("🔍 [TEST] Vérification du RecipeManager...")
local recipeManager = ReplicatedStorage:FindFirstChild("RecipeManager")
if recipeManager and recipeManager:IsA("ModuleScript") then
    local success, module = pcall(require, recipeManager)
    if success and module then
        print("✅ [TEST] RecipeManager chargé:")
        if module.Ingredients then
            local ingredientCount = 0
            for name, _ in pairs(module.Ingredients) do
                ingredientCount = ingredientCount + 1
            end
            print("  - Ingrédients:", ingredientCount)
        end
        if module.Recettes then
            local recipeCount = 0
            for name, recipe in pairs(module.Recettes) do
                recipeCount = recipeCount + 1
                -- Vérifier quelques recettes de base
                if name == "Basique" or name == "Basique Gelatine" then
                    print("  - Recette", name, ":")
                    if recipe.ingredients then
                        for ingredient, qty in pairs(recipe.ingredients) do
                            print("    -", ingredient, ":", qty)
                        end
                    end
                end
            end
            print("  - Recettes:", recipeCount)
        end
    else
        print("❌ [TEST] Erreur lors du chargement de RecipeManager:", module)
    end
else
    print("❌ [TEST] RecipeManager non trouvé!")
end

-- Test de correspondance des noms d'ingrédients
print("🔍 [TEST] Test de correspondance des noms d'ingrédients...")
if recipeManager then
    local success, module = pcall(require, recipeManager)
    if success and module and module.Ingredients and module.Recettes then
        -- Vérifier que tous les ingrédients utilisés dans les recettes existent
        local invalidIngredients = {}
        for recipeName, recipe in pairs(module.Recettes) do
            if recipe.ingredients then
                for ingredient, qty in pairs(recipe.ingredients) do
                    -- Convertir en format attendu (première lettre majuscule)
                    local expectedName = ingredient:gsub("^%l", string.upper)
                    if not module.Ingredients[expectedName] then
                        if not invalidIngredients[ingredient] then
                            invalidIngredients[ingredient] = {}
                        end
                        table.insert(invalidIngredients[ingredient], recipeName)
                    end
                end
            end
        end
        
        if next(invalidIngredients) then
            print("⚠️ [TEST] Ingrédients invalides trouvés dans les recettes:")
            for ingredient, recipes in pairs(invalidIngredients) do
                print("  -", ingredient, "utilisé dans:", table.concat(recipes, ", "))
            end
        else
            print("✅ [TEST] Tous les ingrédients des recettes sont valides!")
        end
    end
end

print("🧪 [TEST] Tests de base terminés - Testez maintenant en jeu:")
print("1. Ouvrir le menu d'achat d'ingrédients")
print("2. Acheter du Sucre et de la Gelatine") 
print("3. Cliquer sur un incubateur pour ouvrir le menu")
print("4. Placer Sucre dans slot 1, Gelatine dans slot 2")
print("5. Vérifier qu'une recette 'Basique Gelatine' apparaît")
print("6. Cliquer sur le slot de sortie pour démarrer la production")



