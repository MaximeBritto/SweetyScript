-- CandySellServer.lua
-- Gestionnaire côté serveur pour la vente de bonbons
-- À placer dans ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Chargement du RecipeManager pour obtenir les prix des recettes
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- Fonction pour obtenir le prix de base d'un bonbon depuis le RecipeManager
local function getBasePriceFromRecipeManager(candyName)
	if RecipeManager and RecipeManager.Recettes then
		for recipeName, recipeData in pairs(RecipeManager.Recettes) do
			if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
				return recipeData.valeur or 15
			end
		end
	end
	return 15 -- Fallback si recette non trouvée
end

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
	if not player or not toolName then
		return false, "Paramètres invalides"
	end

	-- Vérifier que le joueur possède le Tool
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false, "Inventaire non trouvé"
	end

	local tool = nil
	for _, t in pairs(backpack:GetChildren()) do
		if t:IsA("Tool") and t.Name == toolName then
			tool = t
			break
		end
	end

	if not tool then
		return false, "Bonbon non trouvé dans l'inventaire"
	end

	-- Vérifier que c'est bien un bonbon
	if not tool:GetAttribute("BaseName") then
		return false, "Objet invalide"
	end

	-- VENTE DIRECTE AVEC _G.GameManager (bypass CandySellManager)
	warn("🚀 [SELL-SERVER] Vente directe:", tool.Name, "pour", player.Name)

	-- 1. Calculer le prix
	local baseName = tool:GetAttribute("BaseName") or tool.Name
	local stackSize = tool:GetAttribute("StackSize") or 1
	local basePrice = getBasePriceFromRecipeManager(baseName)
	local totalPrice = basePrice * stackSize

	warn("💰 [SELL-SERVER] Prix calculé:", totalPrice, "(", basePrice, "x", stackSize, ")")

	-- 2. Ajouter l'argent via GameManager
	if _G.GameManager and _G.GameManager.ajouterArgent then
		warn("🎯 [SELL-SERVER] Appel GameManager.ajouterArgent")
		local success = _G.GameManager.ajouterArgent(player, totalPrice)
		if not success then
			warn("❌ [SELL-SERVER] Échec ajout argent")
			return false, "Impossible d'ajouter l'argent"
		end

		-- 3. Supprimer le tool
		tool:Destroy()
		warn("✅ [SELL-SERVER] Vente réussie:", totalPrice, "$")
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

	-- Calcul de prix depuis RecipeManager
	local baseName = tool:GetAttribute("BaseName") or tool.Name
	local stackSize = tool:GetAttribute("StackSize") or 1
	local basePrice = getBasePriceFromRecipeManager(baseName)
	return basePrice * stackSize -- Prix réel * quantité
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
