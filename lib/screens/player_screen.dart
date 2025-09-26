import 'package:flutter/material.dart';
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
    final networkService = Provider.of<NetworkService>(context, listen: false);

    try {
      networkService.sendBuzz(widget.playerName, widget.teamName);

      setState(() {
        _isBuzzerLocked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Buzz envoyé !'),
          backgroundColor: Colors.green,
        ),
      );

      // Déverrouiller après 5 secondes
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isBuzzerLocked = false;
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
