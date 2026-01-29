import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_app/api_service.dart';
import 'package:photo_app/models/photo_format.dart';
import 'package:photo_app/utils/colors.dart';
import 'package:photo_app/utils/geometric_background.dart';


final NumberFormat currencyFormatter =
    NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

/// ===============================
/// SCREEN
/// ===============================
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late Future<List<PhotoFormat>> _dimensionsFuture;

  @override
  void initState() {
    super.initState();
    _dimensionsFuture = ApiService.fetchDimensions();
  }

  void _openDetails(BuildContext context, PhotoFormat format) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => DimensionDetailDialog(format: format),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Guide des Dimensions'),
        
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const GeometricBackground(),
          SafeArea(
            child: FutureBuilder<List<PhotoFormat>>(
              future: _dimensionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aucune dimension trouvée.'));
                }

                final photoFormats = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: photoFormats.length,
                  itemBuilder: (context, index) {
                    final format = photoFormats[index];
                    return GestureDetector(
                      onTap: () => _openDetails(context, format),
                      child: DimensionTile(format: format),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// TILE
/// ===============================
class DimensionTile extends StatelessWidget {
  final PhotoFormat format;

  const DimensionTile({super.key, required this.format});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Image.asset(
            format.images.first,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported),
          ),
          _TileInfo(format: format),
          if (format.isPopular) const _PopularBadge(),
        ],
      ),
    );
  }
}

class _TileInfo extends StatelessWidget {
  final PhotoFormat format;

  const _TileInfo({required this.format});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black.withOpacity(0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.dimension,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  currencyFormatter.format(format.price),
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Populaire',
          style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// ===============================
/// DETAIL DIALOG
/// ===============================
class DimensionDetailDialog extends StatefulWidget {
  final PhotoFormat format;

  const DimensionDetailDialog({super.key, required this.format});

  @override
  State<DimensionDetailDialog> createState() =>
      _DimensionDetailDialogState();
}

class _DimensionDetailDialogState extends State<DimensionDetailDialog> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 300,
                        viewportFraction: 1,
                        onPageChanged: (i, _) =>
                            setState(() => currentIndex = i),
                      ),
                      items: widget.format.images.map((img) {
                        return Image.asset(
                          img,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.format.title,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.format.description,
                            style: const TextStyle(
                                color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.format.dimension,
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white),
                              ),
                              Text(
                                currencyFormatter
                                    .format(widget.format.price),
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.primary), // Use primary color for icon
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
