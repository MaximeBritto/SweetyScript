-- RecipeManager.lua
-- Ce ModuleScript centralise toutes les recettes du jeu.
-- Il peut être appelé depuis n'importe quel script (serveur ou client)
-- pour garantir que tout le jeu utilise les mêmes données de recettes.


local RecipeManager = {}

-- [[ LISTE CENTRALE DES INGRÉDIENTS ]]
-- Prix, noms, emojis et modèles 3D des ingrédients vendus par le marchand
RecipeManager.Ingredients = {
	["Sucre"] =      { nom = "Sucre",      prix = 1,  emoji = "🍯", modele = "Sucre",      rarete = "Commune",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Gelatine"] =      { nom = "Gelatine",      prix = 1,  emoji = "🍮", modele = "Gelatine",      rarete = "Commune",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Sirop"] =      { nom = "Sirop",      prix = 3,  emoji = "🍯", modele = "Sirop",      rarete = "Commune",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 40 },
	["PoudreAcidulee"] = { nom = "Poudre Acidulée", prix = 2, emoji = "🍋", modele = "Poudre Acidulée",  rarete = "Commune", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["PoudreDeSucre"] = { nom = "Poudre de Sucre", prix = 1, emoji = "🌾", modele = "Poudre de Sucre", rarete = "Commune", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["SiropMais"] = { nom = "Sirop de Maïs", prix = 1, emoji = "🥣", modele = "SiropMais", rarete = "Commune", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["AromeVanilleDouce"] =       { nom = "Arôme Vanille Douce", prix = 5,  emoji = "🍨", modele = "Arôme Vanille Douce",     rarete = "Commune",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },
	["CaramelFondant"] = { nom = "Caramel Fondant", prix = 5, emoji = "🍮", modele = "CaramelFondant", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Noisettes"] = { nom = "Noisettes Grillées", prix = 4, emoji = "🌰", modele = "Noisettes", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Fraise"] =     { nom = "Fraise",     prix = 8,  emoji = "🍓", modele = "Fraise",   rarete = "Rare",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 25 },
	["Citron"] = { nom = "Citron", prix = 3, emoji = "🍋", modele = "Citron", 	rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Framboise"] = { nom = "Framboise", prix = 4, emoji = "🫐", modele = "Framboise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Cerise"] = { nom = "Cerise", prix = 4, emoji = "🍒", modele = "Cerise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Vanille"] =    { nom = "Vanille",    prix = 10, emoji = "🍦", modele = "Vanille",  rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Chocolat"] =   { nom = "Chocolat",   prix = 12, emoji = "🍫", modele = "Chocolat", rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["PollenMagique"] = { nom = "PollenMagique", prix = 20, emoji = "🌸", modele = "PollenMagique", rarete = "rare", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["Mangue"] = { nom = "Mangue", prix = 4, emoji = "🥭", modele = "Mangue", rarete = "Épique", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["CremeFouettee"] = { nom = "CremeFouettee", prix = 3, emoji = "🍦", modele = "CremeFouettee", rarete = "Épique", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Noisette"] =   { nom = "Noisette",   prix = 15, emoji = "🌰", modele = "Noisette", rarete = "Épique",  couleurRarete = Color3.fromRGB(255, 180, 100), quantiteMax = 5 },
	["MielAncien"] = { nom = "Perle de Miel Ancien", prix = 15, emoji = "🍯", modele = "MielAncien", rarete = "Épique", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["ArcEnCiel"] = { nom = "Essence d’Arc-en-Ciel", prix = 15, emoji = "🌈", modele = "ArcEnCiel", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["CristalEtoile"] = { nom = "CristaldeSucreÉtoilé", prix = 18, emoji = "✨", modele = "CristalEtoile", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["GivreLunaire"] = { nom = "GivreLunaire", prix = 18, emoji = "❄️", modele = "GivreLunaire", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["FlammeSucree"] = { nom = "Flamme Sucrée", prix = 28, emoji = "🔥", modele = "FlammeSucree", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["LarmeLicorne"] = { nom = "Larme de Licorne", prix = 30, emoji = "🦄", modele = "LarmeLicorne", rarete = "Mythique", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["SouffleCeleste"] = { nom = "Souffle Céleste", prix = 35, emoji = "☁️", modele = "SouffleCeleste", rarete = "Mythique", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["NectarEternel"] = { nom = "Nectar Éternel", prix = 35, emoji = "💧", modele = "NectarEternel", rarete = "Mythique", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["EssenceNeant"] = { nom = "Essence du Néant", prix = 40, emoji = "🌌", modele = "EssenceNeant", rarete = "Mythique", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },

    -- Ingrédients Récompense (débloqués via défis Pokédex)
    ["EssenceCommune"] = {
        nom = "Essence Commune",
        prix = 6,
        emoji = "🧪",
        modele = "EssenceCommune",
        rarete = "Commune",
        couleurRarete = Color3.fromRGB(150, 150, 150),
        quantiteMax = 20,
        unlockChallenge = "CompleteAllSizes_Commune"
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
    ["EssenceEpique"] = {
        nom = "Essence Épique",
        prix = 20,
        emoji = "🔮",
        modele = "EssenceEpique",
        rarete = "Épique",
        couleurRarete = Color3.fromRGB(200, 100, 255),
        quantiteMax = 10,
        unlockChallenge = "CompleteAllSizes_Epique"
    },
    ["EssenceLegendaire"] = {
        nom = "Essence Légendaire",
        prix = 28,
        emoji = "💎",
        modele = "EssenceLegendaire",
        rarete = "Légendaire",
        couleurRarete = Color3.fromRGB(255, 180, 100),
        quantiteMax = 8,
        unlockChallenge = "CompleteAllSizes_Legendaire"
    },
    ["EssenceMythique"] = {
        nom = "Essence Mythique",
        prix = 35,
        emoji = "🧬",
        modele = "EssenceMythique",
        rarete = "Mythique",
        couleurRarete = Color3.fromRGB(255, 100, 100),
        quantiteMax = 5,
        unlockChallenge = "CompleteAllSizes_Mythique"
    },

}

-- Ordre d'affichage des ingrédients dans le magasin (TOUS LES INGRÉDIENTS)
RecipeManager.IngredientOrder = {
	-- Ingrédients communs
	"Sucre","Gelatine", "Farine", "SiropMais", "Beurre", "Sirop", 
	-- Ingrédients rares
	"Lait", "Fraise", "CaramelFondant", "Noisettes", "CremeFouettee", "Framboise", "Citron", "Mangue", "Cerise",
	-- Ingrédients épiques
	"Vanille", "Chocolat",
	-- Ingrédients légendaires
	"Noisette", "ArcEnCiel", "CristalEtoile", "PollenMagique", "GivreLunaire", "MielAncien", "FlammeSucree",
	-- Ingrédients Mythiques
	"LarmeLicorne", "SouffleCeleste", "NectarEternel", "EssenceNeant",

	-- Ingrédients Récompense (apparaissent en fin de liste; le shop pourra les masquer tant que non débloqués)
	"EssenceCommune", "EssenceRare", "EssenceEpique", "EssenceLegendaire", "EssenceMythique"
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
--   rarete = "Commune",                            -- Rareté du bonbon (Commune, Rare, Épique, Légendaire, Mythique)
--   couleurRarete = Color3.fromRGB(150,150,150)    -- Couleur associée à la rareté pour l'UI
-- }
RecipeManager.Recettes = {
	["Basique"] = {
		ingredients = {sucre = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Basique",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Basique Gelatine"] = {
		ingredients = {sucre = 1, gelatine = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Basique",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Sucre Citron"] = {
		ingredients = {sucre = 1, poudreacidulee = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Sucre Citron",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Douceur Vanille"] = {
		ingredients = {sucre = 1, aromevanilledouce = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Douceur Vanille",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Tropical Doux"] = {
		ingredients = {siropmais = 1, poudreacidulee = 1, poudredesucre = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Tropical Doux",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Fête Foraine "] = {
		ingredients = {sucre = 1, poudreacidulee = 1, siropmais = 1, aromevanilledouce = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Fête Foraine ",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Arc de Sucre"] = {
		ingredients = {sucre = 1, poudredesucre = 2, aromevanilledouce = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Arc de Sucre ",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Caramele"] = {
		ingredients = {sucre = 1, caramelfondant = 1},
		temps = 3,
		valeur = 25,
		nom = "Bonbon Caramel",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonCaramel",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Caramel"] = {
		ingredients = {sucre = 1, sirop = 1},
		temps = 3,
		valeur = 25,
		nom = "Bonbon Caramel",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonCaramel",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Vanille Noire Croquante"] = {
		ingredients = {vanille = 1, chocolat = 1, noisettes = 1},
		temps = 3,
		valeur = 25,
		nom = "Bonbon Vanille Noire Croquante",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonCaramel",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["CeriseRoyale"] = {
		ingredients = {cerise = 1, poudredesucre = 1, pollenmagique = 1},
		temps = 6,
		valeur = 60,
		nom = "Bonbon Cerise Royale",
		emoji = "🍒",
		description = "Un bonbon d’une rareté exceptionnelle.",
		modele = "BonbonCeriseRoyale",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["CitronCaramelDore"] = {
		ingredients = {citron = 1, caramelfondant = 1, sucre = 1},
		temps = 6,
		valeur = 60,
		nom = "Bonbon Citron Caramel Doré",
		emoji = "🍒",
		description = "Un bonbon d’une rareté exceptionnelle.",
		modele = "BonbonCeriseRoyale",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["FramboiseLélé"] = {
		ingredients = {gelatine = 1, aromevanilledouce = 1, framboise = 1},
		temps = 4,
		valeur = 30,
		nom = "Bonbon Lait-Sucre",
		emoji = "🍬",
		description = "Un doux bonbon au lait sucré.",
		modele = "BonbonLaitSucre",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255)
	},
	["FraiseCaramel"] = {
		ingredients = {fraise = 1, caramelfondant = 1, sucre = 1},
		temps = 3,
		valeur = 28,
		nom = "Bonbon Fraise Caramel",
		emoji = "🍦",
		description = "Un bonbon fondant à la vanille intense.",
		modele = "BonbonVanilleSupreme",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["ForêtEnchantée"] = {
		ingredients = {chocolat = 1, framboise = 1, noisettes = 1, sucre = 1},
		temps = 3,
		valeur = 28,
		nom = "Bonbon Fraise Caramel",
		emoji = "🍦",
		description = "Un bonbon fondant à la vanille intense.",
		modele = "Bonbon Forêt Enchantée",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["VanilleFruité"] = {
		ingredients = {cerise = 1, vanille = 1, fraise = 1},
		temps = 5,
		valeur = 40,
		nom = "Bonbon Vanille Fruité",
		emoji = "🍦",
		description = "Un classique parfumé à la vanille.",
		modele = "BonbonVanille",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255)
	},
	["Fraise Coulante"] = {
		ingredients = {sucre = 1, sirop = 1, fraise = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Fraise Coulante",
		emoji = "✨",
		description = "Un mélange secret aux saveurs surprenantes.",
		modele = "BonbonFraiseCoulante",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(200, 100, 255)
	},
------ pas prevue de base 
	["FruitsMystiques"] = {
		ingredients = {fraise = 1, mangue = 1, framboise = 1},
		temps = 5,
		valeur = 45,
		nom = "Bonbon Fruits Mystiques",
		emoji = "🍇",
		description = "Un mélange fruité enchanté.",
		modele = "BonbonFruitsMystiques",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},

	["FraisePetillante"] = {
		ingredients = {sucre = 1, fraise = 1},
		temps = 4,
		valeur = 30,
		nom = "Bonbon Fraise Pétillante",
		emoji = "🍓",
		description = "Un bonbon fruité qui pétille en bouche.",
		modele = "BonbonFraisePetillante",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["ChocoHaz"] = {
		ingredients = {chocolat = 1, noisettes = 1},
		temps = 4,
		valeur = 35,
		nom = "Bonbon Chocolat Noisette",
		emoji = "🍫",
		description = "Un mélange gourmand chocolaté et croquant.",
		modele = "BonbonChocolatNoisette",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
-------------------------------------------------------
	["Praline Exotique"] = {
		ingredients = {mangue = 1, noisette = 1, chocolat = 1},
		temps = 7,
		valeur = 60,
		nom = "Bonbon Praline Exotique",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonCremeVanille",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(200, 100, 255)
	},
	["Gomme Magique"] = {
		ingredients = {gelatine = 1, ArcEnCiel = 1, sucre = 1, PoudreDeSucre = 1},
		temps = 7,
		valeur = 60,
		nom = "Bonbon Gomme Magique",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonGommeMagique",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(200, 100, 255)
	},
	["Acidulé Royal"] = {
		ingredients = {PoudreAcidulee = 1, CaramelFondant = 1, siropdemais = 1, PoudreDeSucre = 1},
		temps = 10,
		valeur = 100,
		nom = "Bonbon Acidulé Royal",
		emoji = "🍰",
		description = "Toute la douceur d'un fraisier dans un bonbon.",
		modele = "BonbonAciduléRoyal",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(255, 100, 100)
	},
	["MieletFruit"] = {
		ingredients = {miel_ancien = 1, framboise = 1, vanille = 1, PoudreDeSucre = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Miel et Fruit",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonMieletFrui",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["Mangue Passion"] = {
		ingredients = {mangue = 1, citron = 1, framboise = 1, PoudreDeSucre = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Mangue Passion",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonManguePassion",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["Trio des Bois"] = {
		ingredients = {framboise = 1, cerise = 1, noisette = 1, PoudreDeSucre = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Trio des Bois",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonTriodesBois",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["Nuage Fruité"] = {
		ingredients = {fraise = 1, CremeFouettee = 1, sucre = 1, PoudreAcidulee = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Nuage Fruité",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonNuageFruité",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["Soleil d'Été"] = {
		ingredients = {mangue = 1, FlammeSucree = 1, PoudreDeSucre = 1,CaramelFondant = 1 },
		temps = 8,
		valeur = 75,
		nom = "Bonbon Soleil d'Été",
		emoji = "🍫",
		description = "Le croquant de la noisette et la richesse du chocolat.",
		modele = "BonbonSoleild'Été",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 180, 100)
	},
	["ArcEnCiel"] = {
		ingredients = {arc_en_ciel = 1, PoudreDeSucre = 1, fraise = 1,SouffleCeleste = 1 },
		temps = 5,
		valeur = 58,
		nom = "Bonbon Arc-en-ciel",
		emoji = "🌈",
		description = "Un bonbon aux couleurs vives et éclatantes.",
		modele = "BonbonArcEnCiel",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["CitronGivre"] = {
		ingredients = {citron = 1, givrelunaire = 1, sucre = 1, CristalEtoile = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Citron Givré",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonCitronGivre",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["Fleur Royale"] = {
		ingredients = {cerise = 1, arc_en_ciel = 1, PollenMagique = 1, PoudreDeSucre = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Fleur Royale",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonFleurRoyale",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	----- pas utiliser pour l'instant 
	["MangueSoleil"] = {
		ingredients = {mangue = 1, souffleceleste = 1},
		temps = 5,
		valeur = 55,
		nom = "Bonbon Mangue Ensoleillée",
		emoji = "🥭",
		description = "Un bonbon exotique et aérien.",
		modele = "BonbonMangueSoleil",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["FramboiseMagique"] = {
		ingredients = {framboise = 1, pollen_magique = 1},
		temps = 5,
		valeur = 48,
		nom = "Bonbon Framboise Magique",
		emoji = "🫐",
		description = "Un bonbon aux pouvoirs mystérieux.",
		modele = "BonbonFramboiseMagique",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},

	["FlammeSucree"] = {
		ingredients = {flamme_sucree = 1, sirop = 1},
		temps = 5,
		valeur = 65,
		nom = "Bonbon Flamme Sucrée",
		emoji = "🔥",
		description = "Un bonbon chaud et intense.",
		modele = "BonbonFlammeSucree",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	---------------------------------------------------------------------
	["Néant Céleste"] = {
		ingredients = {cristal_etoile = 1, souffle_celeste = 1, larme_licorne = 1 ,EssenceNeant = 1 },
		temps = 6,
		valeur = 75,
		nom = "Bonbon Néant Céleste",
		emoji = "🌟",
		description = "Un bonbon scintillant venu des cieux.",
		modele = "BonbonNéantCéleste",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["NectarAbsolu"] = {
		ingredients = {souffle_celeste = 1, nectar_eternel = 1, MielAncien = 1, fraise = 1, citron = 1},
		temps = 6,
		valeur = 85,
		nom = "Bonbon Nectar Absolu",
		emoji = "☁️",
		description = "Un bonbon aérien et éternel.",
		modele = "BonbonNectarAbsolu",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["MythiqueSupreme"] = {
		ingredients = {essence_neant = 1, larme_licorne = 1, souffle_celeste = 1, nectar_eternel = 1},
		temps = 10,
		valeur = 150,
		nom = "Bonbon Mythique Suprême",
		emoji = "👑",
		description = "Le summum des bonbons, rare et précieux.",
		modele = "BonbonMythiqueSupreme",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
------------ a revoir 
	["EtoileSucree"] = {
		ingredients = {cristal_etoile = 1, nectar_eternel = 1},
		temps = 6,
		valeur = 75,
		nom = "Bonbon Étoilé",
		emoji = "🌟",
		description = "Un bonbon scintillant venu des cieux.",
		modele = "BonbonEtoileSucree",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["LicorneDouce"] = {
		ingredients = {larme_licorne = 1, creme_fouettee = 1,},
		temps = 6,
		valeur = 80,
		nom = "Bonbon Licorne",
		emoji = "🦄",
		description = "Un bonbon magique d’une douceur Mythiquee.",
		modele = "BonbonLicorneDouce",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},

	["Aurore"] = {
		ingredients = {essence_neant = 1, givre_lunaire = 1},
		temps = 6,
		valeur = 88,
		nom = "Bonbon Aurore",
		emoji = "🌌",
		description = "Un bonbon céleste et mystérieux.",
		modele = "BonbonAurore",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["CristalCeleste"] = {
		ingredients = {cristal_etoile = 1, souffle_celeste = 1},
		temps = 6,
		valeur = 90,
		nom = "Bonbon Cristal Céleste",
		emoji = "💎",
		description = "Un bonbon d’une pureté Mythiquee.",
		modele = "BonbonCristalCeleste",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["EssenceUltime"] = {
		ingredients = {essence_neant = 1, larme_licorne = 1},
		temps = 7,
		valeur = 100,
		nom = "Bonbon Essence Ultime",
		emoji = "✨",
		description = "Un bonbon ultime aux pouvoirs infinis.",
		modele = "BonbonEssenceUltime",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
------------------------
}

-- [[ SYSTÈME DE RARETÉS ]]
-- Définition des raretés disponibles pour l'interface
RecipeManager.Raretes = {
	["Commune"] = {
		nom = "Commune",
		couleur = Color3.fromRGB(150, 150, 150),
		ordre = 1
	},
	["Rare"] = {
		nom = "Rare", 
		couleur = Color3.fromRGB(100, 150, 255),
		ordre = 2
	},
	["Épique"] = {
		nom = "Épique",
		couleur = Color3.fromRGB(200, 100, 255),
		ordre = 3
	},
	["Légendaire"] = {
		nom = "Légendaire",
		couleur = Color3.fromRGB(255, 180, 100),
		ordre = 4
	},
	["Mythique"] = {
		nom = "Mythique",
		couleur = Color3.fromRGB(255, 100, 100),
		ordre = 5
	}
}

return RecipeManager 