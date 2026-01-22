import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_app/login_screen.dart'; // Assurez-vous que le chemin est correct

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  int _currentVideoIndex = 0;
  final List<String> _videoAssets = [
    'assets/splash.mp4',
    'assets/splash1.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _playVideo(index: 0);
  }

  void _playVideo({required int index}) {
    // Si on a joué toutes les vidéos, on navigue
    if (index >= _videoAssets.length) {
      _navigateToHome();
      return;
    }

    // Met à jour l'index actuel
    _currentVideoIndex = index;

    // Nettoie l'ancien contrôleur s'il existe
    _controller?.dispose();

    // Initialise le nouveau contrôleur
    _controller = VideoPlayerController.asset(_videoAssets[_currentVideoIndex])
      ..initialize().then((_) {
        // Met à jour l'interface et démarre la vidéo
        if (mounted) {
          setState(() {});
          _controller?.play();
        }
      });
      
    // Planifie la prochaine action dans 2.5 secondes
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        // Passe à la vidéo suivante
        _playVideo(index: _currentVideoIndex + 1);
      }
    });
  }

  void _navigateToHome() {
    // Assurez-vous que la navigation se fait après la construction de l'arbre de widgets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    // Nettoie le contrôleur pour éviter les fuites de mémoire
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _controller != null && _controller!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const CircularProgressIndicator( // Indicateur de chargement en attendant
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
      ),
    );
  }
}
