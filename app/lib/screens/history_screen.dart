import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/storage_service.dart';
import '../widgets/video_player_widget.dart';

/// History screen showing previously processed photos and videos.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await StorageService.getHistory();
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B24),
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClearAll,
              tooltip: 'Clear all history',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00BCD4),
              ),
            )
          : _entries.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No processed items yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Photos and videos you process will appear here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Dismissible(
          key: Key(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: 28,
            ),
          ),
          onDismissed: (_) => _deleteEntry(entry),
          child: _HistoryCard(
            entry: entry,
            onTap: () => _viewEntry(entry),
          ),
        );
      },
    );
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    await StorageService.deleteHistoryEntry(entry.id);
    await StorageService.deleteResultFile(entry.filePath);
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted')),
      );
    }
  }

  void _viewEntry(HistoryEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _HistoryDetailScreen(entry: entry),
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          'Clear History',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Delete all processed items? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService.clearHistory();
              await _loadHistory();
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy - HH:mm').format(entry.timestamp);
    final isPhoto = entry.type == 'photo';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _buildThumbnail(),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPhoto
                              ? const Color(0xFF00BCD4).withValues(alpha: 0.2)
                              : const Color(0xFF9C27B0).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPhoto ? 'Photo' : 'Video',
                          style: TextStyle(
                            color: isPhoto
                                ? const Color(0xFF00BCD4)
                                : const Color(0xFFCE93D8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.facesDetected} face${entry.facesDetected != 1 ? "s" : ""}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (entry.type == 'photo' && entry.thumbnailPath.isNotEmpty) {
      final file = File(entry.thumbnailPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return Container(
      color: Colors.grey[850],
      child: Icon(
        entry.type == 'photo' ? Icons.photo : Icons.videocam,
        color: Colors.white24,
        size: 28,
      ),
    );
  }
}

/// Detail view for a history entry.
class _HistoryDetailScreen extends StatelessWidget {
  final HistoryEntry entry;

  const _HistoryDetailScreen({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B24),
      appBar: AppBar(
        title: Text(entry.type == 'photo' ? 'Photo Result' : 'Video Result'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: entry.type == 'photo'
                  ? _buildPhotoView()
                  : _buildVideoView(),
            ),
            const SizedBox(height: 16),
            Text(
              DateFormat('MMMM d, yyyy - HH:mm').format(entry.timestamp),
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            Text(
              '${entry.facesDetected} face${entry.facesDetected != 1 ? "s" : ""} detected',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoView() {
    final file = File(entry.filePath);
    if (!file.existsSync()) {
      return const Center(
        child: Text(
          'File not found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(file, fit: BoxFit.contain),
    );
  }

  Widget _buildVideoView() {
    final file = File(entry.filePath);
    if (!file.existsSync()) {
      return const Center(
        child: Text(
          'File not found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return VideoPlayerWidget(filePath: entry.filePath);
  }
}
