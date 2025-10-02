# 🎒 Système de Drag & Drop pour l'Inventaire

## 📋 Vue d'ensemble

Le système d'inventaire a été amélioré avec un système complet de **drag and drop**, **division de stacks** et **gestion avancée des items**, inspiré du système Minecraft et de l'inventaire de l'incubateur.

## ✨ Nouvelles fonctionnalités

### 1. **Drag and Drop**
- Cliquez sur un item dans l'inventaire pour le prendre en main
- L'item suit le curseur avec un affichage 3D
- Cliquez sur un slot de la hotbar pour y placer l'item
- Support mobile et tactile

### 2. **Modificateurs clavier**

#### **Clic Gauche (souris)**
- **Clic simple** : Prendre tout le stack / Placer tout le stack
- **CTRL + Clic** : Ouvre un sélecteur de quantité (slider)
- **SHIFT + Clic** : Prendre/placer la moitié du stack

#### **Clic Droit (souris)**
- **Clic droit** : Prendre/placer 1 item à la fois

### 3. **Remplacement et Swap**
- Cliquer sur un slot occupé avec un item en main **échange** les items
- Drag depuis un slot de la hotbar vers un autre slot = swap automatique

### 4. **Annulation**
- **Touche Escape** : Annule le drag en cours et repose l'item
- **Clic dans le vide** : Relâche l'item (retour dans l'inventaire)

## 🎮 Guide d'utilisation

### Depuis l'inventaire complet (TAB)

1. **Prendre un item** :
   - `Clic gauche` : Prendre tout
   - `CTRL + Clic` : Choisir la quantité
   - `SHIFT + Clic` : Prendre la moitié
   - `Clic droit` : Prendre 1

2. **Placer dans la hotbar** :
   - Cliquer sur le slot désiré (avec modificateurs si besoin)

### Depuis la hotbar

1. **Prendre depuis un slot** :
   - `CTRL/SHIFT + Clic` sur le slot
   - Ou `Clic droit` pour prendre 1

2. **Déplacer entre slots** :
   - Prendre l'item d'un slot
   - Cliquer sur un autre slot pour swap/placer

## 🔧 Implémentation technique

### Nouvelles variables globales
```lua
local draggedItem = nil  -- {tool = Tool, sourceSlot = number, quantity = number}
local dragFrame = nil    -- Frame qui suit le curseur
local cursorFollowConnection = nil  -- Connexion pour le suivi curseur
local quantitySelectorOverlay = nil -- Overlay du sélecteur de quantité
```

### Fonctions principales

#### `pickupItemFromTool(tool, quantityToTake)`
Prend un item depuis l'inventaire complet.

#### `pickupItemFromSlot(slotNumber, quantityToTake)`
Prend un item depuis un slot de la hotbar.

#### `placeItemInHotbarSlot(slotNumber, placeAll, quantityOverride)`
Place un item dans un slot de la hotbar avec gestion du remplacement.

#### `showQuantitySelector(tool, maxQuantity, onConfirm)`
Affiche un overlay avec slider pour choisir la quantité.

#### `createCursorItem(tool, quantity)`
Crée le frame 3D qui suit le curseur.

#### `startCursorFollow()` / `stopCursorFollow()`
Gère le suivi du curseur (souris + tactile).

## 🎨 Interface utilisateur

### Sélecteur de quantité
- Overlay semi-transparent avec fond sombre
- Slider horizontal avec bouton glissant
- Affichage de la quantité sélectionnée (X / MAX)
- Boutons "Valider" et "Annuler"
- ZIndex élevé (4500+) pour passer au-dessus de tout

### Item en main (curseur)
- Frame de 50-60px avec modèle 3D
- Bordure dorée pour indiquer qu'il est en main
- Label de quantité dans le coin
- ZIndex très élevé (5000+)
- Support responsive (taille adaptée mobile/desktop)

## 📱 Compatibilité

- ✅ **PC** : Souris + Clavier complet
- ✅ **Mobile** : Tactile + Position fixe pour l'item en main
- ✅ **Tablette** : Support hybride
- ✅ **Responsive** : Tailles adaptées selon la plateforme

## 🔄 Différences avec le système précédent

| Avant | Après |
|-------|-------|
| Clic = Équiper/Déséquiper | Clic = Drag and Drop |
| Pas de division de stacks | Division avec CTRL/SHIFT |
| Pas de remplacement | Swap automatique |
| Pas de sélecteur de quantité | Slider de quantité |
| Pas d'annulation | Escape ou clic vide |

## ⚙️ Configuration

Le système utilise les helpers suivants :
- `isShiftDown()` : Détecte Shift gauche/droit
- `isCtrlDown()` : Détecte Ctrl gauche/droit
- `getToolQuantity(tool)` : Récupère la quantité d'un tool

## 🐛 Débogage

Des messages de debug sont affichés dans la console :
- 🎯 Pickup tool
- 🔍 Quantité disponible
- ✅ Item pris en main
- 🔁 Remplacement du slot
- 🚫 Drag annulé

## 📝 Notes importantes

1. **Les tools équipés** sont toujours visibles dans la hotbar
2. **Les stacks** sont gérés via l'attribut `Count` du tool
3. **Le système ne duplique pas** les items (gestion stricte des quantités)
4. **Les modificateurs** fonctionnent sur PC uniquement (mobile = toucher simple)
5. **L'inventaire complet** (TAB) reste synchronisé en temps réel

## 🎯 Prochaines améliorations possibles

- [ ] Drag entre l'inventaire et des containers externes
- [ ] Raccourcis clavier pour déplacer rapidement (CTRL+1 = placer dans slot 1)
- [ ] Animation de drop pour les items relâchés
- [ ] Son de clic lors du drag/drop
- [ ] Vibration tactile sur mobile lors du pickup

---

**Fichier modifié** : `Script/CustomBackpack.lua`
**Date** : Octobre 2025
**Version** : 2.0 - Drag & Drop System

