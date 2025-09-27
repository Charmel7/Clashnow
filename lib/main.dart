import 'package:clashnow/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/admin_screen.dart';
import 'screens/home_screen.dart';
import 'screens/player_form_screen.dart';
import 'screens/player_screen.dart';
import 'services/network_service.dart';
import 'themes/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //AudioService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NetworkService(),
      child: MaterialApp(
        title: 'CLASHNOW',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/admin': (context) => ChangeNotifierProvider.value(
            value: Provider.of<NetworkService>(context, listen: false),
            child: const AdminScreen(),
          ),
          '/player_form': (context) => const PlayerFormScreen(),
          '/player': (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments
                    as Map<String, dynamic>?;
            return PlayerScreen(
              playerName: args?['playerName'] ?? 'Joueur',
              teamName: args?['teamName'] ?? 'ÉQUIPE A',
            );
          },
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
