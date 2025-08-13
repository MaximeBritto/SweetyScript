-- CandySellServer.lua
-- Gestionnaire côté serveur pour la vente de bonbons
-- À placer dans ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Plus besoin de CandySellManager - logique directe ici
-- local CandySellManager = require(ReplicatedStorage:WaitForChild("CandySellManager"))

-- RemoteEvents pour la communication client-serveur
local sellRemotes = ReplicatedStorage:FindFirstChild("CandySellRemotes")
if not sellRemotes then
    sellRemotes = Instance.new("Folder")
    sellRemotes.Name = "CandySellRemotes"
    sellRemotes.Parent = ReplicatedStorage
    print("⚙️ Dossier CandySellRemotes créé")
end

local sellCandyRemote = sellRemotes:FindFirstChild("SellCandy")
if not sellCandyRemote then
    sellCandyRemote = Instance.new("RemoteFunction")
    sellCandyRemote.Name = "SellCandy"
    sellCandyRemote.Parent = sellRemotes
    print("⚙️ RemoteFunction SellCandy créée")
end

local getCandyPriceRemote = sellRemotes:FindFirstChild("GetCandyPrice")
if not getCandyPriceRemote then
    getCandyPriceRemote = Instance.new("RemoteFunction")
    getCandyPriceRemote.Name = "GetCandyPrice"
    getCandyPriceRemote.Parent = sellRemotes
    print("⚙️ RemoteFunction GetCandyPrice créée")
end

-- Fonction pour vendre un bonbon (sécurisée côté serveur)
sellCandyRemote.OnServerInvoke = function(player, toolName)
    warn("🔥 [SELL-SERVER] DÉBUT vente pour:", player.Name, "tool:", toolName)
    
    if not player or not toolName then
        warn("❌ [SELL-SERVER] Paramètres invalides")
        return false, "Paramètres invalides"
    end
    
    -- Vérifier que le joueur possède le Tool (Backpack ET Character)
    local backpack = player:FindFirstChildOfClass("Backpack")
    local character = player.Character
    
    local tool = nil
    
    -- Chercher dans le backpack
    if backpack then
        for _, t in pairs(backpack:GetChildren()) do
            if t:IsA("Tool") and t.Name == toolName then
                tool = t
                warn("🎒 [SELL-SERVER] Bonbon trouvé dans BACKPACK:", toolName)
                break
            end
        end
    end
    
    -- Si pas trouvé dans le backpack, chercher dans le character (main)
    if not tool and character then
        for _, t in pairs(character:GetChildren()) do
            if t:IsA("Tool") and t.Name == toolName then
                tool = t
                warn("👍 [SELL-SERVER] Bonbon trouvé dans CHARACTER (main):", toolName)
                break
            end
        end
    end
    
    if not tool then
        warn("❌ [SELL-SERVER] Bonbon NON TROUVÉ:", toolName, "ni dans backpack ni dans character")
        return false, "Bonbon non trouvé dans l'inventaire ou en main"
    end
    
    -- Vérifier que c'est bien un bonbon
    if not tool:GetAttribute("BaseName") then
        return false, "Objet invalide - pas de BaseName"
    end
    
    -- Vérification de sécurité : doit être marqué comme bonbon
    if not tool:GetAttribute("IsCandy") then
        warn("⚠️ [SELL-SERVER] Tentative de vente d'un non-bonbon:", tool.Name, "BaseName:", tool:GetAttribute("BaseName"))
        return false, "Seuls les bonbons peuvent être vendus"
    end
    
    -- VENTE DIRECTE AVEC _G.GameManager (bypass CandySellManager)
    warn("🚀 [SELL-SERVER] Vente directe:", tool.Name, "pour", player.Name)
    
    -- 1. Calculer le prix réel
    local baseName = tool:GetAttribute("BaseName") or tool.Name
    local stackSize = tool:GetAttribute("StackSize") or 1
    
    -- Lire les vraies données de taille et rareté
    local candySize = tool:GetAttribute("CandySize") or 1.0
    local candyRarity = tool:GetAttribute("CandyRarity") or "Normal"
    
    -- Calculer le vrai prix (même logique que l'UI)
    local basePrice = 15 -- Prix de base
    local sizeMultiplier = candySize ^ 2.5 -- Progression exponentielle
    
    -- Bonus de rareté
    local rarityBonus = 1
    if candyRarity == "Grand" then rarityBonus = 1.1
    elseif candyRarity == "Géant" then rarityBonus = 1.2
    elseif candyRarity == "Colossal" then rarityBonus = 1.5
    elseif candyRarity == "LÉGENDAIRE" then rarityBonus = 2.0
    end
    
    local unitPrice = math.floor(basePrice * sizeMultiplier * rarityBonus)
    local totalPrice = math.max(unitPrice * stackSize, 1)

    -- Passif: EssenceRare → prix de vente x1.5
    local pd = player:FindFirstChild("PlayerData")
    local su = pd and pd:FindFirstChild("ShopUnlocks")
    local rareFlag = su and su:FindFirstChild("EssenceRare")
    if rareFlag and rareFlag.Value == true then
        totalPrice = math.floor(totalPrice * 1.5)
    end
    
    warn("💰 [SELL-SERVER] Prix calculé:", totalPrice, "$ (", candyRarity, candySize .. "x,", stackSize, "unités) - Base:", basePrice, "Mult:", math.floor(sizeMultiplier*100)/100, "Bonus:", rarityBonus)
    
    -- 2. Ajouter l'argent via GameManager
    warn("🔍 [SELL-SERVER] Vérification _G.GameManager:", _G.GameManager and "OUI" or "NON")
    if _G.GameManager then
        warn("🔍 [SELL-SERVER] ajouterArgent:", _G.GameManager.ajouterArgent and "OUI" or "NON")
    end
    
    if _G.GameManager and _G.GameManager.ajouterArgent then
        warn("🎯 [SELL-SERVER] Appel GameManager.ajouterArgent avec", totalPrice, "$")
        local success = _G.GameManager.ajouterArgent(player, totalPrice)
        warn("🔄 [SELL-SERVER] Résultat ajouterArgent:", success and "OUI" or "NON")
        if not success then
            warn("❌ [SELL-SERVER] Échec ajout argent")
            return false, "Impossible d'ajouter l'argent"
        end
        
        -- 3. Supprimer le tool
        tool:Destroy()
        warn("✅ [SELL-SERVER] Vente réussie:", totalPrice, "$")
        
        -- 🎓 TUTORIAL: Signaler la vente au tutoriel
        if _G.TutorialManager and _G.TutorialManager.onCandySold then
            print("🎓 [TUTORIAL] Signalement vente bonbon au tutoriel pour:", player.Name)
            _G.TutorialManager.onCandySold(player)
        else
            print("⚠️ [TUTORIAL] TutorialManager.onCandySold non disponible")
        end
        
        return true, "Bonbon vendu pour " .. totalPrice .. "$"
    else
        warn("❌ [SELL-SERVER] GameManager introuvable")
        return false, "GameManager indisponible"
    end
end

-- Fonction pour obtenir le prix d'un bonbon
getCandyPriceRemote.OnServerInvoke = function(player, toolName)
    if not player or not toolName then
        return 0
    end
    
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return 0
    end
    
    local tool = nil
    for _, t in pairs(backpack:GetChildren()) do
        if t:IsA("Tool") and t.Name == toolName then
            tool = t
            break
        end
    end
    
    if not tool then
        return 0
    end
    
    -- Calcul de prix simple
    local stackSize = tool:GetAttribute("StackSize") or 1
    return 5 * stackSize -- Prix de base * quantité
end

-- Gestion des connexions/déconnexions
Players.PlayerAdded:Connect(function(player)
    print("🎮 Joueur connecté au système de vente:", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
    print("👋 Joueur déconnecté du système de vente:", player.Name)
end)

print("🏪 SERVEUR DE VENTE DÉMARRÉ !")
print("💰 RemoteEvents créés pour la communication client-serveur")
