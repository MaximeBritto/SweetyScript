-- RecipeManager.lua
-- Ce ModuleScript centralise toutes les recettes du jeu.
-- Il peut être appelé depuis n'importe quel script (serveur ou client)
-- pour garantir que tout le jeu utilise les mêmes données de recettes.


local RecipeManager = {}

-- [[ LISTE CENTRALE DES INGRÉDIENTS ]]
-- Prix, noms, emojis et modèles 3D des ingrédients vendus par le marchand
RecipeManager.Ingredients = {
	["Sucre"] =      { nom = "Sucre",      prix = 1,  emoji = "🍯", modele = "Sucre",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Gelatine"] =      { nom = "Gelatine",      prix = 1,  emoji = "🍮", modele = "Gelatine",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 50 },
	["Sirop"] =      { nom = "Sirop",      prix = 3,  emoji = "🍯", modele = "Sirop",      rarete = "Common",     couleurRarete = Color3.fromRGB(150, 150, 150), quantiteMax = 40 },
	["PoudreAcidulee"] = { nom = "Poudre Acidulée", prix = 2, emoji = "🍋", modele = "Poudre Acidulée",  rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["PoudreDeSucre"] = { nom = "Poudre de Sucre", prix = 1, emoji = "🌾", modele = "Poudre de Sucre", rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["SiropMais"] = { nom = "Sirop de Maïs", prix = 1, emoji = "🥣", modele = "SiropMais", rarete = "Common", couleurRarete = Color3.fromRGB(150,150,150), quantiteMax = 50 },
	["AromeVanilleDouce"] =       { nom = "Arôme Vanille Douce", prix = 5,  emoji = "🍨", modele = "Arôme Vanille Douce",     rarete = "Common",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 30 },
	["CaramelFondant"] = { nom = "Caramel Fondant", prix = 5, emoji = "🍮", modele = "CaramelFondant", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Noisette"] = { nom = "Noisette", prix = 4, emoji = "🌰", modele = "Noisettes", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Fraise"] =     { nom = "Fraise",     prix = 8,  emoji = "🍓", modele = "Fraise",   rarete = "Rare",        couleurRarete = Color3.fromRGB(100, 150, 255), quantiteMax = 25 },
	["Citron"] = { nom = "Citron", prix = 3, emoji = "🍋", modele = "Citron", 	rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Framboise"] = { nom = "Framboise", prix = 4, emoji = "🫐", modele = "Framboise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Cerise"] = { nom = "Cerise", prix = 4, emoji = "🍒", modele = "Cerise", rarete = "Rare", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["Vanille"] =    { nom = "Vanille",    prix = 10, emoji = "🍦", modele = "Vanille",  rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["Chocolat"] =   { nom = "Chocolat",   prix = 12, emoji = "🍫", modele = "Chocolat", rarete = "Rare",      couleurRarete = Color3.fromRGB(200, 100, 255), quantiteMax = 15 },
	["PollenMagique"] = { nom = "PollenMagique", prix = 20, emoji = "🌸", modele = "PollenMagique", rarete = "rare", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["Mangue"] = { nom = "Mangue", prix = 4, emoji = "🥭", modele = "Mangue", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["CremeFouettee"] = { nom = "CremeFouettee", prix = 3, emoji = "🍦", modele = "CremeFouettee", rarete = "Epic", couleurRarete = Color3.fromRGB(0,170,255), quantiteMax = 30 },
	["MielAncien"] = { nom = "Perle de Miel Ancien", prix = 15, emoji = "🍯", modele = "MielAncien", rarete = "Epic", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["ArcEnCiel"] = { nom = "Essence d’Arc-en-Ciel", prix = 15, emoji = "🌈", modele = "ArcEnCiel", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["CristalEtoile"] = { nom = "CristaldeSucreÉtoilé", prix = 18, emoji = "✨", modele = "CristalEtoile", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["GivreLunaire"] = { nom = "GivreLunaire", prix = 18, emoji = "❄️", modele = "GivreLunaire", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["FlammeSucree"] = { nom = "Flamme Sucrée", prix = 28, emoji = "🔥", modele = "FlammeSucree", rarete = "Legendary", couleurRarete = Color3.fromRGB(255,170,0), quantiteMax = 10 },
	["LarmeLicorne"] = { nom = "Larme de Licorne", prix = 30, emoji = "🦄", modele = "LarmeLicorne", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["SouffleCeleste"] = { nom = "Souffle Céleste", prix = 35, emoji = "☁️", modele = "SouffleCeleste", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["NectarEternel"] = { nom = "Nectar Éternel", prix = 35, emoji = "💧", modele = "NectarEternel", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },
	["EssenceNeant"] = { nom = "Essence du Néant", prix = 40, emoji = "🌌", modele = "EssenceNeant", rarete = "Mythic", couleurRarete = Color3.fromRGB(200,0,255), quantiteMax = 5 },

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
	"Sucre", "Gelatine", "PoudreAcidulee", "PoudreDeSucre", "SiropMais", "Sirop", "AromeVanilleDouce",

	-- Ingrédients RARES
	"Fraise", "Citron", "Framboise", "Cerise", "Vanille", "Chocolat", "CaramelFondant", "Noisettes", "PollenMagique",

	-- Ingrédients EpicS
	"Mangue", "CremeFouettee", "Noisette", "MielAncien",

	-- Ingrédients LegendaryS
	"ArcEnCiel", "CristalEtoile", "GivreLunaire", "FlammeSucree",

	-- Ingrédients MythicS
	"LarmeLicorne", "SouffleCeleste", "NectarEternel", "EssenceNeant",

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
		valeur = 100,
		nom = "Bonbon Basique",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
	},
	["Caramel"] = {
		ingredients = {sucre = 1, sirop = 1},
		temps = 3,
		valeur = 25,
		nom = "Bonbon Caramel",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonCaramel",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
	},
	["Sucre Citron"] = {
		ingredients = {sucre = 1, poudreacidulee = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Sucre Citron",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonBasique",
		rarete = "Common",
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
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
	},
	["Arc de Sucre"] = {
		ingredients = {sucre = 1, poudredesucre = 2, aromevanilledouce = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Arc de Sucre ",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonArcDeSucre",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
	},
	["Tropical Doux"] = {
		ingredients = {siropmais = 1, poudreacidulee = 1, poudredesucre = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Tropical Doux",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonTropicalDoux",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
	},
	["Fête Foraine "] = {
		ingredients = {sucre = 1, poudreacidulee = 1, siropmais = 1, aromevanilledouce = 1},
		temps = 2,
		valeur = 15,
		nom = "Bonbon Fête Foraine ",
		emoji = "🍬",
		description = "Un simple bonbon au sucre.",
		modele = "BonbonFeteForaine",
		rarete = "Common",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
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
		--done
	},
	["CitronCaramelDore"] = {
		ingredients = {citron = 1, caramelfondant = 1, sucre = 1},
		temps = 6,
		valeur = 60,
		nom = "Bonbon Citron Caramel Doré",
		emoji = "🍒",
		description = "Un bonbon d’une rareté exceptionnelle.",
		modele = "BonbonCitronCaramelDore",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(255, 170, 0)
		--done
	},
	["Vanille Noire Croquante"] = {
		ingredients = {vanille = 1, chocolat = 1, noisettes = 1},
		temps = 3,
		valeur = 25,
		nom = "Bonbon Vanille Noire Croquante",
		emoji = "🍮",
		description = "Un délicieux bonbon au caramel fondant.",
		modele = "BonbonVanilleNoireCroquante",
		rarete = "rare",
		couleurRarete = Color3.fromRGB(150, 150, 150)
		--done
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
		--done
	},
	["VanilleFruité"] = {
		ingredients = {cerise = 1, vanille = 1, fraise = 1},
		temps = 5,
		valeur = 40,
		nom = "Bonbon Vanille Fruité",
		emoji = "🍦",
		description = "Un classique parfumé à la vanille.",
		modele = "BonbonVanilleFruité",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(100, 150, 255)
		--done
	},
	["ForêtEnchantée"] = {
		ingredients = {chocolat = 1, framboise = 1, noisettes = 1, sucre = 1},
		temps = 3,
		valeur = 28,
		nom = "Bonbon Fraise Caramel",
		emoji = "🍦",
		description = "Un bonbon fondant à la vanille intense.",
		modele = "BonbonForêtEnchantée",
		rarete = "Rare",
		couleurRarete = Color3.fromRGB(0, 170, 255)
		--done
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
		--done
	},
	-------------------------------------------------------
	["Clown sucette"] = {
		ingredients = {fraise = 1, CremeFouettee = 1, sucre = 1, PoudreAcidulee = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Nuage Fruité",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonNuageFruité",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255)
		--todo
	},
	["Praline Exotique"] = {
		ingredients = {mangue = 1, noisette = 1, chocolat = 1},
		temps = 7,
		valeur = 60,
		nom = "Bonbon Praline Exotique",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonPralineExotique",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255)
		--done
	},
	["Gomme Magique"] = {
		ingredients = {gelatine = 1, ArcEnCiel = 1, sucre = 1, PoudreDeSucre = 1},
		temps = 7,
		valeur = 60,
		nom = "Bonbon Gomme Magique",
		emoji = "🍮",
		description = "Un délice crémeux et vanillé.",
		modele = "BonbonGommeMagique",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(200, 100, 255)
		--done
	},
	["Acidulé Royal"] = {
		ingredients = {PoudreAcidulee = 1, CaramelFondant = 1, siropdemais = 1, PoudreDeSucre = 1},
		temps = 10,
		valeur = 100,
		nom = "Bonbon Acidulé Royal",
		emoji = "🍰",
		description = "Toute la douceur d'un fraisier dans un bonbon.",
		modele = "BonbonAciduléRoyal",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(255, 100, 100)
		--done
	},
	["Mangue Passion"] = {
		ingredients = {mangue = 1, citron = 1, framboise = 1, PoudreDeSucre = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Mangue Passion",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonManguePassion",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255)
		--todo
	},
	["MieletFruit"] = {
		ingredients = {miel_ancien = 1, framboise = 1, vanille = 1, PoudreDeSucre = 1},
		temps = 4,
		valeur = 40,
		nom = "Bonbon Miel et Fruit",
		emoji = "🍯",
		description = "Un bonbon sucré au miel millénaire.",
		modele = "BonbonMieletFrui",
		rarete = "Epic",
		couleurRarete = Color3.fromRGB(0, 170, 255)
		--done
	},
	["ArcEnCiel"] = {
		ingredients = {arc_en_ciel = 1, PoudreDeSucre = 1, fraise = 1,SouffleCeleste = 1 },
		temps = 5,
		valeur = 58,
		nom = "Bonbon Arc-en-ciel",
		emoji = "🌈",
		description = "Un bonbon aux couleurs vives et éclatantes.",
		modele = "BonbonArcEnCiel",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0)
		--done
	},
	["CitronGivre"] = {
		ingredients = {citron = 1, givrelunaire = 1, sucre = 1, CristalEtoile = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Citron Givré",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonCitronGivre",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0)
		--done
	},
	["Fleur Royale"] = {
		ingredients = {cerise = 1, arc_en_ciel = 1, PollenMagique = 1, PoudreDeSucre = 1},
		temps = 5,
		valeur = 50,
		nom = "Bonbon Fleur Royale",
		emoji = "🍋",
		description = "Un bonbon glacé à la fraîcheur intense.",
		modele = "BonbonFleurRoyale",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 170, 0)
		--done
	},
	["Soleil d'Été"] = {
		ingredients = {mangue = 1, FlammeSucree = 1, PoudreDeSucre = 1,CaramelFondant = 1 },
		temps = 8,
		valeur = 75,
		nom = "Bonbon Soleil d'Été",
		emoji = "🍫",
		description = "Le croquant de la noisette et la richesse du chocolat.",
		modele = "BonbonSoleild'Été",
		rarete = "Legendary",
		couleurRarete = Color3.fromRGB(255, 180, 100)
		--done
	},
	---------------------------------------------------------------------
	["NectarAbsolu"] = {
		ingredients = {souffle_celeste = 1, nectar_eternel = 1, MielAncien = 1, FlammeSucree = 1, ArcEnCiel = 1},
		temps = 6,
		valeur = 85,
		nom = "Bonbon Nectar Absolu",
		emoji = "☁️",
		description = "Un bonbon aérien et éternel.",
		modele = "BonbonNectarAbsolu",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255)
		--done
	},
	["Néant Céleste"] = {
		ingredients = {cristal_etoile = 1, souffle_celeste = 1, larme_licorne = 1 ,EssenceNeant = 1 },
		temps = 6,
		valeur = 75,
		nom = "Bonbon Néant Céleste",
		emoji = "🌟",
		description = "Un bonbon scintillant venu des cieux.",
		modele = "BonbonNéantCéleste",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255)
		--done
	},
	["MythicSupreme"] = {
		ingredients = {essence_neant = 1, larme_licorne = 1, souffle_celeste = 1, nectar_eternel = 1},
		temps = 10,
		valeur = 150,
		nom = "Bonbon Mythic Suprême",
		emoji = "👑",
		description = "Le summum des bonbons, rare et précieux.",
		modele = "BonbonMythicSupreme",
		rarete = "Mythic",
		couleurRarete = Color3.fromRGB(200, 0, 255)
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

return RecipeManager 