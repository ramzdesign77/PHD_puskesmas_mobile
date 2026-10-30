import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/ticket_status.dart';
import '../../services/api_service.dart';
import '../../widgets/ocean_widgets.dart';

class TrackingView extends StatefulWidget {
  const TrackingView({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  final _ticketController = TextEditingController();
  TicketStatus? _ticket;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _ticketController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Masukkan kode tiket laporan.');
      return;
    }
    setState(() {
      _error = null;
      _ticket = null;
      _isLoading = true;
    });

    try {
      final ticket = await widget.apiService.getTicket(code);
      if (mounted) {
        setState(() => _ticket = ticket);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Status belum dapat dimuat. Periksa koneksi Anda.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          DynamicWaterHeader(
            height: 158,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 34),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lacak laporan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Pantau perkembangan laporan sanitasi Anda.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _ticketController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookup(),
            decoration: InputDecoration(
              labelText: 'Kode tiket',
              hintText: 'IKL-YYYYMMDD-XXXX',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              suffixIcon: IconButton(
                tooltip: 'Cari tiket',
                onPressed: _isLoading ? null : _lookup,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _isLoading ? null : _lookup,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Periksa status'),
          ),
          if (!_isLoading && _ticket == null && _error == null)
            const WaterEmptyState(
              icon: Icons.search_rounded,
              title: 'Siap melacak laporan',
              message:
                  'Masukkan kode tiket laporan untuk melihat status terbaru.',
            ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _MessagePanel(
              icon: Icons.info_outline,
              message: _error!,
              color: AppColors.primary,
            ),
          ],
          if (_ticket != null) ...[
            const SizedBox(height: 20),
            _TicketCard(ticket: _ticket!),
          ],
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final TicketStatus ticket;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(ticket.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: status.$2, width: 4),
          top: BorderSide(color: AppColors.line),
          right: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'STATUS LAPORAN',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status.$2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.$1,
                  style: TextStyle(
                    color: status.$2,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            ticket.code,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Divider(height: 24),
          _TicketDetail(
            label: 'Kategori',
            value: _categoryLabel(ticket.category),
          ),
          _TicketDetail(
            label: 'Alamat',
            value:
                '${ticket.village ?? '-'}, RT ${ticket.rt} / RW ${ticket.rw}',
          ),
          _TicketDetail(label: 'Dikirim', value: ticket.createdAt ?? '-'),
          const SizedBox(height: 12),
          const Text(
            'Keterangan',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(ticket.description, style: const TextStyle(height: 1.4)),
          if (ticket.visitDate != null) ...[
            const Divider(height: 24),
            _TicketDetail(label: 'Jadwal kunjungan', value: ticket.visitDate!),
            _TicketDetail(
              label: 'Petugas',
              value: ticket.officer ?? 'Belum ditentukan',
            ),
            if (ticket.visitStatus != null)
              _TicketDetail(
                label: 'Status kunjungan',
                value: ticket.visitStatus!,
              ),
          ],
        ],
      ),
    );
  }
}

class _TicketDetail extends StatelessWidget {
  const _TicketDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

(String, Color) _statusPresentation(String status) {
  return switch (status) {
    'menunggu' => ('Menunggu', AppColors.amber),
    'diproses' || 'proses' || 'dalam_proses' => ('Diproses', AppColors.primary),
    'dijadwalkan' => ('Dijadwalkan', AppColors.primary),
    'selesai' => ('Selesai', AppColors.green),
    'ditolak' => ('Ditolak', AppColors.primaryDark),
    _ => (status, AppColors.muted),
  };
}

String _categoryLabel(String category) {
  return switch (category) {
    'air_masalah' => 'Masalah air',
    'sanitasi_lingkungan' => 'Sanitasi lingkungan',
    _ => category,
  };
}
