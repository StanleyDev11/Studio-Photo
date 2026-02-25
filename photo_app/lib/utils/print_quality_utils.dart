import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Système de qualité d'impression basé sur le DPI
// ─────────────────────────────────────────────────────────────

/// Niveaux de qualité pour l'impression photo.
enum PrintQuality { perfect, correct, tooSmall }

/// Conversion : 1 pouce = 2.54 cm
const double _kInchToCm = 2.54;

/// Seuils DPI standards de l'industrie
const double kDpiPerfect = 250;
const double kDpiCorrect = 150;

// ─────────────────────────────────────────────────────────────
//  Parsing & Calculs
// ─────────────────────────────────────────────────────────────

/// Parse une dimension (ex: "10x15 cm") et retourne (largeur, hauteur) en cm.
(double w, double h) parseDimensionCm(String dimension) {
  final matches = RegExp(r'(\d+([.,]\d+)?)').allMatches(dimension).toList();
  if (matches.length >= 2) {
    final w = double.tryParse(matches[0].group(1)!.replaceAll(',', '.')) ?? 1;
    final h = double.tryParse(matches[1].group(1)!.replaceAll(',', '.')) ?? 1;
    return (w, h);
  }
  return (10, 15); // fallback par défaut
}

/// Calcule le ratio d'aspect d'un format (largeur / hauteur).
double dimensionAspect(String dimension) {
  final (w, h) = parseDimensionCm(dimension);
  return h == 0 ? 1 : w / h;
}

/// Calcule le DPI réel d'une image pour un format donné.
///
/// On compare le grand côté de l'image (en pixels) au grand côté du format
/// (en cm converti en pouces), pour être toujours dans le cas le plus
/// favorable (mode "fit", pas de rognage).
double computeDpi(Size imageSize, String dimension) {
  final (wCm, hCm) = parseDimensionCm(dimension);

  // Normaliser : grand côté = grand côté
  final imgLong = imageSize.width > imageSize.height
      ? imageSize.width
      : imageSize.height;
  final imgShort = imageSize.width > imageSize.height
      ? imageSize.height
      : imageSize.width;

  final paperLong = wCm > hCm ? wCm : hCm;
  final paperShort = wCm > hCm ? hCm : wCm;

  // DPI = min des deux axes (le pire détermine la qualité)
  final dpiLong = imgLong / (paperLong / _kInchToCm);
  final dpiShort = imgShort / (paperShort / _kInchToCm);

  return dpiLong < dpiShort ? dpiLong : dpiShort;
}

/// Fraction de l'image conservée après rognage pour un ratio cible.
double computeKeepFraction(Size imageSize, double targetAspect) {
  final imageAspect = imageSize.width / imageSize.height;
  if (imageAspect > targetAspect) return targetAspect / imageAspect;
  return imageAspect / targetAspect;
}

/// Détermine la qualité d'impression en fonction du DPI.
PrintQuality qualityFromDpi(double dpi) {
  if (dpi >= kDpiPerfect) return PrintQuality.perfect;
  if (dpi >= kDpiCorrect) return PrintQuality.correct;
  return PrintQuality.tooSmall;
}

/// Compatibilité : qualité basée sur le keepFraction (ratio d'aspect).
/// Utilisé par l'algo de suggestion qui compare les ratios d'aspect.
PrintQuality qualityFromKeepFraction(double keepFraction) {
  if (keepFraction >= 0.90) return PrintQuality.perfect;
  if (keepFraction >= 0.75) return PrintQuality.correct;
  return PrintQuality.tooSmall;
}

// ─────────────────────────────────────────────────────────────
//  Affichage (icônes, couleurs, labels)
// ─────────────────────────────────────────────────────────────

IconData qualityIcon(PrintQuality q) {
  switch (q) {
    case PrintQuality.perfect:
      return Icons.check_circle;
    case PrintQuality.correct:
      return Icons.warning_amber_rounded;
    case PrintQuality.tooSmall:
      return Icons.cancel;
  }
}

Color qualityColor(PrintQuality q) {
  switch (q) {
    case PrintQuality.perfect:
      return const Color(0xFF2E7D32); // vert foncé
    case PrintQuality.correct:
      return const Color(0xFFE65100); // orange foncé
    case PrintQuality.tooSmall:
      return const Color(0xFFC62828); // rouge foncé
  }
}

Color qualityLightColor(PrintQuality q) {
  switch (q) {
    case PrintQuality.perfect:
      return const Color(0xFFE8F5E9);
    case PrintQuality.correct:
      return const Color(0xFFFFF3E0);
    case PrintQuality.tooSmall:
      return const Color(0xFFFFEBEE);
  }
}

String qualityLabel(PrintQuality q) {
  switch (q) {
    case PrintQuality.perfect:
      return 'Qualité parfaite';
    case PrintQuality.correct:
      return 'Qualité correcte';
    case PrintQuality.tooSmall:
      return 'Image trop petite';
  }
}

String qualityEmoji(PrintQuality q) {
  switch (q) {
    case PrintQuality.perfect:
      return '🟢';
    case PrintQuality.correct:
      return '🟡';
    case PrintQuality.tooSmall:
      return '🔴';
  }
}
