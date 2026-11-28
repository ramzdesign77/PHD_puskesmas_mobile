import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/services/auth_service.dart';
import 'package:klinik_sanitasi_mobile/services/citizen_report_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/memory_auth_token_store.dart';

void main() {
  late Directory directory;
  late CitizenReportCache cache;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('citizen-report-cache-');
    cache = _createCache(directory.path);
  });

  tearDown(() async {
    await cache.close();
    await directory.delete(recursive: true);
  });

  test(
    'stores filtered pages per account and survives reopening the database',
    () async {
      await cache.savePage(
        accountId: 'citizen-1',
        page: 1,
        perPage: 10,
        currentPage: 1,
        lastPage: 2,
        status: 'diproses',
        startDate: '2026-11-01',
        endDate: '2026-11-07',
        reports: [_report('TK-1')],
      );

      final otherAccount = await cache.readPage(
        accountId: 'citizen-2',
        page: 1,
        perPage: 10,
        status: 'diproses',
        startDate: '2026-11-01',
        endDate: '2026-11-07',
      );
      final otherFilter = await cache.readPage(
        accountId: 'citizen-1',
        page: 1,
        perPage: 10,
        status: 'ditolak',
        startDate: '2026-11-01',
        endDate: '2026-11-07',
      );

      expect(otherAccount, isNull);
      expect(otherFilter, isNull);
      await cache.close();
      cache = _createCache(directory.path);

      final restored = await cache.readPage(
        accountId: 'citizen-1',
        page: 1,
        perPage: 10,
        status: 'diproses',
        startDate: '2026-11-01',
        endDate: '2026-11-07',
      );
      expect(restored?.reports.single.code, 'TK-1');
      expect(restored?.lastPage, 2);
      expect(restored?.syncedAt, isNotNull);
    },
  );

  test('replaces page contents without duplicate reports', () async {
    await cache.savePage(
      accountId: 'citizen-1',
      page: 1,
      perPage: 10,
      currentPage: 1,
      lastPage: 2,
      reports: [_report('TK-1')],
    );
    await cache.savePage(
      accountId: 'citizen-1',
      page: 1,
      perPage: 10,
      currentPage: 1,
      lastPage: 1,
      reports: [
        _report('TK-2'),
        _report('TK-2', status: 'selesai'),
      ],
    );

    final page = await cache.readPage(
      accountId: 'citizen-1',
      page: 1,
      perPage: 10,
    );
    expect(page?.lastPage, 1);
    expect(page?.reports, hasLength(1));
    expect(page?.reports.single.code, 'TK-2');
    expect(page?.reports.single.status, 'dikirim');
  });

  test(
    'stores opened details and access history, then clears one account',
    () async {
      await cache.saveDetail(accountId: 'citizen-1', report: _report('TK-1'));
      await cache.saveDetail(accountId: 'citizen-2', report: _report('TK-2'));

      final detail = await cache.readDetail(
        accountId: 'citizen-1',
        code: 'TK-1',
      );
      final history = await cache.readRecentAccesses(accountId: 'citizen-1');
      expect(detail?.report.code, 'TK-1');
      expect(detail?.syncedAt, isNotNull);
      expect(history.map((entry) => entry.code), ['TK-1']);

      await cache.clearAccount('citizen-1');

      expect(
        await cache.readDetail(accountId: 'citizen-1', code: 'TK-1'),
        isNull,
      );
      expect(await cache.readRecentAccesses(accountId: 'citizen-1'), isEmpty);
      expect(
        (await cache.readDetail(
          accountId: 'citizen-2',
          code: 'TK-2',
        ))?.report.code,
        'TK-2',
      );
    },
  );

  test('expires cached pages and details after thirty days', () async {
    var now = DateTime(2026, 11, 28);
    await cache.close();
    cache = _createCache(directory.path, clock: () => now);
    await cache.savePage(
      accountId: 'citizen-1',
      page: 1,
      perPage: 10,
      currentPage: 1,
      lastPage: 1,
      reports: [_report('TK-1')],
    );
    await cache.saveDetail(accountId: 'citizen-1', report: _report('TK-1'));
    now = now.add(const Duration(days: 31));

    expect(
      await cache.readPage(accountId: 'citizen-1', page: 1, perPage: 10),
      isNull,
    );
    expect(
      await cache.readDetail(accountId: 'citizen-1', code: 'TK-1'),
      isNull,
    );
  });

  test('API refreshes report pages and opened details into SQLite', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('auth_account_id', 'citizen-1');
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/v1/laporan/history')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'kode_tiket': 'TK-API',
                'status_laporan': 'diproses',
                'kategori_laporan': 'air_masalah',
                'deskripsi': 'Laporan terbaru.',
                'desa': 'Desa Sehat',
                'rt': '02',
                'rw': '04',
                'created_at': '2026-11-28',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': {
            'kode_tiket': 'TK-API',
            'status_laporan': 'selesai',
            'kategori_laporan': 'air_masalah',
            'deskripsi': 'Detail terbaru.',
            'desa': 'Desa Sehat',
            'rt': '02',
            'rw': '04',
            'created_at': '2026-11-28',
          },
        }),
        200,
      );
    });
    final apiService = ApiService(
      client: client,
      tokenStore: MemoryAuthTokenStore()..token = 'session-token',
      reportCache: cache,
    );

    await apiService.getCitizenReportsPage(
      page: 1,
      perPage: 10,
      status: 'diproses',
      startDate: '2026-11-22',
      endDate: '2026-11-28',
    );
    await apiService.getTicket('TK-API');

    final cachedPage = await cache.readPage(
      accountId: 'citizen-1',
      page: 1,
      perPage: 10,
      status: 'diproses',
      startDate: '2026-11-22',
      endDate: '2026-11-28',
    );
    final cachedDetail = await cache.readDetail(
      accountId: 'citizen-1',
      code: 'TK-API',
    );
    expect(cachedPage?.reports.single.description, 'Laporan terbaru.');
    expect(cachedDetail?.report.description, 'Detail terbaru.');
    expect(cachedDetail?.report.status, 'selesai');
    client.close();
  });

  test(
    'cached records are unavailable without an authenticated session token',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_account_id', 'citizen-1');
      await cache.savePage(
        accountId: 'citizen-1',
        page: 1,
        perPage: 10,
        currentPage: 1,
        lastPage: 1,
        reports: [_report('TK-PRIVATE')],
      );
      final apiService = ApiService(
        tokenStore: MemoryAuthTokenStore(),
        reportCache: cache,
      );

      expect(
        await apiService.getCachedCitizenReportsPage(
          accountId: 'citizen-1',
          page: 1,
        ),
        isNull,
      );
    },
  );

  test(
    'account changes and logout purge that account local report data',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_account_id', 'citizen-1');
      await cache.savePage(
        accountId: 'citizen-1',
        page: 1,
        perPage: 10,
        currentPage: 1,
        lastPage: 1,
        reports: [_report('TK-1')],
      );
      final authService = AuthService(
        tokenStore: MemoryAuthTokenStore(),
        reportCache: cache,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'token': 'new-token',
                'user': {
                  'id': 2,
                  'roles': ['warga'],
                },
              },
            }),
            200,
          ),
        ),
      );

      await authService.login(identifier: 'warga-baru', password: 'secret');
      expect(
        await cache.readPage(accountId: 'citizen-1', page: 1, perPage: 10),
        isNull,
      );
      expect(preferences.getString('auth_account_id'), '2');

      await cache.saveDetail(accountId: '2', report: _report('TK-2'));
      await authService.logout();
      expect(await cache.readRecentAccesses(accountId: '2'), isEmpty);
      expect(preferences.getString('auth_account_id'), isNull);
    },
  );
}

CitizenReportCache _createCache(
  String directory, {
  DateTime Function()? clock,
}) => CitizenReportCache(
  databaseFactoryOverride: databaseFactoryFfi,
  databasePath: '$directory${Platform.pathSeparator}reports.db',
  clock: clock,
);

TicketStatus _report(String code, {String status = 'dikirim'}) => TicketStatus(
  code: code,
  status: status,
  category: 'air_masalah',
  description: 'Air keruh.',
  village: 'Desa Sehat',
  rt: '02',
  rw: '04',
  createdAt: '2026-11-28',
);
