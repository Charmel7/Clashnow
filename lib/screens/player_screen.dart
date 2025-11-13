import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

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
  final _audioPlayer = AudioPlayer();
  bool _isBuzzerLocked = false;
  final FocusNode _focusNode = FocusNode(); // To capture keyboard events

  @override
  void initState() {
    super.initState();
    _setupNetworkListener();
    _initAudioPlayer();
    // Request focus to listen to keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/1.mp3');
    } catch (e) {
      debugPrint("Error loading audio source: $e");
    }
  }

  void _sendBuzz() {
    // Prevent buzzing if already locked
    if (_isBuzzerLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Attendez la question suivante...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    final networkService = Provider.of<NetworkService>(context, listen: false);

    try {
      networkService.sendBuzz(widget.playerName, widget.teamName);
      _audioPlayer.play();
      _audioPlayer.seek(Duration.zero);

      if (mounted) {
        setState(() {
          _isBuzzerLocked = true; // Lock locally immediately
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Buzz envoyé ! En attente du premier buzzer...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur de connexion. Veuillez réessayer.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _setupNetworkListener() {
    final networkService = Provider.of<NetworkService>(context, listen: false);

    networkService.messages.listen((message) {
      if (message['type'] == 'score_update' || message['type'] == 'penalty') {
        // Update score for the concerned player
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
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (message['type'] == 'lock_buzzers') {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = message['locked'];
          });

          if (message['locked']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔒 Buzzers verrouillés - Attente réponse admin'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 1),
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
          const SnackBar(
            content: Text('🎮 Partie démarrée ! Prêt à buzzer.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else if (message['type'] == 'next_question') {
        // 🔥 MODIFICATION : Vérifier si on doit déverrouiller toutes les équipes
        final bool unlockAll = message['unlockAll'] ?? false;
        if (mounted) {
          setState(() {
            _isBuzzerLocked =
                !unlockAll; // Si unlockAll est true, déverrouiller
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              unlockAll
                  ? '➡️ Question ${message['questionNumber']} - Toutes les équipes peuvent buzzer !'
                  : '➡️ Question ${message['questionNumber']} - Buzzers activés !',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      } else if (message['type'] == 'lock_team_buzzers') {
        // 🔥 NOUVEAU : Verrouillage par équipe
        if (mounted) {
          final lockedTeam = message['lockedTeam'];
          final unlockedTeam = message['unlockedTeam'];

          // Vérifier si ce joueur est dans l'équipe verrouillée ou déverrouillée
          if (widget.teamName == lockedTeam) {
            setState(() {
              _isBuzzerLocked = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🔒 Votre équipe est verrouillée - Attendez la prochaine question',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (widget.teamName == unlockedTeam) {
            setState(() {
              _isBuzzerLocked = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Votre équipe peut maintenant buzzer !'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else if (message['type'] == 'game_pause') {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = message['paused'];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // 🔥 ENVOYER UN MESSAGE DE DÉCONNEXION
    final networkService = Provider.of<NetworkService>(context, listen: false);
    networkService.sendPlayerLeave(widget.playerName, widget.teamName);

    _audioPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
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
                onPressed: () {
                  // 🔥 ENVOYER DÉCONNEXION AVANT DE QUITTER
                  final networkService = Provider.of<NetworkService>(
                    context,
                    listen: false,
                  );
                  networkService.sendPlayerLeave(
                    widget.playerName,
                    widget.teamName,
                  );
                  Navigator.of(context).pop(true);
                },
                child: const Text('QUITTER'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the entire screen with RawKeyboardListener to capture space bar presses
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.space) {
          _sendBuzz();
        }
      },
      child: WillPopScope(
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
              // Player stats
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Buzzer button
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _sendBuzz,
                    child: // AMÉLIORER LE BUZZER PRINCIPAL
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: _isBuzzerLocked
                            ? Colors.grey[400]
                            : Color(0xFFFF6D00),
                        shape: BoxShape.circle,
                        gradient: _isBuzzerLocked
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF9100), Color(0xFFFF6D00)],
                              ),
                        boxShadow: _isBuzzerLocked
                            ? []
                            : [
                                BoxShadow(
                                  color: Color(0xFFFF6D00).withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Color(0xFFFF6D00).withOpacity(0.2),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                      ),
                      child: AnimatedScale(
                        scale: _isBuzzerLocked ? 0.9 : 1.0,
                        duration: Duration(milliseconds: 200),
                        child: Icon(
                          _isBuzzerLocked
                              ? Icons.lock_outline
                              : Icons.volume_up,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Buzzer message
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
      ),
    );
  }
}
