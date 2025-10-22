-- RobuxPurchaseHandler.lua
-- Gère les achats de Developer Products (Robux)
-- À placer dans ServerScriptService

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- MODE DEBUG : Active la simulation d'achats en Studio
local DEBUG_MODE = RunService:IsStudio()

print("💰 [ROBUX] Handler d'achats Robux chargé")
if DEBUG_MODE then
	print("🔧 [ROBUX] MODE DEBUG ACTIVÉ - Les achats seront simulés en Studio")
end

-- IDs des produits (doivent correspondre à ceux dans StockManager)
local PRODUCT_IDS = {
	RESTOCK = 3370397152,
	UNLOCK_INCUBATOR = 3370397155,
	MERCHANT_UPGRADE_1 = 3370397156,
	MERCHANT_UPGRADE_2 = 3370693193,
	MERCHANT_UPGRADE_3 = 3370711752,
	MERCHANT_UPGRADE_4 = 3370711753,
}

-- Table pour tracker les achats en cours de traitement (éviter les doublons)
local processingPurchases = {}

-- Fonction pour traiter un achat
local function grantPurchase(player, productId)
	print("🎁 [ROBUX] Traitement achat pour", player.Name, "Product:", productId)
	
	-- Vérifier que le joueur est toujours connecté
	if not player or not player.Parent then
		warn("⚠️ [ROBUX] Joueur déconnecté, achat annulé")
		return false
	end
	
	-- Restock instantané
	if productId == PRODUCT_IDS.RESTOCK then
		if _G.StockManager and _G.StockManager.forceRestock then
			_G.StockManager.forceRestock(player)
			print("✅ [ROBUX] Restock accordé à", player.Name)
			return true
		end
	end
	
	-- Déblocage incubateur
	if productId == PRODUCT_IDS.UNLOCK_INCUBATOR then
		local pd = player:FindFirstChild("PlayerData")
		local iu = pd and pd:FindFirstChild("IncubatorsUnlocked")
		if iu and iu.Value < 3 then
			iu.Value = iu.Value + 1
			print("✅ [ROBUX] Incubateur", iu.Value, "débloqué pour", player.Name)
			return true
		end
	end
	
	-- Upgrade marchand
	for level = 1, 4 do
		if productId == PRODUCT_IDS["MERCHANT_UPGRADE_" .. level] then
			local pd = player:FindFirstChild("PlayerData")
			local ml = pd and pd:FindFirstChild("MerchantLevel")
			if ml and ml.Value == level then
				ml.Value = level + 1
				print("✅ [ROBUX] Marchand niveau", ml.Value, "pour", player.Name)
				return true
			end
		end
	end
	
	-- Plateformes (IDs dynamiques, chercher dans _G)
	if _G.PLATFORM_PRODUCT_IDS then
		for platformLevel, pid in pairs(_G.PLATFORM_PRODUCT_IDS) do
			if productId == pid then
				if _G.OnPlatformPurchased then
					_G.OnPlatformPurchased(player, platformLevel)
					print("✅ [ROBUX] Plateforme", platformLevel, "débloquée pour", player.Name)
					return true
				end
			end
		end
	end
	
	-- Ingrédients (chercher dans pending)
	if _G.pendingIngredientByUserId and _G.pendingIngredientByUserId[player.UserId] then
		local pending = _G.pendingIngredientByUserId[player.UserId]
		if pending.productId == productId then
			-- Donner l'ingrédient
			local ingredientName = pending.name
			local quantity = pending.qty or 1
			
			-- Utiliser le système d'achat existant
			local achatEvent = ReplicatedStorage:FindFirstChild("AchatIngredientEvent_V2")
			if achatEvent then
				-- Simuler un achat gratuit (déjà payé en Robux)
				local pd = player:FindFirstChild("PlayerData")
				if pd then
					local backpack = player:FindFirstChildOfClass("Backpack")
					if backpack then
						-- Donner directement l'ingrédient
						local ingredientTools = ReplicatedStorage:FindFirstChild("IngredientTools")
						if ingredientTools then
							local template = ingredientTools:FindFirstChild(ingredientName)
							if template then
								local tool = template:Clone()
								local count = tool:FindFirstChild("Count")
								if count then
									count.Value = quantity
								else
									local newCount = Instance.new("IntValue")
									newCount.Name = "Count"
									newCount.Value = quantity
									newCount.Parent = tool
								end
								tool.Parent = backpack
								print("✅ [ROBUX] Ingrédient", ingredientName, "x" .. quantity, "donné à", player.Name)
								_G.pendingIngredientByUserId[player.UserId] = nil
								return true
							end
						end
					end
				end
			end
		end
	end
	
	warn("⚠️ [ROBUX] Produit inconnu ou non traité:", productId)
	return false
end

-- Callback principal pour les achats
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId
	
	print("💳 [ROBUX] Achat reçu - User:", userId, "Product:", productId, "Purchase:", purchaseId)
	
	-- Vérifier si cet achat est déjà en cours de traitement
	if processingPurchases[purchaseId] then
		print("⏳ [ROBUX] Achat déjà en cours de traitement, attente...")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	-- Marquer comme en cours
	processingPurchases[purchaseId] = true
	
	-- Trouver le joueur
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		warn("⚠️ [ROBUX] Joueur introuvable pour userId:", userId)
		processingPurchases[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- Traiter l'achat
	local success = pcall(function()
		return grantPurchase(player, productId)
	end)
	
	-- Nettoyer
	processingPurchases[purchaseId] = nil
	
	if success then
		print("✅ [ROBUX] Achat traité avec succès pour", player.Name)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn("❌ [ROBUX] Échec du traitement de l'achat pour", player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

print("✅ [ROBUX] ProcessReceipt configuré")
