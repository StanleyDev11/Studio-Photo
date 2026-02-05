import 'dart:ui';
import 'package:Picon/api_service.dart';
import 'package:Picon/models/contact_info.dart';
import 'package:Picon/receipt_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:Picon/widgets/music_wave_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:feda_flutter/feda_flutter.dart';

class PaymentSelectionScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> orderDetails;
  final double totalAmount;
  final bool isExpress;

  const PaymentSelectionScreen({
    super.key,
    required this.orderDetails,
    required this.totalAmount,
    required this.isExpress,
  });

  @override
  State<PaymentSelectionScreen> createState() => _PaymentSelectionScreenState();
}

class _PaymentSelectionScreenState extends State<PaymentSelectionScreen> {
  String? _selectedMethodName;
  Map<String, double>? _prices;
  bool _isLoadingPrices = true;
  // String _prestatairePhoneNumber = ""; // Removed: no longer needed for static methods
  // bool _isLoadingContactInfo = true; // Removed: no longer needed

  final List<Map<String, String>> _paymentMethods = [
    {
      'name': 'PiconPay',
      'logo': 'assets/logos/pro.png',
      'description': 'Payez via Fedapay (environnement Sandbox).'
    }, // Fedapay is the only method
  ];

  @override
  void initState() {
    super.initState();
    _fetchPrices();
    // _fetchContactInfo(); // Removed: no longer needed
    // Initialize Fedapay
    final feda = FedaFlutter(
      apiKey: "sk_sandbox_5eglTc3hCd6lTA8agN_O32jz",
      environment: ApiEnvironment.sandbox,
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur de chargement des prix: $e")));
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
          // 'price': _prices![details['size']], // Add price per unit if needed by backend for order item creation
        };
      }).toList();

      final orderPayload = {
        'isExpress': widget.isExpress, // Use widget.isExpress
        'paymentMethod': _selectedMethodName!,
        'items': items,
        'userId': ApiService.userId,
        'totalAmount': widget.totalAmount, // Pass totalAmount
      };

      // --- Fedapay Integration Logic (now the only payment method) ---
      final String paymentUrl =
          await ApiService.initiateFedapayPayment(orderPayload);

      if (mounted) Navigator.of(context).pop(); // Pop loader

      if (await canLaunchUrl(Uri.parse(paymentUrl))) {
        await launchUrl(Uri.parse(paymentUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Impossible de lancer l\'URL de paiement Fedapay : $paymentUrl';
      }

      // After launching URL, we expect Fedapay to redirect back.
      // For now, we'll navigate to a receipt screen, but a real integration
      // would involve listening for webhooks or deep links.
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              orderDetails: widget.orderDetails,
              paymentMethod: _selectedMethodName!,
              orderId:
                  "FEDAPAY_PENDING", // Placeholder, will be updated by webhook
              prices: _prices!,
              userName: ApiService.userName ?? "Client passant",
              userPhone: ApiService.userEmail ?? "+22890000000",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Pop loader on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors du traitement du paiement: $e'),
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
        title: const Text('Choisir le mode de paiement'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body:
          (_isLoadingPrices /* || _isLoadingContactInfo */) // _isLoadingContactInfo removed
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    const GeometricBackground(),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Veuillez choisir votre mode de paiement :',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.textPrimary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(16.0),
                                        itemCount: _paymentMethods.length,
                                        itemBuilder: (context, index) {
                                          final method = _paymentMethods[index];
                                          final isSelected = method['name'] ==
                                              _selectedMethodName;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0),
                                            child: GestureDetector(
                                              onTap: () => _onMethodSelected(
                                                  method['name']!),
                                              child: AnimatedContainer(
                                                duration: 300.ms,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                          .withOpacity(0.1)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : Colors.white
                                                            .withOpacity(0.4),
                                                    width:
                                                        isSelected ? 2.0 : 1.0,
                                                  ),
                                                ),
                                                child: ListTile(
                                                  contentPadding:
                                                      const EdgeInsets.all(
                                                          16.0),
                                                  leading: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  trailing: AnimatedOpacity(
                                                    opacity:
                                                        isSelected ? 1.0 : 0.0,
                                                    duration: 300.ms,
                                                    child: const Icon(
                                                        Icons.check_circle,
                                                        color:
                                                            AppColors.primary,
                                                        size: 30),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                              .animate()
                                              .fadeIn(delay: (100 * index).ms)
                                              .slideX(begin: 0.1);
                                        },
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: 300.ms,
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                            opacity: animation, child: child);
                                      },
                                      child: Padding(
                                        key: ValueKey<String>(
                                            _selectedMethodName ?? ''),
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 20),
                                        child: Text(
                                          _getDescription(_selectedMethodName),
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 14),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
