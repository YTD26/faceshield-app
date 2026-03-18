import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../models/person_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/video_player_widget.dart';

/// Video mode screen for detecting faces across video frames,
/// clustering into unique persons, and applying selective blur.
class VideoModeScreen extends StatefulWidget {
  const VideoModeScreen({super.key});

  @override
  State<VideoModeScreen> createState() => _VideoModeScreenState();
}

class _VideoModeScreenState extends State<VideoModeScreen> {
  final ImagePicker _picker = ImagePicker();

  List<PersonModel> _persons = [];
  String? _sessionId;
  String? _processedVideoPath;

  bool _isUploading = false;
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _videoProcessed = false;
  double _uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B24),
      appBar: AppBar(
        title: const Text('Video Mode'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isUploading &&
                !_isDetecting &&
                _persons.isEmpty &&
                !_videoProcessed) ...[
              const SizedBox(height: 60),
              _buildPickerSection(),
              const SizedBox(height: 40),
            ],
            if (_isUploading) _buildUploadProgress(),
            if (_isDetecting)
              _buildShimmerLoading('Analyzing video frames...'),
            if (_persons.isNotEmpty && !_videoProcessed) ...[
              _buildPersonsHeader(),
              const SizedBox(height: 12),
              _buildPersonGrid(),
              const SizedBox(height: 20),
              _buildProcessButton(),
            ],
            if (_isProcessing)
              _buildShimmerLoading('Processing video...'),
            if (_videoProcessed && _processedVideoPath != null) ...[
              _buildResultSection(),
            ],
            if (_persons.isNotEmpty || _videoProcessed) ...[
              const SizedBox(height: 12),
              _buildResetButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPickerSection() {
    return Column(
      children: [
        Icon(
          Icons.video_library_outlined,
          size: 80,
          color: Colors.white.withOpacity(0.2),
        ),
        const SizedBox(height: 16),
        Text(
          'Select a video (max 5 min)',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _pickVideo,
          icon: const Icon(Icons.video_library),
          label: const Text('Choose Video'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BCD4),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 32,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: Color(0xFF00BCD4),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Uploading video...',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              backgroundColor: Colors.white12,
              color: const Color(0xFF00BCD4),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonsHeader() {
    return Row(
      children: [
        const Icon(Icons.people, color: Color(0xFF00BCD4), size: 22),
        const SizedBox(width: 8),
        Text(
          '${_persons.length} unique person${_persons.length != 1 ? "s" : ""} detected',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: _persons.length,
      itemBuilder: (context, index) {
        final person = _persons[index];
        return _PersonCard(
          person: person,
          onToggle: () {
            setState(() {
              person.shouldBlur = !person.shouldBlur;
            });
          },
        );
      },
    );
  }

  Widget _buildProcessButton() {
    final blurCount = _persons.where((p) => p.shouldBlur).length;
    return ElevatedButton.icon(
      onPressed: blurCount > 0 ? _processVideo : null,
      icon: const Icon(Icons.blur_on),
      label: Text(
        'Process Video ($blurCount person${blurCount != 1 ? "s" : ""} to blur)',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[800],
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

  Widget _buildResultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00BCD4), size: 20),
            SizedBox(width: 8),
            Text(
              'Video processed successfully',
              style: TextStyle(
                color: Color(0xFF00BCD4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        VideoPlayerWidget(filePath: _processedVideoPath!),
        const SizedBox(height: 16),
        Row(
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
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return TextButton.icon(
      onPressed: _reset,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Start Over'),
      style: TextButton.styleFrom(foregroundColor: Colors.white54),
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
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            backgroundColor: Colors.white12,
            color: Color(0xFF00BCD4),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() => _uploadProgress = i / 10);
        }
      }

      setState(() {
        _isUploading = false;
        _isDetecting = true;
      });

      try {
        final result = await ApiService.detectVideo(bytes, picked.name);

        setState(() {
          _sessionId = result['session_id'] as String;
          _persons = result['persons'] as List<PersonModel>;
          _isDetecting = false;
        });

        if (_persons.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No faces detected in this video')),
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
      setState(() {
        _isUploading = false;
        _isDetecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick video: $e')),
        );
      }
    }
  }

  Future<void> _processVideo() async {
    if (_sessionId == null) return;

    final personIdsToBlur = _persons
        .where((p) => p.shouldBlur)
        .map((p) => p.personId)
        .toList();

    if (personIdsToBlur.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final blurStyle = await StorageService.getBlurStyle();
      final blurIntensity = await StorageService.getBlurIntensity();

      final result = await ApiService.blurVideo(
        sessionId: _sessionId!,
        personIds: personIdsToBlur,
        blurStyle: blurStyle,
        blurIntensity: blurIntensity,
      );

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/faceshield_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(filePath);
      await file.writeAsBytes(result);

      final storedPath = await StorageService.saveResultFile(
        result,
        'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      await StorageService.addHistoryEntry(HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'video',
        filePath: storedPath,
        thumbnailPath: '',
        timestamp: DateTime.now(),
        facesDetected: _persons.length,
      ));

      setState(() {
        _processedVideoPath = filePath;
        _videoProcessed = true;
        _isProcessing = false;
      });

      final autoDelete = await StorageService.getAutoDelete();
      if (autoDelete) {
        ApiService.cleanupSession(_sessionId!);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing failed: $e')),
        );
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_processedVideoPath == null) return;

    try {
      await Gal.putVideo(_processedVideoPath!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved to gallery'),
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
    if (_processedVideoPath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_processedVideoPath!)],
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
      _persons = [];
      _sessionId = null;
      _processedVideoPath = null;
      _isUploading = false;
      _isDetecting = false;
      _isProcessing = false;
      _videoProcessed = false;
      _uploadProgress = 0;
    });
  }
}

class _PersonCard extends StatelessWidget {
  final PersonModel person;
  final VoidCallback onToggle;

  const _PersonCard({
    required this.person,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? imageBytes;
    if (person.sampleThumbnailB64.isNotEmpty) {
      try {
        imageBytes = base64Decode(person.sampleThumbnailB64);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: person.shouldBlur
                ? const Color(0xFF00BCD4)
                : Colors.white24,
            width: 2,
          ),
          color: person.shouldBlur
              ? const Color(0xFF00BCD4).withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  width: double.infinity,
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 36,
                          ),
                        ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: person.shouldBlur
                    ? const Color(0xFF00BCD4).withOpacity(0.15)
                    : Colors.transparent,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Text(
                    person.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        person.shouldBlur ? Icons.blur_on : Icons.blur_off,
                        size: 14,
                        color: person.shouldBlur
                            ? const Color(0xFF00BCD4)
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        person.shouldBlur ? 'Blur' : 'Keep',
                        style: TextStyle(
                          fontSize: 11,
                          color: person.shouldBlur
                              ? const Color(0xFF00BCD4)
                              : Colors.white38,
                        ),
                      ),
                    ],
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
