import 'package:flutter/material.dart';

class ImageTemplate {
  final String name;
  final Color? backgroundColor;
  final Color accentColor;
  final Color textColor;
  final LinearGradient gradient;
  final String? backgroundImageAsset;
  final Color? overlay;

  const ImageTemplate({
    required this.name,
    this.backgroundColor,
    required this.accentColor,
    required this.textColor,
    required this.gradient,
    this.backgroundImageAsset,
    this.overlay,
  });
}
