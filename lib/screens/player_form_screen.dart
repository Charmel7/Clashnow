import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/network_service.dart';

class PlayerFormScreen extends StatefulWidget {
  const PlayerFormScreen({super.key});

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController(
    text: '10.13.21.127',
  ); // IP par défaut
  String? _selectedTeam;
  bool _isConnecting = false;
  String _connectionStatus = '';

  @override
  void initState() {
    super.initState();
    _ipController.text = '10.13.21.127'; // IP typique des hotspots Android
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _connectToGame() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isConnecting = true;
        _connectionStatus = 'Connexion en cours...';
      });

      final networkService = Provider.of<NetworkService>(
        context,
        listen: false,
      );

      try {
        await networkService.joinGame(_ipController.text);
        // ENVOYER LES INFOS JOUEUR APRÈS CONNEXION
        networkService.sendPlayerInfo(
          _nameController.text,
          _selectedTeam ?? 'EQUIPE A',
        ); // Si la connexion réussit
        setState(() {
          _connectionStatus = '✅ Connecté !';
        });

        // Attendre un peu pour montrer le message de succès
        await Future.delayed(const Duration(milliseconds: 500));

        // Naviguer vers l'écran joueur
        Navigator.pushNamed(
          context,
          '/player',
          arguments: {
            'playerName': _nameController.text,
            'teamName': _selectedTeam ?? 'EQUIPE A',
          },
        );
      } catch (e) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = '❌ Erreur: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _testCommonIPs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IPs courantes pour hotspot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IPButton('10.13.21.127', _ipController),
            _IPButton('172.20.10.2', _ipController),
            _IPButton('192.168.0.1', _ipController),
            _IPButton('192.168.1.100', _ipController),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REJOINDRE UN SALON')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // CHAMP IP
              TextFormField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP DU SERVEUR ADMIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: _testCommonIPs,
                    tooltip: 'IPs courantes',
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ENTREZ L\'IP DE L\'ADMIN';
                  }
                  if (!RegExp(
                    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
                  ).hasMatch(value)) {
                    return 'IP INVALIDE';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // CHAMP NOM
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'VOTRE NOM',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ENTREZ VOTRE NOM';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // SELECTION EQUIPE
              DropdownButtonFormField<String>(
                value: _selectedTeam,
                items: const [
                  DropdownMenuItem(value: 'EQUIPE A', child: Text('ÉQUIPE A')),
                  DropdownMenuItem(value: 'EQUIPE B', child: Text('ÉQUIPE B')),
                ],
                onChanged: (value) => setState(() => _selectedTeam = value),
                decoration: const InputDecoration(
                  labelText: 'ÉQUIPE',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null ? 'CHOISISSEZ UNE ÉQUIPE' : null,
              ),

              const SizedBox(height: 20),

              // STATUT CONNEXION
              if (_connectionStatus.isNotEmpty)
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    color: _connectionStatus.contains('✅')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const Spacer(),

              // BOUTON CONNEXION
              ElevatedButton(
                onPressed: _isConnecting ? null : _connectToGame,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isConnecting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 10),
                          Text('CONNEXION...'),
                        ],
                      )
                    : const Text('SE CONNECTER AU SALON'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IPButton extends StatelessWidget {
  final String ip;
  final TextEditingController controller;

  const _IPButton(this.ip, this.controller);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        controller.text = ip;
        Navigator.pop(context);
      },
      child: Text(ip),
    );
  }
}
