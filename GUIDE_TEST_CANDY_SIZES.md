# 🍬 Guide de Test - Préservation des Tailles de Bonbons

Ce guide vous explique comment tester que les tailles de bonbons sont maintenant correctement préservées lors de la sauvegarde et du chargement.

## 🔧 Étapes de Test Manuel

### 1. Préparation
1. Démarrez votre jeu dans Roblox Studio
2. Assurez-vous d'avoir des bonbons de différentes tailles dans votre inventaire
3. Ouvrez la console de sortie pour voir les messages de debug

### 2. Vérification de l'Inventaire Initial
1. Appuyez sur **F8** pour ouvrir l'interface de sauvegarde
2. Regardez la section "Résumé" pour voir vos objets actuels
3. Notez les types et tailles de bonbons que vous possédez

### 3. Sauvegarde
1. Dans l'interface de test, cliquez **"💾 Sauvegarder"**
2. Vérifiez dans la console que vous voyez des messages comme :
   ```
   💾 [SAVE] Taille capturée: Basique | Large | 2.5x
   💾 [SAVE] Données sauvegardées avec succès pour [Votre nom]
   ```

### 4. Test de Restauration
1. Quittez le jeu (arrêtez le test dans Studio)
2. Relancez le jeu
3. Attendez que vos données soient automatiquement chargées
4. Vérifiez dans la console que vous voyez des messages comme :
   ```
   📦 [RESTORE] Configuration taille pour: Basique | Large | 2.5x
   🍬 [RESTORE] Bonbon restauré: Basique x1 (Large 2.5x)
   ```

### 5. Vérification Finale
1. Ouvrez votre inventaire
2. Vérifiez que vos bonbons ont conservé leurs tailles originales :
   - Les **Tiny** bonbons sont restés **Tiny**
   - Les **Large** bonbons sont restés **Large**
   - Les **Colossal** bonbons sont restés **Colossal**
   - etc.

## 🤖 Test Automatique

Pour un test automatique complet :

### 1. Installation du Script de Test
1. Copiez le fichier `TestCandySizeFix.lua` dans **ServerScriptService**
2. Le script sera automatiquement chargé

### 2. Commande de Test
1. Dans le chat du jeu, tapez : `/testsizes`
2. Le script va automatiquement :
   - Créer des bonbons avec différentes tailles
   - Les sauvegarder
   - Vider l'inventaire
   - Restaurer les données
   - Vérifier que les tailles sont préservées

### 3. Lecture des Résultats
Le test affichera dans la console :
```
🧪 [TEST] ========== RÉSULTATS ==========
🧪 [TEST] Bonbons restaurés: 5
🧪 [TEST] Tailles préservées: ✅ OUI
🎉 [TEST] TEST RÉUSSI - Les tailles de bonbons sont correctement préservées!
```

## ❌ Diagnostic des Problèmes

### Problème : Les tailles deviennent toutes "Normal"
**Cause possible :** L'ancien système est encore utilisé
**Solution :**
1. Vérifiez que SaveDataManager.lua version 1.3.0 est bien chargé
2. Vérifiez que CandyTools.lua a été mis à jour
3. Redémarrez complètement le serveur

### Problème : Messages d'erreur dans la console
**Cause possible :** Modules manquants ou mal configurés
**Solution :**
1. Vérifiez que CandySizeManager existe dans ReplicatedStorage
2. Vérifiez que tous les templates de bonbons existent dans CandyModels
3. Consultez les messages d'erreur spécifiques

### Problème : La sauvegarde échoue
**Cause possible :** DataStores non activés
**Solution :**
1. Allez dans Game Settings > Security
2. Activez "Enable Studio Access to API Services"
3. Redémarrez le test

## 🔍 Messages de Debug Importants

### Lors de la Sauvegarde
```
💾 [SAVE] Taille capturée: [Nom] | [Rareté] | [Taille]x
💾 [SAVE] Données sauvegardées avec succès pour [Joueur]
```

### Lors de la Restauration
```
📋 [RESTORE] Configuration taille pour: [Nom] | [Rareté] | [Taille]x
💾 RESTORATION: Utilisation données sauvegardées: [Rareté] | Taille: [Taille]
🍬 [RESTORE] Bonbon restauré: [Nom] x1 ([Rareté] [Taille]x)
```

## ✅ Critères de Réussite

Le test est réussi quand :
1. ✅ Les bonbons conservent leur **rareté** (Tiny, Small, Large, Giant, Colossal, etc.)
2. ✅ Les bonbons conservent leur **taille numérique** (0.5x, 2.5x, 5.0x, etc.)
3. ✅ Les bonbons conservent leur **couleur** personnalisée
4. ✅ La **quantité** de chaque taille est préservée
5. ✅ Aucun bonbon ne devient "Normal" après rechargement

## 🎯 Objectif

Avant ce correctif : ❌ Tous les bonbons devenaient "Normal" après rechargement
Après ce correctif : ✅ Chaque bonbon conserve sa taille exacte

---

**Guide de test v1.3.0** 🍬