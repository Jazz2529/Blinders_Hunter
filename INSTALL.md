# Blinders Hunter — Guide d'installation et de build APK

## FICHIERS DU PROJET

```
lib/
  main.dart                  ← Point d'entrée (imports vérifiés)
  firebase_options.dart      ← ⚠️ À regénérer (voir Étape 2)
  models/
    models.dart              ← Tous les modèles de données
  data/
    game_data.dart           ← Personnages, cartes, terrains
  services/
    engine.dart              ← Moteur de jeu pur (dégâts, effets, victoire)
    firebase_service.dart    ← Opérations Firebase DB
    game_provider.dart       ← State management multijoueur
    solo_controller.dart     ← Contrôleur solo + IA 3 niveaux
  screens/
    home_screen.dart         ← Accueil multi/solo
    multi_screens.dart       ← Lobby + RoleReveal + GameScreen multi
    solo_screen.dart         ← Setup + Jeu + GameOver solo
  widgets/
    theme.dart               ← Palette, styles, composants partagés
```

---

## ÉTAPE 1 — Flutter SDK

```bash
# Si Flutter n'est pas installé :
# https://docs.flutter.dev/get-started/install

flutter --version   # doit afficher 3.x.x
```

---

## ÉTAPE 2 — Firebase (10 minutes)

### 2a. Créer le projet
1. Va sur https://console.firebase.google.com
2. Crée un projet **"blinders-hunter"**
3. Active **Realtime Database** → mode test
4. Active **Authentication** → méthode **Anonyme**
5. Active **Cloud Messaging**

### 2b. Ajouter l'app Android
- Dans Firebase Console → Project Settings → Add app → Android
- Package name : `com.blindershunter.app`
- Télécharge `google-services.json`
- Place-le dans `android/app/google-services.json`

### 2c. Générer firebase_options.dart
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=blinders-hunter
```
→ Cela remplace automatiquement `lib/firebase_options.dart` avec tes vraies clés.

### 2d. Règles de sécurité Firebase
Dans Firebase Console → Realtime Database → Règles, copie le contenu de `firebase/database.rules.json`

---

## ÉTAPE 3 — Polices Google Fonts

Télécharge depuis https://fonts.google.com :
- **Cinzel** : Regular (400), Bold (700), Black (900)
- **Crimson Text** : Regular, SemiBold (600), Italic

Place les fichiers .ttf dans `assets/fonts/` :
```
assets/fonts/
  Cinzel-Regular.ttf
  Cinzel-Bold.ttf
  Cinzel-Black.ttf
  CrimsonText-Regular.ttf
  CrimsonText-SemiBold.ttf
  CrimsonText-Italic.ttf
```

---

## ÉTAPE 4 — Installer les dépendances

```bash
cd blinders_hunter
flutter pub get
```

---

## ÉTAPE 5 — Vérifier que tout compile

```bash
flutter analyze
```

S'il y a 0 erreur → passe à l'étape 6.

---

## ÉTAPE 6 — Générer l'APK

### APK debug (pour tester sur ton téléphone)
```bash
flutter build apk --debug
```
→ Fichier généré : `build/app/outputs/flutter-apk/app-debug.apk`

### Installer via USB
```bash
# Active le débogage USB sur ton Android
adb devices                  # vérifie que le téléphone est détecté
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### APK release (optimisé, plus léger)
```bash
# Crée un keystore (une seule fois)
keytool -genkey -v \
  -keystore ~/blinders.keystore \
  -alias blinders \
  -keyalg RSA -keysize 2048 -validity 10000

# Build release
flutter build apk --release --split-per-abi
```
→ Fichier principal : `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

---

## RÉSOLUTION DES ERREURS COURANTES

**`google-services.json` manquant**
→ Retélécharge depuis Firebase Console → Project Settings → Your apps → Android

**`firebase_options.dart` a des valeurs REMPLACE_MOI**
→ Lance `flutterfire configure --project=blinders-hunter`

**Polices non trouvées**
→ Vérifie que les .ttf sont dans `assets/fonts/` et que les noms correspondent exactement au `pubspec.yaml`

**Erreur Gradle**
```bash
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter build apk --debug
```

**minSdk trop bas**
→ Vérifie `minSdk 21` dans `android/app/build.gradle`

---

## FONCTIONNALITÉS INCLUSES

✅ Mode Solo — 4 joueurs (toi + 3 bots IA)
✅ IA 3 niveaux — Facile / Normal / Difficile
✅ Mode Multijoueur — jusqu'à 7 joueurs en ligne
✅ 15 personnages avec capacités uniques
✅ 30 cartes réparties en 3 decks (Lumière, Ténèbres, Vision)
✅ 6 terrains avec effets
✅ Système d'équipements persistants
✅ Conditions de victoire par faction
✅ Interface sombre pixel-fantasy
✅ Notifications push (notifications Firebase) — nécessite déploiement Cloud Functions
