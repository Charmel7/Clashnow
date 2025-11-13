// lib/services/network_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class NetworkService with ChangeNotifier {
  ServerSocket? _server;
  List<Socket> _clients = [];
  bool _isHost = false;
  bool _isConnected = false;
  String _status = 'Déconnecté';

  // Stream pour recevoir les messages
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  String get status => _status;

  // HÉBERGER UN SALON (Admin)
  Future<void> startHosting() async {
    try {
      _server = await ServerSocket.bind('0.0.0.0', 8080);
      _isHost = true;
      _isConnected = true;
      _status = 'En attente de joueurs...';
      notifyListeners();

      _server!.listen((Socket client) {
        _clients.add(client);
        _status = '${_clients.length} joueur(s) connecté(s)';
        notifyListeners();

        // Écouter les messages du client
        client.listen(
          (Uint8List data) {
            final message = json.decode(String.fromCharCodes(data));
            _messageController.add(Map<String, dynamic>.from(message));
          },
          onError: (error) {
            _clients.remove(client);
            client.close();
          },
          onDone: () {
            _clients.remove(client);
            client.close();
            _removeClient(client);
            print('📤 Client déconnecté');
          },
        );
      });

      print('✅ Serveur démarré sur le port 8080');
    } catch (e) {
      print('❌ Erreur serveur: $e');
      _status = 'Erreur: $e';
      notifyListeners();
    }
  }

  // REJOINDRE UN SALON (Joueur)
  Future<void> joinGame(String ipAddress) async {
    try {
      final socket = await Socket.connect(ipAddress, 8080).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw SocketException('Timeout de connexion');
        },
      );

      _isHost = false;
      _isConnected = true;
      _status = 'Connecté au salon';
      notifyListeners();

      // Écouter les messages du serveur
      socket.listen(
        (Uint8List data) {
          try {
            final message = json.decode(String.fromCharCodes(data));
            _messageController.add(Map<String, dynamic>.from(message));
          } catch (e) {
            debugPrint('❌ Message JSON invalide: $e');
          }
        },
        onError: (error) {
          debugPrint('📡 Erreur connexion: $error');
          _isConnected = false;
          _status = 'Déconnecté - Erreur réseau';
          notifyListeners();
        },
        onDone: () {
          debugPrint('🔌 Déconnecté par le serveur');
          _isConnected = false;
          _status = 'Déconnecté';
          notifyListeners();
        },
      );

      _clients.add(socket);
      print('✅ Connecté à $ipAddress:8080');
    } on SocketException catch (e) {
      _status = 'Erreur connexion';
      notifyListeners();
      throw "Impossible de se connecter à $ipAddress:8080\n\nVérifiez :\n• L'IP du serveur admin\n• Le réseau WiFi commun\n• Le port 8080 disponible";
    } catch (e) {
      _status = 'Erreur inconnue';
      notifyListeners();
      throw "Erreur: $e";
    }
  }

  // ENVOYER UN MESSAGE
  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected) return;

    final jsonMessage = json.encode(message);

    if (_isHost) {
      // Admin envoie à tous les joueurs
      for (final client in _clients) {
        client.write(jsonMessage);
      }
    } else {
      // Joueur envoie à l'admin
      if (_clients.isNotEmpty) {
        _clients.first.write(jsonMessage);
      }
    }
  }

  //méthode pour envoyer les infos joueur après connexion
  void sendPlayerInfo(String playerName, String teamName) {
    // UTILISER LE MÊME FORMAT D'ID QUE L'ADMIN
    final playerId = '${playerName}_$teamName';
    sendMessage({
      'type': 'player_join',
      'playerName': playerName,
      'teamName': teamName,
      'playerId': playerId, // Même format que l'admin
    });
  }

  // ENVOYER UN BUZZER
  void sendBuzz(String playerName, String teamName) {
    sendMessage({
      'type': 'buzz',
      'playerName': playerName,
      'teamName': teamName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  //Pour Supprimer un client
  // Ajouter cette méthode pour gérer la suppression des clients
  void _removeClient(Socket client) {
    try {
      if (_clients.contains(client)) {
        _clients.remove(client);
        client.close();
        _status = '${_clients.length} joueur(s) connecté(s)';
        notifyListeners();
      }
    } catch (e) {
      print('❌ Erreur suppression client: $e');
    }
  }

  // Dans la classe NetworkService, ajoutez cette méthode :
  void sendPlayerLeave(String playerName, String teamName) {
    final playerId = '${playerName}_$teamName';
    sendMessage({
      'type': 'player_leave',
      'playerId': playerId,
      'playerName': playerName,
      'teamName': teamName,
    });
  }

  void disconnect() {
    for (final client in _clients) {
      client.close();
    }
    _server?.close();
    _clients.clear();
    _isConnected = false;
    _isHost = false;
    _status = 'Déconnecté';
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
