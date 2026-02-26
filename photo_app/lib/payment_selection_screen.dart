import 'dart:ui';
import 'package:Picon/api_service.dart';
import 'package:Picon/models/contact_info.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:Picon/widgets/music_wave_loader.dart';
import 'package:Picon/payment_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:feda_flutter/feda_flutter.dart';

class PaymentSelectionScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> orderDetails;
  final double totalAmount;
  final bool isExpress;
  final String? customerFirstname;
  final String? customerLastname;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerCountry;
  final String? deliveryAddress;

  const PaymentSelectionScreen({
    super.key,
    required this.orderDetails,
    required this.totalAmount,
    required this.isExpress,
    this.customerFirstname,
    this.customerLastname,
    this.customerEmail,
    this.customerPhone,
    this.customerCountry,
    this.deliveryAddress,
  });

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  String? _selectedMethodName = 'FedaPay';
  Map<String, double>? _prices;
  bool _isLoadingPrices = true;

  final List<Map<String, String>> _paymentMethods = [
    {
      'name': 'FedaPay',
      'logo': 'assets/logos/pro.png',
      'description': 'Paiement sécurisé via Mobile Money (dans l\'application).'
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchPrices();
    // _fetchContactInfo(); // Removed: no longer needed
    // Clé FedaPay : injectée au build via --dart-define=FEDAPAY_API_KEY=pk_live_xxx
    // En dev sans dart-define, bascule automatiquement sur la clé sandbox.
    const fedaApiKey = String.fromEnvironment(
      'FEDAPAY_API_KEY',
      defaultValue: 'pk_sandbox_T07_uKrSPDbodUlB0zTbAoGb',
    );
    const fedaEnv = String.fromEnvironment(
      'FEDAPAY_ENV',
      defaultValue: 'sandbox',
    );
    final feda = FedaFlutter(
      apiKey: fedaApiKey,
      environment: fedaEnv == 'live'
          ? ApiEnvironment.live
          : ApiEnvironment.sandbox,
    );
    feda.initialize();
  }

  Future<void> _fetchPrices() async {
    try {
      final dimensions = await ApiService.fetchDimensions();
      if (mounted) {
        setState(() {
          _prices = {for (var dim in dimensions) dim.dimension: dim.price};
          _isLoadingPrices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)));
        setState(() {
          _isLoadingPrices = false;
        });
      }
    }
  }

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

  Future<void> _processPayment() async {
    if (_selectedMethodName == null || _prices == null) return;

    _showLoadingDialog();

    try {
      final List<Map<String, dynamic>> items =
          widget.orderDetails.entries.map((entry) {
        final details = entry.value;
        return {
          'imageUrl': entry.key,
          'size': details['size'],
          'quantity': details['quantity'],
          'price': _prices![details['size']], // Add price per unit if needed by backend for order item creation
        };
      }).toList();

      if (ApiService.userId == null) {
        throw "Veuillez vous reconnecter pour continuer le paiement.";
      }

      final orderPayload = {
        'isExpress': widget.isExpress, // Use widget.isExpress
        'paymentMethod': _selectedMethodName!,
        'items': items,
        'userId': ApiService.userId,
        'totalAmount': widget.totalAmount, // Pass totalAmount
        'customerFirstname': widget.customerFirstname,
        'customerLastname': widget.customerLastname,
        'customerEmail': widget.customerEmail,
        'customerPhone': widget.customerPhone,
        'customerCountry': widget.customerCountry,
        'deliveryAddress': widget.deliveryAddress,
      };

      // --- Payment Integration Logic ---
      String paymentUrl = "";
      if (_selectedMethodName == 'FedaPay') {
         final response = await ApiService.initiateFedapayPayment(orderPayload);
         paymentUrl = response['paymentUrl'] as String;
         final orderId = response['orderId'] as String;
         ApiService.setPendingPayment(
           orderDetails: widget.orderDetails,
           prices: _prices!,
           paymentMethod: _selectedMethodName!,
           orderId: orderId,
         );
      } else {
        throw "Méthode de paiement non supportée.";
      }

      if (mounted) Navigator.of(context).pop(); // Pop loader

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewScreen(
              paymentUrl: paymentUrl,
            ),
          ),
        );
      }

      // On attend le deep link de succès/annulation avant d'aller au reçu.
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Pop loader on error
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red),
        );
      }
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
        title: const Text('Confirmation finale'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body:
          (_isLoadingPrices /* || _isLoadingContactInfo */) // _isLoadingContactInfo removed
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    GeometricBackground(),
                    Column(
                      children: [
                        // ── Badge montant total ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total à payer',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${widget.totalAmount.toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Veuillez confirmer vos informations avant de procéder au paiement sécurisé.',
                            style: TextStyle(color: AppColors.textPrimary.withOpacity(0.7), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Bloc Info Client
                                _buildInfoCard(
                                  title: 'Informations de livraison',
                                  icon: Icons.local_shipping_outlined,
                                  children: [
                                    _buildInfoRow(Icons.person_outline, 'Destinataire', '${widget.customerFirstname} ${widget.customerLastname}'),
                                    _buildInfoRow(Icons.phone_outlined, 'Téléphone', widget.customerPhone ?? 'Non spécifié'),
                                    _buildInfoRow(Icons.map_outlined, 'Adresse de livraison', widget.deliveryAddress ?? "Non spécifiée"),
                                    _buildInfoRow(Icons.speed_outlined, 'Mode de retrait', widget.isExpress ? "Express (Prioritaire)" : "Standard"),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Bloc Logos de confiance
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.lock_outline, size: 16, color: Colors.green),
                                          SizedBox(width: 8),
                                          Text(
                                            'Paiement 100% sécurisé',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildTrustLogo('assets/logos/pro.png'), // Feda
                                          _buildTrustLogo('assets/logos/mixbyyass.jpg'), // Yass
                                          _buildTrustLogo('assets/logos/mastercard.png'),
                                          _buildTrustLogo('assets/logos/flooz.webp'),
                                          const Icon(Icons.credit_card, size: 32, color: AppColors.primary),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Cartes Bancaires & Mobile Money (MTN, Moov, Flooz, MixxYas Wave)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary, letterSpacing: 0.3)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5, color: Colors.white24),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary.withOpacity(0.6)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustLogo(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Image.asset(assetPath, width: 35, height: 25, fit: BoxFit.contain),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.textOnPrimary,
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
        onPressed: _processPayment,
        child: Text(
          'Confirmer et Payer ${widget.totalAmount.toStringAsFixed(0)} FCFA',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
