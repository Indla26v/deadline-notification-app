import 'package:flutter/material.dart';

class BellIcon extends StatelessWidget {
  final double size;
  final Color color;

  const BellIcon({
    Key? key,
    this.size = 24,
    this.color = Colors.amber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: BellPainter(color: color),
    );
  }
}

class BellPainter extends CustomPainter {
  final Color color;

  BellPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // Draw the small circular knob on top
    final knobRadius = width * 0.12;
    final knobCenter = Offset(width / 2, height * 0.12);
    canvas.drawCircle(knobCenter, knobRadius, paint);

    // Draw the main bell body - simple trapezoid/pentagon shape
    final path = Path();
    
    // Start from top center (below knob)
    final topY = height * 0.24;
    final topWidth = width * 0.15;
    
    // Top left
    path.moveTo(width / 2 - topWidth, topY);
    
    // Straight line down and out to bottom left
    path.lineTo(width * 0.18, height * 0.85);
    
    // Small curve at bottom left corner
    path.quadraticBezierTo(
      width * 0.15, height * 0.92,
      width * 0.22, height * 0.95,
    );
    
    // Bottom left to center-left with small notch
    path.lineTo(width * 0.42, height * 0.95);
    
    // Small notch indent at bottom center
    path.lineTo(width * 0.45, height * 0.98);
    path.lineTo(width * 0.55, height * 0.98);
    path.lineTo(width * 0.58, height * 0.95);
    
    // Bottom center-right to right
    path.lineTo(width * 0.78, height * 0.95);
    
    // Small curve at bottom right corner
    path.quadraticBezierTo(
      width * 0.85, height * 0.92,
      width * 0.82, height * 0.85,
    );
    
    // Bottom right up to top right
    path.lineTo(width / 2 + topWidth, topY);
    
    path.close();
    canvas.drawPath(path, paint);
    
    // Add darker bottom section for depth (like the reference image)
    final bottomPaint = Paint()
      ..color = Color.lerp(color, Colors.orange.shade800, 0.3)!
      ..style = PaintingStyle.fill;
    
    final bottomPath = Path();
    bottomPath.moveTo(width * 0.25, height * 0.85);
    bottomPath.lineTo(width * 0.75, height * 0.85);
    bottomPath.lineTo(width * 0.78, height * 0.95);
    bottomPath.lineTo(width * 0.22, height * 0.95);
    bottomPath.close();
    
    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
