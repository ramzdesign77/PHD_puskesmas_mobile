import 'visit_schedule.dart';

class OfficerDashboardData {
  const OfficerDashboardData({
    this.summary = const OfficerSummary(),
    this.schedules = const [],
    this.profile = const OfficerProfile(),
  });

  final OfficerSummary summary;
  final List<VisitSchedule> schedules;
  final OfficerProfile profile;

  factory OfficerDashboardData.fromJson(Map<String, dynamic> json) {
    final payload = _map(json['data']) ?? json;
    final summaryJson = _map(payload['summary']) ?? payload;
    final profileJson =
        _map(payload['officer']) ??
        _map(payload['petugas']) ??
        _map(payload['user']) ??
        const <String, dynamic>{};
    final rawSchedules =
        payload['tasks'] ??
        payload['jadwal'] ??
        payload['schedules'] ??
        payload['reports'] ??
        payload['laporan'] ??
        payload['items'];
    final combinedRows = <Object?>[
      rawSchedules,
      payload['recent_reports'],
      payload['recentReports'],
      payload['today_schedules'],
      payload['todaySchedules'],
    ];
    final nestedData = payload['data'];
    if (nestedData is Map) {
      final nested = _map(nestedData) ?? const <String, dynamic>{};
      combinedRows.addAll([
        nested['tasks'],
        nested['items'],
        nested['jadwal'],
        nested['schedules'],
        nested['reports'],
        nested['laporan'],
        nested['recent_reports'],
        nested['recentReports'],
        nested['today_schedules'],
        nested['todaySchedules'],
      ]);
    } else {
      combinedRows.add(nestedData);
    }
    final schedules = <VisitSchedule>[];
    final seen = <String>{};
    for (final value in combinedRows) {
      if (value is! List) continue;
      for (final row in value.whereType<Map>()) {
        final item = VisitSchedule.fromJson(Map<String, dynamic>.from(row));
        final key =
            '${item.isInspection}:${item.scheduleId ?? item.id}:${item.status}:${item.reporterName}:${item.category}';
        if (seen.add(key)) schedules.add(item);
      }
    }

    return OfficerDashboardData(
      summary: OfficerSummary.fromJson(summaryJson),
      schedules: schedules,
      profile: OfficerProfile.fromJson(profileJson),
    );
  }
}

class OfficerSummary {
  const OfficerSummary({
    this.newReportsCount,
    this.todayInspectionsCount,
    this.activeTasksCount,
    this.completedCount,
  });

  final int? newReportsCount;
  final int? todayInspectionsCount;
  final int? activeTasksCount;
  final int? completedCount;

  factory OfficerSummary.fromJson(Map<String, dynamic> json) {
    return OfficerSummary(
      newReportsCount: _optionalInteger(
        json['aduan_baru_count'] ?? json['new_reports_count'],
      ),
      todayInspectionsCount: _optionalInteger(
        json['jadwal_ikl_hari_ini_count'] ??
            json['today_inspections_count'] ??
            json['jadwal_hari_ini_count'],
      ),
      activeTasksCount: _optionalInteger(
        json['tugas_aktif_count'] ?? json['active_tasks_count'],
      ),
      completedCount: _optionalInteger(
        json['selesai_count'] ?? json['completed_count'],
      ),
    );
  }
}

class OfficerProfile {
  const OfficerProfile({
    this.name = '',
    this.nip = '',
    this.position = '',
    this.serviceArea = '',
    this.healthCenter = '',
  });

  final String name;
  final String nip;
  final String position;
  final String serviceArea;
  final String healthCenter;

  factory OfficerProfile.fromJson(Map<String, dynamic> json) {
    return OfficerProfile(
      name: _string(json['nama'] ?? json['name'] ?? json['nama_petugas']),
      nip: _string(json['nip']),
      position: _string(json['jabatan'] ?? json['position']),
      serviceArea: _string(json['wilayah_kerja'] ?? json['service_area']),
      healthCenter: _string(
        json['puskesmas'] ?? json['nama_puskesmas'] ?? json['health_center'],
      ),
    );
  }
}

class StbmDesa {
  const StbmDesa({
    required this.name,
    this.verifiedHouseholds = 0,
    this.stbmAchievement = 0,
    this.waterRiskCount = 0,
    this.riskLabel = 'Belum ada data',
  });

  final String name;
  final int verifiedHouseholds;
  final double stbmAchievement;
  final int waterRiskCount;
  final String riskLabel;

  factory StbmDesa.fromJson(Map<String, dynamic> json) {
    final waterRisk = json['risiko_air_count'] ?? json['water_risk_count'];
    return StbmDesa(
      name: _string(
        json['nama_desa'] ?? json['desa'] ?? json['name'],
        fallback: 'Desa',
      ),
      verifiedHouseholds: _integer(
        json['rumah_terverifikasi'] ?? json['verified_households'],
      ),
      stbmAchievement: _decimal(
        json['capaian_stbm'] ?? json['stbm_achievement'] ?? json['persentase'],
      ),
      waterRiskCount: _integer(waterRisk),
      riskLabel: _string(
        json['risiko_air'] ?? json['risk_label'],
        fallback: 'Belum ada data',
      ),
    );
  }
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _optionalInteger(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _string(Object? value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
