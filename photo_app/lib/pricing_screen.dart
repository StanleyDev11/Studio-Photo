import 'dart:ui';
import 'package:Picon/api_service.dart';
import 'package:Picon/models/photo_format.dart';
import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late Future<List<PhotoFormat>> _pricesFuture;

  @override
  void initState() {
    super.initState();
    _pricesFuture = ApiService.fetchDimensions();
  }

  Future<void> _refreshPrices() async {
    setState(() {
      _pricesFuture = ApiService.fetchDimensions();
    });
    await _pricesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Prix des Tirages'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GeometricBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshPrices,
              color: AppColors.primary,
              child: FutureBuilder<List<PhotoFormat>>(
                future: _pricesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    String errorMessage = snapshot.error.toString();
                    if (errorMessage.startsWith('Exception: ')) {
                      errorMessage = errorMessage.substring(11);
                    }
                    return Center(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 200),
                          Center(child: Text("Impossible de charger les tarifs. $errorMessage")),
                        ],
                      ),
                    );
                  }

                  final prices = snapshot.data!;
                  return _buildGridView(prices);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<PhotoFormat> prices, {bool isOffline = false}) {
    final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Column(
      children: [
        if (isOffline)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Impossible de charger les tarifs en ligne. Affichage des tarifs hors ligne.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: prices.length,
            itemBuilder: (context, index) {
              final item = prices[index];
              return _PriceTile(
                dimension: item.dimension,
                price: currencyFormatter.format(item.price),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PriceTile extends StatelessWidget {
  final String dimension;
  final String price;

  const _PriceTile({required this.dimension, required this.price});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary, width: 1.0), // Blue primary fine border
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dimension,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}