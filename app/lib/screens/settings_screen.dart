import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Settings screen with blur style, intensity, auto-delete, and privacy info.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _blurStyle = 'gaussian';
  double _blurIntensityValue = 2.0; // 0=low, 1=medium, 2=high
  bool _autoDelete = true;
  bool _isLoading = true;

  static const Map<String, String> _blurStyleLabels = {
    'gaussian': 'Gaussian Blur',
    'pixelate': 'Pixelate',
    'blackbox': 'Black Box',
  };

  static const Map<String, IconData> _blurStyleIcons = {
    'gaussian': Icons.blur_on,
    'pixelate': Icons.grid_on,
    'blackbox': Icons.square,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final style = await StorageService.getBlurStyle();
    final intensity = await StorageService.getBlurIntensity();
    final autoDelete = await StorageService.getAutoDelete();

    setState(() {
      _blurStyle = style;
      _blurIntensityValue = intensity == 'low'
          ? 0
          : intensity == 'medium'
              ? 1
              : 2;
      _autoDelete = autoDelete;
      _isLoading = false;
    });
  }

  String _intensityLabel(double value) {
    if (value <= 0.5) return 'Low';
    if (value <= 1.5) return 'Medium';
    return 'High';
  }

  String _intensityValue(double value) {
    if (value <= 0.5) return 'low';
    if (value <= 1.5) return 'medium';
    return 'high';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B24),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B24),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Blur Style Section
          _buildSectionHeader('Blur Style'),
          const SizedBox(height: 12),
          _buildBlurStyleSelector(),
          const SizedBox(height: 24),

          // Blur Intensity Section
          _buildSectionHeader('Blur Intensity'),
          const SizedBox(height: 12),
          _buildIntensitySlider(),
          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader('Privacy & Data'),
          const SizedBox(height: 12),
          _buildAutoDeleteToggle(),
          const SizedBox(height: 16),
          _buildGdprInfo(),
          const SizedBox(height: 24),

          // Server Configuration
          _buildSectionHeader('Server'),
          const SizedBox(height: 12),
          _buildServerInfo(),
          const SizedBox(height: 24),

          // App Info
          _buildSectionHeader('About'),
          const SizedBox(height: 12),
          _buildAppInfo(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00BCD4),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildBlurStyleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: _blurStyleLabels.entries.map((entry) {
          final isSelected = _blurStyle == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                setState(() => _blurStyle = entry.key);
                await StorageService.setBlurStyle(entry.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00BCD4).withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: const Color(0xFF00BCD4).withOpacity(0.5))
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      _blurStyleIcons[entry.key],
                      color: isSelected
                          ? const Color(0xFF00BCD4)
                          : Colors.white38,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIntensitySlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Intensity', style: TextStyle(color: Colors.white70)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _intensityLabel(_blurIntensityValue),
                  style: const TextStyle(
                    color: Color(0xFF00BCD4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF00BCD4),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00BCD4),
              overlayColor: const Color(0xFF00BCD4).withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _blurIntensityValue,
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (value) async {
                setState(() => _blurIntensityValue = value);
                await StorageService.setBlurIntensity(
                    _intensityValue(value));
              },
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('Medium',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('High',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDeleteToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Auto-delete from server',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: const Text(
          'Remove uploaded files after processing',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        value: _autoDelete,
        onChanged: (value) async {
          setState(() => _autoDelete = value);
          await StorageService.setAutoDelete(value);
        },
        activeColor: const Color(0xFF00BCD4),
        inactiveTrackColor: Colors.white12,
      ),
    );
  }

  Widget _buildGdprInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00BCD4).withOpacity(0.2),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: Color(0xFF00BCD4), size: 18),
              SizedBox(width: 8),
              Text(
                'GDPR Compliance',
                style: TextStyle(
                  color: Color(0xFF00BCD4),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• All uploaded files are automatically deleted from the server within 60 seconds after processing.\n'
            '• No face data, biometric data, or personal information is stored on our servers.\n'
            '• All processing is done in temporary memory and immediately discarded.\n'
            '• Your processing history is stored only on your device.\n'
            '• You have full control over your data at all times.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Server URL',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              GestureDetector(
                onTap: _testConnection,
                child: const Row(
                  children: [
                    Icon(Icons.wifi, color: Color(0xFF00BCD4), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Test',
                      style: TextStyle(
                        color: Color(0xFF00BCD4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ApiService.baseUrl,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('App Version',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('1.0.0',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Build',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('1',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'FaceShield uses AI to detect and blur faces in your photos and videos, helping you protect privacy before sharing content online.',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Testing connection...')),
    );

    final isHealthy = await ApiService.healthCheck();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHealthy
                ? 'Server is reachable and healthy'
                : 'Cannot reach server',
          ),
          backgroundColor: isHealthy ? const Color(0xFF00BCD4) : Colors.red,
        ),
      );
    }
  }
}
