# 🎓 Système de Tutoriel - Guide d'Installation

## 📋 Vue d'ensemble

Le système de tutoriel guide automatiquement les nouveaux joueurs à travers les mécaniques de base du jeu :

1. **Bienvenue** - Message d'accueil
2. **Aller au vendeur** - Flèche et surbrillance du vendeur
3. **Parler au vendeur** - Dialogue "Hey tu veux acheter quoi ?"
4. **Acheter du sucre** - Surbrillance du sucre dans le menu (2 unités)
5. **Aller à l'incubateur** - Flèche vers l'incubateur du joueur
6. **Créer un bonbon** - Instructions pour la production
7. **Ramasser le bonbon** - Ramasser le bonbon créé
8. **Vendre le bonbon** - Ouvrir le sac et vendre

## 📁 Fichiers créés

### Scripts Serveur (dans `Script/`)
- `TutorialManager.lua` - Gestionnaire principal du tutoriel
- `VendeurPNJ.lua` - **MODIFIÉ** pour intégrer le tutoriel
- `IncubatorServer.lua` - **MODIFIÉ** pour détecter la création de bonbons
- `CreateRemoteEvents.lua` - **MODIFIÉ** pour ajouter les RemoteEvents

### Scripts Client (dans `Script/`)
- `TutorialClient.lua` - Interface utilisateur (messages, flèches, surbrillance)

## 🔧 Installation

### 1. Placement des scripts

**Scripts Serveur :**
- `TutorialManager.lua` → `ServerScriptService`
- `VendeurPNJ.lua` → Dans le PNJ vendeur (avec ClickDetector)
- `IncubatorServer.lua` → `ServerScriptService`
- `CreateRemoteEvents.lua` → `ServerScriptService` (exécuter une fois)

**Scripts Client :**
- `TutorialClient.lua` → `StarterPlayer > StarterPlayerScripts`

### 2. Configuration requise

#### Dans `TutorialManager.lua`, ajustez ces positions :

```lua
local TUTORIAL_CONFIG = {
    -- À MODIFIER selon votre jeu
    VENDOR_POSITION = Vector3.new(0, 5, 0),     -- Position du vendeur
    INCUBATOR_POSITION = Vector3.new(10, 5, 10), -- Position type d'incubateur
    
    STARTING_MONEY = 100,        -- Argent minimum pour le tutoriel
    COMPLETION_REWARD = 500      -- Récompense de fin
}
```

#### Structure requise dans le Workspace :

```
Workspace/
├── [Vendeur avec ClickDetector]
├── Ile_Slot_1/
│   └── Incubator (Model)
├── Ile_Slot_2/
│   └── Incubator (Model)
└── ...
```

#### Structure requise pour les joueurs :

```
Player/
└── PlayerData/
    ├── Argent (IntValue)
    ├── SacBonbons (Folder)
    └── TutorialCompleted (BoolValue) [créé automatiquement]
```

## 🎮 Fonctionnement

### Déclenchement automatique
- Le tutoriel se déclenche automatiquement pour tout nouveau joueur
- Vérifie si `PlayerData.TutorialCompleted` existe
- Si absent, lance le tutoriel après 3 secondes

### Détection des actions
- **Clic vendeur** : Détecté via `VendeurPNJ.lua`
- **Achat ingrédients** : Détecté via `AchatIngredientEvent_V2`
- **Création bonbons** : Détecté via `IncubatorServer.lua`
- **Ramassage bonbons** : Détecté via `PickupCandyEvent`
- **Vente bonbons** : Détecté via `VenteEvent`

### Interface utilisateur
- **Messages** : Boîtes avec titre et instructions
- **Flèches** : Pointent vers les objets importants
- **Surbrillance** : Met en évidence les éléments interactifs
- **Sons** : Notifications sonores à chaque étape

## 🔧 Personnalisation

### Modifier les messages

Dans `TutorialManager.lua`, modifiez les fonctions `start[X]Step()` :

```lua
local function startWelcomeStep(player)
    tutorialStepRemote:FireClient(player, "WELCOME", {
        title = "🎉 Votre titre personnalisé",
        message = "Votre message personnalisé pour " .. player.Name,
        -- ...
    })
end
```

### Ajouter des étapes

1. Ajoutez l'étape dans `TUTORIAL_CONFIG.STEPS`
2. Créez une fonction `startNouvelleEtapeStep(player)`
3. Ajoutez la détection dans les hooks appropriés

### Modifier l'apparence

Dans `TutorialClient.lua`, modifiez `UI_CONFIG` :

```lua
local UI_CONFIG = {
    BACKGROUND_COLOR = Color3.fromRGB(20, 20, 20),
    HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0),
    ARROW_COLOR = Color3.fromRGB(255, 215, 0),
    -- ...
}
```

## 🐛 Dépannage

### Problèmes courants

1. **Tutoriel ne se déclenche pas**
   - Vérifiez que `PlayerData` existe
   - Vérifiez que `TutorialCompleted` n'existe pas déjà
   - Regardez les logs console pour les erreurs

2. **Flèches ne pointent pas au bon endroit**
   - Ajustez `VENDOR_POSITION` et `INCUBATOR_POSITION`
   - Vérifiez que les objets ont les bons noms

3. **Surbrillance ne fonctionne pas**
   - Vérifiez que les objets sont des `BasePart`
   - Vérifiez les noms des éléments UI dans le menu d'achat

4. **Étapes ne s'enchaînent pas**
   - Vérifiez que les RemoteEvents sont créés
   - Vérifiez les hooks dans les scripts existants

### Logs de débogage

Le système affiche des logs préfixés par `🎓 [TUTORIAL]` :

```
🎓 [TUTORIAL] Nouveau joueur détecté: PlayerName
🎓 [TUTORIAL] PlayerName → Étape: WELCOME
🎓 [TUTORIAL] PlayerName → Étape: GO_TO_VENDOR
🎉 [TUTORIAL] PlayerName a terminé le tutoriel!
```

## 📝 Notes importantes

- Le tutoriel est **automatique** et **non-intrusif**
- Les joueurs ayant déjà fait le tutoriel ne le reverront pas
- Le système s'intègre parfaitement avec les scripts existants
- Tous les éléments UI sont nettoyés automatiquement

## 🎯 Prochaines améliorations possibles

- Bouton "Passer le tutoriel" pour les joueurs expérimentés
- Tutoriels avancés pour les fonctionnalités complexes
- Système de hints contextuels
- Replay du tutoriel sur demande
- Tutoriel adaptatif selon le niveau du joueur

---

**Système créé par l'IA - Prêt à l'emploi ! 🚀** 