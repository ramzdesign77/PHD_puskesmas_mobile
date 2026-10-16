import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../models/visit_schedule.dart';

/// Widget Card reusable untuk satu item jadwal kunjungan di ListView.
/// Berisi: Nama Pelapor, Alamat/Desa, Tanggal, Badge Status, dan Kategori.
class VisitCardWidget extends StatelessWidget {
  const VisitCardWidget({
    super.key,
    required this.schedule,
    required this.onTap,
  });

  final VisitSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = _statusBadge(schedule.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Garis warna status di atas card ─────────────────
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: badge.color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

            // ── Konten Card ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris atas: nama pelapor + badge status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          schedule.reporterName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(label: badge.label, color: badge.color),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Kategori laporan
                  _InfoRow(
                    icon: Icons.category_outlined,
                    text: schedule.category,
                    bold: true,
                    iconColor: AppColors.primary,
                  ),
                  const SizedBox(height: 4),

                  // Alamat + Desa
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text:
                        '${schedule.address}, RT ${schedule.rt}/RW ${schedule.rw} — ${schedule.village}',
                  ),
                  const SizedBox(height: 4),

                  // Tanggal kunjungan
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: 'Kunjungan: ${_formatDate(schedule.visitDate)}',
                    iconColor: AppColors.amber,
                  ),
                ],
              ),
            ),

            // ── Footer: tombol lihat detail ──────────────────────
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    schedule.ticketCode.isEmpty
                        ? 'Detail Laporan'
                        : schedule.ticketCode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: format tanggal '2026-10-18' → '18 Oktober 2026' ───
  String _formatDate(String raw) {
    try {
      final parts = raw.split('-');
      if (parts.length != 3) return raw;
      const bulan = [
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
      final m = int.tryParse(parts[1]) ?? 0;
      return '${parts[2]} ${bulan[m]} ${parts[0]}';
    } catch (_) {
      return raw;
    }
  }

  // ── Helper: tentukan label & warna badge berdasarkan status ───
  _BadgeData _statusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return _BadgeData('Selesai', AppColors.green);
      case 'diproses':
        return _BadgeData('Diproses', AppColors.amber);
      default:
        return _BadgeData('Belum Ditangani', AppColors.primary);
    }
  }
}

// ────────────────────────────────────────────────────────────────────────
// Widget Badge Status (label berwarna)
// ────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Widget baris info (icon + teks)
// ────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.bold = false,
    this.iconColor = AppColors.muted,
  });

  final IconData icon;
  final String text;
  final bool bold;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: bold ? AppColors.ink : AppColors.muted,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Data holder untuk badge ──────────────────────────────────────────────
class _BadgeData {
  const _BadgeData(this.label, this.color);

  final String label;
  final Color color;
}
