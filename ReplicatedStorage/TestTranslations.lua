--------------------------------------------------------------------
-- TestTranslations.lua - Script de test pour le système de traduction
-- Exécute ce script dans la console pour tester les traductions
--------------------------------------------------------------------

local TranslationManager = require(script.Parent:WaitForChild("TranslationManager"))

print("🧪 [TEST] Début des tests de traduction...")
print("=" .. string.rep("=", 60))

-- Test 1: Vérifier toutes les langues supportées
local languages = {"en", "fr", "es", "de", "pt", "it", "ru", "ja", "zh", "ko", "ar", "tr", "pl", "nl"}
local testKey = "WELCOME_TITLE"

print("\n📋 Test 1: Traduction de", testKey, "dans toutes les langues")
for _, lang in ipairs(languages) do
    local translation = TranslationManager.Translate(testKey, lang)
    print("  ", lang, "→", translation)
end

-- Test 2: Vérifier les variables dynamiques
print("\n📋 Test 2: Variables dynamiques")
local welcomeMsg = TranslationManager.Translate("WELCOME_MESSAGE", "fr", {PLAYER = "TestPlayer"})
print("   FR avec {PLAYER}:", welcomeMsg)

local completedMsg = TranslationManager.Translate("COMPLETED_MESSAGE", "en", {REWARD = "100"})
print("   EN avec {REWARD}:", completedMsg)

-- Test 3: Vérifier toutes les étapes du tutoriel
print("\n📋 Test 3: Toutes les étapes du tutoriel en français")
local steps = {
    "WELCOME", "GO_TO_VENDOR", "TALK_TO_VENDOR", "BUY_SUGAR",
    "GO_TO_INCUBATOR", "OPEN_INCUBATOR", "WAIT_PRODUCTION",
    "PICKUP_CANDY", "OPEN_BAG", "SELL_CANDY",
    "GO_TO_PLATFORM", "UNLOCK_PLATFORM", "PLACE_CANDY_ON_PLATFORM",
    "COLLECT_MONEY", "COMPLETED"
}

for _, step in ipairs(steps) do
    local translations = TranslationManager.GetStepTranslations(step, "fr")
    print("   ✅", step, "→", translations.title)
end

-- Test 4: Fallback vers l'anglais
print("\n📋 Test 4: Fallback vers l'anglais pour langue inexistante")
local fallback = TranslationManager.Translate("WELCOME_TITLE", "xx")  -- Langue inexistante
print("   Langue 'xx' →", fallback, "(devrait être en anglais)")

-- Test 5: Clé inexistante
print("\n📋 Test 5: Gestion des clés inexistantes")
local missing = TranslationManager.Translate("NONEXISTENT_KEY", "en")
print("   Clé inexistante →", missing, "(devrait afficher un warning)")

print("\n" .. string.rep("=", 60))
print("🎉 [TEST] Tests terminés!")
print("💡 Si tous les tests affichent des traductions, le système fonctionne correctement.")
