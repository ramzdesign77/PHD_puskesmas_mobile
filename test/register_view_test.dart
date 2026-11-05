import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/auth/register_view.dart';

void main() {
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
    await tester.pumpAndSettle();

    final password = find.byKey(const Key('register_password_field'));
    await tester.ensureVisible(password);
    await tester.enterText(password, 'dani12');
    final registerButton = find.text('Daftar');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

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
