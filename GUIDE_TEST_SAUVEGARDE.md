# Guide de Test du Système de Sauvegarde - SweetyScript

Ce guide t'explique comment tester le système de sauvegarde que nous venons de créer dans Roblox Studio.

## 📋 Fichiers Créés

1. **`ReplicatedStorage/SaveDataManager.lua`** - Module principal de sauvegarde
2. **`Script/AutoSaveManager.lua`** - Script serveur pour sauvegarde automatique
3. **`Script/SaveTestUI.lua`** - Interface de test (LocalScript)
4. **Modifications dans `Script/GameManager_Fixed.lua`** - Intégration du système

## 🛠️ Installation dans Roblox Studio

### Étape 1: Placement des Scripts

1. **SaveDataManager.lua** → `ReplicatedStorage`
2. **AutoSaveManager.lua** → `ServerScriptService`
3. **SaveTestUI.lua** → `StarterPlayer > StarterPlayerScripts`
4. **GameManager_Fixed.lua** → Déjà mis à jour

### Étape 2: Vérification des Modules

Assure-toi que ces modules existent dans `ReplicatedStorage`:
- ✅ `CandyTools`
- ✅ `RecipeManager` 
- ✅ `StockManager`

### Étape 3: Configuration des DataStores

Dans Roblox Studio, va dans **Game Settings > Security** et assure-toi que:
- ✅ **Enable Studio Access to API Services** est coché
- ✅ **Allow HTTP Requests** est coché (si nécessaire)

## 🧪 Tests à Effectuer

### Test 1: Vérification du Système

1. **Lance le jeu en Studio**
2. **Vérifie la console** pour ces messages:
   ```
   ✅ [SAVE] DataStores initialisés avec succès
   🔄 [AUTOSAVE] AutoSaveManager initialisé
   ✅ [SAVE TEST] Interface de test de sauvegarde prête
   ```

### Test 2: Interface de Test

1. **Appuie sur F8** ou clique sur le bouton **💾 Save** en haut à droite
2. **L'interface devrait s'ouvrir** avec:
   - Résumé de tes données actuelles
   - Boutons "Sauvegarder" et "Statistiques"

### Test 3: Sauvegarde Manuelle

1. **Clique sur "💾 Sauvegarder"**
2. **Regarde la console** pour:
   ```
   💾 [SAVE] Données sauvegardées avec succès pour [TonNom]
   ```
3. **Dans l'interface**, tu devrais voir "✅ Sauvegarde réussie!"

### Test 4: Test de Chargement

1. **Sauvegarde d'abord** (Test 3)
2. **Arrête le jeu**
3. **Relance le jeu**
4. **Vérifie la console** pour:
   ```
   📥 [LOAD] Données chargées pour [TonNom]
   🔄 [RESTORE] Restauration des données pour [TonNom]
   ```

### Test 5: Test avec Données

1. **Achète quelques ingrédients** (si tu as un système de shop)
2. **Gagne de l'argent**
3. **Change ton niveau marchand** (si possible)
4. **Sauvegarde** (F8 → Sauvegarder)
5. **Arrête et relance le jeu**
6. **Vérifie que tout est restauré**

### Test 6: Statistiques

1. **Ouvre l'interface** (F8)
2. **Clique sur "📊 Statistiques"**
3. **Tu devrais voir**:
   - Nombre de sauvegardes effectuées
   - Dernière sauvegarde
   - Joueurs actifs

## 🐛 Résolution de Problèmes

### ❌ "DataStore request was rejected"

**Cause**: DataStores pas activés ou limites atteintes
**Solution**: 
- Vérifie Game Settings > Security
- Attends quelques minutes (limites de rate)

### ❌ "SaveDataManager non disponible"

**Cause**: Module non chargé correctement
**Solution**:
- Vérifie que SaveDataManager.lua est dans ReplicatedStorage
- Regarde s'il y a des erreurs de syntaxe

### ❌ Interface ne s'ouvre pas

**Cause**: Script client mal placé
**Solution**:
- Place SaveTestUI.lua dans StarterPlayerScripts
- Vérifie qu'il n'y a pas d'erreurs dans la console

### ❌ Sauvegarde échoue

**Cause**: Données trop volumineuses ou erreur de sérialisation
**Solution**:
- Vérifie la console pour des erreurs détaillées
- Les données sont limitées à 4MB par défaut

## 🎮 Commandes de Test Avancé

Si tu es administrateur, tu peux utiliser ces commandes dans le chat:

- **`/saveall`** - Force la sauvegarde de tous les joueurs
- **`/savestats`** - Affiche les statistiques détaillées dans la console

## 📊 Données Sauvegardées

Le système sauvegarde automatiquement:

### 💰 Données Économiques
- Argent du joueur
- Niveau marchand
- Déblocages du shop

### 📦 Inventaire
- Tous les outils dans le Backpack
- Quantités (attribut Count)
- Types de bonbons et ingrédients
- Outil équipé

### 🍬 Progression
- Sac à bonbons (SacBonbons)
- Recettes découvertes
- Ingrédients découverts
- Tailles découvertes (Pokédex)

### 🏭 Déblocages
- Plateformes débloquées
- Incubateurs débloqués
- Statut du tutoriel

## ⏰ Sauvegarde Automatique

Le système sauvegarde automatiquement:
- ✅ **Toutes les 5 minutes** (si données changées)
- ✅ **Quand un joueur quitte**
- ✅ **À l'arrêt du serveur**

## 🔧 Personnalisation

Tu peux modifier ces paramètres dans `SaveDataManager.lua`:

```lua
local CONFIG = {
    MAX_RETRIES = 3,           -- Tentatives de sauvegarde
    RETRY_DELAY = 2,           -- Délai entre tentatives
    AUTO_SAVE_INTERVAL = 300,  -- 5 minutes
    MAX_DATA_SIZE = 4000000,   -- 4MB max
}
```

## 📝 Notes Importantes

1. **En Studio**, les DataStores sont simulés - les données persistent entre les sessions de test
2. **En production**, les données sont sauvegardées sur les serveurs Roblox
3. **Les sauvegardes sont sécurisées** - validation côté serveur uniquement
4. **Compression automatique** des données volumineuses
5. **Système de backup** avec plusieurs copies de sécurité

## ✅ Checklist de Test

Coche ces éléments pour confirmer que tout fonctionne:

- [ ] Interface de test s'ouvre (F8)
- [ ] Sauvegarde manuelle fonctionne
- [ ] Données se chargent au démarrage
- [ ] Inventaire est restauré correctement
- [ ] Argent est restauré correctement
- [ ] Statistiques s'affichent
- [ ] Pas d'erreurs dans la console
- [ ] Sauvegarde automatique fonctionne (attendre 5min)

## 🎉 Félicitations !

Si tous les tests passent, ton système de sauvegarde est opérationnel ! 

Tes joueurs pourront maintenant:
- 💾 Garder leur progression entre les sessions
- 🔄 Récupérer leurs données automatiquement
- 🛡️ Bénéficier d'un système sécurisé et robuste

---

**Bon test ! 🚀**