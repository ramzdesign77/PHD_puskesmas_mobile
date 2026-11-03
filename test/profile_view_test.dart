import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klinik_sanitasi_mobile/services/profile_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/profile/edit_profile_view.dart';
import 'package:klinik_sanitasi_mobile/views/profile/profile_view.dart';

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
