import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TrackingFilterSettings {
  const TrackingFilterSettings({
    this.status,
    this.dateFilter = 'all',
    this.startDate,
    this.endDate,
  });

  final String? status;
  final String dateFilter;
  final String? startDate;
  final String? endDate;
}

class TrackingFilterPreferences {
  TrackingFilterPreferences({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static const accountIdKey = 'auth_account_id';
  static const _filterKeyPrefix = 'tracking_filter_';
  static const _validStatuses = {
    'dikirim',
    'menunggu',
    'diproses',
    'dijadwalkan',
    'ditindaklanjuti',
    'selesai',
    'ditolak',
  };
  static const _validDateFilters = {
    'all',
    'today',
    'last7Days',
    'last30Days',
    'custom',
  };

  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<String?> loadAccountId() async {
    final preferences = await _preferencesProvider();
    return preferences.getString(accountIdKey);
  }

  Future<TrackingFilterSettings?> load(String accountId) async {
    final preferences = await _preferencesProvider();
    final stored = preferences.getString(_keyFor(accountId));
    if (stored == null) return null;

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) {
        await preferences.remove(_keyFor(accountId));
        return null;
      }
      final dateFilter = decoded['date_filter'];
      final status = decoded['status'];
      final startDate = decoded['start_date'];
      final endDate = decoded['end_date'];
      final parsedStart = startDate is String
          ? DateTime.tryParse(startDate)
          : null;
      final parsedEnd = endDate is String ? DateTime.tryParse(endDate) : null;
      final validCustomRange =
          parsedStart != null &&
          parsedEnd != null &&
          !parsedStart.isAfter(parsedEnd);
      final resolvedDateFilter =
          dateFilter is String && _validDateFilters.contains(dateFilter)
          ? dateFilter
          : 'all';
      return TrackingFilterSettings(
        status: status is String && _validStatuses.contains(status)
            ? status
            : null,
        dateFilter: resolvedDateFilter == 'custom' && !validCustomRange
            ? 'all'
            : resolvedDateFilter,
        startDate: validCustomRange ? startDate as String : null,
        endDate: validCustomRange ? endDate as String : null,
      );
    } on FormatException {
      await preferences.remove(_keyFor(accountId));
      return null;
    }
  }

  Future<void> save(
    String accountId, {
    required String? status,
    required String dateFilter,
    String? startDate,
    String? endDate,
  }) async {
    if (status != null && !_validStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Status filter tidak valid.');
    }
    if (!_validDateFilters.contains(dateFilter)) {
      throw ArgumentError.value(
        dateFilter,
        'dateFilter',
        'Rentang tanggal tidak valid.',
      );
    }
    if (dateFilter == 'custom') {
      final parsedStart = DateTime.tryParse(startDate ?? '');
      final parsedEnd = DateTime.tryParse(endDate ?? '');
      if (parsedStart == null ||
          parsedEnd == null ||
          parsedStart.isAfter(parsedEnd)) {
        throw ArgumentError('Rentang tanggal khusus tidak valid.');
      }
    }
    final preferences = await _preferencesProvider();
    final settings = {
      'status': status,
      'date_filter': dateFilter,
      'start_date': dateFilter == 'custom' ? startDate : null,
      'end_date': dateFilter == 'custom' ? endDate : null,
    };
    if (!await preferences.setString(
      _keyFor(accountId),
      jsonEncode(settings),
    )) {
      throw StateError('Filter Lacak tidak dapat disimpan.');
    }
  }

  Future<void> clear(String accountId) async {
    final preferences = await _preferencesProvider();
    await preferences.remove(_keyFor(accountId));
  }

  String _keyFor(String accountId) =>
      '$_filterKeyPrefix${Uri.encodeComponent(accountId)}';
}
