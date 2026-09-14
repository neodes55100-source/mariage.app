# mariage.app

Application mobile du mariage **Emmanuel & Jennifer — 03 juillet 2027**.

## Fonctionnement

- Android et iPhone.
- L’invité saisit une seule fois son nom / prénom.
- Il autorise l’accès à sa photothèque.
- Seuls les médias créés entre le **03/07/2027 à 14:00** et le **04/07/2027 à 05:00** sont sélectionnés.
- Les fichiers sont envoyés vers le système d’upload existant de `mariage.creemachanson.com`.
- Les identifiants des médias déjà envoyés sont conservés localement pour éviter les doublons.
- Android utilise une tâche périodique en arrière-plan. iOS rattrape les médias manquants à chaque réveil / réouverture de l’application, car Apple limite fortement l’exécution continue en arrière-plan.

## Builds

GitHub Actions produit :

- `app-release.apk` — Android installable directement.
- `app-release.aab` — Android pour Google Play.
- `Mariage-iOS-unsigned.ipa` — build iOS non signé. Un compte Apple Developer et des certificats sont nécessaires pour une installation normale sur iPhone / App Store.
