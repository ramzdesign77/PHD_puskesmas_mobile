import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klinik_sanitasi_mobile/services/profile_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/profile/change_password_view.dart';
import 'package:klinik_sanitasi_mobile/views/profile/edit_profile_view.dart';
import 'package:klinik_sanitasi_mobile/views/profile/profile_view.dart';
import 'package:klinik_sanitasi_mobile/views/profile/profile_widgets.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'profile-test-session',
      ProfileService.nameKey: 'Rina Puspita',
      ProfileService.emailKey: 'rina@example.com',
      ProfileService.phoneKey: '081234567890',
      ProfileService.usernameKey: 'rina',
    });
  });

  testWidgets('editing a profile saves the fields and updates its card', (
    tester,
  ) async {
    LocalProfile? changedProfile;
    await _openProfile(
      tester,
      onProfileChanged: (profile) => changedProfile = profile,
    );
    await _openEditor(tester);

    await tester.enterText(_field('name'), 'Rina Utami');
    await tester.enterText(_field('phone'), '081298765432');
    await tester.enterText(_field('email'), 'rina.utami@example.com');
    await tester.enterText(_field('username'), 'rina_utami');
    await _saveProfile(tester);

    expect(find.byType(EditProfileView), findsNothing);
    expect(find.text('Rina Utami'), findsOneWidget);
    expect(changedProfile?.name, 'Rina Utami');
    final reloaded = await ProfileService().load(fallbackName: 'Warga');
    expect(reloaded.name, 'Rina Utami');
    expect(reloaded.phone, '081298765432');
    expect(reloaded.email, 'rina.utami@example.com');
    expect(reloaded.username, 'rina_utami');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid profile details remain in the form without saving', (
    tester,
  ) async {
    await _openProfile(tester);
    await _openEditor(tester);

    await tester.enterText(_field('name'), '   ');
    await tester.enterText(_field('email'), 'email-tidak-valid');
    await _saveProfile(tester);

    expect(find.byType(EditProfileView), findsOneWidget);
    expect(
      tester.state<FormFieldState<String>>(_field('name')).hasError,
      isTrue,
    );
    expect(
      tester.state<FormFieldState<String>>(_field('email')).hasError,
      isTrue,
    );
    final reloaded = await ProfileService().load(fallbackName: 'Warga');
    expect(reloaded.name, 'Rina Puspita');
    expect(reloaded.email, 'rina@example.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the editor discards unsaved profile changes', (
    tester,
  ) async {
    await _openProfile(tester);
    await _openEditor(tester);
    await tester.enterText(_field('name'), 'Belum Disimpan');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileView), findsNothing);
    expect(find.text('Rina Puspita'), findsOneWidget);
    expect(find.text('Belum Disimpan'), findsNothing);
    await _openEditor(tester);
    final nameField = tester.widget<TextFormField>(_field('name'));
    expect(nameField.controller?.text, 'Rina Puspita');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile and editor fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await _openProfile(tester, textScale: 1.5);
    expect(tester.takeException(), isNull);
    await _openEditor(tester);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.ensureVisible(_field('email'));
    await tester.enterText(_field('email'), 'rina.baru@example.com');
    await _saveProfile(tester);

    expect(find.byType(EditProfileView), findsNothing);
    expect(tester.takeException(), isNull);
    final reloaded = await ProfileService().load(fallbackName: 'Warga');
    expect(reloaded.email, 'rina.baru@example.com');
  });

  testWidgets('account settings open the change password form', (tester) async {
    await _openProfile(tester);

    expect(find.text('Ganti password'), findsOneWidget);
    final changePasswordButton = find.byKey(
      const Key('profile_change_password_button'),
    );
    await tester.ensureVisible(changePasswordButton);
    await tester.tap(changePasswordButton);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordView), findsOneWidget);
    expect(find.text('Password lama'), findsOneWidget);
    expect(find.text('Password baru'), findsOneWidget);
    expect(find.text('Konfirmasi password baru'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('profile_change_password_save_button')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .state<FormFieldState<String>>(
            find.byKey(const Key('profile_current_password_field')),
          )
          .hasError,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('password fields stay editable after validation fails', (
    tester,
  ) async {
    await _openProfile(tester);
    final changePasswordButton = find.byKey(
      const Key('profile_change_password_button'),
    );
    await tester.ensureVisible(changePasswordButton);
    await tester.tap(changePasswordButton);
    await tester.pumpAndSettle();

    final currentPassword = find.byKey(
      const Key('profile_current_password_field'),
    );
    final newPassword = find.byKey(const Key('profile_new_password_field'));
    final confirmation = find.byKey(
      const Key('profile_password_confirmation_field'),
    );
    await tester.enterText(currentPassword, 'password-lama');
    await tester.enterText(newPassword, 'dani12');
    await tester.enterText(confirmation, 'dani12');
    final saveButton = find.byKey(
      const Key('profile_change_password_save_button'),
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
    expect(tester.widget<TextFormField>(newPassword).enabled, isTrue);

    await tester.enterText(newPassword, '');
    expect(tester.widget<TextFormField>(newPassword).controller!.text, isEmpty);
    await tester.enterText(newPassword, 'password-baru');
    expect(
      tester.widget<TextFormField>(newPassword).controller!.text,
      'password-baru',
    );
    expect(find.text('Password minimal 8 karakter.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page uses the water header with profile reload', (
    tester,
  ) async {
    await _openProfile(tester);

    expect(find.byKey(const Key('profile_water_header')), findsOneWidget);
    expect(find.byKey(const Key('profile_reload_button')), findsOneWidget);
    expect(find.text('Pengaturan'), findsNothing);
    expect(find.text('Kelola akun dan preferensi aplikasi.'), findsNothing);
    expect(find.text('Muat ulang profil'), findsNothing);
    expect(find.byType(ProfileAvatar), findsOneWidget);
    final avatarCenter = tester.getCenter(find.byType(ProfileAvatar));
    final waterHeaderRect = tester.getRect(
      find.byKey(const Key('profile_water_header')),
    );
    expect(
      avatarCenter.dx,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        1,
      ),
    );
    expect(avatarCenter.dy, greaterThan(waterHeaderRect.top + 100));
    expect(avatarCenter.dy, lessThan(waterHeaderRect.bottom));
    expect(tester.takeException(), isNull);
  });
}

Finder _field(String name) => find.byKey(Key('profile_${name}_field'));

Future<void> _openProfile(
  WidgetTester tester, {
  ValueChanged<LocalProfile>? onProfileChanged,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ProfileView(
          fallbackName: 'Warga',
          roleLabel: 'Warga',
          onBack: () {},
          onLogout: () {},
          onProfileChanged: onProfileChanged,
          profileService: ProfileService(
            client: MockClient((request) async {
              final values = request.method == 'PUT'
                  ? jsonDecode(request.body) as Map<String, dynamic>
                  : const <String, dynamic>{};
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'user': {
                      'nama_lengkap': values['nama_lengkap'] ?? 'Rina Puspita',
                      'username': values['username'] ?? 'rina',
                      'email': values['email'] ?? 'rina@example.com',
                      'no_telepon': values['no_telepon'] ?? '081234567890',
                    },
                  },
                }),
                200,
              );
            }),
          ),
        ),
        bottomNavigationBar: const SizedBox(height: 80),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  final editButton = find.byKey(const Key('profile_edit_button'));
  await tester.ensureVisible(editButton);
  await tester.tap(editButton);
  await tester.pumpAndSettle();
  expect(find.byType(EditProfileView), findsOneWidget);
}

Future<void> _saveProfile(WidgetTester tester) async {
  tester.testTextInput.hide();
  final saveButton = find.byKey(const Key('profile_save_button'));
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}
