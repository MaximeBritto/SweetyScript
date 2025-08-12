-- GameManager_Fixed.lua  – Argent initial 100 $, leaderstats synchro,
--                         sac à bonbons stackable, production, achats, ventes

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-------------------------------------------------
-- MODULES & REMOTES
-------------------------------------------------
-- Fonction de chargement sécurisée pour les modules
local function requireModule(name)
	local module = ReplicatedStorage:WaitForChild(name, 20) -- On attend jusqu'à 20 secondes
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

-- On arrête tout si un module critique est manquant
if not RecipeManager or not StockManager then
	error("ERREUR CRITIQUE: Un ou plusieurs modules essentiels (RecipeManager, StockManager) n'ont pas pu être chargés. Le jeu ne peut pas continuer.")
end

local RECETTES = RecipeManager.Recettes

local function waitForRemoteEvent(name)
	local ev = ReplicatedStorage:WaitForChild(name, 10)
	if not ev then warn("RemoteEvent manquant : "..name) end
	return ev
end

-- On utilise le nouveau nom d'événement pour être sûr d'être le seul à écouter
local evAchat   = waitForRemoteEvent("AchatIngredientEvent_V2")
-- local evVente   = waitForRemoteEvent("VendreUnBonbonEvent") -- SUPPRIMÉ
local evProd    = waitForRemoteEvent("DemarrerProductionEvent")

-------------------------------------------------
-- INIT JOUEUR
-------------------------------------------------
local function setupPlayerData(plr)
	warn("🎆 [DEBUG] ========== setupPlayerData DEBUT ==========")
	warn("🎆 [DEBUG] setupPlayerData appelé pour", plr.Name)
	warn("🎆 [DEBUG] Call stack:", debug.traceback())
	
	-- DEBUG: Vérifier l'argent AVANT notre setup
	local existingPD = plr:FindFirstChild("PlayerData")
	local existingLS = plr:FindFirstChild("leaderstats")
	warn("🔍 AVANT SETUP - PlayerData:", existingPD and "OUI" or "NON")
	if existingPD and existingPD:FindFirstChild("Argent") then
		warn("🔍 AVANT SETUP - PlayerData.Argent:", existingPD.Argent.Value)
	end
	warn("🔍 AVANT SETUP - leaderstats:", existingLS and "OUI" or "NON")
	if existingLS and existingLS:FindFirstChild("Argent") then
		warn("🔍 AVANT SETUP - leaderstats.Argent:", existingLS.Argent.Value)
	end
    -- Vérifier si PlayerData existe déjà (pour éviter d'écraser les données)
	local pd = plr:FindFirstChild("PlayerData")
	if pd then
		local argent = pd:FindFirstChild("Argent")
		print("⚠️ SETUP: PlayerData existe déjà pour", plr.Name, "- Conservation des données | Argent actuel:", argent and argent.Value or "N/A")
        -- Juste s'assurer que leaderstats est synchronisé
        argent = pd:FindFirstChild("Argent")
		if argent then
			local ls = plr:FindFirstChild("leaderstats") or Instance.new("Folder", plr)
			ls.Name = "leaderstats"
			local argentStat = ls:FindFirstChild("Argent") or Instance.new("IntValue", ls)
			argentStat.Name = "Argent"
			argentStat.Value = argent.Value -- Sync avec la valeur actuelle
			-- Sync PlayerData → leaderstats
			argent.Changed:Connect(function(v) 
				argentStat.Value = v 
				print("➡️ SYNC PlayerData → leaderstats:", v)
			end)
			-- GARDE-FOU: Rétablir leaderstats si modifié directement
			argentStat.Changed:Connect(function(v)
				local vraiArgent = argent.Value
				if v ~= vraiArgent then
					warn("🚫 LEADERSTATS MODIFIÉ DIRECTEMENT:", v, "→ rétablissement à", vraiArgent)
					warn("🔍 Source du changement:", debug.traceback())
					-- Rétablir immédiatement la vraie valeur
					argentStat.Value = vraiArgent
				end
			end)
			print("⚙️ SYNC: leaderstats.Argent =", argentStat.Value, "(depuis PlayerData.Argent)")
		end

        -- S'assurer que le compteur de plateformes débloquées existe (par défaut 1 = Platform1 gratuite)
        if not pd:FindFirstChild("PlatformsUnlocked") then
            local pu = Instance.new("IntValue")
            pu.Name = "PlatformsUnlocked"
            pu.Value = 0
            pu.Parent = pd
            print("🛠️ Ajout du champ PlatformsUnlocked = 0 pour", plr.Name)
        end
		return
	end
	
	-- Créer PlayerData si n'existe pas
	print("🎆 SETUP: Création PlayerData pour nouveau joueur", plr.Name)
	pd = Instance.new("Folder", plr)
	pd.Name = "PlayerData"

	local argent = Instance.new("IntValue", pd)
	argent.Name, argent.Value = "Argent", 100

    local ls = Instance.new("Folder", plr)
    ls.Name = "leaderstats"
    local argentStat = Instance.new("IntValue", ls)
    argentStat.Name  = "Argent"
    argentStat.Value = argent.Value
	-- Debug: Traquer tous les changements d'argent
	argent.Changed:Connect(function(v) 
		argentStat.Value = v 
		warn("💰 [DEBUG] PlayerData.Argent changé à:", v, "pour", plr.Name)
		warn("🔍 [DEBUG] Trace:", debug.traceback())
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

    -- Nombre de plateformes débloquées par joueur (1 = Platform1 gratuite)
    local platformsUnlocked = Instance.new("IntValue", pd)
    platformsUnlocked.Name = "PlatformsUnlocked"
    platformsUnlocked.Value = 0

    local rf = Instance.new("Folder", pd)
    rf.Name = "RecettesDecouvertes"
    local base = Instance.new("BoolValue", rf)
    base.Name, base.Value = "Basique", true
end

-------------------------------------------------
-- SAC À BONBONS
-------------------------------------------------
-- Ajoute un bonbon :
-- 1) empile le Tool bonbon dans le Backpack (CandyTools)
-- 2) met à jour le dossier SacBonbons pour la logique existante (secret recipes, etc.)
local CandyTools = requireModule("CandyTools")
local function ajouterBonbonAuSac(plr, typeB)
	-- SYSTÈME MODERNE SEULEMENT : Empiler dans le Backpack en tant que Tool
	-- (Plus de legacy SacBonbons pour éviter la duplication)
	local success = CandyTools.giveCandy(plr, typeB, 1)
	if success then
		print("🍭 BONBON AJOUTÉ:", typeB, "au joueur", plr.Name)
	else
		warn("❌ ÉCHEC ajout bonbon:", typeB, "au joueur", plr.Name)
	end
	return success
end

-- Fonction de synchronisation simple (comme setupPlayerData)
local function syncArgentLeaderstats(plr)
	local pd = plr:FindFirstChild("PlayerData")
	local ls = plr:FindFirstChild("leaderstats")
	if pd and pd.Argent and ls and ls.Argent then
		ls.Argent.Value = pd.Argent.Value
		print("🔄 SYNC SIMPLE: leaderstats.Argent =", ls.Argent.Value, "(depuis PlayerData)")
	end
end

-- Fonctions de gestion de l'argent - MODIFIE LEADERSTATS DIRECTEMENT
local function ajouterArgent(plr, montant)
	warn("🎯 [ajouterArgent] DEBUT pour", plr.Name, "montant:", montant)
	-- Modifier leaderstats EN PREMIER (le vrai argent)
	local ls = plr:FindFirstChild("leaderstats")
	warn("🎯 [ajouterArgent] leaderstats:", ls and "OUI" or "NON")
	if ls and ls:FindFirstChild("Argent") then
		local oldValue = ls.Argent.Value
		warn("🎯 [ajouterArgent] Argent AVANT:", oldValue)
		ls.Argent.Value = ls.Argent.Value + montant
		warn("💵 AJOUT DIRECT LEADERSTATS:", plr.Name, "|", oldValue, "+", montant, "=", ls.Argent.Value)
		
		-- Synchroniser PlayerData pour éviter les conflits
		local pd = plr:FindFirstChild("PlayerData")
		if pd and pd:FindFirstChild("Argent") then
			pd.Argent.Value = ls.Argent.Value
			print("🔄 SYNC PlayerData depuis leaderstats:", pd.Argent.Value)
		end
		return true
	end
	
	-- Fallback: PlayerData si leaderstats n'existe pas
	local pd = plr:FindFirstChild("PlayerData")
	if pd and pd:FindFirstChild("Argent") then
		local oldValue = pd.Argent.Value
		pd.Argent.Value = pd.Argent.Value + montant
		warn("💵 AJOUT FALLBACK PlayerData:", plr.Name, "|", oldValue, "+", montant, "=", pd.Argent.Value)
		return true
	end
	
	warn("❌ AJOUT ARGENT ÉCHOUÉ:", plr.Name, "- Aucun système d'argent trouvé")
	return false
end

local function retirerArgent(plr, montant)
	-- Retirer depuis leaderstats EN PREMIER (le vrai argent)
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Argent") and ls.Argent.Value >= montant then
		local oldValue = ls.Argent.Value
		ls.Argent.Value = ls.Argent.Value - montant
		warn("💸 RETRAIT DIRECT LEADERSTATS:", plr.Name, "|", oldValue, "-", montant, "=", ls.Argent.Value)
		
		-- Synchroniser PlayerData pour éviter les conflits
		local pd = plr:FindFirstChild("PlayerData")
		if pd and pd:FindFirstChild("Argent") then
			pd.Argent.Value = ls.Argent.Value
			print("🔄 SYNC PlayerData depuis leaderstats:", pd.Argent.Value)
		end
		return true
	end
	
	-- Fallback: PlayerData si leaderstats n'existe pas
	local pd = plr:FindFirstChild("PlayerData")
	if pd and pd:FindFirstChild("Argent") and pd.Argent.Value >= montant then
		local oldValue = pd.Argent.Value
		pd.Argent.Value = pd.Argent.Value - montant
		warn("💸 RETRAIT FALLBACK PlayerData:", plr.Name, "|", oldValue, "-", montant, "=", pd.Argent.Value)
		return true
	end
	
	warn("❌ RETRAIT ARGENT ÉCHOUÉ:", plr.Name, "| Argent leaderstats:", ls and ls.Argent and ls.Argent.Value or "N/A", "| PlayerData:", pd and pd.Argent and pd.Argent.Value or "N/A", "| Requis:", montant)
	return false
end

local function getArgent(plr)
	-- Vérifier d'abord leaderstats (l'affichage réel)
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Argent") then
		warn("💰 getArgent: leaderstats.Argent =", ls.Argent.Value)
		return ls.Argent.Value
	end
	
	-- Fallback sur PlayerData
	local pd = plr:FindFirstChild("PlayerData")
	if pd and pd:FindFirstChild("Argent") then
		warn("💰 getArgent: PlayerData.Argent =", pd.Argent.Value)
		return pd.Argent.Value
	end
	
	warn("❌ getArgent: Aucun argent trouvé pour", plr.Name)
	return 0
end

-- Fonction pour forcer la mise à jour du sac visuel
local function rafraichirSacVisuel(plr)
	print("🔄 SERVEUR: Demande de rafraîchissement du sac pour", plr.Name)
	-- Déclencher un événement pour que le client mette à jour le sac
	local backpackRefreshEvent = ReplicatedStorage:FindFirstChild("BackpackRefreshEvent")
	if not backpackRefreshEvent then
		print("🛠️ CRÉATION BackpackRefreshEvent")
		backpackRefreshEvent = Instance.new("RemoteEvent")
		backpackRefreshEvent.Name = "BackpackRefreshEvent"
		backpackRefreshEvent.Parent = ReplicatedStorage
	else
		print("✅ BackpackRefreshEvent trouvé")
	end
	backpackRefreshEvent:FireClient(plr)
	print("📶 Événement envoyé au client", plr.Name)
end

-- Fonction pour retirer des bonbons du sac (SYSTÈME MODERNE)
local function retirerBonbonDuSac(plr, typeB, q)
	-- Utiliser CandyTools.removeCandy pour le système moderne
	local success = CandyTools.removeCandy(plr, typeB, q)
	if success then
		print("➤ BONBON RETIRÉ:", typeB, "x" .. q, "du joueur", plr.Name)
	else
		warn("❌ ÉCHEC retrait bonbon:", typeB, "x" .. q, "du joueur", plr.Name)
	end
	return success
end

-- NOTE: _G.GameManager est exposé à la fin du script avec toutes les fonctions

-------------------------------------------------
-- RECETTES SECRÈTES (identique à avant)
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
-- ACHATS STACKABLES (ligne corrigée)
-------------------------------------------------
-- Récupération des prix depuis le RecipeManager
local function getPrixIngredient(nom)
	local ingredient = RecipeManager.Ingredients[nom]
	return ingredient and ingredient.prix or 0
end

local function onAchatIngredient(plr, ing, qty)
	qty = tonumber(qty) or 1
	if qty <= 0 then return end

	-- Vérifier le stock disponible
	local stockDisponible = StockManager.getIngredientStock(ing)
	if stockDisponible < qty then
		warn(plr.Name .. " a tenté d'acheter " .. qty .. " " .. ing .. " mais seulement " .. stockDisponible .. " en stock")
		return
	end

	-- Utiliser le système moderne de gestion de l'argent
	local cost = getPrixIngredient(ing) * qty
	if not cost or cost == 0 then return end
	
	-- Vérifier si le joueur a assez d'argent
	if getArgent(plr) < cost then 
		warn("💰 ACHAT REFUSÉ: Joueur", plr.Name, "n'a que", getArgent(plr), "$ pour acheter", cost, "$")
		return 
	end
	
	-- Retirer l'argent via le système moderne (sync avec leaderstats)
	local success = retirerArgent(plr, cost)
	if not success then
		warn("❌ ÉCHEC retrait argent:", cost, "$ pour", plr.Name)
		return
	end
	print("💸 ACHAT RÉUSSI:", plr.Name, "a payé", cost, "$ pour", qty, "x", ing)
	
	-- FORCER la synchronisation leaderstats après achat
	local ls = plr:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Argent") then
		ls.Argent.Value = plr.PlayerData.Argent.Value
		print("🔄 SYNC FORCÉ: leaderstats.Argent =", ls.Argent.Value)
	end

    local tpl = ReplicatedStorage.IngredientTools:FindFirstChild(ing)
    if not tpl then
        warn("Template " .. ing .. " manquant")
        return
    end

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
-- ANCIEN SYSTÈME DE VENTE SUPPRIMÉ
-- Utilisez maintenant le nouveau système CandySellManager
-------------------------------------------------

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
-- CONNEXIONS
------------------------------------------------- Exposer les fonctions GameManager pour CandySellManager
_G.GameManager = {
	ajouterArgent = ajouterArgent,
	retirerArgent = retirerArgent,
	getArgent = getArgent,
	ajouterBonbonAuSac = ajouterBonbonAuSac,
	retirerBonbonDuSac = retirerBonbonDuSac,
	rafraichirSacVisuel = rafraichirSacVisuel,
	syncArgentLeaderstats = syncArgentLeaderstats
}
warn("⚙️ [EXPORT] GameManager exposé dans _G.GameManager")
warn("⚙️ [EXPORT] _G.GameManager:", _G.GameManager and "OUI" or "NON")
warn("⚙️ [EXPORT] ajouterArgent:", _G.GameManager.ajouterArgent and "OUI" or "NON")

-- NOTE: Vente maintenant gérée directement dans CandySellServer.lua

-- Test différé (non-bloquant)
task.spawn(function()
	task.wait(1)
	warn("⚙️ [TEST 1s] _G.GameManager:", _G.GameManager and "OUI" or "NON")
end)

-- Connexions d'événements
Players.PlayerAdded:Connect(setupPlayerData)
if evAchat then evAchat.OnServerEvent:Connect(onAchatIngredient) end
-- if evVente then evVente.OnServerEvent:Connect(onVente) end -- ANCIEN SYSTÈME SUPPRIMÉ
if evProd  then evProd .OnServerEvent:Connect(demarrerProduction) end

task.spawn(function()
    while true do
        task.wait(1)
        tickProd()
    end
end)


