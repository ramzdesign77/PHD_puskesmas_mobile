import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/auth/register_view.dart';

void main() {
  testWidgets('registration links show draft terms and privacy documents', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterView(
          apiService: ApiService(
            client: MockClient((_) async {
              fail('The legal document dialog must not call the API.');
            }),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Syarat & Ketentuan'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Syarat & Ketentuan'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('register_legal_notice_draft')),
      findsOneWidget,
    );
    expect(find.text('1. Tujuan layanan'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Kebijakan Privasi'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Kebijakan Privasi'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('register_legal_notice_draft')),
      findsOneWidget,
    );
    expect(find.text('1. Data yang digunakan'), findsOneWidget);
    expect(find.textContaining('Koordinat GPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration validates name, username, and phone locally', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = MockClient((_) async {
      fail('Registration API should not be called for invalid fields.');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterView(apiService: ApiService(client: client)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    Future<void> enter(Key key, String value) async {
      final field = find.byKey(key);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await enter(const Key('register_name_field'), 'A');
    await enter(const Key('register_username_field'), 'user name');
    await enter(const Key('register_email_field'), 'warga@example.test');
    await enter(const Key('register_phone_field'), '08123');
    await enter(const Key('register_password_field'), 'secret123');
    await enter(const Key('register_confirmation_field'), 'secret123');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Daftar'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nama lengkap minimal 2 karakter.'), findsOneWidget);
    expect(
      find.text('Gunakan huruf, angka, titik, garis bawah, atau tanda hubung.'),
      findsOneWidget,
    );
    expect(
      find.text('Gunakan format nomor Indonesia: 08... atau +62 8...'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration rejects phone numbers outside Indonesia', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = MockClient((_) async {
      fail('Registration API should not be called for an invalid phone.');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterView(apiService: ApiService(client: client)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final phone = find.byKey(const Key('register_phone_field'));
    await tester.ensureVisible(phone);
    await tester.enterText(phone, '12345678901');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Daftar'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Gunakan format nomor Indonesia: 08... atau +62 8...'),
      findsOneWidget,
    );

    await tester.enterText(phone, '+62 812 3456 7890');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<TextFormField>(phone).controller!.text,
      '6281234567890',
    );
    expect(
      find.text('Gunakan format nomor Indonesia: 08... atau +62 8...'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration rejects numbers in the full name', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = MockClient((_) async {
      fail('Registration API should not be called for an invalid name.');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterView(apiService: ApiService(client: client)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final name = find.byKey(const Key('register_name_field'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Budi2 Santoso');
    await tester.ensureVisible(find.text('Daftar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Daftar'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Nama lengkap hanya boleh berisi huruf dan spasi.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'registration keeps phone input numeric and shows server field errors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      late Map<String, dynamic> requestBody;
      final client = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'message': 'Data registrasi tidak valid.',
            'errors': {
              'username': ['Username sudah digunakan.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RegisterView(apiService: ApiService(client: client)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      Future<void> enter(Key key, String value) async {
        final field = find.byKey(key);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await enter(const Key('register_name_field'), ' Warga Contoh ');
      await enter(const Key('register_username_field'), 'warga.contoh_1');
      await enter(const Key('register_email_field'), 'WARGA@EXAMPLE.TEST');
      final phoneField = find.byKey(const Key('register_phone_field'));
      await enter(const Key('register_phone_field'), '0812abc34567890');
      expect(
        tester.widget<TextFormField>(phoneField).controller!.text,
        '081234567890',
      );
      await enter(const Key('register_password_field'), 'secret123');
      await enter(const Key('register_confirmation_field'), 'secret123');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(Checkbox));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('Daftar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Daftar'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(requestBody['nama_lengkap'], 'Warga Contoh');
      expect(requestBody['username'], 'warga.contoh_1');
      expect(requestBody['email'], 'warga@example.test');
      expect(requestBody['no_telepon'], '081234567890');
      expect(find.text('Username sudah digunakan.'), findsOneWidget);

      await enter(const Key('register_username_field'), 'warga.contoh.2');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Username sudah digunakan.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registration password stays editable after validation fails', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterView(
          apiService: ApiService(
            client: MockClient((_) async {
              fail('Registration API should not be called for invalid fields.');
            }),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final password = find.byKey(const Key('register_password_field'));
    await tester.ensureVisible(password);
    await tester.enterText(password, 'dani12');
    final registerButton = find.text('Daftar');
    await tester.ensureVisible(registerButton);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(registerButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Kata sandi minimal 8 karakter.'), findsOneWidget);
    expect(tester.widget<TextFormField>(password).enabled, isTrue);

    await tester.enterText(password, '');
    expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
    await tester.enterText(password, 'password-baru');
    expect(
      tester.widget<TextFormField>(password).controller!.text,
      'password-baru',
    );
    expect(find.text('Kata sandi minimal 8 karakter.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
