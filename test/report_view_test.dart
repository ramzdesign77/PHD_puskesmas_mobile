import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:klinik_sanitasi_mobile/models/saved_address.dart';
import 'package:klinik_sanitasi_mobile/models/village.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';
import 'package:klinik_sanitasi_mobile/services/profile_service.dart';
import 'package:klinik_sanitasi_mobile/views/public/report_view.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: -8.198997,
    longitude: 113.643575,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeReportApiService extends ApiService {
  @override
  Future<List<Village>> getVillages() async {
    return [
      const Village(id: 1, name: 'Desa Sumbersari'),
      const Village(id: 2, name: 'Desa Sukamaju'),
    ];
  }
}

class _AuthenticatedReportApiService extends _FakeReportApiService {
  @override
  Future<AuthSession?> loadSavedSession() async =>
      const AuthSession(token: 'test-token', role: 'warga', userName: 'Warga');
}

class _SavedAddressProfileService extends ProfileService {
  _SavedAddressProfileService(this.address);

  final SavedAddress? address;
  int saveCalls = 0;

  @override
  Future<SavedAddress?> loadSavedAddress() async => address;

  @override
  Future<SavedAddress> saveAddress(
    SavedAddress value, {
    required LocalProfile profile,
  }) async {
    saveCalls++;
    return value;
  }
}

void main() {
  testWidgets(
    'ReportView renders header, form groups, and submit button precisely',
    (WidgetTester tester) async {
      final fakeApi = _FakeReportApiService();

      await tester.pumpWidget(
        MaterialApp(home: ReportView(apiService: fakeApi)),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Buat Laporan'), findsOneWidget);
      expect(
        find.text('Sampaikan masalah air atau sanitasi\ndi lingkungan Anda.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Verify Section 1: Data Pelapor
      expect(find.text('Data Pelapor'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('NIK'), findsNothing);
      expect(find.text('Nomor WhatsApp Aktif'), findsOneWidget);

      // Verify Section 2: Lokasi Kejadian
      expect(find.text('Lokasi Kejadian'), findsOneWidget);
      expect(find.text('Desa / Kelurahan'), findsOneWidget);
      expect(find.text('Pilih desa'), findsOneWidget);
      expect(find.text('RT'), findsOneWidget);
      expect(find.text('RW'), findsOneWidget);
      expect(find.text('Gunakan Lokasi Saat Ini'), findsOneWidget);
      expect(find.text('Riwayat Laporan Terakhir Anda'), findsNothing);
      expect(find.byKey(const Key('report_location_map')), findsNothing);

      // Verify Section 3: Detail Laporan
      expect(find.text('Detail Laporan'), findsOneWidget);
      expect(find.text('Kategori Laporan'), findsOneWidget);
      expect(find.text('Air Sumur Keruh / Berbau'), findsOneWidget);
      expect(find.text('Sarang Nyamuk / Indikasi DBD'), findsOneWidget);
      expect(find.text('Deskripsi masalah'), findsOneWidget);
      expect(find.text('0/2000'), findsOneWidget);

      // Verify Character Counter updates
      await tester.enterText(
        find.byType(TextFormField).last,
        'Air keruh dan berbau.',
      );
      await tester.pumpAndSettle();
      expect(find.text('21/2000'), findsOneWidget);

      // Verify Submit Button
      expect(find.text('KIRIM LAPORAN PENGADUAN'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    },
  );

  testWidgets('saved account address is selected and can be overridden', (
    tester,
  ) async {
    final profileService = _SavedAddressProfileService(
      const SavedAddress(
        villageId: 2,
        villageName: 'Desa Sukamaju',
        rt: '03',
        rw: '02',
        detail: 'Dekat balai desa',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ReportView(
          apiService: _AuthenticatedReportApiService(),
          profileService: profileService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final accountAddressOption = find.byKey(
      const Key('report_use_account_address'),
    );
    await tester.ensureVisible(accountAddressOption);
    expect(find.text('Gunakan alamat akun'), findsOneWidget);
    expect(find.text('Gunakan lokasi lain'), findsOneWidget);
    expect(
      find.byKey(const Key('report_account_address_summary')),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<Village>), findsNothing);
    expect(find.text('Gunakan Lokasi Saat Ini'), findsNothing);
    expect(find.byKey(const Key('report_address_detail_true')), findsNothing);
    expect(find.textContaining('RT 03 / RW 02'), findsOneWidget);

    final otherAddressOption = find.byKey(
      const Key('report_use_other_address'),
    );
    await tester.ensureVisible(otherAddressOption);
    await tester.tap(otherAddressOption);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('report_address_detail_false')),
          )
          .enabled,
      isTrue,
    );
    expect(find.byType(DropdownButtonFormField<Village>), findsOneWidget);
    expect(find.text('Gunakan Lokasi Saat Ini'), findsOneWidget);
    expect(profileService.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a picked GPS point can be canceled and selected again', (
    tester,
  ) async {
    final previousPlatform = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
    addTearDown(() => GeolocatorPlatform.instance = previousPlatform);

    await tester.pumpWidget(
      MaterialApp(home: ReportView(apiService: _FakeReportApiService())),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gunakan Lokasi Saat Ini'));
    await tester.tap(find.text('Gunakan Lokasi Saat Ini'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report_location_map')), findsOneWidget);

    final cancelButton = find.byKey(
      const Key('report_cancel_location_selection'),
    );
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report_location_map')), findsNothing);
    expect(find.text('Gunakan Lokasi Saat Ini'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in user without an address can still enter a location', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportView(
          apiService: _AuthenticatedReportApiService(),
          profileService: _SavedAddressProfileService(null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report_address_not_saved')), findsOneWidget);
    expect(find.textContaining('Profil → Alamat'), findsOneWidget);
    expect(find.text('Pilih desa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
