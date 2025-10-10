# 💰 Système de Revente d'Ingrédients

## 📋 Description

Ce système permet aux joueurs de revendre les ingrédients dont ils n'ont plus besoin depuis le shop. Les ingrédients sont revendus à **50% de leur prix d'achat**.

## 🎮 Comment utiliser

### Pour les joueurs :

1. **Ouvrir le shop** en cliquant sur le vendeur PNJ
2. **Cliquer sur l'onglet "💰 VENDRE"** en haut du menu
3. **Voir la liste des ingrédients** disponibles dans votre inventaire
4. **Choisir la quantité à vendre** :
   - Bouton **"VENDRE 1"** (ou "x1" sur mobile) : vend 1 unité
   - Bouton **"VENDRE TOUT"** (ou "TOUT" sur mobile) : vend toute la quantité possédée
5. **Recevoir l'argent instantanément** à 50% du prix d'achat

### Informations affichées :

- **Nom de l'ingrédient** avec son icône 3D
- **Quantité possédée** (ex: "Possédé: x15")
- **Prix de revente par unité** (ex: "Revente: 2$ /unité")
- **Rareté de l'ingrédient** (Common, Rare, Epic, Legendary, Mythic)

## 🔧 Fonctionnalités techniques

### Côté Client (`MenuAchatClient.lua`)

- **Système d'onglets** : 
  - Onglet "🛒 ACHETER" : shop classique
  - Onglet "💰 VENDRE" : revente d'ingrédients
- **Fonction `getPlayerIngredients()`** : récupère les ingrédients du backpack
- **Fonction `createSellIngredientSlot()`** : crée les slots de vente avec viewport 3D
- **Fonction `buildSellSlots()`** : construit la liste des ingrédients à vendre
- **Interface responsive** : s'adapte automatiquement aux écrans mobile et desktop

### Côté Serveur (`GameManager_Fixed.lua`)

- **RemoteEvent `VendreIngredientEvent`** : gère les transactions de revente
- **Fonction `vendreIngredient(player, ingredientName, quantity)`** :
  1. Vérifie que l'ingrédient existe dans le backpack
  2. Vérifie la quantité disponible
  3. Calcule le prix de revente (50% du prix d'achat)
  4. Retire l'ingrédient du backpack
  5. Ajoute l'argent au joueur
  6. Remet le stock dans la boutique (jusqu'au maximum)
  7. Force la synchronisation des leaderstats

### Prix de revente

```lua
local RESELL_PERCENTAGE = 0.5  -- 50% du prix d'achat
local prixRevente = math.floor(ingredientData.prix * qty * RESELL_PERCENTAGE)
```

**Exemples :**
- Sucre (1$) → revente à 0$ (arrondi) ⚠️ Pas rentable
- Gelatine (1$) → revente à 0$ (arrondi) ⚠️ Pas rentable  
- Sirop (3$) → revente à 1$ par unité
- Fraise (8$) → revente à 4$ par unité
- Chocolat (12$) → revente à 6$ par unité
- Flamme Sucrée (28$) → revente à 14$ par unité
- Larme de Licorne (30$) → revente à 15$ par unité

## 🎨 Interface utilisateur

### Onglets :

- **Onglet ACHETER (actif)** : fond vert (RGB 85, 170, 85)
- **Onglet VENDRE (inactif)** : fond gris (RGB 100, 100, 100)
- **Onglet VENDRE (actif)** : fond orange (RGB 200, 100, 50)

### Slots de vente :

- **Fond** : marron clair (RGB 139, 99, 58)
- **Viewport 3D** : affiche le modèle de l'ingrédient
- **Label de quantité** : jaune pâle (RGB 255, 240, 200)
- **Label de prix** : doré (RGB 255, 215, 100)
- **Boutons de vente** : orange (RGB 200, 100, 50 et 170, 85, 40)

### Message si inventaire vide :

```
Aucun ingrédient à vendre
Achetez des ingrédients d'abord !
```

## 🔄 Synchronisation

Le système force la synchronisation des `leaderstats.Argent` après chaque transaction pour garantir que l'affichage est à jour immédiatement.

## ⚠️ Sécurité

- Vérification côté serveur de la quantité disponible
- Impossibilité de vendre des ingrédients non possédés
- Impossible de vendre des bonbons (filtre `IsCandy = false`)
- Le stock de la boutique est limité au maximum défini (`quantiteMax`)

## 📱 Responsive Design

Le système s'adapte automatiquement :

- **Mobile** : textes courts ("TOUT", "x1"), interface compacte
- **Desktop** : textes complets ("VENDRE TOUT", "VENDRE 1"), interface spacieuse

## 🐛 Dépannage

**Problème : Les ingrédients n'apparaissent pas dans l'onglet VENDRE**

- Vérifiez que vous possédez bien des ingrédients dans votre backpack
- Assurez-vous que les outils ont l'attribut `BaseName` correctement défini
- Vérifiez que les outils n'ont pas l'attribut `IsCandy = true`

**Problème : L'argent n'est pas crédité**

- Vérifiez les logs serveur pour voir les messages `[REVENTE]`
- Assurez-vous que `leaderstats.Argent` existe pour le joueur
- Vérifiez que `PlayerData.Argent` est synchronisé

## 📊 Logs de débogage

Le système affiche des logs détaillés côté serveur :

```
🔄 [REVENTE] Tentative: PlayerName veut vendre 5 x Sucre
💰 [REVENTE] + 2$ pour PlayerName
📦 [REVENTE] Stock de Sucre augmenté: 45 → 50
🔄 SYNC FORCÉ: leaderstats.Argent = 102
```

## ✅ Installation

Les fichiers modifiés :

1. **Script/GameManager_Fixed.lua** : logique serveur de revente
2. **Script/MenuAchatClient.lua** : interface d'onglets et de vente

Aucune configuration supplémentaire n'est nécessaire ! Le système est prêt à l'emploi.

---

**Version** : 1.0  
**Date** : 2025-01-07  
**Compatibilité** : Système de shop existant avec RecipeManager












