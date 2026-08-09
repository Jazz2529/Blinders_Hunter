# Configuration Firebase — OBLIGATOIRE avant de tester le multijoueur réseau

## 1. Créer le projet Firebase
1. Va sur https://console.firebase.google.com
2. "Ajouter un projet" → nomme-le par ex. `blinders-hunter`
3. Une fois créé, dans le menu de gauche :
   - **Build → Realtime Database** → "Créer une base de données"
     - Région : Europe (europe-west1) recommandé
     - Mode : commence en "mode test" (règles ouvertes 30 jours)
   - **Build → Authentication** → onglet "Sign-in method" → active **Anonyme**

## 2. Règles Realtime Database (à coller dans Database → Règles)
```json
{
  "rules": {
    "rooms": {
      "$roomId": {
        ".read": true,
        ".write": true,
        ".indexOn": ["status"]
      }
    }
  }
}
```
Clique "Publier".

## 3. Lier le projet Flutter (à faire dans ton terminal)
```cmd
cd C:\Users\jazzo\Downloads\blinders_hunter
dart pub global activate flutterfire_cli
flutterfire configure --project=blinders-hunter
```
- Sélectionne les plateformes : **windows, android** (+ ios si besoin)
- Cela génère automatiquement `lib/firebase_options.dart` avec les vraies clés.

## 4. Vérifier pubspec.yaml
Doit contenir (normalement déjà présent) :
```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_database: ^10.4.0
  firebase_auth: ^4.16.0
```

## 5. Vérifier main.dart
`Firebase.initializeApp()` doit être appelé avant `runApp()` :
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```
(remplace `DefaultFirebaseOptions` par le nom généré dans `firebase_options.dart`,
généralement `DefaultFirebaseOptions`)

## 6. Build
```cmd
flutter pub get
flutter build windows
```

---

## Test rapide entre 2 appareils
1. PC : Multijoueur → Créer une salle → note le code à 5 lettres
2. Téléphone (même réseau ou 4G, peu importe — c'est internet) :
   Multijoueur → Rejoindre → entre le code
3. Les deux écrans doivent se synchroniser en temps réel dans le lobby.
4. Avec 4+ joueurs (vrais ou via "+ Ajouter un bot"), l'hôte peut lancer la partie.

## Dépannage
- **"Connexion impossible"** → vérifie que Realtime Database est bien créée
  et que les règles sont publiées (étape 2).
- **Erreur firebase_core / DefaultFirebaseOptions introuvable** → `flutterfire configure`
  n'a pas été exécuté ou a échoué — relance l'étape 3.
- **Le lobby ne se met pas à jour** → vérifie ta connexion internet ; les deux
  appareils doivent pouvoir atteindre `*.firebaseio.com`.
