-- StockManager.lua
-- Gère le stock global des ingrédients de la boutique et le timer de réassort.

local StockManager = {}

-- Developer Product générique pour acheter un ingrédient (pack x1)
-- IMPORTANT: mettez ici l'ID réel du produit créé dans Roblox; laissez 0 pour désactiver le prompt.
local BUY_INGREDIENT_1_PRODUCT_ID = 3370711755
StockManager.__index = StockManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RecipeManager do
	local modInst = ReplicatedStorage:FindFirstChild("RecipeManager")
	local ok, mod = false, nil
	if modInst and modInst:IsA("ModuleScript") then
		ok, mod = pcall(require, modInst)
	end
	if ok and type(mod) == "table" then
		RecipeManager = mod
	else
		warn("[StockManager] RecipeManager introuvable au démarrage – fallback tables vides (environnement Studio/lint?)")
		RecipeManager = { Ingredients = {}, IngredientOrder = {}, Raretes = {} }
	end
end

-- Developer Product ID pour le restock (configurez-le dans Roblox avec un prix de 30 Robux)
-- IMPORTANT: Remplacez 0 par l'ID réel du Developer Product
local RESTOCK_PRODUCT_ID = 3370397152
-- Developer Product ID pour finir instantanément la production (à configurer)
local FINISH_CRAFT_PRODUCT_ID = 3370397154
-- Developer Product commun pour débloquer les incubateurs 2 et 3 (même code pour l'instant)
local UNLOCK_INCUBATOR_PRODUCT_ID = 3370397155
-- Developer Products pour upgrade marchand en Robux (par niveau)
local MERCHANT_UPGRADE_PRODUCT_IDS = {
	[1] = 3370397156, -- Niveau 1→2: 50 Robux (configure ce produit à 50R$ dans Studio)
	[2] = 3370693193, -- Niveau 2→3: 100 Robux (crée ce produit à 100R$)
	[3] = 3370711752, -- Niveau 3→4: 200 Robux (crée ce produit à 200R$)
	[4] = 3370711753, -- Niveau 4→5: 400 Robux (crée ce produit à 400R$)
}

-- Developer Products par rareté pour achat d'ingrédients EN STOCK (avec le bouton "R$ BUY")
-- Clés conformes à _normalizeRarete: "Commune", "Rare", "Épique", "Légendaire", "Mythique"
local INGREDIENT_PRODUCT_ID_BY_RARETE = {
	["Commune"] = 3370711755,
	["Rare"] = 3370855431,
	["Épique"] = 3370855432,
	["Légendaire"] = 3370855433,
	["Mythique"] = 3370855440,
}

-- Developer Products pour achat d'ingrédients OUT OF STOCK (panneau qui s'ouvre quand stock = 0)
-- Ces produits ont des prix différents car ils permettent d'acheter même sans stock
local OUT_OF_STOCK_PRODUCT_ID_BY_RARETE = {
	["Commune"] = 3450332679,      -- 25 Robux
	["Rare"] = 3450072428,         -- 100 Robux
	["Épique"] = 3450072658,       -- 200 Robux
	["Légendaire"] = 3450072832,   -- 350 Robux
	["Mythique"] = 3450072975,     -- 600 Robux
}

-- Developer Products par taille pour valider une taille de recette dans le Pokédex
-- IMPORTANT: Renseignez ici les IDs réels des Developer Products (1 par taille)
-- Clés attendues exactement: "Minuscule", "Petit", "Normal", "Grand", "Géant", "Colossal", "LÉGENDAIRE"
local POKEDEX_SIZE_PRODUCT_IDS = {
	["Minuscule"] = 3370882287,
	["Petit"] = 3370882286,
	["Normal"] = 3370882285,
	["Grand"] = 3370882284,
	["Géant"] = 3370882283,
	["Colossal"] = 3370882282,
	["Légendaire"] = 3370882281,
}

-- Developer Products pour l'achat/déblocage de plateformes (8 niveaux)
-- IMPORTANT: Remplacez les 0 par vos IDs réels de Developer Products, avec des prix croissants
local PLATFORM_PRODUCT_IDS = {
	[1] = 3374849211,
	[2] = 3374849210,
	[3] = 3374849208,
	[4] = 3374849207,
	[5] = 3374849205,
	[6] = 3374849204,
	[7] = 3374849203,
	[8] = 3374849202,
}

local RESTOCK_INTERVAL = 300 -- 5 minutes en secondes

-- Coûts Robux pour upgrade marchand (niveau -> prix Robux) - définis côté client
local _MERCHANT_UPGRADE_ROBUX_COSTS = {
	[1] = 50,   -- Niveau 1 → 2 : 50 Robux
	[2] = 100,  -- Niveau 2 → 3 : 100 Robux  
	[3] = 200,  -- Niveau 3 → 4 : 200 Robux
	[4] = 400,  -- Niveau 4 → 5 : 400 Robux
}
local MAX_MERCHANT_LEVEL = 5

-- 🔄 NOUVEAU: Stock par joueur au lieu de global
local playerStocks = {} -- { [userId] = { [ingredientName] = quantity, lastRestock = timestamp } }

-- 🛒 Variables de gestion du timer de restock (pour sauvegarde)
local currentRestockTime = RESTOCK_INTERVAL  -- Temps restant actuel
local lastRestockTimestamp = 0               -- Timestamp du dernier restock
local restockTimerRunning = false            -- Indique si le timer tourne déjà
-- plus de limitation de restock par cycle
-- Mapping temporaire: UserId -> incubatorID ciblé pour "Finir maintenant"
local pendingFinishByUserId = {}
local pendingUnlockByUserId = {}
local finishPromptCooldownByUserId = {}
local restockPromptCooldownByUserId = {}
local upgradePromptCooldownByUserId = {}
-- Mapping pour achat d'ingrédient via Robux: UserId -> { name = "Sucre", qty = 1 }
local pendingIngredientByUserId = {}
local ingredientPromptCooldownByUserId = {}
-- Pokedex size purchase state
local pendingPokedexSizeByUserId = {}
local pokedexSizePromptCooldownByUserId = {}
-- Plateformes: état d'achat et anti-spam
local pendingPlatformByUserId = {}
local platformPromptCooldownByUserId = {}

local stockValue = Instance.new("Folder")
stockValue.Name = "ShopStock"
stockValue.Parent = ReplicatedStorage

local restockTimeValue = Instance.new("IntValue")
restockTimeValue.Name = "RestockTime"
restockTimeValue.Parent = stockValue

-- 🔄 Initialiser le stock pour un joueur spécifique
local function initializePlayerStock(userId)
	if playerStocks[userId] then return end -- Déjà initialisé
	
	playerStocks[userId] = {
		lastRestock = os.time()
	}
	
	-- Créer un dossier de stock pour ce joueur dans ReplicatedStorage
	local playerStockFolder = Instance.new("Folder")
	playerStockFolder.Name = "PlayerStock_" .. userId
	playerStockFolder.Parent = ReplicatedStorage
	
	for name, ingredient in pairs(RecipeManager.Ingredients) do
		local rarity = ingredient.rarete or "Common"
		local rarityConfig = RecipeManager.RestockRanges[rarity]
		
		if not rarityConfig then
			warn("🛒 [STOCK] Configuration manquante pour la rareté:", rarity, "- utilisation de Common")
			rarityConfig = RecipeManager.RestockRanges["Common"]
		end
		
		local minQty = rarityConfig.minQuantity
		local maxQty = rarityConfig.maxQuantity
		
		-- Générer une quantité aléatoire pour l'initialisation
		local randomValue = math.random()
		local targetQuantity
		
		if randomValue <= rarityConfig.highQuantityChance then
			-- Quantité proche du maximum
			local range = maxQty - minQty
			local variation = math.random(0, math.floor(range * 0.3))
			targetQuantity = maxQty - variation
		else
			-- Quantité proche du minimum
			local range = maxQty - minQty
			local variation = math.random(0, math.floor(range * 0.3))
			targetQuantity = minQty + variation
		end
		
		-- S'assurer que la quantité est dans les limites
		targetQuantity = math.max(minQty, math.min(maxQty, targetQuantity))
		
		-- 🎓 TUTORIEL: Vérifier si le joueur est en tutoriel
		local playerObj = Players:GetPlayerByUserId(userId)
		local isInTutorial = false
		if playerObj then
			local playerData = playerObj:FindFirstChild("PlayerData")
			local tutorialCompleted = playerData and playerData:FindFirstChild("TutorialCompleted")
			isInTutorial = not (tutorialCompleted and tutorialCompleted.Value)
		end
		
		-- Garantir minimum 3 pour les ingrédients essentiels (Sucre et Gelatine)
		-- SAUF pendant le tutoriel où on met seulement 1
		if name == "Sucre" or name == "Gelatine" then
			if isInTutorial then
				targetQuantity = 1 -- Pendant le tutoriel: seulement 1
			else
				targetQuantity = math.max(3, targetQuantity) -- Après le tutoriel: minimum 3
			end
		end
		
		playerStocks[userId][name] = targetQuantity
		
		-- Créer un IntValue pour cet ingrédient
		local stockValue = Instance.new("IntValue")
		stockValue.Name = name
		stockValue.Value = targetQuantity
		stockValue.Parent = playerStockFolder
	end
	
	print("🛒 [STOCK] Stock initialisé pour le joueur:", userId)
end

-- 🔄 Obtenir le stock d'un joueur (avec fallback pour compatibilité)
function StockManager.getIngredientStock(ingredientName, player)
	-- Si player fourni, utiliser son stock personnel
	if player then
		local userId = type(player) == "number" and player or player.UserId
		if not playerStocks[userId] then
			initializePlayerStock(userId)
		end
		return playerStocks[userId][ingredientName] or 0
	end
	
	-- Fallback: retourner 0 si pas de joueur spécifié
	return 0
end

-- 🔄 Décrémenter le stock d'un joueur
function StockManager.decrementIngredientStock(ingredientName, quantity, player)
	if not player then return end
	
	local userId = type(player) == "number" and player or player.UserId
	if not playerStocks[userId] then
		initializePlayerStock(userId)
	end
	
	local currentStock = playerStocks[userId][ingredientName] or 0
	local newStock = math.max(0, currentStock - (quantity or 1))
	playerStocks[userId][ingredientName] = newStock
	
	-- � Notifier le  client du changement de stock
	local playerObj = type(player) == "number" and Players:GetPlayerByUserId(player) or player
	if playerObj and playerObj.Parent then
		local updateEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerStock")
		if updateEvent then
			updateEvent:FireClient(playerObj, ingredientName, newStock)
		end
	end
end

-- 🔄 Restock pour un joueur spécifique
local function restockPlayerShop(userId)
	if not playerStocks[userId] then
		initializePlayerStock(userId)
		return
	end
	
	print("🛒 [STOCK] Réassort de la boutique pour le joueur:", userId)
	
	for name, ingredient in pairs(RecipeManager.Ingredients) do
		local rarity = ingredient.rarete or "Common"
		local rarityConfig = RecipeManager.RestockRanges[rarity]
		
		if not rarityConfig then
			warn("🛒 [STOCK] Configuration manquante pour la rareté:", rarity, "- utilisation de Common")
			rarityConfig = RecipeManager.RestockRanges["Common"]
		end
		
		local minQty = rarityConfig.minQuantity
		local maxQty = rarityConfig.maxQuantity
		
		-- Déterminer si on va vers le haut ou le bas
		local randomValue = math.random()
		local targetQuantity
		
		if randomValue <= rarityConfig.highQuantityChance then
			-- Quantité proche du maximum
			local range = maxQty - minQty
			local variation = math.random(0, math.floor(range * 0.3))
			targetQuantity = maxQty - variation
		else
			-- Quantité proche du minimum
			local range = maxQty - minQty
			local variation = math.random(0, math.floor(range * 0.3))
			targetQuantity = minQty + variation
		end
		
		-- S'assurer que la quantité est dans les limites
		targetQuantity = math.max(minQty, math.min(maxQty, targetQuantity))
		
		-- 🎓 TUTORIEL: Vérifier si le joueur est en tutoriel
		local playerObj = Players:GetPlayerByUserId(userId)
		local isInTutorial = false
		if playerObj then
			local playerData = playerObj:FindFirstChild("PlayerData")
			local tutorialCompleted = playerData and playerData:FindFirstChild("TutorialCompleted")
			isInTutorial = not (tutorialCompleted and tutorialCompleted.Value)
		end
		
		-- Garantir minimum 3 pour les ingrédients essentiels (Sucre et Gelatine)
		-- SAUF pendant le tutoriel où on met seulement 1
		if name == "Sucre" or name == "Gelatine" then
			if isInTutorial then
				targetQuantity = 1 -- Pendant le tutoriel: seulement 1
			else
				targetQuantity = math.max(3, targetQuantity) -- Après le tutoriel: minimum 3
			end
		end
		
		playerStocks[userId][name] = targetQuantity
	end
	
	playerStocks[userId].lastRestock = os.time()
	print("🛒 [STOCK] Restock terminé pour le joueur:", userId)
	
	-- 🔄 Notifier le client de tous les changements de stock
	local playerObj = Players:GetPlayerByUserId(userId)
	if playerObj and playerObj.Parent then
		local updateEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerStock")
		if updateEvent then
			for name, qty in pairs(playerStocks[userId]) do
				if name ~= "lastRestock" then
					updateEvent:FireClient(playerObj, name, qty)
				end
			end
		end
	end
end

-- 🔄 Restock global (tous les joueurs)
function StockManager.restock()
	print("🛒 [STOCK] Réassort global de toutes les boutiques !")
	
	-- Restock pour tous les joueurs connectés
	for _, player in ipairs(Players:GetPlayers()) do
		restockPlayerShop(player.UserId)
		
		-- 💰 SAFETY NET: Garantir minimum 30$ pour chaque joueur
		local playerData = player:FindFirstChild("PlayerData")
		if playerData then
			local argentValue = playerData:FindFirstChild("Argent")
			if argentValue and argentValue.Value < 30 then
				local oldMoney = argentValue.Value
				argentValue.Value = 30
				print("💰 [SAFETY] Joueur", player.Name, "avait", oldMoney, "$ → rechargé à 30$")
			end
		end
	end
	
	-- Mettre à jour le timestamp du dernier restock
	lastRestockTimestamp = os.time()
	currentRestockTime = RESTOCK_INTERVAL
	print("🛒 [STOCK] Prochain restock dans", RESTOCK_INTERVAL, "secondes")
end

-- 🔄 Exposer la fonction de restock pour un joueur spécifique (utilisé par le tutoriel)
function StockManager.restockPlayerShop(userId)
	restockPlayerShop(userId)
end

-- 🛒 Référence à la coroutine du timer pour pouvoir l'arrêter
local restockTimerThread = nil

-- 🛒 Fonction pour démarrer la boucle de restock avec un temps personnalisé
local function startRestockTimer(startTime, forceRestart)
	if restockTimerRunning and not forceRestart then
		warn("🛒 [STOCK] Timer de restock déjà en cours, ignoré (utilisez forceRestart=true pour forcer)")
		return
	end
	
	-- Arrêter l'ancien timer s'il existe
	if restockTimerThread then
		pcall(function()
			task.cancel(restockTimerThread)
		end)
		restockTimerThread = nil
		print("🛒 [STOCK] Ancien timer de restock arrêté")
	end
	
	restockTimerRunning = true
	currentRestockTime = startTime or RESTOCK_INTERVAL
	
	restockTimerThread = task.spawn(function()
		print("🛒 [STOCK] Timer de restock démarré à", currentRestockTime, "secondes")
		while true do
			for i = currentRestockTime, 1, -1 do
				currentRestockTime = i
				restockTimeValue.Value = i
				task.wait(1)
			end
			StockManager.restock()
			currentRestockTime = RESTOCK_INTERVAL
		end
	end)
end

-- Boucle de réassort (uniquement côté serveur)
if game:GetService("RunService"):IsServer() then
	-- 🔄 Initialiser le stock pour chaque joueur à la connexion
	Players.PlayerAdded:Connect(function(player)
		initializePlayerStock(player.UserId)
	end)
	
	-- 🔄 Nettoyer le stock à la déconnexion (optionnel, économise la mémoire)
	Players.PlayerRemoving:Connect(function(player)
		-- On peut garder le stock en mémoire pour un temps ou le supprimer immédiatement
		-- Pour l'instant, on le garde pour permettre la reconnexion rapide
		-- playerStocks[player.UserId] = nil
	end)
	
	-- Initialiser le stock pour les joueurs déjà connectés
	for _, player in ipairs(Players:GetPlayers()) do
		initializePlayerStock(player.UserId)
	end
	
	-- Démarrer le timer (sera écrasé par la restauration si nécessaire)
	startRestockTimer(RESTOCK_INTERVAL)

	-- 🔄 RemoteFunction pour que le client récupère son stock personnel
	local getPlayerStockFunc = Instance.new("RemoteFunction")
	getPlayerStockFunc.Name = "GetPlayerStock"
	getPlayerStockFunc.Parent = ReplicatedStorage
	
	getPlayerStockFunc.OnServerInvoke = function(player)
		local userId = player.UserId
		if not playerStocks[userId] then
			initializePlayerStock(userId)
		end
		-- Retourner une copie du stock (sans lastRestock)
		local stockCopy = {}
		for name, qty in pairs(playerStocks[userId]) do
			if name ~= "lastRestock" then
				stockCopy[name] = qty
			end
		end
		return stockCopy
	end
	
	-- 🔄 RemoteEvent pour notifier le client des changements de stock
	local updateStockEvent = Instance.new("RemoteEvent")
	updateStockEvent.Name = "UpdatePlayerStock"
	updateStockEvent.Parent = ReplicatedStorage

	-- Remote event pour le réassort forcé (ex: via Robux)
	local forceRestockEvent = Instance.new("RemoteEvent")
	forceRestockEvent.Name = "ForceRestockEvent"
	forceRestockEvent.Parent = ReplicatedStorage

	forceRestockEvent.OnServerEvent:Connect(function(player)
		-- Ouvre le prompt d'achat Robux (Developer Product) pour restocker
		if RESTOCK_PRODUCT_ID == 0 then
			warn("[RESTOCK] RESTOCK_PRODUCT_ID non configuré. Veuillez renseigner l'ID du produit.")
			return
		end
		-- Anti-spam léger pour éviter doubles prompts
		local now = os.clock()
		local last = restockPromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		restockPromptCooldownByUserId[player.UserId] = now
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, RESTOCK_PRODUCT_ID)
		end)
		if not ok then
			warn("[RESTOCK] Erreur lors de l'ouverture du prompt d'achat:", err)
			restockPromptCooldownByUserId[player.UserId] = 0
		end
	end)

	-- Remote event: demander la fin immédiate d'une production d'incubateur
	local requestFinishEvt = Instance.new("RemoteEvent")
	requestFinishEvt.Name = "RequestFinishCrafting"
	requestFinishEvt.Parent = ReplicatedStorage

	-- Remote event: notification d'achat réussi pour FINIR (fermeture UI côté client)
	local finishPurchasedEvt = ReplicatedStorage:FindFirstChild("FinishCraftingPurchased")
	if not finishPurchasedEvt then
		finishPurchasedEvt = Instance.new("RemoteEvent")
		finishPurchasedEvt.Name = "FinishCraftingPurchased"
		finishPurchasedEvt.Parent = ReplicatedStorage
	end

	-- Remote event: notification d'achat réussi pour UNLOCK (fermeture UI côté client)
	local unlockPurchasedEvt = ReplicatedStorage:FindFirstChild("UnlockIncubatorPurchased")
	if not unlockPurchasedEvt then
		unlockPurchasedEvt = Instance.new("RemoteEvent")
		unlockPurchasedEvt.Name = "UnlockIncubatorPurchased"
		unlockPurchasedEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande de déblocage d'un incubateur avec monnaie ($)
	local requestUnlockMoneyEvt = ReplicatedStorage:FindFirstChild("RequestUnlockIncubatorMoney")
	if not requestUnlockMoneyEvt then
		requestUnlockMoneyEvt = Instance.new("RemoteEvent")
		requestUnlockMoneyEvt.Name = "RequestUnlockIncubatorMoney"
		requestUnlockMoneyEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande de reset de sauvegarde (wipe)
	local requestResetSaveEvt = ReplicatedStorage:FindFirstChild("RequestResetSave")
	if not requestResetSaveEvt then
		requestResetSaveEvt = Instance.new("RemoteEvent")
		requestResetSaveEvt.Name = "RequestResetSave"
		requestResetSaveEvt.Parent = ReplicatedStorage
	end

	-- Reset total de la sauvegarde du joueur
	requestResetSaveEvt.OnServerEvent:Connect(function(player)
		-- Remettre à zéro le PlayerData en session et déclencher une sauvegarde
		local pd = player:FindFirstChild("PlayerData")
		if pd then
			-- Argent
			local argent = pd:FindFirstChild("Argent"); if argent then argent.Value = 0 end
			-- Déblocages
			local iu = pd:FindFirstChild("IncubatorsUnlocked"); if iu then iu.Value = 1 end
			local pu = pd:FindFirstChild("PlatformsUnlocked"); if pu then pu.Value = 0 end
			local ml = pd:FindFirstChild("MerchantLevel"); if ml then ml.Value = 1 end
			-- Dossiers à vider
			for _, name in ipairs({"SacBonbons","RecettesDecouvertes","IngredientsDecouverts","PokedexSizes","ShopUnlocks"}) do
				local f = pd:FindFirstChild(name)
				if f then
					for _, ch in ipairs(f:GetChildren()) do ch:Destroy() end
				end
			end
		end
		-- Sauvegarde via GameManager
		if _G and _G.GameManager and _G.GameManager.sauvegarderJoueur then
			pcall(function()
				_G.GameManager.sauvegarderJoueur(player)
			end)
		end
	end)

	-- Remote event: demande de déblocage d'un incubateur (Robux)
	local requestUnlockEvt = ReplicatedStorage:FindFirstChild("RequestUnlockIncubator")
	if not requestUnlockEvt then
		requestUnlockEvt = Instance.new("RemoteEvent")
		requestUnlockEvt.Name = "RequestUnlockIncubator"
		requestUnlockEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande d'upgrade marchand (Robux)
	local requestUpgradeRobuxEvt = ReplicatedStorage:FindFirstChild("RequestMerchantUpgradeRobux")
	if not requestUpgradeRobuxEvt then
		requestUpgradeRobuxEvt = Instance.new("RemoteEvent")
		requestUpgradeRobuxEvt.Name = "RequestMerchantUpgradeRobux"
		requestUpgradeRobuxEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande d'achat d'un ingrédient via Robux (pack x1)
	local requestIngredientRobuxEvt = ReplicatedStorage:FindFirstChild("RequestIngredientPurchaseRobux")
	if not requestIngredientRobuxEvt then
		requestIngredientRobuxEvt = Instance.new("RemoteEvent")
		requestIngredientRobuxEvt.Name = "RequestIngredientPurchaseRobux"
		requestIngredientRobuxEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande de validation d'une taille de recette Pokédex (Robux)
	local requestPokedexSizeEvt = ReplicatedStorage:FindFirstChild("RequestPokedexSizePurchaseRobux")
	if not requestPokedexSizeEvt then
		requestPokedexSizeEvt = Instance.new("RemoteEvent")
		requestPokedexSizeEvt.Name = "RequestPokedexSizePurchaseRobux"
		requestPokedexSizeEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande d'achat de plateforme (Robux)
	local requestPlatformRobuxEvt = ReplicatedStorage:FindFirstChild("RequestPlatformPurchaseRobux")
	if not requestPlatformRobuxEvt then
		requestPlatformRobuxEvt = Instance.new("RemoteEvent")
		requestPlatformRobuxEvt.Name = "RequestPlatformPurchaseRobux"
		requestPlatformRobuxEvt.Parent = ReplicatedStorage
	end

	-- Remote event: demande d'achat/déblocage de plateforme avec fallback auto (monnaie -> Robux)
	local requestPlatformAutoEvt = ReplicatedStorage:FindFirstChild("RequestPlatformUnlockAuto")
	if not requestPlatformAutoEvt then
		requestPlatformAutoEvt = Instance.new("RemoteEvent")
		requestPlatformAutoEvt.Name = "RequestPlatformUnlockAuto"
		requestPlatformAutoEvt.Parent = ReplicatedStorage
	end

	-- Remote event: notification d'achat de plateforme réussi (fermeture/refresh UI côté client)
	local platformPurchasedEvt = ReplicatedStorage:FindFirstChild("PlatformPurchaseGranted")
	if not platformPurchasedEvt then
		platformPurchasedEvt = Instance.new("RemoteEvent")
		platformPurchasedEvt.Name = "PlatformPurchaseGranted"
		platformPurchasedEvt.Parent = ReplicatedStorage
	end

	-- Helper: normaliser les accents pour rareté
	local function _normalizeRarete(s)
		if type(s) ~= "string" then return "Commune" end
		s = s:gsub("É","e"):gsub("é","e"):gsub("È","e"):gsub("è","e"):gsub("Ê","e"):gsub("ê","e")
		s = s:gsub("À","a"):gsub("Â","a"):gsub("Ä","a"):gsub("à","a"):gsub("â","a"):gsub("ä","a")
		s = s:gsub("Ï","i"):gsub("î","i"):gsub("ï","i")
		s = s:gsub("Ô","o"):gsub("ô","o")
		s = s:gsub("Ù","u"):gsub("Û","u"):gsub("Ü","u"):gsub("ù","u"):gsub("û","u"):gsub("ü","u")
		s = string.lower(s)
		-- Support français ET anglais
		if string.find(s, "commune", 1, true) or string.find(s, "common", 1, true) then return "Commune" end
		if string.find(s, "rare", 1, true) then return "Rare" end
		if string.find(s, "epique", 1, true) or string.find(s, "epic", 1, true) then return "Épique" end
		if string.find(s, "legendaire", 1, true) or string.find(s, "legendary", 1, true) then return "Légendaire" end
		if string.find(s, "mythique", 1, true) or string.find(s, "mythic", 1, true) then return "Mythique" end
		return "Commune"
	end

	local function _isIngredientAllowedForPlayer(player, ingredientName)
		local def = RecipeManager and RecipeManager.Ingredients and RecipeManager.Ingredients[ingredientName]
		if not def then return false end
		local pd = player:FindFirstChild("PlayerData")
		local ml = pd and pd:FindFirstChild("MerchantLevel") and pd.MerchantLevel.Value or 1
		local order = 1
		if RecipeManager.Raretes and def.rarete then
			local key = _normalizeRarete(def.rarete)
			local info = RecipeManager.Raretes[key]
			if info and info.ordre then order = info.ordre end
		end
		return order <= math.clamp(ml, 1, MAX_MERCHANT_LEVEL)
	end

	local function _isIngredientProductId(pid)
		for _, v in pairs(INGREDIENT_PRODUCT_ID_BY_RARETE) do
			if v == pid then return true end
		end
		-- compat: ancien produit unique
		return pid == BUY_INGREDIENT_1_PRODUCT_ID
	end

	local function _isPokedexSizeProductId(pid)
		for _, v in pairs(POKEDEX_SIZE_PRODUCT_IDS) do
			if v == pid and v ~= 0 then return true end
		end
		return false
	end

	local function _isPlatformProductId(pid)
		for _, v in pairs(PLATFORM_PRODUCT_IDS) do
			if v == pid and v ~= 0 then return true end
		end
		return false
	end

	-- (removed duplicate _normalizeSizeKey definition; see hardened version below)

	local function _normalizeSizeKey(label)
		-- Accept exact keys as-is if they exist in the product table
		local rawLabel = tostring(label or "")
		if POKEDEX_SIZE_PRODUCT_IDS and POKEDEX_SIZE_PRODUCT_IDS[rawLabel] ~= nil then
			return rawLabel
		end
		-- Accept full labels or mobile abbreviations
		local map = {
			["M"] = "Minuscule",
			["P"] = "Petit",
			["N"] = "Normal",
			["G"] = "Grand",
			["G+"] = "Géant",
			["C"] = "Colossal",
			["L"] = "LÉGENDAIRE",
		}
		-- Trim whitespace and tolerate a trailing hyphen/colon (e.g. "L -")
		local trimmed = (rawLabel:match("^%s*(.-)%s*$")) or ""
		-- Remove common invisible spaces (NBSP, ZWSP, ZWNJ, ZWJ, BOM)
		trimmed = trimmed
			:gsub("\194\160", " ") -- NBSP → space
			:gsub("\226\128[\139-\141]", "") -- U+200B..U+200D
			:gsub("\239\187\191", "") -- BOM
		local noTrail = trimmed:gsub("%s*[-–—:]+%s*$", "")
		-- Direct match on full labels (handles proper accents and common variants)
		local fullMap = {
			["Minuscule"] = "Minuscule",
			["Petit"] = "Petit",
			["Normal"] = "Normal",
			["Grand"] = "Grand",
			["Géant"] = "Géant", ["Geant"] = "Géant",
			["Colossal"] = "Colossal",
			["Légendaire"] = "Légendaire"
		}
		if fullMap[noTrail] then return fullMap[noTrail] end
		-- Check abbreviations first (tolerate case)
		if map[noTrail] then return map[noTrail] end
		local upTok = string.upper(noTrail)
		if map[upTok] then return map[upTok] end
		-- Normalize full labels: drop spaces/hyphens/underscores and strip accents (both cases)
		local s = noTrail
		s = s:gsub("%s+", ""):gsub("[%-%_]", "")
		-- Remove same invisible spaces inside token
		s = s
			:gsub("\194\160", "")
			:gsub("\226\128[\139-\141]", "")
			:gsub("\239\187\191", "")
		s = s
			:gsub("[ÀÁÂÃÄÅàáâãäå]", "a")
			:gsub("[Çç]", "c")
			:gsub("[ÈÉÊËèéêë]", "e")
			:gsub("[ÌÍÎÏìíîï]", "i")
			:gsub("[Ññ]", "n")
			:gsub("[ÒÓÔÕÖòóôõö]", "o")
			:gsub("[ÙÚÛÜùúûü]", "u")
			:gsub("[ÝŸýÿ]", "y")
		-- Remove UTF-8 combining diacritics (U+0300..U+036F), e.g. e +  ́
		s = s:gsub("\204[\128-\191]", ""):gsub("\205[\128-\175]", "")
		local lower = s:lower()
		-- Mapping anglais → français (pour compatibilité avec CandySizeManager)
		if lower == "tiny" then return "Minuscule" end
		if lower == "small" then return "Petit" end
		if lower == "normal" then return "Normal" end
		if lower == "large" then return "Grand" end
		if lower == "giant" then return "Géant" end
		if lower == "colossal" then return "Colossal" end
		if lower == "legendary" then return "Légendaire" end
		-- Mapping français (fallback)
		if lower == "minuscule" then return "Minuscule" end
		if lower == "petit" then return "Petit" end
		if lower == "grand" then return "Grand" end
		if lower == "geant" then return "Géant" end
		if lower == "legendaire"  then return "Légendaire" end
		return nil
	end

	requestIngredientRobuxEvt.OnServerEvent:Connect(function(player, ingredientName, qty, isOutOfStock)
		qty = tonumber(qty) or 1
		if qty < 1 then qty = 1 end
		isOutOfStock = isOutOfStock == true -- Convertir en booléen
		
		-- Vérifs basiques
		if type(ingredientName) ~= "string" then return end
		local def = RecipeManager.Ingredients[ingredientName]
		if not def then
			warn("[ING R$] Ingrédient inconnu:", tostring(ingredientName))
			return
		end
		if not _isIngredientAllowedForPlayer(player, ingredientName) then
			warn("[ING R$] Refusé: niveau marchand insuffisant pour", player.Name, ingredientName)
			return
		end
		
		local rarityKey = _normalizeRarete(def.rarete)
		
		-- Choisir la bonne table de produits selon si c'est out of stock ou pas
		local productId
		if isOutOfStock then
			productId = OUT_OF_STOCK_PRODUCT_ID_BY_RARETE[rarityKey]
			print("💎 [ING R$] Demande d'achat OUT OF STOCK pour", player.Name, "-", ingredientName, "- Rareté:", rarityKey)
		else
			productId = INGREDIENT_PRODUCT_ID_BY_RARETE[rarityKey]
			print("💎 [ING R$] Demande d'achat EN STOCK pour", player.Name, "-", ingredientName, "- Rareté:", rarityKey)
		end
		
		if not productId or productId == 0 then
			warn("[ING R$] Aucun Developer Product configuré pour la rareté:", rarityKey, "(", tostring(ingredientName), ")", isOutOfStock and "OUT OF STOCK" or "IN STOCK")
			return
		end
		
		-- 🧪 MODE TEST STUDIO: Simuler l'achat directement sans Robux
		if RunService:IsStudio() then
			print("🧪 [TEST] Mode Studio détecté - Simulation achat Robux pour", player.Name)
			-- Simuler le ProcessReceipt directement
			task.delay(0.5, function()
				local receiptInfo = {
					PlayerId = player.UserId,
					ProductId = productId
				}
				-- Appeler directement la logique de ProcessReceipt
				pendingIngredientByUserId[player.UserId] = { name = ingredientName, qty = 1, productId = productId }
				
				-- Simuler le traitement
				local bp = player:FindFirstChildOfClass("Backpack")
				if bp then
					local ingFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
					local tpl = ingFolder and ingFolder:FindFirstChild(ingredientName)
					
					local tool
					for _, t in ipairs(bp:GetChildren()) do
						if t:IsA("Tool") and t:GetAttribute("BaseName") == ingredientName then
							tool = t
							break
						end
					end
					
					if tool then
						local cnt = tool:FindFirstChild("Count")
						if not cnt then
							cnt = Instance.new("IntValue")
							cnt.Name = "Count"
							cnt.Parent = tool
						end
						cnt.Value = (cnt.Value or 0) + 1
						print("✅ [TEST] Ajouté au stack existant:", ingredientName, "- Nouveau count:", cnt.Value)
					else
						if tpl then
							local clone = tpl:Clone()
							clone:SetAttribute("BaseName", ingredientName)
							local cnt = clone:FindFirstChild("Count")
							if not cnt then
								cnt = Instance.new("IntValue")
								cnt.Name = "Count"
								cnt.Parent = clone
							end
							cnt.Value = 1
							clone.Parent = bp
							print("✅ [TEST] Nouveau tool créé:", ingredientName)
						end
					end
					
					-- Décrémenter le stock
					StockManager.decrementIngredientStock(ingredientName, 1, player)
					print("✅ [TEST] Achat Robux simulé avec succès pour", player.Name, "-", ingredientName)
				end
				
				pendingIngredientByUserId[player.UserId] = nil
			end)
			return
		end
		
		-- Mode production: utiliser le vrai système Robux
		-- Anti-spam 1.5s
		local now = os.clock()
		local last = ingredientPromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		ingredientPromptCooldownByUserId[player.UserId] = now

		pendingIngredientByUserId[player.UserId] = { name = ingredientName, qty = 1, productId = productId }
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[ING R$] Erreur PromptProductPurchase:", err)
			pendingIngredientByUserId[player.UserId] = nil
		end
	end)

	-- Demande d'achat Robux pour une taille Pokédex
	requestPokedexSizeEvt.OnServerEvent:Connect(function(player, recipeName, sizeLabel)
		if type(recipeName) ~= "string" or type(sizeLabel) ~= "string" then return end
		local recs = RecipeManager and RecipeManager.Recettes
		if not recs or not recs[recipeName] then
			warn("[DEX SIZE R$] Recette inconnue:", tostring(recipeName))
			return
		end
		local sizeKey = _normalizeSizeKey(sizeLabel) or _normalizeSizeKey(tostring(sizeLabel))
		if not sizeKey then
			local rx = tostring(sizeLabel)
			local bytes = {}
			for i = 1, #rx do bytes[#bytes+1] = string.byte(rx, i) end
			warn("[DEX SIZE R$] Taille inconnue:", rx, " bytes:", table.concat(bytes, ","))
			return
		end
		local productId = POKEDEX_SIZE_PRODUCT_IDS[sizeKey]
		if not productId or productId == 0 then
			warn("[DEX SIZE R$] Aucun ProductId configuré pour la taille:", sizeKey)
			return
		end
		-- Déjà validé ?
		local pd = player:FindFirstChild("PlayerData")
		local sizesRoot = pd and pd:FindFirstChild("PokedexSizes")
		local rf = sizesRoot and sizesRoot:FindFirstChild(recipeName)
		if rf then
			local flag = rf:FindFirstChild(sizeKey)
			if flag and flag:IsA("BoolValue") and flag.Value == true then
				warn("[DEX SIZE R$] Taille déjà validée pour", player.Name, recipeName, sizeKey)
				return
			end
		end
		-- Anti-spam léger
		local now = os.clock()
		local last = pokedexSizePromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		pokedexSizePromptCooldownByUserId[player.UserId] = now

		-- 🧪 MODE TEST STUDIO: Simuler l'achat directement sans Robux
		if RunService:IsStudio() then
			print("🧪 [TEST] Mode Studio détecté - Simulation achat taille Pokédex pour", player.Name)
			task.delay(0.5, function()
				-- Simuler la validation de la taille
				local pd = player:FindFirstChild("PlayerData")
				if not pd then return end
				local sizesRoot = pd:FindFirstChild("PokedexSizes")
				if not sizesRoot then
					sizesRoot = Instance.new("Folder")
					sizesRoot.Name = "PokedexSizes"
					sizesRoot.Parent = pd
				end
				local rf = sizesRoot:FindFirstChild(recipeName)
				if not rf then
					rf = Instance.new("Folder")
					rf.Name = recipeName
					rf.Parent = sizesRoot
				end
				local flag = rf:FindFirstChild(sizeKey)
				if not flag then
					flag = Instance.new("BoolValue")
					flag.Name = sizeKey
					flag.Parent = rf
				end
				flag.Value = true
				print("✅ [TEST] Taille validée:", recipeName, "-", sizeKey)
			end)
			return
		end

		pendingPokedexSizeByUserId[player.UserId] = { recipe = recipeName, sizeKey = sizeKey, productId = productId }
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[DEX SIZE R$] Erreur PromptProductPurchase:", err)
			pendingPokedexSizeByUserId[player.UserId] = nil
		end
	end)

	-- Demande d'achat Robux pour une plateforme (niveau 1..8)
	requestPlatformRobuxEvt.OnServerEvent:Connect(function(player, platformLevel)
		local lvl = tonumber(platformLevel)
		if not lvl or lvl < 1 or lvl > 8 then
			warn("[PLATFORM R$] Niveau de plateforme invalide:", tostring(platformLevel))
			return
		end
		local productId = PLATFORM_PRODUCT_IDS[lvl]
		if not productId or productId == 0 then
			warn("[PLATFORM R$] Aucun ProductId configuré pour le niveau:", lvl)
			return
		end
		-- Anti-spam 1.5s
		local now = os.clock()
		local last = platformPromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		platformPromptCooldownByUserId[player.UserId] = now

		pendingPlatformByUserId[player.UserId] = { level = lvl, productId = productId }
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[PLATFORM R$] Erreur PromptProductPurchase:", err)
			pendingPlatformByUserId[player.UserId] = nil
		end
	end)

	-- Demande d'achat/déblocage AUTO: tente monnaie in-game, sinon prompt Robux
	requestPlatformAutoEvt.OnServerEvent:Connect(function(player, platformLevel)
		local lvl = tonumber(platformLevel)
		if not lvl or lvl < 1 or lvl > 8 then
			warn("[PLATFORM AUTO] Niveau de plateforme invalide:", tostring(platformLevel))
			return
		end

		-- Tente achat via monnaie in-game si hook dispo
		local purchasedWithCurrency = false
		local hasHook = _G and type(_G.TryPurchasePlatformWithCurrency) == "function"
		if hasHook then
			local okHook, res = pcall(_G.TryPurchasePlatformWithCurrency, player, lvl)
			if not okHook then
				warn("[PLATFORM AUTO] TryPurchasePlatformWithCurrency erreur:", res)
			else
				purchasedWithCurrency = res == true
			end
		end

		if purchasedWithCurrency then
			-- Succès via monnaie: notifier client pour refresh UI
			if platformPurchasedEvt then
				platformPurchasedEvt:FireClient(player, lvl)
			end
			return
		end

		-- Fallback: prompt Robux pour le niveau demandé
		local productId = PLATFORM_PRODUCT_IDS[lvl]
		if not productId or productId == 0 then
			warn("[PLATFORM AUTO] Aucun ProductId configuré pour le niveau:", lvl)
			return
		end
		local now = os.clock()
		local last = platformPromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		platformPromptCooldownByUserId[player.UserId] = now

		pendingPlatformByUserId[player.UserId] = { level = lvl, productId = productId }
		local okPrompt, err2 = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not okPrompt then
			warn("[PLATFORM AUTO] Erreur PromptProductPurchase:", err2)
			pendingPlatformByUserId[player.UserId] = nil
		end
	end)

	requestUnlockEvt.OnServerEvent:Connect(function(player, incubatorIndex)
		if UNLOCK_INCUBATOR_PRODUCT_ID == 0 then
			warn("[UNLOCK INCUBATOR] ProductId non configuré")
			return
		end
		local idx = tonumber(incubatorIndex)
		if idx ~= 2 and idx ~= 3 then
			warn("[UNLOCK INCUBATOR] Index demandé invalide:", incubatorIndex)
			return
		end
		pendingUnlockByUserId[player.UserId] = idx
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, UNLOCK_INCUBATOR_PRODUCT_ID)
		end)
		if not ok then
			warn("[UNLOCK INCUBATOR] Erreur prompt:", err)
			pendingUnlockByUserId[player.UserId] = nil
		end
	end)

	-- Déblocage incubateur via monnaie in-game
	requestUnlockMoneyEvt.OnServerEvent:Connect(function(player, incubatorIndex)
		local idx = tonumber(incubatorIndex)
		if idx ~= 2 and idx ~= 3 then
			warn("[UNLOCK $] Index invalide:", incubatorIndex)
			return
		end
		local pd = player:FindFirstChild("PlayerData")
		local iu = pd and pd:FindFirstChild("IncubatorsUnlocked")
		local argent = pd and pd:FindFirstChild("Argent")
		if not (iu and argent) then
			warn("[UNLOCK $] PlayerData/valeurs manquants pour", player.Name)
			return
		end
		-- Coûts: 2 → 100,000,000,000 ; 3 → 1,000,000,000,000 (comme l'UI)
		local cost = (idx == 2) and 100000000000 or 1000000000000
		if argent.Value < cost then
			warn("[UNLOCK $] Fonds insuffisants pour", player.Name, "nécessite:", cost)
			return
		end
		-- Débiter et débloquer
		argent.Value -= cost
		iu.Value = math.max(iu.Value, idx)
		print("✅ Incubateur", idx, "débloqué via monnaie pour", player.Name)
		-- Notifier le client pour fermer/refresh UI
		if unlockPurchasedEvt then unlockPurchasedEvt:FireClient(player, idx) end
	end)

	requestUpgradeRobuxEvt.OnServerEvent:Connect(function(player)
		local pd = player:FindFirstChild("PlayerData")
		if not pd then
			warn("[MERCHANT UPGRADE] PlayerData manquant pour", player.Name)
			return
		end

		local ml = pd:FindFirstChild("MerchantLevel")
		if not ml then
			warn("[MERCHANT UPGRADE] MerchantLevel manquant pour", player.Name)
			return
		end

		local currentLevel = ml.Value
		if currentLevel >= MAX_MERCHANT_LEVEL then
			warn("[MERCHANT UPGRADE] Joueur", player.Name, "est déjà au niveau max")
			return
		end

		-- Récupérer le Product ID correspondant au niveau actuel
		local productId = MERCHANT_UPGRADE_PRODUCT_IDS[currentLevel]
		if not productId then
			warn("[MERCHANT UPGRADE] Aucun Product ID pour le niveau", currentLevel)
			return
		end

		-- Anti-spam: 1.5s entre deux prompts max
		local now = os.clock()
		local last = upgradePromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		upgradePromptCooldownByUserId[player.UserId] = now

		print("🎯 [MERCHANT UPGRADE] Niveau", currentLevel, "→ Product ID:", productId)
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[MERCHANT UPGRADE] Erreur lors de l'ouverture du prompt:", err)
			upgradePromptCooldownByUserId[player.UserId] = 0
		end
	end)

	requestFinishEvt.OnServerEvent:Connect(function(player, incubatorID)
		if FINISH_CRAFT_PRODUCT_ID == 0 then
			warn("[INCUBATOR FINISH] FINISH_CRAFT_PRODUCT_ID non configuré. Veuillez renseigner l'ID du produit.")
			return
		end
		pendingFinishByUserId[player.UserId] = tostring(incubatorID or "")
		-- Anti-spam: 1.5s entre deux prompts max
		local now = os.clock()
		local last = finishPromptCooldownByUserId[player.UserId] or 0
		if now - last < 1.5 then return end
		finishPromptCooldownByUserId[player.UserId] = now
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, FINISH_CRAFT_PRODUCT_ID)
		end)
		if not ok then
			warn("[INCUBATOR FINISH] Erreur lors de l'ouverture du prompt:", err)
			-- reset cooldown on error
			finishPromptCooldownByUserId[player.UserId] = 0
		end
	end)

	-- Réinitialiser le flag lorsque le prompt est fermé
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
		if productId == RESTOCK_PRODUCT_ID then
			-- rien à faire côté attribut désormais
		elseif productId == FINISH_CRAFT_PRODUCT_ID then
			-- Si non acheté, on libère l'état en attente pour permettre un nouveau clic
			if not wasPurchased then
				pendingFinishByUserId[player.UserId] = nil
			end
			-- La fermeture UI sera déclenchée après ProcessReceipt via FinishCraftingPurchased
		elseif productId == UNLOCK_INCUBATOR_PRODUCT_ID then
			if not wasPurchased then
				pendingUnlockByUserId[player.UserId] = nil
			else
				-- Afficher l'écran de production immédiatement
				local ev = ReplicatedStorage:FindFirstChild("UnlockIncubatorPurchased")
				if ev and ev:IsA("RemoteEvent") then
					-- Envoyer l'index de l'incubateur débloqué
					local targetIdx = pendingUnlockByUserId[player.UserId]
					ev:FireClient(player, targetIdx)
				end
			end
		else
			-- Vérifier si c'est un des Product IDs d'upgrade marchand
			local isMerchantUpgrade = false
			for level, pid in pairs(MERCHANT_UPGRADE_PRODUCT_IDS) do
				if productId == pid then
					isMerchantUpgrade = true
					break
				end
			end
			if isMerchantUpgrade then
				-- Pas besoin de traitement spécial ici, ProcessReceipt s'en charge
			elseif _isIngredientProductId(productId) then
				-- Si non acheté, on libère l'état en attente
				if not wasPurchased then
					pendingIngredientByUserId[player.UserId] = nil
				end
			elseif _isPokedexSizeProductId(productId) then
				if not wasPurchased then
					pendingPokedexSizeByUserId[player.UserId] = nil
				end
			elseif _isPlatformProductId(productId) then
				if not wasPurchased then
					pendingPlatformByUserId[player.UserId] = nil
				end
			end
		end
	end)

	-- Traitement du reçu d'achat: si le produit correspond, on restock et on accorde l'achat
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		if receiptInfo.ProductId == RESTOCK_PRODUCT_ID then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if player then
				print(player.Name .. " a acheté un Restock (Developer Product). Réassort de SA boutique…")
				-- 🔄 Restock uniquement pour CE joueur
				restockPlayerShop(receiptInfo.PlayerId)
			else
				warn("[RESTOCK] Joueur introuvable pour le reçu")
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif receiptInfo.ProductId == FINISH_CRAFT_PRODUCT_ID then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			print("💎 [FINISH] ProcessReceipt called for user:", receiptInfo.PlayerId)
			
			-- Utiliser la nouvelle fonction globale de IncubatorServer_New
			if player and _G.FinishProductionInstantly then
				print("✅ [FINISH] Calling FinishProductionInstantly for", player.Name)
				local ok, err = pcall(function()
					return _G.FinishProductionInstantly(player)
				end)
				if ok then
					print("✅ [FINISH] Production finished successfully")
				else
					warn("❌ [FINISH] Error finishing production:", err)
				end
			else
				if not player then 
					warn("❌ [FINISH] Player not found for receipt") 
				end
				if not _G.FinishProductionInstantly then 
					warn("❌ [FINISH] _G.FinishProductionInstantly not available")
					-- Fallback vers l'ancienne méthode si disponible
					local incID = pendingFinishByUserId and pendingFinishByUserId[receiptInfo.PlayerId]
					if incID and _G.IncubatorFinishNow then
						print("⚠️ [FINISH] Using fallback method")
						pcall(function()
							_G.IncubatorFinishNow(player, incID)
						end)
					end
				end
			end
			
			-- Nettoyer l'ancien système si présent
			if pendingFinishByUserId then
				pendingFinishByUserId[receiptInfo.PlayerId] = nil
			end
			
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif receiptInfo.ProductId == UNLOCK_INCUBATOR_PRODUCT_ID then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			local targetIdx = pendingUnlockByUserId[receiptInfo.PlayerId]
			if player and (targetIdx == 2 or targetIdx == 3) then
				local pd = player:FindFirstChild("PlayerData")
				local iu = pd and pd:FindFirstChild("IncubatorsUnlocked")
				if iu then
					iu.Value = math.max(iu.Value, targetIdx)
					print("✅ Incubateur "..tostring(targetIdx).." débloqué via Robux pour "..player.Name)
					-- Fermer l'UI incubateur côté client (il devra recliquer pour voir le déblocage)
					local ev = ReplicatedStorage:FindFirstChild("UnlockIncubatorPurchased")
					if ev and ev:IsA("RemoteEvent") then
						ev:FireClient(player, targetIdx)
					end
				else
					warn("[UNLOCK INCUBATOR] IncubatorsUnlocked absent pour ", player.Name)
				end
			else
				if not player then warn("[UNLOCK INCUBATOR] Joueur introuvable pour le reçu") end
				if not (targetIdx == 2 or targetIdx == 3) then warn("[UNLOCK INCUBATOR] Index cible invalide: ", targetIdx) end
			end
			pendingUnlockByUserId[receiptInfo.PlayerId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif _isIngredientProductId(receiptInfo.ProductId) then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if not player then
				warn("[ING R$] Joueur introuvable pour le reçu – réessai ultérieur")
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local pending = pendingIngredientByUserId[receiptInfo.PlayerId]
			if not pending or type(pending.name) ~= "string" then
				warn("[ING R$] Aucun achat d'ingrédient en attente pour ce joueur")
				-- On accorde quand même pour éviter les boucles infinies, mais sans stock/objet cela n'a pas de sens.
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if pending.productId and pending.productId ~= receiptInfo.ProductId then
				warn("[ING R$] Mismatch ProductId (attendu=", tostring(pending.productId), ", reçu=", tostring(receiptInfo.ProductId), ") – poursuite du traitement par sécurité")
			end
			local ingredientName = pending.name
			local qty = tonumber(pending.qty) or 1

			-- Sécurité supplémentaire: vérifier l'accès par niveau marchand
			if not _isIngredientAllowedForPlayer(player, ingredientName) then
				warn("[ING R$] Achat reçu mais niveau marchand insuffisant pour", player.Name, ingredientName)
				pendingIngredientByUserId[receiptInfo.PlayerId] = nil
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end

			-- Ajouter l'ingrédient dans le Backpack du joueur (stack Count)
			print("🔍 [ING R$] Traitement achat pour:", player.Name, "- Ingrédient:", ingredientName, "- Qty:", qty)
			local ingFolder = ReplicatedStorage:FindFirstChild("IngredientTools")
			print("🔍 [ING R$] IngredientTools folder:", ingFolder ~= nil)
			local tpl = ingFolder and ingFolder:FindFirstChild(ingredientName)
			print("🔍 [ING R$] Template trouvé:", tpl ~= nil, "- Nom recherché:", ingredientName)
			if not tpl then
				warn("[ING R$] Template introuvable pour l'ingrédient:", ingredientName, "→ création d'un Tool générique")
			end

			local bp = player:FindFirstChildOfClass("Backpack")
			if not bp then
				warn("[ING R$] Backpack introuvable pour", player.Name)
				pendingIngredientByUserId[receiptInfo.PlayerId] = nil
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			local tool
			for _, t in ipairs(bp:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("BaseName") == ingredientName then
					tool = t
					break
				end
			end
			if tool then
				print("✅ [ING R$] Tool existant trouvé, ajout au stack")
				local cnt = tool:FindFirstChild("Count")
				if not cnt then
					cnt = Instance.new("IntValue")
					cnt.Name = "Count"
					cnt.Parent = tool
				end
				cnt.Value = (cnt.Value or 0) + qty
				print("✅ [ING R$] Nouveau count:", cnt.Value)
			else
				print("🆕 [ING R$] Création nouveau tool")
				local clone
				if tpl then
					clone = tpl:Clone()
				else
					clone = Instance.new("Tool")
					clone.Name = ingredientName
					clone.RequiresHandle = false
				end
				clone:SetAttribute("BaseName", ingredientName)
				local cnt = clone:FindFirstChild("Count")
				if not cnt then
					cnt = Instance.new("IntValue")
					cnt.Name = "Count"
					cnt.Parent = clone
				end
				cnt.Value = qty
				clone.Parent = bp
				print("✅ [ING R$] Tool créé et ajouté au backpack")
			end

			-- 🔄 Décrémenter le stock DU JOUEUR (pas global)
			print("📉 [ING R$] Décrémentation stock joueur:", ingredientName, "- Qty:", qty)
			StockManager.decrementIngredientStock(ingredientName, qty, player)

			-- Nettoyage et accord
			print("✅ [ING R$] Achat Robux complété pour", player.Name, "-", ingredientName, "x" .. qty)
			pendingIngredientByUserId[receiptInfo.PlayerId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif _isPokedexSizeProductId(receiptInfo.ProductId) then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if not player then
				warn("[DEX SIZE R$] Joueur introuvable pour le reçu – réessai ultérieur")
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local pending = pendingPokedexSizeByUserId[receiptInfo.PlayerId]
			if not pending or type(pending.recipe) ~= "string" or type(pending.sizeKey) ~= "string" then
				warn("[DEX SIZE R$] Aucun achat de taille en attente pour ce joueur")
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if pending.productId and pending.productId ~= receiptInfo.ProductId then
				warn("[DEX SIZE R$] Mismatch ProductId (attendu=", tostring(pending.productId), ", reçu=", tostring(receiptInfo.ProductId), ") – poursuite du traitement")
			end
			local pd = player:FindFirstChild("PlayerData")
			if not pd then
				warn("[DEX SIZE R$] PlayerData manquant pour ", player.Name)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local sizesRoot = pd:FindFirstChild("PokedexSizes")
			if not sizesRoot then
				sizesRoot = Instance.new("Folder")
				sizesRoot.Name = "PokedexSizes"
				sizesRoot.Parent = pd
			end
			local rf = sizesRoot:FindFirstChild(pending.recipe)
			if not rf then
				rf = Instance.new("Folder")
				rf.Name = pending.recipe
				rf.Parent = sizesRoot
			end
			local flag = rf:FindFirstChild(pending.sizeKey)
			if not flag then
				flag = Instance.new("BoolValue")
				flag.Name = pending.sizeKey
				flag.Parent = rf
			end
			flag.Value = true
			print("✅ [Pokédex] ", player.Name, " a validé ", pending.recipe, " - ", pending.sizeKey, " via Robux")
			pendingPokedexSizeByUserId[receiptInfo.PlayerId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif _isPlatformProductId(receiptInfo.ProductId) then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if not player then
				warn("[PLATFORM R$] Joueur introuvable pour le reçu – réessai ultérieur")
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			local pending = pendingPlatformByUserId[receiptInfo.PlayerId]
			if not pending or not pending.level then
				warn("[PLATFORM R$] Aucun achat de plateforme en attente pour ce joueur")
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if pending.productId and pending.productId ~= receiptInfo.ProductId then
				warn("[PLATFORM R$] Mismatch ProductId (attendu=", tostring(pending.productId), ", reçu=", tostring(receiptInfo.ProductId), ") – poursuite du traitement")
			end
			-- Hook serveur: laisser IslandManager/serveur appliquer le déblocage
			if _G and typeof(_G.OnPlatformPurchased) == "function" then
				local ok, err = pcall(function()
					_G.OnPlatformPurchased(player, pending.level)
				end)
				if not ok then warn("[PLATFORM R$] Erreur OnPlatformPurchased:", err) end
			end
			-- Notifier le client pour rafraîchir l'UI
			local ev = ReplicatedStorage:FindFirstChild("PlatformPurchaseGranted")
			if ev and ev:IsA("RemoteEvent") then
				ev:FireClient(player, pending.level)
			end
			pendingPlatformByUserId[receiptInfo.PlayerId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			-- Vérifier si c'est un des Product IDs d'upgrade marchand
			local isMerchantUpgrade = false
			for level, pid in pairs(MERCHANT_UPGRADE_PRODUCT_IDS) do
				if receiptInfo.ProductId == pid then
					isMerchantUpgrade = true
					break
				end
			end
			if isMerchantUpgrade then
				local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
				if not player then 
					warn("[MERCHANT UPGRADE] Joueur non trouvé pour l'achat")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local pd = player:FindFirstChild("PlayerData")
				if not pd then
					warn("[MERCHANT UPGRADE] PlayerData manquant")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local ml = pd:FindFirstChild("MerchantLevel")
				if not ml then
					warn("[MERCHANT UPGRADE] MerchantLevel manquant")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local currentLevel = ml.Value
				if currentLevel >= MAX_MERCHANT_LEVEL then
					warn("[MERCHANT UPGRADE] Joueur déjà au niveau max")
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				local newLevel = math.clamp(currentLevel + 1, 1, MAX_MERCHANT_LEVEL)
				ml.Value = newLevel
				print(" UPGRADE ROBUX réussi pour", player.Name, ":", currentLevel, "→", newLevel, "(Product:", receiptInfo.ProductId, ")")
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
end

-- Prompt Robux pour débloquer un incubateur (2 ou 3)
function StockManager.promptUnlockIncubator(player, incubatorIndex)
	if not player or (incubatorIndex ~= 2 and incubatorIndex ~= 3) then return end
	pendingUnlockByUserId[player.UserId] = incubatorIndex
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, UNLOCK_INCUBATOR_PRODUCT_ID)
	end)
	if not ok then warn("[UNLOCK INCUBATOR] Erreur prompt:", err) end
end

-- Prompt Robux direct pour une plateforme (niveau 1..8)
function StockManager.promptPlatformRobux(player, platformLevel)
    if not player then return false end
    local lvl = tonumber(platformLevel)
    if not lvl or lvl < 1 or lvl > 8 then
        warn("[PLATFORM R$ API] Niveau invalide:", tostring(platformLevel))
        return false
    end
    local productId = PLATFORM_PRODUCT_IDS[lvl]
    if not productId or productId == 0 then
        warn("[PLATFORM R$ API] ProductId non configuré pour le niveau:", lvl)
        return false
    end
    -- Anti-spam 1.5s
    local now = os.clock()
    local last = platformPromptCooldownByUserId[player.UserId] or 0
    if now - last < 1.5 then return false end
    platformPromptCooldownByUserId[player.UserId] = now

    pendingPlatformByUserId[player.UserId] = { level = lvl, productId = productId }
    local ok, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, productId)
    end)
    if not ok then
        warn("[PLATFORM R$ API] Erreur PromptProductPurchase:", err)
        pendingPlatformByUserId[player.UserId] = nil
        return false
    end
    return true
end

-- Essaie l'achat en monnaie; si insuffisant, prompt Robux automatiquement
function StockManager.promptPlatformAuto(player, platformLevel)
    if not player then return false end
    local lvl = tonumber(platformLevel)
    if not lvl or lvl < 1 or lvl > 8 then
        warn("[PLATFORM AUTO API] Niveau invalide:", tostring(platformLevel))
        return false
    end

    -- 1) Tentative monnaie in-game via hook global si dispo
    local purchasedWithCurrency = false
    local hasHook = _G and type(_G.TryPurchasePlatformWithCurrency) == "function"
    if hasHook then
        local okHook, res = pcall(_G.TryPurchasePlatformWithCurrency, player, lvl)
        if not okHook then
            warn("[PLATFORM AUTO API] TryPurchasePlatformWithCurrency erreur:", res)
        else
            purchasedWithCurrency = res == true
        end
    end

    if purchasedWithCurrency then
        -- Notifier le client pour MAJ UI
        local evt = ReplicatedStorage:FindFirstChild("PlatformPurchaseGranted")
        if evt and evt:IsA("RemoteEvent") then
            evt:FireClient(player, lvl)
        end
        return true
    end

    -- 2) Fallback: prompt Robux
    return StockManager.promptPlatformRobux(player, lvl)
end

-- 🛒 SYSTÈME DE SAUVEGARDE DU RESTOCK TIMER
-- ===========================================

-- Fonction pour récupérer les données actuelles de la boutique (pour sauvegarde)
-- 🔄 Obtenir les données de boutique pour un joueur (pour sauvegarde)
function StockManager.getShopData(player)
	local userId = type(player) == "number" and player or (player and player.UserId)
	if not userId or not playerStocks[userId] then
		return nil
	end
	
	local snapshot = {
		lastRestock = playerStocks[userId].lastRestock or os.time(),
		stockData = {}
	}
	
	-- Copier le stock actuel de chaque ingrédient
	for ingredientName, stock in pairs(playerStocks[userId]) do
		if ingredientName ~= "lastRestock" then
			snapshot.stockData[ingredientName] = stock
		end
	end
	
	return snapshot
end

-- 🔄 Restaurer les données de boutique pour un joueur
function StockManager.restoreShopData(player, shopData, offlineSeconds)
	local userId = type(player) == "number" and player or (player and player.UserId)
	if not userId then
		warn("🛒 [RESTORE] UserId invalide")
		return
	end
	
	if not shopData then 
		warn("🛒 [RESTORE] Aucune donnée de boutique à restaurer pour le joueur:", userId)
		-- Initialiser un nouveau stock
		initializePlayerStock(userId)
		return 
	end
	
	print("🛒 [RESTORE] Restauration boutique pour le joueur:", userId, "| Temps hors ligne:", offlineSeconds, "s")
	
	-- Initialiser le stock du joueur s'il n'existe pas
	if not playerStocks[userId] then
		playerStocks[userId] = {}
	end
	
	-- Restaurer le stock de chaque ingrédient
	if shopData.stockData then
		local count = 0
		for ingredientName, savedStock in pairs(shopData.stockData) do
			playerStocks[userId][ingredientName] = savedStock
			count = count + 1
		end
		print("🛒 [RESTORE] Stock restauré pour", count, "ingrédients")
	end
	
	-- Calculer combien de restocks ont eu lieu pendant l'absence
	local lastRestock = shopData.lastRestock or os.time()
	local timeSinceLastRestock = os.time() - lastRestock
	local restocksOccurred = math.floor(timeSinceLastRestock / RESTOCK_INTERVAL)
	
	-- Si au moins un restock a eu lieu, restock la boutique du joueur
	if restocksOccurred > 0 then
		print("🛒 [RESTORE]", restocksOccurred, "restock(s) ont eu lieu pendant l'absence - Restock de la boutique")
		restockPlayerShop(userId)
	end
	
	-- Mettre à jour le timestamp
	playerStocks[userId].lastRestock = os.time()
	print("🛒 [RESTORE] Boutique restaurée pour le joueur:", userId)
end

-- Exposer le StockManager dans l'espace global pour le système de sauvegarde
if game:GetService("RunService"):IsServer() then
	_G.StockManager = StockManager
	_G.pendingIngredientByUserId = pendingIngredientByUserId
	print("🛒 [STOCK] StockManager exposé dans _G pour la sauvegarde")
end

return StockManager