// This is a basic Flutter widget test.

//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klinik_sanitasi_mobile/main.dart';
import 'package:klinik_sanitasi_mobile/models/education_article.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/models/user_model.dart';
import 'package:klinik_sanitasi_mobile/models/village.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app flow: splash opens login and login opens registration', (
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

  testWidgets('splash restores the saved officer role', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'auth_role': 'admin',
      'auth_user_name': 'Petugas Contoh',
    });
    await tester.pumpWidget(MyApp(apiService: _FakeApiService()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang,'), findsOneWidget);
    expect(find.text('Petugas Contoh'), findsOneWidget);
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
    expect(find.text('Halo, Warga'), findsOneWidget);
    expect(find.text('Info Kesehatan'), findsOneWidget);
    expect(find.text('Lapor\nPengaduan'), findsOneWidget);
    expect(find.text('Status\nLaporan'), findsOneWidget);
    expect(find.text('Edukasi &\nSTBM'), findsOneWidget);
    expect(find.text('PENGUMUMAN'), findsOneWidget);
    expect(find.text('Lacak'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Sesi pengguna tidak ditemukan.'), findsOneWidget);
  });

  testWidgets('petugas role opens the field dashboard', (
    WidgetTester tester,
  ) async {
    await _openLogin(tester, const ['petugas']);
    await _submitLogin(tester);

    expect(find.text('Selamat Datang,'), findsOneWidget);
    expect(find.text('Petugas Contoh'), findsOneWidget);
  });

  testWidgets('admin role opens the field dashboard', (
    WidgetTester tester,
  ) async {
    await _openLogin(tester, const ['admin']);
    await _submitLogin(tester);

    expect(find.text('Selamat Datang,'), findsOneWidget);
    expect(find.text('Petugas Contoh'), findsOneWidget);
  });

  testWidgets('warga role opens the existing public home', (
    WidgetTester tester,
  ) async {
    await _openLogin(tester, const ['warga']);
    await _submitLogin(tester);

    expect(find.text('KLINIK SANITASI'), findsOneWidget);
    expect(find.text('Info Kesehatan'), findsOneWidget);
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

Future<void> _openLogin(WidgetTester tester, List<String> roles) async {
  await tester.pumpWidget(
    MyApp(apiService: _FakeApiService(), authService: _FakeAuthService(roles)),
  );
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  expect(find.text('Masuk ke Akun'), findsOneWidget);
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'warga@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
}

class _FakeApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> register({
    required String namaLengkap,
    required String username,
    required String email,
    required String password,
  }) async {
    throw const ApiException('Autentikasi belum terhubung ke backend.');
  }

  @override
  Future<List<EducationArticle>> getArticles() async => [];

  @override
  Future<List<Village>> getVillages() async => [];

  @override
  Future<TicketStatus> getTicket(String code) async {
    throw const ApiException('Kode tiket tidak ditemukan.');
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.roles);

  final List<String> roles;

  @override
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async =>
      UserModel(token: 'test-token', roles: roles, name: 'Petugas Contoh');
}
