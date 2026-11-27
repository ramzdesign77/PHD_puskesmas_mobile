import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tracking requests report offline socket failures clearly', () async {
    final apiService = ApiService(
      client: MockClient((_) async {
        throw const SocketException('network unavailable');
      }),
    );

    await expectLater(
      apiService.getTicket('TK-TEST'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Periksa koneksi internet'),
        ),
      ),
    );
    await expectLater(
      apiService.syncCitizenTicketsHistory(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Periksa koneksi internet'),
        ),
      ),
    );
  });

  test('requests authenticated citizen report pages with combined filters', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'citizen-token'});
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/laporan/history');
      expect(request.url.queryParameters, {
        'page': '2',
        'per_page': '10',
        'status': 'diproses',
        'start_date': '2026-11-01',
        'end_date': '2026-11-07',
      });
      expect(request.headers['Authorization'], 'Bearer citizen-token');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'kode_tiket': 'IKL-20261101-0001',
              'status_laporan': 'diproses',
              'kategori_laporan': 'air_masalah',
              'deskripsi': 'Air keruh.',
            },
          ],
          'meta': {'current_page': 2, 'last_page': 4, 'per_page': 10},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiService = ApiService(client: client);

    final result = await apiService.getCitizenReportsPage(
      page: 2,
      perPage: 10,
      status: 'diproses',
      startDate: '2026-11-01',
      endDate: '2026-11-07',
    );

    expect(result.currentPage, 2);
    expect(result.lastPage, 4);
    expect(result.reports, hasLength(1));
    expect(result.reports.single.code, 'IKL-20261101-0001');
    expect(result.reports.single.status, 'diproses');
    client.close();
  });

  test('rejects citizen report pages without pagination data', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'citizen-token'});
    final apiService = ApiService(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'message': 'Invalid'}), 200),
      ),
    );

    await expectLater(
      apiService.getCitizenReportsPage(page: 1),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Format daftar laporan dari server tidak valid.',
        ),
      ),
    );
  });

  test('saved ticket and cached status lists are pruned to fifteen', () async {
    final savedCodes = List.generate(20, (index) => 'TK-$index');
    final statuses = [
      for (final code in savedCodes) {'kode_tiket': code},
    ];
    SharedPreferences.setMockInitialValues({
      'saved_citizen_tickets': savedCodes,
      'cached_citizen_ticket_statuses': jsonEncode(statuses),
    });
    final apiService = ApiService();

    final restoredCodes = await apiService.getSavedCitizenTicketCodes();
    final restoredStatuses = await apiService.getCachedCitizenTicketStatuses();
    final preferences = await SharedPreferences.getInstance();

    expect(restoredCodes, hasLength(ApiService.maxSavedTickets));
    expect(restoredCodes.first, 'TK-0');
    expect(
      preferences.getStringList('saved_citizen_tickets'),
      hasLength(ApiService.maxSavedTickets),
    );
    expect(restoredStatuses, hasLength(ApiService.maxSavedTickets));
    expect(
      (jsonDecode(preferences.getString('cached_citizen_ticket_statuses')!)
          as List),
      hasLength(ApiService.maxSavedTickets),
    );
  });

  test(
    'history sync requests fifteen rows and at most ten local codes',
    () async {
      final savedCodes = List.generate(20, (index) => 'TK-$index');
      final client = MockClient((request) async {
        expect(request.url.queryParameters['limit'], '15');
        expect(
          request.url.queryParameters['codes']!.split(','),
          savedCodes.take(10).toList(),
        );
        return http.Response(jsonEncode({'data': []}), 200);
      });
      SharedPreferences.setMockInitialValues({
        'saved_citizen_tickets': savedCodes,
      });
      final apiService = ApiService(client: client);

      final merged = await apiService.syncCitizenTicketsHistory();

      expect(merged, hasLength(ApiService.maxSavedTickets));
      client.close();
    },
  );

  test('registers with the phone field expected by the API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/register');
      expect(jsonDecode(request.body), {
        'nama_lengkap': 'Warga Contoh',
        'username': 'warga-contoh',
        'email': 'warga@example.test',
        'password': 'secret123',
        'password_confirmation': 'secret123',
        'no_telepon': '081234567890',
        'no_hp': '081234567890',
      });

      return http.Response(
        jsonEncode({
          'message': 'Registrasi berhasil.',
          'token': 'mobile-token',
          'user': {
            'nama_lengkap': 'Warga Contoh',
            'username': 'warga-contoh',
            'email': 'warga@example.test',
            'no_telepon': '081234567890',
            'role': 'warga',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final apiService = ApiService(client: client);

    await apiService.register(
      namaLengkap: 'Warga Contoh',
      username: 'warga-contoh',
      email: 'warga@example.test',
      password: 'secret123',
      phone: '081234567890',
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('auth_user_phone'), '081234567890');
    expect(preferences.getString('auth_user_email'), 'warga@example.test');
    client.close();
  });

  group('ApiService.submitReport', () {
    // Tes baru: memastikan kontrak POST /api/laporan dan kode tiket.
    test('posts multipart report data and returns the ticket code', () async {
      final client = MockClient((request) async {
        expect(request, isA<http.Request>());
        expect(request.method, 'POST');
        expect(request.url.path, '/api/laporan');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="nama_pelapor"'));
        expect(request.body, contains('Warga Contoh'));
        expect(request.body, isNot(contains('nik_pelapor')));
        expect(request.body, isNot(contains('name="nik"')));
        expect(request.body, contains('name="id_desa"'));
        expect(request.body, contains('\r\n12\r\n'));
        expect(request.body, contains('Air keruh'));
        expect(request.headers['Accept'], 'application/json');

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Laporan berhasil dikirim.',
            'kode_tiket': 'IKL-20261028-0001',
            'id_laporan': 1,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final apiService = ApiService(client: client);

      final ticketCode = await apiService.submitReport({
        'nama_pelapor': 'Warga Contoh',
        'nik_pelapor': '1234567890123456',
        'nik': '1234567890123456',
        'id_desa': 12,
        'deskripsi': 'Air keruh',
      });

      expect(ticketCode, 'IKL-20261028-0001');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('saved_citizen_tickets'), [
        'IKL-20261028-0001',
      ]);
      final cachedTicket = await apiService.getCachedTicketStatus(
        'IKL-20261028-0001',
      );
      expect(cachedTicket?.status, 'dikirim');
      expect(cachedTicket?.description, 'Air keruh');
      client.close();
    });

    test('uploads image bytes as a multipart file', () async {
      final client = MockClient((request) async {
        expect(request, isA<http.Request>());
        expect(request.body, contains('name="foto_bukti"; filename='));
        expect(request.body, contains('\r\nIMG\r\n'));

        return http.Response(
          jsonEncode({'kode_tiket': 'IKL-20261028-0002'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final apiService = ApiService(client: client);

      final ticketCode = await apiService.submitReport(
        {'deskripsi': 'Air keruh'},
        imageFile: XFile.fromData(
          Uint8List.fromList([0x49, 0x4D, 0x47]),
          name: 'bukti.png',
          mimeType: 'image/png',
        ),
      );

      expect(ticketCode, 'IKL-20261028-0002');
      client.close();
    });

    test('stores submitted codes newest-first without duplicates', () async {
      final apiService = ApiService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({'kode_tiket': 'IKL-20261028-0002'}),
            201,
          );
        }),
      );

      await apiService.saveCitizenTicketCode('IKL-20261028-0001');
      await apiService.submitReport({'deskripsi': 'Laporan terbaru'});
      await apiService.saveCitizenTicketCode('IKL-20261028-0001');

      expect(await apiService.getSavedCitizenTicketCodes(), [
        'IKL-20261028-0001',
        'IKL-20261028-0002',
      ]);
    });

    test('surfaces validation errors from the laporan endpoint', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Data laporan tidak valid.',
            'errors': {
              'deskripsi': ['Deskripsi wajib diisi.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );
      final apiService = ApiService(client: client);

      await expectLater(
        apiService.submitReport({'deskripsi': ''}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having(
                (error) => error.message,
                'message',
                'Deskripsi wajib diisi.',
              ),
        ),
      );
      client.close();
    });
  });

  group('TicketStatus progress mapping', () {
    test('maps report statuses to the five tracking steps', () {
      final expectedSteps = {
        'dikirim': 0,
        'menunggu': 1,
        'diproses': 1,
        'dijadwalkan': 2,
        'ditindaklanjuti': 3,
        'selesai': 4,
      };

      for (final entry in expectedSteps.entries) {
        final ticket = TicketStatus.fromJson({'status_laporan': entry.key});
        expect(ticket.currentStepIndex, entry.value, reason: entry.key);
      }

      final rejected = TicketStatus.fromJson({
        'status_laporan': 'ditolak',
        'alasan_penolakan': 'Data lokasi tidak lengkap.',
      });
      expect(rejected.isRejected, isTrue);
      expect(rejected.currentStepIndex, isNull);
      expect(rejected.rejectionReason, 'Data lokasi tidak lengkap.');
    });

    test('reads schedule and sanitarian outcome details', () {
      final ticket = TicketStatus.fromJson({
        'status_laporan': 'selesai',
        'nama_pelapor': 'Warga Contoh',
        'jadwal': {
          'tanggal_kunjungan': '2026-10-29 09:00',
          'petugas': 'Petugas Contoh',
          'intervensi_fisik': 'Pemeriksaan sumur',
        },
        'hasil_ikl': {
          'risiko_air': 'Risiko sedang',
          'rekomendasi_sanitarian': 'Tutup sumur setelah digunakan.',
        },
      });

      expect(ticket.reporterName, 'Warga Contoh');
      expect(ticket.visitDate, '2026-10-29 09:00');
      expect(ticket.officer, 'Petugas Contoh');
      expect(ticket.intervention, 'Pemeriksaan sumur');
      expect(ticket.riskCategory, 'Risiko sedang');
      expect(ticket.recommendation, 'Tutup sumur setelah digunakan.');
    });

    test('serializes status for local ticket cache', () {
      final ticket = TicketStatus.fromJson({
        'kode_tiket': 'TK-20261030-0001',
        'status_laporan': 'selesai',
        'kategori_laporan': 'air_masalah',
        'deskripsi': 'Air keruh',
        'nama_pelapor': 'Warga Contoh',
        'desa': 'Desa Sehat',
        'rt': '02',
        'rw': '04',
        'created_at': '2026-10-29',
        'tanggal_kunjungan': '2026-10-30',
        'petugas': 'Sanitarian',
        'kategori_risiko_air': 'Risiko sedang',
        'rekomendasi_sanitarian': 'Rebus air sebelum diminum.',
      });

      final restored = TicketStatus.fromJson(ticket.toJson());
      expect(restored.code, ticket.code);
      expect(restored.status, ticket.status);
      expect(restored.reporterName, ticket.reporterName);
      expect(restored.visitDate, ticket.visitDate);
      expect(restored.riskCategory, ticket.riskCategory);
      expect(restored.recommendation, ticket.recommendation);
      expect(restored.isCompleted, isTrue);
    });

    test('ignores malformed fields and nested payloads', () {
      final ticket = TicketStatus.fromJson({
        'kode_tiket': 42,
        'status_laporan': {'unexpected': 'object'},
        'kategori_laporan': [],
        'deskripsi': null,
        'rt': 7,
        'jadwal': 'unexpected',
        'hasil_ikl': ['unexpected'],
        'total_skor_ya': {'unexpected': 3},
      });

      expect(ticket.code, '42');
      expect(ticket.status, '');
      expect(ticket.category, '');
      expect(ticket.description, '');
      expect(ticket.rt, '7');
      expect(ticket.visitDate, isNull);
      expect(ticket.riskCategory, isNull);
      expect(ticket.riskScore, isNull);
    });
  });

  test('skips corrupt cached ticket entries and saved-code values', () async {
    SharedPreferences.setMockInitialValues({
      'saved_citizen_tickets': 'legacy-invalid-value',
      'cached_citizen_ticket_statuses': jsonEncode([
        null,
        {
          'status_laporan': ['invalid'],
        },
        {'kode_tiket': 'TK-VALID', 'status_laporan': 'dikirim'},
      ]),
    });
    final apiService = ApiService();

    expect(await apiService.getSavedCitizenTicketCodes(), isEmpty);
    final cachedStatuses = await apiService.getCachedCitizenTicketStatuses();
    expect(cachedStatuses, hasLength(1));
    expect(cachedStatuses.single.code, 'TK-VALID');
  });
}
