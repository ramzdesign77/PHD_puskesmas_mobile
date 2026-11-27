import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/services/officer_api_service.dart';
import 'package:klinik_sanitasi_mobile/theme/app_theme.dart';
import 'package:klinik_sanitasi_mobile/views/officer/officer_dashboard_view.dart';

void main() {
  testWidgets('officer home shows the card dashboard without narrow overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final client = MockClient((request) async {
      final isDashboard = request.url.path.endsWith('/dashboard');
      return http.Response(
        jsonEncode(
          isDashboard
              ? {
                  'data': {
                    'summary': {'jadwal_ikl_hari_ini_count': 1},
                    'officer': {'nama': 'Rani'},
                  },
                }
              : {
                  'data': [
                    {
                      'id': 8,
                      'tipe': 'ikl',
                      'nama_pelapor': 'Ayu',
                      'kategori_laporan': 'Sumber Air',
                      'alamat': 'Jalan Melati',
                      'desa': 'Desa Biru',
                      'status_kunjungan': 'terjadwal',
                      'tanggal_kunjungan': DateTime.now()
                          .toIso8601String()
                          .substring(0, 10),
                      'jadwal': {'id_jadwal': 8},
                      'hasil_inspeksi': {'kategori_risiko': 'aman'},
                    },
                    {
                      'id': 9,
                      'tipe': 'aduan',
                      'nama_pelapor': 'Budi',
                      'kategori_laporan': 'Saluran Air',
                      'alamat': 'Jalan Kenanga',
                      'desa': 'Desa Biru',
                      'status_laporan': 'pending',
                    },
                    {
                      'id': 10,
                      'tipe': 'ikl',
                      'nama_pelapor': 'Citra',
                      'kode_tiket': 'IKL-10',
                      'kategori_laporan': 'Sumber Air',
                      'desa': 'Desa Hijau',
                      'rt': '02',
                      'rw': '04',
                      'status_kunjungan': 'selesai',
                      'tanggal_kunjungan': '2026-11-20',
                      'hasil_inspeksi': {
                        'tanggal_inspeksi': '2026-11-20',
                        'kategori_risiko': 'aman',
                        'intervensi_fisik': 'Pembagian Kaporit',
                      },
                    },
                  ],
                },
        ),
        200,
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OfficerDashboardView(
          token: 'test-token',
          officerName: 'Petugas Rani',
          apiService: OfficerApiService(client: client),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tugas IKL Mendatang'), findsOneWidget);
    expect(find.text('Mulai Kunjungan Terdekat'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('officer_home_list')),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Laporan Warga Terbaru'), findsOneWidget);
    expect(find.text('Laporan Warga Masuk'), findsOneWidget);

    await tester.tap(find.text('Jadwal'));
    await tester.pumpAndSettle();
    expect(find.text('Semua Aktif'), findsOneWidget);
    expect(find.text('Verifikasi & Jadwalkan'), findsOneWidget);
    expect(find.text('Buka Peta & Isi IKL'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat Pemeriksaan'), findsOneWidget);
    expect(find.text('Citra'), findsOneWidget);
    expect(find.text('Aman'), findsWidgets);
    expect(find.textContaining('Pembagian Kaporit'), findsOneWidget);
    expect(find.textContaining('2026-11-20'), findsOneWidget);
    expect(find.textContaining('RT 02/RW 04'), findsOneWidget);
    expect(find.text('#IKL-10'), findsOneWidget);
    expect(find.text('Lihat Hasil Pemeriksaan'), findsOneWidget);
    await tester.tap(find.text('Lihat Hasil Pemeriksaan'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('officer_inspection_history_detail')),
      findsOneWidget,
    );
    expect(find.text('Kuesioner Inspeksi Kesehatan Lingkungan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
