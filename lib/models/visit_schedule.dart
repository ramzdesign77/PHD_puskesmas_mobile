/// Model data untuk satu jadwal kunjungan petugas ke lapangan.
/// Field-field ini sesuai dengan struktur respons API Laravel.
class VisitSchedule {
  const VisitSchedule({
    required this.id,
    this.scheduleId,
    required this.reporterName,
    required this.address,
    required this.village,
    required this.visitDate,
    required this.status,
    required this.category,
    required this.description,
    required this.rt,
    required this.rw,
    this.ticketCode = '',
    this.officerNote = '',
    this.photoUrl,
    this.isInspection = false,
    this.riskCategory,
  });

  final int id;
  final int? scheduleId;
  final String reporterName;
  final String address;
  final String village;
  final String visitDate;

  /// Status tiket: 'pending', 'diproses', 'selesai'
  final String status;
  final String category;
  final String description;
  final String rt;
  final String rw;
  final String ticketCode;
  final String officerNote;
  final String? photoUrl;
  final bool isInspection;
  final String? riskCategory;

  /// Parsing dari respons JSON API Laravel
  factory VisitSchedule.fromJson(Map<String, dynamic> json) {
    final scheduleValue = json['jadwal'] ?? json['schedule'];
    final schedule = scheduleValue is Map
        ? Map<String, dynamic>.from(scheduleValue)
        : null;
    final location = json['lokasi'] is Map
        ? Map<String, dynamic>.from(json['lokasi'] as Map)
        : const <String, dynamic>{};
    final villageValue = json['desa'] is Map
        ? json['desa']
        : json['village'] is Map
        ? json['village']
        : json['lokasi'] is Map
        ? ((json['lokasi'] as Map)['desa'] is Map
              ? (json['lokasi'] as Map)['desa']
              : null)
        : null;
    final villageMap = villageValue is Map
        ? Map<String, dynamic>.from(villageValue)
        : const <String, dynamic>{};
    final reporterValue = json['pelapor'] is Map
        ? json['pelapor']
        : json['user'] is Map
        ? json['user']
        : json['warga'] is Map
        ? json['warga']
        : null;
    final reporterMap = reporterValue is Map
        ? Map<String, dynamic>.from(reporterValue)
        : const <String, dynamic>{};
    final inspectionValue =
        json['hasil_inspeksi'] ??
        json['inspection'] ??
        schedule?['hasil_inspeksi'];
    final inspection = inspectionValue is Map
        ? Map<String, dynamic>.from(inspectionValue)
        : const <String, dynamic>{};
    final reportValue =
        json['laporan'] ?? json['report'] ?? json['aduan'] ?? json['data'];
    final report = reportValue is Map
        ? Map<String, dynamic>.from(reportValue)
        : const <String, dynamic>{};
    final desaValue =
        json['desa'] ??
        json['village_name'] ??
        report['desa'] ??
        report['village'];
    final desaMap = desaValue is Map
        ? Map<String, dynamic>.from(desaValue)
        : const <String, dynamic>{};
    final nestedLocation = _map(report['lokasi']) ?? location;
    final nestedPelapor = _map(report['pelapor']) ?? reporterMap;
    final id =
        json['id_laporan'] ??
        json['laporan_id'] ??
        report['id_laporan'] ??
        report['id'] ??
        json['id'] ??
        json['id_jadwal'] ??
        schedule?['id_laporan'] ??
        schedule?['id'];
    final type =
        (json['tipe'] ??
                json['type'] ??
                json['jenis'] ??
                json['task_type'] ??
                '')
            .toString()
            .toLowerCase();
    final scheduleId =
        json['id_jadwal'] ??
        json['jadwal_id'] ??
        schedule?['id_jadwal'] ??
        schedule?['id'] ??
        (type.contains('ikl') || type.contains('inspeksi') ? id : null);
    final isInspectionValue =
        type.contains('ikl') ||
        type.contains('inspeksi') ||
        json['is_inspection'] == true ||
        json['id_jadwal'] != null ||
        json['jadwal_id'] != null ||
        schedule != null ||
        json['tanggal_kunjungan'] != null ||
        json['visit_date'] != null;
    final statusValue =
        json['status_kunjungan'] ??
        schedule?['status_kunjungan'] ??
        json['status_verifikasi'] ??
        report['status_verifikasi'] ??
        json['status_laporan'] ??
        report['status_laporan'] ??
        json['status'] ??
        schedule?['status'];
    final reporterName =
        json['nama_pelapor'] ??
        json['citizen_name'] ??
        json['pelapor'] ??
        reporterMap['nama_lengkap'] ??
        reporterMap['name'] ??
        reporterMap['nama'] ??
        nestedPelapor['nama_lengkap'] ??
        nestedPelapor['name'] ??
        nestedPelapor['nama'] ??
        report['nama_pelapor'];
    final ticketCode =
        json['kode_tiket'] ??
        json['ticket_code'] ??
        report['kode_tiket'] ??
        report['ticket_code'];
    final category =
        json['kategori_label'] ??
        json['kategori_laporan'] ??
        json['category'] ??
        json['kategori'] ??
        report['kategori_label'] ??
        report['kategori_laporan'];
    final villageName =
        json['nama_desa'] ??
        desaMap['nama_desa'] ??
        report['nama_desa'] ??
        _map(report['desa'])?['nama_desa'] ??
        json['village_name'] ??
        villageMap['nama_desa'] ??
        villageMap['name'] ??
        (desaValue is String ? desaValue : null) ??
        location['nama_desa'] ??
        location['desa'];
    return VisitSchedule(
      scheduleId: scheduleId is int
          ? scheduleId
          : int.tryParse(scheduleId?.toString() ?? ''),
      id: id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0,
      reporterName: _stringValue(reporterName, fallback: 'Warga Pelapor'),
      address: _stringValue(
        json['alamat_detail'] ??
            json['patokan_alamat'] ??
            json['alamat'] ??
            json['address'] ??
            report['alamat_detail'] ??
            report['alamat'] ??
            nestedLocation['alamat_detail'] ??
            '',
        fallback: '',
      ),
      village: _stringValue(villageName, fallback: '-'),
      visitDate: _stringValue(
        schedule?['tanggal_kunjungan'] ??
            json['tanggal_kunjungan'] ??
            json['visit_date'] ??
            json['created_at'] ??
            report['tanggal_kunjungan'] ??
            report['created_at'],
        fallback: '',
      ),
      status: _stringValue(statusValue, fallback: 'menunggu'),
      category: _normalizeCategory(category),
      description: _stringValue(
        json['deskripsi'] ??
            json['description'] ??
            json['isi_laporan'] ??
            report['deskripsi'] ??
            report['description'] ??
            '',
        fallback: '',
      ),
      rt: _stringValue(
        json['rt'] ??
            report['rt'] ??
            nestedLocation['rt'] ??
            location['rt'] ??
            villageMap['rt'],
      ),
      rw: _stringValue(
        json['rw'] ??
            report['rw'] ??
            nestedLocation['rw'] ??
            location['rw'] ??
            villageMap['rw'],
      ),
      ticketCode: _stringValue(ticketCode, fallback: '-'),
      officerNote: _stringValue(
        schedule?['catatan_petugas'] ?? json['catatan_petugas'],
      ),
      photoUrl: json['foto_bukti'] is String
          ? json['foto_bukti'] as String
          : schedule?['foto_bukti'] is String
          ? schedule!['foto_bukti'] as String
          : null,
      isInspection: isInspectionValue,
      riskCategory: _optionalString(
        inspection['kategori_risiko'] ??
            inspection['kategori_risiko_air'] ??
            json['kategori_risiko'] ??
            json['kategori_risiko_air'],
      ),
    );
  }

  /// Salin objek dengan nilai yang diperbarui (immutable update)
  VisitSchedule copyWith({String? status, String? officerNote}) {
    return VisitSchedule(
      id: id,
      scheduleId: scheduleId,
      reporterName: reporterName,
      address: address,
      village: village,
      visitDate: visitDate,
      status: status ?? this.status,
      category: category,
      description: description,
      rt: rt,
      rw: rw,
      ticketCode: ticketCode,
      officerNote: officerNote ?? this.officerNote,
      photoUrl: photoUrl,
      isInspection: isInspection,
      riskCategory: riskCategory,
    );
  }
}

String _stringValue(Object? value, {String fallback = '-'}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _normalizeCategory(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw == '-') return 'Masalah Sanitasi';
  final normalized = raw.toLowerCase().replaceAll(' ', '_');
  return switch (normalized) {
    'air_masalah' => 'Masalah Air Bersih',
    'air_sumur_keruh_berbau' => 'Air Sumur Keruh / Berbau',
    'sanitasi_lingkungan' => 'Sanitasi Lingkungan',
    'sarang_nyamuk_dbd' => 'Sarang Nyamuk / DBD',
    'jamban_limbah_stbm' => 'Masalah Jamban & Limbah (STBM)',
    'tumpukan_sampah' => 'Tumpukan Sampah',
    _ => raw.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
  };
}

/// Data dummy untuk preview UI sebelum API dihubungkan.
final List<VisitSchedule> dummyVisitSchedules = [
  const VisitSchedule(
    id: 1,
    reporterName: 'Budi Santoso',
    address: 'Jl. Melati No. 12',
    village: 'Desa Sukamaju',
    visitDate: '2026-10-18',
    status: 'pending',
    category: 'Sanitasi Air',
    description: 'Sumber air sumur warga berwarna keruh dan berbau tidak sedap sejak 2 minggu lalu.',
    rt: '03',
    rw: '01',
    ticketCode: 'TKT-001',
  ),
  const VisitSchedule(
    id: 2,
    reporterName: 'Siti Rahayu',
    address: 'Jl. Dahlia No. 5',
    village: 'Desa Cikaret',
    visitDate: '2026-10-19',
    status: 'diproses',
    category: 'Pembuangan Limbah',
    description: 'Limbah rumah tangga mengenang di depan rumah dan menimbulkan bau busuk.',
    rt: '01',
    rw: '02',
    ticketCode: 'TKT-002',
  ),
  const VisitSchedule(
    id: 3,
    reporterName: 'Ahmad Fauzi',
    address: 'Jl. Anggrek No. 8',
    village: 'Desa Bojong',
    visitDate: '2026-10-15',
    status: 'selesai',
    category: 'Jamban / MCK',
    description: 'Fasilitas MCK umum rusak dan tidak dapat digunakan warga.',
    rt: '05',
    rw: '03',
    ticketCode: 'TKT-003',
    officerNote: 'Telah dilakukan perbaikan ringan. Disarankan pengajuan anggaran perbaikan besar ke desa.',
  ),
  const VisitSchedule(
    id: 4,
    reporterName: 'Dewi Lestari',
    address: 'Jl. Kenanga No. 22',
    village: 'Desa Sukamaju',
    visitDate: '2026-10-20',
    status: 'pending',
    category: 'Vektor dan Binatang',
    description:
        'Terdapat sarang nyamuk di sekitar got warga yang jarang dibersihkan.',
    rt: '02',
    rw: '04',
    ticketCode: 'TKT-004',
  ),
  const VisitSchedule(
    id: 5,
    reporterName: 'Hendra Gunawan',
    address: 'Jl. Mawar No. 3',
    village: 'Desa Cikaret',
    visitDate: '2026-10-12',
    status: 'selesai',
    category: 'Sanitasi Air',
    description: 'Pipa air bocor menyebabkan genangan di jalan kampung.',
    rt: '04',
    rw: '02',
    ticketCode: 'TKT-005',
    officerNote: 'Pipa telah diperbaiki oleh PDAM setempat atas koordinasi petugas puskesmas.',
  ),
];
