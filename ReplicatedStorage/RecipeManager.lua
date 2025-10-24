-- RecipeManager.lua
-- Ce ModuleScript centralise toutes les recettes du jeu.
-- Il peut être appelé depuis n'importe quel script (serveur ou client)
-- pour garantir que tout le jeu utilise les mêmes données de recettes.


local RecipeManager = {}

-- [[ LISTE CENTRALE DES INGRÉDIENTS ]]
-- Prix, noms, emojis et modèles 3D des ingrédients vendus par le marchand
RecipeManager.Ingredients = {
	["Sucre"] =      { nom = "Sugar",      prix = 15,  emoji = "🍯", modele = "Sucre",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150) },
	["Gelatine"] =      { nom = "Gelatin",      prix = 15,  emoji = "🍮", modele = "Gelatine",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150)},
	["Sirop"] =      { nom = "Syrup",      prix = 150,  emoji = "🍯", modele = "Sirop",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150)},
	["PoudreAcidulee"] = { nom = "Sour Powder", prix = 1_000, emoji = "🍋", modele = "PoudreAcidulee",  rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["ChipsDouce"] = { nom = "Sweet Vanilla Flavor", prix = 5_000,  emoji = "🍨", modele = "ChipsDouce",     rarete = "Common",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },
	["PoudreDeSucre"] = { nom = "Powdered Sugar", prix = 20_000, emoji = "🌾", modele = "PoudreDeSucre", rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["SiropMais"] = { nom = "Corn Syrup", prix = 600_000, emoji = "🥣", modele = "SiropMais", rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["CottonCandy"] = { nom = "Cotton Candy", prix = 4_200_000,  emoji = "🍨", modele = "CottonCandy",     rarete = "Common",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },

	["Framboise"] = { nom = "Raspberry", prix = 25_000_000, emoji = "🫐", modele = "Framboise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["CaramelFondant"] = { nom = "Melting Caramel", prix = 100_000_000, emoji = "🍮", modele = "CaramelFondant", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Citron"] = { nom = "Lemon", prix = 200_000_000, emoji = "🍋", modele = "Citron", 	rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Noisette"] = { nom = "Hazelnut", prix = 1_200_000_000, emoji = "🌰", modele = "Noisettes", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Vanille"] =    { nom = "Vanilla",    prix = 1_200_000_000, emoji = "🍦", modele = "Vanille",  rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Chocolat"] =   { nom = "Chocolate",   prix = 1_200_000_000, emoji = "🍫", modele = "Chocolat", rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Fraise"] =     { nom = "Strawberry",     prix = 19_000_000_000,  emoji = "🍓", modele = "Fraise",   rarete = "Rare",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 25 },
	["Cerise"] = { nom = "Cherry", prix = 475_000_000_000, emoji = "🍒", modele = "Cerise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["WoodlandSugar"] = { nom = "Woodland Sugar", prix = 2_100_000_000_000, emoji = "🌸", modele = "WoodlandSugar", rarete = "rare", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["PollenMagique"] = { nom = "Magic Pollen", prix = 48_000_000_000_000, emoji = "🌸", modele = "PollenMagique", rarete = "rare", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },

	["CremeFouettee"] = { nom = "Whipped Cream", prix = 1_500_000_000_000_000, emoji = "🍦", modele = "CremeFouettee", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["MultiFruit"] = { nom = "Multi Fruit", prix = 8_000_000_000_000_000, emoji = "🥭", modele = "MultiFruit", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["EnchantedSyrup"] = { nom = "Enchanted Syrup", prix = 87_500_000_000_000_000, emoji = "🥭", modele = "EnchantedSyrup", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["RoyalJelly"] = { nom = "Royal Jelly", prix = 1_800_000_000_000_000_000, emoji = "🥭", modele = "RoyalJelly", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Mangue"] = { nom = "Mango", prix = 7_000_000_000_000_000_000, emoji = "🥭", modele = "Mangue", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["MielAncien"] = { nom = "Elder Honey", prix = 120_000_000_000_000_000_000, emoji = "🍯", modele = "MielAncien", rarete = "Epic", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },

	["EssenceArcEnCiel"] = { nom = "Rainbow Essence", prix = 1_200_000_000_000_000_000_000, emoji = "🌈", modele = "EssenceArcEnCiel", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["GivreLunaire"] = { nom = "Lunar Frost", prix = 15_000_000_000_000_000_000_000, emoji = "❄️", modele = "GivreLunaire", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["CristalEtoile"] = { nom = "Star Crystal", prix = 3_750_000_000_000_000_000_000 * 100, emoji = "✨", modele = "CristalEtoile", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["FlammeSucree"] = { nom = "Sweet Flame", prix = 2_250_000_000_000_000_000_000 * 1_000, emoji = "🔥", modele = "FlammeSucree", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },

	["SouffleCeleste"] = { nom = "Heavenly Breath", prix = 2_700_000_000_000_000_000_000 * 10_000, emoji = "☁️", modele = "SouffleCeleste", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["NectarEternel"] = { nom = "Eternal Nectar", prix = 2_700_000_000_000_000_000_000 * 10_000, emoji = "💧", modele = "NectarEternel", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["LarmeLicorne"] = { nom = "Unicorn Tear", prix = 36_000_000_000_000_000_000_000 * 10_000, emoji = "🦄", modele = "LarmeLicorne", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["EssenceNeant"] = { nom = "Void Essence", prix = 6_500_000_000_000_000_000_000 * 1_000_000, emoji = "🌌", modele = "EssenceNeant", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },

	-- Ingrédients Récompense (débloqués via défis Pokédex)
	["EssenceCommon"] = {
		nom = "Essence Common",
		prix = 6,
		emoji = "🧪",
		modele = "EssenceCommon",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		quantiteMax = 20,
		unlockChallenge = "CompleteAllSizes_Common"
	},
	["EssenceRare"] = {
		nom = "Essence Rare",
		prix = 12,
		emoji = "💠",
		modele = "EssenceRare",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		quantiteMax = 15,
		unlockChallenge = "CompleteAllSizes_Rare"
	},
	["Essenceepic"] = {
		nom = "Essence Epic",
		prix = 20,
		emoji = "🔮",
		modele = "Essenceepic",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		quantiteMax = 10,
		unlockChallenge = "CompleteAllSizes_epic"
	},
	["EssenceLegendary"] = {
		nom = "Essence Legendary",
		prix = 28,
		emoji = "💎",
		modele = "EssenceLegendary",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 180, 100),
		quantiteMax = 8,
		unlockChallenge = "CompleteAllSizes_Legendary"
	},
	["EssenceMythic"] = {
		nom = "Essence Mythic",
		prix = 35,
		emoji = "🧬",
		modele = "EssenceMythic",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(255, 100, 100),
		quantiteMax = 5,
		unlockChallenge = "CompleteAllSizes_Mythic"
	},

}

-- [[ CONFIGURATION DES PLAGES DE RANDOMISATION PAR RARETÉ ]]
-- Définit les quantités min/max pour chaque rareté lors du restock
RecipeManager.RestockRanges = {
	["Common"] = {
		minQuantity = 0,
		maxQuantity = 8,
		highQuantityChance = 0.5,  -- 50% de chance d'avoir une quantité proche du max
		lowQuantityChance = 0.5    -- 50% de chance d'avoir une quantité proche du min
	},
	["Rare"] = {
		minQuantity = 0,
		maxQuantity = 6,
		highQuantityChance = 0.3,  -- 30% de chance
		lowQuantityChance = 0.7    -- 70% de chance
	},
	["Epic"] = {
		minQuantity = 0,
		maxQuantity = 4,
		highQuantityChance = 0.15, -- 15% de chance
		lowQuantityChance = 0.85   -- 85% de chance
	},
	["Legendary"] = {
		minQuantity = 0,
		maxQuantity = 2,
		highQuantityChance = 0.05, -- 5% de chance
		lowQuantityChance = 0.95   -- 95% de chance
	},
	["Mythic"] = {
		minQuantity = 0,
		maxQuantity = 1,
		highQuantityChance = 0.001, -- 0.1% de chance
		lowQuantityChance = 9.999   -- 99.9% de chance
	}
}

-- Ordre d'affichage des ingrédients dans le magasin (TOUS LES INGRÉDIENTS)
RecipeManager.IngredientOrder = {
	-- Ingrédients COMMUNS
	"Sucre", "Gelatine", "Sirop", "PoudreAcidulee", "ChipsDouce", "PoudreDeSucre", "SiropMais", "CottonCandy",

	-- Ingrédients RARES
	"Framboise", "CaramelFondant","Citron", "Noisette", "Vanille", "Chocolat", "Fraise",   "Cerise", "WoodlandSugar", "PollenMagique",

	-- Ingrédients EpicS
	"CremeFouettee", "MultiFruit", "EnchantedSyrup", "RoyalJelly", "Mangue", "MielAncien",

	-- Ingrédients LegendaryS
	"EssenceArcEnCiel", "GivreLunaire", "CristalEtoile",  "FlammeSucree",

	-- Ingrédients MythicS
	"SouffleCeleste", "NectarEternel", "LarmeLicorne",   "EssenceNeant",

	-- (Optionnel) Ingrédients Récompense (à la fin de la liste)
	-- "EssenceCommon", "EssenceRare", "Essenceepic", "EssenceLegendary", "EssenceMythic",
}

-- [[ LISTE CENTRALE DES RECETTES ]]
-- C'est le seul endroit où vous devez modifier les recettes.
--
-- Structure d'une recette :
-- {
--   ingredients = { [nom_ingredient] = quantite }, -- Ingrédients requis
--   temps = nombre,                                -- Temps de production en secondes
--   valeur = nombre,                               -- Prix de vente du bonbon
--   nom = "Nom à afficher",                        -- Nom affiché dans l'interface
--   emoji = "🍬",                                  -- Emoji pour l'interface
--   description = "Description pour l'UI",         -- Description dans le menu des recettes
--   modele = "NomDuModele3D",                      -- Modèle à faire apparaître (utilisé par l'incubateur)
--   rarete = "Common",                            -- Rareté du bonbon (Common, Rare, Epic, Legendary, Mythic)
--   couleurRarete = Color3.fromRGB(150,150,150)    -- Couleur associée à la rareté pour l'UI
-- }
RecipeManager.Recettes = {
	-- ========== COMMON (ordre 1-6) ==========
	["Basique Gelatine"] = {
		ordre = 1,
		ingredients = {sucre = 1, gelatine = 1},
		temps = 60,
		valeur = 60,
		candiesPerBatch = 60,
		nom = "Basic gelatin",
		emoji = "🍬",
		description = "A candy that sticks a bit — that's its charm !",
		modele = "BonbonBasique",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 1,
	},
	["Caramel"] = {
		ordre = 2,
		ingredients = {sucre = 1, sirop = 2},
		temps = 60,
		valeur = 500,
		candiesPerBatch = 60,
		nom = "Caramel",
		emoji = "🍮",
		description = "Melts in your mouth… or in your teeth !",
		modele = "BonbonCaramel",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 3,
	},
	["Douceur Vanille"] = {
		ordre = 3,
		ingredients = {sucre = 3, chipsdouce = 2},
		temps = 60,
		valeur = 15_000,
		candiesPerBatch = 60,
		nom = "Vanilla Sweetness",
		emoji = "🍬",
		description = "Sweetness incarnate. Simple, yet dangerous",
		modele = "BonbonDouceurVanille",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 10,
	},
	["Arc de Sucre"] = {
		ordre = 4,
		ingredients = {sucre = 2, poudredesucre = 3, chipsdouce = 1},
		temps = 60,
		valeur = 100_000,
		candiesPerBatch = 60,
		nom = "Sugar ark",
		emoji = "🍬",
		description = "Too sweet to be true… and yet, it is",
		modele = "BonbonArcDeSucre",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 50,
	},
	["Tropical Doux"] = {
		ordre = 5,
		ingredients = {siropmais = 2, poudreacidulee = 2, poudredesucre = 1},
		temps = 60,
		valeur = 1_800_000,
		candiesPerBatch = 60,
		nom = "Tropical Sweet",
		emoji = "🍬",
		description = "The taste of vacation in one sweet cube",
		modele = "BonbonTropicalDoux",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 500,
	},
	["Fête Foraine "] = {
		ordre = 6,
		ingredients = {sucre = 3, poudreacidulee = 1, cottoncandy = 2, chipsdouce = 2},
		temps = 60,
		valeur = 12_500_000,
		candiesPerBatch = 60,
		nom = "Funfair",
		emoji = "🍬",
		description = "It sticks to your fingers and childhood memories",
		modele = "BonbonFeteForaine",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 1_000,
	},
	-- ========== RARE (ordre 1-7) ==========
	["FramboiseLélé"] = {
		ordre = 1,
		ingredients = {gelatine = 3, chipsdouce = 1, framboise = 2},
		temps = 120,
		valeur = 75_000_000,
		candiesPerBatch = 60,
		nom = "Raspberry Lélé",
		emoji = "🍬",
		description = "A candy that stares at you with a smile… maybe",
		modele = "BonbonFramboiseLélé",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		platformValue = 5_000,
	},
	["CitronCaramelDore"] = {
		ordre = 2,
		ingredients = {citron = 1, caramelfondant = 1, sucre = 3},
		temps = 120,
		valeur = 600_000_000,
		candiesPerBatch = 60,
		nom = "Golden Caramel Lemon",
		emoji = "🍒",
		description = "When lemon decides to go luxury mode",
		modele = "BonbonCitronCaramelDore",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 50_000,
	},
	["Vanille Noire Croquante"] = {
		ordre = 3,
		ingredients = {vanille = 1, chocolat = 1, noisette = 1},
		temps = 120,
		valeur = 5_400_000_000,
		candiesPerBatch = 60,
		nom = "Crunchy Black Vanilla",
		emoji = "🍮",
		description = "Crunchy outside, mysterious inside",
		modele = "BonbonVanilleNoireCroquante",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 500_000,
	},
	["Fraise Coulante"] = {
		ordre = 4,
		ingredients = {sucre = 2, sirop = 2, fraise = 2},
		temps = 120,
		valeur = 57_000_000_000,
		candiesPerBatch = 60,
		nom = "Flowing Strawberry",
		emoji = "✨",
		description = "A candy that defies gravity and table manners",
		modele = "BonbonFraiseCoulante",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		platformValue = 5_000_000,
	},
	["VanilleFruité"] = {
		ordre = 5,
		ingredients = {cerise = 1, vanille = 1, fraise = 1},
		temps = 120,
		valeur = 700_000_000_000,
		candiesPerBatch = 60,
		nom = "Vanilla Fruity",
		emoji = "🍦",
		description = "A fruity cocktail wrapped in a cloud of sweetness",
		modele = "BonbonVanilleFruité",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		platformValue = 25_000_000,
	},
	["ForêtEnchantée"] = {
		ordre = 6,
		ingredients = {chocolat = 1, framboise = 1, noisette = 2, woodlandsugar = 3},
		temps = 120,
		valeur = 9_500_000_000_000,
		candiesPerBatch = 60,
		nom = "Enchanted Forest",
		emoji = "🍦",
		description = "Elves eat this to dance all night long, they say",
		modele = "BonbonForêtEnchantée",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 100_000_000,
	},
	["CeriseRoyale"] = {
		ordre = 7,
		ingredients = {cerise = 1, poudredesucre = 2, pollenmagique = 2},
		temps = 120,
		valeur = 144_000_000_000_000,
		candiesPerBatch = 60,
		nom = "Royal Cherry",
		emoji = "🍒",
		description = "A noble taste… sugar that demands respect",
		modele = "BonbonCeriseRoyale",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 1_000_000_000,
	},
	-- ========== EPIC (ordre 1-6) ==========
	["Clown sucette"] = {
		ordre = 1,
		ingredients = {fraise = 2, cremefouettee = 1, sucre = 3, poudreacidulee = 1},
		temps = 300,
		valeur = 2_250_000_000_000_000,
		candiesPerBatch = 100,
		nom = "Lollipop Clown",
		emoji = "🍯",
		description = "Sweet, funny, and a little scary. Like a real clown",
		modele = "BonbonClown",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 10_000_000_000,
	},
	["Praline Exotique"] = {
		ordre = 2,
		ingredients = {multifruit  = 2, noisette = 1, chocolat = 2},
		temps = 300,
		valeur = 24_000_000_000_000_000,
		candiesPerBatch = 100,
		nom = "Exotic Praline",
		emoji = "🍮",
		description = "A one-way trip to a chocolate island",
		modele = "BonbonPralineExotique",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		platformValue = 100_000_000_000,
	},
	["Bonbon Gomme Magique"] = {
		ordre = 3,
		ingredients = {gelatine = 3, enchantedsyrup =2, sucre = 3, poudredesucre = 1},
		temps = 300,
		valeur = 260_000_000_000_000_000,
		candiesPerBatch = 100,
		nom = "Magic Gum",
		emoji = "🍮",
		description = "Chew it… it might chew you back",
		modele = "BonbonGommeMagique",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		platformValue = 1_000_000_000_000,
	},
	["Acidulé Royal"] = {
		ordre = 4,
		ingredients = {royaljelly = 1, caramelfondant = 2, siropmais = 2, poudredesucre = 2},
		temps = 300,
		valeur = 2_700_000_000_000_000_000,
		candiesPerBatch = 100,
		nom = "Tangy Royal",
		emoji = "🍰",
		description = "Sour like a king who lost his throne",
		modele = "BonbonAciduléRoyal",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(255, 100, 100),
		platformValue = 10_000_000_000_000,
	},
	["Mangue Passion"] = {
		ordre = 5,
		ingredients = {mangue = 3, citron = 1, framboise = 1, poudredesucre = 2},
		temps = 300,
		valeur = 31_000_000_000_000_000_000,
		candiesPerBatch = 100,
		nom = "Eternal Bloom",
		emoji = "🍯",
		description = "A tropical explosion — no passport required",
		modele = "BonbonManguePassion",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 100_000_000_000_000,
	},
	["MieletFruit"] = {
		ordre = 6,
		ingredients = {mielancien = 2, framboise = 1, vanille = 2, poudredesucre = 3},
		temps = 300,
		valeur = 360_000_000_000_000_000_000,
		candiesPerBatch = 100,
		nom = "Honey and Fruit",
		emoji = "🍯",
		description = "Sweet, juicy, and dangerously addictive",
		modele = "BonbonMieletFrui",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 1_000_000_000_000_000,
	},
	-- ========== LEGENDARY (ordre 1-4) ==========
	["ArcEnCiel"] = {
		ordre = 1,
		ingredients = {essencearcenciel = 2, poudredesucre = 3, fraise = 1 },
		temps = 480,
		valeur = 3_600_000_000_000_000_000_000,
		candiesPerBatch = 80,
		nom = "Rainbow",
		emoji = "🌈",
		description = "Each color tastes different… or maybe not",
		modele = "BonbonArcEnCiel",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 10_000_000_000_000_000,
	},
	["CitronGivre"] = {
		ordre = 2,
		ingredients = {citron = 2, givrelunaire = 2, sucre = 4},
		temps = 480,
		valeur = 4_500_000_000_000_000_000_000 * 10,
		candiesPerBatch = 80,
		nom = "Lemon Frost",
		emoji = "🍋",
		description = "So cold it freezes your smile",
		modele = "BonbonCitronGivre",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 100_000_000_000_000_000,
	},
	["Fleur Royale"] = {
		ordre = 3,
		ingredients = {cerise = 2, essencearcenciel = 2, pollenmagique = 3, cristaletoile = 1},
		temps = 480,
		valeur = 56_000_000_000_000_000_000_000 * 10,
		candiesPerBatch = 80,
		nom = "Royal Flower",
		emoji = "🍋",
		description = "Grown with moonlight and royal pride",
		modele = "BonbonFleurRoyale",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 1_000_000_000_000_000_000,
	},
	["Soleil d'Été"] = {
		ordre = 4,
		ingredients = {mangue = 1, flammesucree = 2, poudredesucre = 3,caramelfondant = 2 },
		temps = 480,
		valeur = 675_000_000_000_000_000_000 * 10_000,
		candiesPerBatch = 80,
		nom = "Summer Sun",
		emoji = "🍫",
		description = "Shines, warms, and melts like a real sunbeam",
		modele = "BonbonSoleild'Été",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 180, 100),
		platformValue = 10_000_000_000_000_000_000,
	},
	
	-- ========== MYTHIC (ordre 1-3) ==========
	["NectarAbsolu"] = {
		ordre = 1,
		ingredients = {souffleceleste = 1, nectareternel = 1, mielancien = 1, flammesucree = 1, essencearcenciel = 1},
		temps = 600,
		valeur = 8_200_000_000_000_000_000_000 * 10_000,
		candiesPerBatch = 75,
		nom = "Nectar Absolute",
		emoji = "☁️",
		description = "A heavenly taste for divine sweet tooths",
		modele = "BonbonNectarAbsolu",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255),
		platformValue = 100_000_000_000_000_000_000,
	},
	["Néant Céleste"] = {
		ordre = 2,
		ingredients = {cristaletoile = 1, souffleceleste = 1, larmelicorne = 2 },
		temps = 600,
		valeur = 120_000_000_000_000_000_000_000 * 10_000,
		candiesPerBatch = 75,
		nom = "Heavenly void",
		emoji = "🌟",
		description = "You taste nothing… and yet everything",
		modele = "BonbonNéantCéleste",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255),
		platformValue = 1_000_000_000_000_000_000_000,
	},
	["MythicSupreme"] = {
		ordre = 3,
		ingredients = {essenceneant = 2, larmelicorne = 2, souffleceleste = 1, nectareternel = 1},
		temps = 600,
		valeur = 15_000_000_000_000_000_000_000 * 1_000_000,
		candiesPerBatch = 75,
		nom = "Supreme Mythic",
		emoji = "👑",
		description = "The candy of sugar gods — don't swallow it all at once",
		modele = "BonbonMythicSupreme",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255),
		platformValue = 10_000_000_000_000_000_000_000,
	},
}

-- [[ SYSTÈME DE RARETÉS ]]
-- Définition des raretés disponibles pour l'interface
RecipeManager.Raretes = {
	["Common"] = {
		nom = "Common",
		couleur = Color3.fromRGB(150, 150, 150),
		ordre = 1
	},
	["Rare"] = {
		nom = "Rare", 
		couleur = Color3.fromRGB(100, 150, 255),
		ordre = 2
	},
	["Epic"] = {
		nom = "Epic",
		couleur = Color3.fromRGB(200, 100, 255),
		ordre = 3
	},
	["Legendary"] = {
		nom = "Legendary",
		couleur = Color3.fromRGB(255, 180, 100),
		ordre = 4
	},
	["Mythic"] = {
		nom = "Mythic",
		couleur = Color3.fromRGB(255, 100, 100),
		ordre = 5
	}
}

-- Palette centralisée des couleurs par rareté (pour éviter de répéter les RGB)
RecipeManager.CouleursRarete = {
	["Common"]     = Color3.fromRGB(150, 150, 150),
	["Rare"]        = Color3.fromRGB(100, 150, 255),
	["Epic"]      = Color3.fromRGB(200, 100, 255),
	["Legendary"]  = Color3.fromRGB(255, 180, 100),
	["Mythic"]    = Color3.fromRGB(255, 100, 100),
}

-- Normalisation des libellés de rareté et application automatique de la couleur
local function _normalizeRareteName(r)
	if type(r) ~= "string" then return "Common" end
	-- Rendre insensible aux accents et à la casse sur les lettres utilisées
	local s = r
	s = s:gsub("É", "e"):gsub("é", "e"):gsub("È", "e"):gsub("è", "e"):gsub("Ê", "e"):gsub("ê", "e")
	s = s:gsub("À", "a"):gsub("Â", "a"):gsub("Ä", "a"):gsub("à", "a"):gsub("â", "a"):gsub("ä", "a")
	s = s:gsub("Ï", "i"):gsub("î", "i"):gsub("ï", "i")
	s = s:gsub("Ô", "o"):gsub("ô", "o")
	s = s:gsub("Ù", "u"):gsub("Û", "u"):gsub("Ü", "u"):gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u")
	s = string.lower(s)
	if string.find(s, "common", 1, true) then return "Common" end
	if string.find(s, "rare", 1, true) then return "Rare" end
	if string.find(s, "epic", 1, true) then return "Epic" end
	if string.find(s, "legendary", 1, true) then return "Legendary" end
	if string.find(s, "mythic", 1, true) then return "Mythic" end
	return "Common"
end

for ingName, ing in pairs(RecipeManager.Ingredients) do
	local key = _normalizeRareteName(ing.rarete)
	ing.rarete = key
	local col = RecipeManager.CouleursRarete[key]
	if col then
		ing.couleurRarete = col
	end
end

-- Harmoniser aussi les recettes
for recName, rec in pairs(RecipeManager.Recettes or {}) do
	local key = _normalizeRareteName(rec.rarete)
	rec.rarete = key
	local col = RecipeManager.CouleursRarete[key]
	if col then
		rec.couleurRarete = col
	end
end

-- [[ CALCUL DE VALEUR DE PLATEFORME SELON LA TAILLE ]]
-- Multiplicateurs selon la rareté de taille du bonbon
RecipeManager.SizeMultipliers = {
	["Tiny"] = 0.5,       -- Minuscule: 50% de la valeur
	["Small"] = 0.75,     -- Petit: 75% de la valeur
	["Normal"] = 1.0,     -- Normal: 100% de la valeur (base)
	["Large"] = 1.25,     -- Grand: 125% de la valeur
	["Giant"] = 1.5,      -- Géant: 150% de la valeur
	["Colossal"] = 2.0,   -- Colossal: 200% de la valeur
	["LEGENDARY"] = 3.0,  -- Légendaire: 300% de la valeur
}

-- Calcule la valeur de production d'une plateforme selon le bonbon et sa taille
function RecipeManager.calculatePlatformValue(candyName, sizeData)
	-- Trouver la recette correspondante
	local recipe = nil
	local matchedName = nil
	for recipeName, recipeData in pairs(RecipeManager.Recettes) do
		-- Recherche: nom exact ou modèle exact
		if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
			recipe = recipeData
			matchedName = recipeName
			break
		end
	end

	-- Si pas trouvé, essayer une recherche partielle (pour les noms avec espaces, etc.)
	if not recipe then
		for recipeName, recipeData in pairs(RecipeManager.Recettes) do
			local normalizedRecipeName = recipeName:gsub("%s+", ""):lower()
			local normalizedCandyName = candyName:gsub("%s+", ""):lower()
			if normalizedRecipeName == normalizedCandyName then
				recipe = recipeData
				matchedName = recipeName
				break
			end
		end
	end

	-- Valeur de base (défaut à 10 si non définie)
	local baseValue = (recipe and recipe.platformValue) or 10

	-- Multiplicateur de taille (défaut à 1.0 si non défini)
	local sizeMultiplier = 1.0
	if sizeData and sizeData.rarity then
		sizeMultiplier = RecipeManager.SizeMultipliers[sizeData.rarity] or 1.0
	end

	-- Calcul final
	local finalValue = baseValue * sizeMultiplier

	return math.floor(finalValue)
end

-- Obtient la valeur de base de plateforme d'une recette
function RecipeManager.getBasePlatformValue(candyName)
	for recipeName, recipeData in pairs(RecipeManager.Recettes) do
		if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
			return recipeData.platformValue or 10
		end
	end
	return 10
end

return RecipeManager 