import 'dart:async';
import 'dart:ui';

import 'package:Picon/api_service.dart';
import 'package:Picon/payment_success_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:Picon/widgets/music_wave_loader.dart';
import 'package:flutter/material.dart';

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

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  Timer? _timer;
  bool _isChecking = false;
  int _attempts = 0;
  final int _maxAttempts = 12;
  final Duration _interval = const Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _checkStatus());
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    if (_attempts >= _maxAttempts) return;
    setState(() {
      _isChecking = true;
      _attempts += 1;
    });

    try {
      String status = 'pending';
      String? orderId = widget.orderId ?? ApiService.pendingOrderId;

      if (widget.transactionId != null && widget.transactionId!.isNotEmpty) {
        final verify =
            await ApiService.verifyFedapayTransaction(widget.transactionId!);
        status = (verify['status'] ?? 'pending').toString();
        orderId = (verify['orderId'] ?? orderId ?? '').toString();
      } else if (orderId != null && orderId.isNotEmpty) {
        final order = await ApiService.fetchOrderById(orderId);
        if (order != null) {
          status = order.status.toLowerCase() == 'processing'
              ? 'approved'
              : order.status.toLowerCase();
        }
      }

      if (status == 'approved') {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              orderId: orderId ?? '',
            ),
          ),
        );
      } else if (status == 'canceled' || status == 'failed') {
        _timer?.cancel();
        ApiService.clearPendingPayment();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Paiement échoué ou annulé."),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      // silent retry
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement en attente'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GeometricBackground()),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MusicWaveLoader(),
                        const SizedBox(height: 16),
                        const Text(
                          'Nous vérifions votre paiement...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tentatives: $_attempts / $_maxAttempts',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isChecking ? null : _checkStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Vérifier maintenant'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Retour'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
