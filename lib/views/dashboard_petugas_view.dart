import 'package:flutter/material.dart';

class DashboardPetugasView extends StatelessWidget {
  const DashboardPetugasView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Petugas')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_rounded,
              size: 58,
              color: Color(0xFF0B8585),
            ),
            SizedBox(height: 12),
            Text(
              'Dashboard Kerja Lapangan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text('Kelola tugas dan tindak lanjut laporan.'),
          ],
        ),
      ),
    );
  }
}
