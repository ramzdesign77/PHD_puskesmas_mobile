import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../models/ticket_status.dart';
import '../../services/api_service.dart';

class TrackingView extends StatefulWidget {
  const TrackingView({
    super.key,
    required this.apiService,
    this.initialTicketCode,
  });

  final ApiService apiService;
  final String? initialTicketCode;

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  final _ticketController = TextEditingController();
  TicketStatus? _ticket;
  bool _isLoading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialTicket(widget.initialTicketCode);
  }

  @override
  void didUpdateWidget(covariant TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCode = widget.initialTicketCode?.trim();
    if (newCode != null &&
        newCode.isNotEmpty &&
        newCode != oldWidget.initialTicketCode?.trim()) {
      _loadInitialTicket(newCode);
    }
  }

  void _loadInitialTicket(String? ticketCode) {
    final code = ticketCode?.trim();
    if (code == null || code.isEmpty) return;
    _ticketController.text = code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ticketController.text.trim() == code) {
        _trackTicket();
      }
    });
  }

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _trackTicket({bool clearPrevious = true}) async {
    final code = _ticketController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Masukkan kode tiket laporan.');
      return;
    }

    final requestId = ++_requestId;
    setState(() {
      _error = null;
      if (clearPrevious) _ticket = null;
      _isLoading = true;
    });

    try {
      final ticket = await widget.apiService.getTicket(code);
      if (mounted && requestId == _requestId) {
        setState(() => _ticket = ticket);
      }
    } on ApiException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(
          () => _error = 'Status belum dapat dimuat. Periksa koneksi Anda.',
        );
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refresh() async {
    if (_ticketController.text.trim().isNotEmpty) {
      await _trackTicket(clearPrevious: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Text(
              'Lacak laporan',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pantau perkembangan penanganan laporan Anda.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            _buildSearchBar(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _MessagePanel(
                icon: Icons.info_outline,
                message: _error!,
                color: AppColors.primary,
              ),
            ],
            if (_isLoading && _ticket == null) ...[
              const SizedBox(height: 52),
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ] else if (_ticket != null) ...[
              const SizedBox(height: 18),
              _TicketDetails(ticket: _ticket!),
            ] else if (_error == null) ...[
              const SizedBox(height: 72),
              const _EmptyTrackingState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _ticketController,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _trackTicket(),
        decoration: InputDecoration(
          hintText: 'Masukkan kode tiket (TK-...)',
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.primary,
          ),
          suffixIcon: IconButton(
            tooltip: 'Cari tiket',
            onPressed: _isLoading ? null : _trackTicket,
            icon: _isLoading
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.search, color: AppColors.primary),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _TicketDetails extends StatelessWidget {
  const _TicketDetails({required this.ticket});

  final TicketStatus ticket;

  @override
  Widget build(BuildContext context) {
    final stepIndex = ticket.currentStepIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusHero(ticket: ticket),
        if (!ticket.isRejected) ...[
          const SizedBox(height: 14),
          _ProgressCard(currentStepIndex: stepIndex ?? 0),
        ],
        if (ticket.isRejected) ...[
          const SizedBox(height: 14),
          _RejectedBanner(reason: ticket.rejectionReason),
        ],
        if (!ticket.isRejected && (stepIndex ?? -1) >= 2) ...[
          const SizedBox(height: 14),
          _ScheduleCard(ticket: ticket),
        ],
        const SizedBox(height: 14),
        _TimelineCard(ticket: ticket),
        const SizedBox(height: 14),
        _ReportSummaryCard(ticket: ticket),
        if (ticket.status.trim().toLowerCase() == 'selesai') ...[
          const SizedBox(height: 14),
          _RecommendationCard(ticket: ticket),
        ],
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.ticket});

  final TicketStatus ticket;

  @override
  Widget build(BuildContext context) {
    final rejected = ticket.isRejected;
    final step = ticket.currentStepIndex;
    final presentation = _statusPresentation(ticket.status);
    final title = rejected
        ? 'Laporan Ditolak'
        : switch (step) {
            0 => 'Laporan Berhasil Dikirim',
            1 => 'Laporan Sedang Diproses',
            2 => 'Laporan Sedang Dijadwalkan',
            3 => 'Petugas Sedang Menindaklanjuti',
            4 => 'Penanganan Selesai',
            _ => 'Status Laporan',
          };
    final description = rejected
        ? (ticket.rejectionReason?.trim().isNotEmpty == true
              ? ticket.rejectionReason!
              : 'Laporan belum dapat ditindaklanjuti.')
        : switch (step) {
            0 => 'Laporan Anda sudah tercatat dan menunggu verifikasi.',
            1 => 'Admin Puskesmas sedang memverifikasi laporan Anda.',
            2 => 'Jadwal kunjungan petugas sedang disiapkan.',
            3 => 'Petugas sedang melakukan pemeriksaan atau intervensi.',
            4 => 'Pemeriksaan selesai dan rekomendasi telah diterbitkan.',
            _ => 'Status laporan Anda telah diperbarui.',
          };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rejected
              ? const [Color(0xFFC63832), Color(0xFF8F1D1D)]
              : const [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rejected ? 'STATUS LAPORAN' : 'PEMBARUAN LAPORAN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    presentation.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              rejected ? Icons.cancel_outlined : _stepIcon(step),
              color: Colors.white,
              size: 33,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.currentStepIndex});

  final int currentStepIndex;

  static const _steps = [
    ('Dikirim', Icons.send_rounded),
    ('Diproses', Icons.fact_check_outlined),
    ('Dijadwalkan', Icons.calendar_month_outlined),
    ('Ditindaklanjuti', Icons.health_and_safety_outlined),
    ('Selesai', Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Progres penanganan',
            subtitle: 'Tahapan laporan dari awal hingga selesai',
            icon: Icons.route_outlined,
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < _steps.length; index++) ...[
                  SizedBox(
                    width: 68,
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: index <= currentStepIndex
                                ? AppColors.primary
                                : const Color(0xFFE9ECEF),
                            shape: BoxShape.circle,
                            boxShadow: index == currentStepIndex
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.24,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _steps[index].$2,
                            color: index <= currentStepIndex
                                ? Colors.white
                                : AppColors.muted,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _steps[index].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: index <= currentStepIndex
                                ? AppColors.ink
                                : AppColors.muted,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: index == currentStepIndex
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < _steps.length - 1)
                    Container(
                      width: 22,
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 23),
                      decoration: BoxDecoration(
                        color: index < currentStepIndex
                            ? AppColors.primary
                            : const Color(0xFFE4E7E8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.ticket});

  final TicketStatus ticket;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      color: const Color(0xFFF8FBF9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Petugas & jadwal kunjungan',
            subtitle: 'Informasi tindak lanjut di lokasi',
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFE5F3EC),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.green,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Petugas Kesehatan Lingkungan',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket.officer?.trim().isNotEmpty == true
                          ? ticket.officer!
                          : 'Sanitarian',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 13),
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Jadwal kunjungan',
            value: ticket.visitDate?.trim().isNotEmpty == true
                ? ticket.visitDate!
                : 'Belum diinformasikan',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.assignment_outlined,
            label: 'Intervensi lapangan',
            value: ticket.intervention?.trim().isNotEmpty == true
                ? ticket.intervention!
                : 'Inspeksi Kesehatan Lingkungan (IKL)',
          ),
          if (ticket.visitStatus?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.info_outline,
              label: 'Status kunjungan',
              value: ticket.visitStatus!,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.ticket});

  final TicketStatus ticket;

  static const _titles = [
    'Dikirim',
    'Diproses',
    'Dijadwalkan',
    'Ditindaklanjuti',
    'Selesai',
  ];
  static const _descriptions = [
    'Laporan warga berhasil diterima oleh sistem.',
    'Admin Puskesmas melakukan verifikasi laporan.',
    'Jadwal kunjungan petugas sanitarian ditetapkan.',
    'Petugas melakukan IKL atau intervensi di lokasi.',
    'Pemeriksaan selesai dan rekomendasi sanitasi diterbitkan.',
  ];

  @override
  Widget build(BuildContext context) {
    final currentStep = ticket.currentStepIndex;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Riwayat status',
            subtitle: 'Catatan tahapan penanganan laporan',
            icon: Icons.history,
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < _titles.length; index++)
            _TimelineEntry(
              title: _titles[index],
              description: _descriptions[index],
              timestamp: _timestampFor(ticket, index),
              active: currentStep != null && index <= currentStep,
              current: currentStep == index,
              isLast: index == _titles.length - 1,
            ),
          if (ticket.isRejected)
            _TimelineEntry(
              title: 'Ditolak',
              description:
                  ticket.rejectionReason?.trim().isNotEmpty == true
                  ? ticket.rejectionReason!
                  : 'Laporan tidak dapat ditindaklanjuti.',
              timestamp: 'Status terbaru',
              active: true,
              current: true,
              isLast: true,
              rejected: true,
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.active,
    required this.current,
    required this.isLast,
    this.rejected = false,
  });

  final String title;
  final String description;
  final String timestamp;
  final bool active;
  final bool current;
  final bool isLast;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final color = rejected
        ? const Color(0xFFB42318)
        : active
        ? AppColors.primary
        : const Color(0xFFD8DCDE);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: current ? 13 : 10,
                  height: current ? 13 : 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: current
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.28),
                              blurRadius: 9,
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: active ? AppColors.primary : AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: active || current
                                ? AppColors.ink
                                : AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          timestamp,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({required this.ticket});

  final TicketStatus ticket;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: ticket.code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode tiket berhasil disalin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Rincian laporan',
            subtitle: 'Informasi laporan yang Anda kirim',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticket.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyCode(context),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Salin'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailRow(
            label: 'Nama pelapor',
            value: ticket.reporterName?.trim().isNotEmpty == true
                ? ticket.reporterName!
                : 'Warga',
          ),
          _DetailRow(
            label: 'Lokasi',
            value: '${ticket.village ?? '-'}, RT ${ticket.rt} / RW ${ticket.rw}',
          ),
          _DetailRow(label: 'Kategori', value: _categoryLabel(ticket.category)),
          _DetailRow(
            label: 'Deskripsi',
            value: ticket.description.trim().isNotEmpty
                ? ticket.description
                : '-',
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.ticket});

  final TicketStatus ticket;

  @override
  Widget build(BuildContext context) {
    final risk = ticket.riskCategory?.trim().isNotEmpty == true
        ? ticket.riskCategory!
        : 'Belum dicantumkan';
    final recommendation = ticket.recommendation?.trim().isNotEmpty == true
        ? ticket.recommendation!
        : 'Rekomendasi belum tersedia.';
    return _SectionCard(
      color: const Color(0xFFF5FAF7),
      borderColor: const Color(0xFFD9EADF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Hasil & Rekomendasi Sanitarian',
            subtitle: 'Ringkasan pemeriksaan lingkungan',
            icon: Icons.verified_user_outlined,
            iconColor: AppColors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'KATEGORI RISIKO AIR',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F3EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              risk,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SARAN PERBAIKAN',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recommendation,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedBanner extends StatelessWidget {
  const _RejectedBanner({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        border: Border.all(color: const Color(0xFFF4C7C4)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alasan penolakan',
                  style: TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason?.trim().isNotEmpty == true
                      ? reason!
                      : 'Alasan belum disampaikan.',
                  style: const TextStyle(
                    color: Color(0xFF7A271A),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.color = Colors.white,
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = AppColors.primary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.green),
        const SizedBox(width: 8),
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
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

class _EmptyTrackingState extends StatelessWidget {
  const _EmptyTrackingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: AppColors.softRed,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_searching_rounded,
            color: AppColors.primary,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Belum ada tiket yang dilacak',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Masukkan kode tiket laporan untuk melihat progres penanganannya.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

IconData _stepIcon(int? step) => switch (step) {
  0 => Icons.send_rounded,
  1 => Icons.fact_check_outlined,
  2 => Icons.calendar_month_outlined,
  3 => Icons.health_and_safety_outlined,
  4 => Icons.check_circle_outline,
  _ => Icons.track_changes_outlined,
};

(String, Color) _statusPresentation(String status) {
  return switch (status.trim().toLowerCase()) {
    'dikirim' => ('Dikirim', AppColors.primary),
    'menunggu' || 'diproses' || 'pending' => ('Diproses', AppColors.amber),
    'dijadwalkan' => ('Dijadwalkan', AppColors.primary),
    'ditindaklanjuti' => ('Ditindaklanjuti', AppColors.primary),
    'selesai' => ('Selesai', AppColors.green),
    'ditolak' => ('Ditolak', const Color(0xFFB42318)),
    _ => (status, AppColors.muted),
  };
}

String _timestampFor(TicketStatus ticket, int step) {
  return switch (step) {
    0 => ticket.createdAt ?? 'Waktu pengiriman',
    2 || 3 || 4 => ticket.visitDate ?? 'Belum tercatat',
    _ => ticket.currentStepIndex != null && step <= ticket.currentStepIndex!
        ? 'Sedang berlangsung'
        : 'Menunggu',
  };
}

String _categoryLabel(String category) {
  return switch (category) {
    'air_masalah' => 'Masalah air',
    'sanitasi_lingkungan' => 'Sanitasi lingkungan',
    _ => category,
  };
}
