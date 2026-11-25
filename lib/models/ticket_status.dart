import 'risk_score.dart';

class TicketStatus {
  const TicketStatus({
    required this.code,
    required this.status,
    required this.category,
    required this.description,
    this.reporterName,
    required this.village,
    required this.rt,
    required this.rw,
    required this.createdAt,
    this.visitDate,
    this.officer,
    this.visitStatus,
    this.intervention,
    this.riskCategory,
    this.riskScore,
    this.inspectionDate,
    this.recommendation,
    this.rejectionReason,
  });

  final String code;
  final String status;
  final String category;
  final String description;
  final String? reporterName;
  final String? village;
  final String rt;
  final String rw;
  final String? createdAt;
  final String? visitDate;
  final String? officer;
  final String? visitStatus;
  final String? intervention;
  final String? riskCategory;
  final int? riskScore;
  final String? inspectionDate;
  final String? recommendation;
  final String? rejectionReason;

  bool get hasInspectionResult =>
      (riskCategory?.trim().isNotEmpty ?? false) ||
      riskScore != null ||
      inspectionDate != null;

  String get riskLabel => RiskScore.label(riskCategory);

  int? get currentStepIndex => switch (status.trim().toLowerCase()) {
    'dikirim' => 0,
    'menunggu' || 'diproses' || 'pending' => 1,
    'dijadwalkan' => 2,
    'ditindaklanjuti' => 3,
    'selesai' => 4,
    'ditolak' => null,
    _ => 0,
  };

  bool get isRejected => status.trim().toLowerCase() == 'ditolak';

  bool get isCompleted =>
      status.trim().toLowerCase() == 'selesai' || isRejected;

  Map<String, dynamic> toJson() => {
    'kode_tiket': code,
    'status_laporan': status,
    'kategori_laporan': category,
    'deskripsi': description,
    'nama_pelapor': reporterName,
    'desa': village,
    'rt': rt,
    'rw': rw,
    'created_at': createdAt,
    'tanggal_kunjungan': visitDate,
    'petugas': officer,
    'status_kunjungan': visitStatus,
    'intervensi_fisik': intervention,
    'kategori_risiko_air': riskCategory,
    'kategori_risiko': riskCategory,
    'total_skor_ya': riskScore,
    'tanggal_inspeksi': inspectionDate,
    'rekomendasi_sanitarian': recommendation,
    'alasan_penolakan': rejectionReason,
  };

  factory TicketStatus.fromJson(Map<String, dynamic> json) {
    final schedule = _jsonMap(json['jadwal']);
    final inspection =
        _jsonMap(json['hasil_inspeksi']) ?? _jsonMap(json['hasil_ikl']);

    return TicketStatus(
      code: _stringValue(json['kode_tiket']) ?? '',
      status: _stringValue(json['status_laporan']) ?? '',
      category: _stringValue(json['kategori_laporan']) ?? '',
      description: _stringValue(json['deskripsi']) ?? '',
      reporterName: _stringValue(json['nama_pelapor']),
      village: _stringValue(json['desa']),
      rt: _stringValue(json['rt']) ?? '-',
      rw: _stringValue(json['rw']) ?? '-',
      createdAt: _stringValue(json['created_at']),
      visitDate:
          _stringValue(schedule?['tanggal_kunjungan']) ??
          _stringValue(json['tanggal_kunjungan']),
      officer:
          _stringValue(schedule?['petugas']) ?? _stringValue(json['petugas']),
      visitStatus:
          _stringValue(schedule?['status_kunjungan']) ??
          _stringValue(json['status_kunjungan']),
      intervention:
          _stringValue(inspection?['intervensi_fisik']) ??
          _stringValue(schedule?['intervensi_fisik']) ??
          _stringValue(json['intervensi_fisik']) ??
          _stringValue(json['jenis_intervensi']),
      riskCategory:
          _stringValue(inspection?['kategori_risiko']) ??
          _stringValue(inspection?['kategori_risiko_air']) ??
          _stringValue(inspection?['risiko_air']) ??
          _stringValue(json['kategori_risiko']) ??
          _stringValue(json['kategori_risiko_air']) ??
          _stringValue(json['risiko_air']),
      riskScore: _parseRiskScore(
        inspection?['total_skor_ya'] ?? json['total_skor_ya'],
      ),
      inspectionDate:
          _stringValue(inspection?['tanggal_inspeksi']) ??
          _stringValue(json['tanggal_inspeksi']),
      recommendation:
          _stringValue(inspection?['rekomendasi_sanitarian']) ??
          _stringValue(json['rekomendasi_sanitarian']),
      rejectionReason:
          _stringValue(json['alasan_penolakan']) ??
          _stringValue(json['catatan_penolakan']),
    );
  }
}

Map<String, dynamic>? _jsonMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String? _stringValue(Object? value) {
  if (value is String) return value;
  if (value is num) return value.toString();
  return null;
}

int? _parseRiskScore(Object? value) {
  final score = value is int ? value : int.tryParse(value?.toString() ?? '');
  return score != null && score >= 0 && score <= 5 ? score : null;
}
