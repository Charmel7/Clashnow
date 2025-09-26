import 'package:flutter/material.dart';

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
              onPressed: () {
                Navigator.pushNamed(context, '/admin');
              },
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
