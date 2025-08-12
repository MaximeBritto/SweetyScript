# 🏭 SYSTÈME DE PLATEFORMES DE PRODUCTION

## 📋 Aperçu du système

Un système complet de plateformes de production automatique qui permet aux joueurs de :

- ✨ Placer des bonbons sur des plateformes magiques
- 🔄 Générer automatiquement de l'argent avec ces bonbons
- 💰 Ramasser l'argent en marchant dessus
- 🎨 Profiter d'effets visuels immersifs (lévitation, rotation, particules)

## 📁 Fichiers du système

### Scripts côté serveur
- **`ProductionPlatformServer.lua`** : Gestionnaire principal des plateformes
  - Placement/retrait de bonbons
  - Génération automatique d'argent
  - Détection de ramassage par proximité
  - Effets visuels et animations

### Scripts côté client
- **`ProductionPlatformClient.lua`** : Interface utilisateur
  - Menu de gestion des plateformes (6 max par joueur)
  - Interface responsive mobile/desktop
  - Notifications système
  - Raccourci clavier (P)

### Configuration
- **`ProductionPlatformEvents.lua`** : Gestionnaire d'événements centralisé
  - RemoteEvents pour communication client-serveur
  - Configuration automatique des événements

### Interface intégrée
- **`CustomBackpack.lua`** : Bouton plateformes ajouté
  - Bouton 🏭 à gauche de la hotbar
  - Accès rapide au menu des plateformes

## 🎮 Utilisation pour les joueurs

### Raccourcis
- **Touche P** : Ouvrir/fermer le menu des plateformes
- **Bouton 🏭** : Accès rapide depuis la hotbar

### Étapes d'utilisation
1. **Équiper un bonbon** dans votre main
2. **Ouvrir le menu** avec P ou le bouton 🏭
3. **Cliquer "Placer"** sur une plateforme libre
4. **Le bonbon lévite** et commence à produire de l'argent
5. **Marcher près des pièces** pour les ramasser automatiquement

## ⚙️ Configuration technique

### Variables de production
```lua
PRODUCTION_CONFIG = {
    GENERATION_INTERVAL = 5,      -- Génère argent toutes les 5 secondes
    BASE_GENERATION = 10,         -- Argent de base généré
    PICKUP_DISTANCE = 8,          -- Distance pour ramasser l'argent
    MAX_PLATFORMS = 6,            -- Maximum plateformes par joueur
    LEVITATION_HEIGHT = 3,        -- Hauteur de lévitation du bonbon
    ROTATION_SPEED = 45,          -- Degrés par seconde de rotation
}
```

### Calcul des gains
- **Argent généré** = `BASE_GENERATION × StackSize du bonbon`
- **Exemple** : Bonbon x5 = 10 × 5 = 50$ toutes les 5 secondes

## 🎨 Effets visuels

### Plateformes
- **Matériau** : Neon brillant bleu
- **Forme** : Cylindre horizontal (dalle)
- **Éclairage** : PointLight dynamique
- **Zone détection** : Cylindre translucide vert

### Bonbons en lévitation
- **Position** : 3 studs au-dessus de la plateforme
- **Animation** : Rotation continue (45°/sec)
- **Couleurs** : Selon le type de bonbon
- **Effets** : Particules et éclairage coloré

### Argent généré
- **Apparence** : Sphères dorées brillantes
- **Animation** : Bobbing vertical automatique
- **UI** : Affichage du montant en 3D
- **Ramassage** : Effet de vol vers le joueur

## 🔧 Intégration système

### Communication serveur-client
- **PlaceCandyOnPlatformEvent** : Placement de bonbons
- **PickupPlatformMoneyEvent** : Ramassage d'argent
- **RemoveCandyFromPlatformEvent** : Retrait de bonbons

### Synchronisation argent
- Utilise `_G.GameManager.ajouterArgent()` si disponible
- Fallback vers `PlayerData.Argent.Value` direct
- Synchronisation leaderstats automatique

### Nettoyage automatique
- **Déconnexion joueur** : Destruction plateformes et argent
- **Timeout argent** : 30 secondes puis suppression auto
- **Gestion mémoire** : Tables nettoyées régulièrement

## 📱 Responsive design

### Mobile
- **Menu** : Interface compacte adaptée
- **Boutons** : Taille tactile optimisée
- **Position** : Évite conflits avec interface de jeu

### Desktop
- **Menu** : Interface complète avec détails
- **Raccourcis** : Support clavier complet
- **Affichage** : Informations étendues

## 🛡️ Sécurité

### Validation côté serveur
- **Bonbons seulement** : Vérification attribut `IsCandy`
- **Propriété joueur** : Vérification possession du bonbon
- **Limites** : Maximum 6 plateformes par joueur
- **Anti-spam** : Cooldowns et vérifications

### Protection données
- **Isolation joueur** : Plateformes privées par joueur
- **Validation argent** : Calculs sécurisés côté serveur
- **Nettoyage** : Suppression auto des données orphelines

## 🚀 Déploiement

### Prérequis
1. **GameManager** : Système d'argent existant
2. **CandyTools** : Système de bonbons avec attributs
3. **CustomBackpack** : Interface hotbar personnalisée

### Installation
1. Copier les scripts dans `ServerScriptService` et `ReplicatedStorage`
2. Les événements se créent automatiquement au démarrage
3. L'interface s'intègre automatiquement à la hotbar

### Test
1. Équiper un bonbon
2. Appuyer sur P ou cliquer 🏭
3. Placer le bonbon sur une plateforme
4. Vérifier la génération d'argent
5. Tester le ramassage par proximité

---

**✨ Le système est maintenant prêt à utiliser ! Les joueurs peuvent créer leurs fermes de bonbons automatiques.**
