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
local evVente   = waitForRemoteEvent("VendreUnBonbonEvent")
local evProd    = waitForRemoteEvent("DemarrerProductionEvent")

-------------------------------------------------
-- INIT JOUEUR
-------------------------------------------------
local function setupPlayerData(plr)
	local pd = Instance.new("Folder", plr); pd.Name = "PlayerData"

	local argent = Instance.new("IntValue", pd)
	argent.Name, argent.Value = "Argent", 100

	local ls = Instance.new("Folder", plr); ls.Name = "leaderstats"
	local argentStat = Instance.new("IntValue", ls)
	argentStat.Name  = "Argent"; argentStat.Value = argent.Value
	argent.Changed:Connect(function(v) argentStat.Value = v end)

	local sac = Instance.new("Folder", pd); sac.Name = "SacBonbons"
	local maxSlots = Instance.new("IntValue", pd)
	maxSlots.Name, maxSlots.Value = "MaxSlotsSac", 20

	for _,ing in ipairs({"Sucre","Sirop","AromeFruit"}) do
		local iv = Instance.new("IntValue", pd); iv.Name = ing
	end
	local maxIng = Instance.new("IntValue", pd)
	maxIng.Name, maxIng.Value = "MaxIngredients", 30

	Instance.new("BoolValue",   pd).Name = "EnProduction"
	Instance.new("NumberValue", pd).Name = "TempsProductionRestant"
	Instance.new("StringValue", pd).Name = "RecetteEnCours"

	local rf = Instance.new("Folder", pd); rf.Name = "RecettesDecouvertes"
	local base = Instance.new("BoolValue", rf); base.Name, base.Value="Basique",true
end

-------------------------------------------------
-- SAC À BONBONS
-------------------------------------------------
local function ajouterBonbonAuSac(plr, typeB)
	local sac = plr.PlayerData.SacBonbons
	local slot = sac:FindFirstChild(typeB)
	if slot then slot.Value += 1
	else
		local cnt = #sac:GetChildren()
		if cnt >= plr.PlayerData.MaxSlotsSac.Value then return false end
		local iv = Instance.new("IntValue", sac); iv.Name, iv.Value = typeB, 1
	end
	return true
end

-- Exposer les fonctions globalement pour les autres scripts
_G.GameManager = {
	ajouterBonbonAuSac = ajouterBonbonAuSac
}

local function retirerBonbonDuSac(plr, typeB, q)
	local iv = plr.PlayerData.SacBonbons:FindFirstChild(typeB)
	if not iv or iv.Value < q then return false end
	iv.Value -= q; if iv.Value<=0 then iv:Destroy() end
	return true
end

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
	pd.EnProduction.Value=false; pd.RecetteEnCours.Value=""
end

local function demarrerProduction(plr, recName)
	local pd = plr.PlayerData; if pd.EnProduction.Value then return end
	local def = RECETTES[recName]; if not def then return end
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

	local pd=plr.PlayerData
	local cost=getPrixIngredient(ing) * qty
	if not cost or cost == 0 or pd.Argent.Value<cost then return end
	pd.Argent.Value -= cost

	local tpl = ReplicatedStorage.IngredientTools:FindFirstChild(ing)
	if not tpl then warn("Template "..ing.." manquant") return end

	local bp  = plr.Backpack
	local tool= nil
	for _,t in ipairs(bp:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("BaseName")==ing then tool=t break end
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
-- VENTE
-------------------------------------------------
local function onVente(plr, typeB, q)
	local def = RECETTES[typeB]; if not def then return end
	if retirerBonbonDuSac(plr,typeB,q) then
		plr.PlayerData.Argent.Value += def.valeur*q
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
-- CONNEXIONS
-------------------------------------------------
Players.PlayerAdded:Connect(setupPlayerData)
if evAchat then evAchat.OnServerEvent:Connect(onAchatIngredient) end
if evVente then evVente.OnServerEvent:Connect(onVente) end
if evProd  then evProd .OnServerEvent:Connect(demarrerProduction) end

task.spawn(function() while true do task.wait(1) tickProd() end end)


