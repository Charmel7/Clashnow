import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

//import '../services/audio_service.dart';
import '../services/network_service.dart';

class PlayerScreen extends StatefulWidget {
  final String playerName;
  final String teamName;

  const PlayerScreen({
    super.key,
    required this.playerName,
    required this.teamName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int score = 0;
  bool isBuzzerLocked = false;
  /*
  void buzz() {
    if (!isBuzzerLocked) {
      setState(() {
        isBuzzerLocked = true;
      });

      // Simuler l'envoi du buzzer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buzz envoyé !'),
          backgroundColor: Colors.green,
        ),
      );

      // Déverrouiller après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            isBuzzerLocked = false;
          });
        }
      });
    }
  }*/
  bool _isBuzzerLocked = false;
  void _sendBuzz() {
    // EMPÊCHER LE BUZZ SI DÉJÀ VERROUILLÉ
    if (_isBuzzerLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Attendez la question suivante...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final networkService = Provider.of<NetworkService>(context, listen: false);

    try {
      // AudioService.playBuzz();
      networkService.sendBuzz(widget.playerName, widget.teamName);

      setState(() {
        _isBuzzerLocked = true; // Verrouiller localement immédiatement
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Buzz envoyé ! En attente du premier buzzer...'),
          backgroundColor: Colors.green,
        ),
      );

      // NE PAS DÉVERROUILLER AUTOMATIQUEMENT - l'admin contrôle ça
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _setupNetworkListener();
  }

  // Dans _PlayerScreenState - MODIFIER le listener
  void _setupNetworkListener() {
    final networkService = Provider.of<NetworkService>(context, listen: false);

    networkService.messages.listen((message) {
      if (message['type'] == 'score_update' || message['type'] == 'penalty') {
        // METTRE À JOUR LE SCORE DU JOUEUR CONCERNÉ
        if (message['playerName'] == widget.playerName) {
          final newScore =
              message['totalScore'] ?? (score + (message['points'] ?? 0));
          if (mounted) {
            setState(() {
              score = newScore;
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message['type'] == 'penalty'
                    ? '⛔ Pénalité: ${message['points']} pts. Total: $newScore'
                    : '🎉 +${message['points']} points ! Total: $newScore',
              ),
              backgroundColor: message['type'] == 'penalty'
                  ? Colors.orange
                  : Colors.green,
            ),
          );
        }
      } else if (message['type'] == 'lock_buzzers') {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = message['locked'];
          });

          // Feedback visuel selon l'état
          if (message['locked']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔒 Buzzers verrouillés - Attente réponse admin'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (message['type'] == 'game_start') {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎮 Partie démarrée ! Prêt à buzzer.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (message['type'] == 'next_question') {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '➡️ Question ${message['questionNumber']} - Buzzers activés !',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (message['type'] == 'game_pause') {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = message['paused'];
          });
        }
      }
    });
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quitter le jeu ?'),
            content: const Text('Vous serez déconnecté du salon.'),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.playerName),
              Text(widget.teamName, style: const TextStyle(fontSize: 14)),
            ],
          ),
          backgroundColor: Colors.blueGrey[800],
        ),
        body: Column(
          children: [
            // STATS DU JOUEUR
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('SCORE'),
                          Text(
                            '$score',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('ÉQUIPE'),
                          Text(
                            widget.teamName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BUZZER
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _sendBuzz,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _isBuzzerLocked ? Colors.grey : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (!_isBuzzerLocked)
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Icon(
                      _isBuzzerLocked ? Icons.lock : Icons.volume_up,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // MESSAGE BUZZER
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _isBuzzerLocked ? 'BUZZ ENVOYÉ' : 'APPUYEZ POUR BUZZER',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
