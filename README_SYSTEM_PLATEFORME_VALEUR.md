# 🏭 Système de Valeur Dynamique des Plateformes

## 📋 Vue d'ensemble

Le système de génération d'argent des plateformes est maintenant **dynamique** et basé sur :
1. Le type de bonbon placé sur la plateforme
2. La taille du bonbon (Minuscule, Petit, Normal, Grand, Géant, Colossal, Légendaire)

## 💰 Valeurs de Base par Bonbon (platformValue)

### Bonbons Common
- **Basique Gelatine** : 10 $/cycle
- **Caramel** : 8 $/cycle
- **Sucre Citron** : 6 $/cycle
- **Douceur Vanille** : 6 $/cycle
- **Arc de Sucre** : 6 $/cycle
- **Tropical Doux** : 6 $/cycle
- **Fête Foraine** : 6 $/cycle

### Bonbons Rare
- **FramboiseLélé** : 12 $/cycle
- **CitronCaramelDoré** : 20 $/cycle
- **Vanille Noire Croquante** : 10 $/cycle
- **Fraise Coulante** : 18 $/cycle
- **VanilleFruité** : 14 $/cycle
- **ForêtEnchantée** : 11 $/cycle
- **CeriseRoyale** : 20 $/cycle

### Bonbons Epic
- **Clown sucette** : 25 $/cycle
- **Praline Exotique** : 30 $/cycle
- **Gomme Magique** : 30 $/cycle
- **Acidulé Royal** : 35 $/cycle
- **Mangue Passion** : 25 $/cycle
- **MieletFruit** : 25 $/cycle

### Bonbons Legendary
- **ArcEnCiel** : 50 $/cycle
- **CitronGivré** : 45 $/cycle
- **Fleur Royale** : 45 $/cycle
- **Soleil d'Été** : 60 $/cycle

### Bonbons Mythic
- **NectarAbsolu** : 80 $/cycle
- **Néant Céleste** : 70 $/cycle
- **MythicSuprême** : 100 $/cycle

## 📏 Multiplicateurs de Taille

Le système applique un multiplicateur selon la taille du bonbon :

| Taille | Multiplicateur | Effet |
|--------|---------------|-------|
| **Minuscule** (Tiny) | 0.5x | 50% de la valeur de base |
| **Petit** (Small) | 0.75x | 75% de la valeur de base |
| **Normal** | 1.0x | 100% de la valeur de base (standard) |
| **Grand** (Large) | 1.25x | 125% de la valeur de base |
| **Géant** (Giant) | 1.5x | 150% de la valeur de base |
| **Colossal** | 2.0x | 200% de la valeur de base |
| **Légendaire** (LEGENDARY) | 3.0x | 300% de la valeur de base |

## 🧮 Exemples de Calcul

### Exemple 1 : Bonbon Basique Gelatine
- **Valeur de base** : 10 $/cycle
- **Taille Normal** (1.0x) : 10 $ par cycle
- **Taille Petit** (0.75x) : 7 $ par cycle
- **Taille Minuscule** (0.5x) : 5 $ par cycle
- **Taille Grand** (1.25x) : 12 $ par cycle
- **Taille Géant** (1.5x) : 15 $ par cycle
- **Taille Colossal** (2.0x) : 20 $ par cycle
- **Taille Légendaire** (3.0x) : 30 $ par cycle

### Exemple 2 : Bonbon MythicSuprême
- **Valeur de base** : 100 $/cycle
- **Taille Normal** (1.0x) : 100 $ par cycle
- **Taille Minuscule** (0.5x) : 50 $ par cycle
- **Taille Grand** (1.25x) : 125 $ par cycle
- **Taille Géant** (1.5x) : 150 $ par cycle
- **Taille Colossal** (2.0x) : 200 $ par cycle
- **Taille Légendaire** (3.0x) : 300 $ par cycle

### Exemple 3 : ArcEnCiel Légendaire (meilleur combo!)
- **Valeur de base** : 50 $/cycle
- **Taille Légendaire** (3.0x) : **150 $ par cycle** 🌟

## ⚙️ Formule Complète

```lua
Montant final = (platformValue × multiplicateur de taille) × stackSize × gainMultiplier
```

Où :
- `platformValue` = Valeur de base du bonbon (définie dans RecipeManager)
- `multiplicateur de taille` = Multiplicateur selon la rareté de taille du bonbon
- `stackSize` = Taille du stack (nombre de bonbons empilés)
- `gainMultiplier` = Multiplicateur de gain additionnel (boosts, etc.)

## 🔧 Modifications Techniques

### Fichiers modifiés

1. **ReplicatedStorage/RecipeManager.lua**
   - Ajout du champ `platformValue` à toutes les recettes
   - Ajout de `RecipeManager.SizeMultipliers` (table des multiplicateurs)
   - Ajout de `RecipeManager.calculatePlatformValue(candyName, sizeData)` (fonction de calcul)
   - Ajout de `RecipeManager.getBasePlatformValue(candyName)` (récupère la valeur de base)

2. **Script/CandyPlatforms.lua**
   - Import de `RecipeManager`
   - Modification de `generateMoney()` pour utiliser le calcul dynamique
   - Modification de `applyOfflineEarningsForPlayer()` pour utiliser le calcul dynamique
   - Ajout de logs pour le debugging

## 🎯 Avantages du Nouveau Système

1. **Plus de stratégie** : Les joueurs doivent choisir entre bonbons rares et bonbons de grande taille
2. **Récompense la chance** : Les bonbons légendaires (taille) génèrent beaucoup plus d'argent
3. **Équilibrage facile** : Modifier les valeurs dans RecipeManager suffit
4. **Extensible** : Facile d'ajouter de nouveaux bonbons avec leurs valeurs

## 🐛 Debug

Le système affiche maintenant des logs détaillés :
```
💰 Génération argent: [Nom bonbon] | Base: [valeur] | Taille: [rareté] | Stack: [nombre] | Montant final: [montant]
```

Pour les gains hors-ligne :
```
💸 Gains hors-ligne: [Nom bonbon] | Cycles: [nombre] | Par cycle: [valeur] | Total: [montant]
```

## 📝 Notes

- Les valeurs de base ont été équilibrées selon la rareté des bonbons
- Un bonbon Mythic + taille Légendaire peut générer jusqu'à **300 $/cycle** !
- Le système reste compatible avec les multiplicateurs existants (gainMultiplier)
- Les gains hors-ligne utilisent le même système de calcul

