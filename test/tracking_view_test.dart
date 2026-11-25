import 'dart:async';

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
  Future<List<String>> syncCitizenTicketsHistory() async =>
      getSavedCitizenTicketCodes();

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
  int syncCount = 0;

  @override
  Future<List<String>> syncCitizenTicketsHistory() async {
    syncCount++;
    throw const ApiException('Tidak ada koneksi internet.');
  }

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
  Future<List<String>> syncCitizenTicketsHistory() async => [];

  @override
  Future<List<String>> getSavedCitizenTicketCodes() async => [];

  @override
  Future<TicketStatus> getTicket(String code) async => TicketStatus.fromJson({
    'kode_tiket': code,
    'status_laporan': inspected ? 'selesai' : 'dijadwalkan',
    'hasil_inspeksi': inspected
        ? {
            'total_skor_ya': 3,
            'kategori_risiko': 'risiko_tinggi',
            'tanggal_inspeksi': '2026-11-02',
            'rekomendasi_sanitarian': 'Perbaiki penutup sumur.',
          }
        : null,
  });
}

class _AggregateCacheTrackingApiService extends ApiService {
  @override
  Future<List<String>> syncCitizenTicketsHistory() async => [];

  @override
  Future<List<String>> getSavedCitizenTicketCodes() async => [];

  @override
  Future<List<TicketStatus>> getCachedCitizenTicketStatuses() async => [
    const TicketStatus(
      code: 'TK-CACHED-ONLY',
      status: 'dikirim',
      category: 'air_masalah',
      description: 'Laporan dari cache.',
      village: 'Desa Sehat',
      rt: '02',
      rw: '04',
      createdAt: '2026-10-29',
    ),
  ];
}

class _CacheFirstTrackingApiService extends ApiService {
  final syncCompleter = Completer<List<String>>();
  static const cachedTicket = TicketStatus(
    code: 'TK-CACHE-FIRST',
    status: 'dikirim',
    category: 'air_masalah',
    description: 'Data lokal tersedia.',
    village: 'Desa Sehat',
    rt: '02',
    rw: '04',
    createdAt: '2026-10-29',
  );

  @override
  Future<List<String>> syncCitizenTicketsHistory() => syncCompleter.future;

  @override
  Future<List<String>> getSavedCitizenTicketCodes() async => [
    cachedTicket.code,
  ];

  @override
  Future<List<TicketStatus>> getCachedCitizenTicketStatuses() async => [
    cachedTicket,
  ];

  @override
  Future<TicketStatus?> getCachedTicketStatus(String code) async =>
      cachedTicket;

  @override
  Future<TicketStatus> getTicket(String code) async => cachedTicket;
}

class _UnavailableTrackingApiService extends ApiService {
  int syncCount = 0;

  @override
  Future<List<String>> syncCitizenTicketsHistory() async {
    syncCount++;
    throw const ApiException('Tidak dapat terhubung ke server.');
  }

  @override
  Future<List<String>> getSavedCitizenTicketCodes() async => [];

  @override
  Future<List<TicketStatus>> getCachedCitizenTicketStatuses() async => [];
}

class _EmptyTrackingApiService extends ApiService {
  @override
  Future<List<String>> syncCitizenTicketsHistory() async => [];

  @override
  Future<List<String>> getSavedCitizenTicketCodes() async => [];

  @override
  Future<List<TicketStatus>> getCachedCitizenTicketStatuses() async => [];
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

    final headerRect = tester.getRect(
      find.byKey(const Key('tracking_detail_header')),
    );
    expect(headerRect.left, 0);
    expect(headerRect.top, 0);
    expect(headerRect.width, 390);
    expect(headerRect.height, 265);
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
      expect(find.text('Coba Lagi'), findsOneWidget);
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(apiService.syncCount, 2);
      expect(apiService.requestCount, 0);

      await tester.tap(find.text('Selesai / Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada laporan di kategori ini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history shows aggregate cache when saved codes are unavailable',
    (WidgetTester tester) async {
      final apiService = _AggregateCacheTrackingApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackingView(apiService: apiService)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TK-CACHED-ONLY'), findsOneWidget);
      expect(find.text('Laporan dari cache.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders cached history before background refresh completes', (
    WidgetTester tester,
  ) async {
    final apiService = _CacheFirstTrackingApiService();

    await tester.pumpWidget(
      MaterialApp(home: TrackingView(apiService: apiService)),
    );
    for (
      var frame = 0;
      frame < 10 && find.text('TK-CACHE-FIRST').evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('TK-CACHE-FIRST'), findsOneWidget);
    expect(find.byKey(const Key('tracking_refresh_indicator')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);

    apiService.syncCompleter.complete([
      _CacheFirstTrackingApiService.cachedTicket.code,
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('network failure shows retry and eventually stops loading', (
    WidgetTester tester,
  ) async {
    final apiService = _UnavailableTrackingApiService();

    await tester.pumpWidget(
      MaterialApp(home: TrackingView(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Gagal memuat data dari server. Periksa koneksi Wi-Fi Anda.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();
    expect(apiService.syncCount, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty history can open the report tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reportOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TrackingView(
          apiService: _EmptyTrackingApiService(),
          onOpenReport: () => reportOpened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada riwayat laporan'), findsOneWidget);
    await tester.ensureVisible(find.text('Lapor Sekarang'));
    await tester.tap(find.text('Lapor Sekarang'));
    expect(reportOpened, isTrue);
  });

  testWidgets(
    'completed ticket prioritizes examination results and folds initial report',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _InspectionTrackingApiService();
      Widget screen(bool active) => MaterialApp(
        home: TrackingView(
          apiService: api,
          initialTicketCode: 'IKL-1',
          isActive: active,
        ),
      );
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('citizen_inspection_result')),
      );
      expect(find.text('Menunggu hasil pemeriksaan petugas.'), findsOneWidget);
      expect(find.text('Aman'), findsNothing);

      await tester.pumpWidget(screen(false));
      api.inspected = true;
      await tester.pumpWidget(screen(true));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Penanganan Selesai'));
      final statusBottom = tester
          .getBottomLeft(find.text('Penanganan Selesai'))
          .dy;
      final resultTop = tester
          .getTopLeft(find.byKey(const Key('citizen_inspection_result')))
          .dy;
      final progressTop = tester.getTopLeft(find.text('Progres penanganan')).dy;
      expect(resultTop, greaterThan(statusBottom));
      expect(progressTop, greaterThan(resultTop));

      await tester.ensureVisible(
        find.byKey(const Key('citizen_inspection_result')),
      );
      expect(find.text('Hasil Pemeriksaan Petugas'), findsOneWidget);
      expect(find.text('Risiko Tinggi'), findsOneWidget);
      expect(find.text('Skor: 3 dari 5'), findsOneWidget);
      expect(find.text('Perbaiki penutup sumur.'), findsOneWidget);

      expect(find.text('Nama pelapor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
