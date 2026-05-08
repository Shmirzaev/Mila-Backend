import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TelegramRelayServiceException implements Exception {
  const TelegramRelayServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TelegramRelayResult {
  const TelegramRelayResult({
    required this.message,
    required this.filename,
    required this.telegramResult,
  });

  factory TelegramRelayResult.fromJson(Map<String, dynamic> json) {
    return TelegramRelayResult(
      message: json['message'] as String? ?? 'Attachment sent to Telegram.',
      filename: json['filename'] as String? ?? 'attachment',
      telegramResult: json['telegram_result'] as String? ?? '',
    );
  }

  final String message;
  final String filename;
  final String telegramResult;
}

class TelegramRelayService {
  TelegramRelayService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<TelegramRelayResult> sendStaffAttachment({
    required String backendBaseUrl,
    required PlatformFile file,
    required String participantName,
    required String participantIdentity,
    required String participantSource,
    String message = '',
  }) async {
    final uri = _buildRelayUri(backendBaseUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['message'] = message.trim()
      ..fields['participant_name'] = participantName.trim()
      ..fields['participant_identity'] = participantIdentity.trim()
      ..fields['source'] = participantSource.trim();

    request.files.add(await _buildMultipartFile(file));

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } on http.ClientException catch (error) {
      throw TelegramRelayServiceException(
        'Could not reach the MILA upload endpoint: ${error.message}',
      );
    } catch (error) {
      throw TelegramRelayServiceException(
        'Could not reach the MILA upload endpoint: $error',
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TelegramRelayServiceException(_buildHttpErrorMessage(response));
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        throw const FormatException('Response body is not a JSON object.');
      }

      return TelegramRelayResult.fromJson(Map<String, dynamic>.from(payload));
    } on FormatException catch (error) {
      throw TelegramRelayServiceException(
        'The backend returned an invalid Telegram upload payload: ${error.message}',
      );
    } on Object catch (error) {
      throw TelegramRelayServiceException(
        'The backend returned an unreadable Telegram upload payload: $error',
      );
    }
  }

  void dispose() {
    _client.close();
  }

  Uri _buildRelayUri(String backendBaseUrl) {
    final normalizedUrl = backendBaseUrl.trim();

    if (normalizedUrl.isEmpty) {
      throw const TelegramRelayServiceException(
        'Backend URL is missing, so Mila cannot send attachments to Telegram.',
      );
    }

    late final Uri baseUri;
    try {
      baseUri = Uri.parse(normalizedUrl);
    } on FormatException {
      throw const TelegramRelayServiceException(
        'Backend URL is invalid. Use a full URL like https://my-domain.com.',
      );
    }

    if (!baseUri.hasScheme ||
        (baseUri.scheme != 'https' && baseUri.scheme != 'http')) {
      throw const TelegramRelayServiceException(
        'Backend URL must start with http:// or https://.',
      );
    }

    final cleanedPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    return baseUri.replace(path: '$cleanedPath/telegram/staff-upload');
  }

  Future<http.MultipartFile> _buildMultipartFile(PlatformFile file) async {
    final safeName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : 'attachment';

    if (!kIsWeb && file.path != null && file.path!.trim().isNotEmpty) {
      return http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: safeName,
      );
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw const TelegramRelayServiceException(
        'Mila could not read the selected attachment.',
      );
    }

    return http.MultipartFile.fromBytes('file', bytes, filename: safeName);
  }

  String _buildHttpErrorMessage(http.Response response) {
    final prefix = 'Backend upload request failed (${response.statusCode})';
    final body = response.body.trim();

    if (body.isEmpty) {
      return '$prefix.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail =
            decoded['detail'] ?? decoded['error'] ?? decoded['message'];
        if (detail is String && detail.trim().isNotEmpty) {
          return '$prefix: ${detail.trim()}';
        }
      }
    } catch (_) {
      // Fall back to the raw body below.
    }

    return '$prefix: $body';
  }
}
