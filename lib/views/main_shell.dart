import 'package:flutter/material.dart';

import '../services/api_service.dart';
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

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeView(
        apiService: widget.apiService,
        onOpenReports: () => _selectTab(1),
      ),
      ReportView(apiService: widget.apiService),
      TrackingView(apiService: widget.apiService),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            selectedIcon: Icon(Icons.add_location_alt),
            label: 'Lapor',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Lacak',
          ),
        ],
      ),
    );
  }
}
