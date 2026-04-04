import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

/// Result of uploading an image (or using an existing URL).
class ImageUploadResult {
  final String? url;
  /// Set when upload failed; null means success (including "no file" for optional fields).
  final String? errorMessage;

  const ImageUploadResult._({this.url, this.errorMessage});

  /// Existing or uploaded URL.
  factory ImageUploadResult.ok(String? url) =>
      ImageUploadResult._(url: url, errorMessage: null);

  factory ImageUploadResult.fail(String message) =>
      ImageUploadResult._(url: null, errorMessage: message);

  bool get isOk => errorMessage == null;
}

class UploadApi {
  static String _basename(String p) {
    final s = p.replaceAll(r'\', '/');
    final i = s.lastIndexOf('/');
    return i < 0 ? s : s.substring(i + 1);
  }

  static MediaType _contentTypeForPath(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    return MediaType('image', 'jpeg');
  }

  /// Upload file; returns URL or error details (server message / network).
  static Future<ImageUploadResult> uploadImage(String filePath) async {
    final uri = Uri.parse('$apiBaseUrl$apiUploadPath');
    final request = http.MultipartRequest('POST', uri);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImageUploadResult.fail('File not found. Pick the image again.');
      }

      try {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            filePath,
            filename: _basename(filePath),
            contentType: _contentTypeForPath(filePath),
          ),
        );
      } catch (_) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: _basename(filePath),
            contentType: _contentTypeForPath(filePath),
          ),
        );
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      Map<String, dynamic> body;
      try {
        final raw =
            res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
        body = Map<String, dynamic>.from(raw is Map ? raw : {});
      } catch (_) {
        return ImageUploadResult.fail(
          'Invalid server response (${res.statusCode}). Check API URL and server.',
        );
      }

      final success = body['success'] == true;
      final okStatus = res.statusCode == 200 || res.statusCode == 201;
      if (!success || !okStatus) {
        final msg = body['message']?.toString() ??
            'Upload failed (${res.statusCode})';
        return ImageUploadResult.fail(msg);
      }

      final data = body['data'];
      if (data is Map && data['url'] != null) {
        return ImageUploadResult.ok(data['url'].toString());
      }
      return ImageUploadResult.fail('Server did not return image URL');
    } catch (e, st) {
      debugPrint('UploadApi.uploadImage: $e\n$st');
      return ImageUploadResult.fail('Network error: $e');
    }
  }
}
