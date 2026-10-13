// This is a basic Flutter widget test.

//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:klinik_sanitasi_mobile/main.dart';
import 'package:klinik_sanitasi_mobile/models/education_article.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/models/village.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';

void main() {
  testWidgets('splash opens login and login opens registration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(apiService: _FakeApiService()));

    expect(find.text('E-Klinik Sanitasi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke Akun'), findsOneWidget);
    await tester.ensureVisible(find.text('Daftar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Buat Akun'), findsOneWidget);
    expect(find.text('Konfirmasi Kata Sandi'), findsOneWidget);
  });

  testWidgets('existing home shell remains available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(apiService: _FakeApiService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed('/home');
    await tester.pumpAndSettle();

    expect(find.text('KLINIK SANITASI'), findsOneWidget);
    expect(find.text('Edukasi kesehatan'), findsOneWidget);
    expect(find.text('Lacak'), findsOneWidget);
  });

  testWidgets('registration validates confirmation and consent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(apiService: _FakeApiService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);

    Future<void> enterField(int index, String value) async {
      await tester.ensureVisible(fields.at(index));
      await tester.enterText(fields.at(index), value);
    }

    await enterField(0, 'Siti Aminah');
    await enterField(1, 'siti');
    await enterField(2, 'siti@example.com');
    await enterField(3, 'password123');
    await enterField(4, 'different123');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Kata sandi tidak cocok.'), findsOneWidget);

    await enterField(4, 'password123');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Persetujuan wajib diberikan untuk mendaftar.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Daftar'));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Autentikasi belum terhubung ke backend.'),
      findsOneWidget,
    );
  });
}

class _FakeApiService extends ApiService {
  @override
  Future<List<EducationArticle>> getArticles() async => [];

  @override
  Future<List<Village>> getVillages() async => [];

  @override
  Future<TicketStatus> getTicket(String code) async {
    throw const ApiException('Kode tiket tidak ditemukan.');
  }
}
