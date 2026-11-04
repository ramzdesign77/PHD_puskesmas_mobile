import 'package:flutter_test/flutter_test.dart';
import 'package:klinik_sanitasi_mobile/models/risk_score.dart';
import 'package:klinik_sanitasi_mobile/models/ticket_status.dart';
import 'package:klinik_sanitasi_mobile/models/visit_schedule.dart';

void main() {
  test('all checklist scores use the backend thresholds', () {
    const expected = [
      'aman',
      'risiko_sedang',
      'risiko_sedang',
      'risiko_tinggi',
      'risiko_tinggi',
      'risiko_tinggi',
    ];
    for (var score = 0; score <= 5; score++) {
      final answers = List.generate(5, (index) => index < score);
      expect(RiskScore.total(answers), score);
      expect(RiskScore.category(RiskScore.total(answers)), expected[score]);
    }
  });

  test('missing inspection stays unknown and never defaults to Aman', () {
    final ticket = TicketStatus.fromJson({
      'kode_tiket': 'IKL-1',
      'status_laporan': 'dijadwalkan',
      'hasil_inspeksi': null,
    });
    expect(ticket.hasInspectionResult, isFalse);
    expect(ticket.riskScore, isNull);
    expect(ticket.riskLabel, 'Belum tersedia');
    expect(TicketStatus.fromJson(ticket.toJson()).hasInspectionResult, isFalse);
  });

  test('server result survives the offline ticket cache round trip', () {
    final ticket = TicketStatus.fromJson({
      'kode_tiket': 'IKL-1',
      'status_laporan': 'selesai',
      'hasil_inspeksi': {
        'total_skor_ya': 3,
        'kategori_risiko': 'risiko_tinggi',
        'tanggal_inspeksi': '2026-11-02',
        'rekomendasi_sanitarian': 'Perbaiki saluran pembuangan.',
        'intervensi_fisik': 'Edukasi',
      },
    });
    final cached = TicketStatus.fromJson(ticket.toJson());
    expect(cached.hasInspectionResult, isTrue);
    expect(cached.riskLabel, 'Tinggi');
    expect(cached.riskScore, 3);
    expect(cached.inspectionDate, '2026-11-02');
    expect(cached.recommendation, 'Perbaiki saluran pembuangan.');
  });

  test('zero is a saved safe result rather than a missing score', () {
    final ticket = TicketStatus.fromJson({
      'hasil_inspeksi': {'total_skor_ya': 0, 'kategori_risiko': 'aman'},
    });
    expect(ticket.hasInspectionResult, isTrue);
    expect(ticket.riskScore, 0);
    expect(ticket.riskLabel, 'Aman');
  });

  test('report id is kept separate from the nested inspection schedule id', () {
    final task = VisitSchedule.fromJson({
      'id': 99,
      'id_laporan': 99,
      'jadwal': {
        'id_jadwal': 7,
        'status_kunjungan': 'terjadwal',
        'hasil_inspeksi': {'kategori_risiko': 'risiko_sedang'},
      },
    });
    expect(task.id, 99);
    expect(task.scheduleId, 7);
    expect(task.riskCategory, 'risiko_sedang');
    expect(task.copyWith(status: 'selesai').scheduleId, 7);
    expect(task.copyWith(status: 'selesai').riskCategory, 'risiko_sedang');
    expect(
      VisitSchedule.fromJson({'id': 99, 'tipe': 'aduan'}).scheduleId,
      isNull,
    );
  });
}
