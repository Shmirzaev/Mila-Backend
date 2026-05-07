import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  SettingsService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String backendBaseUrlKey = 'backend_base_url';

  final FlutterSecureStorage _storage;

  Future<String?> readBackendBaseUrl() async {
    final value = await _storage.read(key: backendBaseUrlKey);
    return value?.trim();
  }

  Future<void> saveBackendBaseUrl(String value) {
    return _storage.write(key: backendBaseUrlKey, value: value.trim());
  }
}
