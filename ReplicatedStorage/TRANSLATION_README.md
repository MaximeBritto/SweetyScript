# 🌐 Système de Traduction Automatique - Tutorial

## 📋 Vue d'ensemble

Ce système traduit automatiquement tout le tutoriel dans la langue du joueur en utilisant l'API de localisation de Roblox.

## 🎯 Langues supportées

- 🇬🇧 Anglais (en) - Par défaut
- 🇫🇷 Français (fr)
- 🇪🇸 Espagnol (es)
- 🇩🇪 Allemand (de)
- 🇵🇹 Portugais (pt)
- 🇮🇹 Italien (it)
- 🇷🇺 Russe (ru)
- 🇯🇵 Japonais (ja)
- 🇨🇳 Chinois (zh)
- 🇰🇷 Coréen (ko)
- 🇸🇦 Arabe (ar)
- 🇹🇷 Turc (tr)
- 🇵🇱 Polonais (pl)
- 🇳🇱 Néerlandais (nl)

## 📁 Structure des fichiers

```
ReplicatedStorage/
├── TranslationManager.lua          # Module principal de traduction
├── TutorialTranslations_Extended.lua  # Traductions étapes intermédiaires
└── TutorialTranslations_Final.lua     # Traductions étapes finales

Script/
└── TutorialManager.lua             # Utilise le système de traduction
```

## 🚀 Comment ça fonctionne

### 1. Détection automatique de la langue

Quand un joueur rejoint, le système détecte automatiquement sa langue via :
```lua
local lang = TranslationManager.GetPlayerLanguage(player)
```

Cette fonction utilise `LocalizationService:GetCountryRegionForPlayerAsync()` pour détecter le pays du joueur et mapper vers la langue appropriée.

### 2. Traduction des textes

Pour traduire un texte :
```lua
local translations = TranslationManager.GetStepTranslations("WELCOME", lang, {PLAYER = player.Name})
```

Cela retourne :
```lua
{
    title = "🎉 Bienvenue dans le jeu !",  -- Si le joueur est français
    message = "Salut PlayerName ! Je vais t'apprendre les bases..."
}
```

### 3. Variables dynamiques

Tu peux utiliser des placeholders dans les traductions :
```lua
{PLAYER} -> Nom du joueur
{REWARD} -> Montant de la récompense
```

## ➕ Ajouter une nouvelle langue

1. Ouvre `TranslationManager.lua`
2. Ajoute le mapping pays → langue dans `countryToLanguage` :
```lua
VI = "vi",  -- Vietnam
```

3. Ajoute les traductions dans chaque fichier :
```lua
WELCOME_TITLE = {
    en = "🎉 Welcome!",
    fr = "🎉 Bienvenue !",
    vi = "🎉 Chào mừng!",  -- Nouvelle langue
}
```

## ➕ Ajouter une nouvelle étape du tutoriel

1. Crée les traductions dans `TutorialTranslations_Final.lua` :
```lua
NEW_STEP_TITLE = {
    en = "Title in English",
    fr = "Titre en français",
    -- ... autres langues
},
NEW_STEP_MESSAGE = {
    en = "Message in English",
    fr = "Message en français",
    -- ... autres langues
},
```

2. Utilise-les dans `TutorialManager.lua` :
```lua
local translations = TranslationManager.GetStepTranslations("NEW_STEP", lang)
tutorialStepRemote:FireClient(player, "NEW_STEP", {
    title = translations.title,
    message = translations.message,
})
```

## 🔧 Maintenance

- **Fallback** : Si une traduction manque, le système utilise automatiquement l'anglais
- **Cache** : La langue du joueur est mise en cache pour éviter les appels répétés à l'API
- **Nettoyage** : Le cache est automatiquement nettoyé quand le joueur quitte

## 🐛 Debug

Pour voir quelle langue est détectée, regarde les logs :
```
🌐 [TRANSLATION] Langue détectée pour PlayerName : fr (Pays: FR)
```

Si une traduction manque :
```
❌ [TRANSLATION] Clé de traduction introuvable: UNKNOWN_KEY
```

## 📝 Notes

- Le système est **100% automatique** - aucune configuration requise par le joueur
- Les traductions sont **instantanées** - pas de délai de chargement
- Compatible avec **tous les appareils** (PC, Mobile, Console)
