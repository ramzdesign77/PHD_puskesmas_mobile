/// Model data untuk satu jadwal kunjungan petugas ke lapangan.
/// Field-field ini sesuai dengan struktur respons API Laravel.
class VisitSchedule {
  const VisitSchedule({
    required this.id,
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
  });

  final int id;
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

  /// Parsing dari respons JSON API Laravel
  factory VisitSchedule.fromJson(Map<String, dynamic> json) {
    final schedule = json['jadwal'] as Map<String, dynamic>?;
    return VisitSchedule(
      id: json['id'] as int? ?? 0,
      reporterName: json['nama_pelapor'] as String? ?? '-',
      address: json['alamat'] as String? ?? '-',
      village: json['desa'] as String? ?? '-',
      visitDate: schedule?['tanggal_kunjungan'] as String? ?? '-',
      status: json['status_laporan'] as String? ?? 'pending',
      category: json['kategori_laporan'] as String? ?? '-',
      description: json['deskripsi'] as String? ?? '-',
      rt: json['rt'] as String? ?? '-',
      rw: json['rw'] as String? ?? '-',
      ticketCode: json['kode_tiket'] as String? ?? '',
      officerNote: schedule?['catatan_petugas'] as String? ?? '',
      photoUrl: schedule?['foto_bukti'] as String?,
    );
  }

  /// Salin objek dengan nilai yang diperbarui (immutable update)
  VisitSchedule copyWith({String? status, String? officerNote}) {
    return VisitSchedule(
      id: id,
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
    );
  }
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
    description:
        'Sumber air sumur warga berwarna keruh dan berbau tidak sedap sejak 2 minggu lalu.',
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
    description:
        'Limbah rumah tangga mengenang di depan rumah dan menimbulkan bau busuk.',
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
    officerNote:
        'Telah dilakukan perbaikan ringan. Disarankan pengajuan anggaran perbaikan besar ke desa.',
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
    officerNote:
        'Pipa telah diperbaiki oleh PDAM setempat atas koordinasi petugas puskesmas.',
  ),
];
