import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../models/ticket_status.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page_header.dart';

class TrackingView extends StatefulWidget {
  const TrackingView({
    super.key,
    required this.apiService,
    this.initialTicketCode,
    this.isActive = true,
    this.onOpenReport,
  });

  final ApiService apiService;
  final String? initialTicketCode;
  final bool isActive;
  final VoidCallback? onOpenReport;

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

String _reportCodeKey(String code) => code.trim().toUpperCase();

enum _ReportDateFilter { all, today, last7Days, last30Days, custom }

class _TrackingViewState extends State<TrackingView> {
  final _ticketController = TextEditingController();
  final _scrollController = ScrollController();
  List<TicketStatus> _tickets = [];
  String? _selectedCode;
  String? _selectedStatus;
  _ReportDateFilter _selectedDateFilter = _ReportDateFilter.all;
  DateTimeRange? _customDateRange;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _loadMoreError;
  int _currentPage = 1;
  int _lastPage = 1;
  int _requestId = 0;
  static const _perPage = 10;

  static const _reportStatuses = <(String, String)>[
    ('dikirim', 'Dikirim'),
    ('menunggu', 'Menunggu'),
    ('diproses', 'Diproses'),
    ('dijadwalkan', 'Dijadwalkan'),
    ('ditindaklanjuti', 'Ditindaklanjuti'),
    ('selesai', 'Selesai'),
    ('ditolak', 'Ditolak'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _selectedCode = _normalizedCode(widget.initialTicketCode);
    if (_selectedCode != null) _ticketController.text = _selectedCode!;
    if (widget.isActive) _loadHistory(preferredCode: _selectedCode);
  }

  @override
  void didUpdateWidget(covariant TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCode = _normalizedCode(oldWidget.initialTicketCode);
    final newCode = _normalizedCode(widget.initialTicketCode);
    if (newCode != null && newCode != oldCode) {
      _selectedCode = newCode;
      _ticketController.text = newCode;
      if (widget.isActive) _loadHistory(preferredCode: newCode);
      return;
    }
    if (widget.isActive && !oldWidget.isActive) _refresh();
  }

  String? _normalizedCode(String? code) {
    final normalized = code?.trim();
    return normalized == null || normalized.isEmpty
        ? null
        : normalized.toUpperCase();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _ticketController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({String? preferredCode}) async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _isRefreshing = false;
      _isSearching = false;
      _isLoadingMore = false;
      _tickets = [];
      _currentPage = 1;
      _lastPage = 1;
      _error = null;
      _loadMoreError = null;
    });

    try {
      final dateRange = _selectedDateRange;
      if (dateRange != null && dateRange.start.isAfter(dateRange.end)) {
        throw const ApiException(
          'Tanggal mulai tidak boleh melebihi tanggal akhir.',
        );
      }

      final page = await widget.apiService.getCitizenReportsPage(
        page: 1,
        perPage: _perPage,
        status: _selectedStatus,
        startDate: dateRange == null ? null : _formatDate(dateRange.start),
        endDate: dateRange == null ? null : _formatDate(dateRange.end),
      );
      final reportsByCode = <String, TicketStatus>{
        for (final report in page.reports) _reportCodeKey(report.code): report,
      };
      if (preferredCode != null &&
          !reportsByCode.containsKey(_reportCodeKey(preferredCode))) {
        final ticket = await widget.apiService.getTicket(preferredCode);
        reportsByCode[_reportCodeKey(ticket.code)] = ticket;
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _tickets = reportsByCode.values.toList(growable: false);
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
      _scheduleLoadIfNearBottom();
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = _loadErrorMessage(error, hasCachedData: false));
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTimeRange? get _selectedDateRange {
    final today = DateUtils.dateOnly(DateTime.now());
    return switch (_selectedDateFilter) {
      _ReportDateFilter.all => null,
      _ReportDateFilter.today => DateTimeRange(start: today, end: today),
      _ReportDateFilter.last7Days => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _ReportDateFilter.last30Days => DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      _ReportDateFilter.custom => _customDateRange,
    };
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _handleScroll() {
    if (_selectedCode != null ||
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter > 300) {
      return;
    }
    _loadNextPage();
  }

  void _scheduleLoadIfNearBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _selectedCode == null &&
          _scrollController.hasClients &&
          _scrollController.position.extentAfter <= 300) {
        _loadNextPage();
      }
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoading ||
        _isLoadingMore ||
        _currentPage >= _lastPage ||
        _selectedCode != null) {
      return;
    }
    final requestId = _requestId;
    final nextPage = _currentPage + 1;
    final dateRange = _selectedDateRange;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final page = await widget.apiService.getCitizenReportsPage(
        page: nextPage,
        perPage: _perPage,
        status: _selectedStatus,
        startDate: dateRange == null ? null : _formatDate(dateRange.start),
        endDate: dateRange == null ? null : _formatDate(dateRange.end),
      );
      if (!mounted || requestId != _requestId) return;
      final knownCodes = _tickets
          .map((ticket) => _reportCodeKey(ticket.code))
          .toSet();
      setState(() {
        _tickets = [
          ..._tickets,
          for (final report in page.reports)
            if (knownCodes.add(_reportCodeKey(report.code))) report,
        ];
        _currentPage = page.currentPage;
        _lastPage = page.lastPage;
      });
      _scheduleLoadIfNearBottom();
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _loadMoreError = error.toString());
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _selectDateFilter(_ReportDateFilter filter) async {
    if (filter != _ReportDateFilter.custom) {
      setState(() => _selectedDateFilter = filter);
      await _loadHistory();
      return;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final initial =
        _customDateRange ??
        DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: initial,
      helpText: 'Pilih rentang tanggal laporan',
      saveText: 'Terapkan',
      cancelText: 'Batal',
    );
    if (range == null || !mounted) return;
    final start = DateUtils.dateOnly(range.start);
    final end = DateUtils.dateOnly(range.end);
    if (start.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal mulai tidak boleh melebihi tanggal akhir.'),
        ),
      );
      return;
    }
    setState(() {
      _customDateRange = DateTimeRange(start: start, end: end);
      _selectedDateFilter = _ReportDateFilter.custom;
    });
    await _loadHistory();
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedStatus = null;
      _selectedDateFilter = _ReportDateFilter.all;
      _customDateRange = null;
    });
    await _loadHistory();
  }

  String _loadErrorMessage(Object error, {required bool hasCachedData}) {
    if (!hasCachedData) {
      return 'Gagal memuat data dari server. Periksa koneksi Wi-Fi Anda.';
    }
    final detail = error is ApiException ? error.message : error.toString();
    return 'Sebagian status belum dapat diperbarui: $detail';
  }

  Future<void> _searchTicket() async {
    if (_isSearching) return;
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
      _isLoading = _ticketForCode(code) == null;
      _isRefreshing = false;
      _isSearching = true;
    });

    try {
      final cachedTicket = await widget.apiService.getCachedTicketStatus(code);
      if (cachedTicket != null && mounted && requestId == _requestId) {
        setState(() {
          _upsertTicket(cachedTicket);
          _isLoading = false;
        });
      }
      final ticket = await widget.apiService.getTicket(code);
      if (!mounted || requestId != _requestId) return;
      setState(() => _upsertTicket(ticket));
      await widget.apiService.saveCitizenTicketCode(code);
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(
          () => _error = _loadErrorMessage(
            error,
            hasCachedData: _ticketForCode(code) != null,
          ),
        );
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _isLoading = false;
          _isSearching = false;
        });
      }
    }
  }

  void _upsertTicket(TicketStatus ticket) {
    _tickets = [
      ticket,
      ..._tickets.where(
        (savedTicket) =>
            _reportCodeKey(savedTicket.code) != _reportCodeKey(ticket.code),
      ),
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
      _isLoading = _ticketForCode(code) == null;
      _isRefreshing = true;
      _isSearching = false;
      _error = null;
    });
    try {
      final ticket = await widget.apiService.getTicket(code);
      if (mounted && requestId == _requestId) {
        setState(() => _upsertTicket(ticket));
      }
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(
          () => _error = _loadErrorMessage(
            error,
            hasCachedData: _ticketForCode(code) != null,
          ),
        );
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
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
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: selectedTicket != null || _selectedCode != null
                ? _buildTicketDetail(selectedTicket)
                : _buildHistory(),
          ),
        ),
      ),
    );
  }

  TicketStatus? _ticketForCode(String code) {
    for (final ticket in _tickets) {
      if (_reportCodeKey(ticket.code) == _reportCodeKey(code)) return ticket;
    }
    return null;
  }

  Widget _buildHistory() {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 380
        ? 12.0
        : 18.0;
    final header = <Widget>[
      AppPageHeader(
        key: const Key('tracking_history_header'),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.viewPaddingOf(context).top + 4,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            const SizedBox(height: 14),
            Text(
              'Lacak laporan',
              style: TextStyle(
                fontFamily: AppTheme.headlineFontFamily,
                color: Colors.white,
                fontSize: 26,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pantau perkembangan laporan sanitasi Anda.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      if (_isRefreshing)
        const LinearProgressIndicator(
          key: Key('tracking_refresh_indicator'),
          minHeight: 2,
          color: AppColors.primary,
        ),
      Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          18,
          horizontalPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchBar(),
            if (_error != null && _tickets.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MessagePanel(
                icon: Icons.info_outline,
                message: _error!,
                color: AppColors.primary,
                onRetry: _loadHistory,
              ),
            ],
            const SizedBox(height: 20),
            _buildHistoryFilters(),
            const SizedBox(height: 14),
          ],
        ),
      ),
    ];
    final emptyState = _error != null && _tickets.isEmpty
        ? _TrackingNetworkError(onRetry: _loadHistory)
        : _isLoading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        : _EmptyTrackingState(
            hasHistory: _tickets.isNotEmpty,
            onOpenReport: widget.onOpenReport,
          );
    final hasFooter =
        _tickets.isNotEmpty &&
        (_currentPage < _lastPage || _isLoadingMore || _loadMoreError != null);
    final contentCount = _tickets.isEmpty
        ? 1
        : _tickets.length + (hasFooter ? 1 : 0);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: header.length + contentCount,
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          if (_tickets.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: emptyState,
            );
          }
          final itemIndex = index - header.length;
          if (itemIndex == _tickets.length) {
            if (_loadMoreError != null) {
              return Center(
                child: TextButton.icon(
                  key: const Key('tracking_load_more_retry'),
                  onPressed: _loadNextPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Gagal memuat. Coba lagi'),
                ),
              );
            }
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('tracking_load_more_indicator'),
                    color: AppColors.primary,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          final ticket = _tickets[itemIndex];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: _OrderHistoryCard(
              ticket: ticket,
              onTap: () => setState(() {
                _selectedCode = ticket.code;
                _ticketController.text = ticket.code;
                _error = null;
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryFilters() {
    final dateRange = _selectedDateRange;
    final hasActiveFilters =
        _selectedStatus != null || _selectedDateFilter != _ReportDateFilter.all;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  key: const Key('tracking_status_filter'),
                  value: _selectedStatus ?? '',
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.expand_more_rounded),
                  style: const TextStyle(color: AppColors.ink, fontSize: 13),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Semua status'),
                    ),
                    for (final (value, label) in _reportStatuses)
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (value) async {
                    setState(
                      () => _selectedStatus = value == null || value.isEmpty
                          ? null
                          : value,
                    );
                    await _loadHistory();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  key: const Key('tracking_date_filter'),
                  value: _selectedDateFilter.name,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.expand_more_rounded),
                  style: const TextStyle(color: AppColors.ink, fontSize: 13),
                  items: [
                    for (final filter in _ReportDateFilter.values)
                      DropdownMenuItem(
                        value: filter.name,
                        child: Text(
                          _dateFilterLabel(filter, dateRange),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _selectDateFilter(
                      _ReportDateFilter.values.firstWhere(
                        (filter) => filter.name == value,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (hasActiveFilters)
            Row(
              children: [
                const Icon(
                  Icons.filter_alt_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Filter aktif',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
                TextButton(
                  key: const Key('tracking_reset_filters'),
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Reset filter'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _dateFilterLabel(_ReportDateFilter filter, DateTimeRange? dateRange) {
    return switch (filter) {
      _ReportDateFilter.all => 'Semua tanggal',
      _ReportDateFilter.today => 'Hari ini',
      _ReportDateFilter.last7Days => '7 hari terakhir',
      _ReportDateFilter.last30Days => '30 hari terakhir',
      _ReportDateFilter.custom when dateRange != null =>
        '${_formatShortDate(dateRange.start)} - '
            '${_formatShortDate(dateRange.end)}',
      _ReportDateFilter.custom => 'Rentang khusus',
    };
  }

  String _formatShortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Widget _buildTicketDetail(TicketStatus? ticket) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 380
        ? 12.0
        : 18.0;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          AppPageHeader(
            key: const Key('tracking_detail_header'),
            padding: EdgeInsets.fromLTRB(
              10,
              MediaQuery.viewPaddingOf(context).top + 4,
              10,
              26,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Kembali ke riwayat',
                  onPressed: () => setState(() {
                    _selectedCode = null;
                    _error = null;
                  }),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Laporan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (_selectedCode != null)
                        Text(
                          _selectedCode!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Perbarui status',
                  onPressed: _isLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
          if (_isRefreshing)
            const LinearProgressIndicator(
              key: Key('tracking_refresh_indicator'),
              minHeight: 2,
              color: AppColors.primary,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ticket != null) ...[
                  _TicketDetails(ticket: ticket),
                ] else if (_isLoading) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _MessagePanel(
                    icon: Icons.info_outline,
                    message: _error!,
                    color: AppColors.primary,
                    onRetry: _refresh,
                  ),
                ],
              ],
            ),
          ),
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
            onPressed: _isSearching ? null : _searchTicket,
            icon: _isSearching
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
                          fontWeight: FontWeight.w400,
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
                          fontWeight: FontWeight.w400,
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
                    fontWeight: FontWeight.w400,
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
        if (!ticket.isRejected && ticket.isCompleted) ...[
          const SizedBox(height: 14),
          _RecommendationCard(ticket: ticket),
        ],
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
        if (!ticket.isRejected && !ticket.isCompleted) ...[
          const SizedBox(height: 14),
          _RecommendationCard(ticket: ticket),
        ],
        const SizedBox(height: 14),
        _TimelineCard(ticket: ticket),
        const SizedBox(height: 14),
        _ReportSummaryCard(ticket: ticket),
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
            3 =>
              'Petugas sedang melakukan pemeriksaan dan tindakan penanganan.',
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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
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
                    fontWeight: FontWeight.w400,
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
                    fontWeight: FontWeight.w400,
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
                      fontWeight: FontWeight.w400,
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
                                ? FontWeight.w400
                                : FontWeight.w400,
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
                      'Petugas Puskesmas',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket.officer?.trim().isNotEmpty == true
                          ? ticket.officer!
                          : 'Petugas',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            ticket.code,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: AppTheme.headlineFontFamily,
              fontWeight: FontWeight.w400,
              height: 1.25,
              letterSpacing: -0.16,
            ),
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
            label: 'Tindakan Petugas',
            value: ticket.intervention?.trim().isNotEmpty == true
                ? ticket.intervention!
                : 'Pemeriksaan',
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
    'Jadwal kunjungan petugas ditetapkan.',
    'Petugas sedang melakukan pemeriksaan dan tindakan penanganan di lokasi.',
    'Pemeriksaan selesai dan rekomendasi diterbitkan.',
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
                            fontWeight: FontWeight.w400,
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
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: ValueKey(ticket.isCompleted),
          initiallyExpanded: !ticket.isCompleted,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const _SectionHeading(
            title: 'Rincian Laporan Awal',
            subtitle: 'Informasi laporan yang Anda kirim',
            icon: Icons.receipt_long_outlined,
          ),
          children: [
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
                        fontWeight: FontWeight.w400,
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
            _DetailRow(
              label: 'Kategori',
              value: _categoryLabel(ticket.category),
            ),
            _DetailRow(
              label: 'Deskripsi',
              value: ticket.description.trim().isNotEmpty
                  ? ticket.description
                  : '-',
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.ticket});

  final TicketStatus ticket;

  @override
  Widget build(BuildContext context) {
    final hasResult = ticket.hasInspectionResult;
    final color = hasResult
        ? switch (ticket.riskLabel) {
            'Aman' => AppColors.green,
            'Sedang' => AppColors.orange,
            'Tinggi' => const Color(0xFFE53935),
            _ => AppColors.muted,
          }
        : AppColors.muted;
    return _SectionCard(
      color: color.withValues(alpha: 0.04),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        key: const Key('citizen_inspection_result'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: 'Hasil Pemeriksaan Petugas',
            subtitle: 'Hasil pemeriksaan pada laporan ini',
            icon: Icons.health_and_safety_outlined,
            iconColor: color,
          ),
          const SizedBox(height: 16),
          if (!hasResult)
            Text(
              ticket.status.toLowerCase() == 'selesai'
                  ? 'Hasil pemeriksaan belum tersedia. Tarik halaman untuk memperbarui.'
                  : 'Menunggu hasil pemeriksaan petugas.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket.riskLabel,
                    key: const Key('citizen_risk_label'),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
                if (ticket.riskScore != null)
                  Text(
                    'Skor: ${ticket.riskScore} dari 5',
                    key: const Key('citizen_risk_score'),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Tanggal pemeriksaan',
              value: ticket.inspectionDate ?? 'Belum dicantumkan',
            ),
            if (ticket.officer?.trim().isNotEmpty == true)
              _DetailRow(label: 'Petugas', value: ticket.officer!),
            if (ticket.intervention?.trim().isNotEmpty == true)
              _DetailRow(
                label: 'Tindakan Petugas',
                value: ticket.intervention!,
              ),
            const Text(
              'Rekomendasi Petugas',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ticket.recommendation?.trim().isNotEmpty == true
                  ? ticket.recommendation!
                  : 'Rekomendasi belum tersedia.',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
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
                    fontWeight: FontWeight.w400,
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
                  fontFamily: AppTheme.headlineFontFamily,
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w400,
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
                fontWeight: FontWeight.w400,
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
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Future<void> Function() onRetry;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: color)),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba Lagi'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    visualDensity: VisualDensity.compact,
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

class _EmptyTrackingState extends StatelessWidget {
  const _EmptyTrackingState({this.hasHistory = false, this.onOpenReport});

  final bool hasHistory;
  final VoidCallback? onOpenReport;

  @override
  Widget build(BuildContext context) {
    final title = hasHistory
        ? 'Tidak ada laporan di kategori ini'
        : 'Belum ada riwayat laporan';
    const description =
        'Laporan yang dikirim dari akun ini akan tampil di sini.';
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
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
        if (!hasHistory && onOpenReport != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenReport,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Lapor Sekarang'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

class _TrackingNetworkError extends StatelessWidget {
  const _TrackingNetworkError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 44),
        const SizedBox(height: 12),
        const Text(
          'Gagal memuat data dari server. Periksa koneksi Wi-Fi Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
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
    'menunggu' || 'pending' => ('Menunggu', AppColors.amber),
    'diproses' || 'proses' || 'dalam_proses' => ('Diproses', AppColors.primary),
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
