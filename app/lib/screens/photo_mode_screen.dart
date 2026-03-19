import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../models/face_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/blur_overlay_painter.dart';
import '../widgets/face_thumbnail_grid.dart';

/// Photo mode screen for detecting and blurring faces in photos.
class PhotoModeScreen extends StatefulWidget {
  const PhotoModeScreen({super.key});

  @override
  State<PhotoModeScreen> createState() => _PhotoModeScreenState();
}

class _PhotoModeScreenState extends State<PhotoModeScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _originalImageBytes;
  Uint8List? _blurredImageBytes;
  List<FaceModel> _faces = [];
  String? _sessionId;
  int _imageWidth = 0;
  int _imageHeight = 0;

  bool _isDetecting = false;
  bool _isBlurring = false;
  bool _showBlurredResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B24),
      appBar: AppBar(
        title: const Text('Photo Mode'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_originalImageBytes == null && !_isDetecting) ...[
              const SizedBox(height: 40),
              _buildPickerButtons(),
              const SizedBox(height: 40),
            ],
            if (_isDetecting) _buildShimmerLoading('Detecting faces...'),
            if (_originalImageBytes != null && !_isDetecting) ...[
              _buildImagePreview(),
              const SizedBox(height: 16),
              if (_faces.isNotEmpty && !_showBlurredResult)
                FaceThumbnailGrid(
                  faces: _faces,
                  onToggle: _toggleFaceBlur,
                ),
              const SizedBox(height: 16),
              if (!_showBlurredResult && _faces.isNotEmpty)
                _buildApplyBlurButton(),
              if (_isBlurring) _buildShimmerLoading('Applying blur...'),
              if (_showBlurredResult && _blurredImageBytes != null) ...[
                _buildBlurredPreview(),
                const SizedBox(height: 16),
                _buildResultButtons(),
              ],
              const SizedBox(height: 8),
              _buildResetButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButtons() {
    return Column(
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 80,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.photo_camera,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final bytes = _showBlurredResult && _blurredImageBytes != null
        ? _blurredImageBytes!
        : _originalImageBytes!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        final aspectRatio =
            _imageWidth > 0 && _imageHeight > 0
                ? _imageWidth / _imageHeight
                : 1.0;
        final displayHeight = displayWidth / aspectRatio;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: Stack(
              children: [
                Image.memory(
                  bytes,
                  width: displayWidth,
                  height: displayHeight,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
                if (!_showBlurredResult && _faces.isNotEmpty)
                  CustomPaint(
                    size: Size(displayWidth, displayHeight),
                    painter: BlurOverlayPainter(
                      faces: _faces,
                      imageWidth: _imageWidth.toDouble(),
                      imageHeight: _imageHeight.toDouble(),
                      displayWidth: displayWidth,
                      displayHeight: displayHeight,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlurredPreview() {
    return Column(
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00BCD4), size: 20),
            SizedBox(width: 8),
            Text(
              'Blur applied successfully',
              style: TextStyle(
                color: Color(0xFF00BCD4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _blurredImageBytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ],
    );
  }

  Widget _buildApplyBlurButton() {
    final blurCount = _faces.where((f) => f.shouldBlur).length;
    return ElevatedButton.icon(
      onPressed: blurCount > 0 ? _applyBlur : null,
      icon: const Icon(Icons.blur_on),
      label: Text('Apply Blur ($blurCount face${blurCount != 1 ? "s" : ""})'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildResultButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveToGallery,
            icon: const Icon(Icons.save_alt, size: 20),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shareResult,
            icon: const Icon(Icons.share, size: 20),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return TextButton.icon(
      onPressed: _reset,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Start Over'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white54,
      ),
    );
  }

  Widget _buildShimmerLoading(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFF1A237E),
            highlightColor: const Color(0xFF00BCD4),
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _originalImageBytes = bytes;
        _isDetecting = true;
        _faces = [];
        _blurredImageBytes = null;
        _showBlurredResult = false;
      });

      try {
        final result = await ApiService.detectPhoto(bytes, picked.name);

        setState(() {
          _sessionId = result['session_id'] as String;
          _faces = result['faces'] as List<FaceModel>;
          _imageWidth = result['image_width'] as int;
          _imageHeight = result['image_height'] as int;
          _isDetecting = false;
        });

        if (_faces.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No faces detected in this image')),
          );
        }
      } catch (e) {
        setState(() => _isDetecting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detection failed: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  void _toggleFaceBlur(int index) {
    setState(() {
      _faces[index].shouldBlur = !_faces[index].shouldBlur;
    });
  }

  Future<void> _applyBlur() async {
    if (_sessionId == null) return;

    final faceIdsToBlur = _faces
        .where((f) => f.shouldBlur)
        .map((f) => f.faceId)
        .toList();

    if (faceIdsToBlur.isEmpty) return;

    setState(() => _isBlurring = true);

    try {
      final blurStyle = await StorageService.getBlurStyle();
      final blurIntensity = await StorageService.getBlurIntensity();

      final result = await ApiService.blurPhoto(
        sessionId: _sessionId!,
        faceIds: faceIdsToBlur,
        blurStyle: blurStyle,
        blurIntensity: blurIntensity,
      );

      setState(() {
        _blurredImageBytes = result;
        _showBlurredResult = true;
        _isBlurring = false;
      });

      final filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = await StorageService.saveResultFile(result, filename);

      await StorageService.addHistoryEntry(HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'photo',
        filePath: filePath,
        thumbnailPath: filePath,
        timestamp: DateTime.now(),
        facesDetected: _faces.length,
      ));

      final autoDelete = await StorageService.getAutoDelete();
      if (autoDelete) {
        ApiService.cleanupSession(_sessionId!);
      }
    } catch (e) {
      setState(() => _isBlurring = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blur failed: $e')),
        );
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_blurredImageBytes == null) return;

    try {
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/faceshield_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(_blurredImageBytes!);

      await Gal.putImage(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved to gallery'),
            backgroundColor: Color(0xFF00BCD4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _shareResult() async {
    if (_blurredImageBytes == null) return;

    try {
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/faceshield_share_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(_blurredImageBytes!);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Processed with FaceShield',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  void _reset() {
    if (_sessionId != null) {
      ApiService.cleanupSession(_sessionId!);
    }
    setState(() {
      _originalImageBytes = null;
      _blurredImageBytes = null;
      _faces = [];
      _sessionId = null;
      _showBlurredResult = false;
      _isDetecting = false;
      _isBlurring = false;
    });
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF00BCD4), size: 40),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
