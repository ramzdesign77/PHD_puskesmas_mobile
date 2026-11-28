import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/officer_dashboard_data.dart';
import '../../models/risk_score.dart';
import '../../models/visit_schedule.dart';
import '../../services/api_service.dart';
import '../../services/officer_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocean_widgets.dart';
import '../profile/profile_view.dart';
import 'officer_detail_view.dart';
import 'widgets/visit_card_widget.dart';
import '../../widgets/fluid_bottom_nav.dart';

const _canvasWhite = Color(0xFFF8FAFC);

class OfficerDashboardView extends StatefulWidget {
  const OfficerDashboardView({
    super.key,
    required this.token,
    required this.officerName,
    required this.apiService,
  });

  final String token;
  final String officerName;
  final OfficerApiService apiService;

  @override
  State<OfficerDashboardView> createState() => _OfficerDashboardViewState();
}

class _OfficerDashboardViewState extends State<OfficerDashboardView> {
  int _selectedTab = 0;
  String _taskFilter = 'semua_aktif';
  final TextEditingController _taskSearchController = TextEditingController();
  String _taskSearch = '';
  final TextEditingController _historySearchController =
      TextEditingController();
  String _historySearch = '';
  String _riskFilter = 'semua';
  List<VisitSchedule> _schedules = const [];
  OfficerDashboardData? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;
  String? _dashboardWarning;
  String? _localProfileName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _taskSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _dashboardWarning = null;
      });
    }

    OfficerDashboardData? dashboard;
    List<VisitSchedule>? schedules;
    Object? dashboardError;
    Object? taskError;
    try {
      dashboard = await widget.apiService.getDashboard(widget.token);
    } catch (error) {
      dashboardError = error;
    }
    try {
      schedules = await widget.apiService.fetchTasks(
        token: widget.token,
        filter: 'semua',
      );
    } catch (error) {
      taskError = error;
    }

    if (!mounted) return;
    var loadedSchedules = schedules ?? const <VisitSchedule>[];
    if (loadedSchedules.isEmpty && dashboard?.schedules.isNotEmpty == true) {
      loadedSchedules = dashboard!.schedules;
    } else if (loadedSchedules.isNotEmpty &&
        dashboard?.schedules.isNotEmpty == true) {
      final merged = <VisitSchedule>[...loadedSchedules];
      final keys = {
        for (final item in loadedSchedules)
          '${item.isInspection}:${item.scheduleId ?? item.id}:${item.status}:${item.category}:${item.reporterName}',
      };
      for (final item in dashboard!.schedules) {
        final key =
            '${item.isInspection}:${item.scheduleId ?? item.id}:${item.status}:${item.category}:${item.reporterName}';
        if (keys.add(key)) merged.add(item);
      }
      loadedSchedules = merged;
    }
    setState(() {
      _dashboard = dashboard;
      _schedules = loadedSchedules;
      _isLoading = false;
      if (schedules == null && dashboard == null) {
        _errorMessage =
            taskError?.toString() ??
            dashboardError?.toString() ??
            'Data petugas tidak dapat dimuat.';
      } else if (dashboardError != null) {
        _dashboardWarning =
            'Ringkasan belum tersedia. Daftar tugas tetap dapat digunakan.';
      }
    });
  }

  List<VisitSchedule> get _activeTasks => _schedules
      .where((schedule) => !_isFinished(schedule.status))
      .toList(growable: false);

  List<VisitSchedule> get _completedTasks => _schedules
      .where(
        (schedule) =>
            schedule.isInspection &&
            schedule.status.trim().toLowerCase() == 'selesai',
      )
      .toList(growable: false);

  List<VisitSchedule> get _todayInspections => _schedules
      .where(
        (schedule) =>
            schedule.isInspection &&
            !_isFinished(schedule.status) &&
            _isScheduledTask(schedule) &&
            schedule.visitDate.startsWith(_todayDate),
      )
      .toList(growable: false);

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  int get _pendingReportCount =>
      _dashboard?.summary.newReportsCount ??
      _schedules
          .where((schedule) => !schedule.isInspection && _isNewReport(schedule))
          .length;

  int get _todayInspectionCount =>
      _dashboard?.summary.todayInspectionsCount ?? _todayInspections.length;

  int get _completedTodayCount =>
      _dashboard?.summary.completedCount ??
      _schedules
          .where(
            (schedule) =>
                schedule.status.toLowerCase() == 'selesai' &&
                (!schedule.isInspection ||
                    schedule.visitDate.startsWith(_todayDate)),
          )
          .length;

  List<VisitSchedule> get _upcomingInspections {
    final tasks =
        _activeTasks
            .where(
              (schedule) => schedule.isInspection && _isScheduledTask(schedule),
            )
            .toList()
          ..sort((first, second) {
            final firstDate = first.visitDate;
            final secondDate = second.visitDate;
            final firstRank = firstDate.startsWith(_todayDate)
                ? 0
                : firstDate.compareTo(_todayDate) > 0
                ? 1
                : 2;
            final secondRank = secondDate.startsWith(_todayDate)
                ? 0
                : secondDate.compareTo(_todayDate) > 0
                ? 1
                : 2;
            final rankComparison = firstRank.compareTo(secondRank);
            if (rankComparison != 0) return rankComparison;
            if (firstDate == '-') return 1;
            if (secondDate == '-') return -1;
            return firstDate.compareTo(secondDate);
          });
    return tasks.take(5).toList(growable: false);
  }

  List<VisitSchedule> get _recentReports {
    final reports =
        _schedules.where((schedule) => !schedule.isInspection).toList()
          ..sort((first, second) {
            final firstPending = _isNewReport(first) ? 0 : 1;
            final secondPending = _isNewReport(second) ? 0 : 1;
            return firstPending.compareTo(secondPending);
          });
    return reports.take(5).toList(growable: false);
  }

  String get _displayName {
    if (_localProfileName != null) return _localProfileName!;
    final name = _dashboard?.profile.name.trim();
    return name == null || name.isEmpty ? widget.officerName : name;
  }

  String get _greetingName {
    var name = _displayName.trim();
    name = name.replaceFirst(RegExp(r'^Petugas\s+', caseSensitive: false), '');
    return name.isEmpty ? 'Kesling' : name;
  }

  Future<void> _openDetail(VisitSchedule schedule) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => OfficerDetailView(
          schedule: schedule,
          token: widget.token,
          apiService: widget.apiService,
        ),
      ),
    );
    if (result == true) {
      await _loadData();
      return;
    }
    if (result is! VisitSchedule || !mounted) return;
    final updated = result;
    setState(() {
      final index = _schedules.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _schedules[index] = updated;
    });
  }

  Future<void> _openHistoryDetail(VisitSchedule schedule) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OfficerDetailView(
          schedule: schedule,
          token: widget.token,
          apiService: widget.apiService,
          readOnly: true,
        ),
      ),
    );
  }

  void _openTodayScheduleTab() {
    setState(() {
      _taskFilter = 'terjadwal_hari_ini';
      _selectedTab = 1;
    });
  }

  void _openNewReportsTab() {
    setState(() {
      _taskFilter = 'aduan_baru';
      _selectedTab = 1;
    });
  }

  void _startNearestVisit() {
    final today = _todayInspections;
    if (today.length == 1) {
      _openDetail(today.single);
    } else {
      _openTodayScheduleTab();
    }
  }

  Future<void> _verify(VisitSchedule schedule) async {
    try {
      await widget.apiService.verifyReport(
        token: widget.token,
        reportId: schedule.id,
      );
      if (!mounted) return;
      setState(() {
        final index = _schedules.indexWhere((item) => item.id == schedule.id);
        if (index >= 0) {
          _schedules[index] = _schedules[index].copyWith(status: 'diproses');
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aduan berhasil diverifikasi.')),
      );
    } on ApiOfficerException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('Verifikasi aduan gagal: $error', isError: true);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu login kembali untuk melanjutkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    String? logoutError;
    try {
      await widget.apiService.logoutOfficer(widget.token);
    } catch (error) {
      logoutError = error.toString();
    }
    try {
      await ApiService.clearSavedSession();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Token sesi tidak dapat dihapus dari perangkat: $error',
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    if (logoutError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sesi lokal dihapus. Logout server gagal: $logoutError',
          ),
        ),
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primaryDark : AppColors.green,
      ),
    );
  }

  void _selectTab(int tab) => setState(() => _selectedTab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      _buildTasksTab(),
      _buildHistoryTab(),
      _buildProfileTab(),
    ];
    return Scaffold(
      backgroundColor: _canvasWhite,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedTab,
          children: [
            for (var index = 0; index < pages.length; index++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                opacity: index == _selectedTab ? 1 : 0,
                child: pages[index],
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: FluidBottomNav(
            selectedIndex: _selectedTab,
            onDestinationSelected: _selectTab,
            showLabels: true,
            destinations: const [
              FluidNavDestination(
                label: 'Beranda',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
              ),
              FluidNavDestination(
                label: 'Jadwal',
                icon: Icons.event_note_rounded,
                selectedIcon: Icons.assignment_rounded,
              ),
              FluidNavDestination(
                label: 'Riwayat',
                icon: Icons.history_rounded,
                selectedIcon: Icons.fact_check_rounded,
              ),
              FluidNavDestination(
                label: 'Profil',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHome() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView(
        key: const Key('officer_home_list'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          120 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _buildHeroCard(),
          if (_dashboardWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _dashboardWarning!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          _buildSectionTitle(
            'Ringkasan Aktivitas',
            subtitle: 'Ringkasan Tugas Lapangan Hari Ini:',
            actionLabel: 'Data STBM',
            onAction: _showStbmSummary,
          ),
          const SizedBox(height: 12),
          _buildStatsCard(),
          const SizedBox(height: 26),
          _buildSectionTitle(
            'Tugas IKL Mendatang',
            subtitle: 'Jadwal inspeksi yang perlu ditindaklanjuti.',
            actionLabel: 'Semua jadwal',
            onAction: _openTodayScheduleTab,
          ),
          const SizedBox(height: 12),
          _buildUpcomingCarousel(),
          const SizedBox(height: 26),
          _buildSectionTitle(
            'Laporan Warga Terbaru',
            subtitle: 'Aduan yang menunggu verifikasi petugas.',
            actionLabel: 'Lihat semua',
            onAction: _openNewReportsTab,
          ),
          const SizedBox(height: 12),
          _buildReportHighlights(),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      key: const Key('officer_header_background'),
      height: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0369A1),
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _WaterMapPainter()),
            ),
            Positioned(
              right: -8,
              top: 24,
              child: Icon(
                Icons.water_drop_rounded,
                size: 144,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Positioned(right: 94, top: 28, child: _HeaderBubble(size: 36)),
            Positioned(right: 24, bottom: 86, child: _HeaderBubble(size: 54)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF082F49).withValues(alpha: 0.48),
                    const Color(0xFF082F49).withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 21, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.health_and_safety_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'KLINIK SANITASI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Halo, Petugas $_greetingName',
                      key: const Key('officer_greeting'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.headlineFontFamily,
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Siap untuk jadwal inspeksi hari ini?',
                      style: TextStyle(
                        color: Color(0xEFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 9,
                      runSpacing: 8,
                      children: [
                        _HeroActionButton(
                          label: 'Jadwal Hari Ini',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _startNearestVisit,
                        ),
                        _HeroActionButton(
                          label: 'Lihat Jadwal',
                          icon: Icons.calendar_month_outlined,
                          outlined: true,
                          onPressed: _openTodayScheduleTab,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.headlineFontFamily,
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              minimumSize: const Size(0, 34),
              shape: const StadiumBorder(),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final stats = [
      (Icons.report_gmailerrorred_rounded, _pendingReportCount, 'Aduan\nBaru'),
      (Icons.today_outlined, _todayInspectionCount, 'Jadwal Hari\nIni'),
      (Icons.task_alt_rounded, _completedTodayCount, 'Selesai'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 15, 8, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < stats.length; index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 72,
                color: AppColors.line.withValues(alpha: 0.8),
              ),
            Expanded(
              child: _DashboardStat(
                icon: stats[index].$1,
                count: stats[index].$2,
                label: stats[index].$3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingCarousel() {
    if (_isLoading) {
      return const SizedBox(
        height: 202,
        child: Center(child: WaterLoadingIndicator()),
      );
    }
    if (_errorMessage != null) {
      return SizedBox(height: 190, child: _buildError(_errorMessage!));
    }
    final tasks = _upcomingInspections;
    if (tasks.isEmpty) {
      return _DashboardEmptyCard(
        icon: Icons.water_drop_outlined,
        title: 'Belum ada jadwal IKL',
        message: 'Jadwal inspeksi mendatang akan tampil di sini.',
        height: 164,
      );
    }
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 6, right: 4),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _InspectionTaskCard(
            schedule: task,
            onTap: () => _openDetail(task),
            showQuickAction:
                index == 0 && task.visitDate.startsWith(_todayDate),
          );
        },
      ),
    );
  }

  Widget _buildReportHighlights() {
    final reports = _recentReports;
    return SizedBox(
      height: 195,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 5, right: 4),
        itemCount: reports.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ReportCalloutCard(
              reportCount: _pendingReportCount,
              onTap: _openNewReportsTab,
            );
          }
          final report = reports[index - 1];
          return _ReportSummaryCard(
            schedule: report,
            onTap: () => _openDetail(report),
            onVerify: _isNewReport(report) ? () => _verify(report) : null,
          );
        },
      ),
    );
  }

  Widget _buildTasksTab() {
    return _buildListPage(
      title: 'Jadwal',
      description: 'Tugas aktif yang perlu ditindaklanjuti petugas.',
    );
  }

  Widget _buildListPage({required String title, required String description}) {
    final visibleTasks = _activeTasks
        .where(_matchesTaskFilter)
        .where(_matchesTaskSearch)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: title,
          description: description,
          onRefresh: _loadData,
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children:
                      const [
                            ('semua_aktif', 'Semua Aktif'),
                            ('aduan_baru', 'Aduan Baru'),
                            ('terjadwal_hari_ini', 'Terjadwal Hari Ini'),
                            ('mendatang', 'Mendatang'),
                          ]
                          .map((item) {
                            final selected = _taskFilter == item.$1;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(item.$2),
                                selected: selected,
                                showCheckmark: false,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.muted,
                                  fontFamily: AppTheme.bodyFontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                onSelected: (_) =>
                                    setState(() => _taskFilter = item.$1),
                              ),
                            );
                          })
                          .toList(growable: false),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _taskSearchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama, desa, kategori, atau tiket',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _taskSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _taskSearchController.clear();
                            setState(() => _taskSearch = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                ),
                onChanged: (value) => setState(() {
                  _taskSearch = value;
                }),
              ),
            ),
          ],
        ),
        if (_isLoading)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Memuat jadwal aktif...',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_errorMessage != null)
          Expanded(child: Center(child: _buildError(_errorMessage!)))
        else if (visibleTasks.isEmpty)
          Expanded(
            child: Center(
              child: WaterEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum ada jadwal aktif',
                message: _activeTasks.isNotEmpty
                    ? 'Tidak ada jadwal untuk filter yang dipilih.'
                    : 'Aduan baru dan jadwal kunjungan aktif akan tampil di sini.',
              ),
            ),
          )
        else
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: RefreshIndicator(
                key: ValueKey('tasks-$_taskFilter'),
                color: AppColors.primary,
                onRefresh: _loadData,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    120 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  itemCount: visibleTasks.length,
                  itemBuilder: (_, index) {
                    final task = visibleTasks[index];
                    return VisitCardWidget(
                      schedule: task,
                      onTap: () => _openDetail(task),
                      onAction: _isNewReport(task)
                          ? () => _verify(task)
                          : () => _openDetail(task),
                      actionLabel: _isNewReport(task)
                          ? 'Verifikasi & Jadwalkan'
                          : _isScheduledTask(task)
                          ? 'Buka Peta & Isi IKL'
                          : 'Lihat Detail Aduan',
                      isInspection: task.isInspection,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _matchesTaskSearch(VisitSchedule task) {
    final query = _taskSearch.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      task.reporterName,
      task.category,
      task.description,
      task.village,
      task.address,
      task.ticketCode,
      task.rt,
      task.rw,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  bool _matchesTaskFilter(VisitSchedule task) {
    return switch (_taskFilter) {
      'aduan_baru' => _isNewReport(task),
      'terjadwal_hari_ini' =>
        _isScheduledTask(task) && task.visitDate.startsWith(_todayDate),
      'mendatang' =>
        _isScheduledTask(task) && task.visitDate.compareTo(_todayDate) > 0,
      _ => true,
    };
  }

  Widget _buildHistoryTab() {
    final completed = [..._completedTasks]
      ..sort((first, second) {
        final firstDate = first.inspectionDate ?? first.visitDate;
        final secondDate = second.inspectionDate ?? second.visitDate;
        return secondDate.compareTo(firstDate);
      });
    final query = _historySearch.trim().toLowerCase();
    final visibleTasks = completed
        .where((task) {
          final matchesRisk =
              _riskFilter == 'semua' || _riskCategoryKey(task) == _riskFilter;
          final searchable = [
            task.reporterName,
            task.ticketCode,
            task.village,
            task.rt,
            task.rw,
            task.intervention ?? '',
            RiskScore.label(task.riskCategory),
          ].join(' ').toLowerCase();
          return matchesRisk && (query.isEmpty || searchable.contains(query));
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(
          title: 'Riwayat Pemeriksaan',
          description: 'Hasil IKL selesai.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _historySearchController,
            onChanged: (value) => setState(() => _historySearch = value),
            decoration: InputDecoration(
              hintText: 'Cari pelapor, tiket, desa, atau intervensi',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _historySearch.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _historySearchController.clear();
                        setState(() => _historySearch = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.line),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final item in const [
                ('semua', 'Semua'),
                ('aman', 'Aman'),
                ('sedang', 'Sedang'),
                ('tinggi', 'Tinggi'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: _riskFilter == item.$1,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _riskFilter == item.$1
                          ? AppColors.primary
                          : AppColors.line,
                    ),
                    labelStyle: TextStyle(
                      color: _riskFilter == item.$1
                          ? Colors.white
                          : AppColors.muted,
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _riskFilter = item.$1),
                  ),
                ),
            ],
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_errorMessage != null)
          Expanded(child: Center(child: _buildError(_errorMessage!)))
        else if (visibleTasks.isEmpty)
          const Expanded(
            child: Center(
              child: WaterEmptyState(
                icon: Icons.history_rounded,
                title: 'Belum ada hasil pemeriksaan',
                message: 'Kunjungan IKL yang selesai akan tampil di sini.',
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  120 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemCount: visibleTasks.length,
                itemBuilder: (_, index) => VisitCardWidget(
                  schedule: visibleTasks[index],
                  onTap: () => _openHistoryDetail(visibleTasks[index]),
                  actionLabel: 'Lihat Hasil Pemeriksaan',
                  isHistory: true,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final profile = _dashboard?.profile ?? const OfficerProfile();
    return ProfileView(
      isActive: _selectedTab == 3,
      fallbackName: _displayName,
      roleLabel: 'Petugas Sanitasi',
      onBack: () => _selectTab(0),
      onLogout: _logout,
      logoutKey: const Key('officer_logout_btn'),
      onProfileChanged: (updated) {
        setState(() => _localProfileName = updated.name);
      },
      accountDetails: {
        'NIP': profile.nip,
        'Jabatan': profile.position,
        'Wilayah kerja': profile.serviceArea,
        'Puskesmas': profile.healthCenter.isEmpty
            ? 'Puskesmas Sumbersari'
            : profile.healthCenter,
      },
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStbmSummary() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _StbmDesaSheet(apiService: widget.apiService, token: widget.token),
    );
  }
}

String _normalizeTaskStatus(String status) =>
    status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

bool _isFinished(String status) =>
    const ['selesai', 'batal', 'ditolak'].contains(status.toLowerCase());

bool _isNewReport(VisitSchedule task) =>
    !task.isInspection &&
    const [
      'pending',
      'menunggu',
      'dikirim',
      'belum diverifikasi',
      'belum_diverifikasi',
      'menunggu_verifikasi',
      'menunggu-verifikasi',
    ].contains(task.status.trim().toLowerCase());

bool _isScheduledTask(VisitSchedule task) =>
    const [
      'terjadwal',
      'dijadwalkan',
      'ditindaklanjuti',
    ].contains(task.status.trim().toLowerCase()) ||
    (task.isInspection && task.status.trim().toLowerCase() == 'diproses');

String _riskCategoryKey(VisitSchedule task) {
  final risk = task.riskCategory?.trim().toLowerCase().replaceAll(' ', '_');
  if (risk == 'aman') return 'aman';
  if (risk == 'risiko_sedang' || risk == 'sedang') return 'sedang';
  if (risk == 'risiko_tinggi' ||
      risk == 'risiko_amat_tinggi' ||
      risk == 'amat_tinggi' ||
      risk == 'tinggi') {
    return 'tinggi';
  }
  return 'lainnya';
}

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

bool _isPending(String status) {
  final normalized = _normalizeTaskStatus(status);
  return const [
    'pending',
    'menunggu',
    'dikirim',
    'diproses',
    'menunggu_verifikasi',
    'belum_diverifikasi',
    'terjadwal',
    'dijadwalkan',
  ].contains(normalized);
}

class _HeaderBubble extends StatelessWidget {
  const _HeaderBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(height: 7),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: AppTheme.headlineFontFamily,
              color: AppColors.ink,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined ? Colors.white : AppColors.primary;
    return Material(
      color: outlined ? Colors.white.withValues(alpha: 0.13) : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: outlined ? Colors.white.withValues(alpha: 0.48) : Colors.white,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: foreground, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectionTaskCard extends StatelessWidget {
  const _InspectionTaskCard({
    required this.schedule,
    required this.onTap,
    this.showQuickAction = false,
  });

  final VisitSchedule schedule;
  final VoidCallback onTap;
  final bool showQuickAction;

  @override
  Widget build(BuildContext context) {
    final riskLabel = RiskScore.label(schedule.riskCategory);
    final riskColor = switch (riskLabel) {
      'Aman' => AppColors.green,
      'Sedang' => AppColors.orange,
      'Tinggi' => const Color(0xFFDC2626),
      _ => Colors.white,
    };
    final title = schedule.reporterName == '-'
        ? schedule.category
        : schedule.reporterName;
    final address = [
      if (schedule.address != '-') schedule.address,
      if (schedule.village != '-') schedule.village,
    ].join(', ');

    return SizedBox(
      width: 246,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 3,
        shadowColor: AppColors.primary.withValues(alpha: 0.16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF38BDF8), Color(0xFF0369A1)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(painter: _WaterMapPainter()),
                  Positioned(
                    top: 44,
                    right: 74,
                    child: Icon(
                      Icons.water_drop_rounded,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Positioned(
                    top: 64,
                    right: 96,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 35,
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.25, 1],
                        colors: [Colors.transparent, Color(0xE600172A)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _GlassLabel(
                      label: 'JADWAL IKL',
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _GlassLabel(label: riskLabel, color: riskColor),
                  ),
                  Positioned(
                    left: 15,
                    right: 15,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.headlineFontFamily,
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address.isEmpty ? schedule.category : address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xEFFFFFFF),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                schedule.visitDate == '-'
                                    ? 'Tanggal belum ditentukan'
                                    : schedule.visitDate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                        if (showQuickAction) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              icon: const Icon(
                                Icons.navigation_rounded,
                                size: 14,
                              ),
                              label: const Text(
                                'Mulai Kunjungan Terdekat',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCalloutCard extends StatelessWidget {
  const _ReportCalloutCard({required this.reportCount, required this.onTap});

  final int reportCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 174,
      height: 195,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -17,
            child: Icon(
              Icons.water_drop_rounded,
              size: 76,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                color: Colors.white,
                size: 20,
              ),
              const Spacer(),
              const Text(
                'Laporan Warga Masuk',
                style: TextStyle(
                  fontFamily: AppTheme.headlineFontFamily,
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$reportCount menunggu verifikasi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xEFFFFFFF), fontSize: 10),
              ),
              const SizedBox(height: 10),
              Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const StadiumBorder(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      'Lihat Semua  ›',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.schedule,
    required this.onTap,
    required this.onVerify,
  });

  final VisitSchedule schedule;
  final VoidCallback onTap;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final title = schedule.reporterName == '-'
        ? schedule.category
        : schedule.reporterName;
    return SizedBox(
      width: 218,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 195,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.75)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.softBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.report_problem_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _isPending(schedule.status)
                            ? AppColors.orange.withValues(alpha: 0.1)
                            : AppColors.softBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isPending(schedule.status)
                            ? 'Pending'
                            : schedule.status,
                        style: TextStyle(
                          color: _isPending(schedule.status)
                              ? AppColors.orange
                              : AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.headlineFontFamily,
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatKategoriLaporan(schedule.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        schedule.village,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (onVerify != null)
                      TextButton(
                        onPressed: onVerify,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          minimumSize: const Size(0, 30),
                        ),
                        child: const Text(
                          'Verifikasi',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyCard extends StatelessWidget {
  const _DashboardEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.height,
  });

  final IconData icon;
  final String title;
  final String message;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.headlineFontFamily,
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _WaterMapPainter extends CustomPainter {
  const _WaterMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var index = 0; index < 5; index++) {
      final path = Path()
        ..moveTo(size.width * (0.25 + index * 0.1), -size.height * 0.12)
        ..cubicTo(
          size.width * (0.1 + index * 0.12),
          size.height * 0.28,
          size.width * (0.9 - index * 0.08),
          size.height * 0.32,
          size.width * (0.62 + index * 0.1),
          size.height * 1.08,
        );
      canvas.drawPath(path, paint);
    }
    final stream = Path()
      ..moveTo(-size.width * 0.05, size.height * 0.72)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.48,
        size.width * 0.65,
        size.height * 0.94,
        size.width * 1.08,
        size.height * 0.56,
      );
    canvas.drawPath(stream, paint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _WaterMapPainter oldDelegate) => false;
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.description,
    this.onRefresh,
  });

  final String title;
  final String description;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return DynamicWaterHeader(
      height: 154,
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 34),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.headlineFontFamily,
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w400,
                  ).asHeading,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _StbmDesaSheet extends StatefulWidget {
  const _StbmDesaSheet({required this.apiService, required this.token});

  final OfficerApiService apiService;
  final String token;

  @override
  State<_StbmDesaSheet> createState() => _StbmDesaSheetState();
}

class _StbmDesaSheetState extends State<_StbmDesaSheet> {
  late final Future<List<StbmDesa>> _villages = widget.apiService.getStbmDesa(
    widget.token,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Capaian STBM Desa',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ringkasan sanitasi dan risiko sumber air.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<StbmDesa>>(
              future: _villages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Data STBM gagal dimuat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: WaterLoadingIndicator());
                }
                final villages = snapshot.data!;
                if (villages.isEmpty) {
                  return const WaterEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Belum ada data STBM',
                    message: 'Data capaian sanitasi desa belum tersedia.',
                  );
                }
                return ListView.separated(
                  itemCount: villages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final village = villages[index];
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            village.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            'Capaian STBM: ${village.stbmAchievement}%  •  Rumah terdata: ${village.verifiedHouseholds}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Risiko air: ${village.riskLabel} (${village.waterRiskCount})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
