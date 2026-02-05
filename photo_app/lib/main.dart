import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:Picon/signup_screen.dart';
import 'package:Picon/splash_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/police.dart';
import 'package:flutter/material.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for SharedPreferences
  await ApiService.init(); // Initialize ApiService
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo App',
      theme: ThemeData(
        primarySwatch: MaterialColor(AppColors.primary.value, const <int, Color>{
          50: Color(0xFFE8EAF6),
          100: Color(0xFFC5CAE9),
          200: Color(0xFF9FA8DA),
          300: Color(0xFF7986CB),
          400: Color(0xFF5C6BC0),
          500: AppColors.primary,
          600: Color(0xFF3F51B5),
          700: Color(0xFF303F9F),
          800: Color(0xFF283593),
          900: Color(0xFF1A237E),
        }),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        // New: Apply Poppins text theme
        textTheme: buildPoppinsTextTheme(ThemeData.light().textTheme),
        fontFamily: primaryFont.fontFamily, // Set Poppins as default font family
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            );
          case '/signup':
            return MaterialPageRoute(
              builder: (context) => const SignupScreen(),
            );
          case '/home':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: args?['userName'] as String? ?? 'Utilisateur',
                userLastName: args?['userLastName'] as String? ?? '',
                userEmail: args?['userEmail'] as String? ?? '',
                userId: args?['userId'] as int? ?? 0,
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
