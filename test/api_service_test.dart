import 'dart:convert';
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
  });
}
