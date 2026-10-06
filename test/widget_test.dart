// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:klinik_sanitasi_mobile/main.dart';
import 'package:klinik_sanitasi_mobile/models/education_article.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/models/village.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';

void main() {
  testWidgets('citizen home and navigation render', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(apiService: _FakeApiService()));
    await tester.pumpAndSettle();

    expect(find.text('KLINIK SANITASI'), findsOneWidget);
    expect(find.text('Edukasi kesehatan'), findsOneWidget);
    expect(find.text('Lacak'), findsOneWidget);
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
