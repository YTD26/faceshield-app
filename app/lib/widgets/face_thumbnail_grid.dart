import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/face_model.dart';

/// Grid widget displaying face thumbnails with blur toggle checkboxes.
class FaceThumbnailGrid extends StatelessWidget {
  final List<FaceModel> faces;
  final ValueChanged<int> onToggle;

  const FaceThumbnailGrid({
    super.key,
    required this.faces,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (faces.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No faces detected',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${faces.length} face${faces.length != 1 ? 's' : ''} detected',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(faces.length, (index) {
              final face = faces[index];
              return _FaceThumbnailItem(
                face: face,
                index: index + 1,
                onToggle: () => onToggle(index),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FaceThumbnailItem extends StatelessWidget {
  final FaceModel face;
  final int index;
  final VoidCallback onToggle;

  const _FaceThumbnailItem({
    required this.face,
    required this.index,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    if (face.thumbnailB64.isNotEmpty) {
      try {
        imageBytes = base64Decode(face.thumbnailB64);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: face.shouldBlur
                ? const Color(0xFF00BCD4)
                : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Face thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: SizedBox(
                width: 68,
                height: 68,
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.face,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
              ),
            ),
            // Blur toggle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: face.shouldBlur
                    ? const Color(0xFF00BCD4).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    face.shouldBlur
                        ? Icons.blur_on
                        : Icons.blur_off,
                    size: 14,
                    color: face.shouldBlur
                        ? const Color(0xFF00BCD4)
                        : Colors.white54,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'F$index',
                    style: TextStyle(
                      fontSize: 11,
                      color: face.shouldBlur
                          ? const Color(0xFF00BCD4)
                          : Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
