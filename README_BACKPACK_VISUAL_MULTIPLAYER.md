# Système de Sac à Dos Visuel Multijoueur

## 🎒 Problème Résolu

Le sac à dos visuel n'était visible que par le joueur propriétaire. Les autres joueurs ne pouvaient pas voir le sac des autres.

## ✅ Solution Implémentée

Le système a été divisé en deux parties :

### 1. **BackpackVisualServer.lua** (ServerScriptService)
- Crée le modèle 3D du sac pour chaque joueur
- Le sac est **visible par tous les joueurs**
- Gère la taille et les effets visuels (lueur) côté serveur
- Utilise un RemoteEvent pour recevoir les mises à jour du client

### 2. **BackpackVisualClient.lua** (StarterPlayerScripts)
- Crée le BillboardGui (compteur de bonbons) **visible uniquement par le propriétaire**
- Calcule le nombre de bonbons et la rareté moyenne
- Envoie les informations au serveur via RemoteEvent
- Gère les animations du compteur (arc-en-ciel, etc.)

## 🔧 Installation

1. **Placer BackpackVisualServer.lua** dans `ServerScriptService`
2. **Placer BackpackVisualClient.lua** dans `StarterPlayer > StarterPlayerScripts`
3. Les scripts créeront automatiquement le RemoteEvent `UpdateBackpackSize` dans ReplicatedStorage

## 📋 Fonctionnalités

### Visible par tous :
- ✅ Modèle 3D du sac
- ✅ Taille qui change selon le nombre de bonbons
- ✅ Effet de lueur selon la rareté
- ✅ Position ajustée sur le dos

### Visible uniquement par le propriétaire :
- ✅ Compteur de bonbons (BillboardGui)
- ✅ Animation arc-en-ciel à 300 bonbons
- ✅ Changement de couleur selon le nombre

## 🎮 Comportement

- Chaque joueur voit le sac 3D de tous les autres joueurs
- Chaque joueur voit uniquement son propre compteur de bonbons
- Les autres joueurs ne voient pas le compteur sur les sacs des autres (évite le spam visuel)
- Le sac grossit automatiquement et recule sur le dos pour ne pas gêner

## 🔄 Communication Client-Serveur

```lua
-- Client → Serveur
UpdateBackpackSize:FireServer(candyCount, averageRarity)

-- Serveur reçoit et met à jour le sac visible par tous
```

## 📝 Notes Techniques

- Le sac est attaché avec un Motor6D pour un mouvement naturel
- Pas de collision (CanCollide = false)
- Pas d'ancrage (Anchored = false)
- Le BillboardGui est créé côté client pour éviter la réplication inutile
