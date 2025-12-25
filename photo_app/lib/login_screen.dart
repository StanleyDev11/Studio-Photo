import 'package:flutter/material.dart';
import 'api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('Veuillez remplir tous les champs.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Log des données reçues pour vérifier la réponse
      print('Réponse de l\'API : $response');

      if (response['success'] == true) {
        final user = response['user'];
        if (user != null && user['name'] != null && user['id'] != null) {
          print('Utilisateur connecté : Nom=${user['name']}, ID=${user['id']}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: user['name'],
                userId: user['id'],
              ),
            ),
          );
        } else {
          _showErrorDialog(
            'Les données utilisateur sont incomplètes dans la réponse du serveur.',
          );
        }
      } else {
        _showErrorDialog(response['message'] ?? 'Erreur de connexion.');
      }
    } catch (e) {
      print('Erreur de connexion : $e');
      _showErrorDialog('Une erreur est survenue : $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String? message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur de connexion'),
        content: Text(message ?? 'Une erreur est survenue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 120,
                child: Image.asset(
                  'assets/images/pro.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bienvenue',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                'Connectez-vous pour accéder à vos albums photo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    debugPrint('Mot de passe oublié cliqué.');
                  },
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14.0,
                          horizontal: 24.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Vous n\'avez pas de compte ?'),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      'Créer un compte',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
