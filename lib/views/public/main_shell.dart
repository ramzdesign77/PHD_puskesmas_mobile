import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import 'home_view.dart';
import 'report_view.dart';
import 'tracking_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late Future<AuthSession?> _session;

  @override
  void initState() {
    super.initState();
    _session = widget.apiService.loadSavedSession();
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

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
      ReportView(apiService: widget.apiService),
      TrackingView(apiService: widget.apiService),
      _ProfileTab(session: _session),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.muted,
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.softRed,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.muted),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.muted,
                child: Icon(Icons.add, color: Colors.white, size: 18),
              ),
              selectedIcon: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.add, color: Colors.white, size: 18),
              ),
              label: 'Lapor',
            ),
            NavigationDestination(
              icon: Icon(Icons.access_time, color: AppColors.muted),
              selectedIcon:
                  Icon(Icons.access_time_filled, color: AppColors.primary),
              label: 'Lacak',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppColors.muted),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.session});

  final Future<AuthSession?> session;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<AuthSession?>(
        future: session,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Profil tidak dapat dimuat: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Sesi pengguna tidak ditemukan.'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Profil',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.softRed,
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nama',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.userName.isEmpty ? 'Warga' : user.userName,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Peran akun',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.role,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
