import 'package:flutter/material.dart';

/// Loading indicator for map tiles
class MapLoadingIndicator extends StatelessWidget {
  final bool isLoading;
  final String? message;

  const MapLoadingIndicator({
    super.key,
    this.isLoading = true,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message ?? 'Loading map...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for map initialization
class MapSkeletonLoader extends StatelessWidget {
  const MapSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Grid pattern to simulate map tiles loading
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: GridPatternPainter(),
            ),
          ),
          // Loading text at bottom
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Initializing BushTrack...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading map tiles',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2C2C2C)
      ..strokeWidth = 1;
    
    const tileSize = 64.0;
    
    // Draw grid lines
    for (double x = 0; x < size.width; x += tileSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    for (double y = 0; y < size.height; y += tileSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // Draw some random "tile" boxes
    final randomPaint = Paint()
      ..color = const Color(0xFF252525);
    
    for (double x = 0; x < size.width; x += tileSize) {
      for (double y = 0; y < size.height; y += tileSize) {
        if ((x + y) % (tileSize * 3) == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x + 1, y + 1, tileSize - 2, tileSize - 2),
            randomPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
