# 💾 Système de Sauvegarde SweetyScript

Un système de sauvegarde complet et robuste pour votre jeu Roblox, capable de sauvegarder et restaurer toutes les données des joueurs de manière sécurisée.

## 🌟 Fonctionnalités

### 💾 Sauvegarde Complète
- **Inventaire** : Tous les outils avec quantités
- **Tailles de bonbons** : 🍬 Préservation des tailles (Tiny, Small, Large, Giant, Colossal, etc.)
- **Économie** : Argent, niveau marchand, déblocages
- **Progression** : Recettes, ingrédients, tailles découvertes
- **Tutoriel** : Statut et progression
- **Plateformes** : Déblocages et configuration

### 🔄 Sauvegarde Automatique
- ✅ Toutes les 5 minutes (si données modifiées)
- ✅ À la déconnexion du joueur
- ✅ À l'arrêt du serveur
- ✅ Gestion intelligente du cache pour éviter les sauvegardes redondantes

### 🛡️ Sécurité et Robustesse
- **Validation serveur** : Toute la logique côté serveur uniquement
- **Système de retry** : 3 tentatives avec délais croissants
- **Compression** : Optimisation automatique des données volumineuses
- **Backup** : Copies de sécurité multiples
- **Limite de taille** : Protection contre les données corrompues

### 🧪 Interface de Test
- Interface graphique pour tester les sauvegardes
- Statistiques détaillées en temps réel
- Résumé des données du joueur
- Raccourcis clavier (F8, Ctrl+S)

## 📁 Architecture

```
SweetyScript/
├── ReplicatedStorage/
│   └── SaveDataManager.lua      # Module principal de sauvegarde
├── Script/
│   ├── AutoSaveManager.lua      # Gestionnaire automatique (Serveur)
│   ├── SaveTestUI.lua          # Interface de test (Client)
│   └── GameManager_Fixed.lua   # Intégration existante
└── GUIDE_TEST_SAUVEGARDE.md    # Guide de test détaillé
```

## 🚀 Installation Rapide

### 1. Placement des fichiers

```
ServerScriptService/
└── AutoSaveManager.lua

ReplicatedStorage/
└── SaveDataManager.lua

StarterPlayerScripts/
└── SaveTestUI.lua
```

### 2. Configuration Roblox Studio

Dans **Game Settings > Security** :
- ✅ Enable Studio Access to API Services
- ✅ Allow HTTP Requests (si nécessaire)

### 3. Test immédiat

1. Lance le jeu
2. Appuie sur **F8**
3. Clique **"💾 Sauvegarder"**
4. Vérifie les messages de succès

## ⚙️ Configuration

### Paramètres de sauvegarde

```lua
-- Dans SaveDataManager.lua
local CONFIG = {
    MAX_RETRIES = 3,                -- Nombre max de tentatives
    RETRY_DELAY = 2,               -- Délai entre tentatives (secondes)
    AUTO_SAVE_INTERVAL = 300,      -- Sauvegarde auto toutes les 5 minutes
    BACKUP_COUNT = 3,              -- Nombre de copies de sécurité
    MAX_DATA_SIZE = 4000000,       -- Taille max 4MB
    COMPRESSION_ENABLED = true,     -- Compression automatique
}
```

### DataStore personnalisé

```lua
-- Changez le nom si nécessaire
local DATASTORE_NAME = "SweetyScriptPlayerData_v1.3"
local SAVE_VERSION = "1.3.0"
```

## 📋 API du Système

### SaveDataManager (Module)

```lua
local SaveDataManager = require(ReplicatedStorage.SaveDataManager)

-- Sauvegarder un joueur
local success = SaveDataManager.savePlayerData(player)

-- Charger les données d'un joueur
local data = SaveDataManager.loadPlayerData(player)

-- Restaurer les données d'un joueur
local success = SaveDataManager.restorePlayerData(player, data)

-- Restaurer l'inventaire séparément
local success = SaveDataManager.restoreInventory(player, data)

-- Obtenir les statistiques
local stats = SaveDataManager.getPlayerStats(player)
```

### GameManager (Intégration)

```lua
-- Nouvelles fonctions ajoutées à _G.GameManager
_G.GameManager.sauvegarderJoueur(player)  -- Sauvegarde manuelle
_G.GameManager.chargerJoueur(player)      -- Chargement manuel
```

### Événements RemoteEvent

```lua
-- Sauvegarde manuelle (Client → Serveur)
ReplicatedStorage.ManualSaveEvent:FireServer()

-- Statistiques (Client → Serveur)
ReplicatedStorage.SaveStatsEvent:FireServer()
```

## 🎮 Utilisation pour les Joueurs

### Raccourcis clavier
- **F8** : Ouvrir/fermer l'interface de test
- **Ctrl+S** : Sauvegarde rapide

### Interface de test
- **Bouton 💾 Save** (coin haut-droit) : Ouvrir l'interface
- **💾 Sauvegarder** : Force une sauvegarde immédiate
- **📊 Statistiques** : Voir les stats du système
- **🧪 Résumé** : Afficher les données actuelles

## 🔧 Commandes Admin

Dans le chat du jeu :

```
/saveall    - Sauvegarder tous les joueurs connectés
/savestats  - Afficher les statistiques détaillées
```

*Note: Remplacez les UserIDs dans AutoSaveManager.lua par les vôtres*

## 📊 Structure des Données Sauvegardées

```lua
saveData = {
    version = "1.2.0",
    timestamp = 1234567890,
    playerId = 123456789,
    playerName = "Joueur",
    
    -- Économie
    money = 1000,
    platformsUnlocked = 3,
    incubatorsUnlocked = 2,
    merchantLevel = 5,
    
    -- Inventaire sérialisé
    inventory = {
        ["Sucre"] = { quantity = 10, isCandy = false },
        ["BonbonFraise"] = { quantity = 5, isCandy = true }
    },
    
    -- Progression
    candyBag = { ... },
    discoveredRecipes = { ... },
    discoveredIngredients = { ... },
    discoveredSizes = { ... },
    shopUnlocks = { ... },
    
    -- Métadonnées
    tutorialCompleted = true,
    playTime = 3600,
    lastLogin = 1234567890
}
```

## 🐛 Résolution de Problèmes

### Erreurs courantes

| Erreur | Cause | Solution |
|--------|-------|----------|
| `DataStore request was rejected` | DataStores pas activés | Vérifier Game Settings |
| `SaveDataManager non disponible` | Module non chargé | Vérifier placement du fichier |
| `Interface ne s'ouvre pas` | Script mal placé | Placer dans StarterPlayerScripts |
| `Données trop volumineuses` | Limite 4MB dépassée | Activer compression ou réduire données |

### Debug

Activez les messages de debug dans la console :

```lua
-- Messages automatiques dans la console
✅ [SAVE] DataStores initialisés avec succès
💾 [SAVE] Données sauvegardées avec succès pour [Joueur]
📥 [LOAD] Données chargées pour [Joueur]
🔄 [RESTORE] Restauration terminée pour [Joueur]
```

## 📈 Statistiques et Monitoring

Le système fournit des statistiques complètes :

```lua
-- Statistiques globales
stats.global = {
    totalSaves = 150,
    successfulSaves = 148,
    failedSaves = 2,
    totalLoads = 89,
    successfulLoads = 89
}

-- Statistiques par joueur
stats.player = {
    lastSaveTime = 1234567890,
    hasCachedData = true,
    saveVersion = "1.2.0"
}
```

## 🔄 Migration et Versioning

Le système gère automatiquement les versions :

```lua
-- Détection de version dans les données chargées
if loadedData.version ~= SAVE_VERSION then
    -- Logique de migration automatique
    migratePlayerData(loadedData)
end
```

## 🚨 Limites et Considérations

### Limites Roblox DataStore
- **Taille max par clé** : 4MB (géré automatiquement)
- **Requêtes par minute** : Limitées par Roblox (retry automatique)
- **Clés max par DataStore** : Illimitées pratiquement

### Performances
- **Cache intelligent** : Évite les sauvegardes redondantes
- **Compression** : Réduit la taille des données
- **Sauvegardes asynchrones** : N'impactent pas le gameplay

### Sécurité
- **Validation serveur** : Impossible de tricher depuis le client
- **Sérialisation sécurisée** : Protection contre l'injection de code
- **Backup automatique** : Protection contre la corruption

## 📚 Exemples d'Utilisation

### Sauvegarde personnalisée

```lua
-- Ajouter des données personnalisées
function SaveDataManager.saveCustomData(player, customData)
    local saveData = SaveDataManager.loadPlayerData(player) or {}
    saveData.customData = customData
    return SaveDataManager.savePlayerData(player, saveData)
end
```

### Événements personnalisés

```lua
-- Écouter les sauvegardes réussies
local saveSuccessEvent = Instance.new("BindableEvent")
saveSuccessEvent.Event:Connect(function(player)
    print("Sauvegarde réussie pour", player.Name)
end)
```

## 🎉 Conclusion

Ce système de sauvegarde offre :

- ✅ **Simplicité d'utilisation** : Installation et test en 5 minutes
- ✅ **Robustesse** : Gestion d'erreurs complète avec retry
- ✅ **Performance** : Cache intelligent et compression
- ✅ **Sécurité** : Validation serveur et protection contre les exploits
- ✅ **Monitoring** : Statistiques complètes et interface de debug
- ✅ **Évolutivité** : Architecture modulaire et extensible

Votre jeu peut maintenant offrir une expérience fluide où les joueurs ne perdront jamais leur progression ! 🚀

---

**Développé pour SweetyScript** 💜
*Système de sauvegarde v1.3.0 - Avec préservation améliorée des tailles de bonbons*

## 🔄 Changelog v1.3.0
- ✅ **Correction majeure** : Les tailles de bonbons (Tiny, Small, Large, Giant, Colossal, etc.) sont maintenant correctement préservées lors de la sauvegarde/chargement
- ✅ **Optimisation** : Transfert direct des données de taille lors de la restauration
- ✅ **Test** : Ajout d'un script de test automatique pour vérifier la préservation
- ✅ **Compatibilité** : Migration automatique depuis les versions précédentes