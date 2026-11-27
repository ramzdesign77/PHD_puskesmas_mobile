import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/risk_score.dart';
import '../../../models/visit_schedule.dart';
import '../../../theme/app_theme.dart';

String formatKategoriLaporan(String raw) {
  final normalized = raw.trim().toLowerCase();
  return switch (normalized) {
    'air_masalah' => 'Masalah Air Bersih',
    'air_sumur_keruh_berbau' => 'Air Sumur Keruh / Berbau',
    'sanitasi_lingkungan' => 'Sanitasi Lingkungan',
    'sarang_nyamuk_dbd' => 'Sarang Nyamuk / DBD',
    'jamban_limbah_stbm' => 'Masalah Jamban & Limbah (STBM)',
    'tumpukan_sampah' => 'Tumpukan Sampah',
    _ =>
      raw.trim().isEmpty || raw == '-'
          ? 'Kategori belum tersedia'
          : raw.trim().replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' '),
  };
}

class VisitCardWidget extends StatelessWidget {
  const VisitCardWidget({
    super.key,
    required this.schedule,
    required this.onTap,
    this.onAction,
    this.actionLabel,
    this.isInspection = false,
    this.isHistory = false,
  });

  final VisitSchedule schedule;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool isInspection;
  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final pending = _isPending(schedule.status);
    final normalizedStatus = schedule.status.toLowerCase();
    final riskLabel = RiskScore.label(schedule.riskCategory);
    final historyRiskLabel = _historyRiskLabel(schedule.riskCategory);
    final hasRisk = riskLabel != 'Belum tersedia';
    final badgeColor = isHistory
        ? switch (historyRiskLabel) {
            'Aman' => AppColors.green,
            'Risiko Sedang' => AppColors.amber,
            'Risiko Tinggi' => const Color(0xFFDC2626),
            _ => AppColors.muted,
          }
        : hasRisk
        ? switch (riskLabel) {
            'Aman' => AppColors.green,
            'Sedang' => AppColors.amber,
            'Tinggi' => const Color(0xFFDC2626),
            _ => AppColors.accent,
          }
        : isInspection
        ? AppColors.accent
        : pending
        ? AppColors.amber
        : normalizedStatus == 'selesai'
        ? AppColors.green
        : AppColors.primary;
    final badgeLabel = isHistory
        ? historyRiskLabel
        : hasRisk
        ? 'RISIKO $riskLabel'
        : isInspection
        ? 'TERJADWAL IKL'
        : pending
        ? 'MENUNGGU VERIFIKASI'
        : normalizedStatus == 'selesai'
        ? 'SELESAI'
        : schedule.status.toUpperCase();
    final ticketLabel =
        schedule.ticketCode != '-' && schedule.ticketCode.trim().isNotEmpty
        ? schedule.ticketCode.startsWith('#')
              ? schedule.ticketCode
              : '#${schedule.ticketCode}'
        : '';
    final villageLabel = schedule.village == '-'
        ? '-'
        : schedule.village.toLowerCase().startsWith('desa ')
        ? schedule.village
        : 'Desa ${schedule.village}';
    final rtRwLabel = schedule.rt == '-' && schedule.rw == '-'
        ? ''
        : ', RT ${schedule.rt}/RW ${schedule.rw}';
    final locationLabel = '$villageLabel$rtRwLabel';
    final addressLabel =
        schedule.address != '-' && schedule.address.trim().isNotEmpty
        ? schedule.address
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        // BoxDecoration requires a uniform border when borderRadius is set.
        border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, color: badgeColor),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              badgeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (ticketLabel.isNotEmpty)
                          Flexible(
                            child: Text(
                              ticketLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.headlineFontFamily,
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ).asHeading,
                    ),
                    const SizedBox(height: 7),
                    if (!isInspection && schedule.category != '-') ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 15,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formatKategoriLaporan(schedule.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (addressLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        addressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (isHistory) ...[
                      const SizedBox(height: 7),
                      Text(
                        'Tanggal Pemeriksaan: ${_displayDate(schedule.inspectionDate ?? schedule.visitDate)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tindakan: ${schedule.intervention?.trim().isNotEmpty == true ? schedule.intervention : 'Belum tercatat'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!isInspection && schedule.description != '-') ...[
                      Text(
                        schedule.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: onAction ?? onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(actionLabel ?? 'Tindak Lanjut'),
                          ),
                        ),
                        if (!isHistory) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Detail'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _title {
    if (isInspection) return schedule.category;
    final category = schedule.category.trim();
    final reporter = schedule.reporterName.trim();
    if (reporter.isEmpty || reporter == '-') {
      return formatKategoriLaporan(category);
    }
    return reporter;
  }

  bool _isPending(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'pending' ||
        normalized == 'menunggu' ||
        normalized == 'belum diverifikasi' ||
        normalized == 'menunggu_verifikasi' ||
        normalized == 'menunggu-verifikasi' ||
        normalized == 'dikirim' ||
        normalized == 'diproses' ||
        normalized == 'terjadwal' ||
        normalized == 'dijadwalkan';
  }

  String _historyRiskLabel(String? category) {
    final normalized = category?.trim().toLowerCase().replaceAll(' ', '_');
    return switch (normalized) {
      'aman' => 'Aman',
      'sedang' || 'risiko_sedang' => 'Risiko Sedang',
      'tinggi' ||
      'risiko_tinggi' ||
      'amat_tinggi' ||
      'risiko_amat_tinggi' => 'Risiko Tinggi',
      _ => 'Risiko Belum Tersedia',
    };
  }

  String _displayDate(String value) =>
      value.trim().isEmpty || value == '-' ? 'Belum tersedia' : value;
}
