import 'dart:async';
import 'dart:io';

import 'package:Picon/utils/colors.dart';
import 'package:Picon/utils/geometric_background.dart';
import 'package:flutter/material.dart';

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

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  int _selectedIndex = 0;
  final Map<String, Size> _imageSizes = {};
  final Map<String, Future<Size>> _sizeFutures = {};

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  void _initializeDefaults() {
    if (widget.images.isEmpty) return;
    final defaultSize = _defaultDimension();
    for (final image in widget.images) {
      widget.photoDetails.putIfAbsent(
        image,
        () => {
          'size': defaultSize,
          'quantity': 1,
        },
      );
    }
  }

  String _defaultDimension() {
    if (widget.prices.isEmpty) return '10x15 cm';
    if (widget.prices.containsKey('10x15 cm')) return '10x15 cm';
    return widget.prices.keys.first;
  }

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
    listener = ImageStreamListener((ImageInfo info, bool syncCall) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      _imageSizes[imageUrl] = size;
      if (!completer.isCompleted) {
        completer.complete(size);
      }
      stream.removeListener(listener);
    }, onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.complete(const Size(1, 1));
      }
      stream.removeListener(listener);
    });

    stream.addListener(listener);
    _sizeFutures[imageUrl] = completer.future;
    return completer.future;
  }

  double _dimensionAspect(String dimension) {
    final matches = RegExp(r'(\d+([.,]\d+)?)').allMatches(dimension).toList();
    if (matches.length >= 2) {
      final width = double.tryParse(
            matches[0].group(1)!.replaceAll(',', '.'),
          ) ??
          1;
      final height = double.tryParse(
            matches[1].group(1)!.replaceAll(',', '.'),
          ) ??
          1;
      if (height == 0) return 1;
      return width / height;
    }
    return 1;
  }

  double _keepFraction(Size imageSize, double targetAspect) {
    final imageAspect = imageSize.width / imageSize.height;
    if (imageAspect > targetAspect) {
      return targetAspect / imageAspect;
    }
    return imageAspect / targetAspect;
  }

  Color _validationColor(double keepFraction) {
    if (keepFraction >= 0.9) return Colors.green;
    if (keepFraction >= 0.75) return Colors.orange;
    return Colors.red;
  }

  String _validationLabel(double keepFraction) {
    if (keepFraction >= 0.9) return "Bon pour l'impression";
    if (keepFraction >= 0.75) return "Acceptable";
    return "Dimension non adaptée";
  }

  Future<bool> _canContinue() async {
    bool hasRed = false;
    for (final image in widget.images) {
      final details = widget.photoDetails[image];
      if (details == null) continue;
      final dimension = details['size'] as String;
      final targetAspect = _dimensionAspect(dimension);
      final imageSize = await _loadImageSize(image);
      final keep = _keepFraction(imageSize, targetAspect);
      if (keep < 0.75) {
        hasRed = true;
        break;
      }
    }
    return !hasRed;
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Photo non conforme'),
        content: const Text(
          "Au moins une photo est en rouge. "
          "Choisissez une autre dimension ou retirez la photo concernée.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
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
    final selectedDetails = widget.photoDetails[selectedImage]!;
    final selectedDimension = selectedDetails['size'] as String;
    final targetAspect = _dimensionAspect(selectedDimension);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Prévisualisation'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GeometricBackground()),
          Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = widget.images[index];
                    final isSelected = index == _selectedIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.4),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: imageUrl.startsWith('http')
                                    ? Image.network(imageUrl, fit: BoxFit.cover)
                                    : Image.file(File(imageUrl), fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                child: FutureBuilder<Size>(
                                  future: _loadImageSize(imageUrl),
                                  builder: (context, snapshot) {
                                    final size =
                                        snapshot.data ?? const Size(1, 1);
                                    final details = widget.photoDetails[imageUrl];
                                    final dim = details?['size'] as String? ??
                                        _defaultDimension();
                                    final aspect = _dimensionAspect(dim);
                                    final keep = _keepFraction(size, aspect);
                                    final color =
                                        _validationColor(keep).withOpacity(0.7);
                                    return Container(
                                      width: 70 * 0.5,
                                      height: 90 * 0.5,
                                      decoration: BoxDecoration(
                                        color: color,
                                        border: Border.all(
                                            color: Colors.white, width: 1),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      widget.images.removeAt(index);
                                      widget.photoDetails.remove(imageUrl);
                                      if (widget.images.isEmpty) {
                                        Navigator.of(context).pop();
                                      } else if (_selectedIndex >=
                                          widget.images.length) {
                                        _selectedIndex =
                                            widget.images.length - 1;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(220, 240, 48, 48),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: selectedDimension,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Dimension',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: const Icon(Icons.straighten, size: 18),
                  ),
                  items: widget.prices.keys
                      .map(
                        (size) =>
                            DropdownMenuItem(value: size, child: Text(size)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      widget.photoDetails[selectedImage]!['size'] = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final maxHeight = constraints.maxHeight;
                    final usableHeight = maxHeight * 0.78;
                    double previewWidth = maxWidth;
                    double previewHeight = previewWidth / targetAspect;

                    if (previewHeight > usableHeight) {
                      previewHeight = usableHeight;
                      previewWidth = previewHeight * targetAspect;
                    }

                    return Center(
                      child: FutureBuilder<Size>(
                        future: _loadImageSize(selectedImage),
                        builder: (context, snapshot) {
                          final imageSize =
                              snapshot.data ?? const Size(1, 1);
                          final keep = _keepFraction(imageSize, targetAspect);
                          final borderColor = _validationColor(keep);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                child: SizedBox(
                                  width: previewWidth,
                                  height: previewHeight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: borderColor, width: 3),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: selectedImage.startsWith('http')
                                          ? Image.network(
                                              selectedImage,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(selectedImage),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: borderColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _validationLabel(keep),
                                    style: TextStyle(
                                      color: borderColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await _canContinue();
                    if (!ok) {
                      _showBlockedDialog();
                      return;
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Continuer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
