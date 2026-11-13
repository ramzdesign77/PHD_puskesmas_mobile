/// Aturan IKL yang sama dengan InspeksiIkl::hitungKategoriRisiko di Laravel.
abstract final class RiskScore {
  static const legacyFields = [
    'p1_dinding_sumur_retak',
    'p2_penutup_tidak_rapat',
    'p3_lantai_becek_retak',
    'p4_spal_tersumbat',
    'p5_air_keruh_berbau',
  ];
  static const fields = [
    'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7',
  ];

  static const questions = [
    'Dinding sumur retak',
    'Penutup sumber air tidak rapat',
    'Lantai di sekitar sumber air becek atau retak',
    'Saluran pembuangan air limbah (SPAL) tersumbat',
    'Air keruh atau berbau',
  ];

  static const categoryQuestions = <String, List<String>>{
    'sumur_gali': [
      'Apakah jarak sumur dengan tangki septik (septic tank) atau sumber pencemar lain kurang dari 10 meter?',
      'Apakah cincin atau bibir sumur memiliki tinggi kurang dari 80 cm dari permukaan tanah?',
      'Apakah dinding sumur retak, bocor, atau tidak kedap air pada kedalaman 3 meter dari permukaan?',
      'Apakah lantai di sekeliling sumur retak, becek, atau tidak kedap air?',
      'Apakah tidak ada Saluran Pembuangan Air Limbah (SPAL) sehingga air bekas tumpahan menggenang?',
      'Apakah sumur tidak memiliki penutup bagian atas yang rapat?',
      'Apakah timba atau tali pengambil air diletakkan di lantai/tanah saat tidak digunakan?',
    ],
    'sumur_bor': [
      'Apakah jarak sumur bor dengan tangki septik (septic tank) atau sumber pencemar lain kurang dari 10 meter?',
      'Apakah lantai di sekeliling pompa retak, amblas, atau tidak kedap air?',
      'Apakah genangan air limbah ditemukan di sekitar dudukan pompa?',
      'Apakah dudukan mesin pompa (pengecoran) retak atau bocor?',
      'Apakah selubung pipa hisap air bor terlihat bocor, berkarat, atau tidak tertutup rapat?',
      'Apakah tangki penampungan air (toren) kotor, berlumut, atau tidak memiliki tutup rapat?',
      'Apakah kondisi air yang keluar dari pompa tampak keruh, berwarna, atau berbau?',
    ],
    'sarang_nyamuk_dbd': [
      'Apakah ditemukan jentik nyamuk pada bak mandi, ember, atau wadah air di dalam rumah?',
      'Apakah ditemukan jentik nyamuk pada penampungan air minum (tempayan, dispenser, toren)?',
      'Apakah barang bekas (ban, kaleng, botol) dibiarkan berserakan dan menampung air hujan di luar rumah?',
      'Apakah wadah penampungan air bersih dibiarkan terbuka atau tidak ditutup rapat?',
      'Apakah terdapat tumpukan pakaian kotor yang dibiarkan menggantung di dalam ruangan?',
      'Apakah ventilasi rumah (jendela atau lubang angin) tidak dilengkapi kawat anti nyamuk?',
      'Apakah lingkungan di dalam rumah terasa gelap, pengap, dan lembap?',
    ],
    'jamban_limbah_stbm': [
      'Apakah rumah tangga belum memiliki fasilitas jamban (WC) sendiri secara permanen?',
      'Apakah kloset yang digunakan bukan model leher angsa (misalnya kloset cemplung atau terbuka)?',
      'Apakah pipa pembuangan tinja tidak dialirkan ke tangki septik (septic tank) yang kedap air?',
      'Apakah pembuangan akhir tinja dialirkan langsung ke sungai, selokan, atau lahan terbuka?',
      'Apakah tidak tersedia fasilitas cuci tangan (air mengalir dan sabun) di dekat jamban?',
      'Apakah Saluran Pembuangan Air Limbah (SPAL) dari dapur atau kamar mandi tidak tertutup dan airnya menggenang?',
      'Apakah genangan limbah cair rumah tangga menimbulkan bau busuk di sekitar pekarangan?',
    ],
    'tumpukan_sampah': [
      'Apakah rumah tangga tidak menyediakan tempat sampah yang tertutup di dalam rumah?',
      'Apakah tempat penampungan sampah di luar rumah tidak kedap air dan dibiarkan terbuka?',
      'Apakah sampah rumah tangga dibiarkan menumpuk dan berserakan di atas tanah pekarangan?',
      'Apakah jarak tumpukan atau lubang pembuangan sampah kurang dari 10 meter dari sumber air?',
      'Apakah pengolahan sampah dilakukan dengan cara dibakar di area pemukiman padat?',
      'Apakah sampah rumah tangga dibuang sembarangan ke selokan, sungai, atau lahan kosong?',
      'Apakah ditemukan banyak vektor pembawa penyakit (lalat, tikus, kecoa) di area tumpukan sampah tersebut?',
    ],
  };

  static List<String> questionsFor(String category) =>
      categoryQuestions[category] ?? categoryQuestions['sumur_gali']!;

  static int totalDynamic(List<bool> answers) {
    if (answers.length != 7) throw ArgumentError('Tujuh jawaban IKL harus tersedia.');
    return answers.where((answer) => answer).length;
  }

  static String dynamicCategory(int score, {bool urgentWaterFinding = false}) {
    if (score < 0 || score > 7) throw RangeError.range(score, 0, 7, 'score');
    if (urgentWaterFinding || score >= 6) return 'risiko_amat_tinggi';
    if (score >= 4) return 'risiko_tinggi';
    if (score >= 2) return 'risiko_sedang';
    return 'aman';
  }

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
    'aman' => 'Risiko Rendah (Aman)',
    'risiko_sedang' || 'sedang' => 'Risiko Sedang',
    'risiko_tinggi' || 'tinggi' => 'Risiko Tinggi',
    'risiko_amat_tinggi' || 'amat_tinggi' => 'Risiko Amat Tinggi',
    _ => 'Belum tersedia',
  };
}
