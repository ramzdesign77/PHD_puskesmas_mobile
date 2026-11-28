import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/services/tracking_filter_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists filter settings separately for each account', () async {
    final preferences = TrackingFilterPreferences();
    await preferences.save(
      'citizen-1',
      status: 'diproses',
      dateFilter: 'custom',
      startDate: '2026-11-01',
      endDate: '2026-11-07',
    );
    await preferences.save('citizen-2', status: 'ditolak', dateFilter: 'today');

    final firstAccount = await preferences.load('citizen-1');
    final secondAccount = await preferences.load('citizen-2');

    expect(firstAccount?.status, 'diproses');
    expect(firstAccount?.dateFilter, 'custom');
    expect(firstAccount?.startDate, '2026-11-01');
    expect(firstAccount?.endDate, '2026-11-07');
    expect(secondAccount?.status, 'ditolak');
    expect(secondAccount?.dateFilter, 'today');
  });

  test('rejects invalid custom date ranges', () async {
    final preferences = TrackingFilterPreferences();

    await expectLater(
      preferences.save(
        'citizen-1',
        status: null,
        dateFilter: 'custom',
        startDate: '2026-11-08',
        endDate: '2026-11-01',
      ),
      throwsArgumentError,
    );
  });
}
