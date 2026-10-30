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
  final String? recommendation;
  final String? rejectionReason;

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

  factory TicketStatus.fromJson(Map<String, dynamic> json) {
    final schedule = json['jadwal'] as Map<String, dynamic>?;
    final inspection =
        json['hasil_ikl'] as Map<String, dynamic>? ??
        json['hasil_inspeksi'] as Map<String, dynamic>?;

    return TicketStatus(
      code: json['kode_tiket'] as String? ?? '',
      status: json['status_laporan'] as String? ?? '',
      category: json['kategori_laporan'] as String? ?? '',
      description: json['deskripsi'] as String? ?? '',
      reporterName: json['nama_pelapor'] as String?,
      village: json['desa'] as String?,
      rt: json['rt'] as String? ?? '-',
      rw: json['rw'] as String? ?? '-',
      createdAt: json['created_at'] as String?,
      visitDate:
          schedule?['tanggal_kunjungan'] as String? ??
          json['tanggal_kunjungan'] as String?,
      officer: schedule?['petugas'] as String?,
      visitStatus: schedule?['status_kunjungan'] as String?,
      intervention:
          inspection?['intervensi_fisik'] as String? ??
          schedule?['intervensi_fisik'] as String? ??
          json['intervensi_fisik'] as String? ??
          json['jenis_intervensi'] as String?,
      riskCategory:
          inspection?['kategori_risiko_air'] as String? ??
          inspection?['risiko_air'] as String? ??
          json['kategori_risiko_air'] as String? ??
          json['risiko_air'] as String?,
      recommendation:
          inspection?['rekomendasi_sanitarian'] as String? ??
          json['rekomendasi_sanitarian'] as String?,
      rejectionReason:
          json['alasan_penolakan'] as String? ??
          json['catatan_penolakan'] as String?,
    );
  }
}
