import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/models/village.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/views/public/report_view.dart';

class _FakeReportApiService extends ApiService {
  @override
  Future<List<Village>> getVillages() async {
    return [
      const Village(id: 1, name: 'Desa Sumbersari'),
      const Village(id: 2, name: 'Desa Sukamaju'),
    ];
  }
}

void main() {
  testWidgets('ReportView renders header, form groups, and submit button precisely', (
    WidgetTester tester,
  ) async {
    final fakeApi = _FakeReportApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportView(apiService: fakeApi),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Buat Laporan'), findsOneWidget);
    expect(
      find.text('Sampaikan masalah air atau sanitasi\ndi lingkungan Anda.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // Verify Section 1: Data Pelapor
    expect(find.text('Data Pelapor'), findsOneWidget);
    expect(find.text('Nama lengkap'), findsOneWidget);
    expect(find.text('NIK'), findsOneWidget);
    expect(find.text('Nomor telepon'), findsOneWidget);

    // Verify Section 2: Lokasi Kejadian
    expect(find.text('Lokasi Kejadian'), findsOneWidget);
    expect(find.text('Desa / Kelurahan'), findsOneWidget);
    expect(find.text('Pilih desa'), findsOneWidget);
    expect(find.text('RT'), findsOneWidget);
    expect(find.text('RW'), findsOneWidget);

    // Verify Section 3: Detail Laporan
    expect(find.text('Detail Laporan'), findsOneWidget);
    expect(find.text('Kategori Laporan'), findsOneWidget);
    expect(find.text('Masalah air'), findsOneWidget);
    expect(find.text('Deskripsi masalah'), findsOneWidget);
    expect(find.text('0/2000'), findsOneWidget);

    // Verify Character Counter updates
    final descField = find.widgetWithText(TextFormField, '0/2000');
    // Or enter text in description field
    await tester.enterText(find.byType(TextFormField).last, 'Air keruh dan berbau.');
    await tester.pumpAndSettle();
    expect(find.text('21/2000'), findsOneWidget);

    // Verify Submit Button
    expect(find.text('Kirim Laporan'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}

