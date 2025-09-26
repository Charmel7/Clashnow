import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/network_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> players = [
    {'name': 'Joueur 1', 'team': 'ÉQUIPE A', 'score': 0, 'connected': true},
    {'name': 'Joueur 2', 'team': 'ÉQUIPE B', 'score': 0, 'connected': true},
  ];

  String? _buzzedPlayer;
  bool _serverStarted = false;
  bool isGameStarted = false;
  int currentQuestion = 1;
  @override
  void initState() {
    super.initState();
    // On ne peut pas utiliser Provider dans initState directement
    // On va utiliser un delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNetworkListener();
    });
  }

  void _setupNetworkListener() {
    final networkService = Provider.of<NetworkService>(context, listen: false);

    networkService.messages.listen((message) {
      if (message['type'] == 'buzz') {
        _handleBuzzMessage(message);
      } else if (message['type'] == 'player_join') {
        _handlePlayerJoin(message);
      }
    });
  }

  // AJOUTE cette méthode
  void _handlePlayerJoin(Map<String, dynamic> message) {
    final playerName = message['playerName'];
    final teamName = message['teamName'];
    final playerId = message['playerId'];

    setState(() {
      players.add({
        'name': playerName,
        'team': teamName,
        'id': playerId, // IMPORTANT pour identifier le joueur
        'score': 0,
        'connected': true,
      });
    });
  }

  void _handleBuzzMessage(Map<String, dynamic> message) {
    final playerName = message['playerName'];
    final teamName = message['teamName'];
    final playerId = message['id'];

    setState(() {
      _buzzedPlayer = playerName;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 BUZZ !'),
        content: Text('$playerName ($teamName) a buzzé !'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerName, playerId);
            },
            child: const Text('ATTRIBUER POINTS'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _buzzedPlayer = null;
              });
              Navigator.pop(context);
            },
            child: const Text('IGNORER'),
          ),
        ],
      ),
    );
  }

  void startGame() {
    setState(() {
      isGameStarted = true;
    });
  }

  void nextQuestion() {
    setState(() {
      currentQuestion++;
    });
  }

  void addPoints(int playerIndex, int points) {
    setState(() {
      players[playerIndex]['score'] += points;
    });
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
      return 'IP non trouvée';
    } catch (e) {
      return 'Erreur: $e';
    }
  }

  void _startGame() {
    if (!_serverStarted) return;

    setState(() {
      isGameStarted = true;
    });

    // Envoyer un message à tous les joueurs
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'game_start',
      'message': 'La partie commence !',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎮 Partie démarrée ! Les buzzers sont actifs.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startServer() async {
    // Utilise un WidgetsBinding pour accéder au Provider après le build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final networkService = Provider.of<NetworkService>(
        context,
        listen: false,
      );

      try {
        await networkService.startHosting();
        setState(() {
          _serverStarted = true;
        });

        // Ajouter quelques joueurs de test
        setState(() {
          players = [
            {
              'name': 'Joueur 1',
              'team': 'ÉQUIPE A',
              'score': 0,
              'connected': true,
            },
            {
              'name': 'Joueur 2',
              'team': 'ÉQUIPE B',
              'score': 0,
              'connected': true,
            },
          ];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Serveur démarré ! Les joueurs peuvent se connecter.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _showPointsDialog(int playerIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Points pour ${players[playerIndex]['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PointsButton(
              points: 5,
              onPressed: () => addPoints(playerIndex, 5),
            ),
            _PointsButton(
              points: 10,
              onPressed: () => addPoints(playerIndex, 10),
            ),
            _PointsButton(
              points: -5,
              onPressed: () => addPoints(playerIndex, -5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('FERMER'),
          ),
        ],
      ),
    );
  }

  int _getConnectedClientsCount(NetworkService network) {
    // Pour l'instant, retourne un compte simulé
    // Plus tard, on connectera avec les vrais clients
    return players.length;
  }

  void _simulateBuzz() {
    if (players.isNotEmpty && isGameStarted) {
      setState(() {
        _buzzedPlayer = players[0]['name'];
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('BUZZ !'),
          content: Text('$_buzzedPlayer a buzzé !'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showPointsDialog(0);
              },
              child: const Text('ATTRIBUER POINTS'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _buzzedPlayer = null;
                });
                Navigator.pop(context);
              },
              child: const Text('IGNORER'),
            ),
          ],
        ),
      );
    }
  }

  // MODIFIE _awardPoints pour utiliser l'ID
  void _awardPoints(String playerId, int points) {
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex != -1) {
      setState(() {
        players[playerIndex]['score'] += points;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PANNEAU ADMIN'),
        backgroundColor: Colors.blueGrey[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // STATUT DU JEU
            // Remplace la carte actuelle par :
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      isGameStarted
                          ? 'QUESTION $currentQuestion'
                          : 'EN ATTENTE',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // STATUT SERVEUR
                    // Dans la partie STATUT SERVEUR, remplace par :
                    Builder(
                      builder: (context) {
                        final network = Provider.of<NetworkService>(context);
                        return Column(
                          children: [
                            Text(
                              network.status,
                              style: TextStyle(
                                color: network.isConnected
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (network.isHost)
                              Text('${players.length} joueur(s)'),
                          ],
                        );
                      },
                    ),
                    // NOTIFICATION BUZZ
                    if (_buzzedPlayer != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'BUZZ: $_buzzedPlayer',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Builder(
              builder: (context) {
                final network = Provider.of<NetworkService>(context);
                return FutureBuilder<String>(
                  future: _getLocalIp(),
                  builder: (context, snapshot) {
                    return Column(
                      children: [
                        Text(
                          network.status,
                          style: TextStyle(
                            color: network.isConnected
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (network.isHost && snapshot.hasData)
                          Text('IP: ${snapshot.data!}:8080'),
                        if (network.isHost) Text('${players.length} joueur(s)'),
                      ],
                    );
                  },
                );
              },
            ),
            // LISTE DES JOUEURS
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        player['connected'] ? Icons.person : Icons.person_off,
                        color: player['connected'] ? Colors.green : Colors.grey,
                      ),
                      title: Text(player['name']),
                      subtitle: Text(player['team']),
                      trailing: Text(
                        '${player['score']} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () => _showPointsDialog(index),
                    ),
                  );
                },
              ),
            ),

            // BOUTONS DE CONTRÔLE
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _serverStarted ? null : _startServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('SERVER'),
                  ),
                ),
                ElevatedButton(
                  onPressed: _serverStarted && !isGameStarted
                      ? _startGame
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('START'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isGameStarted ? nextQuestion : null,
                    child: const Text('NEXT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0),
            ElevatedButton(
              onPressed: _simulateBuzz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('TEST BUZZ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsButton extends StatelessWidget {
  final int points;
  final VoidCallback onPressed;

  const _PointsButton({required this.points, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: points > 0 ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text('${points > 0 ? '+' : ''}$points points'),
    );
  }
}
