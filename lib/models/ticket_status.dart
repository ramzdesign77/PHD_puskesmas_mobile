class TicketStatus {
  const TicketStatus({
    required this.code,
    required this.status,
    required this.category,
    required this.description,
    required this.village,
    required this.rt,
    required this.rw,
    required this.createdAt,
    this.visitDate,
    this.officer,
    this.visitStatus,
  });

  final String code;
  final String status;
  final String category;
  final String description;
  final String? village;
  final String rt;
  final String rw;
  final String? createdAt;
  final String? visitDate;
  final String? officer;
  final String? visitStatus;

  factory TicketStatus.fromJson(Map<String, dynamic> json) {
    final schedule = json['jadwal'] as Map<String, dynamic>?;

    return TicketStatus(
      code: json['kode_tiket'] as String? ?? '',
      status: json['status_laporan'] as String? ?? '',
      category: json['kategori_laporan'] as String? ?? '',
      description: json['deskripsi'] as String? ?? '',
      village: json['desa'] as String?,
      rt: json['rt'] as String? ?? '-',
      rw: json['rw'] as String? ?? '-',
      createdAt: json['created_at'] as String?,
      visitDate: schedule?['tanggal_kunjungan'] as String?,
      officer: schedule?['petugas'] as String?,
      visitStatus: schedule?['status_kunjungan'] as String?,
    );
  }
}
