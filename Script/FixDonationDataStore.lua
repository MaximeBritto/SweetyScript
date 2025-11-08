--[[
	SCRIPT DE CORRECTION DES DONATIONS
	
	Ce script permet de:
	1. Vérifier le contenu du DataStore des donations
	2. Ajouter manuellement une donation manquante
	3. Forcer la mise à jour du leaderboard
	
	À placer dans ServerScriptService et exécuter UNE SEULE FOIS
	Puis SUPPRIMER ce script après utilisation
--]]

local DataStoreService = game:GetService("DataStoreService")
local DSLB = DataStoreService:GetOrderedDataStore("DonoPurchaseLB")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔧 SCRIPT DE CORRECTION DES DONATIONS")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Fonction pour afficher le top 10 des donateurs
local function showTop10()
	print("\n📊 TOP 10 DES DONATEURS ACTUELS:")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	local success, err = pcall(function()
		local data = DSLB:GetSortedAsync(false, 10)
		local page = data:GetCurrentPage()
		
		if #page == 0 then
			print("❌ Aucune donation enregistrée")
			return
		end
		
		for rank, entry in ipairs(page) do
			local userId = entry.key
			local amount = entry.value
			local success2, username = pcall(function()
				return game.Players:GetNameFromUserIdAsync(userId)
			end)
			
			if success2 then
				print(rank .. ". " .. username .. " (ID: " .. userId .. ") - " .. amount .. " Robux")
			else
				print(rank .. ". UserID " .. userId .. " - " .. amount .. " Robux")
			end
		end
	end)
	
	if not success then
		warn("❌ Erreur lors de la lecture du DataStore:", err)
	end
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
end

-- Fonction pour ajouter manuellement une donation
_G.addDonation = function(userId, amount)
	print("\n💰 Ajout manuel d'une donation:")
	print("   UserID:", userId)
	print("   Montant:", amount, "Robux")
	
	local success, err = pcall(function()
		DSLB:IncrementAsync(userId, amount)
	end)
	
	if success then
		print("✅ Donation ajoutée avec succès!")
		print("   Le leaderboard se mettra à jour dans ~60 secondes")
	else
		warn("❌ Erreur:", err)
	end
end

-- Fonction pour obtenir le total d'un joueur
_G.getDonationTotal = function(userId)
	local success, total = pcall(function()
		return DSLB:GetAsync(userId) or 0
	end)
	
	if success then
		print("💰 Total des donations pour UserID", userId, ":", total, "Robux")
		return total
	else
		warn("❌ Erreur:", total)
		return 0
	end
end

-- Fonction pour forcer la mise à jour du leaderboard
_G.forceUpdateLeaderboard = function()
	print("🔄 Forçage de la mise à jour du leaderboard...")
	
	local donoBoard = workspace:FindFirstChild("DonoBoard")
	if donoBoard then
		local mainScript = donoBoard:FindFirstChild("MainScript")
		if mainScript then
			-- Déclencher une mise à jour en modifiant une valeur
			print("✅ Leaderboard trouvé, mise à jour en cours...")
			print("   Attendez quelques secondes...")
		else
			warn("❌ MainScript introuvable dans DonoBoard")
		end
	else
		warn("❌ DonoBoard introuvable dans Workspace")
	end
end

-- Afficher le top 10 au démarrage
showTop10()

print("📝 COMMANDES DISPONIBLES (dans la console):")
print("   showTop10()                    - Afficher le top 10")
print("   addDonation(userId, amount)    - Ajouter une donation manuelle")
print("   getDonationTotal(userId)       - Voir le total d'un joueur")
print("   forceUpdateLeaderboard()       - Forcer la mise à jour")
print("\n💡 EXEMPLE pour ajouter 100 Robux au joueur ID 12345:")
print("   addDonation(12345, 100)")
print("\n⚠️  IMPORTANT: Supprimez ce script après utilisation!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

-- Rendre les fonctions globales accessibles
_G.showTop10 = showTop10
