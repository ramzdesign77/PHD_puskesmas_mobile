import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/services/officer_api_service.dart';

void main() {
  group('OfficerApiService', () {
    test('loads the v1 officer dashboard with bearer authentication', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/officer/dashboard');
        expect(request.headers['Authorization'], 'Bearer secure-token');
        return http.Response(
          jsonEncode({
            'data': {
              'summary': {
                'aduan_baru_count': 3,
                'jadwal_ikl_hari_ini_count': 2,
              },
              'officer': {
                'nama': 'Petugas Contoh',
                'nip': '123',
                'wilayah_kerja': 'Sumbersari',
              },
              'tasks': [
                {
                  'id': 42,
                  'nama_pelapor': 'Budi Santoso',
                  'kategori_laporan': 'Sanitasi Air',
                  'status_laporan': 'pending',
                  'tipe': 'aduan',
                },
              ],
            },
          }),
          200,
        );
      });

      final dashboard = await OfficerApiService(client: client)
          .getDashboard('secure-token');

      expect(dashboard.summary.newReportsCount, 3);
      expect(dashboard.summary.todayInspectionsCount, 2);
      expect(dashboard.profile.name, 'Petugas Contoh');
      expect(dashboard.schedules.single.id, 42);
      client.close();
    });

    test(
      'falls back to the legacy schedule endpoint when tasks is missing',
      () async {
        final requests = <String>[];
        final client = MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '/api/v1/officer/tasks') {
            return http.Response(jsonEncode({'message': 'Not found'}), 404);
          }
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 7, 'nama_pelapor': 'Siti', 'status_laporan': 'pending'},
              ],
            }),
            200,
          );
        });

        final tasks = await OfficerApiService(client: client).getTasks('token');

        expect(requests, ['/api/v1/officer/tasks', '/api/petugas/jadwal']);
        expect(tasks.single.reporterName, 'Siti');
        client.close();
      },
    );

    test(
      'submits the five IKL risk indicators to the inspections endpoint',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/officer/inspections');
          expect(request.headers['Authorization'], 'Bearer token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['id_jadwal'], 8);
          expect(body.containsKey('jadwal_id'), isFalse);
          expect(body['jenis_sarana_air'], 'sumur_terlindung');
          expect(body['jarak_sumber_pencemar'], 12);
          expect(body['tanggal_inspeksi'], '2026-11-02');
          expect(body['p1_dinding_sumur_retak'], isTrue);
          expect(body.containsKey('total_skor_ya'), isFalse);
          expect(body['p5_air_keruh_berbau'], isFalse);
          expect(body['intervensi_fisik'], 'Pemberian Kaporit');
          return http.Response(jsonEncode({'data': {
            'id_inspeksi': 10,
            'status_kunjungan': 'selesai',
            'total_skor_ya': 1,
            'kategori_risiko': 'risiko_sedang',
          }}), 201);
        });

        await OfficerApiService(client: client).submitInspection(
          token: 'token',
          scheduleId: 8,
          waterSource: 'sumur_terlindung',
          pollutantDistance: 12,
          inspectionDate: '2026-11-02',
          riskIndicators: const [true, false, false, false, false],
          intervention: 'Pemberian Kaporit',
          interventionNote: 'Sesuai dosis',
          recommendation: 'Periksa kembali',
          officerNote: 'Temuan lapangan',
        );
        client.close();
      },
    );

    test('does not fall back to saving a visit note when inspection fails', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response(jsonEncode({'message': 'Jadwal tidak ditemukan.'}), 404);
      });
      await expectLater(
        OfficerApiService(client: client).submitInspection(
          token: 'token', scheduleId: 8, waterSource: 'pdam',
          pollutantDistance: 12, inspectionDate: '2026-11-02',
          riskIndicators: const [false, false, false, false, false],
          intervention: 'Tidak Ada', interventionNote: '',
          recommendation: 'Jaga kebersihan.', officerNote: '',
        ),
        throwsA(isA<ApiOfficerException>()),
      );
      expect(requests, 1);
      client.close();
    });
  });
}
