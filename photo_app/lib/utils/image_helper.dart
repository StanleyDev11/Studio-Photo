import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_size_getter/image_size_getter.dart' as isg;
import 'package:image_size_getter/file_input.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────
//  Lecture rapide des dimensions (headers seulement)
// ─────────────────────────────────────────────────────────────

/// Retourne la taille (en pixels) d'une image locale en lisant
/// uniquement les headers du fichier (JPEG, PNG, GIF, BMP, WebP).
/// **Ne décode PAS l'image entière** — très rapide même pour 48 MP.
///
/// Si la lecture échoue (format non supporté, fichier corrompu),
/// retombe sur le décodeur Flutter classique.
Future<ui.Size> getImageDimensions(String path) async {
  // Fichier distant (URL) → fallback Flutter classique
  if (path.startsWith('http')) {
    return _getImageDimensionsFallback(path);
  }

  try {
    final file = File(path);
    if (!await file.exists()) return const ui.Size(1, 1);

    final imageSize = isg.ImageSizeGetter.getSize(FileInput(file));
    if (imageSize.width > 0 && imageSize.height > 0) {
      return ui.Size(imageSize.width.toDouble(), imageSize.height.toDouble());
    }
    // Dimensions nulles → fallback
    return _getImageDimensionsFallback(path);
  } catch (_) {
    // Format non supporté (ex: HEIC sur certains OS) → fallback
    return _getImageDimensionsFallback(path);
  }
}

/// Fallback : décodage classique Flutter (charge l'image entière).
Future<ui.Size> _getImageDimensionsFallback(String path) async {
  final completer = Completer<ui.Size>();
  final ImageProvider provider = path.startsWith('http')
      ? NetworkImage(path)
      : FileImage(File(path)) as ImageProvider;
  final stream = provider.resolve(const ImageConfiguration());
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      final size = ui.Size(
          info.image.width.toDouble(), info.image.height.toDouble());
      if (!completer.isCompleted) completer.complete(size);
      stream.removeListener(listener);
    },
    onError: (_, __) {
      if (!completer.isCompleted) completer.complete(const ui.Size(1, 1));
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

// ─────────────────────────────────────────────────────────────
//  Compression avant upload
// ─────────────────────────────────────────────────────────────

/// Résolution maximale nécessaire pour l'impression :
/// 20x30 cm à 300 DPI = 2362 x 3543 px.
/// On arrondit à 3600 pour garder de la marge.
const int kMaxPrintDimension = 3600;

/// Qualité JPEG de compression (90 = excellente qualité, ~3x plus léger).
const int kJpegQuality = 90;

/// Compresse une image locale pour l'upload :
/// - Redimensionne si un côté dépasse [kMaxPrintDimension]
/// - Convertit en JPEG qualité [kJpegQuality]
/// - Retourne le chemin du fichier compressé (dans le dossier temp)
///
/// Si la compression échoue (plateforme non supportée, format inconnu),
/// retourne le chemin original sans compression.
Future<String> compressForUpload(String originalPath) async {
  try {
    final file = File(originalPath);
    if (!await file.exists()) return originalPath;

    // Déterminer les dimensions actuelles
    final dimensions = await getImageDimensions(originalPath);
    final int origW = dimensions.width.round();
    final int origH = dimensions.height.round();

    // Si l'image est déjà petite, pas besoin de redimensionner
    // mais on compresse quand même en JPEG pour réduire le poids
    int targetW = origW;
    int targetH = origH;

    if (origW > kMaxPrintDimension || origH > kMaxPrintDimension) {
      if (origW > origH) {
        targetW = kMaxPrintDimension;
        targetH = (origH * kMaxPrintDimension / origW).round();
      } else {
        targetH = kMaxPrintDimension;
        targetW = (origW * kMaxPrintDimension / origH).round();
      }
    }

    // Chemin de sortie dans le dossier temporaire
    final tempDir = await Directory.systemTemp.createTemp('img_compress_');
    final baseName = p.basenameWithoutExtension(originalPath);
    final outputPath = '${tempDir.path}/$baseName.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      originalPath,
      outputPath,
      quality: kJpegQuality,
      minWidth: targetW,
      minHeight: targetH,
      format: CompressFormat.jpeg,
    );

    if (result != null && await File(result.path).exists()) {
      final origSize = await file.length();
      final compSize = await File(result.path).length();
      debugPrint(
        '🗜️ Compression : ${_formatBytes(origSize)} → ${_formatBytes(compSize)} '
        '(${(100 - compSize * 100 / origSize).round()}% réduit) '
        '| ${origW}x$origH → ${targetW}x$targetH',
      );
      return result.path;
    }
    return originalPath;
  } catch (e) {
    debugPrint('⚠️ Compression échouée, envoi original : $e');
    return originalPath;
  }
}

/// Compresse une liste de fichiers en parallèle.
/// Retourne la liste des chemins compressés (même ordre).
Future<List<String>> compressBatch(List<dynamic> files) async {
  final futures = files.map((f) => compressForUpload(f.path));
  return Future.wait(futures);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
