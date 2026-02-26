import 'dart:ui';

import 'package:Picon/api_service.dart';
import 'package:Picon/history_screen.dart';
import 'package:Picon/receipt_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String orderId;

  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
  });

  /// Navigue vers l'accueil puis vers l'historique pour éviter le bug de déconnexion.
  void _goToHistory(BuildContext context) {
    ApiService.clearPendingPayment();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {
        'userName': ApiService.userName,
        'userLastName': ApiService.userLastName,
        'userEmail': ApiService.userEmail,
        'userId': ApiService.userId,
      },
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  void _goToHome(BuildContext context) {
    ApiService.clearPendingPayment();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {
        'userName': ApiService.userName,
        'userLastName': ApiService.userLastName,
        'userEmail': ApiService.userEmail,
        'userId': ApiService.userId,
      },
    );
  }

  Future<void> _sendWhatsAppSummary(BuildContext context) async {
    try {
      final contact = await ApiService.fetchContactInfo();
      final phone = contact.phoneNumber.replaceAll(RegExp(r'\s+'), '');
      
      final buffer = StringBuffer();
      buffer.writeln("🎉 *Nouvelle Commande Reçue * 🎉");
      buffer.writeln("---------------------------------");
      buffer.writeln("*Commande ID:* $orderId");
      buffer.writeln("*Client:* ${ApiService.userName} ${ApiService.userLastName}");
      buffer.writeln("*Contact:* ${ApiService.userPhone ?? ApiService.userEmail}"); 
      buffer.writeln("*Mode de paiement:* ${ApiService.pendingPaymentMethod ?? 'Mix by Yass'}");
      buffer.writeln("---------------------------------");
      buffer.writeln("*Détails de la commande:*");

      if (ApiService.pendingOrderDetails != null) {
        ApiService.pendingOrderDetails!.forEach((imageUrl, details) {
          final fileName = imageUrl.split('/').last;
          buffer.writeln("- Photo: $fileName");
          buffer.writeln("  Taille: ${details['size']}");
          buffer.writeln("  Quantité: ${details['quantity']}");
        });
      }
      
      buffer.writeln("---------------------------------");
      buffer.writeln("Merci de traiter cette commande.");

      final message = Uri.encodeComponent(buffer.toString());
      final whatsappUrl = Uri.parse("whatsapp://send?phone=$phone&text=$message");
      final webUrl = Uri.parse("https://wa.me/$phone?text=$message");

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Impossible de lancer WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur WhatsApp : $e"), backgroundColor: Colors.orange),
        );
      }
    }
  }

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
        automaticallyImplyLeading: false, // Pas de retour arrière possible
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
                        // Icône de succès animée
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
                            .scale(
                                duration: 450.ms,
                                curve: Curves.easeOutBack),
                        const SizedBox(height: 16),
                        const Text(
                          'Paiement réussi !',
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
                        const SizedBox(height: 6),
                        const Text(
                          'Votre commande est en cours de traitement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bouton "Voir le reçu" (si données disponibles)
                        if (hasPending)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Voir le reçu'),
                              onPressed: () {
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
                                ).then((_) => _goToHistory(context));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // Bouton principal : envoyer WhatsApp et aller à l'historique
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.history_outlined),
                            label: const Text('Envoyer WhatsApp & Voir commandes'),
                            onPressed: () {
                              _sendWhatsAppSummary(context);
                              _goToHistory(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Nouveau bouton : Retour à l'accueil (Bouton d'action secondaire propre)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.home_outlined),
                            label: const Text("Page d'accueil"),
                            onPressed: () => _goToHome(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

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
