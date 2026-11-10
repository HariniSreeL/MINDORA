
// Mindora – Centralised colour palette and design tokens
// Inspired by North-East Indian handloom textiles, bamboo architecture,
// regional flora and warm earthy landscapes.

import 'package:flutter/material.dart';

class MindoraColors {
  MindoraColors._();

  // ── Primary palette ──────────────────────────────────────────────────────
  static const Color forestGreen    = Color(0xFF354C3C); // deep bamboo green
  static const Color sageGreen      = Color(0xFF496C52); // sage leaf
  static const Color lightSage      = Color(0xFF64866B); // lighter sage
  static const Color paleGreen      = Color(0xFFDDEBDD); // mint mist

  // ── Background tones ─────────────────────────────────────────────────────
  static const Color cream          = Color(0xFFFAF8F0); // warm ivory
  static const Color parchment      = Color(0xFFF5EFE0); // aged parchment
  static const Color linen          = Color(0xFFEEE8D8); // natural linen

  // ── Accent tones ─────────────────────────────────────────────────────────
  static const Color terracotta     = Color(0xFFB86B4E); // muted terracotta
  static const Color dustyRose      = Color(0xFFD4856B); // soft terracotta rose
  static const Color warmAmber      = Color(0xFFC8974A); // turmeric amber
  static const Color softBlue       = Color(0xFF6B8FAB); // mountain mist blue
  static const Color mutedIndigo    = Color(0xFF7B7FA8); // evening indigo

  // ── Surface / card tones ─────────────────────────────────────────────────
  static const Color cardCream      = Color(0xFFF8F5EC);
  static const Color cardGreen      = Color(0xFFE4EDE5);
  static const Color cardAmber      = Color(0xFFF5EBD4);
  static const Color cardBlue       = Color(0xFFDDE8F0);
  static const Color cardRose       = Color(0xFFF5E3DC);

  // ── Text tones ───────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF2C3A2E);
  static const Color textSecondary  = Color(0xFF55584E);
  static const Color textMuted      = Color(0xFF7A7D72);

  // ── Border / divider ─────────────────────────────────────────────────────
  static const Color borderLight    = Color(0xFFE7E5D9);
  static const Color borderMedium   = Color(0xFFCDD0C4);
}

class MindoraTextStyles {
  MindoraTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: MindoraColors.forestGreen,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: MindoraColors.forestGreen,
    height: 1.35,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: MindoraColors.forestGreen,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: MindoraColors.forestGreen,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    height: 1.6,
    color: MindoraColors.textSecondary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    height: 1.55,
    color: MindoraColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: MindoraColors.textMuted,
  );
}

// ── Shared widget decorations ─────────────────────────────────────────────

BoxDecoration mindoraCard({Color? color, double radius = 20}) {
  return BoxDecoration(
    color: color ?? MindoraColors.cardCream,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: MindoraColors.borderLight),
    boxShadow: const [
      BoxShadow(
        color: Color(0x10000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
  );
}

BoxDecoration mindoraGradientCard({
  List<Color>? colors,
  double radius = 24,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: colors ??
          [
            MindoraColors.cardGreen,
            MindoraColors.cardAmber.withValues(alpha: 0.6),
          ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: MindoraColors.borderLight),
  );
}
