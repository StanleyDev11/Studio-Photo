import 'dart:ui';

import 'package:Picon/api_service.dart';
import 'package:Picon/payment_selection_screen.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';

class PaymentCustomerInfoScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> orderDetails;
  final double totalAmount;
  final bool isExpress;

  const PaymentCustomerInfoScreen({
    super.key,
    required this.orderDetails,
    required this.totalAmount,
    required this.isExpress,
  });

  @override
  State<PaymentCustomerInfoScreen> createState() =>
      _PaymentCustomerInfoScreenState();
}

class _PaymentCustomerInfoScreenState extends State<PaymentCustomerInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _address;
  String _country = 'TG';

  @override
  void initState() {
    super.initState();
    final fullName = (ApiService.userName ?? '').trim();
    final parts = fullName.split(' ');
    _firstName =
        TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    _lastName = TextEditingController(
        text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _email = TextEditingController(text: ApiService.userEmail ?? '');
    _phone = TextEditingController(text: '');
    _address = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSelectionScreen(
          orderDetails: widget.orderDetails,
          totalAmount: widget.totalAmount,
          isExpress: widget.isExpress,
          customerFirstname: _firstName.text.trim(),
          customerLastname: _lastName.text.trim(),
          customerEmail: _email.text.trim(),
          customerPhone: _normalizePhone(_phone.text),
          customerCountry: _country,
          deliveryAddress: _address.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infos du client'),
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
      body: Stack(
        children: [
          const Positioned.fill(child: GeometricBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Vérifiez vos informations avant le paiement.',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Carte résumé montant ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF283593)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A237E).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total à payer',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    '${widget.orderDetails.length} photo${widget.orderDetails.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${widget.totalAmount.toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildField(
                          label: 'Prénom',
                          controller: _firstName,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requis' : null,
                        ),
                        _buildField(
                          label: 'Nom (optionnel)',
                          controller: _lastName,
                          textInputAction: TextInputAction.next,
                        ),
                        _buildField(
                          label: 'Email',
                          controller: _email,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requis' : null,
                        ),
                        _buildField(
                          label: 'Adresse de livraison complète',
                          controller: _address,
                          textInputAction: TextInputAction.next,
                          hint: 'Quartier, Rue, Maison...',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requis' : null,
                        ),
                        _buildField(
                          label: 'Téléphone (Mobile Money)',
                          controller: _phone,
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.phone,
                          hint: 'Ex: 90 00 00 00',
                          prefix: CountryCodePicker(
                            onChanged: (countryCode) {
                              setState(() {
                                _country = countryCode.code ?? 'TG';
                              });
                            },
                            initialSelection: 'TG',
                            favorite: const [
                              '+228',
                              '+229',
                              '+225',
                              '+227',
                              '+221'
                            ],
                            countryFilter: const ['BJ', 'TG', 'CI', 'NE', 'SN'],
                            textStyle: TextStyle(
                                color: AppColors.textPrimary.withOpacity(0.9)),
                          ),
                          validator: (v) => _validatePhone(v, _country),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _phoneHintByCountry(_country),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _continue,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: const Text(
                                'Continuer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    Widget? prefix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        decoration: _glassyInputDecoration(
          label,
          hint: hint,
          prefix: prefix,
        ),
      ),
    );
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _validatePhone(String? input, String country) {
    if (input == null || input.trim().isEmpty) return 'Requis';
    final digits = _normalizePhone(input);
    if (country == 'BJ' || country == 'TG' || country == 'NE') {
      if (digits.length != 8) return 'Numéro: 8 chiffres';
      return null;
    }
    if (country == 'CI') {
      if (digits.length != 10) return 'Numéro: 10 chiffres';
      return null;
    }
    if (country == 'SN') {
      if (digits.length != 9) return 'Numéro: 9 chiffres';
      return null;
    }
    return null;
  }

  String _phoneHintByCountry(String country) {
    switch (country) {
      case 'BJ':
        return 'Bénin: 8 chiffres (ex: 9XXXXXXX ou 6XXXXXXX)';
      case 'TG':
        return 'Togo: 8 chiffres (ex: 9XXXXXXX ou 7XXXXXXX)';
      case 'CI':
        return 'Côte d’Ivoire: 10 chiffres (ex: 01XXXXXXXX, 05XXXXXXXX, 07XXXXXXXX)';
      case 'NE':
        return 'Niger: 8 chiffres (ex: 9XXXXXXX)';
      case 'SN':
        return 'Sénégal: 9 chiffres (ex: 7XXXXXXXX)';
      default:
        return '';
    }
  }

  InputDecoration _glassyInputDecoration(String label,
      {String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.3),
      labelStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}
