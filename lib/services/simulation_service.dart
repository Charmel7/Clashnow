// lib/services/simulation_service.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class SimulationService with ChangeNotifier {
  Timer? _simulationTimer;
  bool _isSimulationRunning = false;
  List<Map<String, dynamic>> _simulatedPlayers = [];
  Random _random = Random();
  Function(Map<String, dynamic>)? _onBuzzCallback;
  Function()? _onNextQuestionCallback;
  Function(Map<String, dynamic>)? _onScoreUpdateCallback;
  Function(Map<String, dynamic>)? _onPenaltyCallback;
  Function(Map<String, dynamic>)? _onPlayerDisconnectCallback;
  Function(List<Map<String, dynamic>>)? _onPlayersUpdateCallback;

  bool get isSimulationRunning => _isSimulationRunning;
  List<Map<String, dynamic>> get simulatedPlayers => _simulatedPlayers;

  // 🔥 INITIALISATION DES CALLBACKS
  void initialize({
    required Function(Map<String, dynamic>) onBuzz,
    required Function() onNextQuestion,
    required Function(Map<String, dynamic>) onScoreUpdate,
    required Function(Map<String, dynamic>) onPenalty,
    required Function(Map<String, dynamic>) onPlayerDisconnect,
    required Function(List<Map<String, dynamic>>) onPlayersUpdate,
  }) {
    _onBuzzCallback = onBuzz;
    _onNextQuestionCallback = onNextQuestion;
    _onScoreUpdateCallback = onScoreUpdate;
    _onPlayerDisconnectCallback = onPlayerDisconnect;
    _onPlayersUpdateCallback = onPlayersUpdate;
  }

  // 🔥 DÉMARRER LA SIMULATION COMPLÈTE
  void startCompleteSimulation() {
    if (_isSimulationRunning) {
      stopSimulation();
      return;
    }

    _isSimulationRunning = true;
    notifyListeners();

    print('🎮 Démarrage de la simulation complète...');

    addSimulatedPlayers();

    // Démarrer le timer de simulation
    _simulationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!_isSimulationRunning) {
        timer.cancel();
        return;
      }
      _simulateRandomEvent();
    });
  }

  // 🔥 ARRÊTER LA SIMULATION
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulationRunning = false;
    _removeSimulatedPlayers();
    notifyListeners();
  }

  // 🔥 SIMULATION RAPIDE
  void startQuickGame() {
    if (_isSimulationRunning) {
      stopSimulation();
    }

    startCompleteSimulation();

    // Simulation rapide d'une partie complète
    Future.delayed(Duration(seconds: 3), () {
      if (!_isSimulationRunning) return;

      // Question 1
      _simulateBuzz();

      Future.delayed(Duration(seconds: 2), () {
        if (!_isSimulationRunning) return;
        _onNextQuestionCallback?.call();

        Future.delayed(Duration(seconds: 3), () {
          if (!_isSimulationRunning) return;

          // Question 2
          _simulateBuzz();

          Future.delayed(Duration(seconds: 2), () {
            if (!_isSimulationRunning) return;
            _onNextQuestionCallback?.call();
          });
        });
      });
    });
  }

  // 🔥 AJOUTER DES JOUEURS SIMULÉS
  void addSimulatedPlayers() {
    final simulatedPlayers = [
      {
        'id': 'sim_john_equipe_a',
        'name': 'John (Sim)',
        'team': 'EQUIPE A',
        'score': 0,
        'penalties': 0,
        'attempts': 0,
        'success': 0,
        'connected': true,
        'isSimulated': true,
      },
      {
        'id': 'sim_jane_equipe_a',
        'name': 'Jane (Sim)',
        'team': 'EQUIPE A',
        'score': 0,
        'penalties': 0,
        'attempts': 0,
        'success': 0,
        'connected': true,
        'isSimulated': true,
      },
      {
        'id': 'sim_bob_equipe_b',
        'name': 'Bob (Sim)',
        'team': 'EQUIPE B',
        'score': 0,
        'penalties': 0,
        'attempts': 0,
        'success': 0,
        'connected': true,
        'isSimulated': true,
      },
      {
        'id': 'sim_alice_equipe_b',
        'name': 'Alice (Sim)',
        'team': 'EQUIPE B',
        'score': 0,
        'penalties': 0,
        'attempts': 0,
        'success': 0,
        'connected': true,
        'isSimulated': true,
      },
    ];

    _simulatedPlayers = simulatedPlayers;
    _onPlayersUpdateCallback?.call(simulatedPlayers);
  }

  // 🔥 SUPPRIMER LES JOUEURS SIMULÉS
  void _removeSimulatedPlayers() {
    _simulatedPlayers.clear();
    _onPlayersUpdateCallback?.call([]);
  }

  // 🔥 ÉVÉNEMENT ALÉATOIRE
  void _simulateRandomEvent() {
    if (!_isSimulationRunning || _simulatedPlayers.isEmpty) return;

    final events = [
      _simulateBuzz,
      simulateMultipleBuzz,
      _simulateScoreUpdate,
      _simulatePenalty,
      _simulatePlayerDisconnect,
    ];

    final randomEvent = events[_random.nextInt(events.length)];
    randomEvent();
  }

  // 🔥 SIMULER UN BUZZ
  void _simulateBuzz() {
    if (_simulatedPlayers.isEmpty) return;

    final randomPlayer =
        _simulatedPlayers[_random.nextInt(_simulatedPlayers.length)];

    print('🎯 Simulation buzz: ${randomPlayer['name']}');

    _onBuzzCallback?.call({
      'type': 'buzz',
      'playerName': randomPlayer['name'],
      'teamName': randomPlayer['team'],
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 🔥 SIMULER DES BUZZ MULTIPLES
  void simulateMultipleBuzz() {
    if (_simulatedPlayers.length < 2) return;

    print('🎯 Simulation multiple buzz');

    // Premier buzz
    final firstPlayer =
        _simulatedPlayers[_random.nextInt(_simulatedPlayers.length)];
    _onBuzzCallback?.call({
      'type': 'buzz',
      'playerName': firstPlayer['name'],
      'teamName': firstPlayer['team'],
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Deuxième buzz après un court délai
    Future.delayed(Duration(milliseconds: 500), () {
      if (!_isSimulationRunning) return;

      List<Map<String, dynamic>> otherPlayers = _simulatedPlayers
          .where((p) => p['id'] != firstPlayer['id'])
          .toList();

      if (otherPlayers.isNotEmpty) {
        final secondPlayer = otherPlayers[_random.nextInt(otherPlayers.length)];
        _onBuzzCallback?.call({
          'type': 'buzz',
          'playerName': secondPlayer['name'],
          'teamName': secondPlayer['team'],
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  // 🔥 SIMULER UN SCORE
  void _simulateScoreUpdate() {
    if (_simulatedPlayers.isEmpty) return;

    final randomPlayer =
        _simulatedPlayers[_random.nextInt(_simulatedPlayers.length)];
    final points = [5, 10][_random.nextInt(2)];

    print('⭐ Simulation score: +$points pour ${randomPlayer['name']}');

    _onScoreUpdateCallback?.call({
      'playerId': randomPlayer['id'],
      'playerName': randomPlayer['name'],
      'teamName': randomPlayer['team'],
      'points': points,
      'totalScore': (randomPlayer['score'] ?? 0) + points,
    });
  }

  // 🔥 SIMULER UNE PÉNALITÉ
  void _simulatePenalty() {
    if (_simulatedPlayers.isEmpty) return;

    final randomPlayer =
        _simulatedPlayers[_random.nextInt(_simulatedPlayers.length)];

    print('⛔ Simulation pénalité: ${randomPlayer['name']}');

    _onPenaltyCallback?.call({
      'playerId': randomPlayer['id'],
      'playerName': randomPlayer['name'],
      'teamName': randomPlayer['team'],
      'points': -5,
      'totalScore': (randomPlayer['score'] ?? 0) - 5,
    });
  }

  // 🔥 SIMULER UNE DÉCONNEXION
  void _simulatePlayerDisconnect() {
    if (_simulatedPlayers.isEmpty) return;

    final randomPlayer =
        _simulatedPlayers[_random.nextInt(_simulatedPlayers.length)];

    print('📤 Simulation déconnexion: ${randomPlayer['name']}');

    _onPlayerDisconnectCallback?.call({
      'playerId': randomPlayer['id'],
      'playerName': randomPlayer['name'],
      'teamName': randomPlayer['team'],
    });

    // Simuler la reconnexion après un délai
    Future.delayed(Duration(seconds: 3), () {
      if (_isSimulationRunning) {
        print('🔄 Simulation reconnexion: ${randomPlayer['name']}');
        // Pour la reconnexion, on pourrait ajouter un callback si nécessaire
      }
    });
  }

  // 🔥 ACTIONS MANUELLES
  void simulateManualBuzz() => _simulateBuzz();
  void simulateManualScore() => _simulateScoreUpdate();
  void simulateManualPenalty() => _simulatePenalty();
  void simulateManualDisconnect() => _simulatePlayerDisconnect();

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
