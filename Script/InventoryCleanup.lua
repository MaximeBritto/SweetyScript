--[[
InventoryCleanup.lua - Script de nettoyage d'urgence pour les doublons
Ce script supprime les doublons d'items causés par le bug de restauration.

À exécuter UNE SEULE FOIS pour nettoyer les doublons existants.
Peut être placé temporairement dans ServerScriptService.
--]]

local Players = game:GetService("Players")

-- Script de nettoyage d'urgence
local function cleanupPlayerInventory(player)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then 
        warn("❌ [CLEANUP] Pas de backpack pour", player.Name)
        return 
    end
    
    print("🧹 [CLEANUP] Nettoyage de l'inventaire de", player.Name)
    
    -- Regrouper les items par BaseName
    local itemGroups = {}
    local totalCleaned = 0
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local baseName = tool:GetAttribute("BaseName") or tool.Name
            
            if not itemGroups[baseName] then
                itemGroups[baseName] = {
                    tools = {},
                    totalQuantity = 0,
                    isCandy = tool:GetAttribute("IsCandy") or false
                }
            end
            
            local count = tool:FindFirstChild("Count")
            local quantity = count and count.Value or 1
            
            table.insert(itemGroups[baseName].tools, tool)
            itemGroups[baseName].totalQuantity = itemGroups[baseName].totalQuantity + quantity
        end
    end
    
    -- Nettoyer les doublons et consolider
    for baseName, group in pairs(itemGroups) do
        if #group.tools > 1 then
            print("🔧 [CLEANUP]", baseName, ":", #group.tools, "doublons trouvés, quantité totale:", group.totalQuantity)
            
            -- Garder seulement le premier tool, détruire les autres
            local keepTool = group.tools[1]
            
            for i = 2, #group.tools do
                group.tools[i]:Destroy()
                totalCleaned = totalCleaned + 1
            end
            
            -- Mettre à jour la quantité du tool gardé
            local count = keepTool:FindFirstChild("Count")
            if count then
                count.Value = group.totalQuantity
            end
            
            print("✅ [CLEANUP]", baseName, "nettoyé - Quantité finale:", group.totalQuantity)
        end
    end
    
    print("🎉 [CLEANUP] Nettoyage terminé pour", player.Name, "- Items doublons supprimés:", totalCleaned)
end

-- Nettoyer tous les joueurs connectés
print("🚨 [CLEANUP] DÉMARRAGE DU NETTOYAGE D'URGENCE DES DOUBLONS")

for _, player in pairs(Players:GetPlayers()) do
    if player.Character then
        cleanupPlayerInventory(player)
    end
end

print("✅ [CLEANUP] NETTOYAGE TERMINÉ POUR TOUS LES JOUEURS")
print("⚠️ [CLEANUP] Ce script peut maintenant être supprimé")

-- Auto-destruction du script après 10 secondes
task.wait(10)
script:Destroy()