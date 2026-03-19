import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/face_model.dart';
import '../models/person_model.dart';

/// Service for communicating with the FaceShield FastAPI backend.
class ApiService {
  /// Backend URL, auto-detected per platform:
  /// - Web (Codespaces / hosted): same origin, port 8000
  /// - Android emulator: 10.0.2.2:8000 (maps to host localhost)
  /// - Other (iOS sim / desktop): localhost:8000
  static String baseUrl = _defaultBaseUrl();

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      // On web we can read the browser location.
      // In Codespaces the forwarded URL looks like:
      //   https://<codespace>-<port>.app.github.dev
      // We replace the app port with 8000 for the backend.
      final uri = Uri.base; // browser's current URL
      final host = uri.host; // e.g. "localhost" or "xxx-3000.app.github.dev"
      final scheme = uri.scheme; // http or https

      // Codespaces: host contains "-<port>.app.github.dev"
      final codespacePattern = RegExp(r'-\d+(\.app\.github\.dev)');
      if (codespacePattern.hasMatch(host)) {
        // Replace the port portion with 8000
        final backendHost = host.replaceFirst(
          RegExp(r'-\d+(\.app\.github\.dev)'),
          '-8000\$1',
        );
        return '$scheme://$backendHost';
      }

      // Local dev or any other web host: same hostname, port 8000
      return '$scheme://${uri.hostname}:8000';
    }

    // Native platforms
    // Android emulator uses 10.0.2.2 to reach host machine's localhost
    // For a real device or iOS, change this or use the settings screen.
    const isAndroid = bool.fromEnvironment('dart.library.io');
    if (isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Detect faces in a photo.
  ///
  /// Returns a map with 'session_id', 'faces' list, and image dimensions.
  static Future<Map<String, dynamic>> detectPhoto(Uint8List imageBytes, String filename) async {
    final uri = Uri.parse('$baseUrl/detect/photo');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: filename,
    ));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        'Face detection failed: ${response.statusCode}',
        response.body,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final faces = (data['faces'] as List)
        .map((f) => FaceModel.fromJson(f as Map<String, dynamic>))
        .toList();

    return {
      'session_id': data['session_id'] as String,
      'faces': faces,
      'face_count': data['face_count'] as int,
      'image_width': data['image_width'] as int,
      'image_height': data['image_height'] as int,
    };
  }

  /// Apply blur to specified faces in a photo.
  ///
  /// Returns the blurred image as bytes (JPEG).
  static Future<Uint8List> blurPhoto({
    required String sessionId,
    required List<String> faceIds,
    String blurStyle = 'gaussian',
    String blurIntensity = 'high',
  }) async {
    final uri = Uri.parse('$baseUrl/blur/photo');
    final request = http.MultipartRequest('POST', uri);

    request.fields['session_id'] = sessionId;
    request.fields['face_ids'] = faceIds.join(',');
    request.fields['blur_style'] = blurStyle;
    request.fields['blur_intensity'] = blurIntensity;

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw ApiException(
        'Blur failed: ${streamedResponse.statusCode}',
        body,
      );
    }

    return await streamedResponse.stream.toBytes();
  }

  /// Detect and cluster faces in a video.
  ///
  /// Returns a map with 'session_id', 'persons' list, and video metadata.
  static Future<Map<String, dynamic>> detectVideo(Uint8List videoBytes, String filename) async {
    final uri = Uri.parse('$baseUrl/detect/video');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      videoBytes,
      filename: filename,
    ));

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 5),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ApiException(
        'Video detection failed: ${response.statusCode}',
        response.body,
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final persons = (data['persons'] as List)
        .map((p) => PersonModel.fromJson(p as Map<String, dynamic>))
        .toList();

    return {
      'session_id': data['session_id'] as String,
      'persons': persons,
      'person_count': data['person_count'] as int,
      'video_duration': (data['video_duration'] as num).toDouble(),
    };
  }

  /// Apply blur to specified persons in a video.
  ///
  /// Returns the blurred video as bytes (MP4).
  static Future<Uint8List> blurVideo({
    required String sessionId,
    required List<String> personIds,
    String blurStyle = 'gaussian',
    String blurIntensity = 'high',
  }) async {
    final uri = Uri.parse('$baseUrl/blur/video');
    final request = http.MultipartRequest('POST', uri);

    request.fields['session_id'] = sessionId;
    request.fields['person_ids'] = personIds.join(',');
    request.fields['blur_style'] = blurStyle;
    request.fields['blur_intensity'] = blurIntensity;

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 10),
    );

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw ApiException(
        'Video blur failed: ${streamedResponse.statusCode}',
        body,
      );
    }

    return await streamedResponse.stream.toBytes();
  }

  /// Clean up server-side session data.
  static Future<void> cleanupSession(String sessionId) async {
    try {
      final uri = Uri.parse('$baseUrl/cleanup/$sessionId');
      await http.delete(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Silently ignore cleanup errors - server auto-cleans anyway
    }
  }

  /// Check if the backend is reachable.
  static Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Custom exception for API errors.
class ApiException implements Exception {
  final String message;
  final String? responseBody;

  ApiException(this.message, [this.responseBody]);

  @override
  String toString() => 'ApiException: $message';
}
