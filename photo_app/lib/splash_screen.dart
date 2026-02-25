import 'dart:async';
import 'package:Picon/api_service.dart';
import 'package:Picon/home_screen.dart';
import 'package:Picon/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initVideo();

    // Sécurité : on navigue dans tous les cas après 3 secondes
    Future.delayed(const Duration(seconds: 3), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset('assets/splash1.mp4');
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.play();

      // Attendre la fin de la vidéo
      controller.addListener(() {
        if (controller.value.position >= controller.value.duration &&
            controller.value.duration > Duration.zero) {
          _navigateToNextScreen();
        }
      });
    } catch (_) {
      // Si la vidéo échoue, le timer de 3s prendra le relais
    }
  }

  void _navigateToNextScreen() {
    if (_navigated || !mounted) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ApiService.authToken != null && ApiService.userId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userName: ApiService.userName ?? 'Utilisateur',
              userLastName: ApiService.userLastName ?? '',
              userEmail: ApiService.userEmail ?? '',
              userId: ApiService.userId!,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller != null && _controller!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const SizedBox.shrink(), // fond noir propre pendant le chargement
      ),
    );
  }
}
