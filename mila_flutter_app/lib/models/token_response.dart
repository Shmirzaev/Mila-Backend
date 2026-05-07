class TokenResponse {
  const TokenResponse({
    required this.serverUrl,
    required this.participantToken,
  });

  final String serverUrl;
  final String participantToken;

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      serverUrl: _readRequiredString(json, 'server_url'),
      participantToken: _readRequiredString(json, 'participant_token'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'server_url': serverUrl,
      'participant_token': participantToken,
    };
  }

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw FormatException('Token response is missing a valid "$key" field.');
  }
}
