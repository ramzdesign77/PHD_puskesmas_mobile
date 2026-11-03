import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/views/public/tracking_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTrackingApiService extends ApiService {
  int requestCount = 0;
  final List<String> requestedCodes = [];

  @override
  Future<TicketStatus> getTicket(String code) async {
    requestCount++;
    requestedCodes.add(code);
    return const TicketStatus(
      code: 'TK-20261030-0001',
      status: 'dijadwalkan',
      category: 'air_masalah',
      description: 'Air sumur keruh.',
      reporterName: 'Warga Contoh',
      village: 'Desa Sehat',
      rt: '02',
      rw: '04',
      createdAt: '2026-10-29 08:00',
      visitDate: '2026-10-31 09:00',
      officer: 'Petugas Contoh',
      intervention: 'Pemeriksaan kualitas air',
    );
  }
}

class _OfflineTrackingApiService extends _FakeTrackingApiService {
  @override
  Future<TicketStatus> getTicket(String code) async {
    requestCount++;
    throw const ApiException('Tidak ada koneksi internet.');
  }

  @override
  Future<TicketStatus?> getCachedTicketStatus(String code) async =>
      const TicketStatus(
        code: 'TK-20261030-0001',
        status: 'dijadwalkan',
        category: 'air_masalah',
        description: 'Air sumur keruh.',
        reporterName: 'Warga Contoh',
        village: 'Desa Sehat',
        rt: '02',
        rw: '04',
        createdAt: '2026-10-29 08:00',
        visitDate: '2026-10-31 09:00',
        officer: 'Petugas Contoh',
      );
}

class _InspectionTrackingApiService extends ApiService {
  bool inspected = false;

  @override
  Future<TicketStatus> getTicket(String code) async => TicketStatus.fromJson({
    'kode_tiket': code,
    'status_laporan': inspected ? 'selesai' : 'dijadwalkan',
    'hasil_inspeksi': inspected ? {
      'total_skor_ya': 3,
      'kategori_risiko': 'risiko_tinggi',
      'tanggal_inspeksi': '2026-11-02',
      'rekomendasi_sanitarian': 'Perbaiki penutup sumur.',
    } : null,
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('initial ticket loads automatically and tracker fits screen', (
    WidgetTester tester,
  ) async {
    final apiService = _FakeTrackingApiService();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackingView(
            apiService: apiService,
            initialTicketCode: 'TK-20261030-0001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(apiService.requestCount, 1);
    expect(apiService.requestedCodes.single, 'TK-20261030-0001');
    expect(find.text('Laporan Sedang Dijadwalkan'), findsOneWidget);
    expect(find.text('Petugas Contoh'), findsOneWidget);
    expect(find.text('Pemeriksaan kualitas air'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, 360));
    await tester.pumpAndSettle();
    expect(apiService.requestCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history shows cached tickets while offline and filters completed',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'saved_citizen_tickets': ['TK-20261030-0001'],
      });
      final apiService = _OfflineTrackingApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackingView(apiService: apiService)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lacak laporan'), findsOneWidget);
      expect(find.text('TK-20261030-0001'), findsOneWidget);
      expect(
        find.textContaining('Sebagian status belum dapat diperbarui'),
        findsOneWidget,
      );

      await tester.tap(find.text('Selesai / Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada laporan di kategori ini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('refresh displays the official inspection result to the citizen', (tester) async {
    final api = _InspectionTrackingApiService();
    Widget screen(bool active) => MaterialApp(home: TrackingView(
      apiService: api, initialTicketCode: 'IKL-1', isActive: active,
    ));
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('citizen_inspection_result')));
    expect(find.text('Menunggu hasil inspeksi petugas.'), findsOneWidget);
    expect(find.text('Aman'), findsNothing);

    await tester.pumpWidget(screen(false));
    api.inspected = true;
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('citizen_inspection_result')));
    expect(find.text('Tinggi'), findsOneWidget);
    expect(find.text('Skor: 3 dari 5'), findsOneWidget);
    expect(find.text('Perbaiki penutup sumur.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
