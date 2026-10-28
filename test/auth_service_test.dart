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
              'name': 'Warga Contoh',
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
    expect(preferences.getString(AuthService.sessionRoleKey), 'warga');
    expect(preferences.getString(AuthService.userNameKey), 'Warga Contoh');
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
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AuthService.sessionRoleKey), 'petugas');
  });

  test(
    'tries the legacy login endpoint when the v1 route is unavailable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requestPaths = <String>[];
      final authService = AuthService(
        client: MockClient((request) async {
          requestPaths.add(request.url.path);
          if (request.url.path == '/api/v1/login') {
            return http.Response('Not found', 404);
          }
          return http.Response(
            jsonEncode({
              'data': {
                'token': 'legacy-token',
                'user': {'role': 'warga'},
              },
            }),
            200,
          );
        }),
      );

      final user = await authService.login(
        identifier: 'warga',
        password: 'secret',
      );

      expect(requestPaths, ['/api/v1/login', '/api/auth/login']);
      expect(user.token, 'legacy-token');
      expect(user.roles, ['warga']);
    },
  );

  test('parses Laravel access_token and a singular role field', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'token-for-this-login',
            'user': {'name': 'Petugas Contoh', 'role': 'Petugas'},
          }),
          200,
        ),
      ),
    );

    final user = await authService.login(
      identifier: 'petugas',
      password: 'secret',
    );

    expect(user.token, 'token-for-this-login');
    expect(user.roles, ['petugas']);
    expect(user.name, 'Petugas Contoh');
  });

  test(
    'reports whether token or role is missing from login response',
    () async {
      final authService = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'user': {'name': 'Petugas Contoh', 'role': 'petugas'},
              },
            }),
            200,
          ),
        ),
      );

      expect(
        () => authService.login(identifier: 'petugas', password: 'secret'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            contains('Token tidak ditemukan'),
          ),
        ),
      );
    },
  );

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

  test('logout clears saved authentication values only', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.tokenKey: 'access-token',
      AuthService.rolesKey: ['warga'],
      AuthService.sessionRoleKey: 'warga',
      AuthService.userNameKey: 'Warga Contoh',
      'other_preference': 'keep',
    });
    final authService = AuthService();

    await authService.logout();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AuthService.tokenKey), isNull);
    expect(preferences.getStringList(AuthService.rolesKey), isNull);
    expect(preferences.getString(AuthService.sessionRoleKey), isNull);
    expect(preferences.getString(AuthService.userNameKey), isNull);
    expect(preferences.getString('other_preference'), 'keep');
  });
}
