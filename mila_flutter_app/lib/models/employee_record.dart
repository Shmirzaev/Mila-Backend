class EmployeeRecord {
  const EmployeeRecord({
    required this.employeeNo,
    required this.fullName,
    this.shortName,
    this.position,
    this.departmentKey,
    this.departmentTitle,
    this.phone,
    this.telegramUsername,
    this.telegramChatId,
    this.accessLevel,
    this.status,
  });

  final int? employeeNo;
  final String fullName;
  final String? shortName;
  final String? position;
  final String? departmentKey;
  final String? departmentTitle;
  final String? phone;
  final String? telegramUsername;
  final String? telegramChatId;
  final String? accessLevel;
  final String? status;

  String get badgeLabel =>
      employeeNo == null ? 'STAFF' : '#${employeeNo.toString()}';

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    final values = <String>[
      if (employeeNo != null) employeeNo.toString(),
      fullName,
      ?shortName,
      ?position,
      ?departmentTitle,
      ?departmentKey,
      ?phone,
      ?telegramUsername,
    ];

    return values.any((value) => value.toLowerCase().contains(normalized));
  }

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) {
    return EmployeeRecord(
      employeeNo: _readOptionalInt(json, 'employee_no'),
      fullName: _readRequiredString(json, 'full_name'),
      shortName: _readOptionalString(json, 'short_name'),
      position: _readOptionalString(json, 'position'),
      departmentKey: _readOptionalString(json, 'department_key'),
      departmentTitle: _readOptionalString(json, 'department_title'),
      phone: _readOptionalString(json, 'phone'),
      telegramUsername: _readOptionalString(json, 'telegram_username'),
      telegramChatId: _readOptionalString(json, 'telegram_chat_id'),
      accessLevel: _readOptionalString(json, 'access_level'),
      status: _readOptionalString(json, 'status'),
    );
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw FormatException('Employee payload is missing a valid "$key" field.');
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  static int? _readOptionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
