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
  List<TicketStatus> _tickets = [];
  String? _selectedCode;
  bool _showCompleted = false;
  bool _isLoading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedCode = _normalizedCode(widget.initialTicketCode);
    if (_selectedCode != null) _ticketController.text = _selectedCode!;
    _loadHistory(preferredCode: _selectedCode);
  }

  @override
  void didUpdateWidget(covariant TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCode = _normalizedCode(oldWidget.initialTicketCode);
    final newCode = _normalizedCode(widget.initialTicketCode);
    if (newCode != null && newCode != oldCode) {
      _selectedCode = newCode;
      _ticketController.text = newCode;
      _loadHistory(preferredCode: newCode);
    }
  }

  String? _normalizedCode(String? code) {
    final normalized = code?.trim();
    return normalized == null || normalized.isEmpty
        ? null
        : normalized.toUpperCase();
  }

  @override
  void dispose() {
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({String? preferredCode}) async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final savedCodes = await widget.apiService.getSavedCitizenTicketCodes();
      if (preferredCode != null && !savedCodes.contains(preferredCode)) {
        await widget.apiService.saveCitizenTicketCode(preferredCode);
        savedCodes.insert(0, preferredCode);
      }
      final preferredCodes = preferredCode == null
          ? <String>[]
          : <String>[preferredCode];
      final codes = <String>[
        ...preferredCodes,
        ...savedCodes.where((code) => code != preferredCode),
      ];

      final cachedTickets = <TicketStatus>[];
      String? cacheError;
      for (final code in codes) {
        try {
          final cached = await widget.apiService.getCachedTicketStatus(code);
          if (cached != null) cachedTickets.add(cached);
        } on ApiException catch (error) {
          cacheError ??= error.message;
        }
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _tickets = cachedTickets;
        _error = cacheError;
      });

      final refreshedTickets = <TicketStatus>[];
      final refreshErrors = <String>[];
      for (final code in codes) {
        try {
          refreshedTickets.add(await widget.apiService.getTicket(code));
        } on ApiException catch (error) {
          refreshErrors.add(error.message);
        } on Exception catch (error) {
          refreshErrors.add(error.toString());
        }
      }
      if (!mounted || requestId != _requestId) return;

      final refreshedByCode = {
        for (final ticket in refreshedTickets) ticket.code: ticket,
      };
      final ticketsByCode = {
        for (final ticket in cachedTickets) ticket.code: ticket,
        ...refreshedByCode,
      };
      setState(() {
        _tickets = [
          for (final code in codes)
            if (ticketsByCode[code] != null) ticketsByCode[code]!,
        ];
        _error = refreshErrors.isEmpty
            ? null
            : 'Sebagian status belum dapat diperbarui: ${refreshErrors.first}';
      });
    } on ApiException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } on Exception catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Riwayat laporan tidak dapat dimuat: $error');
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchTicket() async {
    final code = _normalizedCode(_ticketController.text);
    if (code == null) {
      setState(() => _error = 'Masukkan kode tiket laporan.');
      return;
    }

    final requestId = ++_requestId;
    setState(() {
      _error = null;
      _selectedCode = code;
      _ticketController.text = code;
      _isLoading = true;
    });

    try {
      final ticket = await widget.apiService.getTicket(code);
      if (!mounted || requestId != _requestId) return;
      setState(() => _upsertTicket(ticket));
      await widget.apiService.saveCitizenTicketCode(code);
    } on ApiException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } on Exception catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Status tiket tidak dapat dimuat: $error');
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _upsertTicket(TicketStatus ticket) {
    _tickets = [
      ticket,
      ..._tickets.where((savedTicket) => savedTicket.code != ticket.code),
    ];
  }

  Future<void> _refresh() async {
    if (_selectedCode == null) {
      await _loadHistory();
      return;
    }

    final code = _selectedCode!;
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ticket = await widget.apiService.getTicket(code);
      if (mounted && requestId == _requestId) {
        setState(() => _upsertTicket(ticket));
      }
    } on ApiException catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.message);
      }
    } on Exception catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'Status tiket tidak dapat diperbarui: $error');
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTicket = _selectedCode == null
        ? null
        : _ticketForCode(_selectedCode!);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: selectedTicket != null || _selectedCode != null
            ? _buildTicketDetail(selectedTicket)
            : _buildHistory(),
      ),
    );
  }

  TicketStatus? _ticketForCode(String code) {
    for (final ticket in _tickets) {
      if (ticket.code == code) return ticket;
    }
    return null;
  }

  Widget _buildHistory() {
    final visibleTickets = _tickets
        .where((ticket) => ticket.isCompleted == _showCompleted)
        .toList();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Text(
            'Riwayat & Status Laporan',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pantau dan buka kembali laporan yang pernah Anda kirim.',
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
          const SizedBox(height: 20),
          _buildHistoryFilters(),
          const SizedBox(height: 14),
          if (_isLoading && _tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (visibleTickets.isEmpty)
            _EmptyTrackingState(hasHistory: _tickets.isNotEmpty)
          else
            for (final ticket in visibleTickets)
              _OrderHistoryCard(
                ticket: ticket,
                onTap: () => setState(() {
                  _selectedCode = ticket.code;
                  _ticketController.text = ticket.code;
                  _error = null;
                }),
              ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilters() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _HistoryFilter(
            title: 'Dalam Proses',
            selected: !_showCompleted,
            onTap: () => setState(() => _showCompleted = false),
          ),
          _HistoryFilter(
            title: 'Selesai / Riwayat',
            selected: _showCompleted,
            onTap: () => setState(() => _showCompleted = true),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketDetail(TicketStatus? ticket) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Kembali ke riwayat',
                onPressed: () => setState(() {
                  _selectedCode = null;
                  _error = null;
                }),
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              ),
              Expanded(
                child: Text(
                  'Status Laporan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Perbarui status',
                onPressed: _isLoading ? null : _refresh,
                icon: const Icon(Icons.refresh, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (ticket != null) ...[
            _TicketDetails(ticket: ticket),
          ] else if (_isLoading) ...[
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _MessagePanel(
              icon: Icons.info_outline,
              message: _error!,
              color: AppColors.primary,
            ),
          ],
        ],
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
        onSubmitted: (_) => _searchTicket(),
        decoration: InputDecoration(
          hintText: 'Cari kode tiket lain (TK-...)',
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.primary,
          ),
          suffixIcon: IconButton(
            tooltip: 'Cari tiket',
            onPressed: _isLoading ? null : _searchTicket,
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

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.ticket, required this.onTap});

  final TicketStatus ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(ticket.status);
    final progress = ticket.isRejected
        ? 'Laporan tidak dapat ditindaklanjuti'
        : switch (ticket.currentStepIndex) {
            0 => 'Laporan berhasil diterima sistem',
            1 => 'Laporan sedang diverifikasi',
            2 => 'Kunjungan petugas sedang dijadwalkan',
            3 => 'Petugas sedang melakukan pemeriksaan',
            4 => 'Pemeriksaan dan rekomendasi selesai',
            _ => 'Status laporan diperbarui',
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status.$2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.$1,
                        style: TextStyle(
                          color: status.$2,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_categoryLabel(ticket.category)} · ${ticket.village ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 13,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        ticket.createdAt ?? 'Tanggal laporan tidak tersedia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
                const SizedBox(height: 11),
                if (!ticket.isRejected)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: ((ticket.currentStepIndex ?? 0) + 1) / 5,
                      backgroundColor: AppColors.line,
                      color: AppColors.primary,
                    ),
                  ),
                if (ticket.isRejected) const SizedBox(height: 4),
                const SizedBox(height: 7),
                Text(
                  progress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
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
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
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
              description: ticket.rejectionReason?.trim().isNotEmpty == true
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
            value:
                '${ticket.village ?? '-'}, RT ${ticket.rt} / RW ${ticket.rw}',
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
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
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
  const _EmptyTrackingState({this.hasHistory = false});

  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    final title = hasHistory
        ? 'Tidak ada laporan di kategori ini'
        : 'Belum ada riwayat laporan';
    const description =
        'Kode tiket laporan yang pernah dikirim akan tersimpan dan tampil di sini.';
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
        Text(
          title,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          description,
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
    _ =>
      ticket.currentStepIndex != null && step <= ticket.currentStepIndex!
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
