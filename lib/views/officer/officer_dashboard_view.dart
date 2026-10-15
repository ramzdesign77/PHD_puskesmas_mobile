import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/visit_schedule.dart';
import '../../services/api_service.dart';
import '../../services/officer_api_service.dart';
import 'officer_detail_view.dart';
import 'widgets/visit_card_widget.dart';

/// Dashboard / Beranda Petugas.
/// Menampilkan daftar jadwal kunjungan dengan tab filter:
///   - "Tugas Baru"       : status pending atau diproses
///   - "Riwayat Selesai"  : status selesai
///
/// Data dummy digunakan sementara agar UI bisa langsung dipreview
/// sebelum API dihubungkan (ganti `_useDummyData = true` menjadi false).
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

class _OfficerDashboardViewState extends State<OfficerDashboardView>
    with SingleTickerProviderStateMixin {
  // ── Ganti ke false saat API sudah siap ─────────────────────────
  static const bool _useDummyData = true;

  late final TabController _tabController;
  List<VisitSchedule> _allSchedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load data (dummy atau API) ─────────────────────────────────
  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_useDummyData) {
        // Simulasi delay jaringan agar terasa natural
        await Future.delayed(const Duration(milliseconds: 600));
        _allSchedules = List.from(dummyVisitSchedules);
      } else {
        _allSchedules = await widget.apiService.getMySchedules(widget.token);
      }
    } on ApiOfficerException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Gagal memuat jadwal. Periksa koneksi Anda.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Filter berdasarkan tab ─────────────────────────────────────
  List<VisitSchedule> get _activeTasks => _allSchedules
      .where(
        (s) =>
            s.status.toLowerCase() == 'pending' ||
            s.status.toLowerCase() == 'diproses',
      )
      .toList();

  List<VisitSchedule> get _finishedTasks =>
      _allSchedules.where((s) => s.status.toLowerCase() == 'selesai').toList();

  // ── Navigasi ke halaman detail ─────────────────────────────────
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
    // Jika petugas berhasil submit, perbarui state lokal
    if (updated != null && mounted) {
      setState(() {
        final idx = _allSchedules.indexWhere((s) => s.id == updated.id);
        if (idx != -1) _allSchedules[idx] = updated;
      });
    }
  }

  // ── Logout ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Anda yakin ingin keluar dari sistem petugas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.apiService.logoutOfficer(widget.token);
    } catch (_) {
      // Abaikan error logout — tetap arahkan ke login
    }
    await ApiService.clearSavedSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxScrolled) => [_buildSliverAppBar()],
        body: Column(
          children: [
            // ── Tab Bar ───────────────────────────────────────
            _buildTabBar(),

            // ── Konten tab ────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScheduleList(
                    _activeTasks,
                    emptyLabel: 'Tidak ada tugas baru saat ini.',
                  ),
                  _buildScheduleList(
                    _finishedTasks,
                    emptyLabel: 'Belum ada kunjungan yang selesai.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sliver App Bar ─────────────────────────────────────────────
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.primary,
      actions: [
        IconButton(
          key: const Key('officer_refresh_btn'),
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadSchedules,
          tooltip: 'Muat Ulang',
        ),
        IconButton(
          key: const Key('officer_logout_btn'),
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
          tooltip: 'Keluar',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Selamat Datang,',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.officerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryChips(),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Summary chip (jumlah tugas baru & selesai) ─────────────────
  Widget _buildSummaryChips() {
    return Row(
      children: [
        _SummaryChip(
          count: _activeTasks.length,
          label: 'Tugas Aktif',
          icon: Icons.pending_actions,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          count: _finishedTasks.length,
          label: 'Selesai',
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
        ),
        tabs: const [
          Tab(text: 'Tugas Baru'),
          Tab(text: 'Riwayat Selesai'),
        ],
      ),
    );
  }

  // ── Daftar Jadwal ──────────────────────────────────────────────
  Widget _buildScheduleList(
    List<VisitSchedule> items, {
    required String emptyLabel,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSchedules,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 56,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadSchedules,
      child: ListView.builder(
        key: PageStorageKey(emptyLabel),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => VisitCardWidget(
          schedule: items[i],
          onTap: () => _openDetail(items[i]),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Widget chip ringkasan di header
// ────────────────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.icon,
  });

  final int count;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
