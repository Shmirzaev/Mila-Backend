import 'package:flutter_test/flutter_test.dart';
import 'package:mila_flutter_app/models/token_response.dart';

void main() {
  group('TokenResponse', () {
    test('parses the backend token payload', () {
      final response = TokenResponse.fromJson(<String, dynamic>{
        'server_url': 'wss://livekit.example.com',
        'participant_token': 'jwt-token',
      });

      expect(response.serverUrl, 'wss://livekit.example.com');
      expect(response.participantToken, 'jwt-token');
    });

    test('throws when required fields are missing', () {
      expect(
        () => TokenResponse.fromJson(<String, dynamic>{'server_url': ''}),
        throwsFormatException,
      );
    });
  });
}
