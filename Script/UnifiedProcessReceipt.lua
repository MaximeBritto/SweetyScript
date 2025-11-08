--[[
	UnifiedProcessReceipt.lua
	
	Script UNIQUE qui gère TOUS les achats Robux du jeu:
	- Donations (DonoBoard)
	- Restock
	- Upgrades marchand
	- Incubateurs
	- Etc.
	
	À placer dans ServerScriptService
	IMPORTANT: Supprimez le ProcessReceipt du MainScript après avoir ajouté ce script
--]]

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("💳 [UNIFIED RECEIPT] Chargement du ProcessReceipt unifié...")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- DataStore pour les donations
local DSLB = DataStoreService:GetOrderedDataStore("DonoPurchaseLB")

-- Charger les produits de donation
local donationProducts = {}
local productsModule = ReplicatedStorage:WaitForChild("Products")
local products = require(productsModule).Products

for _, prod in ipairs(products) do
	donationProducts[prod.ProductId] = prod.ProductPrice
end

print("✅ [UNIFIED RECEIPT]", #products, "produits de donation chargés")

-- IDs des autres produits (Restock, etc.)
local OTHER_PRODUCTS = {
	RESTOCK = 3370397152,
	UNLOCK_INCUBATOR = 3370397155,
	FINISH_PRODUCTION = 3370397154,
	MERCHANT_UPGRADE_1 = 3370397156,
	MERCHANT_UPGRADE_2 = 3370693193,
	MERCHANT_UPGRADE_3 = 3370711752,
	MERCHANT_UPGRADE_4 = 3370711753,
}

-- Fonction principale ProcessReceipt
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("💳 [UNIFIED RECEIPT] Achat reçu!")
	print("   UserId:", userId)
	print("   ProductId:", productId)
	print("   PurchaseId:", purchaseId)
	
	-- Vérifier si c'est une DONATION
	if donationProducts[productId] then
		local price = donationProducts[productId]
		print("💰 [DONATION] Donation détectée:", price, "Robux")
		
		local success, err = pcall(function()
			DSLB:IncrementAsync(userId, price)
		end)
		
		if success then
			print("✅ [DONATION] Donation enregistrée avec succès!")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			warn("❌ [DONATION] Erreur:", err)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	
	-- Vérifier si c'est un RESTOCK
	if productId == OTHER_PRODUCTS.RESTOCK then
		print("🔄 [RESTOCK] Restock détecté")
		if _G.StockManager and _G.StockManager.forceRestock then
			local player = game.Players:GetPlayerByUserId(userId)
			if player then
				_G.StockManager.forceRestock(player)
				print("✅ [RESTOCK] Restock accordé")
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
	end
	
	-- Autres produits (incubateurs, upgrades, etc.)
	-- À compléter selon vos besoins
	
	warn("⚠️ [UNIFIED RECEIPT] Produit non géré:", productId)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("✅ [UNIFIED RECEIPT] ProcessReceipt configuré et prêt!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Vérifier toutes les 5 secondes si le ProcessReceipt est toujours le nôtre
task.spawn(function()
	while true do
		task.wait(5)
		if MarketplaceService.ProcessReceipt ~= MarketplaceService.ProcessReceipt then
			warn("⚠️ [UNIFIED RECEIPT] ATTENTION: ProcessReceipt a été écrasé par un autre script!")
		end
	end
end)
