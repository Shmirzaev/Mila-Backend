import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mila_flutter_app/services/token_service.dart';

void main() {
  group('TokenService', () {
    test('surfaces backend error details', () async {
      final service = TokenService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.com/token');
          expect(jsonDecode(request.body), <String, dynamic>{
            'participant_identity': 'ios-user',
            'participant_name': 'Beknazar iOS',
            'source': 'ios',
          });

          return http.Response(
            jsonEncode(<String, dynamic>{
              'detail':
                  'Missing required LiveKit environment variables: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET',
            }),
            500,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => service.fetchToken(
          backendBaseUrl: 'https://api.example.com',
          participantIdentity: 'ios-user',
          participantName: 'Beknazar iOS',
          participantSource: 'ios',
        ),
        throwsA(
          isA<TokenServiceException>().having(
            (error) => error.message,
            'message',
            contains('Missing required LiveKit environment variables'),
          ),
        ),
      );
    });
  });
}
