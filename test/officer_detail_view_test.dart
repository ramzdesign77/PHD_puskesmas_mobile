import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:klinik_sanitasi_mobile/models/visit_schedule.dart';
import 'package:klinik_sanitasi_mobile/services/officer_api_service.dart';
import 'package:klinik_sanitasi_mobile/views/officer/officer_detail_view.dart';

void main() {
  testWidgets('IKL questionnaire opens only after arrival confirmation', (
    tester,
  ) async {
    final client = MockClient((_) async => http.Response('{}', 200));
    addTearDown(client.close);
    final schedule = VisitSchedule.fromJson({
      'id': 42,
      'kode_tiket': 'IKL-42',
      'tipe': 'ikl',
      'nama_pelapor': 'Warga Sumbersari',
      'no_wa': '081234567890',
      'desa': 'Desa Sumbersari',
      'rt': '03',
      'rw': '02',
      'alamat_detail': 'Dekat balai desa',
      'deskripsi': 'Air sumur keruh.',
      'kategori_laporan': 'air_masalah',
      'status_kunjungan': 'terjadwal',
      'tanggal_kunjungan': '2026-11-14',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OfficerDetailView(
          schedule: schedule,
          token: 'test-token',
          apiService: OfficerApiService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Warga Sumbersari • WA 081234567890'), findsOneWidget);
    expect(find.text('Kuesioner Inspeksi Kesehatan Lingkungan'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('officer_arrived_button')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('officer_arrived_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Kuesioner Inspeksi Kesehatan Lingkungan'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Kuesioner Inspeksi Kesehatan Lingkungan'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('officer_arrived_button')), findsNothing);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('officer_toggle_location_preview')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('officer_toggle_location_preview')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('officer_google_maps_button')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('officer_google_maps_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed schedule opens with the arrival badge and IKL form', (
    tester,
  ) async {
    final client = MockClient((_) async => http.Response('{}', 200));
    addTearDown(client.close);
    const schedule = VisitSchedule(
      id: 8,
      reporterName: 'Warga Contoh',
      address: '',
      village: 'Sumbersari',
      visitDate: '2026-11-13',
      status: 'selesai',
      category: 'Masalah Air Bersih',
      description: 'Air keruh.',
      rt: '01',
      rw: '02',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OfficerDetailView(
          schedule: schedule,
          token: 'test-token',
          apiService: OfficerApiService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Petugas Telah Tiba di Lokasi — Silakan Isi Formulir Pemeriksaan',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('officer_arrived_button')), findsNothing);
    expect(
      find.text('Kuesioner Inspeksi Kesehatan Lingkungan'),
      findsOneWidget,
    );
  });
}
