import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/officer_dashboard_data.dart';
import '../../models/visit_schedule.dart';
import '../../services/api_service.dart';
import '../../services/officer_api_service.dart';
import '../../widgets/ocean_widgets.dart';
import 'officer_detail_view.dart';
import 'widgets/visit_card_widget.dart';

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
  List<VisitSchedule> _schedules = const [];
  OfficerDashboardData? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;
  String? _dashboardWarning;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      schedules = await widget.apiService.getTasks(widget.token);
    } catch (error) {
      taskError = error;
    }

    if (!mounted) return;
    final loadedSchedules =
        schedules ?? dashboard?.schedules ?? const <VisitSchedule>[];
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

  List<VisitSchedule> get _todayInspections => _schedules
      .where(
        (schedule) =>
            !_isFinished(schedule.status) &&
            schedule.visitDate.startsWith(_todayDate),
      )
      .toList(growable: false);

  List<VisitSchedule> get _recentTasks {
    final tasks = [..._schedules]
      ..sort((first, second) {
        final firstPending = _isPending(first.status) ? 0 : 1;
        final secondPending = _isPending(second.status) ? 0 : 1;
        return firstPending.compareTo(secondPending);
      });
    return tasks.take(5).toList(growable: false);
  }

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  int get _newReportsCount =>
      _dashboard?.summary.newReportsCount ??
      _schedules.where((schedule) => _isPending(schedule.status)).length;

  int get _todayInspectionCount =>
      _dashboard?.summary.todayInspectionsCount ?? _todayInspections.length;

  String get _displayName {
    final name = _dashboard?.profile.name.trim();
    return name == null || name.isEmpty ? widget.officerName : name;
  }

  Future<void> _openDetail(VisitSchedule schedule) async {
    final updated = await Navigator.of(context).push<VisitSchedule>(
      MaterialPageRoute(
        builder: (_) => OfficerDetailView(
          schedule: schedule,
          token: widget.token,
          apiService: widget.apiService,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final index = _schedules.indexWhere((item) => item.id == updated.id);
      if (index >= 0) _schedules[index] = updated;
    });
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
    await ApiService.clearSavedSession();
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
      _buildInspectionTab(),
      _buildProfileTab(),
    ];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedTab, children: pages),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: _selectTab,
            backgroundColor: Colors.white.withValues(alpha: 0.86),
            indicatorColor: AppColors.softRed,
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'Tugas Aduan',
              ),
              NavigationDestination(
                icon: Icon(Icons.note_add_outlined),
                selectedIcon: Icon(Icons.note_add_rounded),
                label: 'Input IKL',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
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
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 430,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 306,
                  child: DynamicWaterHeader(
                    key: const Key('officer_header_background'),
                    height: 306,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          children: [
                            Container(
                              height: 72,
                              width: 72,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.asset(
                                  'assets/images/logo.jpg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.health_and_safety_outlined,
                                    color: AppColors.primary,
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'KLINIK SANITASI',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dashboard?.profile.healthCenter.isNotEmpty ==
                                      true
                                  ? _dashboard!.profile.healthCenter
                                  : 'PUSKESMAS SUMBERSARI',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 238,
                  left: 18,
                  right: 18,
                  child: _buildSummaryCard(),
                ),
              ],
            ),
          ),
          if (_dashboardWarning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                _dashboardWarning!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          _buildQuickActions(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daftar Tugas & Aduan Terbaru',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _selectTab(1),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.softRed,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Lihat Semua  ›',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          _buildRecentCards(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Halo, $_displayName, SKM',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Petugas Kesling',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Ringkasan Tugas Lapangan Hari Ini:',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        count: _newReportsCount,
                        label: 'Aduan Baru',
                        color: AppColors.primary,
                        icon: Icons.mark_email_unread_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        count: _todayInspectionCount,
                        label: 'Jadwal IKL',
                        color: AppColors.accent,
                        icon: Icons.assignment_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.water_drop_rounded,
                        color: Color(0x3029B6F6),
                        size: 68,
                      ),
                      Icon(
                        Icons.health_and_safety_rounded,
                        color: AppColors.primary,
                        size: 37,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    const actions = [
      _QuickActionData(
        label: 'Verifikasi\nAduan',
        icon: Icons.fact_check_outlined,
        tab: 1,
      ),
      _QuickActionData(
        label: 'Input Form\nIKL',
        icon: Icons.note_add_outlined,
        tab: 2,
      ),
      _QuickActionData(
        label: 'Jadwal\nKunjungan',
        icon: Icons.calendar_month_outlined,
        tab: 1,
      ),
      _QuickActionData(
        label: 'Data STBM\nDesa',
        icon: Icons.bar_chart_rounded,
        tab: -1,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: action.tab < 0
                      ? _showStbmSummary
                      : () => _selectTab(action.tab),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Container(
                          height: 62,
                          width: 62,
                          decoration: const BoxDecoration(
                            color: AppColors.softBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            action.icon,
                            color: AppColors.primaryDark,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          action.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 10.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildRecentCards() {
    if (_isLoading) {
      return const SizedBox(
        height: 155,
        child: Center(child: WaterLoadingIndicator()),
      );
    }
    if (_errorMessage != null) return _buildError(_errorMessage!);
    final tasks = _recentTasks;
    if (tasks.isEmpty) {
      return const WaterEmptyState(
        icon: Icons.assignment_outlined,
        title: 'Belum ada tugas lapangan',
        message: 'Tugas terbaru akan muncul di sini.',
      );
    }
    return SizedBox(
      height: 222,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final schedule = tasks[index];
          return SizedBox(
            width: 300,
            child: VisitCardWidget(
              schedule: schedule,
              onTap: () => _openDetail(schedule),
              actionLabel: _isPending(schedule.status)
                  ? 'Tindak Lanjut'
                  : 'Lihat Detail',
              isInspection: schedule.isInspection,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksTab() {
    return _buildListPage(
      title: 'Tugas Aduan',
      description: 'Aduan warga dan jadwal kunjungan lapangan.',
      tasks: _schedules,
      emptyMessage: 'Belum ada aduan atau tugas kunjungan.',
      isTaskList: true,
    );
  }

  Widget _buildInspectionTab() {
    return _buildListPage(
      title: 'Input Form IKL',
      description: 'Pilih jadwal aktif untuk mengisi kuesioner inspeksi.',
      tasks: _activeTasks,
      emptyMessage: 'Tidak ada jadwal aktif untuk diinspeksi.',
      isTaskList: false,
    );
  }

  Widget _buildListPage({
    required String title,
    required String description,
    required List<VisitSchedule> tasks,
    required String emptyMessage,
    required bool isTaskList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: title,
          description: description,
          onRefresh: _loadData,
        ),
        if (_isLoading)
          const Expanded(child: Center(child: WaterLoadingIndicator()))
        else if (_errorMessage != null)
          Expanded(child: Center(child: _buildError(_errorMessage!)))
        else if (tasks.isEmpty)
          Expanded(
            child: Center(
              child: WaterEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum ada tugas',
                message: emptyMessage,
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: tasks.length,
                itemBuilder: (_, index) {
                  final task = tasks[index];
                  return VisitCardWidget(
                    schedule: task,
                    onTap: () => _openDetail(task),
                    onAction: isTaskList && _isPending(task.status)
                        ? () => _verify(task)
                        : null,
                    actionLabel: isTaskList && _isPending(task.status)
                        ? 'Verifikasi'
                        : 'Isi Form IKL',
                    isInspection: !isTaskList || task.isInspection,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final profile = _dashboard?.profile ?? const OfficerProfile();
    return Column(
      children: [
        const _PageHeader(
          title: 'Profil Petugas',
          description: 'Informasi akun dan wilayah kerja.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 31,
                        backgroundColor: AppColors.softBlue,
                        child: Icon(
                          Icons.person_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.name.isEmpty ? widget.officerName : profile.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfileRow(label: 'NIP', value: profile.nip),
                    _ProfileRow(label: 'Jabatan', value: profile.position),
                    _ProfileRow(
                      label: 'Wilayah Kerja',
                      value: profile.serviceArea,
                    ),
                    _ProfileRow(
                      label: 'Puskesmas',
                      value: profile.healthCenter.isEmpty
                          ? 'Puskesmas Sumbersari'
                          : profile.healthCenter,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('officer_logout_btn'),
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar / Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'E-Klinik Sanitasi · Versi 1.0.0',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
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

bool _isFinished(String status) => status.toLowerCase() == 'selesai';

bool _isPending(String status) {
  final normalized = status.toLowerCase();
  return normalized == 'pending' ||
      normalized == 'menunggu' ||
      normalized == 'belum diverifikasi';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int count;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 25,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Icon(icon, size: 14, color: color),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.tab,
  });

  final String label;
  final IconData icon;
  final int tab;
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
      height: 138,
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
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 108,
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.line),
      ],
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
              fontWeight: FontWeight.w800,
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
                              fontWeight: FontWeight.w800,
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
                              fontWeight: FontWeight.w600,
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
