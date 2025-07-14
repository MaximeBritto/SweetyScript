# 🍬 Guide d'Installation - Jeu Usine à Bonbons V0.2

## 📋 Structure du Projet

Voici où placer chaque script dans Roblox Studio :

### 🔧 Scripts Serveur (ServerScriptService)
- **`GameManager.lua`** → Placez dans `ServerScriptService`
  - Script principal qui gère toutes les données des joueurs
  - Gère la vente, les améliorations et les achats d'ingrédients

### 🎮 Scripts d'Objets (Workspace)
- **`ProductionScript.lua`** → Placez dans `Workspace > MachineDeMelange`
  - N'oubliez pas d'ajouter un `ClickDetector` dans la machine aussi !
- **`VendeurPNJ.lua`** → Placez dans `Workspace > VendeurPNJ`
  - N'oubliez pas d'ajouter un `ClickDetector` dans le PNJ aussi !

### 🖥️ Scripts Interface (StarterGui)
- **`UIManager.lua`** → Placez dans `StarterGui > ScreenGui` (LocalScript)
- **`VenteClientScript.lua`** → Placez dans `StarterGui > ScreenGui > BoutonVendre` (LocalScript)
- **`UpgradeClientScript.lua`** → Placez dans `StarterGui > ScreenGui > BoutonUpgrade` (LocalScript)
- **`MenuAchatClient.lua`** → Placez dans `StarterGui > ScreenGui` (LocalScript)

### 📡 RemoteEvents (ReplicatedStorage)
Créez ces RemoteEvents dans `ReplicatedStorage` :
- `VenteEvent`
- `UpgradeEvent`
- `AchatIngredientEvent` *(NOUVEAU V0.2)*
- `OuvrirMenuEvent` *(NOUVEAU V0.2)*

## 🏗️ Éléments à Créer dans Roblox Studio

### Map (Workspace)
1. **SolUsine** - Part (sol de l'usine)
2. **MachineDeMelange** - Part/Cylindre avec ClickDetector
3. **TableDeVente** - Part (optionnel, pour la déco)
4. **VendeurPNJ** - Part/Model avec ClickDetector *(NOUVEAU V0.2)*

### Interface (StarterGui > ScreenGui)
1. **ArgentLabel** - TextLabel (affiche l'argent)
2. **StockLabel** - TextLabel (affiche les bonbons)
3. **BoutonVendre** - TextButton
4. **BoutonUpgrade** - TextButton
5. **IngredientsLabel** - TextLabel (créé automatiquement par UIManager) *(NOUVEAU V0.2)*

## 🎯 Gameplay V0.2
### Boucle de Jeu Complète :
1. **Cliquez sur le PNJ Vendeur** → Ouvre le menu d'achat d'ingrédients
2. **Achetez des ingrédients** :
   - 🍯 Sucre : 1$
   - 🍯 Sirop : 2$
   - 🍓 Arôme Fruit : 5$
3. **Cliquez sur la machine** → Produit 1 bonbon (nécessite des ingrédients)
4. **Cliquez sur "Vendre"** → Vend tous les bonbons
5. **Cliquez sur "Améliorer"** → Coûte 100$, augmente la valeur des bonbons de 5$

### Nouvelles Fonctionnalités V0.2 :
- **PNJ Vendeur** avec menu d'achat interactif
- **Système d'ingrédients** avec stock limité (20 max)
- **Affichage des ingrédients** en temps réel
- **Production basée sur les ingrédients** (pour l'instant, la machine utilise automatiquement les ingrédients disponibles)

## 🚀 Prochaines Étapes (V0.3+)
- **Recettes spécifiques** (sucre + sirop = bonbon classique, etc.)
- **Valeurs variables** selon les ingrédients utilisés
- **Assistants** pour automatiser la production
- **Upgrades de stockage** d'ingrédients
- **Production offline**

## 🔧 Notes Techniques
- Le joueur commence avec 50$ (au lieu de 0$) pour pouvoir acheter des ingrédients
- L'interface se met à jour automatiquement quand les valeurs changent
- Le menu d'achat a des animations fluides d'ouverture/fermeture
- Tous les achats sont sécurisés côté serveur

Bon développement ! 🎮 