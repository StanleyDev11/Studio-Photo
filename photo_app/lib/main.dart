import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            );
          case '/signup':
            return MaterialPageRoute(
              builder: (context) => const SignupScreen(),
            );
          case '/home':
            final args = settings.arguments as Map<String, dynamic>?; // Récupération des arguments
            return MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: args?['userName'] ?? 'Utilisateur',
                userId: args?['userId'] ?? '',
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            );
        }
      },
    );
  }
}
