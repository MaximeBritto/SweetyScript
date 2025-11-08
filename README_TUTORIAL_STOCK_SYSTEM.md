# 🎓 Système de Stock Tutoriel

## 📋 Description

Ce système ajuste automatiquement le stock d'ingrédients dans la boutique en fonction du statut du tutoriel du joueur.

## ✨ Fonctionnalités

### Pendant le Tutoriel
- **Sucre** : 1 unité disponible (au lieu de 3+)
- **Gélatine** : 1 unité disponible (au lieu de 3+)
- Autres ingrédients : stock normal selon leur rareté

### Après le Tutoriel
- **Sucre** : minimum 3 unités garanties
- **Gélatine** : minimum 3 unités garanties
- Restock automatique à la fin du tutoriel

## 🔧 Implémentation

### Fichiers Modifiés

#### 1. `ReplicatedStorage/StockManager.lua`
- Ajout de la vérification du statut tutoriel dans `initializePlayerStock()`
- Ajout de la vérification du statut tutoriel dans `restockPlayerShop()`
- Exposition de la fonction `StockManager.restockPlayerShop()` pour usage externe

**Code ajouté :**
```lua
-- 🎓 TUTORIEL: Vérifier si le joueur est en tutoriel
local playerObj = Players:GetPlayerByUserId(userId)
local isInTutorial = false
if playerObj then
    local playerData = playerObj:FindFirstChild("PlayerData")
    local tutorialCompleted = playerData and playerData:FindFirstChild("TutorialCompleted")
    isInTutorial = not (tutorialCompleted and tutorialCompleted.Value)
end

-- Garantir minimum 3 pour les ingrédients essentiels (Sucre et Gelatine)
-- SAUF pendant le tutoriel où on met seulement 1
if name == "Sucre" or name == "Gelatine" then
    if isInTutorial then
        targetQuantity = 1 -- Pendant le tutoriel: seulement 1
    else
        targetQuantity = math.max(3, targetQuantity) -- Après le tutoriel: minimum 3
    end
end
```

#### 2. `Script/TutorialManager.lua`
- Ajout d'un restock automatique à la fin du tutoriel dans `completeTutorial()`

**Code ajouté :**
```lua
-- 🛒 RESTOCK: Forcer un restock de la boutique pour passer de 1 à 3 ingrédients
task.delay(0.5, function()
    -- Appeler le StockManager pour restock le joueur
    if _G.StockManager and _G.StockManager.restockPlayerShop then
        _G.StockManager.restockPlayerShop(player.UserId)
        print("🛒 [TUTORIAL] Restock de la boutique après fin du tutoriel pour", player.Name)
    end
end)
```

## 🎮 Comportement en Jeu

### Scénario 1 : Nouveau Joueur
1. Le joueur rejoint le jeu
2. Le tutoriel démarre automatiquement
3. La boutique affiche **1 Sucre** et **1 Gélatine**
4. Le joueur achète les ingrédients pour le tutoriel
5. Le joueur termine le tutoriel
6. **Restock automatique** : la boutique passe à **3 Sucre** et **3 Gélatine** minimum

### Scénario 2 : Joueur Expérimenté
1. Le joueur rejoint le jeu (tutoriel déjà complété)
2. La boutique affiche **3+ Sucre** et **3+ Gélatine** dès le départ
3. Les restocks périodiques maintiennent ce minimum

## 🔍 Détection du Statut Tutoriel

Le système vérifie la présence de `PlayerData.TutorialCompleted` :
- **Absent ou false** → Joueur en tutoriel → Stock limité à 1
- **Present et true** → Tutoriel terminé → Stock minimum de 3

## 📝 Notes Techniques

- Le stock est **personnel par joueur** (système de stock individuel)
- Le restock se fait **0.5 secondes** après la fin du tutoriel
- Le système utilise `_G.StockManager` pour la communication inter-scripts
- Compatible avec le système de sauvegarde existant

## ✅ Avantages

1. **Expérience tutoriel améliorée** : Le joueur n'est pas submergé d'ingrédients
2. **Progression naturelle** : Le stock augmente après avoir appris les bases
3. **Automatique** : Aucune intervention manuelle nécessaire
4. **Rétrocompatible** : Les joueurs existants ne sont pas affectés

## 🐛 Dépannage

Si le stock ne change pas après le tutoriel :
1. Vérifier que `TutorialCompleted` est bien créé dans `PlayerData`
2. Vérifier les logs console pour `[TUTORIAL] Restock de la boutique`
3. Vérifier que `_G.StockManager` est bien exposé (log au démarrage)

---

**Date de création** : 8 novembre 2025  
**Version** : 1.0
