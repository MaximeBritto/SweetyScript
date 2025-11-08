--------------------------------------------------------------------
-- TranslationManager.lua - Système de traduction automatique
-- Détecte la langue du joueur et traduit tous les textes
--------------------------------------------------------------------

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TranslationManager = {}

-- Charger les traductions étendues
local extendedTranslations = require(script.Parent:WaitForChild("TutorialTranslations_Extended"))
local finalTranslations = require(script.Parent:WaitForChild("TutorialTranslations_Final"))

--------------------------------------------------------------------
-- 🧪 MODE TEST : Force une langue spécifique pour tester dans Studio
-- Change "TEST_MODE" à true et définis "FORCE_LANGUAGE" pour tester
--------------------------------------------------------------------
local TEST_MODE = false
local FORCE_LANGUAGE = "fr"

--------------------------------------------------------------------
-- DICTIONNAIRE DE TRADUCTIONS
--------------------------------------------------------------------
local TRANSLATIONS = {
    WELCOME_TITLE = {
        en = "🎉 Welcome to the game!",
        fr = "🎉 Bienvenue dans le jeu !",
        es = "🎉 ¡Bienvenido al juego!",
        de = "🎉 Willkommen im Spiel!",
    },
    WELCOME_MESSAGE = {
        en = "Hi {PLAYER}! I'll teach you the basics.\nLet's start by buying some ingredients!",
        fr = "Salut {PLAYER} ! Je vais t'apprendre les bases.\nCommençons par acheter des ingrédients !",
        es = "¡Hola {PLAYER}! Te enseñaré lo básico.\n¡Empecemos comprando ingredientes!",
        de = "Hallo {PLAYER}! Ich bringe dir die Grundlagen bei.\nLass uns mit dem Kauf von Zutaten beginnen!",
    },
    GO_TO_VENDOR_TITLE = {
        en = "🛒 Go see the vendor",
        fr = "🛒 Va voir le vendeur",
        es = "🛒 Ve a ver al vendedor",
        de = "🛒 Geh zum Verkäufer",
    },
    GO_TO_VENDOR_MESSAGE = {
        en = "Great! Now go to the vendor to buy ingredients.\n\n🎯 Follow the golden arrow!",
        fr = "Super ! Maintenant va voir le vendeur pour acheter des ingrédients.\n\n🎯 Suis la flèche dorée !",
        es = "¡Genial! Ahora ve al vendedor para comprar ingredientes.\n\n🎯 ¡Sigue la flecha dorada!",
        de = "Großartig! Geh jetzt zum Verkäufer, um Zutaten zu kaufen.\n\n🎯 Folge dem goldenen Pfeil!",
    },
    TALK_TO_VENDOR_TITLE = {
        en = "💬 Talk to the vendor",
        fr = "💬 Parle au vendeur",
        es = "💬 Habla con el vendedor",
        de = "💬 Sprich mit dem Verkäufer",
    },
    TALK_TO_VENDOR_MESSAGE = {
        en = "Great! Now click on the vendor to open the shop menu!",
        fr = "Super ! Maintenant clique sur le vendeur pour ouvrir le menu de la boutique !",
        es = "¡Genial! ¡Ahora haz clic en el vendedor para abrir el menú de la tienda!",
        de = "Großartig! Klicke jetzt auf den Verkäufer, um das Shop-Menü zu öffnen!",
    },
    BUY_SUGAR_TITLE = {
        en = "🛒 Buy ingredients",
        fr = "🛒 Achète des ingrédients",
        es = "🛒 Compra ingredientes",
        de = "🛒 Kaufe Zutaten",
    },
    BUY_SUGAR_MESSAGE = {
        en = "Buy 1 'Sugar' and 1 'Gelatin' in the shop.",
        fr = "Achète 1 'Sucre' et 1 'Gélatine' dans la boutique.",
        es = "Compra 1 'Azúcar' y 1 'Gelatina' en la tienda.",
        de = "Kaufe 1 'Zucker' und 1 'Gelatine' im Shop.",
    },
    GO_TO_INCUBATOR_TITLE = {
        en = "🏭 Go to your incubator",
        fr = "🏭 Va à ton incubateur",
        es = "🏭 Ve a tu incubadora",
        de = "🏭 Geh zu deinem Inkubator",
    },
    GO_TO_INCUBATOR_MESSAGE = {
        en = "Now that you have sugar and gelatin, go to your incubator!",
        fr = "Maintenant que tu as du sucre et de la gélatine, va à ton incubateur !",
        es = "Ahora que tienes azúcar y gelatina, ¡ve a tu incubadora!",
        de = "Jetzt, wo du Zucker und Gelatine hast, geh zu deinem Inkubator!",
    },
    OPEN_INCUBATOR_TITLE = {
        en = "🏭 Start production",
        fr = "🏭 Démarre la production",
        es = "🏭 Iniciar producción",
        de = "🏭 Produktion starten",
    },
    OPEN_INCUBATOR_MESSAGE = {
        en = "Click the incubator to open the recipe menu!",
        fr = "Clique sur l'incubateur pour ouvrir le menu des recettes !",
        es = "¡Haz clic en la incubadora para abrir el menú de recetas!",
        de = "Klicke auf den Inkubator, um das Rezeptmenü zu öffnen!",
    },
}

--------------------------------------------------------------------
-- FONCTION POUR DÉTECTER LA LANGUE DU JOUEUR
--------------------------------------------------------------------
function TranslationManager.GetPlayerLanguage(player)
    if TEST_MODE then
        print("🧪 [TRANSLATION TEST] Langue forcée:", FORCE_LANGUAGE)
        return FORCE_LANGUAGE
    end
    
    local success, result = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(player)
    end)
    
    if not success then
        print("⚠️ [TRANSLATION] Impossible de détecter la langue, utilisation de l'anglais par défaut")
        return "en"
    end
    
    local countryToLanguage = {
        FR = "fr", BE = "fr", CH = "fr", CA = "fr",
        ES = "es", MX = "es", AR = "es", CO = "es",
        DE = "de", AT = "de",
        BR = "pt", PT = "pt",
        IT = "it",
        RU = "ru",
        JP = "ja",
        CN = "zh",
        KR = "ko",
    }
    
    local language = countryToLanguage[result] or "en"
    print("🌐 [TRANSLATION] Langue détectée pour", player.Name, ":", language)
    
    return language
end

--------------------------------------------------------------------
-- FONCTION POUR TRADUIRE UN TEXTE
--------------------------------------------------------------------
function TranslationManager.Translate(key, language, replacements)
    local translationTable = TRANSLATIONS[key]
    
    if not translationTable then
        translationTable = extendedTranslations[key]
    end
    
    if not translationTable then
        translationTable = finalTranslations[key]
    end
    
    if not translationTable then
        warn("❌ [TRANSLATION] Clé de traduction introuvable:", key)
        return key
    end
    
    local text = translationTable[language] or translationTable["en"] or key
    
    if replacements then
        for placeholder, value in pairs(replacements) do
            -- Ignorer les valeurs qui ne sont pas des strings ou numbers (comme player Instance)
            if type(value) == "string" or type(value) == "number" then
                text = text:gsub("{" .. placeholder .. "}", tostring(value))
            end
        end
    end
    
    return text
end

--------------------------------------------------------------------
-- FONCTION POUR OBTENIR TOUTES LES TRADUCTIONS D'UNE ÉTAPE
--------------------------------------------------------------------
function TranslationManager.GetStepTranslations(stepName, language, replacements)
    local titleKey = stepName .. "_TITLE"
    local messageKey = stepName .. "_MESSAGE"
    
    return {
        title = TranslationManager.Translate(titleKey, language, replacements),
        message = TranslationManager.Translate(messageKey, language, replacements)
    }
end

return TranslationManager
