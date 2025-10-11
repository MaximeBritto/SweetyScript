-- RecipeManager.lua
-- Ce ModuleScript centralise toutes les recettes du jeu.
-- Il peut être appelé depuis n'importe quel script (serveur ou client)
-- pour garantir que tout le jeu utilise les mêmes données de recettes.


local RecipeManager = {}

-- [[ LISTE CENTRALE DES INGRÉDIENTS ]]
-- Prix, noms, emojis et modèles 3D des ingrédients vendus par le marchand
RecipeManager.Ingredients = {
	["Sucre"] =      { nom = "Sugar",      prix = 1,  emoji = "🍯", modele = "Sucre",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Gelatine"] =      { nom = "Gelatin",      prix = 1,  emoji = "🍮", modele = "Gelatine",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Sirop"] =      { nom = "Syrup",      prix = 40,  emoji = "🍯", modele = "Sirop",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 40 },
	["PoudreAcidulee"] = { nom = "Sour Powder", prix = 800, emoji = "🍋", modele = "PoudreAcidulee",  rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["AromeVanilleDouce"] =       { nom = "Sweet Vanilla Flavor", prix = 8_000,  emoji = "🍨", modele = "AromeVanilleDouce",     rarete = "Common",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },
	["PoudreDeSucre"] = { nom = "Powdered Sugar", prix = 160_000, emoji = "🌾", modele = "PoudreDeSucre", rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["SiropMais"] = { nom = "Corn Syrup", prix = 1_800_000, emoji = "🥣", modele = "SiropMais", rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["CottonCandy"] = { nom = "Cotton Candy", prix = 18_000_000,  emoji = "🍨", modele = "CottonCandy",     rarete = "Common",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },
	
	["Framboise"] = { nom = "Raspberry", prix = 180_000_000, emoji = "🫐", modele = "Framboise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["CaramelFondant"] = { nom = "Melting Caramel", prix = 900_000_000, emoji = "🍮", modele = "CaramelFondant", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Citron"] = { nom = "Lemon", prix = 900_000_000, emoji = "🍋", modele = "Citron", 	rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Noisette"] = { nom = "Hazelnut", prix = 6_000_000_000, emoji = "🌰", modele = "Noisettes", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Vanille"] =    { nom = "Vanilla",    prix = 6_000_000_000, emoji = "🍦", modele = "Vanille",  rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Chocolat"] =   { nom = "Chocolate",   prix = 6_000_000_000, emoji = "🍫", modele = "Chocolat", rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Fraise"] =     { nom = "Strawberry",     prix = 180_000_000_000,  emoji = "🍓", modele = "Fraise",   rarete = "Rare",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 25 },
	["Cerise"] = { nom = "Cherry", prix = 1_500_000_000_000, emoji = "🍒", modele = "Cerise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["WoodlandSugar"] = { nom = "Woodland Sugar", prix = 16_000_000_000_000, emoji = "🌸", modele = "WoodlandSugar", rarete = "rare", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["PollenMagique"] = { nom = "Magic Pollen", prix = 160_000_000_000_000, emoji = "🌸", modele = "PollenMagique", rarete = "rare", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	
	["MultiFruit"] = { nom = "Multi Fruit", prix = 22_000_000_000_000_000, emoji = "🥭", modele = "MultiFruit", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["EnchantedSyrup"] = { nom = "Enchanted Syrup", prix = 330_000_000_000_000_000, emoji = "🥭", modele = "EnchantedSyrup", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["RoyalJelly"] = { nom = "Royal Jelly", prix = 3_500_000_000_000_000_000, emoji = "🥭", modele = "RoyalJelly", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Mangue"] = { nom = "Mango", prix = 150_000_000_000_000_000_000, emoji = "🥭", modele = "Mangue", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["CremeFouettee"] = { nom = "Whipped Cream", prix = 1_500_000_000_000_000, emoji = "🍦", modele = "CremeFouettee", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["MielAncien"] = { nom = "Elder Honey", prix = 2_000_000_000_000_000_000_000, emoji = "🍯", modele = "MielAncien", rarete = "Epic", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	
	["EssenceArcEnCiel"] = { nom = "Rainbow Essence", prix = 30_000_000_000_000_000_000_000, emoji = "🌈", modele = "EssenceArcEnCiel", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["CristalEtoile"] = { nom = "Star Crystal", prix = 80_000_000_000_000_000_000_000 * 100, emoji = "✨", modele = "CristalEtoile", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["GivreLunaire"] = { nom = "Lunar Frost", prix = 4_500_000_000_000_000_000_000 * 100, emoji = "❄️", modele = "GivreLunaire", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["FlammeSucree"] = { nom = "Sweet Flame", prix = 160_000_000_000_000_000_000_000 * 1_000, emoji = "🔥", modele = "FlammeSucree", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	
	["LarmeLicorne"] = { nom = "Unicorn Tear", prix = 10_000_000_000_000_000_000_000 * 10_000_000, emoji = "🦄", modele = "LarmeLicorne", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["SouffleCeleste"] = { nom = "Heavenly Breath", prix = 80_000_000_000_000_000_000_000 * 10_000, emoji = "☁️", modele = "SouffleCeleste", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["NectarEternel"] = { nom = "Eternal Nectar", prix = 80_000_000_000_000_000_000_000 * 10_000, emoji = "💧", modele = "NectarEternel", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["EssenceNeant"] = { nom = "Void Essence", prix = 5_000_000_000_000_000_000_000 * 1_000_000_000, emoji = "🌌", modele = "EssenceNeant", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },

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

-- Ordre d'affichage des ingrédients dans le magasin (TOUS LES INGRÉDIENTS)
RecipeManager.IngredientOrder = {
	-- Ingrédients COMMUNS
	"Sucre", "Gelatine", "Sirop", "PoudreAcidulee", "AromeVanilleDouce", "PoudreDeSucre", "SiropMais", "CottonCandy",

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
	["Basique Gelatine"] = {
		ingredients = {sucre = 1, gelatine = 1},
		temps = 2,
		valeur = 4,
		nom = "Basic gelatin",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 1,
		--done
	},
	["Caramel"] = {
		ingredients = {sucre = 1, sirop = 1},
		temps = 5,
		valeur = 80,
		nom = "Caramel",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonCaramel",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 10,
		--done
	},
	["Sucre Citron"] = {
		ingredients = {sucre = 1, poudreacidulee = 1},
		temps = 15,
		valeur = 1_200,
		nom = "Lemon Sugar",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 50,
	},
	["Douceur Vanille"] = {
		ingredients = {sucre = 1, aromevanilledouce = 1},
		temps = 30,
		valeur = 16_000,
		nom = "Vanilla Sweetness",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 100,
		--done
	},
	["Arc de Sucre"] = {
		ingredients = {sucre = 1, poudredesucre = 2, aromevanilledouce = 1},
		temps = 120,
		valeur = 250_000,
		nom = "Sugar ark",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonArcDeSucre",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 500,
		--done
	},
	["Tropical Doux"] = {
		ingredients = {siropmais = 1, poudreacidulee = 1, poudredesucre = 1},
		temps = 300,
		valeur = 2_700_000,
		nom = "Tropical Sweet",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonTropicalDoux",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 3000,
		--done
	},
	["Fête Foraine "] = {
		ingredients = {sucre = 1, poudreacidulee = 1, cottoncandy = 1, aromevanilledouce = 1},
		temps = 600,
		valeur = 27_000_000,
		nom = "Funfair",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonFeteForaine",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 15_000,
		--done
	},
	--rare
	["FramboiseLélé"] = {
		ingredients = {gelatine = 1, aromevanilledouce = 1, framboise = 1},
		temps = 180,
		valeur = 270_000_000,
		nom = "Raspberry Lélé",
		emoji = "🍬",
		description = "Un doux bonbon au lait sucré.",
		modele = "BonbonLaitSucre",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		platformValue = 500_000,
		--done
	},
	["CitronCaramelDore"] = {
		ingredients = {citron = 1, caramelfondant = 1, sucre = 1},
		temps = 360,
		valeur = 2_700_000_000,
		nom = "Golden Caramel Lemon",
		emoji = "🍒",
		description = "Un bonbon d'une rareté exceptionnelle.",
		modele = "BonbonCitronCaramelDore",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 2_000_000,
		--done
	},
	["Vanille Noire Croquante"] = {
		ingredients = {vanille = 1, chocolat = 1, noisette = 1},
		temps = 600,
		valeur = 27_000_000_000,
		nom = "Crunchy Black Vanilla",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonVanilleNoireCroquante",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(150, 150, 150),
		platformValue = 10_000_000,
		--done
	},
	["Fraise Coulante"] = {
		ingredients = {sucre = 1, sirop = 1, fraise = 1},
		temps = 600,
		valeur = 270_000_000_000,
		nom = "Flowing Strawberry",
		emoji = "✨",
		description = "Un mélange secret aux saveurs surprenantes.",
		modele = "BonbonFraiseCoulante",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		platformValue = 100_000_000,
		--done
	},
	["VanilleFruité"] = {
		ingredients = {cerise = 1, vanille = 1, fraise = 1},
		temps = 600,
		valeur = 2_300_000_000_000,
		nom = "Vanilla Fruity",
		emoji = "🍦",
		description = "Un classique parfumé à la vanille.",
		modele = "BonbonVanilleFruité",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255),
		platformValue = 1_000_000_000,
		--done
	},
	["ForêtEnchantée"] = {
		ingredients = {chocolat = 1, framboise = 1, noisette = 1, woodlandsugar = 1},
		temps = 900,
		valeur = 25_000_000_000_000,
		nom = "Enchanted Forest",
		emoji = "🍦",
		description = "Un bonbon fondant à la vanille intense.",
		modele = "BonbonForêtEnchantée",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 5_000_000_000,
		--done
	},
	["CeriseRoyale"] = {
		ingredients = {cerise = 1, poudredesucre = 1, pollenmagique = 1},
		temps = 1_200,
		valeur = 240_000_000_000_000,
		nom = "Royal Cherry",
		emoji = "🍒",
		description = "Un bonbon d'une rareté exceptionnelle.",
		modele = "BonbonCeriseRoyale",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 15_000_000_000,
		--done
	},
	------------------------------------------------------- epic
	["Clown sucette"] = {
		ingredients = {fraise = 1, cremefouettee = 1, sucre = 1, poudreacidulee = 1},
		temps = 300,
		valeur = 2_250_000_000_000_000,
		nom = "Lollipop Clown",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonNuageFruité",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 1_000_000_000_000,
		--todo
	},
	["Praline Exotique"] = {
		ingredients = {multifruit  = 1, noisette = 1, chocolat = 1},
		temps = 480,
		valeur = 33_000_000_000_000_000,
		nom = "Exotic Praline",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonPralineExotique",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		platformValue = 5_000_000_000_000,
		--done
	},
	["Bonbon Gomme Magique"] = {
		ingredients = {gelatine = 1, enchantedsyrup = 1, sucre = 1, poudredesucre = 1},
		temps = 600,
		valeur = 450_000_000_000_000_000,
		nom = "Magic Gum",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonGommeMagique",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255),
		platformValue = 50_000_000_000_000,
		--done
	},
	["Acidulé Royal"] = {
		ingredients = {royaljelly = 1, caramelfondant = 1, siropdemais = 1, poudredesucre = 1},
		temps = 900,
		valeur = 5_000_000_000_000_000_000,
		nom = "Tangy Royal",
		emoji = "🍰",
		description = "Toute la douceur d'un fraisier dans un bonbon.",
		modele = "BonbonAciduléRoyal",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(255, 100, 100),
		platformValue = 500_000_000_000_000,
		--done
	},
	["Mangue Passion"] = {
		ingredients = {mangue = 1, citron = 1, framboise = 1, poudredesucre = 1},
		temps = 1_080,
		valeur = 220_000_000_000_000_000_000,
		nom = "Mango Passion",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonManguePassion",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 25_000_000_000_000_000,
		--todo
	},
	["MieletFruit"] = {
		ingredients = {mielancien = 1, framboise = 1, vanille = 1, poudredesucre = 1},
		temps = 1_200,
		valeur = 3_000_000_000_000_000_000_000,
		nom = "Honey and Fruit",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonMieletFrui",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255),
		platformValue = 100_000_000_000_000_000,
		--done
	},
	--Epic
	["ArcEnCiel"] = {
		ingredients = {essencearcenciel = 1, poudredesucre = 1, fraise = 1 },
		temps = 300,
		valeur = 4_500_000_000_000_000_000_000 * 10,
		nom = "Rainbow",
		emoji = "🌈",
		description = "Un bonbon aux couleurs vives et éclatantes.",
		modele = "BonbonArcEnCiel",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 1_000_000_000_000_000_000,
		--done
	},
	["CitronGivre"] = {
		ingredients = {citron = 1, givrelunaire = 1, sucre = 1},
		temps = 600,
		valeur = 6_500_000_000_000_000_000_000 * 100,
		nom = "Lemon Frost",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonCitronGivre",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 500_000_000_000_000_000_000,
		--done
	},
	["Fleur Royale"] = {
		ingredients = {cerise = 1, essencearcenciel = 1, pollenmagique = 1, cristaletoile = 1},
		temps = 900,
		valeur = 120_000_000_000_000_000_000_000 * 100,
		nom = "Royal Flower",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonFleurRoyale",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0),
		platformValue = 1_000_000_000_000_000_000_000,
		--done
	},
	["Soleil d'Été"] = {
		ingredients = {mangue = 1, flammesucree = 1, poudredesucre = 1,caramelfondant = 1 },
		temps = 1200,
		valeur = 20_000_000_000_000_000_000_000 * 10_000,
		nom = "Summer Sun",
		emoji = "🍫",
		description = "Le croquant de la noisette et la richesse du chocolat.",
		modele = "BonbonSoleild'Été",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 180, 100),
		platformValue = 5_000_000_000_000_000_000_000,
		--done
	},
	---------------------------------------------------------------------
	["NectarAbsolu"] = {
		ingredients = {souffleceleste = 1, nectareternel = 1, mielancien = 1, flammesucree = 1, essencearcenciel = 1},
		temps = 1_800,
		valeur = 2_500_000_000_000_000_000_000 * 1_000_000,
		nom = "Nectar Absolute",
		emoji = "☁️",
		description = "Un bonbon aérien et éternel.",
		modele = "BonbonNectarAbsolu",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255),
		platformValue = 5_000_000_000_000_000_000_000 * 10,
		--done
	},
	["Néant Céleste"] = {
		ingredients = {cristaletoile = 1, souffleceleste = 1, larmelicorne = 1 },
		temps = 3_600,
		valeur = 15_000_000_000_000_000_000_000 * 10_000_000,
		nom = "Heavenly void",
		emoji = "🌟",
		description = "Un bonbon scintillant venu des cieux.",
		modele = "BonbonNéantCéleste",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255),
		platformValue = 10_000_000_000_000_000_000_000 * 100,
		--done
	},
	["MythicSupreme"] = {
		ingredients = {essenceneant = 1, larmelicorne = 1, souffleceleste = 1, nectareternel = 1},
		temps = 7_200,
		valeur = 7_000_000_000_000_000_000_000 * 1_000_000_000,
		nom = "Supreme Mythic",
		emoji = "👑",
		description = "Le summum des bonbons, rare et précieux.",
		modele = "BonbonMythicSupreme",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255),
		platformValue = 5_000_000_000_000_000_000_000 * 10_000,
		--todo
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
	print("🔍 [RecipeManager] Calcul valeur plateforme:")
	print("  - Nom reçu:", candyName)
	print("  - SizeData:", sizeData)
	if sizeData then
		print("    - Taille:", sizeData.size)
		print("    - Rareté:", sizeData.rarity)
	end

	-- Trouver la recette correspondante
	local recipe = nil
	local matchedName = nil
	for recipeName, recipeData in pairs(RecipeManager.Recettes) do
		-- Recherche: nom exact ou modèle exact
		if recipeName == candyName or (recipeData.modele and recipeData.modele == candyName) then
			recipe = recipeData
			matchedName = recipeName
			print("  - Match exact trouvé:", recipeName)
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
				print("  - Match normalisé trouvé:", recipeName)
				break
			end
		end
	end

	if recipe then
		print("  - Recette trouvée:", matchedName)
	else
		print("  - ⚠️ RECETTE NON TROUVÉE! Utilisation valeur par défaut")
	end

	-- Valeur de base (défaut à 10 si non définie)
	local baseValue = (recipe and recipe.platformValue) or 10
	print("  - Valeur de base:", baseValue)

	-- Multiplicateur de taille (défaut à 1.0 si non défini)
	local sizeMultiplier = 1.0
	if sizeData and sizeData.rarity then
		sizeMultiplier = RecipeManager.SizeMultipliers[sizeData.rarity] or 1.0
		print("  - Multiplicateur taille:", sizeMultiplier, "(", sizeData.rarity, ")")
	else
		print("  - Pas de taille spécifique, multiplicateur = 1.0")
	end

	-- Calcul final
	local finalValue = baseValue * sizeMultiplier
	print("  - Valeur finale:", finalValue, "=", baseValue, "x", sizeMultiplier)

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