-- GameManager_Fixed.lua  – Argent initial 100 $, leaderstats synchro,
--                         sac à bonbons stackable, production, achats, ventes

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _RunService       = game:GetService("RunService")

-------------------------------------------------
-- MODULES & REMOTES
-------------------------------------------------
-- Fonction de chargement sécurisée pour les modules
local function requireModule(name)
	local module = ReplicatedStorage:WaitForChild(name, 20)
	if module and module:IsA("ModuleScript") then
		local success, result = pcall(require, module)
		if success then
			return result
		else
			warn("❌ Erreur lors de l'exécution du module '" .. name .. "': " .. tostring(result))
			return nil
		end
	else
		warn("❌ Impossible de charger le module '" .. name .. "'. Il est introuvable ou n'est pas un ModuleScript.")
		return nil
	end
end

-- Chargement des modules essentiels
local RecipeManager = requireModule("RecipeManager")
local StockManager = requireModule("StockManager")
local SaveDataManager = requireModule("SaveDataManager")

-- On arrête tout si un module critique est manquant
if not RecipeManager or not StockManager then
	error("ERREUR CRITIQUE: Un ou plusieurs modules essentiels (RecipeManager, StockManager) n'ont pas pu être chargés. Le jeu ne peut pas continuer.")
end

if not SaveDataManager then
	warn("⚠️ SaveDataManager non disponible - le système de sauvegarde sera désactivé")
end

local RECETTES = RecipeManager.Recettes

local function waitForRemoteEvent(name)
	local ev = ReplicatedStorage:WaitForChild(name, 10)
	if not ev then warn("RemoteEvent manquant : "..name) end
	return ev
end

-- Remote utilitaires
local function getOrCreateRemoteEvent(name)
	local ev = ReplicatedStorage:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = ReplicatedStorage
	end
	return ev
end

local function signalPlayerDataReady(plr)
	pcall(function()
		plr:SetAttribute("DataReady", true)
	end)
	local ev = getOrCreateRemoteEvent("PlayerDataReady")
	ev:FireClient(plr)
end

-- Délai supplémentaire pour laisser finir la restauration offline lourde (incubateur)
local OFFLINE_READY_EXTRA_DELAY = 3.6

-- On utilise le nouveau nom d'événement pour être sûr d'être le seul à écouter
 local evAchat   = waitForRemoteEvent("AchatIngredientEvent_V2")
 local evUpgrade = waitForRemoteEvent("UpgradeEvent")
local evProd    = waitForRemoteEvent("DemarrerProductionEvent")

-- Créer le RemoteEvent pour la revente d'ingrédients
local evVenteIngredient = getOrCreateRemoteEvent("VendreIngredientEvent")

-- Remote pour réclamer les récompenses Pokédex (essences/passifs)
local claimRewardEvt = ReplicatedStorage:FindFirstChild("ClaimPokedexReward")
if not claimRewardEvt then
    claimRewardEvt = Instance.new("RemoteEvent")
    claimRewardEvt.Name = "ClaimPokedexReward"
    claimRewardEvt.Parent = ReplicatedStorage
end

-------------------------------------------------
-- INIT JOUEUR
-------------------------------------------------
-- Assure la présence du dossier ShopUnlocks et des 5 booléens d'essence
local function ensureShopUnlocksFolder(plr)
    local pd = plr:FindFirstChild("PlayerData")
    if not pd then return end
    local su = pd:FindFirstChild("ShopUnlocks")
    if not su then
        su = Instance.new("Folder")
        su.Name = "ShopUnlocks"
        su.Parent = pd
    end
    local keys = {
        "EssenceCommune",
        "EssenceRare",
        "EssenceEpique",
        "EssenceLegendaire",
        "EssenceMythique",
    }
    for _, k in ipairs(keys) do
        if not su:FindFirstChild(k) then
            local b = Instance.new("BoolValue")
            b.Name = k
            b.Value = false
            b.Parent = su
        end
    end
end

local function setupPlayerData(plr)
    -- Vérifier si PlayerData existe déjà (pour éviter d'écraser les données)
	local pd = plr:FindFirstChild("PlayerData")
	if pd then
		local argent = pd:FindFirstChild("Argent")
        
		-- 🔄 MIGRATION: Convertir IntValue en NumberValue pour supporter les gros montants
		if argent and argent:IsA("IntValue") then
			local oldValue = argent.Value
			argent:Destroy()
			argent = Instance.new("NumberValue", pd)
			argent.Name = "Argent"
			argent.Value = oldValue
		end
		
        -- Juste s'assurer que leaderstats est synchronisé
        argent = pd:FindFirstChild("Argent")
		if argent then
			local ls = plr:FindFirstChild("leaderstats") or Instance.new("Folder", plr)
			ls.Name = "leaderstats"
			local argentStat = ls:FindFirstChild("Money")
			
			-- 🔄 MIGRATION: Convertir IntValue en StringValue pour affichage formaté
			if argentStat and argentStat:IsA("IntValue") then
				local oldValue = argentStat.Value
				argentStat:Destroy()
				argentStat = Instance.new("StringValue", ls)
				argentStat.Name = "Money"
				-- Formater l'argent avec UIUtils
				local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
				argentStat.Value = UIUtils.formatMoneyShort(oldValue)
			elseif not argentStat then
				argentStat = Instance.new("StringValue", ls)
				argentStat.Name = "Money"
				-- Formater l'argent avec UIUtils
				local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
				argentStat.Value = UIUtils.formatMoneyShort(argent.Value)
			end
			
			-- Formater l'argent initial
			local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
			argentStat.Value = UIUtils.formatMoneyShort(argent.Value)
			
			-- Sync PlayerData → leaderstats avec formatage
			argent.Changed:Connect(function(v) 
				argentStat.Value = UIUtils.formatMoneyShort(v)
			end)
			-- GARDE-FOU: Rétablir leaderstats si modifié directement
			argentStat.Changed:Connect(function(v)
				local vraiArgent = argent.Value
				local formattedArgent = UIUtils.formatMoneyShort(vraiArgent)
				if v ~= formattedArgent then
					argentStat.Value = formattedArgent
				end
			end)
		end

        -- S'assurer que le compteur de plateformes débloquées existe
        if not pd:FindFirstChild("PlatformsUnlocked") then
            local pu = Instance.new("IntValue")
            pu.Name = "PlatformsUnlocked"
            pu.Value = 0
            pu.Parent = pd
        end

        -- S'assurer que le niveau du marchand existe
        if not pd:FindFirstChild("MerchantLevel") then
            local ml = Instance.new("IntValue")
            ml.Name = "MerchantLevel"
            ml.Value = 1
            ml.Parent = pd
        end

		-- S'assurer que le compteur d'incubateurs débloqués existe (1 par défaut)
		if not pd:FindFirstChild("IncubatorsUnlocked") then
			local iu = Instance.new("IntValue")
			iu.Name = "IncubatorsUnlocked"
			iu.Value = 1
			iu.Parent = pd
		end
        -- S'assurer des passifs ShopUnlocks
        ensureShopUnlocksFolder(plr)
		return
	end
	
	-- Créer PlayerData si n'existe pas
	pd = Instance.new("Folder", plr)
	pd.Name = "PlayerData"

	local argent = Instance.new("NumberValue", pd)
	argent.Name, argent.Value = "Argent", 30

    local ls = Instance.new("Folder", plr)
    ls.Name = "leaderstats"
    local argentStat = Instance.new("StringValue", ls)
    argentStat.Name = "Money"
    -- Formater l'argent avec UIUtils
    local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
    argentStat.Value = UIUtils.formatMoneyShort(argent.Value)
	argent.Changed:Connect(function(v) 
		argentStat.Value = UIUtils.formatMoneyShort(v)
	end)

    local sac = Instance.new("Folder", pd)
    sac.Name = "SacBonbons"
	local maxSlots = Instance.new("IntValue", pd)
	maxSlots.Name, maxSlots.Value = "MaxSlotsSac", 20

	for _,ing in ipairs({"Sucre","Sirop","AromeFruit"}) do
        local iv = Instance.new("IntValue", pd)
        iv.Name = ing
	end
	local maxIng = Instance.new("IntValue", pd)
	maxIng.Name, maxIng.Value = "MaxIngredients", 30

	Instance.new("BoolValue",   pd).Name = "EnProduction"
	Instance.new("NumberValue", pd).Name = "TempsProductionRestant"
	Instance.new("StringValue", pd).Name = "RecetteEnCours"

    -- Nombre de plateformes débloquées par joueur
    local platformsUnlocked = Instance.new("IntValue", pd)
    platformsUnlocked.Name = "PlatformsUnlocked"
    platformsUnlocked.Value = 0

    local rf = Instance.new("Folder", pd)
    rf.Name = "RecettesDecouvertes"
    local base = Instance.new("BoolValue", rf)
    base.Name, base.Value = "Basique", true

    -- Niveau marchand (débloque les raretés au shop)
    local merchantLevel = Instance.new("IntValue", pd)
    merchantLevel.Name = "MerchantLevel"
    merchantLevel.Value = 1

	-- Nombre d'incubateurs débloqués (1 au départ)
	local incubatorsUnlocked = Instance.new("IntValue", pd)
	incubatorsUnlocked.Name = "IncubatorsUnlocked"
	incubatorsUnlocked.Value = 1
    -- Initialiser le dossier ShopUnlocks et les 5 essences
    ensureShopUnlocksFolder(plr)
end

-------------------------------------------------
-- SAC À BONBONS
-------------------------------------------------
local CandyTools = requireModule("CandyTools")
local function ajouterBonbonAuSac(plr, typeB)
	local success = CandyTools.giveCandy(plr, typeB, 1)
	return success
end

-- Fonction de synchronisation simple (comme setupPlayerData)
local function syncArgentLeaderstats(plr)
	local pd = plr:FindFirstChild("PlayerData")
	local ls = plr:FindFirstChild("leaderstats")
	if pd and pd.Argent and ls and ls.Money then
		local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
		ls.Money.Value = UIUtils.formatMoneyShort(pd.Argent.Value)
	end
end

-- Fonctions de gestion de l'argent - MODIFIE LEADERSTATS DIRECTEMENT
local function ajouterArgent(plr, montant)
	-- Modifier PlayerData EN PREMIER (la vraie source)
	local pd = plr:FindFirstChild("PlayerData")
	if pd and pd:FindFirstChild("Argent") then
		pd.Argent.Value = pd.Argent.Value + montant
		
		-- Synchroniser leaderstats avec formatage
		local ls = plr:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Money") then
			local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
			ls.Money.Value = UIUtils.formatMoneyShort(pd.Argent.Value)
		end
		return true
	end
	
	return false
end

local function retirerArgent(plr, montant)
	-- Retirer depuis PlayerData EN PREMIER (la vraie source)
	local pd = plr:FindFirstChild("PlayerData")
	if pd and pd:FindFirstChild("Argent") and pd.Argent.Value >= montant then
		pd.Argent.Value = pd.Argent.Value - montant
		
		-- Synchroniser leaderstats avec formatage
		local ls = plr:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Money") then
			local UIUtils = require(game:GetService("ReplicatedStorage"):WaitForChild("UIUtils"))
			ls.Money.Value = UIUtils.formatMoneyShort(pd.Argent.Value)
		end
		return true
	end
	
	return false
end

local function getArgent(plr)
	-- Toujours utiliser PlayerData comme source de vérité (valeur numérique)
	local pd = plr:FindFirstChild("PlayerData")
	if pd and pd:FindFirstChild("Argent") then
		return pd.Argent.Value
	end
	
	return 0
end

-- Fonction pour forcer la mise à jour du sac visuel
local function rafraichirSacVisuel(plr)
	local backpackRefreshEvent = ReplicatedStorage:FindFirstChild("BackpackRefreshEvent")
	if not backpackRefreshEvent then
		backpackRefreshEvent = Instance.new("RemoteEvent")
		backpackRefreshEvent.Name = "BackpackRefreshEvent"
		backpackRefreshEvent.Parent = ReplicatedStorage
	end
	backpackRefreshEvent:FireClient(plr)
end

-- Fonction pour retirer des bonbons du sac (SYSTÈME MODERNE)
local function retirerBonbonDuSac(plr, typeB, q)
	local success = CandyTools.removeCandy(plr, typeB, q)
	return success
end

-------------------------------------------------
-- RECETTES SECRÈTES
-------------------------------------------------
local function debloquerRecettesSecretes(plr)
	local sac = plr.PlayerData.SacBonbons
	local rf  = plr.PlayerData.RecettesDecouvertes
	if sac.Basique and sac.Basique.Value>=5 and not rf:FindFirstChild("Fraise") then
		Instance.new("BoolValue", rf).Name="Fraise"
	end
	if sac:FindFirstChild("Fraise") and sac.Fraise.Value>=3 and not rf:FindFirstChild("ChocoMenthe") then
		Instance.new("BoolValue", rf).Name="ChocoMenthe"
	end
	if sac:FindFirstChild("ChocoMenthe") and sac.ChocoMenthe.Value>=2 and not rf:FindFirstChild("Galaxie") then
		Instance.new("BoolValue", rf).Name="Galaxie"
	end
end

-------------------------------------------------
-- PRODUCTION
-------------------------------------------------
local function terminerProduction(plr)
	local pd = plr.PlayerData
	local rec = pd.RecetteEnCours.Value
	if rec~="" and RECETTES[rec] and ajouterBonbonAuSac(plr, rec) then debloquerRecettesSecretes(plr) end
    pd.EnProduction.Value = false
    pd.RecetteEnCours.Value = ""
end

local function demarrerProduction(plr, recName)
    local pd = plr.PlayerData
    if pd.EnProduction.Value then return end
    local def = RECETTES[recName]
    if not def then return end
	for ing,req in pairs(def.ingredients) do
		if pd[ing].Value < req then return end
	end
	for ing,req in pairs(def.ingredients) do pd[ing].Value -= req end
	pd.RecetteEnCours.Value = recName
	pd.TempsProductionRestant.Value = def.temps
	pd.EnProduction.Value = true
	if def.temps==0 then terminerProduction(plr) end
end

-------------------------------------------------
-- ACHATS STACKABLES
-------------------------------------------------
-- Système d'upgrade du marchand
local MAX_MERCHANT_LEVEL = 5
local UPGRADE_COSTS = {
    [1] = 300000000000,   -- vers 2 (Rare) - 300 Billions
    [2] = 500000000000,  -- vers 3 (Epic) - 500 Billions
    [3] = 10000000000000,  -- vers 4 (Legendary) - 10 Trillions
    [4] = 400000000000000000, -- vers 5 (Mythic) - 400 Quadrillions
}

local function normalizeRareteName(rarete)
    if type(rarete) ~= "string" then return "Common" end
    local s = rarete
    s = s:gsub("É", "e"):gsub("é", "e"):gsub("È", "e"):gsub("è", "e"):gsub("Ê", "e"):gsub("ê", "e")
    s = s:gsub("À", "a"):gsub("Â", "a"):gsub("Ä", "a"):gsub("à", "a"):gsub("â", "a"):gsub("ä", "a")
    s = s:gsub("Ï", "i"):gsub("î", "i"):gsub("ï", "i")
    s = s:gsub("Ô", "o"):gsub("ô", "o")
    s = s:gsub("Ù", "u"):gsub("Û", "u"):gsub("Ü", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
    s = string.lower(s)
    if string.find(s, "common", 1, true) then return "Common" end
    if string.find(s, "rare", 1, true) then return "Rare" end
    if string.find(s, "epic", 1, true) then return "Epic" end
    if string.find(s, "legendary", 1, true) then return "Legendary" end
    if string.find(s, "mythic", 1, true) then return "Mythic" end
    return "Common"
end

local function getRareteOrder(rarete)
    local key = normalizeRareteName(rarete)
    local R = RecipeManager and RecipeManager.Raretes or nil
    if R and R[key] and R[key].ordre then return R[key].ordre end
    local fallback = {Common = 1, ["Rare"] = 2, ["Epic"] = 3, ["Legendary"] = 4, ["Mythic"] = 5}
    return fallback[key] or 1
end

-- Validation serveur: calcule le nombre total/done par rareté pour le joueur
local function computePokedexChallengesServer(plr)
    local result = {
        Common = { total = 0, done = 0 },
        Rare = { total = 0, done = 0 },
        ["Epic"] = { total = 0, done = 0 },
        ["Legendary"] = { total = 0, done = 0 },
        Mythic = { total = 0, done = 0 },
    }
    if not RecipeManager or not RecipeManager.Recettes then return result end
    local pd = plr:FindFirstChild("PlayerData")
    local sizesRoot = pd and pd:FindFirstChild("PokedexSizes")
    local function normalizeText(s)
        s = tostring(s or "")
        s = s:lower():gsub("[^%w]", "")
        return s
    end
    for recipeName, def in pairs(RecipeManager.Recettes) do
        local r = normalizeRareteName(def.rarete)
        if result[r] then
            result[r].total = result[r].total + 1
            local rf = sizesRoot and sizesRoot:FindFirstChild(recipeName)
            if not rf and sizesRoot then
                local target = normalizeText(recipeName)
                for _, ch in ipairs(sizesRoot:GetChildren()) do
                    if normalizeText(ch.Name) == target then
                        rf = ch
                        break
                    end
                end
            end
            local discovered = 0
            if rf then
                for _, child in ipairs(rf:GetChildren()) do
                    if child:IsA("BoolValue") and child.Value == true then
                        discovered = discovered + 1
                    end
                end
            end
            if discovered >= 7 then
                result[r].done = result[r].done + 1
            end
        end
    end
    return result
end

-- Réclamation des récompenses (déverrouille les passifs)
local function onClaimPokedexReward(plr, rareteName)
    if type(rareteName) ~= "string" then return end
    local map = {
        ["Common"] = "EssenceCommune",
        ["Rare"] = "EssenceRare",
        ["Epic"] = "EssenceEpique",
        ["Legendary"] = "EssenceLegendaire",
        ["Mythic"] = "EssenceMythique",
    }
    local key = map[normalizeRareteName(rareteName)] or map[rareteName]
    if not key then return end
    local pd = plr:FindFirstChild("PlayerData")
    local su = pd and pd:FindFirstChild("ShopUnlocks")
    if not su then return end
    local flag = su:FindFirstChild(key)
    if flag and flag.Value == true then return end -- déjà débloqué
    local ch = computePokedexChallengesServer(plr)
    local rn = normalizeRareteName(rareteName)
    local data = ch[rn]
    if not data then return end
    local threshold = data.total
    if data.done >= threshold then
        if not flag then
            flag = Instance.new("BoolValue")
            flag.Name = key
            flag.Parent = su
        end
        flag.Value = true
    end
end

local function isIngredientAllowedForLevel(ingredientName, level)
    if not RecipeManager or not RecipeManager.Ingredients then return true end
    local def = RecipeManager.Ingredients[ingredientName]
    if not def then return false end
    local ingOrder = getRareteOrder(def.rarete)
    local allowedOrder = math.clamp(tonumber(level) or 1, 1, MAX_MERCHANT_LEVEL)
    return ingOrder <= allowedOrder
end

local function onUpgradeRequested(plr)
    local pd = plr:FindFirstChild("PlayerData")
    if not pd then return end
    local ml = pd:FindFirstChild("MerchantLevel")
    if not ml then return end
    local current = ml.Value
    if current >= MAX_MERCHANT_LEVEL then return end
    local cost = UPGRADE_COSTS[current]
    if not cost then return end
    if getArgent(plr) < cost then return end
    local ok = retirerArgent(plr, cost)
    if not ok then return end
    ml.Value = math.clamp(current + 1, 1, MAX_MERCHANT_LEVEL)
end

-- Récupération des prix depuis le RecipeManager
local function getPrixIngredient(nom)
	local ingredient = RecipeManager.Ingredients[nom]
	return ingredient and ingredient.prix or 0
end

local function onAchatIngredient(plr, ing, qty)
	qty = tonumber(qty) or 1
	if qty <= 0 then return end

    -- Vérifier le niveau du marchand par rareté (sécurité serveur)
    local pd = plr:FindFirstChild("PlayerData")
    local lvl = pd and pd:FindFirstChild("MerchantLevel") and pd.MerchantLevel.Value or 1
    if not isIngredientAllowedForLevel(ing, lvl) then
        return
    end

	-- Vérifier le stock disponible
	local stockDisponible = StockManager.getIngredientStock(ing)
	if stockDisponible < qty then
		return
	end

	-- Utiliser le système moderne de gestion de l'argent
	local cost = getPrixIngredient(ing) * qty
	if not cost or cost == 0 then return end
	
	-- Vérifier si le joueur a assez d'argent
	if getArgent(plr) < cost then return end
	
	-- Retirer l'argent via le système moderne (sync avec leaderstats)
	local success = retirerArgent(plr, cost)
	if not success then return end
	
	-- FORCER la synchronisation leaderstats après achat
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Argent") then
		ls.Argent.Value = plr.PlayerData.Argent.Value
	end

    local tpl = ReplicatedStorage.IngredientTools:FindFirstChild(ing)
    if not tpl then return end

	local bp  = plr.Backpack
	local tool= nil
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t:GetAttribute("BaseName") == ing then
            tool = t
            break
        end
    end

	if tool then
		local cnt = tool:FindFirstChild("Count")
		if cnt then
			cnt.Value += qty
		end
	else
		local clone = tpl:Clone()
		clone:SetAttribute("BaseName", ing)
		local cnt = clone:FindFirstChild("Count")
		if not cnt then
			cnt = Instance.new("IntValue")
			cnt.Name   = "Count"
			cnt.Parent = clone
		end
		cnt.Value = qty
		clone.Parent = bp
	end

	-- Décrémenter le stock global après un achat réussi
	StockManager.decrementIngredientStock(ing, qty)
end

-------------------------------------------------
-- SYSTÈME DE REVENTE D'INGRÉDIENTS
-------------------------------------------------
local RESELL_PERCENTAGE = 0.5

local function vendreIngredient(plr, ing, qty)
	if not plr or not ing or not qty then return end
	qty = math.floor(tonumber(qty) or 1)
	if qty < 1 then return end
	
	-- Vérifier que l'ingrédient existe
	local ingredientData = RecipeManager.Ingredients[ing]
	if not ingredientData then return end
	
	-- Chercher l'ingrédient dans le backpack
	local bp = plr:FindFirstChildOfClass("Backpack")
	if not bp then return end
	
	local tool = nil
	for _, t in ipairs(bp:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("BaseName") == ing then
			tool = t
			break
		end
	end
	
	if not tool then return end
	
	local cnt = tool:FindFirstChild("Count")
	if not cnt or cnt.Value < qty then return end
	
	-- Calculer le prix de revente (50% du prix d'achat)
	local prixRevente = math.floor(ingredientData.prix * qty * RESELL_PERCENTAGE)
	
	-- Retirer l'ingrédient du backpack
	cnt.Value -= qty
	if cnt.Value <= 0 then
		tool:Destroy()
	end
	
	-- Ajouter l'argent au joueur
	ajouterArgent(plr, prixRevente)
	
	-- Remettre le stock dans la boutique
	local shopStockFolder = ReplicatedStorage:FindFirstChild("ShopStock")
	if shopStockFolder then
		local stockValue = shopStockFolder:FindFirstChild(ing)
		if stockValue then
			local currentStock = stockValue.Value
			local maxStock = ingredientData.quantiteMax or 50
			stockValue.Value = math.min(currentStock + qty, maxStock)
		end
	end
	
	-- FORCER la synchronisation leaderstats après revente
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Argent") then
		ls.Argent.Value = plr.PlayerData.Argent.Value
	end
end

-------------------------------------------------
-- TIMER 1s
-------------------------------------------------
local function tickProd()
	for _,pl in ipairs(Players:GetPlayers()) do
		local pd=pl.PlayerData
		if pd and pd.EnProduction.Value and pd.TempsProductionRestant.Value>0 then
			pd.TempsProductionRestant.Value -= 1
			if pd.TempsProductionRestant.Value<=0 then terminerProduction(pl) end
		end
	end
end

-------------------------------------------------
-- SYSTÈME DE SAUVEGARDE
-------------------------------------------------
local restoringPlayers = {}

-- Fonction pour sauvegarder un joueur manuellement
local function sauvegarderJoueur(plr)
    if not SaveDataManager then return false end
    local success = SaveDataManager.savePlayerData(plr)
    return success
end

-- Fonction pour charger et restaurer un joueur
local function chargerJoueur(plr)
    if not SaveDataManager then 
		signalPlayerDataReady(plr)
		return false
    end
    
    if restoringPlayers[plr.UserId] then return false end
    restoringPlayers[plr.UserId] = true
    
    local playerData = plr:FindFirstChild("PlayerData")
    if not playerData then
        restoringPlayers[plr.UserId] = nil
        return false
    end
    
    local loadedData = SaveDataManager.loadPlayerData(plr)
    if loadedData then
        local success = SaveDataManager.restorePlayerData(plr, loadedData)
        if success then
            task.spawn(function()
                task.wait(3)
                if restoringPlayers[plr.UserId] then
                    SaveDataManager.restoreInventory(plr, loadedData)
                    SaveDataManager.restoreProduction(plr, loadedData)
                    restoringPlayers[plr.UserId] = nil
					task.delay(OFFLINE_READY_EXTRA_DELAY, function()
						if plr and plr.Parent then
							signalPlayerDataReady(plr)
						end
					end)
                end
            end)
            return true
        end
    end
    
	restoringPlayers[plr.UserId] = nil
	signalPlayerDataReady(plr)
	return false
end

local function setupPlayerDataWithSave(plr)
    setupPlayerData(plr)
    task.spawn(function()
        task.wait(1)
        chargerJoueur(plr)
    end)
end

-------------------------------------------------
-- CONNEXIONS
-------------------------------------------------
_G.GameManager = {
	ajouterArgent = ajouterArgent,
	retirerArgent = retirerArgent,
	getArgent = getArgent,
	ajouterBonbonAuSac = ajouterBonbonAuSac,
	retirerBonbonDuSac = retirerBonbonDuSac,
	rafraichirSacVisuel = rafraichirSacVisuel,
	syncArgentLeaderstats = syncArgentLeaderstats,
	sauvegarderJoueur = sauvegarderJoueur,
	chargerJoueur = chargerJoueur
}

Players.PlayerAdded:Connect(setupPlayerDataWithSave)

Players.PlayerRemoving:Connect(function(plr)
    restoringPlayers[plr.UserId] = nil
end)

if evAchat then evAchat.OnServerEvent:Connect(onAchatIngredient) end
if evUpgrade then evUpgrade.OnServerEvent:Connect(onUpgradeRequested) end
if evProd  then evProd .OnServerEvent:Connect(demarrerProduction) end
if claimRewardEvt then claimRewardEvt.OnServerEvent:Connect(onClaimPokedexReward) end
if evVenteIngredient then evVenteIngredient.OnServerEvent:Connect(vendreIngredient) end

-- Commandes chat
Players.PlayerAdded:Connect(function(plr)
	plr.Chatted:Connect(function(message)
		-- Commande pour vider l'inventaire
		if message == "/clearinv" or message == "/clearinventory" then
			local bp = plr:FindFirstChildOfClass("Backpack")
			if bp then
				for _, tool in ipairs(bp:GetChildren()) do
					if tool:IsA("Tool") then
						tool:Destroy()
					end
				end
			end
			
		-- Commande pour reset complet de la sauvegarde
		elseif message == "/resetsave" or message == "/reset" then
			-- 1. Vider l'inventaire
			local bp = plr:FindFirstChildOfClass("Backpack")
			if bp then
				for _, tool in ipairs(bp:GetChildren()) do
					if tool:IsA("Tool") then
						tool:Destroy()
					end
				end
			end
			
			-- 2. Vider l'inventaire équipé
			if plr.Character then
				for _, tool in ipairs(plr.Character:GetChildren()) do
					if tool:IsA("Tool") then
						tool:Destroy()
					end
				end
			end
			
			-- 3. Réinitialiser PlayerData
			local pd = plr:FindFirstChild("PlayerData")
			if pd then
				local argent = pd:FindFirstChild("Argent")
				if argent then argent.Value = 100 end
				
				local iu = pd:FindFirstChild("IncubatorsUnlocked")
				if iu then iu.Value = 1 end
				
				local pu = pd:FindFirstChild("PlatformsUnlocked")
				if pu then pu.Value = 0 end
				
				local ml = pd:FindFirstChild("MerchantLevel")
				if ml then ml.Value = 1 end
				
				for _, folderName in ipairs({"SacBonbons", "RecettesDecouvertes", "IngredientsDecouverts", "PokedexSizes", "ShopUnlocks"}) do
					local folder = pd:FindFirstChild(folderName)
					if folder then
						for _, child in ipairs(folder:GetChildren()) do
							child:Destroy()
						end
					end
				end
				
				ensureShopUnlocksFolder(plr)
			end
			
			-- 4. Synchroniser leaderstats
			syncArgentLeaderstats(plr)
			
			-- 5. Sauvegarder
			if SaveDataManager then
				pcall(function()
					sauvegarderJoueur(plr)
				end)
			end
		end
	end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        tickProd()
    end
end)
