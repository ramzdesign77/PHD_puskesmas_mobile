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
          expect(body['jadwal_id'], 8);
          expect(body['jenis_sarana_air'], 'Sumur Gali');
          expect(body['jarak_sumber_pencemar'], 12.5);
          expect(body['p1'], isTrue);
          expect(body['p5'], isFalse);
          expect(body['intervensi_fisik'], 'Pemberian Kaporit');
          return http.Response('', 204);
        });

        await OfficerApiService(client: client).submitInspection(
          token: 'token',
          scheduleId: 8,
          waterSource: 'Sumur Gali',
          pollutantDistance: 12.5,
          riskIndicators: const [true, false, false, false, false],
          intervention: 'Pemberian Kaporit',
          interventionNote: 'Sesuai dosis',
          recommendation: 'Periksa kembali',
          visitStatus: 'diproses',
          officerNote: 'Temuan lapangan',
        );
        client.close();
      },
    );
  });
}
