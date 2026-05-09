import 'package:flutter/material.dart';

class AppColors {
  // Base Matte Dark Theme
  static const Color background = Color(0xFF0D0D12);
  static const Color panelMatte = Color(0xFF161620);
  static const Color panelLight = Color(0xFF1E1E2A);
  static const Color panelHighlight = Color(0xFF252538);
  
  // 🌟 Gold Gradient - Primary Brand
  static const Color goldPrimary = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE44D);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color goldGlow = Color(0x66FFD700);
  
  // 💚 Green - Success/Nature/Eco
  static const Color greenPrimary = Color(0xFF00E676);
  static const Color greenLight = Color(0xFF69F0AE);
  static const Color greenDark = Color(0xFF00C853);
  static const Color greenGlow = Color(0x6600E676);
  
  // 💜 Purple - AI/Tech/Accent
  static const Color purplePrimary = Color(0xFF9C27B0);
  static const Color purpleLight = Color(0xFFBA68C8);
  static const Color purpleDark = Color(0xFF7B1FA2);
  static const Color purpleGlow = Color(0x669C27B0);
  
  // Bright Orange Accents (OutletBuddy style) - Secondary
  static const Color primaryOrange = Color(0xFFFF5722);
  static const Color deepOrange = Color(0xFFE64A19);
  
  // Data Viz Mesh Networking Colors (Orion UI style)
  static const Color meshNodeActive = Color(0xFFFF6B00);
  static const Color meshNodeRelay = Color(0xFFFF3D00);
  static const Color meshConnectionLine = Color(0xAAFF5722);
  
  // Status Colors
  static const Color statusGreen = Color(0xFF00E676);
  static const Color statusYellow = Color(0xFFFFEB3B);
  static const Color statusRed = Color(0xFFEF5350);
  static const Color statusBlue = Color(0xFF42A5F5);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF707080);
  
  // 💎 Glassmorphic & Glow Tokens
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBlack = Color(0x33000000);
  static const Color glowOchre = Color(0x80FF5722);
  static const Color glowGold = Color(0x80FFD700);
  static const Color blurOverlay = Color(0x4D0D0D12);
  
  // Gradient definitions
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, goldPrimary, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient greenGradient = LinearGradient(
    colors: [greenLight, greenPrimary, greenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [purpleLight, purplePrimary, purpleDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cosmicGradient = LinearGradient(
    colors: [purplePrimary, primaryOrange, goldPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
