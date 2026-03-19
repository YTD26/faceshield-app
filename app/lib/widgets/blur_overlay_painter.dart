import 'package:flutter/material.dart';

import '../models/face_model.dart';

/// Custom painter that draws bounding boxes around detected faces.
/// Shows blur status with color-coded overlays.
class BlurOverlayPainter extends CustomPainter {
  final List<FaceModel> faces;
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;

  BlurOverlayPainter({
    required this.faces,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = displayWidth / imageWidth;
    final double scaleY = displayHeight / imageHeight;

    for (int i = 0; i < faces.length; i++) {
      final face = faces[i];

      final rect = Rect.fromLTWH(
        face.x * scaleX,
        face.y * scaleY,
        face.width * scaleX,
        face.height * scaleY,
      );

      // Draw bounding box
      final boxPaint = Paint()
        ..color = face.shouldBlur
            ? const Color(0xFF00BCD4)
            : const Color(0xFF4CAF50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, boxPaint);

      // Draw semi-transparent fill for blur-targeted faces
      if (face.shouldBlur) {
        final fillPaint = Paint()
          ..color = const Color(0xFF00BCD4).withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, fillPaint);
      }

      // Draw label background
      final labelText = 'F${i + 1}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: face.shouldBlur ? '🔒 $labelText' : '👁 $labelText',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelBgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left,
          rect.top - 20,
          textPainter.width + 10,
          18,
        ),
        const Radius.circular(4),
      );

      final labelBgPaint = Paint()
        ..color = face.shouldBlur
            ? const Color(0xFF00BCD4).withValues(alpha: 0.85)
            : const Color(0xFF4CAF50).withValues(alpha: 0.85);
      canvas.drawRRect(labelBgRect, labelBgPaint);

      textPainter.paint(
        canvas,
        Offset(rect.left + 5, rect.top - 19),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BlurOverlayPainter oldDelegate) {
    return faces != oldDelegate.faces;
  }
}
