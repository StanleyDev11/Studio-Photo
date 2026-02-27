// import 'dart:async';
// import 'package:Picon/api_service.dart';
// import 'package:Picon/home_screen.dart';
// import 'package:Picon/login_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   bool _navigated = false;

//   @override
//   void initState() {
//     super.initState();
//     // Navigation occurs strictly after 3 seconds
//     Future.delayed(const Duration(seconds: 3), () {
//       _navigateToNextScreen();
//     });
//   }

//   void _navigateToNextScreen() {
//     if (_navigated || !mounted) return;
//     _navigated = true;

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       if (ApiService.authToken != null && ApiService.userId != null) {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(
//             builder: (context) => HomeScreen(
//               userName: ApiService.userName ?? 'Utilisateur',
//               userLastName: ApiService.userLastName ?? '',
//               userEmail: ApiService.userEmail ?? '',
//               userId: ApiService.userId!,
//             ),
//           ),
//         );
//       } else {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const LoginScreen()),
//         );
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Image.asset(
//           'assets/images/pro.png',
//           width: 250,
//         )
//         .animate()
//         .fadeIn(duration: 800.ms)
//         .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 800.ms, curve: Curves.easeOutBack)
//         .then(delay: 400.ms)
//         .shimmer(duration: 1200.ms, color: Colors.grey.withOpacity(0.3)),
//       ),
//     );
//   }
// }
