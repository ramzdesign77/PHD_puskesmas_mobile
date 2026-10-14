import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('posts email credentials and persists token and roles', () async {
    SharedPreferences.setMockInitialValues({});
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestUri = request.url;
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'data': {
            'token': 'access-token',
            'user': {
              'roles': ['WARGA'],
            },
          },
        }),
        200,
      );
    });
    final authService = AuthService(client: client);

    final user = await authService.login(
      identifier: ' warga@example.com ',
      password: 'secret',
    );
    final preferences = await SharedPreferences.getInstance();

    expect(requestUri.path, endsWith('/api/v1/login'));
    expect(requestBody, {
      'login': 'warga@example.com',
      'identifier': 'warga@example.com',
      'email': 'warga@example.com',
      'password': 'secret',
    });
    expect(user.token, 'access-token');
    expect(user.roles, ['warga']);
    expect(preferences.getString(AuthService.tokenKey), 'access-token');
    expect(preferences.getStringList(AuthService.rolesKey), ['warga']);
  });

  test('posts username credentials using the username field', () async {
    SharedPreferences.setMockInitialValues({});
    late Map<String, dynamic> requestBody;
    final authService = AuthService(
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': 'access-token',
              'user': {
                'roles': [
                  {'name': 'petugas'},
                ],
              },
            },
          }),
          200,
        );
      }),
    );

    final user = await authService.login(
      identifier: ' petugas1 ',
      password: 'secret',
    );

    expect(requestBody, {
      'login': 'petugas1',
      'identifier': 'petugas1',
      'username': 'petugas1',
      'password': 'secret',
    });
    expect(user.roles, ['petugas']);
  });

  test('returns server error message for rejected credentials', () async {
    final authService = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Kredensial tidak valid.'}),
          401,
        ),
      ),
    );

    expect(
      () => authService.login(identifier: 'unknown', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Kredensial tidak valid.',
        ),
      ),
    );
  });
}
