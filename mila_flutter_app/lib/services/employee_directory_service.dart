import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/employee_record.dart';

class EmployeeDirectoryServiceException implements Exception {
  const EmployeeDirectoryServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmployeeDirectoryService {
  EmployeeDirectoryService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<EmployeeRecord>> fetchEmployees({
    required String backendBaseUrl,
    int limit = 250,
  }) async {
    final uri = _buildEmployeesUri(backendBaseUrl, limit);

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      );
    } on http.ClientException catch (error) {
      throw EmployeeDirectoryServiceException(
        'Could not reach the MILA employee directory: ${error.message}',
      );
    } catch (error) {
      throw EmployeeDirectoryServiceException(
        'Could not reach the MILA employee directory: $error',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmployeeDirectoryServiceException(_buildHttpErrorMessage(response));
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        throw const FormatException('Response body is not a JSON object.');
      }

      final rawEmployees = payload['employees'];
      if (rawEmployees is! List) {
        throw const FormatException(
          'Response body is missing an employees array.',
        );
      }

      return rawEmployees.map((entry) {
        if (entry is! Map) {
          throw const FormatException(
            'Employees array contains a non-object item.',
          );
        }

        return EmployeeRecord.fromJson(Map<String, dynamic>.from(entry));
      }).toList();
    } on FormatException catch (error) {
      throw EmployeeDirectoryServiceException(
        'The backend returned an invalid employee payload: ${error.message}',
      );
    } on Object catch (error) {
      throw EmployeeDirectoryServiceException(
        'The backend returned an unreadable employee payload: $error',
      );
    }
  }

  void dispose() {
    _client.close();
  }

  Uri _buildEmployeesUri(String backendBaseUrl, int limit) {
    final normalizedUrl = backendBaseUrl.trim();

    if (normalizedUrl.isEmpty) {
      throw const EmployeeDirectoryServiceException(
        'Backend URL is empty. Save it in Settings before loading employees.',
      );
    }

    late final Uri baseUri;
    try {
      baseUri = Uri.parse(normalizedUrl);
    } on FormatException {
      throw const EmployeeDirectoryServiceException(
        'Backend URL is invalid. Use a full URL like https://my-domain.com.',
      );
    }

    if (!baseUri.hasScheme ||
        (baseUri.scheme != 'https' && baseUri.scheme != 'http')) {
      throw const EmployeeDirectoryServiceException(
        'Backend URL must start with http:// or https://.',
      );
    }

    final cleanedPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');

    return baseUri.replace(
      path: '$cleanedPath/employees',
      queryParameters: <String, String>{'limit': limit.toString()},
    );
  }

  String _buildHttpErrorMessage(http.Response response) {
    final prefix = 'Backend employee request failed (${response.statusCode})';
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
