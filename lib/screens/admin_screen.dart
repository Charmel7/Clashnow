import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/network_service.dart';
import '../services/simulation_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> players = [];
  final AudioPlayer _buzzSoundPlayer = AudioPlayer();
  bool _isBuzzSoundLoaded = false;
  String? _buzzedPlayer;
  String? _buzzedPlayerId;
  bool _serverStarted = false;
  bool isGameStarted = false;
  int currentQuestion = 1;
  bool _isGamePaused = false;
  String? _firstBuzzerPlayerId;
  bool _waitingForAnswer = false;
  List<String> _buzzedPlayers = [];

  @override
  void initState() {
    super.initState();
    _initSimulationService();
    _initBuzzSound();
    // On ne peut pas utiliser Provider dans initState directement
    // On va utiliser un delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNetworkListener();
    });
  }

  @override
  void dispose() {
    _simulationService.dispose();
    _buzzSoundPlayer.dispose();
    super.dispose();
  }

  Future<void> _initBuzzSound() async {
    try {
      await _buzzSoundPlayer.setAsset('assets/sounds/1.mp3');
      setState(() {
        _isBuzzSoundLoaded = true;
      });
    } catch (e) {
      print('❌ Erreur chargement son buzz: $e');
    }
  }

  void _playBuzzSound() async {
    if (!_isBuzzSoundLoaded) return;

    try {
      await _buzzSoundPlayer.seek(Duration.zero);
      await _buzzSoundPlayer.play();
    } catch (e) {
      print('❌ Erreur lecture son buzz: $e');
    }
  }

  // 🔥 SERVICE DE SIMULATION
  late SimulationService _simulationService;

  void _initSimulationService() {
    _simulationService = SimulationService();
    _simulationService.initialize(
      onBuzz: _handleBuzzMessage,
      onNextQuestion: nextQuestion,
      onScoreUpdate: _handleSimulatedScoreUpdate,
      onPenalty: _handleSimulatedPenalty,
      onPlayerDisconnect: _handleSimulatedPlayerDisconnect,
      onPlayersUpdate: _handleSimulatedPlayersUpdate,
    );

    // Écouter les changements d'état de la simulation
    _simulationService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // 🔥 GESTION DES SCORES SIMULÉS
  void _handleSimulatedScoreUpdate(Map<String, dynamic> data) {
    final playerIndex = players.indexWhere((p) => p['id'] == data['playerId']);
    if (playerIndex != -1) {
      setState(() {
        players[playerIndex]['score'] = data['totalScore'];
        players[playerIndex]['success'] =
            (players[playerIndex]['success'] ?? 0) + 1;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⭐ Simulation: ${data['playerName']} +${data['points']} points',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 🔥 GESTION DES PÉNALITÉS SIMULÉES
  void _handleSimulatedPenalty(Map<String, dynamic> data) {
    final playerIndex = players.indexWhere((p) => p['id'] == data['playerId']);
    if (playerIndex != -1) {
      setState(() {
        players[playerIndex]['score'] = data['totalScore'];
        players[playerIndex]['penalties'] =
            (players[playerIndex]['penalties'] ?? 0) + 1;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⛔ Simulation: Pénalité ${data['playerName']} -5 points'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 🔥 GESTION DES DÉCONNEXIONS SIMULÉES
  void _handleSimulatedPlayerDisconnect(Map<String, dynamic> data) {
    final playerIndex = players.indexWhere((p) => p['id'] == data['playerId']);
    if (playerIndex != -1) {
      setState(() {
        players[playerIndex]['connected'] = false;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📤 Simulation: ${data['playerName']} déconnecté'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 🔥 GESTION DES JOUEURS SIMULÉS
  void _handleSimulatedPlayersUpdate(List<Map<String, dynamic>> newPlayers) {
    setState(() {
      // Supprimer les anciens joueurs simulés
      players.removeWhere((player) => player['isSimulated'] == true);
      // Ajouter les nouveaux joueurs simulés
      players.addAll(newPlayers);
    });
  }

  void _setupNetworkListener() {
    final networkService = Provider.of<NetworkService>(context, listen: false);

    networkService.messages.listen((message) {
      if (message['type'] == 'buzz') {
        _handleBuzzMessage(message);
      } else if (message['type'] == 'player_join') {
        _handlePlayerJoin(message);
      } else if (message['type'] == 'player_leave') {
        _handlePlayerLeave(message);
      }
    });
  }

  void _handlePlayerLeave(Map<String, dynamic> message) {
    final playerId = message['playerId'];
    final playerName = message['playerName'];
    final teamName = message['teamName'];

    print('📤 Joueur déconnecté: $playerName ($teamName) - ID: $playerId');

    if (!mounted) {
      print('⚠️ Widget admin déjà désactivé - Ignorer déconnexion');
      return;
    }

    setState(() {
      players.removeWhere((player) => player['id'] == playerId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📤 $playerName a quitté le salon'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );
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

      return sum + (score is int ? score : 0);
    });
  }

  void _handlePlayerJoin(Map<String, dynamic> message) {
    final playerName = message['playerName'];
    final teamName = message['teamName'];
    final playerId = message['playerId'];

    print('🎮 Nouveau joueur: $playerName ($teamName) - ID: $playerId');

    if (!mounted) {
      print('⚠️ Widget admin déjà désactivé - Ignorer joueur');
      return;
    }

    final existingIndex = players.indexWhere((p) => p['id'] == playerId);

    if (existingIndex != -1) {
      // Joueur existe déjà, mettre à jour le statut (reconnexion)
      if (mounted) {
        setState(() {
          players[existingIndex]['connected'] = true;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 $playerName reconnecté'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Nouveau joueur
    if (mounted) {
      setState(() {
        players.add({
          'name': playerName,
          'team': teamName,
          'id': playerId,
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $playerName a rejoint le salon'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  //  MÉTHODE POUR DESIGNER CAPITAINE
  void _toggleCaptain(String playerId) {
    if (!mounted) return;

    setState(() {
      // Retirer le statut de capitaine à tous les joueurs de la même équipe
      final player = players.firstWhere((p) => p['id'] == playerId);
      final team = player['team'];

      for (var p in players) {
        if (p['team'] == team) {
          p['isCaptain'] = false;
        }
      }

      // Designe le nouveau capitaine
      final playerIndex = players.indexWhere((p) => p['id'] == playerId);
      if (playerIndex != -1) {
        players[playerIndex]['isCaptain'] = true;

        // Envoyer la mise à jour à tous les joueurs
        final networkService = Provider.of<NetworkService>(
          context,
          listen: false,
        );
        networkService.sendMessage({
          'type': 'captain_update',
          'playerId': playerId,
          'playerName': players[playerIndex]['name'],
          'teamName': team,
          'isCaptain': true,
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('👑 Capitaine désigné '),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showEnhancedStatsPreview(String csvText) {
    // Calcul des métriques pour l'affichage
    final sortedPlayers = List.from(players)
      ..sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));

    final topScorer = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    final totalPoints = players.fold(
      0,
      (sum, player) => sum + (player['score'] as int ?? 0),
    );
    final totalAttempts = players.fold(
      0,
      (sum, player) => sum + (player['attempts'] as int ?? 0),
    );
    final totalSuccess = players.fold(
      0,
      (sum, player) => sum + (player['success'] as int ?? 0),
    );
    final globalEfficiency = totalAttempts > 0
        ? ((totalSuccess / totalAttempts) * 100)
        : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 10),
            Text('📊 STATISTIQUES DÉTAILLÉES'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tops Corner
              if (topScorer != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '🏆 TOP SCORER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '${topScorer['name']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${topScorer['team']}',
                        style: TextStyle(color: Colors.blue[600]),
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatChip('Score', '${topScorer['score']} pts'),
                          _StatChip(
                            'Tentatives',
                            '${topScorer['attempts'] ?? 0}',
                          ),
                          _StatChip(
                            'Réussites',
                            '${topScorer['success'] ?? 0}',
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      if ((topScorer['attempts'] ?? 0) > 0)
                        _StatChip(
                          'Efficacité',
                          '${((topScorer['success'] ?? 0) / (topScorer['attempts'] ?? 1) * 100).toStringAsFixed(1)}%',
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Métriques globales
              Text(
                '📈 MÉTRIQUES GLOBALES',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _StatChip('Points totaux', '$totalPoints')),
                  Expanded(child: _StatChip('Tentatives', '$totalAttempts')),
                ],
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Expanded(child: _StatChip('Réussites', '$totalSuccess')),
                  Expanded(
                    child: _StatChip(
                      'Efficacité',
                      '${globalEfficiency.toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Classement détaillé
              Text(
                '🎯 CLASSEMENT DÉTAILLÉ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              ...sortedPlayers.asMap().entries.map((entry) {
                final index = entry.key;
                final player = entry.value;
                final attempts = player['attempts'] ?? 0;
                final success = player['success'] ?? 0;
                final efficiency = attempts > 0
                    ? ((success / attempts) * 100)
                    : 0;

                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.amber[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(),
                  ),
                  child: Row(
                    children: [
                      // Rang
                      Container(
                        width: 30,
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index == 0
                                ? Colors.orange[800]
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                      // Infos joueur
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player['name'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              player['team'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${player['score']} pts',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (attempts > 0)
                            Text(
                              '$success/$attempts (${efficiency.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              SizedBox(height: 16),
              Text(
                'Les tentatives sont comptées pour le premier buzzer uniquement.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                'Les réussites sont comptées quand des points positifs sont accordés.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('FERMER'),
          ),
        ],
      ),
    );
  }

  void _handleBuzzMessage(Map<String, dynamic> message) {
    final playerName = message['playerName'];
    final teamName = message['teamName'];
    final timestamp = message['timestamp'];
    print('🎯 Buzz reçu de: $playerName ($teamName) à $timestamp');
    _playBuzzSound();
    // Vérifier si le widget est monté
    if (!mounted) {
      print('⚠️ Widget admin désactivé - Ignorer buzz');
      return;
    }

    // TROUVER LE JOUEUR EXACT DANS LA LISTE - recherche améliorée
    final playerIndex = players.indexWhere(
      (p) => p['name'] == playerName && p['team'] == teamName,
    );

    if (playerIndex == -1) {
      print('❌ Joueur $playerName ($teamName) non trouvé dans la liste');
      print('📋 Tentative de récupération depuis l\'ID...');

      // Tentative de récupération avec l'ID
      final playerId = '${playerName}_$teamName';
      final playerIndexById = players.indexWhere((p) => p['id'] == playerId);

      if (playerIndexById != -1) {
        print('✅ Joueur retrouvé par ID: $playerId');
        _processBuzz(playerIndexById, playerName, teamName, playerId);
      } else {
        print('❌ Joueur complètement introuvable - Ajout automatique');
        _addMissingPlayerAndProcessBuzz(playerName, teamName);
      }
      return;
    }

    final actualPlayerId = players[playerIndex]['id'];
    _processBuzz(playerIndex, playerName, teamName, actualPlayerId);
  }

  void _processBuzz(
    int playerIndex,
    String playerName,
    String teamName,
    String playerId,
  ) {
    if (!_waitingForAnswer && _firstBuzzerPlayerId == null) {
      print('🎉 Premier buzz: $playerName');

      if (mounted) {
        setState(() {
          _firstBuzzerPlayerId = playerId;
          _waitingForAnswer = true;
          _buzzedPlayer = playerName;
          _buzzedPlayerId = playerId;
          _buzzedPlayers.add(playerId);

          // 🔥 INCRÉMENTER LE COMPTEUR DE TENTATIVES
          players[playerIndex]['attempts'] =
              (players[playerIndex]['attempts'] ?? 0) + 1;
        });
      }

      _lockBuzzers();
      _showBuzzDialog(playerName, teamName, playerId);
    } else {
      if (!_buzzedPlayers.contains(playerId)) {
        print('🔔 Buzz supplémentaire: $playerName');
        if (mounted) {
          setState(() {
            _buzzedPlayers.add(playerId);
          });
        }
      }
    }
  }

  void _addMissingPlayerAndProcessBuzz(String playerName, String teamName) {
    final playerId = '${playerName}_$teamName';

    if (mounted) {
      setState(() {
        players.add({
          'name': playerName,
          'team': teamName,
          'id': playerId,
          'score': 0,
          'attempts': 0,
          'success': 0,
          'penalties': 0,
          'connected': true,
          'isCaptain': false,
        });
      });
    }

    print('✅ Joueur $playerName ajouté automatiquement');
    _processBuzz(players.length - 1, playerName, teamName, playerId);
  }

  void _showBuzzDialog(String playerName, String teamName, String playerId) {
    // VERIFICATION FINALE AVANT OUVERTURE
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex == -1) {
      print('❌ Dialogue annulé: joueur $playerId non trouvé');
      _resetBuzz();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('BUZZ !'),
        content: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[300]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.orange[100]!,
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'SourceCodePro',
                color: Colors.blueGrey[800],
              ),
              children: [
                TextSpan(
                  text: playerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.orange[700],
                    letterSpacing: 0.5,
                  ),
                ),
                TextSpan(text: '\n'),
                WidgetSpan(
                  child: Icon(Icons.group, size: 16, color: Colors.blue[600]),
                ),
                TextSpan(
                  text: ' $teamName',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 10);
            },
            child: Text('+10 POINTS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 20);
            },
            child: Text('+20 POINTS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 30);
            },
            child: Text('+30 POINTS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 40);
            },
            child: Text('+40 POINTS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, 5);
            },
            child: Text('+5 POINTS'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _awardPoints(playerId, -10);
            },
            child: Text('-10 POINTS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _passAndLockTeam(teamName);
            },
            child: Text('PASSER'),
          ),
        ],
      ),
    ).then((_) {
      // Callback exécuté après la fermeture du dialogue
      print('✅ Dialogue fermé pour $playerName');
    });
  }

  void _startGame() {
    if (!_serverStarted) return;

    _resetBuzz(); // Réinitialiser le système de buzz

    setState(() {
      isGameStarted = true;
      currentQuestion = 1;
    });

    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'game_start',
      'message': 'La partie commence !',
      'questionNumber': currentQuestion,
      // 🔥 Ajouter un indicateur pour déverrouiller toutes les équipes
      'unlockAll': true,
    });

    _sendGameStateToAll();
  }

  void _sendGameStateToAll() {
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'game_state',
      'isGameStarted': isGameStarted,
      'currentQuestion': currentQuestion,
      'buzzerLocked': _waitingForAnswer,
    });
  }

  // Ajoutez cette méthode
  void _simulatePlayers() {
    print('🎮 Simulation de joueurs...');

    // Joueurs simulés
    setState(() {
      players = [
        {
          'id': 'john_equipe_a',
          'name': 'John',
          'team': 'EQUIPE A',
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        },
        {
          'id': 'johne_equipe_a',
          'name': 'Johne',
          'team': 'EQUIPE A',
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        },
        {
          'id': 'marie_equipe_b',
          'name': 'Marie',
          'team': 'EQUIPE B',
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        },
        {
          'id': 'marier_equipe_b',
          'name': 'Marier',
          'team': 'EQUIPE B',
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        },
        {
          'id': 'paul_equipe_b',
          'name': 'Paul',
          'team': 'EQUIPE B',
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        },
        {
          'id': 'pierre_equipe_b',
          'name': 'Pierre',
          'team': 'EQUIPE A',
          'score': 0,
          'penalties': 0,
          'attempts': 0,
          'success': 0,
          'connected': true,
          'isCaptain': false,
        },
      ];
    });

    // Simuler un buzz après 3 secondes
    Future.delayed(Duration(seconds: 3), () {
      _handleBuzzMessage({
        'type': 'buzz',
        'playerName': 'John',
        'teamName': 'EQUIPE A',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  void _lockBuzzers() {
    // Envoyer un message pour bloquer les buzzers
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({'type': 'lock_buzzers', 'locked': true});
  }

  void _passAndLockTeam(String playerTeam) {
    // Déterminer l'équipe adverse
    String otherTeam = (playerTeam == 'EQUIPE A') ? 'EQUIPE B' : 'EQUIPE A';

    print(
      '🔒 Verrouillage équipe $playerTeam - Déverrouillage équipe $otherTeam',
    );

    // Envoyer un message de verrouillage par équipe
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'lock_team_buzzers',
      'lockedTeam': playerTeam,
      'unlockedTeam': otherTeam,
    });

    // Réinitialiser l'état du buzz en cours mais garder le verrouillage partiel
    setState(() {
      _buzzedPlayer = null;
      _buzzedPlayerId = null;
      _firstBuzzerPlayerId = null;
      _waitingForAnswer = false;
      _buzzedPlayers.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔒 $playerTeam verrouillée - ✅ $otherTeam peut buzzer'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
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
        duration: Duration(seconds: 1),
      ),
    );
  }

  void nextQuestion() {
    // RÉINITIALISER LE SYSTÈME DE BUZZ POUR LA NOUVELLE QUESTION
    _resetBuzz();

    setState(() {
      currentQuestion++;
    });

    // ENVOYER UN MESSAGE POUR LA NOUVELLE QUESTION - DÉVERROUILLER TOUTES LES ÉQUIPES
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'next_question',
      'questionNumber': currentQuestion,
      'unlockAll': true,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '➡️ Question $currentQuestion - Toutes les équipes peuvent buzzer !',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
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
            duration: Duration(seconds: 1),
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
        title: Text('Pénalités pour ${players[playerIndex]['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PointsButton(
              points: -5,
              onPressed: () {
                Navigator.pop(context);
                _addPenalty(playerId, 5);
              },
            ),
            const SizedBox(height: 5),
            _PointsButton(
              points: -10,
              onPressed: () {
                Navigator.pop(context);
                _addPenalty(playerId, 10);
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

  void _addPenalty(String playerId, int penalty) {
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex == -1) return;

    setState(() {
      players[playerIndex]['penalties'] =
          (players[playerIndex]['penalties'] ?? 0) + 1;
      players[playerIndex]['score'] =
          (players[playerIndex]['score'] ?? 0) - penalty;
    });

    // Envoyer la pénalité au joueur
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'penalty',
      'playerId': playerId,
      'points': penalty,
      'playerName': players[playerIndex]['name'],
      'totalScore': players[playerIndex]['score'],
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⛔ Pénalité de $penalty pts pour ${players[playerIndex]['name']}',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
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
      teamScores[team] = (((teamScores[team] ?? 0) + (player['score'] ?? 0)))
          .toInt();
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

  // MÉTHODE POUR OPTIONS JOUEUR
  void _showPlayerOptions(String playerId) {
    final playerIndex = players.indexWhere((p) => p['id'] == playerId);
    if (playerIndex == -1) return;

    final player = players[playerIndex];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Options pour ${player['name']}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 16),

            // BOUTON CAPITAINE
            ListTile(
              leading: Icon(Icons.stars, color: Colors.amber),
              title: Text('Désigner comme capitaine'),
              trailing: player['isCaptain'] == true
                  ? Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _toggleCaptain(playerId);
              },
            ),

            // BOUTON PÉNALITÉS
            ListTile(
              leading: Icon(Icons.warning, color: Colors.redAccent),
              title: Text('Ajouter une pénalité'),
              onTap: () {
                Navigator.pop(context);
                _showPointsDialog(playerId);
              },
            ),
          ],
        ),
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

      // 🔥 INCRÉMENTER LE COMPTEUR DE RÉUSSITES SI POINTS POSITIFS
      if (points > 0) {
        players[playerIndex]['success'] =
            (players[playerIndex]['success'] ?? 0) + 1;
      }
    });

    // ENVOYER LES POINTS À TOUS LES JOUEURS
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendMessage({
      'type': 'score_update',
      'playerId': playerId,
      'points': points,
      'playerName': players[playerIndex]['name'],
      'teamName': players[playerIndex]['team'],
      'totalScore': newScore,
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
              Expanded(
                child: Column(
                  children: [
                    // SCORES DES ÉQUIPES
                    // SCORES ÉQUIPE PLUS VISIBLES
                    Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _groupPlayersByTeam().entries.map((team) {
                            final teamName = team.key;
                            final teamScore = _getTeamScore(teamName);
                            final teamColor = teamName == 'EQUIPE A'
                                ? Colors.blue[900]!
                                : Colors.red[700]!;

                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 100,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: teamColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: teamColor, width: 3),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    teamName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: teamColor,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '$teamScore pts',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800, // Très gras
                                      color: teamColor,
                                    ),
                                  ),
                                ],
                              ),
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
                          final attempts = player['attempts'] ?? 0;
                          final success = player['success'] ?? 0;
                          final efficiency = attempts > 0
                              ? ((success / attempts) * 100).toStringAsFixed(1)
                              : '0.0';

                          return Card(
                            color: player['connected']
                                ? null
                                : Colors.grey[200], // Gris si déconnecté
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: player['connected']
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  if (!player['connected'])
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Icon(
                                        Icons.link_off,
                                        size: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  if (player['isCaptain'] ==
                                      true) // 🔥 NOUVEAU - Indicateur capitaine
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Icon(
                                        Icons.stars,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Text(player['name']),

                                  if (player['isCaptain'] ==
                                      true) // 🔥 NOUVEAU - Texte capitaine
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        '(Capitaine)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (!player['connected'])
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        '(déconnecté)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(player['team']),
                                  Text(
                                    'Tentatives: $attempts | Réussites: $success | Efficacité: ${efficiency}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                '${player['score']} pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: player['connected']
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              ),
                              onTap: player['connected']
                                  ? () => _showPlayerOptions(player['id'])
                                  : null,
                            ),
                          ); // JOUEURS AVEC MEILLEURE LISIBILITÉ

                          Card(
                            elevation: 3,
                            margin: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: player['connected']
                                      ? Colors.green[50]
                                      : Colors.grey[200],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: player['connected']
                                        ? Colors.green
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: player['connected']
                                          ? Colors.green[700]
                                          : Colors.grey,
                                      size: 24,
                                    ),
                                    if (player['isCaptain'] == true)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.emoji_events,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              title: Text(
                                player['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: player['connected']
                                      ? Colors.grey[900]
                                      : Colors.grey[500],
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player['team'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: player['team'] == 'EQUIPE A'
                                          ? Colors.blue[900]
                                          : Colors.red[700],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tentatives: ${player['attempts'] ?? 0} | Réussites: ${player['success'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: player['connected']
                                      ? Colors.blue[50]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: player['connected']
                                        ? Colors.blue[700]!
                                        : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  '${player['score']} pts',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: player['connected']
                                        ? Colors.blue[900]!
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
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
                  SizedBox(width: 5),
                  ElevatedButton(
                    onPressed: _exportStatsToCSV,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: Icon(Icons.file_download, size: 20),
                  ),
                ],
              ),
              // 🔥 SECTION SIMULATION - FACILE À SUPPRIMER (début)
              /* Card(
                margin: EdgeInsets.all(8),
                color: Colors.purple[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'OUTILS DE TEST',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[800],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed:
                                _simulationService.startCompleteSimulation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _simulationService.isSimulationRunning
                                  ? Colors.red
                                  : Colors.purple,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              _simulationService.isSimulationRunning
                                  ? 'STOP'
                                  : 'SIMUL',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _simulationService.startQuickGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              'QUICK',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.bolt, size: 20),
                            onSelected: (value) {
                              switch (value) {
                                case 'add_players':
                                  _simulationService.addSimulatedPlayers();
                                  break;
                                case 'buzz':
                                  _simulationService.simulateManualBuzz();
                                  break;
                                case 'score':
                                  _simulationService.simulateManualScore();
                                  break;
                                case 'penalty':
                                  _simulationService.simulateManualPenalty();
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'add_players',
                                child: Text('➕ Ajouter joueurs'),
                              ),
                              PopupMenuItem(
                                value: 'buzz',
                                child: Text('🎯 Simuler buzz'),
                              ),
                              PopupMenuItem(
                                value: 'score',
                                child: Text('⭐ Ajouter points'),
                              ),
                              PopupMenuItem(
                                value: 'penalty',
                                child: Text('⛔ Pénalité'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),*/
              // 🔥 SECTION SIMULATION - FACILE À SUPPRIMER (fin)
            ],
          ),
        ),
      ),
    );
  }

  void _exportStatsToCSV() async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.day}/${now.month}/${now.year} ${now.hour}h${now.minute}';

      final StringBuffer csv = StringBuffer();

      // En-tête
      csv.writeln('STATISTIQUES CLASHNOW - $dateStr');
      csv.writeln('Question actuelle: $currentQuestion');
      csv.writeln(
        'Joueurs connectés: ${players.where((p) => p['connected'] == true).length}',
      );
      csv.writeln('');

      // Vérification joueurs
      if (players.isEmpty) {
        csv.writeln('Aucun joueur connecté');
        final text = csv.toString();
        await Clipboard.setData(ClipboardData(text: text));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📊 Statistiques copiées ($dateStr)'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // 🔥 CORRECTION : Top scorer sécurisé
      final topScorer = players.isNotEmpty
          ? players.reduce((a, b) {
              final scoreA = _safeGetInt(a, 'score');
              final scoreB = _safeGetInt(b, 'score');
              return scoreA > scoreB ? a : b;
            })
          : null;

      // Topscores
      csv.writeln('🏆 TOP SCORER');
      if (topScorer != null) {
        csv.writeln(
          'Meilleur joueur: ${topScorer['name']} (${topScorer['team']})',
        );
        csv.writeln('Score: ${_safeGetInt(topScorer, 'score')} points');

        final attempts = _safeGetInt(topScorer, 'attempts');
        final success = _safeGetInt(topScorer, 'success');
        final efficiency = attempts > 0
            ? ((success / attempts) * 100).toStringAsFixed(1)
            : '0.0';
        csv.writeln('Efficacité: $success/$attempts (${efficiency}%)');
      }
      csv.writeln('');

      // Classement individuel sécurisé
      csv.writeln('📊 CLASSEMENT INDIVIDUEL DÉTAILLÉ');
      csv.writeln(
        'Rang,Nom,Équipe,Score,Pénalités,Tentatives,Réussites,Efficacité',
      );

      final sortedPlayers = List.from(players)
        ..sort((a, b) {
          final scoreA = _safeGetInt(a, 'score');
          final scoreB = _safeGetInt(b, 'score');
          return scoreB.compareTo(scoreA);
        });

      for (int i = 0; i < sortedPlayers.length; i++) {
        final player = sortedPlayers[i];
        final attempts = _safeGetInt(player, 'attempts');
        final success = _safeGetInt(player, 'success');
        final efficiency = attempts > 0
            ? ((success / attempts) * 100).toStringAsFixed(1)
            : '0.0';

        csv.writeln(
          '${i + 1},'
          '${player['name']},'
          '${player['team']},'
          '${_safeGetInt(player, 'score')},'
          '${_safeGetInt(player, 'penalties')},'
          '$attempts,'
          '$success,'
          '${efficiency}%',
        );
      }

      // Scores par équipe sécurisés
      csv.writeln('\n👥 SCORES PAR ÉQUIPE');
      csv.writeln('Équipe,Score total,Joueurs,Tentatives,Réussites,Efficacité');

      final teams = _groupPlayersByTeam();
      for (var team in teams.entries) {
        final teamPlayers = team.value;
        final teamScore = _getTeamScoreSafe(team.key);
        final teamAttempts = teamPlayers.fold(
          0,
          (sum, player) => sum + _safeGetInt(player, 'attempts'),
        );
        final teamSuccess = teamPlayers.fold(
          0,
          (sum, player) => sum + _safeGetInt(player, 'success'),
        );
        final teamEfficiency = teamAttempts > 0
            ? ((teamSuccess / teamAttempts) * 100).toStringAsFixed(1)
            : '0.0';

        csv.writeln(
          '${team.key},$teamScore,${teamPlayers.length},$teamAttempts,$teamSuccess,${teamEfficiency}%',
        );
      }

      // Métriques globales sécurisées
      csv.writeln('\n📈 MÉTRIQUES GLOBALES');
      final totalPoints = players.fold(
        0,
        (sum, player) => sum + _safeGetInt(player, 'score'),
      );
      final totalAttempts = players.fold(
        0,
        (sum, player) => sum + _safeGetInt(player, 'attempts'),
      );
      final totalSuccess = players.fold(
        0,
        (sum, player) => sum + _safeGetInt(player, 'success'),
      );
      final totalPenalties = players.fold(
        0,
        (sum, player) => sum + _safeGetInt(player, 'penalties'),
      );
      final globalEfficiency = totalAttempts > 0
          ? ((totalSuccess / totalAttempts) * 100).toStringAsFixed(1)
          : '0.0';

      csv.writeln('Points totaux: $totalPoints');
      csv.writeln('Tentatives totales: $totalAttempts');
      csv.writeln('Réussites totales: $totalSuccess');
      csv.writeln('Efficacité globale: ${globalEfficiency}%');
      csv.writeln('Pénalités totales: $totalPenalties');
      csv.writeln('Taux de réussite: ${globalEfficiency}%');

      // Copie dans le presse-papiers
      final text = csv.toString();
      await Clipboard.setData(ClipboardData(text: text));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📊 Statistiques copiées ($dateStr)'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VOIR',
            onPressed: () => _showEnhancedStatsPreview(text),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 NOUVELLE MÉTHODE POUR ACCÈS SÉCURISÉ AUX DONNÉES
  int _safeGetInt(Map<String, dynamic> player, String key) {
    final value = player[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  // 🔥 VERSION CORRIGÉE DE _getTeamScore
  int _getTeamScoreSafe(String teamName) {
    return players.where((player) => player['team'] == teamName).fold(0, (
      sum,
      player,
    ) {
      return sum + _safeGetInt(player, 'score');
    });
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
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
