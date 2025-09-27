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
    {
      'name': 'Joueur 1',
      'team': 'ÉQUIPE A',
      'score': 0,
      'connected': true,
      'id': 5,
    },
    {
      'name': 'Joueur 2',
      'team': 'ÉQUIPE B',
      'score': 0,
      'connected': true,
      'id': 6,
    },
  ];

  String? _buzzedPlayer;
  String? _buzzedPlayerId;
  bool _serverStarted = false;
  bool isGameStarted = false;
  int currentQuestion = 1;
  bool _isGamePaused = false;
  String? _firstBuzzerPlayerId; // Premier joueur à buzzer
  bool _waitingForAnswer = false; // En attente de réponse admin
  List<String> _buzzedPlayers = []; // Liste des joueurs ayant buzzé
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

  Map<String, List<Map<String, dynamic>>> _groupPlayersByTeam() {
    Map<String, List<Map<String, dynamic>>> teams = {};

    for (var player in players) {
      String team = player['team'];
      if (!teams.containsKey(team)) {
        teams[team] = [];
      }
      teams[team]!.add(player);
    }

    return teams;
  }

  Future<bool> _onWillPop() async {
    if (!_serverStarted) return true;

    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quitter le panneau admin ?'),
            content: const Text('Les joueurs seront déconnectés.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ANNULER'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('QUITTER'),
              ),
            ],
          ),
        ) ??
        false;
  }

  int _getTeamScore(String teamName) {
    return players.where((player) => player['team'] == teamName).fold(0, (
      sum,
      player,
    ) {
      final score = player['score'];
      // S'assurer que score est un int, sinon utiliser 0
      return sum + (score is int ? score : 0);
    });
  }

  void _handlePlayerJoin(Map<String, dynamic> message) {
    final playerName = message['playerName'];
    final teamName = message['teamName'];
    final playerId =
        message['playerId'] ??
        DateTime.now().millisecondsSinceEpoch.toString(); // ← CORRECTION

    // Vérifier si le joueur existe déjà
    if (players.any((p) => p['id'] == playerId)) return;

    setState(() {
      players.add({
        'name': playerName,
        'team': teamName,
        'id': playerId,
        'score': 0,
        'connected': true,
      });
    });
  }

  /*void _handleBuzzMessage(Map<String, dynamic> message) {
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
              _showPointsDialog(playerId);
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
  }*/
  void _handleBuzzMessage(Map<String, dynamic> message) {
    final playerName = message['playerName'];
    final teamName = message['teamName'];
    final playerId = message['playerId'] ?? playerName;

    // PREMIER BUZZ
    if (!_waitingForAnswer && _firstBuzzerPlayerId == null) {
      setState(() {
        _firstBuzzerPlayerId = playerId;
        _waitingForAnswer = true;
        _buzzedPlayer = playerName;
        _buzzedPlayerId = playerId;
        _buzzedPlayers.add(playerId);
      });

      _lockBuzzers();
      //AudioService.playBuzz();

      // CORRECTION : Appel direct sans callback
      _showBuzzDialog(playerName, teamName, playerId);
    } else {
      // BUZZ SUIVANTS
      if (!_buzzedPlayers.contains(playerId)) {
        setState(() {
          _buzzedPlayers.add(playerId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$playerName a buzzé (en attente)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showBuzzDialog(String playerName, String teamName, String playerId) {
    showDialog(
      context: context,
      barrierDismissible: false, // ← EMPÊCHER DE FERMER SANS CHOIX
      builder: (context) => AlertDialog(
        title: const Text('🎉 BUZZ !'),
        content: Text('$playerName ($teamName) a buzzé !'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 10); // +10 points par défaut
            },
            child: const Text('+10 POINTS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 5); // +5 points
            },
            child: const Text('+5 POINTS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetBuzz(); // Réinitialiser sans points
            },
            child: const Text('PASSER'),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    if (!_serverStarted) return;

    // RÉINITIALISER TOUT LE SYSTÈME DE BUZZ
    _resetBuzz();

    setState(() {
      isGameStarted = true;
      currentQuestion = 1;
    });

    //AudioService.playStart();

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

  void _lockBuzzers() {
    // Envoyer un message pour bloquer les buzzers
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({'type': 'lock_buzzers', 'locked': true});
  }

  void _resetBuzz() {
    setState(() {
      _buzzedPlayer = null;
      _buzzedPlayerId = null;
      _firstBuzzerPlayerId = null;
      _waitingForAnswer = false;
      _buzzedPlayers.clear();
    });

    // DÉVERROUILLER LES BUZZERS POUR LA QUESTION SUIVANTE
    _unlockBuzzers();
  }

  void _unlockBuzzers() {
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({'type': 'lock_buzzers', 'locked': false});
  }

  void _togglePause() {
    setState(() {
      _isGamePaused = !_isGamePaused;
    });

    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({'type': 'game_pause', 'paused': _isGamePaused});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isGamePaused ? '⏸️ Jeu en pause' : '▶️ Jeu repris'),
        backgroundColor: _isGamePaused ? Colors.orange : Colors.green,
      ),
    );
  }

  void nextQuestion() {
    // RÉINITIALISER LE SYSTÈME DE BUZZ POUR LA NOUVELLE QUESTION
    _resetBuzz();

    setState(() {
      currentQuestion++;
    });

    // ENVOYER UN MESSAGE POUR LA NOUVELLE QUESTION
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'next_question',
      'questionNumber': currentQuestion,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('➡️ Question $currentQuestion - Buzzers activés !'),
        backgroundColor: Colors.green,
      ),
    );
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
          players = [];
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

  void _showPointsDialog(String playerId) {
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex == -1) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Points pour ${players[playerIndex]['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PointsButton(
              points: 10,
              onPressed: () {
                Navigator.pop(context);
                _awardPoints(playerId, 10);
              },
            ),
            _PointsButton(
              points: 5,
              onPressed: () {
                Navigator.pop(context);
                _awardPoints(playerId, 5);
              },
            ),
            _PointsButton(
              points: -5,
              onPressed: () {
                Navigator.pop(context);
                _addPenalty(playerId);
              },
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

  /* void _simulateBuzz() {
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
  }*/

  void _addPenalty(String playerId) {
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex == -1) return;

    setState(() {
      players[playerIndex]['penalties'] =
          (players[playerIndex]['penalties'] ?? 0) + 1;
      players[playerIndex]['score'] = (players[playerIndex]['score'] ?? 0) - 5;
    });

    // Envoyer la pénalité au joueur
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'penalty',
      'playerId': playerId,
      'points': -5,
      'playerName': players[playerIndex]['name'],
      'totalScore': players[playerIndex]['score'],
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⛔ Pénalité de 5 pts pour ${players[playerIndex]['name']}',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showBasicStatistics() {
    // Calculs simples
    int totalPoints = players.fold(
      0,
      (sum, player) => sum + ((player['score'] ?? 0) as num).toInt(),
    );
    int connectedPlayers = players.where((p) => p['connected'] == true).length;
    int totalPenalties = players.fold(
      0,
      (sum, player) => sum + ((player['penalties'] ?? 0) as num).toInt(),
    );

    // Meilleur joueur
    var bestPlayer = players.isNotEmpty
        ? players.reduce(
            (a, b) => (a['score'] ?? 0) > (b['score'] ?? 0) ? a : b,
          )
        : null;

    // Scores par équipe
    Map<String, int> teamScores = {};
    for (var player in players) {
      String team = player['team'];
      teamScores[team] =
          (((teamScores[team] ?? 0) + (player['score'] ?? 0)) as num).toInt();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 STATISTIQUES DU JEU'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatRow('Question actuelle', '#$currentQuestion'),
              _StatRow(
                'Joueurs connectés',
                '$connectedPlayers/${players.length}',
              ),
              _StatRow('Points totaux', '$totalPoints pts'),
              _StatRow('Pénalités totales', '$totalPenalties'),

              const SizedBox(height: 10),
              const Text(
                '🏆 Scores par équipe:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...teamScores.entries.map(
                (team) => _StatRow(team.key, '${team.value} pts'),
              ),

              if (bestPlayer != null) ...[
                const SizedBox(height: 10),
                const Text(
                  '⭐ Meilleur joueur:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                _StatRow(bestPlayer['name'], '${bestPlayer['score']} pts'),
              ],
            ],
          ),
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

  void _awardPoints(String playerId, int points) {
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex == -1) {
      print('❌ Joueur non trouvé: $playerId');
      return;
    }

    // Calculer le nouveau score AVANT la mise à jour
    int newScore = (players[playerIndex]['score'] ?? 0) + points;

    setState(() {
      players[playerIndex]['score'] = newScore;
    });

    // ENVOYER LES POINTS À TOUS LES JOUEURS (CORRIGÉ)
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'score_update',
      'playerId': playerId,
      'points': points,
      'playerName': players[playerIndex]['name'],
      'teamName': players[playerIndex]['team'],
      'totalScore': newScore, // ← UTILISER newScore calculé
    });

    _lockBuzzers();
    _resetBuzz();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PANNEAU ADMIN'),
          backgroundColor: Colors.blueGrey[800],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // STATUT DU JEU
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        isGameStarted
                            ? 'QUESTION $currentQuestion'
                            : 'EN ATTENTE',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (_waitingForAnswer) ...[
                        SizedBox(height: 5),
                        Text(
                          '⏳ En attente de réponse...',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      if (_buzzedPlayers.isNotEmpty) ...[
                        SizedBox(height: 5),
                        Text(
                          '🎯 ${_buzzedPlayers.length} buzz(s)',
                          style: TextStyle(color: Colors.blue, fontSize: 14),
                        ),
                      ],
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
                          if (network.isHost)
                            Text('${players.length} joueur(s)'),
                        ],
                      );
                    },
                  );
                },
              ),
              // LISTE DES JOUEURS
              // Dans le build method - REMPLACER la ListView actuelle
              Expanded(
                child: Column(
                  children: [
                    // SCORES DES ÉQUIPES
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _groupPlayersByTeam().entries.map((team) {
                            return Column(
                              children: [
                                Text(
                                  team.key,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_getTeamScore(team.key)} pts',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // LISTE DES JOUEURS PAR ÉQUIPE
                    Expanded(
                      child: ListView.builder(
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                player['connected']
                                    ? Icons.person
                                    : Icons.person_off,
                                color: player['connected']
                                    ? Colors.green
                                    : Colors.grey,
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
                              onTap: () => _showPointsDialog(player['id']),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
                      ),
                      child: const Text('SERVER'),
                    ),
                  ),
                  SizedBox(width: 5),
                  ElevatedButton(
                    onPressed: _serverStarted && !isGameStarted
                        ? _startGame
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('START'),
                  ),
                  SizedBox(width: 5),
                  ElevatedButton(
                    onPressed: isGameStarted ? _togglePause : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isGamePaused
                          ? Colors.green
                          : Colors.orange,
                    ),
                    child: Icon(_isGamePaused ? Icons.play_arrow : Icons.pause),
                  ),
                  SizedBox(width: 5),
                  ElevatedButton(
                    onPressed: _showBasicStatistics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    child: const Icon(Icons.analytics),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isGameStarted ? nextQuestion : null,
                      child: const Text('NEXT'),
                    ),
                  ),
                ],
              ),
              /* const SizedBox(height: 0),
              ElevatedButton(
                onPressed: _simulateBuzz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('TEST BUZZ'),
              ),*/
            ],
          ),
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
