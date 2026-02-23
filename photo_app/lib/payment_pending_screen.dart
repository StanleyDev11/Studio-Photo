import 'dart:async';
import 'dart:ui';

import 'package:Picon/api_service.dart';
import 'package:Picon/history_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:Picon/widgets/music_wave_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// États de la vérification du paiement
enum _PayState { checking, success, failed, timeout }

class PaymentPendingScreen extends StatefulWidget {
  final String? transactionId;
  final String? orderId;

  const PaymentPendingScreen({
    super.key,
    this.transactionId,
    this.orderId,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen>
    with WidgetsBindingObserver {
  _PayState _state = _PayState.checking;
  String? _resolvedOrderId;

  // Polling : max 2 minutes (intervalle de 5 s pour ne pas saturer le serveur)
  Timer? _pollTimer;
  int _attempts = 0;
  final int _maxAttempts = 24; // 24 * 5s = 120s (2 minutes)
  final Duration _pollInterval = const Duration(seconds: 5);

  // Compte à rebours de 3 s après succès → redirection auto
  int _successCountdown = 3;
  Timer? _successTimer;

  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolvedOrderId = widget.orderId ?? ApiService.pendingOrderId;
    _startChecking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      if (_state == _PayState.checking) {
        _checkOnce();
        _pollTimer = Timer.periodic(_pollInterval, (_) => _checkOnce());
      }
    }
  }

  void _startChecking() {
    _attempts = 0;
    _checkOnce(); // Première vérif immédiate
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkOnce());
  }

  Future<void> _checkOnce() async {
    if (_state != _PayState.checking) return;
    
    _attempts++;

    try {
      String status = 'pending';

      // ── Stratégie 1 : check via BDD (webhook FedaPay déjà traité) ──
      if (_resolvedOrderId != null && _resolvedOrderId!.isNotEmpty) {
        final order = await ApiService.fetchOrderById(_resolvedOrderId!);
        if (order != null) {
          final s = order.status.toUpperCase();
          if (s == 'PROCESSING' || s == 'CONFIRMED' || s == 'COMPLETED') {
            status = 'approved';
          } else if (s == 'CANCELLED') {
            status = 'canceled';
          }
        }
      }

      // ── Stratégie 2 : si toujours pending, appel direct FedaPay ──
      if (status == 'pending' &&
          widget.transactionId != null &&
          widget.transactionId!.isNotEmpty) {
        final verify =
            await ApiService.verifyFedapayTransaction(widget.transactionId!);
        final feda = (verify['status'] ?? 'pending').toString();
        if (feda == 'approved') {
          status = 'approved';
          final fromVerify = (verify['orderId'] ?? '').toString();
          if (fromVerify.isNotEmpty) _resolvedOrderId = fromVerify;
        } else if (feda == 'canceled' || feda == 'failed') {
          status = 'canceled';
        }
      }

      if (!mounted) return;

      if (status == 'approved') {
        _onSuccess();
      } else if (status == 'canceled') {
        _onFailed();
      } else if (_attempts >= _maxAttempts) {
        _onTimeout();
      }
    } catch (_) {
      if (_attempts >= _maxAttempts) _onTimeout();
    }
  }

  void _onSuccess() {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _state = _PayState.success;
      _successCountdown = 3;
    });
    // Compte à rebours 3 s → redirection auto
    _successTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_successCountdown > 0) _successCountdown--;
      });
      if (_successCountdown <= 0) {
        t.cancel();
        _goToHistory();
      }
    });
  }

  void _onFailed() {
    _pollTimer?.cancel();
    if (!mounted) return;
    ApiService.clearPendingPayment();
    setState(() => _state = _PayState.failed);
  }

  void _onTimeout() {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() => _state = _PayState.timeout);
  }

  void _goToHistory() {
    ApiService.clearPendingPayment();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _retryChecking() {
    setState(() {
      _state = _PayState.checking;
    });
    _startChecking();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_state != _PayState.checking) _goToHistory();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: GeometricBackground()),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _state == _PayState.checking
                    ? _buildCheckingView()
                    : _state == _PayState.success
                        ? _buildSuccessView()
                        : _buildErrorView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckingView() {
    return Center(
      key: const ValueKey('checking'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MusicWaveLoader(),
            const SizedBox(height: 32),
            const Text(
              'Vérification en cours...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nous confirmons la réception de votre paiement.\nCela ne prendra que quelques instants.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 60),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            const Text(
              'Paiement Réussi !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Merci pour votre confiance.\nRedirection automatique dans $_successCountdown s...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final isTimeout = _state == _PayState.timeout;
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isTimeout ? Colors.orange : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTimeout ? Icons.hourglass_empty : Icons.close,
                color: Colors.white,
                size: 60,
              ),
            ).animate().shake(duration: 400.ms),
            const SizedBox(height: 24),
            Text(
              isTimeout ? 'Délai expiré' : 'Paiement échoué',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isTimeout ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTimeout
                  ? 'La confirmation prend plus de temps que prévu.\nSi vous avez reçu le mail de confirmation, vérifiez vos commandes.'
                  : 'Une erreur est survenue lors du paiement.\nVeuillez réessayer ou contacter le support.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _retryChecking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: _goToHistory,
              child: const Text('Voir mes commandes', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
