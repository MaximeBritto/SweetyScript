-- CandySellManager.lua
-- Système de vente pour bonbons à tailles variables

local CandySellManager = {}

-- Variable pour stocker GameManager injecté directement
local injectedGameManager = nil

-- Fonction pour recevoir GameManager de GameManager_Fixed.lua
function CandySellManager.setGameManager(gm)
	warn("🔌 [INJECTION REÇUE] GameManager injecté dans CandySellManager")
	injectedGameManager = gm
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import du gestionnaire de tailles
local CandySizeManager
local success, result = pcall(function()
    return require(ReplicatedStorage:WaitForChild("CandySizeManager"))
end)
if success then
    CandySizeManager = result
end

-- Fonction pour obtenir le prix de vente d'un Tool bonbon
function CandySellManager.getCandyPrice(tool)
    if not tool or not tool:IsA("Tool") then
        return 0
    end
    
    local candyName = tool:GetAttribute("BaseName")
    if not candyName then
        return 0
    end
    
    -- Récupérer les données de taille
    if CandySizeManager then
        local sizeData = CandySizeManager.getSizeDataFromTool(tool)
        if sizeData then
            return CandySizeManager.calculatePrice(candyName, sizeData)
        end
    end
    
    -- Prix de base si pas de données de taille
    return 15
end

-- Fonction pour vendre un bonbon (côté serveur)
function CandySellManager.sellCandy(player, tool)
    if not tool or not tool:IsA("Tool") then
        return false, "Objet invalide"
    end
    
    local price = CandySellManager.getCandyPrice(tool)
    if price <= 0 then
        return false, "Impossible de déterminer le prix"
    end
    
    -- Récupérer la quantité
    local count = tool:FindFirstChild("Count")
    local quantity = count and count.Value or 1
    local totalPrice = price * quantity
    
    -- Ajouter l'argent au joueur - Système PlayerData.Argent spécifique
    local playerData = player:FindFirstChild("PlayerData")
    local money = nil
    
    print("🔍 DEBUG ARGENT POUR:", player.Name)
    
    -- Priorité: PlayerData.Argent (ton système)
    if playerData then
        money = playerData:FindFirstChild("Argent")
        if money then
            print("✅ ARGENT TROUVÉ PlayerData.Argent:", money.Value)
        else
            print("❌ PlayerData.Argent introuvable")
            print("📝 CONTENU PlayerData:")
            for _, child in pairs(playerData:GetChildren()) do
                print("  - ", child.Name, "(", child.ClassName, ")")
            end
        end
    else
        print("❌ PlayerData introuvable")
        print("📝 CONTENU PLAYER:")
        for _, child in pairs(player:GetChildren()) do
            print("  - ", child.Name, "(", child.ClassName, ")")
        end
    end
    
    -- Fallback: leaderstats.Argent
    if not money then
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            money = leaderstats:FindFirstChild("Argent")
            if money then
                print("✅ FALLBACK: leaderstats.Argent:", money.Value)
            end
        end
    end
    
    print("🔍 DETECTION ARGENT:", player.Name, "| Leaderstats:", leaderstats and "OUI" or "NON", "| Money trouvé:", money and money.Name or "AUCUN")
    if money then
        print("💰 ARGENT ACTUEL:", money.Name, "=", money.Value)
    end
    
    if money then
        -- Utiliser GameManager pour la synchronisation automatique
        local oldValue = money.Value
        warn("🔍 [VENTE] Tentative d'ajout", totalPrice, "$ pour", player.Name)
        
        -- ATTENDRE GameManager si pas encore chargé
        if not _G.GameManager then
            warn("🕰 [VENTE] Attente GameManager...")
            local maxWait = 50 -- 5 secondes max
            local waited = 0
            while not _G.GameManager and waited < maxWait do
                task.wait(0.1)
                waited = waited + 1
            end
            if _G.GameManager then
                warn("✅ [VENTE] GameManager trouvé après", waited * 0.1, "secondes")
            else
                warn("❌ [VENTE] GameManager introuvable après 5 secondes")
            end
        end
        
        -- PRIORITÉ 1: GameManager injecté directement
        warn("🔍 [VENTE] injectedGameManager:", injectedGameManager and "OUI" or "NON")
        warn("🔍 [VENTE] _G.GameManager:", _G.GameManager and "OUI" or "NON")
        
        local gameManager = injectedGameManager or _G.GameManager
        
        if gameManager and gameManager.ajouterArgent then
            warn("🚀 [VENTE] Appel GameManager.ajouterArgent avec montant:", totalPrice)
            warn("🔍 [VENTE] Source:", injectedGameManager and "INJECTÉ" or "_G")
            local success = gameManager.ajouterArgent(player, totalPrice)
            warn("🎯 [VENTE] Retour success:", success and "true" or "false")
            if not success then
                warn("❌ [VENTE] ÉCHEC ajouterArgent - retour false")
                return false, "Impossible d'ajouter l'argent via GameManager"
            end
            local newValue = gameManager.getArgent(player)
            warn("✅ [VENTE] SUCCÈS ajouterArgent - nouveau montant:", newValue)
            print("💰 ARGENT AJOUTÉ VIA GameManager:", totalPrice, "(" .. oldValue .. " + " .. totalPrice .. " = " .. newValue .. ")")
        else
            -- Fallback: TOUJOURS modifier PlayerData.Argent (jamais leaderstats directement)
            local pd = player:FindFirstChild("PlayerData")
            if pd and pd:FindFirstChild("Argent") then
                pd.Argent.Value = pd.Argent.Value + totalPrice
                print("💰 ARGENT AJOUTÉ FALLBACK (PlayerData):", totalPrice, "(" .. oldValue .. " + " .. totalPrice .. " = " .. pd.Argent.Value .. ")")
                
                -- Synchroniser leaderstats depuis PlayerData
                local ls = player:FindFirstChild("leaderstats")
                if ls and ls:FindFirstChild("Argent") then
                    ls.Argent.Value = pd.Argent.Value
                    print("🔄 SYNC AUTO: leaderstats.Argent =", ls.Argent.Value)
                end
            else
                warn("❌ ERREUR: PlayerData.Argent introuvable pour", player.Name)
                return false, "PlayerData.Argent introuvable"
            end
        end
        
        -- Mettre à jour le système legacy SacBonbons via GameManager
        local candyName = tool:GetAttribute("BaseName") or "Inconnu"
        if _G.GameManager and _G.GameManager.retirerBonbonDuSac then
            local success = _G.GameManager.retirerBonbonDuSac(player, candyName, quantity)
            if success then
                print("🍬 SAC LEGACY MIS À JOUR via GameManager:", candyName, "x" .. quantity, "retiré")
            else
                print("⚠️ ERREUR SAC LEGACY: Impossible de retirer", candyName, "x" .. quantity)
            end
        else
            print("⚠️ GameManager.retirerBonbonDuSac non disponible")
        end
        
        -- Supprimer le Tool du backpack
        tool:Destroy()
        
        -- Rafraîchir le sac visuel
        if _G.GameManager and _G.GameManager.rafraichirSacVisuel then
            _G.GameManager.rafraichirSacVisuel(player)
            print("🎒 SAC VISUEL RAFRAICHI pour", player.Name)
        end
        
        -- Logs de vente
        local sizeData = CandySizeManager and CandySizeManager.getSizeDataFromTool(tool)
        local rarityInfo = sizeData and (" | " .. sizeData.rarity .. " (" .. math.floor(sizeData.size * 100) .. "%)") or ""
        
        print("💰 VENTE REUSSIE:", player.Name, "→", candyName .. rarityInfo, "x" .. quantity, "→", totalPrice .. "$")
        print("💰 ARGENT FINAL:", _G.GameManager and _G.GameManager.getArgent(player) or money.Value, "$")
        
        return true, "Vendu pour " .. totalPrice .. "$"
    else
        return false, "Système de monnaie non trouvé"
    end
end

-- Fonction pour obtenir les informations détaillées d'un bonbon
function CandySellManager.getCandyInfo(tool)
    if not tool or not tool:IsA("Tool") then
        return nil
    end
    
    local candyName = tool:GetAttribute("BaseName") or "Inconnu"
    local count = tool:FindFirstChild("Count")
    local quantity = count and count.Value or 1
    local unitPrice = CandySellManager.getCandyPrice(tool)
    local totalPrice = unitPrice * quantity
    
    local info = {
        name = candyName,
        quantity = quantity,
        unitPrice = unitPrice,
        totalPrice = totalPrice,
        rarity = "Normal",
        size = 1.0
    }
    
    -- Ajouter les infos de taille si disponibles
    if CandySizeManager then
        local sizeData = CandySizeManager.getSizeDataFromTool(tool)
        if sizeData then
            info.rarity = sizeData.rarity
            info.size = sizeData.size
        end
    end
    
    return info
end

-- Fonction pour formater les informations d'affichage
function CandySellManager.formatCandyDisplay(candyInfo)
    if not candyInfo then return "Bonbon Inconnu" end
    
    local rarityColor = "⚪" -- Normal
    if candyInfo.rarity == "Minuscule" then rarityColor = "⚫"
    elseif candyInfo.rarity == "Petit" then rarityColor = "🟤"
    elseif candyInfo.rarity == "Grand" then rarityColor = "🟢"
    elseif candyInfo.rarity == "Géant" then rarityColor = "🔵"
    elseif candyInfo.rarity == "Colossal" then rarityColor = "🟣"
    elseif candyInfo.rarity == "LÉGENDAIRE" then rarityColor = "🟡"
    end
    
    local sizePercent = math.floor(candyInfo.size * 100)
    local displayName = candyInfo.name .. " " .. rarityColor .. " " .. candyInfo.rarity .. " (" .. sizePercent .. "%)"
    
    if candyInfo.quantity > 1 then
        displayName = displayName .. " x" .. candyInfo.quantity
    end
    
    return displayName, candyInfo.totalPrice .. "$"
end

-- Fonction pour trier les bonbons par valeur (pour interface de vente)
function CandySellManager.sortCandiesByValue(tools)
    local candyInfos = {}
    
    for _, tool in pairs(tools) do
        if tool:IsA("Tool") and tool:GetAttribute("BaseName") then
            local info = CandySellManager.getCandyInfo(tool)
            if info then
                info.tool = tool
                table.insert(candyInfos, info)
            end
        end
    end
    
    -- Trier par prix total décroissant
    table.sort(candyInfos, function(a, b)
        return a.totalPrice > b.totalPrice
    end)
    
    return candyInfos
end

return CandySellManager
