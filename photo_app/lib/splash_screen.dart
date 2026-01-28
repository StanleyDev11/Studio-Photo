import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_app/api_service.dart'; // Import ApiService
import 'package:photo_app/home_screen.dart'; // Import HomeScreen
import 'package:photo_app/login_screen.dart'; // Import LoginScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  int _currentVideoIndex = 0;
  final List<String> _videoAssets = [
    // 'assets/splash.mp4',
    'assets/splash1.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _playVideo(index: 0);
  }

  void _playVideo({required int index}) {
    if (index >= _videoAssets.length) {
      _navigateToNextScreen();
      return;
    }

    _currentVideoIndex = index;

    _controller?.dispose();

    _controller = VideoPlayerController.asset(_videoAssets[_currentVideoIndex])
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller?.play();
        }
      })
      ..addListener(() {
        if (_controller!.value.position == _controller!.value.duration) {
          if (mounted) {
            _playVideo(index: _currentVideoIndex + 1);
          }
        }
      });
  }

  void _navigateToNextScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (ApiService.authToken != null && ApiService.userId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: 'Utilisateur', // Default name from token, will be replaced with actual user data if API provides it
                userId: ApiService.userId!, userEmail: '',
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
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
      backgroundColor: Colors.white,
      body: Center(
        child: _controller != null && _controller!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
      ),
    );
  }
}
