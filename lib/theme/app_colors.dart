import 'package:flutter/material.dart';

class AppColors {
  // ── Base Dark ──────────────────────────────────────────────────────────────
  static const Color background     = Color(0xFF0A0A0A);
  static const Color panelMatte     = Color(0xFF141414);
  static const Color panelLight     = Color(0xFF1E1E1E);
  static const Color panelHighlight = Color(0xFF2A2A2A);

  // ── Primary Accent — orange only, consistent everywhere ───────────────────
  static const Color accent      = Color(0xFFFF6B00);
  static const Color accentLight = Color(0xFFFF9240);
  static const Color accentDark  = Color(0xFFCC4E00);
  static const Color accentGlow  = Color(0x55FF6B00);

  // Keep old names so existing code doesn't break
  static const Color primaryOrange = accent;
  static const Color deepOrange    = accentDark;
  static const Color meshNodeActive     = accent;
  static const Color meshNodeRelay      = accentDark;
  static const Color meshConnectionLine = Color(0xAAFF6B00);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color statusGreen  = Color(0xFF00E676);
  static const Color statusYellow = Color(0xFFFFEB3B);
  static const Color statusRed    = Color(0xFFEF5350);
  static const Color statusBlue   = Color(0xFF42A5F5);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted     = Color(0xFF616161);

  // ── Legacy aliases (kept for backward compat) ─────────────────────────────
  static const Color goldPrimary  = Color(0xFFFFD700);
  static const Color goldLight    = Color(0xFFFFE44D);
  static const Color goldDark     = Color(0xFFB8860B);
  static const Color goldGlow     = Color(0x66FFD700);
  static const Color greenPrimary = statusGreen;
  static const Color greenLight   = Color(0xFF69F0AE);
  static const Color greenDark    = Color(0xFF00C853);
  static const Color greenGlow    = Color(0x6600E676);
  static const Color purplePrimary = Color(0xFF9C27B0);
  static const Color purpleLight   = Color(0xFFBA68C8);
  static const Color purpleDark    = Color(0xFF7B1FA2);
  static const Color purpleGlow    = Color(0x669C27B0);

  // ── Glass / Overlay ───────────────────────────────────────────────────────
  static const Color glassWhite  = Color(0x1AFFFFFF);
  static const Color glassBlack  = Color(0x33000000);
  static const Color glowOchre   = Color(0x80FF6B00);
  static const Color glowGold    = Color(0x80FFD700);
  static const Color blurOverlay = Color(0x4D0A0A0A);

  // ── Gradients ─────────────────────────────────────────────────────────────

  // Metallic orange shimmer — primary brand gradient
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentLight, accent, accentDark, accent, accentLight],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Brushed steel surface — panels and cards
  static const LinearGradient steelGradient = LinearGradient(
    colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A), Color(0xFF222222), Color(0xFF1E1E1E)],
    stops: [0.0, 0.35, 0.65, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status gradients
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C853), statusGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFD32F2F), statusRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy gradient names
  static const LinearGradient primaryGradient = accentGradient;
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, goldPrimary, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenGradient = successGradient;
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [purpleLight, purplePrimary, purpleDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cosmicGradient = LinearGradient(
    colors: [purplePrimary, accent, goldPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Design System constants — single source of truth for spacing and sizing.
class BushDS {
  // Tap targets — outback users wear gloves
  static const double tapMin    = 48.0;
  static const double tapComfy  = 56.0;

  // Font sizes — WCAG AA minimum readable
  static const double fontXS  = 12.0;
  static const double fontSM  = 13.0;
  static const double fontMD  = 14.0;
  static const double fontLG  = 16.0;
  static const double fontXL  = 18.0;
  static const double fontXXL = 24.0;

  // Border radius
  static const double radiusSM  = 8.0;
  static const double radiusMD  = 12.0;
  static const double radiusLG  = 16.0;
  static const double radiusXL  = 24.0;

  // Spacing
  static const double spXS = 4.0;
  static const double spSM = 8.0;
  static const double spMD = 16.0;
  static const double spLG = 24.0;
  static const double spXL = 32.0;
}
