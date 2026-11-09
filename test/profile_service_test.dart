import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/services/auth_service.dart';
import 'package:klinik_sanitasi_mobile/models/saved_address.dart';
import 'package:klinik_sanitasi_mobile/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'account-a',
      'auth_user_name': 'Nama Awal',
      'auth_user_email': 'awal@example.com',
      'auth_user_phone': '081234567890',
      'auth_user_username': 'awal',
      'auth_user_avatar': base64Encode([1, 2, 3]),
      'saved_citizen_tickets': ['TIKET-1'],
    });
  });

  test('edits persist across views within the same login session', () async {
    final service = ProfileService(client: _successfulProfileClient());
    final original = await service.load(fallbackName: 'Warga');
    final photo = Uint8List.fromList([5, 6, 7]);
    final changed = original.copyWith(
      name: ' Nama Baru ',
      email: 'baru@example.com',
      phone: '089876543210',
      username: 'baru',
      avatarBytes: photo,
    );
    photo[0] = 99;

    await service.save(changed);
    final restored = await ProfileService().load(fallbackName: 'Warga');

    expect(restored.name, 'Nama Baru');
    expect(restored.email, 'baru@example.com');
    expect(restored.phone, '089876543210');
    expect(restored.username, 'baru');
    expect(restored.avatarBytes, [5, 6, 7]);
    expect(() => restored.avatarBytes![0] = 42, throwsUnsupportedError);
    expect(original.name, 'Nama Awal');
  });

  test(
    'an old edit cannot overwrite another account after switching',
    () async {
      final service = ProfileService();
      final original = await service.load(fallbackName: 'Warga');
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_token', 'account-b');
      await preferences.setString('auth_user_name', 'Akun Baru');

      await expectLater(
        service.save(original.copyWith(name: 'Perubahan Akun Lama')),
        throwsA(isA<ProfileException>()),
      );

      expect(preferences.getString('auth_user_name'), 'Akun Baru');
    },
  );

  test('missing session rejects loading and a save after logout', () async {
    final service = ProfileService();
    final original = await service.load(fallbackName: 'Warga');
    await AuthService().logout();

    await expectLater(service.save(original), throwsA(isA<ProfileException>()));
    await expectLater(
      ProfileService().load(fallbackName: 'Warga'),
      throwsA(isA<ProfileException>()),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('auth_user_name'), isNull);
  });

  test('failed writes are reported and restore the prior profile', () async {
    final preferences = await SharedPreferences.getInstance();
    final failingPreferences = _FailOncePreferences(preferences);
    final service = ProfileService(
      preferencesProvider: () async => failingPreferences,
      client: _successfulProfileClient(),
    );
    final original = await service.load(fallbackName: 'Warga');

    await expectLater(
      service.save(
        original.copyWith(name: 'Tidak Tersimpan', email: 'baru@example.com'),
      ),
      throwsA(isA<ProfileException>()),
    );

    expect(preferences.getString('auth_user_name'), 'Nama Awal');
    expect(preferences.getString('auth_user_email'), 'awal@example.com');
    expect(preferences.getString('auth_user_avatar'), base64Encode([1, 2, 3]));
  });

  test(
    'updates the authenticated profile on the API before local storage',
    () async {
      late http.Request request;
      final service = ProfileService(
        client: MockClient((receivedRequest) async {
          request = receivedRequest;
          return http.Response('{}', 200);
        }),
      );
      final original = await service.load(fallbackName: 'Warga');

      await service.save(
        original.copyWith(
          name: 'Nama Baru',
          email: 'baru@example.com',
          phone: '089876543210',
          username: 'baru',
        ),
      );

      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v1/profile');
      expect(request.headers['authorization'], 'Bearer account-a');
      expect(jsonDecode(request.body), {
        'nama_lengkap': 'Nama Baru',
        'username': 'baru',
        'email': 'baru@example.com',
        'no_telepon': '089876543210',
      });
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ProfileService.emailKey),
        'baru@example.com',
      );
    },
  );

  test('changes the authenticated password through the API', () async {
    late http.Request request;
    final service = ProfileService(
      client: MockClient((receivedRequest) async {
        request = receivedRequest;
        return http.Response('{}', 200);
      }),
    );
    await service.load(fallbackName: 'Warga');

    await service.changePassword(
      currentPassword: 'password-lama',
      newPassword: 'password-baru',
    );

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/profile/password');
    expect(request.headers['authorization'], isNotEmpty);
    expect(jsonDecode(request.body), {
      'current_password': 'password-lama',
      'password': 'password-baru',
      'password_confirmation': 'password-baru',
    });
  });

  test('loads the saved address from the authenticated profile', () async {
    late http.Request request;
    final service = ProfileService(
      client: MockClient((receivedRequest) async {
        request = receivedRequest;
        return http.Response(
          jsonEncode({
            'data': {
              'user': {
                'id_desa': 7,
                'nama_desa': 'Desa Contoh',
                'rt': '03',
                'rw': '02',
                'alamat_detail': 'Dekat balai desa',
              },
            },
          }),
          200,
        );
      }),
    );

    final address = await service.loadSavedAddress();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/profile');
    expect(request.headers['authorization'], isNotEmpty);
    expect(address?.villageId, 7);
    expect(address?.villageName, 'Desa Contoh');
    expect(address?.rt, '03');
    expect(address?.rw, '02');
    expect(address?.detail, 'Dekat balai desa');
  });

  test('saves only the selected account address to the profile API', () async {
    late http.Request request;
    final service = ProfileService(
      client: MockClient((receivedRequest) async {
        request = receivedRequest;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'user': {
                'id_desa': 7,
                'nama_desa': 'Desa Contoh',
                'rt': '03',
                'rw': '02',
                'alamat_detail': 'Dekat balai desa',
              },
            },
          }),
          200,
        );
      }),
    );
    const address = SavedAddress(
      villageId: 7,
      villageName: 'Desa Contoh',
      rt: '03',
      rw: '02',
      detail: 'Dekat balai desa',
    );

    final saved = await service.saveAddress(
      address,
      profile: LocalProfile(
        name: 'Nama Akun',
        username: 'akun',
        email: 'akun@example.com',
        phone: '081234567890',
      ),
    );

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/profile');
    expect(request.headers['authorization'], isNotEmpty);
    expect(jsonDecode(request.body), {
      'nama_lengkap': 'Nama Akun',
      'username': 'akun',
      'email': 'akun@example.com',
      'no_telepon': '081234567890',
      'id_desa': 7,
      'rt': '03',
      'rw': '02',
      'alamat_detail': 'Dekat balai desa',
    });
    expect(saved.villageId, address.villageId);
    expect(saved.villageName, address.villageName);
    expect(saved.rt, address.rt);
    expect(saved.rw, address.rw);
    expect(saved.detail, address.detail);
  });

  test(
    'reports address API validation errors instead of caching locally',
    () async {
      final service = ProfileService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'message': 'Desa tidak valid.'}), 422),
        ),
      );

      await expectLater(
        service.saveAddress(
          const SavedAddress(
            villageId: 0,
            rt: '01',
            rw: '01',
            detail: 'Detail',
          ),
          profile: LocalProfile(
            name: 'Nama Akun',
            username: 'akun',
            email: 'akun@example.com',
            phone: '081234567890',
          ),
        ),
        throwsA(
          isA<ProfileException>().having(
            (error) => error.message,
            'message',
            'Desa tidak valid.',
          ),
        ),
      );
    },
  );

  test('reports password change errors returned by the API', () async {
    final service = ProfileService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Password lama tidak sesuai.'}),
          422,
        ),
      ),
    );
    await service.load(fallbackName: 'Warga');

    await expectLater(
      service.changePassword(
        currentPassword: 'salah',
        newPassword: 'password-baru',
      ),
      throwsA(
        isA<ProfileException>().having(
          (error) => error.message,
          'message',
          'Password lama tidak sesuai.',
        ),
      ),
    );
  });

  test(
    'does not save locally when the API rejects the profile update',
    () async {
      final service = ProfileService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Email sudah digunakan.'}),
            422,
          ),
        ),
      );
      final original = await service.load(fallbackName: 'Warga');

      await expectLater(
        service.save(original.copyWith(email: 'terpakai@example.com')),
        throwsA(
          isA<ProfileException>().having(
            (error) => error.message,
            'message',
            'Email sudah digunakan.',
          ),
        ),
      );

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ProfileService.emailKey),
        'awal@example.com',
      );
    },
  );

  test('login seeds profile fields and removes the previous photo', () async {
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'token': 'account-b',
              'user': {
                'name': 'Pengguna Baru',
                'email': 'baru@example.com',
                'no_hp': '081111111111',
                'username': 'pengguna_baru',
                'roles': ['warga'],
              },
            },
          }),
          200,
        ),
      ),
    );

    await auth.login(identifier: 'pengguna_baru', password: 'password');
    final profile = await ProfileService().load(fallbackName: 'Warga');

    expect(profile.name, 'Pengguna Baru');
    expect(profile.email, 'baru@example.com');
    expect(profile.phone, '081111111111');
    expect(profile.username, 'pengguna_baru');
    expect(profile.avatarBytes, isNull);
  });

  test(
    'login without optional fields does not retain old account data',
    () async {
      final auth = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'token': 'account-b',
              'user': {'name': 'Pengguna Baru', 'role': 'warga'},
            }),
            200,
          ),
        ),
      );

      await auth.login(identifier: 'pengguna_baru', password: 'password');
      final profile = await ProfileService().load(fallbackName: 'Warga');

      expect(profile.email, isEmpty);
      expect(profile.phone, isEmpty);
      expect(profile.username, isEmpty);
      expect(profile.avatarBytes, isNull);
    },
  );

  test('legacy registration replaces the previous local profile', () async {
    late Map<String, dynamic> requestBody;
    final api = ApiService(
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'token': 'account-b',
            'user': {
              'nama_lengkap': 'Warga Baru',
              'email': 'warga@example.com',
              'username': 'warga_baru',
            },
          }),
          201,
        );
      }),
    );

    await api.register(
      namaLengkap: 'Warga Baru',
      username: 'warga_baru',
      email: 'warga@example.com',
      phone: '081234567890',
      password: 'password',
    );
    final profile = await ProfileService().load(fallbackName: 'Warga');

    expect(profile.name, 'Warga Baru');
    expect(profile.email, 'warga@example.com');
    expect(profile.username, 'warga_baru');
    expect(profile.phone, '081234567890');
    expect(profile.avatarBytes, isNull);
    expect(requestBody['email'], 'warga@example.com');
    expect(requestBody['no_hp'], '081234567890');
  });

  test(
    'registration seeds submitted details if response omits user data',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'token': 'account-b'}), 201),
        ),
      );

      await api.register(
        namaLengkap: 'Warga Baru',
        username: 'warga_baru',
        email: 'warga@example.com',
        phone: '081234567890',
        password: 'password',
      );
      final profile = await ProfileService().load(fallbackName: 'Warga');

      expect(profile.name, 'Warga Baru');
      expect(profile.email, 'warga@example.com');
      expect(profile.phone, '081234567890');
      expect(profile.username, 'warga_baru');
    },
  );

  for (final legacy in [false, true]) {
    test(
      '${legacy ? 'legacy' : 'current'} logout clears all local fields',
      () async {
        if (legacy) {
          await ApiService.clearSavedSession();
        } else {
          await AuthService().logout();
        }
        final preferences = await SharedPreferences.getInstance();

        expect(
          preferences.getKeys().where((key) => key.startsWith('auth_')),
          isEmpty,
        );
        expect(preferences.getStringList('saved_citizen_tickets'), ['TIKET-1']);
      },
    );
  }
}

http.Client _successfulProfileClient() =>
    MockClient((_) async => http.Response('{}', 200));

/// Models a rejected storage write, including SharedPreferences' updated cache.
class _FailOncePreferences implements SharedPreferences {
  _FailOncePreferences(this.delegate);

  final SharedPreferences delegate;
  bool _failed = false;

  @override
  String? getString(String key) => delegate.getString(key);

  @override
  Future<bool> setString(String key, String value) async {
    final result = await delegate.setString(key, value);
    if (key == ProfileService.emailKey && !_failed) {
      _failed = true;
      return false;
    }
    return result;
  }

  @override
  Future<bool> remove(String key) => delegate.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
