import 'dart:async';
import 'dart:io';

import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';
import 'package:Picon/utils/print_quality_utils.dart';
import 'package:Picon/utils/image_helper.dart';

// ─────────────────────────────────────────────
//  Modèle de classement d'un format d'impression
// ─────────────────────────────────────────────
class _FormatOption {
  final String dimension;
  final double price;
  final PrintQuality quality;
  final double keepFraction;
  final double dpi;
  final bool isNative;

  const _FormatOption({
    required this.dimension,
    required this.price,
    required this.quality,
    required this.keepFraction,
    required this.dpi,
    this.isNative = false,
  });

  Color get color => qualityColor(quality);
  Color get lightColor => qualityLightColor(quality);
  IconData get icon => qualityIcon(quality);
  String get label => qualityLabel(quality);
}

// ─────────────────────────────────────────────
//  Widget principal
// ─────────────────────────────────────────────
class PhotoPreviewScreen extends StatefulWidget {
  final List<String> images;
  final Map<String, Map<String, dynamic>> photoDetails;
  final Map<String, double> prices;

  const PhotoPreviewScreen({
    super.key,
    required this.images,
    required this.photoDetails,
    required this.prices,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSuggesting = false;

  /// Cache des tailles réelles des images (en pixels)
  final Map<String, Size> _imageSizes = {};
  final Map<String, Future<Size>> _sizeFutures = {};

  /// Copie locale modifiable des détails
  late final Map<String, Map<String, dynamic>> _localDetails;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Copie défensive des détails fournis
    _localDetails = {
      for (final img in widget.images)
        img: Map<String, dynamic>.from(
          widget.photoDetails[img] ?? {'size': widget.prices.keys.firstOrNull ?? '', 'quantity': 1},
        ),
    };

    // Préchargement asynchrone
    _preloadAndAssignBestFormats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _preloadAndAssignBestFormats() async {
    for (final img in widget.images) {
      final size = await _loadImageSize(img);
      if (!mounted) return;
      if (_localDetails[img] != null) {
        final best = _bestFormatFor(size);
        if (_localDetails[img]!['_autoAssigned'] != true) {
          setState(() {
            _localDetails[img]!['size'] = best;
            _localDetails[img]!['_autoAssigned'] = true;
          });
        }
      }
    }
  }

  String _bestFormatFor(Size imageSize) {
    if (widget.prices.isEmpty) return '10x15 cm';
    final imgAspect = imageSize.width / imageSize.height;
    String best = widget.prices.keys.first;
    double bestDiff = double.infinity;
    for (final dim in widget.prices.keys) {
      final diff = (dimensionAspect(dim) - imgAspect).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = dim;
      }
    }
    return best;
  }

  Future<Size> _loadImageSize(String imageUrl) {
    if (_imageSizes.containsKey(imageUrl)) {
      return Future.value(_imageSizes[imageUrl]);
    }
    if (_sizeFutures.containsKey(imageUrl)) {
      return _sizeFutures[imageUrl]!;
    }

    final future = getImageDimensions(imageUrl).then((size) {
      _imageSizes[imageUrl] = size;
      return size;
    });
    _sizeFutures[imageUrl] = future;
    return future;
  }

  double _keepFractionLocal(Size imageSize, double targetAspect) =>
      computeKeepFraction(imageSize, targetAspect);

  List<_FormatOption> _buildFormatOptions(Size imageSize) {
    final nativeDim = _bestFormatFor(imageSize);
    final options = widget.prices.entries.map((e) {
      final aspect = dimensionAspect(e.key);
      final keep = _keepFractionLocal(imageSize, aspect);
      final dpi = computeDpi(imageSize, e.key);
      return _FormatOption(
        dimension: e.key,
        price: e.value,
        quality: qualityFromDpi(dpi),
        keepFraction: keep,
        dpi: dpi,
        isNative: e.key == nativeDim,
      );
    }).toList();

    options.sort((a, b) {
      if (a.isNative && !b.isNative) return -1;
      if (!a.isNative && b.isNative) return 1;
      return a.quality.index.compareTo(b.quality.index);
    });
    return options;
  }

  Future<bool> _hasUnsuitablePhotos() async {
    for (final img in widget.images) {
      final dim = _localDetails[img]?['size'] as String? ?? '';
      final imageSize = await _loadImageSize(img);
      final dpi = computeDpi(imageSize, dim);
      if (qualityFromDpi(dpi) == PrintQuality.tooSmall) return true;
    }
    return false;
  }

  Future<void> _confirm() async {
    final hasUnsuitable = await _hasUnsuitablePhotos();
    if (!mounted) return;

    if (hasUnsuitable) {
      final proceed = await _showUnsuitableWarning();
      if (!proceed) return;
    }

    for (final entry in _localDetails.entries) {
      final clean = Map<String, dynamic>.from(entry.value)
        ..remove('_autoAssigned');
      widget.photoDetails[entry.key] = clean;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<bool> _showUnsuitableWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('Qualité insuffisante'),
          ],
        ),
        content: const Text(
          'Une ou plusieurs photos sont dans un format déconseillé. '
          'Le résultat final risque d''être flou ou pixelisé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Modifier'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuer quand même'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _suggestBestFormat() async {
    if (widget.prices.isEmpty || widget.images.isEmpty) return;
    setState(() => _isSuggesting = true);

    final images = widget.images;
    final sizes = await Future.wait(images.map(_loadImageSize));

    for (int i = 0; i < images.length; i++) {
      final url = images[i];
      final size = sizes[i];

      String? bestDim;
      double bestDpi = -1;
      for (final dim in widget.prices.keys) {
        final d = computeDpi(size, dim);
        if (d > bestDpi) {
          bestDpi = d;
          bestDim = dim;
        }
      }
      if (bestDim != null) {
        _localDetails[url] ??= {};
        _localDetails[url]!['size'] = bestDim;
        _localDetails[url]!['_autoAssigned'] = true;
      }
    }

    if (mounted) {
      setState(() => _isSuggesting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: const [
          Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('Formats optimaux attribués à chaque photo !')),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center}) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 30),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          );
        },
      );
    } else {
      return Image.file(
        File(url),
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 30),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Prévisualisation'),
        ),
        body: const Center(child: Text('Aucune photo sélectionnée.')),
      );
    }

    if (_selectedIndex >= widget.images.length) {
      _selectedIndex = widget.images.length - 1;
    }

    final selectedImage = widget.images[_selectedIndex];
    final selectedDimension =
        _localDetails[selectedImage]?['size'] as String? ??
            (widget.prices.keys.firstOrNull ?? '');
    final targetAspect = dimensionAspect(selectedDimension);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Choisir le format'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Annuler',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            const Positioned.fill(child: GeometricBackground()),
            Column(
              children: [
                _buildThumbnailStrip(),
                const SizedBox(height: 12),

                FutureBuilder<Size>(
                  future: _loadImageSize(selectedImage),
                  builder: (context, snap) {
                    final imageSize = snap.data;
                    return _buildFormatDropdown(
                      selectedImage: selectedImage,
                      selectedDimension: selectedDimension,
                      imageSize: imageSize,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ── Bouton Suggestion (Auto-optimiser) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: _isSuggesting ? null : _suggestBestFormat,
                      icon: _isSuggesting
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                        _isSuggesting ? 'Analyse...' : 'Auto-optimiser',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.primary.withOpacity(0.05),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight * 0.76;
                      double pW = maxW - 32;
                      double pH = pW / targetAspect;
                      if (pH > maxH) {
                        pH = maxH;
                        pW = pH * targetAspect;
                      }
                      return FutureBuilder<Size>(
                        future: _loadImageSize(selectedImage),
                        builder: (context, snap) {
                          final imageSize =
                              snap.data ?? const Size(1, 1);
                          final keep =
                              computeKeepFraction(imageSize, targetAspect);
                          final dpi = computeDpi(imageSize, selectedDimension);
                          final q = qualityFromDpi(dpi);
                          final opt = _FormatOption(
                            dimension: selectedDimension,
                            price: 0,
                            quality: q,
                            keepFraction: keep,
                            dpi: dpi,
                          );
                          return SingleChildScrollView(
                            child: _buildPreviewCard(
                              selectedImage: selectedImage,
                              imageSize: imageSize,
                              previewW: pW,
                              previewH: pH,
                              option: opt,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                _buildConfirmButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return Container(
      height: 90,
      padding: const EdgeInsets.only(top: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final url = widget.images[index];
          final isSelected = index == _selectedIndex;
          final dim = _localDetails[url]?['size'] as String? ?? '';

          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(url),
                    // Badge de qualité DPI
                    FutureBuilder<Size>(
                      future: _loadImageSize(url),
                      builder: (context, snap) {
                        if (snap.hasData) {
                          final dpi = computeDpi(snap.data!, dim);
                          final q = qualityFromDpi(dpi);
                          return Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: qualityColor(q),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormatDropdown({
    required String selectedImage,
    required String selectedDimension,
    required Size? imageSize,
  }) {
    if (imageSize == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LinearProgressIndicator(),
      );
    }

    final options = _buildFormatOptions(imageSize);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedDimension,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, color: AppColors.primary),
            items: options.map((opt) {
              return DropdownMenuItem<String>(
                value: opt.dimension,
                child: Row(
                  children: [
                    Icon(opt.icon, color: opt.color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt.dimension,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (opt.isNative)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Natif',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _localDetails[selectedImage]!['size'] = val;
                  _localDetails[selectedImage]!['_autoAssigned'] = true;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard({
    required String selectedImage,
    required Size imageSize,
    required double previewW,
    required double previewH,
    required _FormatOption option,
  }) {
    final int percentage = (option.keepFraction * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            width: previewW,
            height: previewH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildImage(
                selectedImage,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildQualityIndicator(option, percentage, imageSize),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(
      _FormatOption option, int percentage, Size imageSize) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: option.lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: option.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: option.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(option.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        color: option.color.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Qualité basée sur ${option.dpi.toInt()} DPI',
                      style: TextStyle(
                        color: option.color.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (option.quality == PrintQuality.tooSmall) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white54),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.lightbulb_outline, color: Color(0xFFC62828), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conseil : Choisissez un format plus petit pour cette photo.',
                    style: TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ElevatedButton.icon(
        onPressed: _confirm,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Confirmer les formats'),
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
    );
  }
}
