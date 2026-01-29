import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_app/api_service.dart';
import 'payment_selection_screen.dart';
import 'utils/colors.dart';

class OrderSummaryScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> orderDetails;
  final bool isExpress;

  const OrderSummaryScreen({
    super.key,
    required this.orderDetails,
    required this.isExpress,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  late Map<String, Map<String, dynamic>> _editableOrderDetails;
  double _subtotal = 0;
  double _deliveryFee = 0;
  double _totalPrice = 0;

  Map<String, double>? _prices;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _editableOrderDetails = Map<String, Map<String, dynamic>>.from(
      widget.orderDetails.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ),
    );
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    try {
      final dimensions = await ApiService.fetchDimensions();
      if (mounted) {
        setState(() {
          _prices = {for (var dim in dimensions) dim.dimension: dim.price};
          _calculatePrices();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur de chargement des prix: $e")));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculatePrices() {
    if (_prices == null) return;

    double newSubtotal = 0;
    int photoCount = _editableOrderDetails.keys.length;

    _editableOrderDetails.forEach((key, details) {
      final price = _prices![details['size']] ?? 0;
      newSubtotal += price * (details['quantity'] as int);
    });

    double newDeliveryFee = 0;
    if (widget.isExpress) {
      if (photoCount <= 10) {
        newDeliveryFee = 1500;
      }
    }

    setState(() {
      _subtotal = newSubtotal;
      _deliveryFee = newDeliveryFee;
      _totalPrice = _subtotal + _deliveryFee;
    });
  }

  void _updateQuantity(String imageUrl, int change) {
    setState(() {
      final currentQuantity = _editableOrderDetails[imageUrl]!['quantity'] as int;
      if (currentQuantity + change > 0) {
        _editableOrderDetails[imageUrl]!['quantity'] = currentQuantity + change;
        _calculatePrices();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Récapitulatif de la commande'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: _editableOrderDetails.entries.map((entry) {
                      final imageUrl = entry.key;
                      final details = entry.value;
                      final isLocalFile = !imageUrl.startsWith('http');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isLocalFile
                                    ? Image.file(File(imageUrl),
                                        width: 80, height: 80, fit: BoxFit.cover)
                                    : Image.network(imageUrl,
                                        width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Taille: ${details['size']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        'Prix unitaire: ${_prices![details['size']]} FCFA'),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _updateQuantity(imageUrl, -1),
                                  ),
                                  Text('${details['quantity']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: AppColors.primary),
                                    onPressed: () => _updateQuantity(imageUrl, 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                _buildPriceSummary(),
              ],
            ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Sous-total', '${_subtotal.toStringAsFixed(0)} FCFA'),
          _buildSummaryRow('Livraison', widget.isExpress ? 'Xpress' : 'Standard'),
          if (widget.isExpress)
            _buildSummaryRow(
                'Frais de livraison', '+ ${_deliveryFee.toStringAsFixed(0)} FCFA'),
          const Divider(height: 20),
          _buildSummaryRow(
            'TOTAL',
            '${_totalPrice.toStringAsFixed(0)} FCFA',
            isTotal: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.textOnPrimary,
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PaymentSelectionScreen(orderDetails: _editableOrderDetails),
                ),
              );
            },
            child: const Text(
              'Confirmer et choisir le paiement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isTotal = false}) {
    final style = isTotal
        ? const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)
        : const TextStyle(fontSize: 16, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: style.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: style),
        ],
      ),
    );
  }
}