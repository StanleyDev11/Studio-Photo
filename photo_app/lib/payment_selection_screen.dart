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
  String? _selectedMethodName;
  Map<String, double>? _prices;
  bool _isLoadingPrices = true;
  // String _prestatairePhoneNumber = ""; // Removed: no longer needed for static methods
  // bool _isLoadingContactInfo = true; // Removed: no longer needed

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
    // Initialize Fedapay
    final feda = FedaFlutter(
      apiKey: "pk_sandbox_T07_uKrSPDbodUlB0zTbAoGb",
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
        title: const Text('Choisir le mode de paiement'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body:
          (_isLoadingPrices /* || _isLoadingContactInfo */) // _isLoadingContactInfo removed
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    GeometricBackground(),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Text(
                              'Le code PIN Mobile Money est saisi sur l’interface de paiement FedaPay.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
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
                                                vertical: 10.0),
                                            child: GestureDetector(
                                              onTap: () => _onMethodSelected(
                                                  method['name']!),
                                              child: AnimatedContainer(
                                                duration: 400.ms,
                                                curve: Curves.easeOutQuart,
                                                transform: isSelected 
                                                  ? (Matrix4.identity()..scale(1.02))
                                                  : Matrix4.identity(),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white.withOpacity(0.15)
                                                      : Colors.white.withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: isSelected ? [
                                                    BoxShadow(
                                                      color: AppColors.primary.withOpacity(0.3),
                                                      blurRadius: 15,
                                                      spreadRadius: 2,
                                                    )
                                                  ] : [],
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : Colors.white
                                                            .withOpacity(0.2),
                                                    width:
                                                        isSelected ? 2.0 : 1.0,
                                                  ),
                                                ),
                                                child: ListTile(
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 20, vertical: 12),
                                                  leading: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Image.asset(
                                                      method['logo']!,
                                                      width: 40,
                                                      height: 40,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    method['name']!,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  subtitle: isSelected ? Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Text(
                                                      method['description']!,
                                                      style: TextStyle(
                                                        color: AppColors.textPrimary.withOpacity(0.7),
                                                        fontSize: 12,
                                                      ),
                                                    ).animate().fadeIn(),
                                                  ) : null,
                                                  trailing: isSelected 
                                                    ? Icon(Icons.check_circle, color: AppColors.primary, size: 28)
                                                    : Icon(Icons.radio_button_off, color: Colors.white.withOpacity(0.4), size: 24),
                                                ),
                                              ),
                                            ),
                                          )
                                              .animate()
                                              .fadeIn(delay: (50 * index).ms)
                                              .slideY(begin: 0.2, curve: Curves.easeOutBack);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
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
