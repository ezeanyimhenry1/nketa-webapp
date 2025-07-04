import 'package:flutter/material.dart';
import 'package:the_igbo_bible/models/image_template.dart';

final List<ImageTemplate> imageTemplates = [
  ImageTemplate(
    name: 'Classic',
    backgroundColor: Color(0xFF1E3A8A),
    accentColor: Color(0xFFFFB800),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E3A8A), Color(0xFF3730A3)],
    ),
  ),
  ImageTemplate(
    name: 'Nature',
    backgroundColor: Color(0xFF059669),
    accentColor: Color(0xFFFDE047),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF059669), Color(0xFF047857)],
    ),
  ),
  ImageTemplate(
    name: 'Sunset',
    backgroundColor: Color(0xFFDC2626),
    accentColor: Color(0xFFFBBF24),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDC2626), Color(0xFFEA580C), Color(0xFFFBBF24)],
    ),
  ),
  ImageTemplate(
    name: 'Elegant',
    backgroundColor: Color(0xFF374151),
    accentColor: Color(0xFFD1FAE5),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF111827), Color(0xFF374151)],
    ),
  ),
  ImageTemplate(
    name: 'Royal',
    backgroundColor: Color(0xFF7C3AED),
    accentColor: Color(0xFFFDE047),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    ),
  ),
  ImageTemplate(
    name: 'Ocean',
    backgroundColor: Color(0xFF0EA5E9),
    accentColor: Color(0xFFFFFFFF),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    ),
  ),
  ImageTemplate(
    name: 'Igbo Art',
    backgroundImageAsset: 'assets/templates/igbo_art.jpg',
    accentColor: Color(0xFF1E3A8A),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withAlpha((0.75 * 255).toInt()),
        Colors.black.withAlpha((0.75 * 255).toInt()),
      ],
    ),
    overlay: Colors.black.withAlpha((0.5 * 255).toInt()),
  ),
  ImageTemplate(
    name: 'Paper',
    backgroundImageAsset: 'assets/templates/paper.jpg',
    accentColor: Color(0xFF7C3AED),
    textColor: Colors.black,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white.withAlpha((0.8 * 255).toInt()), Colors.transparent],
    ),
  ),
  ImageTemplate(
    name: 'Nature Photo',
    backgroundImageAsset: 'assets/templates/nature.jpg',
    accentColor: Color(0xFF059669),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.black.withAlpha((0.55 * 255).toInt()),
        Colors.transparent,
      ],
    ),
  ),
  ImageTemplate(
    name: 'Blue Pattern',
    backgroundImageAsset: 'assets/templates/blue_pattern.jpg',
    accentColor: Color(0xFF0EA5E9),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.blue.withAlpha((0.4 * 255).toInt()), Colors.transparent],
    ),
  ),
  ImageTemplate(
    name: 'Dessert',
    backgroundImageAsset: 'assets/templates/dessert.jpg',
    accentColor: Color(0xFF0EA5E9),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.blue.withAlpha((0.6 * 255).toInt()), Colors.transparent],
    ),
  ),
  ImageTemplate(
    name: 'Forest Art',
    backgroundImageAsset: 'assets/templates/forest_art.jpg',
    accentColor: Color(0xFF0EA5E9),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.black.withAlpha((0.5 * 255).toInt()), Colors.transparent],
    ),
  ),
  ImageTemplate(
    name: 'Stream',
    backgroundImageAsset: 'assets/templates/stream.jpg',
    accentColor: Color(0xFF0EA5E9),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.blue.withAlpha((0.6 * 255).toInt()), Colors.transparent],
    ),
  ),
  ImageTemplate(
    name: 'Yellow Pattern',
    backgroundImageAsset: 'assets/templates/yellow_pattern.jpg',
    accentColor: Color(0xFF0EA5E9),
    textColor: Colors.white,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.black.withAlpha((0.75 * 255).toInt()),
        Colors.black.withAlpha((0.75 * 255).toInt()),
      ],
    ),
  ),
];
