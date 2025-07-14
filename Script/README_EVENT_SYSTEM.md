# 🌪️ Système d'Events Map - Guide d'Installation et d'Utilisation

## 📋 Vue d'ensemble

Le système d'events map ajoute des événements aléatoires sur chaque île qui peuvent affecter la production d'incubateurs :

- **🍬 Tempête de Bonbons** : Triple la production de bonbons (x3)
- **🌈 Pluie d'Ingrédients Rares** : Augmente la rareté des bonbons produits
- **⚡ Boost de Vitesse** : Production 2x plus rapide
- **💎 Bénédiction Légendaire** : Tous les bonbons deviennent légendaires (très rare)

## 🚀 Installation

### 1. Scripts créés/modifiés :

#### **Nouveaux scripts :**
- `Script/EventMapManager.lua` (SERVEUR) - Gestionnaire principal des events
- `Script/EventMapClient.lua` (CLIENT) - Effets visuels et notifications

#### **Scripts modifiés :**
- `Script/CreateRemoteEvents.lua` - Ajout des nouveaux RemoteEvents
- `Script/IncubatorServer.lua` - Intégration des bonus d'events
- `Script/IslandManager.lua` - Support pour les events par île

### 2. RemoteEvents ajoutés :
- `EventNotificationRemote` - Notifications aux joueurs
- `EventVisualUpdateRemote` - Effets visuels
- `GetEventDataRemote` - Communication serveur/client

## ⚙️ Configuration

### Fréquence des events (dans EventMapManager.lua) :
```lua
EVENT_CONFIG = {
    CHECK_INTERVAL = 30,        -- Vérification toutes les 30 secondes
    EVENT_SPAWN_CHANCE = 0.05,  -- 5% de chance par vérification par île
}
```

### Types d'events et probabilités :
- **Tempête de Bonbons** : 40% (plus commun)
- **Pluie d'Ingrédients** : 25%
- **Boost de Vitesse** : 30%
- **Event Légendaire** : 5% (très rare)

## 🎮 Utilisation

### Pour les joueurs :
1. Les events apparaissent aléatoirement sur les îles
2. Un nuage coloré apparaît au-dessus de l'île avec particules
3. Une notification s'affiche en haut à droite
4. Les effets s'appliquent automatiquement à tous les incubateurs de l'île

### Effets par type d'event :

#### 🍬 **Tempête de Bonbons**
- **Effet** : x3 bonbons produits
- **Durée** : 3-5 minutes
- **Visuel** : Nuage doré avec particules scintillantes

#### 🌈 **Pluie d'Ingrédients Rares** 
- **Effet** : Bonbons gagnent 1 niveau de rareté
- **Durée** : 2-4 minutes  
- **Visuel** : Nuage vert avec particules de feu

#### ⚡ **Boost de Vitesse**
- **Effet** : Production 2x plus rapide
- **Durée** : 1.5-3 minutes
- **Visuel** : Nuage bleu avec éclairs

#### 💎 **Bénédiction Légendaire**
- **Effet** : Tous les bonbons deviennent Légendaires
- **Durée** : 1-2 minutes
- **Visuel** : Nuage violet avec étoiles

## 🧪 Test et Debug

### Commandes de test (côté serveur) :
```lua
-- Forcer un event sur l'île 1
if _G.EventMapManager then
    _G.EventMapManager.forceEvent(1, "TempeteBonbons")
end

-- Vérifier l'event actif sur une île
local activeEvent = _G.EventMapManager.getActiveEventForIsland(1)
print(activeEvent)
```

### Logs à surveiller :
- `🌪️ Event démarré sur l'île X` - Event commence
- `🌪️ Event actif sur l'île X: xY bonbons` - Bonus appliqué
- `🌪️ Event terminé sur l'île X` - Event fini

### Régler la fréquence pour les tests :
Dans `EventMapManager.lua`, ligne ~14 :
```lua
EVENT_SPAWN_CHANCE = 0.5, -- 50% pour tester plus facilement
CHECK_INTERVAL = 10,      -- Vérifier toutes les 10 secondes
```

## 🔧 Dépannage

### Problèmes courants :

1. **Events ne se déclenchent pas :**
   - Vérifier que `EventMapManager.lua` est dans `ServerScriptService`
   - Vérifier les logs : `🌪️ EventMapManager initialisé`

2. **Pas d'effets visuels :**
   - Placer `EventMapClient.lua` dans `StarterPlayer > StarterPlayerScripts`
   - Vérifier les RemoteEvents créés

3. **Bonus ne s'appliquent pas :**
   - Vérifier que `IncubatorServer.lua` a été modifié
   - Contrôler les logs `🌪️ Event actif sur l'île`

### Reset du système :
```lua
-- Côté serveur, nettoyer tous les events
_G.EventMapManager = nil
-- Puis redémarrer le serveur
```

## 📊 Statistiques d'events

Le système track automatiquement :
- Nombre d'events par île
- Types d'events les plus fréquents  
- Bonus de production générés

## 🎨 Personnalisation

### Ajouter un nouvel event :
1. Ouvrir `EventMapManager.lua`
2. Ajouter dans `EVENT_TYPES` :
```lua
["MonNouvelEvent"] = {
    nom = "🔥 Mon Event",
    description = "Description de l'effet",
    duree = {120, 180},
    multiplicateur = 2, -- ou autres propriétés
    rarete = 20,
    couleur = Color3.fromRGB(255, 0, 0),
    effets = {"effet_personnalise"}
}
```
3. Ajouter la logique dans `applyEventBonuses()` de `IncubatorServer.lua`
4. Ajouter les effets visuels dans `EventMapClient.lua`

---

**✅ Le système est maintenant opérationnel ! Les events vont apparaître aléatoirement sur les îles et affecter la production.** 