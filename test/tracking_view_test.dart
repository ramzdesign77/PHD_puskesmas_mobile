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
  final List<
    ({
      int page,
      int perPage,
      String? status,
      String? startDate,
      String? endDate,
    })
  >
  pageRequests = [];
  final Map<int, CitizenReportPage> pages = {};
  Object? pageError;
  Completer<CitizenReportPage>? pageCompleter;

  @override
  Future<CitizenReportPage> getCitizenReportsPage({
    required int page,
    int perPage = 10,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    pageRequests.add((
      page: page,
      perPage: perPage,
      status: status,
      startDate: startDate,
      endDate: endDate,
    ));
    if (pageCompleter != null) return pageCompleter!.future;
    if (pageError != null) throw pageError!;
    return pages[page] ??
        (reports: const <TicketStatus>[], currentPage: page, lastPage: page);
  }

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
  _OfflineTrackingApiService() {
    pageError = const ApiException('Tidak ada koneksi internet.');
  }
}

class _InspectionTrackingApiService extends _FakeTrackingApiService {
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

class _PageTrackingApiService extends _FakeTrackingApiService {
  _PageTrackingApiService() {
    pages[1] = (
      reports: [
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
      ],
      currentPage: 1,
      lastPage: 1,
    );
  }
}

class _UnavailableTrackingApiService extends ApiService {
  int syncCount = 0;

  @override
  Future<CitizenReportPage> getCitizenReportsPage({
    required int page,
    int perPage = 10,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    syncCount++;
    throw const ApiException('Tidak dapat terhubung ke server.');
  }
}

class _EmptyTrackingApiService extends _FakeTrackingApiService {}

TicketStatus _ticket(int index) => TicketStatus(
  code: 'TK-${index.toString().padLeft(2, '0')}',
  status: 'diproses',
  category: 'air_masalah',
  description: 'Laporan $index',
  village: 'Desa Sehat',
  rt: '02',
  rw: '04',
  createdAt: '2026-10-29',
);

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
    'history reports server errors and retries without using local placeholders',
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
      expect(find.text('TK-20261030-0001'), findsNothing);
      expect(
        find.textContaining('Gagal memuat data dari server'),
        findsOneWidget,
      );
      expect(find.text('Coba Lagi'), findsOneWidget);
      apiService.pageError = null;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();
      expect(apiService.pageRequests, hasLength(2));
      expect(find.text('Belum ada riwayat laporan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history renders server reports using the existing ticket model',
    (WidgetTester tester) async {
      final apiService = _PageTrackingApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackingView(apiService: apiService)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TK-CACHED-ONLY'), findsOneWidget);
      expect(find.text('Laporan dari cache.'), findsNothing);
      expect(apiService.pageRequests.single.perPage, 10);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scroll loads the next page without duplicate reports', (
    WidgetTester tester,
  ) async {
    final apiService = _FakeTrackingApiService()
      ..pages[1] = (
        reports: List.generate(10, (index) => _ticket(index)),
        currentPage: 1,
        lastPage: 2,
      )
      ..pages[2] = (
        reports: [
          TicketStatus(
            code: _ticket(0).code,
            status: 'diproses',
            category: 'air_masalah',
            description: 'DUPLICATE',
            village: 'Desa Sehat',
            rt: '02',
            rw: '04',
            createdAt: '2026-10-29',
          ),
          _ticket(10),
        ],
        currentPage: 2,
        lastPage: 2,
      );

    await tester.pumpWidget(
      MaterialApp(home: TrackingView(apiService: apiService)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(apiService.pageRequests.map((request) => request.page), [1, 2]);
    expect(find.text('TK-10'), findsOneWidget);
    expect(find.text('DUPLICATE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status and date filters combine and reset to the first page', (
    WidgetTester tester,
  ) async {
    final apiService = _FakeTrackingApiService()
      ..pages[1] = (reports: [_ticket(1)], currentPage: 1, lastPage: 1);

    await tester.pumpWidget(
      MaterialApp(home: TrackingView(apiService: apiService)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tracking_status_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diproses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tracking_date_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hari ini').last);
    await tester.pumpAndSettle();

    expect(apiService.pageRequests, hasLength(3));
    expect(apiService.pageRequests.last.page, 1);
    expect(apiService.pageRequests.last.perPage, 10);
    expect(apiService.pageRequests.last.status, 'diproses');
    expect(apiService.pageRequests.last.startDate, isNotNull);
    expect(
      apiService.pageRequests.last.startDate,
      apiService.pageRequests.last.endDate,
    );
    expect(find.text('Filter aktif'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tracking_reset_filters')));
    await tester.pumpAndSettle();
    expect(apiService.pageRequests, hasLength(4));
    expect(apiService.pageRequests.last.page, 1);
    expect(apiService.pageRequests.last.status, isNull);
    expect(apiService.pageRequests.last.startDate, isNull);
    expect(apiService.pageRequests.last.endDate, isNull);
    expect(find.text('Filter aktif'), findsNothing);
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
