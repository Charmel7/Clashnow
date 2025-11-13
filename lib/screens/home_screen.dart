import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

bool get isWindows {
  if (kIsWeb) return false; // Web n'est pas Windows
  return Platform.isWindows;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CLASHNOW')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SYSTEME DE BUZZERS',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: isWindows
                  ? () {
                      Navigator.pushNamed(context, '/admin');
                    }
                  : null,
              child: const Text('CRÉER SALON'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/player_form');
              },
              child: const Text('REJOINDRE SALON'),
            ),
          ],
        ),
      ),
    );
  }
}
