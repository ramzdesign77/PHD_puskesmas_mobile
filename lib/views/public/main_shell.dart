import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/fluid_bottom_nav.dart';
import '../../widgets/ocean_widgets.dart';
import '../main_layout_screen.dart';
import '../profile/profile_view.dart';
import 'home_view.dart';
import 'report_view.dart';
import 'tracking_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.apiService, this.authService});

  final ApiService apiService;
  final AuthService? authService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String? _activeTrackingTicketCode;
  late Future<AuthSession?> _session;
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _session = widget.apiService.loadSavedSession();
  }

  void _selectTab(int index) => setState(() => _currentIndex = index);

  void _handleReportSubmitted(String ticketCode) {
    setState(() {
      _activeTrackingTicketCode = ticketCode;
      _currentIndex = 2;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await _authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      FutureBuilder<AuthSession?>(
        future: _session,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Sesi pengguna tidak dapat dimuat: ${snapshot.error}',
              ),
            );
          }
          final name = snapshot.data?.userName.trim();
          return HomeView(
            apiService: widget.apiService,
            greetingName: name == null || name.isEmpty ? 'Warga' : name,
            onOpenReports: () => _selectTab(1),
            onOpenTracking: () => _selectTab(2),
          );
        },
      ),
      ReportView(
        apiService: widget.apiService,
        onReportSubmitted: _handleReportSubmitted,
      ),
      TrackingView(
        apiService: widget.apiService,
        initialTicketCode: _activeTrackingTicketCode,
        isActive: _currentIndex == 2,
      ),
      _ProfileTab(
        session: _session,
        onLogout: _logout,
        isLoggingOut: _isLoggingOut,
        onBack: () => _selectTab(0),
        onProfileChanged: () {
          setState(() {
            _session = widget.apiService.loadSavedSession();
          });
        },
      ),
    ];

    return MainLayoutScreen(
      bodySafeArea: false,
      pages: screens,
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
      destinations: const [
        FluidNavDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Beranda',
        ),
        FluidNavDestination(
          icon: Icons.add_rounded,
          selectedIcon: Icons.add_rounded,
          label: 'Lapor',
        ),
        FluidNavDestination(
          icon: Icons.access_time_outlined,
          selectedIcon: Icons.access_time_filled_rounded,
          label: 'Lacak',
        ),
        FluidNavDestination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profil',
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.session,
    required this.onLogout,
    required this.isLoggingOut,
    required this.onBack,
    required this.onProfileChanged,
  });

  final Future<AuthSession?> session;
  final VoidCallback onLogout;
  final bool isLoggingOut;
  final VoidCallback onBack;
  final VoidCallback onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: session,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Profil tidak dapat dimuat: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: WaterLoadingIndicator());
        }
        final user = snapshot.data;
        if (user == null) {
          return const Center(child: Text('Sesi pengguna tidak ditemukan.'));
        }
        return ProfileView(
          fallbackName: user.userName.isEmpty ? 'Warga' : user.userName,
          roleLabel: user.role == 'warga' ? 'Warga' : user.role,
          onBack: onBack,
          onLogout: onLogout,
          isLoggingOut: isLoggingOut,
          onProfileChanged: (_) => onProfileChanged(),
        );
      },
    );
  }
}
