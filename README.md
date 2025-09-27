# CLASHNOW - Système de Buzzers Temps Réel

Une application Flutter pour gérer des buzzers en temps réel via WiFi local.

## Fonctionnalités

- **Panel Admin** : Créer un salon, gérer les joueurs, attribuer des points
- **Interface Joueur** : Se connecter à un salon, buzzer, voir son score
- **Synchronisation Temps Réel** : Communication via sockets TCP
- **Effets Sonores** : Sons pour les buzzers, les points, les pénalités
- **Statistiques** : Scores par équipe, meilleur joueur, etc.

## Installation

1. Cloner le projet
2. Exécuter `flutter pub get`
3. Lancer l'application sur un appareil ou un émulateur

## Utilisation

### Admin
- Démarrer le serveur via le bouton "SERVER"
- Partager l'IP affichée avec les joueurs
- Démarrer la partie avec "START"
- Gérer les buzzers et attribuer les points

### Joueur
- Saisir l'IP du serveur admin
- Entrer son nom et choisir son équipe
- Se connecter et buzzer quand la partie commence

## Structure du Projet

- `lib/screens/` : Écrans de l'application (admin, joueur, accueil)
- `lib/services/` : Services réseau et audio
- `lib/themes/` : Thème de l'application
- `assets/sounds/` : Fichiers audio pour les effets sonores

## Technologies Utilisées

- Flutter
- Dart
- Sockets TCP
- Provider (state management)


## Licence

MIT