import 'dart:async';
import 'dart:io';

import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Modèle de classement d'un format d'impression
// ─────────────────────────────────────────────
enum FormatQuality { recommended, acceptable, unsuitable }

class _FormatOption {
  final String dimension;
  final double price;
  final FormatQuality quality;
  final double keepFraction;
  final bool isNative;

  const _FormatOption({
    required this.dimension,
    required this.price,
    required this.quality,
    required this.keepFraction,
    this.isNative = false,
  });

  Color get color {
    switch (quality) {
      case FormatQuality.recommended:
        return const Color(0xFF2E7D32); // vert foncé
      case FormatQuality.acceptable:
        return const Color(0xFFE65100); // orange foncé
      case FormatQuality.unsuitable:
        return const Color(0xFFC62828); // rouge foncé
    }
  }

  Color get lightColor {
    switch (quality) {
      case FormatQuality.recommended:
        return const Color(0xFFE8F5E9);
      case FormatQuality.acceptable:
        return const Color(0xFFFFF3E0);
      case FormatQuality.unsuitable:
        return const Color(0xFFFFEBEE);
    }
  }

  IconData get icon {
    switch (quality) {
      case FormatQuality.recommended:
        return Icons.check_circle;
      case FormatQuality.acceptable:
        return Icons.warning_amber_rounded;
      case FormatQuality.unsuitable:
        return Icons.cancel;
    }
  }

  String get label {
    switch (quality) {
      case FormatQuality.recommended:
        return 'Recommandé';
      case FormatQuality.acceptable:
        return 'Acceptable';
      case FormatQuality.unsuitable:
        return 'Déconseillé';
    }
  }
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

  /// Cache des tailles réelles des images (en pixels)
  final Map<String, Size> _imageSizes = {};
  final Map<String, Future<Size>> _sizeFutures = {};

  /// Copie locale modifiable des détails : jamais écrite dans widget.photoDetails
  /// avant confirmation.
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

    // Préchargement asynchrone + attribution du meilleur format
    _preloadAndAssignBestFormats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  //  Préchargement des tailles + meilleur format
  // ──────────────────────────────────────────

  Future<void> _preloadAndAssignBestFormats() async {
    for (final img in widget.images) {
      final size = await _loadImageSize(img);
      if (!mounted) return;
      if (_localDetails[img] != null) {
        final best = _bestFormatFor(size);
        // On n'écrase que si c'est la valeur par défaut ou si pas encore calculé
        if (_localDetails[img]!['_autoAssigned'] != true) {
          setState(() {
            _localDetails[img]!['size'] = best;
            _localDetails[img]!['_autoAssigned'] = true;
          });
        }
      }
    }
  }

  /// Dimension dont le ratio est le plus proche de celui de l'image.
  String _bestFormatFor(Size imageSize) {
    if (widget.prices.isEmpty) return '10x15 cm';
    final imgAspect = imageSize.width / imageSize.height;
    String best = widget.prices.keys.first;
    double bestDiff = double.infinity;
    for (final dim in widget.prices.keys) {
      final diff = (_dimensionAspect(dim) - imgAspect).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = dim;
      }
    }
    return best;
  }

  // ──────────────────────────────────────────
  //  Chargement de la taille d'une image
  // ──────────────────────────────────────────

  Future<Size> _loadImageSize(String imageUrl) {
    if (_imageSizes.containsKey(imageUrl)) {
      return Future.value(_imageSizes[imageUrl]);
    }
    if (_sizeFutures.containsKey(imageUrl)) {
      return _sizeFutures[imageUrl]!;
    }

    final completer = Completer<Size>();
    final ImageProvider provider = imageUrl.startsWith('http')
        ? NetworkImage(imageUrl)
        : FileImage(File(imageUrl));

    final ImageStream stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        _imageSizes[imageUrl] = size;
        if (!completer.isCompleted) completer.complete(size);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(const Size(1, 1));
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    _sizeFutures[imageUrl] = completer.future;
    return completer.future;
  }

  // ──────────────────────────────────────────
  //  Analyse de la compatibilité d'un format
  // ──────────────────────────────────────────

  double _dimensionAspect(String dimension) {
    final matches = RegExp(r'(\d+([.,]\d+)?)').allMatches(dimension).toList();
    if (matches.length >= 2) {
      final w = double.tryParse(matches[0].group(1)!.replaceAll(',', '.')) ?? 1;
      final h = double.tryParse(matches[1].group(1)!.replaceAll(',', '.')) ?? 1;
      return h == 0 ? 1 : w / h;
    }
    return 1;
  }

  double _keepFraction(Size imageSize, double targetAspect) {
    final imageAspect = imageSize.width / imageSize.height;
    if (imageAspect > targetAspect) return targetAspect / imageAspect;
    return imageAspect / targetAspect;
  }

  FormatQuality _quality(double keepFraction) {
    if (keepFraction >= 0.90) return FormatQuality.recommended;
    if (keepFraction >= 0.75) return FormatQuality.acceptable;
    return FormatQuality.unsuitable;
  }

  /// Construit la liste triée des options de format pour une image donnée.
  List<_FormatOption> _buildFormatOptions(Size imageSize) {
    final nativeDim = _bestFormatFor(imageSize);
    final options = widget.prices.entries.map((e) {
      final aspect = _dimensionAspect(e.key);
      final keep = _keepFraction(imageSize, aspect);
      return _FormatOption(
        dimension: e.key,
        price: e.value,
        quality: _quality(keep),
        keepFraction: keep,
        isNative: e.key == nativeDim,
      );
    }).toList();

    // Tri : recommended → acceptable → unsuitable, puis natif en premier
    options.sort((a, b) {
      if (a.isNative && !b.isNative) return -1;
      if (!a.isNative && b.isNative) return 1;
      return a.quality.index.compareTo(b.quality.index);
    });
    return options;
  }

  // ──────────────────────────────────────────
  //  Validation et retour
  // ──────────────────────────────────────────

  Future<bool> _hasUnsuitablePhotos() async {
    for (final img in widget.images) {
      final dim = _localDetails[img]?['size'] as String? ?? '';
      final imageSize = await _loadImageSize(img);
      final keep = _keepFraction(imageSize, _dimensionAspect(dim));
      if (keep < 0.75) return true;
    }
    return false;
  }

  /// Confirmer : écrit les détails locaux dans widget.photoDetails et pop(true)
  Future<void> _confirm() async {
    final hasUnsuitable = await _hasUnsuitablePhotos();
    if (!mounted) return;

    if (hasUnsuitable) {
      final proceed = await _showUnsuitableWarning();
      if (!proceed) return;
    }

    // Copie vers widget.photoDetails
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
          'La qualité d\'impression pourrait être dégradée (recadrage important).\n\n'
          'Voulez-vous quand même continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Choisir un meilleur format'),
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

  // ──────────────────────────────────────────
  //  Build principal
  // ──────────────────────────────────────────

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
    final targetAspect = _dimensionAspect(selectedDimension);

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
                // ── Bande des miniatures ──
                _buildThumbnailStrip(),
                const SizedBox(height: 12),

                // ── Dropdown format ──
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

                // ── Aperçu principal ──
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight * 0.76; // réduit pour laisser place au bandeau
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
                              _keepFraction(imageSize, targetAspect);
                          final q = _quality(keep);
                          final opt = _FormatOption(
                            dimension: selectedDimension,
                            price: 0,
                            quality: q,
                            keepFraction: keep,
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

                // ── Bouton Continuer ──
                _buildConfirmButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  Widgets privés
  // ──────────────────────────────────────────

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final url = widget.images[index];
          final isSelected = index == _selectedIndex;
          final dim =
              _localDetails[url]?['size'] as String? ?? _currentSelectedDimension;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = index);
              _fadeController
                ..reset()
                ..forward();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 66,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.3),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox.expand(
                      child: url.startsWith('http')
                          ? Image.network(url, fit: BoxFit.cover)
                          : Image.file(File(url), fit: BoxFit.cover),
                    ),
                  ),
                  // Badge qualité
                  Positioned(
                    top: 0,
                    left: 0,
                    child: FutureBuilder<Size>(
                      future: _loadImageSize(url),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final keep = _keepFraction(
                          snap.data!,
                          _dimensionAspect(dim),
                        );
                        final q = _quality(keep);
                        final opt = _FormatOption(
                          dimension: dim,
                          price: 0,
                          quality: q,
                          keepFraction: keep,
                        );
                        return Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: opt.color,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Icon(opt.icon,
                              size: 11, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  // Bouton supprimer
                  if (widget.images.length > 1)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          widget.images.removeAt(index);
                          _localDetails.remove(url);
                          if (_selectedIndex >= widget.images.length) {
                            _selectedIndex = widget.images.length - 1;
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.close,
                              size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String get _currentSelectedDimension =>
      _localDetails[widget.images.isNotEmpty
              ? widget.images[_selectedIndex]
              : '']
          ?['size'] as String? ??
      (widget.prices.keys.firstOrNull ?? '');

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
    final currentOpt = options.firstWhere(
      (o) => o.dimension == selectedDimension,
      orElse: () => options.first,
    );
    final nativeOpt = options.firstWhere(
      (o) => o.isNative,
      orElse: () => options.first,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bandeau "Format natif"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.aspect_ratio,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Format natif de votre photo : ${nativeOpt.dimension}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${imageSize.width.toInt()}×${imageSize.height.toInt()} px)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // Dropdown avec qualité inline
          DropdownButtonFormField<String>(
            value: currentOpt.dimension,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Format d\'impression',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: currentOpt.color),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: currentOpt.color, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: currentOpt.color, width: 2),
              ),
              prefixIcon: Icon(currentOpt.icon,
                  size: 18, color: currentOpt.color),
              filled: true,
              fillColor: currentOpt.lightColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffix: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: currentOpt.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentOpt.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            selectedItemBuilder: (context) => options
                .map((o) => Text(o.dimension,
                    overflow: TextOverflow.ellipsis))
                .toList(),
            items: options.map((o) {
              return DropdownMenuItem<String>(
                value: o.dimension,
                child: Row(
                  children: [
                    Icon(o.icon, size: 16, color: o.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(o.dimension,
                          style: TextStyle(
                              fontWeight: o.isNative
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                    if (o.isNative)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Natif',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '${(o.keepFraction * 100).toInt()}%',
                      style: TextStyle(
                          fontSize: 11,
                          color: o.color,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _localDetails[selectedImage]!['size'] = value;
              });
            },
          ),
        ],
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
    final percentage = (option.keepFraction * 100).toInt();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Carte d'aperçu
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.08),
              border: Border.all(
                  color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Container(
                  width: previewW,
                  height: previewH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: option.color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: option.color.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: selectedImage.startsWith('http')
                        ? Image.network(selectedImage, fit: BoxFit.cover)
                        : Image.file(File(selectedImage), fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Indicateur de qualité
          _buildQualityIndicator(option, percentage, imageSize),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(
      _FormatOption option, int percentage, Size imageSize) {
    return Column(
      children: [
        // Barre de progression
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: option.keepFraction,
              minHeight: 8,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(option.color),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Label + pourcentage
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, size: 16, color: option.color),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: TextStyle(
                color: option.color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: option.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$percentage% conservé',
                style: TextStyle(
                    color: option.color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        // Avertissement spécifique si déconseillé
        if (option.quality == FormatQuality.unsuitable) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 14, color: Color(0xFFC62828)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ce format nécessite un recadrage trop important. '
                    'La qualité d\'impression sera très dégradée.',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFFC62828)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
