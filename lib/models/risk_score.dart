/// Aturan IKL yang sama dengan InspeksiIkl::hitungKategoriRisiko di Laravel.
abstract final class RiskScore {
  static const fields = [
    'p1_dinding_sumur_retak',
    'p2_penutup_tidak_rapat',
    'p3_lantai_becek_retak',
    'p4_spal_tersumbat',
    'p5_air_keruh_berbau',
  ];

  static const questions = [
    'Dinding sumur retak',
    'Penutup sumber air tidak rapat',
    'Lantai di sekitar sumber air becek atau retak',
    'Saluran pembuangan air limbah (SPAL) tersumbat',
    'Air keruh atau berbau',
  ];

  static int total(List<bool> answers) {
    if (answers.length != fields.length) {
      throw ArgumentError('Lima jawaban checklist IKL harus diisi.');
    }
    return answers.where((answer) => answer).length;
  }

  static String category(int score) {
    if (score < 0 || score > 5) {
      throw RangeError.range(score, 0, 5, 'score');
    }
    if (score == 0) return 'aman';
    if (score <= 2) return 'risiko_sedang';
    return 'risiko_tinggi';
  }

  static String label(String? category) => switch (category?.trim().toLowerCase().replaceAll(' ', '_')) {
    'aman' => 'Aman',
    'risiko_sedang' || 'sedang' => 'Sedang',
    'risiko_tinggi' || 'tinggi' => 'Tinggi',
    _ => 'Belum tersedia',
  };
}
