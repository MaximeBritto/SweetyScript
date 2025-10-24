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
				local totalBatchPrice = recipeData.valeur or 15
				local candiesPerBatch = recipeData.candiesPerBatch or 1
				local unitPrice = math.floor(totalBatchPrice / candiesPerBatch)
				return math.max(1, unitPrice)
			end
		end
	end
	return 15
end

-- RemoteEvents pour la communication client-serveur
local sellRemotes = ReplicatedStorage:FindFirstChild("CandySellRemotes")
if not sellRemotes then
	sellRemotes = Instance.new("Folder")
	sellRemotes.Name = "CandySellRemotes"
	sellRemotes.Parent = ReplicatedStorage
end

local sellCandyRemote = sellRemotes:FindFirstChild("SellCandy")
if not sellCandyRemote then
	sellCandyRemote = Instance.new("RemoteFunction")
	sellCandyRemote.Name = "SellCandy"
	sellCandyRemote.Parent = sellRemotes
end

local getCandyPriceRemote = sellRemotes:FindFirstChild("GetCandyPrice")
if not getCandyPriceRemote then
	getCandyPriceRemote = Instance.new("RemoteFunction")
	getCandyPriceRemote.Name = "GetCandyPrice"
	getCandyPriceRemote.Parent = sellRemotes
end

-- Fonction pour vendre un bonbon (sécurisée côté serveur)
sellCandyRemote.OnServerInvoke = function(player, toolDataOrName)
	if not player or not toolDataOrName then
		return false, "Paramètres invalides"
	end

	-- Supporter ancien format (string) et nouveau format (table)
	local toolName, toolSize, toolRarity, toolStack
	if type(toolDataOrName) == "table" then
		toolName = toolDataOrName.name
		toolSize = toolDataOrName.size
		toolRarity = toolDataOrName.rarity
		toolStack = toolDataOrName.stackSize
	else
		toolName = toolDataOrName
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
				break
			end
		end
	end

	-- Si pas trouvé dans le backpack, chercher dans le character (main)
	if not tool and character then
		for _, t in pairs(character:GetChildren()) do
			if matchesTool(t) then
				tool = t
				break
			end
		end
	end

	if not tool then
		return false, "Bonbon non trouvé dans l'inventaire ou en main"
	end

	-- Vérifier que c'est bien un bonbon
	if not tool:GetAttribute("BaseName") then
		return false, "Objet invalide - pas de BaseName"
	end

	-- Vérification de sécurité : doit être marqué comme bonbon
	if not tool:GetAttribute("IsCandy") then
		return false, "Seuls les bonbons peuvent être vendus"
	end

	-- VENTE DIRECTE AVEC _G.GameManager
	local baseName = tool:GetAttribute("BaseName") or tool.Name
	local stackSize = tool:GetAttribute("StackSize") or 1

	-- Lire les vraies données de taille et rareté
	local candySize = tool:GetAttribute("CandySize") or 1.0
	local candyRarity = tool:GetAttribute("CandyRarity") or "Normal"

	-- Obtenir le prix de base depuis le RecipeManager
	local basePrice = getBasePriceFromRecipeManager(baseName)
	local sizeMultiplier = candySize ^ 2.5

	-- Bonus de rareté
	local rarityBonus = 1
	if candyRarity == "Grand" then rarityBonus = 1.1
	elseif candyRarity == "Géant" then rarityBonus = 1.2
	elseif candyRarity == "Colossal" then rarityBonus = 1.5
	elseif candyRarity == "LÉGENDAIRE" then rarityBonus = 2.0
	end

	local unitPrice = math.floor(basePrice * sizeMultiplier * rarityBonus)
	unitPrice = math.max(unitPrice, 1) -- Garantir minimum 1$ par bonbon
	local totalPrice = unitPrice * stackSize

	-- Ajouter l'argent via GameManager
	if _G.GameManager and _G.GameManager.ajouterArgent then
		local success = _G.GameManager.ajouterArgent(player, totalPrice)
		if not success then
			return false, "Impossible d'ajouter l'argent"
		end

		-- Supprimer le tool
		tool:Destroy()

		-- 🎓 TUTORIEL: Signaler la vente au tutoriel
		local tutorialRemote = game:GetService("ReplicatedStorage"):FindFirstChild("TutorialRemote")
		if tutorialRemote then
			tutorialRemote:FireClient(player, "candy_sold")
		end

		return true, "Bonbon vendu pour " .. totalPrice .. "$"
	else
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
	return basePrice * stackSize
end
