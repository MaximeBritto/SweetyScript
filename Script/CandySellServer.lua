-- CandySellServer.lua
-- Gestionnaire côté serveur pour la vente de bonbons
-- À placer dans ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Chargement du RecipeManager pour obtenir les prix des recettes
local RecipeManager = require(ReplicatedStorage:WaitForChild("RecipeManager"))

-- Fonction pour obtenir le prix de base d'un bonbon depuis le RecipeManager
-- NOUVEAU : Divise le prix total par candiesPerBatch pour obtenir le prix unitaire
local function getBasePriceFromRecipeManager(candyName)
	warn("🔍 [PRICE-DEBUG] Recherche prix pour:", candyName)
	if RecipeManager and RecipeManager.Recettes then
		for recipeName, recipeData in pairs(RecipeManager.Recettes) do
			if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
				local totalBatchPrice = recipeData.valeur or 15
				local candiesPerBatch = recipeData.candiesPerBatch or 1
				local unitPrice = math.floor(totalBatchPrice / candiesPerBatch)
				warn("🔍 [PRICE-DEBUG] Recette trouvée:", recipeName)
				warn("  - Prix total fournée:", totalBatchPrice)
				warn("  - Bonbons par fournée:", candiesPerBatch)
				warn("  - Prix unitaire calculé:", unitPrice)
				return math.max(1, unitPrice) -- Au moins 1$ par bonbon
			end
		end
	end
	warn("❌ [PRICE-DEBUG] Recette NON trouvée! Utilisation fallback")
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
sellCandyRemote.OnServerInvoke = function(player, toolDataOrName)
	warn("🔥 [SELL-SERVER] DÉBUT vente pour:", player.Name)

	if not player or not toolDataOrName then
		warn("❌ [SELL-SERVER] Paramètres invalides")
		return false, "Paramètres invalides"
	end

	-- Supporter ancien format (string) et nouveau format (table)
	local toolName, toolSize, toolRarity, toolStack
	if type(toolDataOrName) == "table" then
		toolName = toolDataOrName.name
		toolSize = toolDataOrName.size
		toolRarity = toolDataOrName.rarity
		toolStack = toolDataOrName.stackSize
		warn("📦 [SELL-SERVER] Nouveau format - Tool:", toolName, "| Size:", toolSize, "| Rarity:", toolRarity, "| Stack:", toolStack)
	else
		-- Ancien format (juste le nom)
		toolName = toolDataOrName
		warn("📦 [SELL-SERVER] Ancien format - Tool:", toolName)
	end

	-- Vérifier que le joueur possède le Tool (Backpack ET Character)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character

	local tool = nil

	-- Fonction helper pour vérifier si un tool correspond aux critères
	local function matchesTool(t)
		if not t:IsA("Tool") or t.Name ~= toolName then
			return false
		end
		
		-- Si on a les données détaillées, vérifier qu'elles correspondent
		if toolSize and toolRarity and toolStack then
			local tSize = t:GetAttribute("CandySize") or 1.0
			local tRarity = t:GetAttribute("CandyRarity") or "Normal"
			local tStack = t:GetAttribute("StackSize") or 1
			
			-- Vérifier que TOUS les attributs correspondent
			if math.abs(tSize - toolSize) > 0.01 or tRarity ~= toolRarity or tStack ~= toolStack then
				return false
			end
		end
		
		return true
	end

	-- Chercher dans le backpack avec critères précis
	if backpack then
		for _, t in pairs(backpack:GetChildren()) do
			if matchesTool(t) then
				tool = t
				warn("🎒 [SELL-SERVER] Bonbon EXACT trouvé dans BACKPACK:", toolName)
				break
			end
		end
	end

	-- Si pas trouvé dans le backpack, chercher dans le character (main)
	if not tool and character then
		for _, t in pairs(character:GetChildren()) do
			if matchesTool(t) then
				tool = t
				warn("👍 [SELL-SERVER] Bonbon EXACT trouvé dans CHARACTER (main):", toolName)
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

	-- Obtenir le prix de base depuis le RecipeManager
	local basePrice = getBasePriceFromRecipeManager(baseName)
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

	-- Obtenir le prix depuis le RecipeManager
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
print("📋 RecipeManager chargé - Prix dynamiques activés")
