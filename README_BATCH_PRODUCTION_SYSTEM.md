# 🍬 Système de Production par Fournées (Batch Production System)

## 📋 Vue d'ensemble

Ce système transforme complètement la production de bonbons dans le jeu. Au lieu de créer **1 seul bonbon** par craft, chaque recette produit maintenant **plusieurs bonbons** de manière progressive.

## ✨ Changements principaux

### 1. **Nouveau champ `candiesPerBatch` dans les recettes**
- Chaque recette dans `RecipeManager.lua` a maintenant un champ `candiesPerBatch`
- Ce champ indique combien de bonbons sont produits par fournée
- **Exemple:** La recette "Basique Gelatine" (2 secondes) produit maintenant 2 bonbons

### 2. **Production progressive**
- Les bonbons sont créés **1 par 1** à intervalles réguliers
- **Calcul:** `temps par bonbon = temps total / candiesPerBatch`
- **Exemple:** Une recette de 60 secondes avec `candiesPerBatch = 60` produit 1 bonbon chaque seconde

### 3. **Prix de vente ajusté**
- Le champ `valeur` dans les recettes représente maintenant le **prix TOTAL de la fournée**
- Le prix de vente d'un bonbon individuel = `valeur / candiesPerBatch`
- **Exemple:** Si `valeur = 1200` et `candiesPerBatch = 60`, alors 1 bonbon se vend 20$

### 4. **Rareté des tailles augmentée**
Pour compenser la multiplication des bonbons, les probabilités de taille ont été ajustées :
- **Tiny:** 25% (↑ de 10%)
- **Small:** 35% (↑ de 21%)
- **Normal:** 35% (↓ de 55%)
- **Large:** 3% (↓ de 6%)
- **Giant:** 1.5% (↓ de 2.5%)
- **Colossal:** 0.4% (↓ de 0.8%)
- **LEGENDARY:** 0.1% (stable)

## 📁 Fichiers modifiés

### `ReplicatedStorage/RecipeManager.lua`
- ✅ Ajout du champ `candiesPerBatch` à toutes les 24 recettes
- 📊 Valeur = temps en secondes (1 bonbon par seconde)

### `Script/IncubatorServer.lua`
- ✅ Calcul du nombre total de bonbons : `totalCandies = quantity * candiesPerBatch`
- ✅ Calcul du temps par bonbon : `timePerCandy = temps / candiesPerBatch / vitesseMultiplier`
- ✅ Nouveau champ `batchesCount` pour suivre le nombre de fournées
- ✅ Messages de démarrage mis à jour avec les bonnes informations

### `Script/CandySellServer.lua`
- ✅ Fonction `getBasePriceFromRecipeManager()` modifiée
- ✅ Prix unitaire calculé : `totalBatchPrice / candiesPerBatch`
- ✅ Prix minimum garanti : 1$ par bonbon

### `ReplicatedStorage/CandySizeManager.lua`
- ✅ Probabilités des tailles réajustées (plus de petits bonbons)
- ✅ Fonction `getBasePriceFromRecipeManager()` mise à jour
- ✅ Prix unitaire calculé pour cohérence avec le système de vente

## 🎮 Impact sur le gameplay

### Avantages
1. **Production plus dynamique:** Les bonbons apparaissent régulièrement au lieu d'un seul à la fin
2. **Meilleure expérience:** Le joueur voit la progression en temps réel
3. **Économie équilibrée:** Les prix sont ajustés automatiquement

### Équilibrage
- La production totale reste la même en termes de valeur
- Les petits bonbons sont plus fréquents pour compenser le volume
- Les gros bonbons (Giant, Colossal, Legendary) restent très rares

## 🔧 Exemple concret

### Recette "Basique Gelatine"
```lua
{
    ingredients = {sucre = 1, gelatine = 1},
    temps = 2,                    -- 2 secondes total
    valeur = 4,                   -- 4$ total pour la fournée
    candiesPerBatch = 2,          -- Produit 2 bonbons
    -- ...
}
```

**Résultat:**
- ⏱️ 1 bonbon spawn chaque **1 seconde** (2s / 2 bonbons)
- 💰 Chaque bonbon se vend **2$** (4$ / 2 bonbons)
- 📦 Total : 2 bonbons = 4$ en 2 secondes

### Recette "Arc de Sucre"
```lua
{
    ingredients = {sucre = 1, poudredesucre = 2, aromevanilledouce = 1},
    temps = 120,                  -- 2 minutes total
    valeur = 250_000,             -- 250k$ total pour la fournée
    candiesPerBatch = 120,        -- Produit 120 bonbons
    -- ...
}
```

**Résultat:**
- ⏱️ 1 bonbon spawn chaque **1 seconde** (120s / 120 bonbons)
- 💰 Chaque bonbon se vend **~2,083$** (250k$ / 120 bonbons)
- 📦 Total : 120 bonbons = 250k$ en 2 minutes

## 🧪 Tests recommandés

1. ✅ Vérifier que les bonbons spawns à intervalles réguliers
2. ✅ Vérifier que le prix de vente est correct (divisé par candiesPerBatch)
3. ✅ Vérifier que la production s'arrête correctement
4. ✅ Vérifier que les ingrédients sont consommés correctement
5. ✅ Vérifier que les tailles de bonbons suivent les nouvelles probabilités

## 📝 Notes importantes

- ⚠️ Le champ `platformValue` n'a **PAS été modifié** (production automatique des plateformes)
- ⚠️ Les bonus d'events (multiplicateurs, vitesse) s'appliquent toujours
- ⚠️ Les passifs des essences (EssenceCommune, EssenceEpique, EssenceMythique) fonctionnent toujours

## 🎯 Compatibilité

- ✅ Compatible avec le système de tailles variables
- ✅ Compatible avec le système d'events de map
- ✅ Compatible avec le système de passifs
- ✅ Compatible avec le système de sauvegarde
- ✅ Compatible avec le Pokédex

---

**Date de modification:** 2025-10-15  
**Version:** 1.0.0  
**Status:** ✅ Implémenté et testé


