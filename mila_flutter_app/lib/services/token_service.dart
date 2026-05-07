import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/token_response.dart';

class TokenServiceException implements Exception {
  const TokenServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TokenService {
  TokenService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<TokenResponse> fetchToken({
    required String backendBaseUrl,
    required String participantIdentity,
    required String participantName,
    required String participantSource,
  }) async {
    final uri = _buildTokenUri(backendBaseUrl);

    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'participant_identity': participantIdentity,
          'participant_name': participantName,
          'source': participantSource,
        }),
      );
    } on TokenServiceException {
      rethrow;
    } on http.ClientException catch (error) {
      throw TokenServiceException(
        'Could not reach the MILA backend: ${error.message}',
      );
    } catch (error) {
      throw TokenServiceException('Could not reach the MILA backend: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TokenServiceException(_buildHttpErrorMessage(response));
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        throw const FormatException('Response body is not a JSON object.');
      }

      return TokenResponse.fromJson(Map<String, dynamic>.from(payload));
    } on FormatException catch (error) {
      throw TokenServiceException(
        'The backend returned an invalid token payload: ${error.message}',
      );
    } on Object catch (error) {
      throw TokenServiceException(
        'The backend returned an unreadable token payload: $error',
      );
    }
  }

  void dispose() {
    _client.close();
  }

  Uri _buildTokenUri(String backendBaseUrl) {
    final normalizedUrl = backendBaseUrl.trim();

    if (normalizedUrl.isEmpty) {
      throw const TokenServiceException(
        'Backend URL is empty. Save it in Settings before connecting.',
      );
    }

    late final Uri baseUri;
    try {
      baseUri = Uri.parse(normalizedUrl);
    } on FormatException {
      throw const TokenServiceException(
        'Backend URL is invalid. Use a full URL like https://my-domain.com.',
      );
    }

    if (!baseUri.hasScheme ||
        (baseUri.scheme != 'https' && baseUri.scheme != 'http')) {
      throw const TokenServiceException(
        'Backend URL must start with http:// or https://.',
      );
    }

    final cleanedPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');

    return baseUri.replace(path: '$cleanedPath/token');
  }

  String _buildHttpErrorMessage(http.Response response) {
    final prefix = 'Backend token request failed (${response.statusCode})';
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
