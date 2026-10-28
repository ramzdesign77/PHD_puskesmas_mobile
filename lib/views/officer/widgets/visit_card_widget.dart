import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/visit_schedule.dart';

class VisitCardWidget extends StatelessWidget {
  const VisitCardWidget({
    super.key,
    required this.schedule,
    required this.onTap,
    this.onAction,
    this.actionLabel,
    this.isInspection = false,
  });

  final VisitSchedule schedule;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool isInspection;

  @override
  Widget build(BuildContext context) {
    final pending = _isPending(schedule.status);
    final badgeColor = isInspection
        ? AppColors.orange
        : pending
        ? const Color(0xFFE53935)
        : schedule.status.toLowerCase() == 'selesai'
        ? AppColors.green
        : AppColors.amber;
    final badgeLabel = isInspection
        ? 'JADWAL IKL HARI INI'
        : pending
        ? 'BELUM DIVERIFIKASI'
        : schedule.status.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${schedule.village} - RT ${schedule.rt}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      schedule.visitDate == '-'
                          ? schedule.ticketCode
                          : 'Kunjungan: ${_formatDate(schedule.visitDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      onPressed: onAction ?? onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(actionLabel ?? 'Tindak Lanjut'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    if (isInspection) return schedule.category;
    final category = schedule.category.trim();
    final reporter = schedule.reporterName.trim();
    if (category.isEmpty || category == '-') return reporter;
    if (reporter.isEmpty || reporter == '-') return category;
    return '$category - $reporter';
  }

  bool _isPending(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'pending' ||
        normalized == 'menunggu' ||
        normalized == 'belum diverifikasi';
  }

  String _formatDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return raw;
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month >= months.length) return raw;
    return '${parts[2]} ${months[month]} ${parts[0]}';
  }
}
