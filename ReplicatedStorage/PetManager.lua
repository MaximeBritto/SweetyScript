-- PetManager.lua
-- Module pour gérer les données des PETs et leurs boosts
-- À placer dans ReplicatedStorage

local PetManager = {}

-- Définition des raretés (cohérent avec RecipeManager)
PetManager.Raretes = {
	Common = { ordre = 1, couleur = Color3.fromRGB(150, 150, 150) },
	Rare = { ordre = 2, couleur = Color3.fromRGB(100, 150, 255) },
	Epic = { ordre = 3, couleur = Color3.fromRGB(180, 100, 255) },
	Legendary = { ordre = 4, couleur = Color3.fromRGB(255, 200, 50) },
	Mythic = { ordre = 5, couleur = Color3.fromRGB(255, 50, 150) }
}

-- Définition des PETs disponibles
PetManager.Pets = {
	["Lapin"] = {
		nom = "Lapin Rapide",
		description = "Augmente la vitesse de marche",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		prix = 50000, -- 50K
		prixRobux = 25,
		boostType = "Speed",
		boostValue = 1.15, -- +15% vitesse
		modelName = "PetLapin",
		movementType = "Ground" -- Marche au sol
	},
	["Chat"] = {
		nom = "Chat Chanceux",
		description = "Augmente les gains d'argent",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		prix = 100000, -- 100K
		prixRobux = 30,
		boostType = "Money",
		boostValue = 1.10, -- +10% argent
		modelName = "PetChat",
		movementType = "Ground" -- Marche au sol
	},
	["Chien"] = {
		nom = "Chien Fidèle",
		description = "Augmente la capacité du sac",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		prix = 500000, -- 500K
		prixRobux = 50,
		boostType = "Capacity",
		boostValue = 1.20, -- +20% capacité
		modelName = "PetChien",
		movementType = "Ground" -- Marche au sol
	},
	["Renard"] = {
		nom = "Renard Rusé",
		description = "Augmente la vitesse de production",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		prix = 1000000, -- 1M
		prixRobux = 75,
		boostType = "Production",
		boostValue = 1.25, -- +25% vitesse production
		modelName = "PetRenard",
		movementType = "Ground" -- Marche au sol
	},
	["Panda"] = {
		nom = "Panda Zen",
		description = "Augmente tous les gains",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(180, 100, 255),
		prix = 10000000, -- 10M
		prixRobux = 150,
		boostType = "AllBonus",
		boostValue = 1.15, -- +15% tout
		modelName = "PetPanda",
		movementType = "Ground" -- Marche au sol
	},
	["Dragon"] = {
		nom = "Dragon Mystique",
		description = "Boost massif d'argent",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 200, 50),
		prix = 100000000, -- 100M
		prixRobux = 300,
		boostType = "Money",
		boostValue = 1.50, -- +50% argent
		modelName = "PetDragon",
		movementType = "Flying" -- Vole dans les airs
	},
	["Licorne"] = {
		nom = "Licorne Magique",
		description = "Boost massif de production",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 200, 50),
		prix = 250000000, -- 250M
		prixRobux = 400,
		boostType = "Production",
		boostValue = 1.75, -- +75% production
		modelName = "PetLicorne",
		movementType = "Flying" -- Vole dans les airs
	},
	["Phoenix"] = {
		nom = "Phoenix Éternel",
		description = "Boost ultime - Tous les bonus",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(255, 50, 150),
		prix = 1000000000, -- 1B
		prixRobux = 800,
		boostType = "AllBonus",
		boostValue = 2.0, -- +100% tout (x2)
		modelName = "PetPhoenix",
		movementType = "Flying" -- Vole dans les airs
	}
}

-- Ordre d'affichage des PETs (du moins cher au plus cher)
PetManager.PetOrder = {
	"Lapin", "Chat", "Chien", "Renard", "Panda", "Dragon", "Licorne", "Phoenix"
}

-- Fonction pour obtenir les infos d'un PET
function PetManager.getPetInfo(petName)
	return PetManager.Pets[petName]
end

-- Fonction pour calculer le boost total d'un joueur (avec plusieurs PETs équipés)
function PetManager.calculatePlayerBoosts(equippedPets)
	local boosts = {
		Speed = 1.0,
		Money = 1.0,
		Capacity = 1.0,
		Production = 1.0
	}
	
	-- equippedPets peut être une table ou une string (ancien système)
	local petsToProcess = {}
	if type(equippedPets) == "table" then
		petsToProcess = equippedPets
	elseif type(equippedPets) == "string" and equippedPets ~= "" then
		table.insert(petsToProcess, equippedPets)
	end
	
	for _, petName in ipairs(petsToProcess) do
		local petInfo = PetManager.getPetInfo(petName)
		if petInfo then
			if petInfo.boostType == "AllBonus" then
				-- Applique à tous les boosts
				for key, _ in pairs(boosts) do
					boosts[key] = boosts[key] * petInfo.boostValue
				end
			else
				-- Applique au boost spécifique
				boosts[petInfo.boostType] = boosts[petInfo.boostType] * petInfo.boostValue
			end
		end
	end
	
	return boosts
end

-- Constantes
PetManager.MAX_EQUIPPED_PETS = 3

return PetManager
