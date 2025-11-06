# Guide de Configuration du Modèle Popotam

## Structure du Dossier PetModels

Ton dossier `ReplicatedStorage/PetModels` doit contenir:

```
PetModels/
└── Popotam/
    ├── model (MeshPart ou Model avec les parties du modèle)
    ├── AnimSaves/
    │   ├── popotam_idle (Animation)
    │   └── popotam_walk (Animation)
    └── AnimationController (ou Humanoid)
```

## Configuration Requise

### 1. Structure du Modèle Popotam

Le modèle doit avoir:
- **Un PrimaryPart** défini (généralement appelé "Body" ou "HumanoidRootPart")
- **Un AnimationController** ou **Humanoid** pour jouer les animations
- **Un dossier AnimSaves** contenant les animations

### 2. Animations

Dans le dossier `AnimSaves`, tu dois avoir:
- **popotam_idle** : Animation jouée quand le pet est immobile
- **popotam_walk** : Animation jouée quand le pet se déplace

Les animations peuvent aussi s'appeler simplement "idle" et "walk" si tu préfères.

### 3. Configuration dans le Code

Le Popotam est déjà configuré dans `PetManager.lua`:
- **Nom**: Popotam
- **Rareté**: Common
- **Prix**: 75,000 (ou 30 Robux)
- **Boost**: +12% capacité du sac
- **Type de mouvement**: Ground (marche au sol)

## Comment ça Fonctionne

1. **Chargement du Modèle**: Le système cherche le modèle dans `ReplicatedStorage/PetModels/Popotam`
2. **Chargement des Animations**: Les animations sont automatiquement chargées depuis le dossier `AnimSaves`
3. **Suivi du Joueur**: Le pet suit le joueur au sol avec un raycast pour détecter le terrain
4. **Animations Automatiques**:
   - **Idle** joue quand le pet est immobile (vitesse < 0.5)
   - **Walk** joue quand le pet se déplace (vitesse > 0.5)

## Checklist de Vérification

- [ ] Le modèle Popotam est dans `ReplicatedStorage/PetModels/`
- [ ] Le modèle a un PrimaryPart défini
- [ ] Le modèle a un AnimationController ou Humanoid
- [ ] Le dossier AnimSaves existe avec les animations
- [ ] Les animations sont nommées "popotam_idle" et "popotam_walk" (ou "idle" et "walk")
- [ ] Toutes les parties du modèle ont `CanCollide = false`

## Fallback

Si le modèle n'est pas trouvé, le système créera automatiquement un cube coloré comme placeholder, donc pas de panique si tu vois un cube au début!

## Test

Pour tester ton Popotam:
1. Achète-le dans le menu des pets
2. Équipe-le
3. Il devrait apparaître et te suivre avec ses animations

## Notes

- Le pet se téléporte si tu es trop loin (>50 studs)
- Il utilise un raycast pour rester au sol
- Les animations se changent automatiquement selon la vitesse
