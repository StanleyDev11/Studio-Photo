import 'dart:ui';

import 'package:Picon/api_service.dart';
import 'package:Picon/receipt_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String orderId;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = ApiService.pendingOrderDetails != null &&
        ApiService.pendingPrices != null &&
        ApiService.pendingPaymentMethod != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement confirmé'),
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
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 40),
                        )
                            .animate()
                            .scale(duration: 450.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 16),
                        const Text(
                          'Paiement réussi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Commande #$orderId',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!hasPending) {
                                Navigator.of(context).popUntil((r) => r.isFirst);
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReceiptScreen(
                                    orderDetails:
                                        ApiService.pendingOrderDetails!,
                                    paymentMethod:
                                        ApiService.pendingPaymentMethod!,
                                    orderId: orderId,
                                    prices: ApiService.pendingPrices!,
                                    userName:
                                        ApiService.userName ?? "Client",
                                    userPhone:
                                        ApiService.userEmail ?? "",
                                  ),
                                ),
                              ).then((_) => ApiService.clearPendingPayment());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(hasPending
                                ? 'Voir le reçu'
                                : 'Aller à l’accueil'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).popUntil((r) => r.isFirst),
                          child: const Text('Fermer'),
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
