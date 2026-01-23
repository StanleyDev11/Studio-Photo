import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:photo_app/receipt_screen.dart';
import 'package:photo_app/utils/colors.dart';
import 'package:photo_app/utils/geometric_background.dart';
import 'package:photo_app/widgets/music_wave_loader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class PaymentSelectionScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> orderDetails;

  const PaymentSelectionScreen({super.key, required this.orderDetails});

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  String? _selectedMethodName;

  final List<Map<String, String>> _paymentMethods = [
    {'name': 'MasterCard / VISA', 'logo': 'assets/logos/mastercard.png', 'description': 'Payez en toute sécurité avec votre carte bancaire.'},
    {'name': 'Flooz', 'logo': 'assets/logos/flooz.webp', 'description': 'Utilisez votre compte Flooz pour un paiement rapide et facile.'},
    {'name': 'Mix by Yass', 'logo': 'assets/logos/mixbyyass.jpg', 'description': 'Mode de paiement local, contactez le service client pour finaliser.'},
  ];

  void _onMethodSelected(String methodName) {
    setState(() {
      _selectedMethodName = methodName;
    });
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: MusicWaveLoader(),
          ),
        ),
      ),
    );
  }

  String _formatWhatsAppMessage(String orderId) {
    // TODO: Fetch real user info (name, phone number) instead of placeholders
    const userName = "John Doe"; 
    const userPhone = "+22890000000";

    final buffer = StringBuffer();
    buffer.writeln("🎉 *Nouvelle Commande Reçue* 🎉");
    buffer.writeln("---------------------------------");
    buffer.writeln("*Commande ID:* $orderId");
    buffer.writeln("*Client:* $userName");
    buffer.writeln("*Contact:* $userPhone");
    buffer.writeln("*Mode de paiement:* $_selectedMethodName");
    buffer.writeln("---------------------------------");
    buffer.writeln("*Détails de la commande:*");

    widget.orderDetails.forEach((key, details) {
      buffer.writeln("- Photo: ${key.split('/').last}"); // Show only filename
      buffer.writeln("  Taille: ${details['size']}");
      buffer.writeln("  Quantité: ${details['quantity']}");
    });
    
    buffer.writeln("---------------------------------");
    buffer.writeln("Merci de traiter cette commande.");

    return buffer.toString();
  }

  Future<void> _launchWhatsApp() async {
    // TODO: Replace with the provider's real phone number
    const prestatairePhoneNumber = "+22892595661"; 
    final message = _formatWhatsAppMessage(const Uuid().v4()); // Use a generated order ID for WhatsApp
    
    // Use the universal wa.me link which is more reliable
    final universalUrl = Uri.parse("https://wa.me/$prestatairePhoneNumber?text=${Uri.encodeComponent(message)}");

    try {
      // Attempt to launch the URL. 
      // The `mode` LaunchMode.externalApplication is important to prefer opening the app
      // instead of an in-app browser.
      if (!await launchUrl(universalUrl, mode: LaunchMode.externalApplication)) {
        throw 'Impossible de lancer WhatsApp.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du lancement de WhatsApp: $e')),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    if (_selectedMethodName == null) return;

    _showLoadingDialog();
    
    // Generate a unique Order ID
    final String orderId = const Uuid().v4(); // Generate a UUID for the order ID

    // 1. Simulate payment processing
    await Future.delayed(const Duration(seconds: 3));

    // 2. Pop loader
    if(mounted) Navigator.of(context).pop();

    // 3. Launch WhatsApp with order details
    await _launchWhatsApp();

    // 4. Navigate to final receipt screen
    if(mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScreen(
            orderDetails: widget.orderDetails,
            paymentMethod: _selectedMethodName!,
            orderId: orderId,
            // Pass real user name and phone if available
            userName: "John Doe", 
            userPhone: "+22890000000",
          ),
        ),
      );
    }
  }

  String _getDescription(String? methodName) {
    if (methodName == null) return '';
    try {
      final method = _paymentMethods.firstWhere((m) => m['name'] == methodName);
      return method['description'] ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir le mode de paiement'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Stack(
        children: [
          const GeometricBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Veuillez choisir votre mode de paiement :',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _paymentMethods.length,
                              itemBuilder: (context, index) {
                                final method = _paymentMethods[index];
                                final isSelected = method['name'] == _selectedMethodName;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: GestureDetector(
                                    onTap: () => _onMethodSelected(method['name']!),
                                    child: AnimatedContainer(
                                      duration: 300.ms,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.4),
                                          width: isSelected ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16.0),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.asset(
                                            method['logo']!,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        title: Text(
                                          method['name']!,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        trailing: AnimatedOpacity(
                                          opacity: isSelected ? 1.0 : 0.0,
                                          duration: 300.ms,
                                          child: const Icon(Icons.check_circle, color: AppColors.primary, size: 30),
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1);
                              },
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: 300.ms,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            child: Padding(
                              key: ValueKey<String>(_selectedMethodName ?? ''),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              child: Text(
                                _getDescription(_selectedMethodName),
                                style: const TextStyle(color: Colors.black, fontSize: 14),
                                
                                textAlign: TextAlign.center,
                                
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildConfirmButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    bool isVisible = _selectedMethodName != null;
    return AnimatedContainer(
      duration: 300.ms,
      height: isVisible ? 100 : 0,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.textOnPrimary,
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _processPayment,
            child: const Text(
              'Payer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}