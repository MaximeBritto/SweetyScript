--------------------------------------------------------------------
-- TRANSLATION_EXAMPLE.lua - Exemples d'utilisation du système de traduction
-- Ce fichier montre comment utiliser le TranslationManager dans ton code
--------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TranslationManager = require(ReplicatedStorage:WaitForChild("TranslationManager"))

--------------------------------------------------------------------
-- EXEMPLE 1: Détecter la langue d'un joueur
--------------------------------------------------------------------
local function example1_DetectLanguage(player)
    local language = TranslationManager.GetPlayerLanguage(player)
    print("Langue du joueur:", language)
    -- Résultat: "fr", "en", "es", etc.
end

--------------------------------------------------------------------
-- EXEMPLE 2: Traduire un texte simple
--------------------------------------------------------------------
local function example2_SimpleTranslation()
    -- Traduire en français
    local titleFR = TranslationManager.Translate("WELCOME_TITLE", "fr")
    print(titleFR)  -- "🎉 Bienvenue dans le jeu !"
    
    -- Traduire en espagnol
    local titleES = TranslationManager.Translate("WELCOME_TITLE", "es")
    print(titleES)  -- "🎉 ¡Bienvenido al juego!"
end

--------------------------------------------------------------------
-- EXEMPLE 3: Traduire avec des variables dynamiques
--------------------------------------------------------------------
local function example3_DynamicVariables(player)
    local lang = TranslationManager.GetPlayerLanguage(player)
    
    -- Remplacer {PLAYER} par le nom du joueur
    local message = TranslationManager.Translate("WELCOME_MESSAGE", lang, {
        PLAYER = player.Name
    })
    print(message)
    -- Résultat FR: "Salut PlayerName ! Je vais t'apprendre les bases..."
    -- Résultat EN: "Hi PlayerName! I'll teach you the basics..."
end

--------------------------------------------------------------------
-- EXEMPLE 4: Obtenir titre + message d'une étape
--------------------------------------------------------------------
local function example4_GetStepTranslations(player)
    local lang = TranslationManager.GetPlayerLanguage(player)
    
    -- Obtenir titre ET message en une seule fois
    local translations = TranslationManager.GetStepTranslations("WELCOME", lang, {
        PLAYER = player.Name
    })
    
    print("Titre:", translations.title)
    print("Message:", translations.message)
end

--------------------------------------------------------------------
-- EXEMPLE 5: Envoyer un message traduit au client
--------------------------------------------------------------------
local function example5_SendToClient(player, remoteEvent)
    local lang = TranslationManager.GetPlayerLanguage(player)
    local translations = TranslationManager.GetStepTranslations("GO_TO_VENDOR", lang)
    
    remoteEvent:FireClient(player, {
        title = translations.title,
        message = translations.message,
        -- ... autres données
    })
end

--------------------------------------------------------------------
-- EXEMPLE 6: Créer une UI traduite
--------------------------------------------------------------------
local function example6_CreateTranslatedUI(player)
    local lang = TranslationManager.GetPlayerLanguage(player)
    
    -- Créer un ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Parent = player:WaitForChild("PlayerGui")
    
    -- Créer un TextLabel avec texte traduit
    local label = Instance.new("TextLabel")
    label.Text = TranslationManager.Translate("WELCOME_TITLE", lang)
    label.Size = UDim2.new(0, 400, 0, 100)
    label.Position = UDim2.new(0.5, -200, 0.5, -50)
    label.Parent = gui
end

--------------------------------------------------------------------
-- EXEMPLE 7: Système de cache pour performances
--------------------------------------------------------------------
local playerLanguageCache = {}  -- Cache local

local function example7_CachedTranslation(player)
    -- Détecter la langue une seule fois
    if not playerLanguageCache[player] then
        playerLanguageCache[player] = TranslationManager.GetPlayerLanguage(player)
    end
    
    local lang = playerLanguageCache[player]
    
    -- Utiliser la langue en cache pour toutes les traductions
    local title = TranslationManager.Translate("WELCOME_TITLE", lang)
    return title
end

--------------------------------------------------------------------
-- EXEMPLE 8: Ajouter de nouvelles traductions (dans un autre module)
--------------------------------------------------------------------
--[[
    Pour ajouter tes propres traductions, crée un nouveau fichier:
    
    -- MyTranslations.lua
    return {
        MY_CUSTOM_TEXT = {
            en = "Hello!",
            fr = "Bonjour !",
            es = "¡Hola!",
            -- ... autres langues
        }
    }
    
    Puis charge-le dans TranslationManager.lua :
    local myTranslations = require(script.Parent:WaitForChild("MyTranslations"))
    
    Et modifie la fonction Translate pour chercher aussi dans myTranslations
]]

--------------------------------------------------------------------
-- EXEMPLE 9: Gérer les langues non supportées (fallback)
--------------------------------------------------------------------
local function example9_FallbackLanguage(player)
    local lang = TranslationManager.GetPlayerLanguage(player)
    
    -- Si la langue n'est pas supportée, le système utilise automatiquement l'anglais
    local title = TranslationManager.Translate("WELCOME_TITLE", lang)
    -- Toujours un résultat, jamais nil
    
    return title
end

--------------------------------------------------------------------
-- EXEMPLE 10: Traduire plusieurs textes en une fois
--------------------------------------------------------------------
local function example10_MultipleTranslations(player)
    local lang = TranslationManager.GetPlayerLanguage(player)
    
    local texts = {
        welcome = TranslationManager.Translate("WELCOME_TITLE", lang),
        vendor = TranslationManager.Translate("GO_TO_VENDOR_TITLE", lang),
        incubator = TranslationManager.Translate("GO_TO_INCUBATOR_TITLE", lang),
    }
    
    return texts
end

--------------------------------------------------------------------
-- 💡 CONSEILS D'UTILISATION
--------------------------------------------------------------------
--[[
    1. Cache la langue du joueur pour éviter les appels répétés à l'API
    2. Utilise GetStepTranslations() pour obtenir titre + message en une fois
    3. Toujours fournir un fallback (l'anglais est automatique)
    4. Teste avec différentes langues pour vérifier que tout fonctionne
    5. Utilise des placeholders {VARIABLE} pour les textes dynamiques
]]

return {
    example1_DetectLanguage = example1_DetectLanguage,
    example2_SimpleTranslation = example2_SimpleTranslation,
    example3_DynamicVariables = example3_DynamicVariables,
    example4_GetStepTranslations = example4_GetStepTranslations,
    example5_SendToClient = example5_SendToClient,
    example6_CreateTranslatedUI = example6_CreateTranslatedUI,
    example7_CachedTranslation = example7_CachedTranslation,
    example9_FallbackLanguage = example9_FallbackLanguage,
    example10_MultipleTranslations = example10_MultipleTranslations,
}
