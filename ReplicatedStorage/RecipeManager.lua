-- RecipeManager.lua
-- Ce ModuleScript centralise toutes les recettes du jeu.
-- Il peut être appelé depuis n'importe quel script (serveur ou client)
-- pour garantir que tout le jeu utilise les mêmes données de recettes.
print("Chargement de RecipeManager v2...")

local RecipeManager = {}

-- [[ LISTE CENTRALE DES INGRÉDIENTS ]]
-- Prix, noms, emojis et modèles 3D des ingrédients vendus par le marchand
RecipeManager.Ingredients = {
	["Sucre"] =      { nom = "Sucre",      prix = 1,  emoji = "🍯", modele = "Sucre",    rarete = "Commune",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Sirop"] =      { nom = "Sirop",      prix = 3,  emoji = "🍯", modele = "Sirop",    rarete = "Commune",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 40 },
	["Lait"] =       { nom = "Lait",       prix = 5,  emoji = "🥛", modele = "Lait",     rarete = "Rare",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },
	["Fraise"] =     { nom = "Fraise",     prix = 8,  emoji = "🍓", modele = "Fraise",   rarete = "Rare",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 25 },
	["Vanille"] =    { nom = "Vanille",    prix = 10, emoji = "🍦", modele = "Vanille",  rarete = "Épique",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Chocolat"] =   { nom = "Chocolat",   prix = 12, emoji = "🍫", modele = "Chocolat", rarete = "Épique",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Noisette"] =   { nom = "Noisette",   prix = 15, emoji = "🌰", modele = "Noisette", rarete = "Légendaire",  couleurRarete = Color3.fromRGB(255, 180, 100), quantiteMax = 5 },
	["Beurre"] = { nom = "Beurre", prix = 2, emoji = "🧈", modele = "Beurre", rarete = "Commune", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["Farine"] = { nom = "Farine", prix = 1, emoji = "🌾", modele = "Farine", rarete = "Commune", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["SiropMais"] = { nom = "Sirop de Maïs", prix = 1, emoji = "🥣", modele = "SiropMais", rarete = "Commune", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["CaramelFondant"] = { nom = "Caramel Fondant", prix = 5, emoji = "🍮", modele = "CaramelFondant", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Noisettes"] = { nom = "Noisettes Grillées", prix = 4, emoji = "🌰", modele = "Noisettes", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["CremeFouettee"] = { nom = "Crème Fouettée", prix = 3, emoji = "🍦", modele = "CremeFouettee", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Framboise"] = { nom = "Framboise", prix = 4, emoji = "🫐", modele = "Framboise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Citron"] = { nom = "Citron", prix = 3, emoji = "🍋", modele = "Citron", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Mangue"] = { nom = "Mangue", prix = 4, emoji = "🥭", modele = "Mangue", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Cerise"] = { nom = "Cerise", prix = 4, emoji = "🍒", modele = "Cerise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["ArcEnCiel"] = { nom = "Essence d’Arc-en-Ciel", prix = 15, emoji = "🌈", modele = "ArcEnCiel", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["CristalEtoile"] = { nom = "CristaldeSucreÉtoilé", prix = 18, emoji = "✨", modele = "CristalEtoile", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["PollenMagique"] = { nom = "PollenMagique", prix = 20, emoji = "🌸", modele = "PollenMagique", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["GivreLunaire"] = { nom = "GivreLunaire", prix = 18, emoji = "❄️", modele = "GivreLunaire", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["MielAncien"] = { nom = "Perle de Miel Ancien", prix = 15, emoji = "🍯", modele = "MielAncien", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["FlammeSucree"] = { nom = "Flamme Sucrée", prix = 28, emoji = "🔥", modele = "FlammeSucree", rarete = "Légendaire", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["LarmeLicorne"] = { nom = "Larme de Licorne", prix = 30, emoji = "🦄", modele = "LarmeLicorne", rarete = "Divin", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["SouffleCeleste"] = { nom = "Souffle Céleste", prix = 35, emoji = "☁️", modele = "SouffleCeleste", rarete = "Divin", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["NectarEternel"] = { nom = "Nectar Éternel", prix = 35, emoji = "💧", modele = "NectarEternel", rarete = "Divin", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["EssenceNeant"] = { nom = "Essence du Néant", prix = 40, emoji = "🌌", modele = "EssenceNeant", rarete = "Divin", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },

}

-- Ordre d'affichage des ingrédients dans le magasin
RecipeManager.IngredientOrder = {"Sucre", "Sirop", "Lait", "Fraise", "Vanille", "Chocolat", "Noisette", "Beurre", 'PollenMagique', 'GivreLunaire','CristalEtoile', 'Citron'}

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
		ingredients = {sucre = 2},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Basique",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
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
	["SucreMax"] = {
		ingredients = {sucre = 3},
		temps = 2,
		valeur = 30,
		nom = "Bonbon Sucre Max",
		emoji = "🍭",
		description = "Une explosion de sucre pur.",
		modele = "BonbonSucreMax",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255)
	},
	["Mystere"] = {
		ingredients = {sucre = 1, sirop = 1, fraise = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Mystère",
		emoji = "✨",
		description = "Un mélange secret aux saveurs surprenantes.",
		modele = "BonbonMystere",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(200, 100, 255)
	},
	["Lait Sucre"] = {
		ingredients = {sucre = 1, lait = 1},
		temps = 4,
		valeur = 30,
		nom = "Bonbon Lait-Sucre",
		emoji = "🍬",
		description = "Un doux bonbon au lait sucré.",
		modele = "BonbonLaitSucre",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255)
	},
	["Vanille Sucree"] = {
		ingredients = {sucre = 1, vanille = 1},
		temps = 5,
		valeur = 40,
		nom = "Bonbon à la Vanille",
		emoji = "🍦",
		description = "Un classique parfumé à la vanille.",
		modele = "BonbonVanille",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255)
	},
	["Creme Vanille"] = {
		ingredients = {sucre = 1, lait = 1, vanille = 1},
		temps = 7,
		valeur = 60,
		nom = "Bonbon Crème Vanille",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonCremeVanille",
		rarete = "Épique",
		couleurRarete = Color3.fromRGB(200, 100, 255)
	},
	["Praline"] = {
		ingredients = {sucre = 1, chocolat = 1, noisette = 1},
		temps = 8,
		valeur = 75,
		nom = "Bonbon Praliné",
		emoji = "🍫",
		description = "Le croquant de la noisette et la richesse du chocolat.",
		modele = "BonbonPraline",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 180, 100)
	},
	["Fraisier"] = {
		ingredients = {sucre = 1, lait = 1, vanille = 1, fraise = 1},
		temps = 10,
		valeur = 100,
		nom = "Bonbon Fraisier",
		emoji = "🍰",
		description = "Toute la douceur d'un fraisier dans un bonbon.",
		modele = "BonbonFraisier",
		rarete = "Mythique",
		couleurRarete = Color3.fromRGB(255, 100, 100)
	},
	["LaitDoux"] = {
		ingredients = {sucre = 1, lait = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Lait Doux",
		emoji = "🥛",
		description = "Un bonbon crémeux au doux goût de lait.",
		modele = "BonbonLaitDoux",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
	},
	["Caramele"] = {
		ingredients = {sucre = 1, caramel_fondant = 1},
		temps = 3,
		valeur = 25,
		nom = "Bonbon Caramel",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonCaramel",
		rarete = "Commune",
		couleurRarete = Color3.fromRGB(150, 150, 150)
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
	["ChocolatNoisette"] = {
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
	["CitronGivre"] = {
		ingredients = {citron = 1, givrelunaire = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Citron Givré",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonCitronGivre",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
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
	["CeriseRoyale"] = {
		ingredients = {cerise = 1, arcenciel = 1},
		temps = 6,
		valeur = 60,
		nom = "Bonbon Cerise Royale",
		emoji = "🍒",
		description = "Un bonbon d’une rareté exceptionnelle.",
		modele = "BonbonCeriseRoyale",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["VanilleSupreme"] = {
		ingredients = {vanille = 1, creme_fouettee = 1},
		temps = 3,
		valeur = 28,
		nom = "Bonbon Vanille Suprême",
		emoji = "🍦",
		description = "Un bonbon fondant à la vanille intense.",
		modele = "BonbonVanilleSupreme",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
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
	["EtoileSucree"] = {
		ingredients = {cristal_etoile = 1, nectar_eternel = 1},
		temps = 6,
		valeur = 75,
		nom = "Bonbon Étoilé",
		emoji = "🌟",
		description = "Un bonbon scintillant venu des cieux.",
		modele = "BonbonEtoileSucree",
		rarete = "Divin",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["MielAncien"] = {
		ingredients = {miel_ancien = 1, beurre = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Miel Ancien",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonMielAncien",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
	},
	["ArcEnCiel"] = {
		ingredients = {arc_en_ciel = 1, caramel_fondant = 1},
		temps = 5,
		valeur = 58,
		nom = "Bonbon Arc-en-ciel",
		emoji = "🌈",
		description = "Un bonbon aux couleurs vives et éclatantes.",
		modele = "BonbonArcEnCiel",
		rarete = "Légendaire",
		couleurRarete = Color3.fromRGB(255, 170, 0)
	},
	["LicorneDouce"] = {
		ingredients = {larme_licorne = 1, creme_fouettee = 1},
		temps = 6,
		valeur = 80,
		nom = "Bonbon Licorne",
		emoji = "🦄",
		description = "Un bonbon magique d’une douceur divine.",
		modele = "BonbonLicorneDouce",
		rarete = "Divin",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["NectarCeleste"] = {
		ingredients = {souffle_celeste = 1, nectar_eternel = 1},
		temps = 6,
		valeur = 85,
		nom = "Bonbon Nectar Céleste",
		emoji = "☁️",
		description = "Un bonbon aérien et éternel.",
		modele = "BonbonNectarCeleste",
		rarete = "Divin",
		couleurRarete = Color3.fromRGB(200, 0, 255)
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
	["Aurore"] = {
		ingredients = {essence_neant = 1, givre_lunaire = 1},
		temps = 6,
		valeur = 88,
		nom = "Bonbon Aurore",
		emoji = "🌌",
		description = "Un bonbon céleste et mystérieux.",
		modele = "BonbonAurore",
		rarete = "Divin",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
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
	["CristalCeleste"] = {
		ingredients = {cristal_etoile = 1, souffle_celeste = 1},
		temps = 6,
		valeur = 90,
		nom = "Bonbon Cristal Céleste",
		emoji = "💎",
		description = "Un bonbon d’une pureté divine.",
		modele = "BonbonCristalCeleste",
		rarete = "Divin",
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
		rarete = "Divin",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},
	["DivinSupreme"] = {
		ingredients = {essence_neant = 1, larme_licorne = 1, souffle_celeste = 1, nectar_eternel = 1},
		temps = 10,
		valeur = 150,
		nom = "Bonbon Divin Suprême",
		emoji = "👑",
		description = "Le summum des bonbons, rare et précieux.",
		modele = "BonbonDivinSupreme",
		rarete = "Divin",
		couleurRarete = Color3.fromRGB(200, 0, 255)
	},

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