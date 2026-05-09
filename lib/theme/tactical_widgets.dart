import 'dart:ui';
import 'package:flutter/material.dart';
import 'tactical_theme_constants.dart';

class TacticalGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final double borderWidth;

  const TacticalGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.all(12.0),
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: kGlassTint,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: kTacticalGradient,
            ),
            child: Padding(
              padding: EdgeInsets.all(borderWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: kGlassTint,
                  borderRadius: BorderRadius.circular(borderRadius - borderWidth),
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Tactical3DButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onPressed;
  final double size;

  const Tactical3DButton({
    super.key,
    required this.assetPath,
    required this.onPressed,
    this.size = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Image.asset(assetPath),
      ),
    );
  }
}