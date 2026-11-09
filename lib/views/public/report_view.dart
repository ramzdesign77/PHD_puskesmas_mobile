import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/village.dart';
import '../../models/ticket_status.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocean_widgets.dart';

class _WaterCategoryCard extends StatefulWidget {
  const _WaterCategoryCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  State<_WaterCategoryCard> createState() => _WaterCategoryCardState();
}

class _WaterCategoryCardState extends State<_WaterCategoryCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _waterController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: _hovered ? -5 : 0),
          builder: (context, lift, child) {
            return Transform.translate(
              offset: Offset(0, lift),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: _hovered ? 1.025 : 1,
                curve: Curves.easeOutBack,
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.softBlue
                  : const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: _hovered ? 0.9 : 1)
                    : const Color(0xFFE0E0E0),
                width: active ? 2 : 1,
              ),
              boxShadow: _hovered || widget.selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: _hovered ? 0.20 : 0.12,
                        ),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                if (_hovered || widget.selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _waterController,
                        builder: (context, _) => CustomPaint(
                          painter: _CategoryWaterPainter(
                            _waterController.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.selected)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.check_circle,
                      size: 17,
                      color: AppColors.primary,
                    ),
                  ),
                Center(
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary.withValues(alpha: 0.10)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 220),
                          tween: Tween(begin: 0, end: _hovered ? -0.08 : 0),
                          builder: (context, tilt, child) {
                            return Transform.rotate(angle: tilt, child: child);
                          },
                          child: Icon(
                            widget.icon,
                            size: 22,
                            color: active
                                ? AppColors.primary
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: active
                                ? AppColors.primary
                                : const Color(0xFF374151),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryWaterPainter extends CustomPainter {
  const _CategoryWaterPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.primary.withValues(alpha: 0.26);

    for (var ring = 0; ring < 3; ring++) {
      final distance = ((progress + ring / 3) % 1);
      final radius = 16 + distance * size.height * 0.5;
      canvas.drawCircle(
        Offset(size.width * 0.14, size.height * 0.92),
        radius,
        paint
          ..color = AppColors.primary.withValues(alpha: 0.30 * (1 - distance)),
      );
    }

    final wavePaint = Paint()
      ..color = const Color(0xFF4DA3E8).withValues(alpha: 0.36)
      ..style = PaintingStyle.fill;
    final path = Path()..moveTo(-10, size.height * 0.82);
    for (var x = -10.0; x <= size.width + 10; x += 4) {
      final y =
          size.height * 0.82 +
          math.sin((x / size.width) * math.pi * 3 + progress * math.pi * 2) * 4;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width + 10, size.height)
      ..lineTo(-10, size.height)
      ..close();
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _CategoryWaterPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    required this.apiService,
    this.onReportSubmitted,
    this.onOpenTicketHistory,
    this.onOpenAllHistory,
  });

  final ApiService apiService;
  final ValueChanged<String>? onReportSubmitted;
  final ValueChanged<String>? onOpenTicketHistory;
  final VoidCallback? onOpenAllHistory;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _alamatDetail = TextEditingController();
  final _description = TextEditingController();
  final _imagePicker = ImagePicker();

  late Future<List<Village>> _villages;
  Village? _selectedVillage;
  String? _selectedRt;
  String? _selectedRw;
  String _category = '';
  XFile? _image;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  bool _isLoggedIn = false;
  bool _sessionLoaded = false;
  bool _isLoadingLocation = false;
  Position? _selectedPosition;
  String? _profileVillageName;
  List<TicketStatus> _recentTickets = [];

  @override
  void initState() {
    super.initState();
    _villages = widget.apiService.getVillages();
    _loadSession();
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    try {
      await widget.apiService.syncCitizenTicketsHistory();
      final tickets = await widget.apiService.getCachedCitizenTicketStatuses();
      if (!mounted) return;
      setState(() {
        _recentTickets = tickets.take(3).toList();
      });

      final codes = await widget.apiService.getSavedCitizenTickets();
      for (final code in codes.take(3)) {
        try {
          final ticket = await widget.apiService.getTicket(code);
          if (!mounted) return;
          setState(() {
            final updated = [
              ticket,
              ..._recentTickets.where((item) => item.code != ticket.code),
            ];
            _recentTickets = updated.take(3).toList();
          });
        } on ApiException {
          continue;
        } on Exception {
          continue;
        }
      }
    } on Exception {
      if (!mounted) return;
      final cached = await widget.apiService.getCachedCitizenTicketStatuses();
      if (mounted) setState(() => _recentTickets = cached.take(3).toList());
    }
  }

  Future<void> _loadSession() async {
    final session = await widget.apiService.loadSavedSession();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = session != null;
      _sessionLoaded = true;
      if (session != null) {
        _name.text = session.userName;
        _profileVillageName = session.villageName;
        final rt = session.rt?.trim();
        final rw = session.rw?.trim();
        _selectedRt = rt == null || rt.isEmpty ? null : rt.padLeft(2, '0');
        _selectedRw = rw == null || rw.isEmpty ? null : rw.padLeft(2, '0');
        _phone.text = session.phone ?? '';
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _alamatDetail.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Ambil dari Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _image = image;
          _imageBytes = bytes;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        _showError('Gagal memilih foto. $error');
      }
    }
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException(
        'Aktifkan layanan lokasi untuk mengirim laporan.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Izin lokasi diperlukan untuk mengirim laporan.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  Future<void> _takeLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await _currentPosition();
      if (!mounted) return;
      setState(() => _selectedPosition = position);
    } on ApiException catch (error) {
      _showError(error.message);
    } on Exception catch (error) {
      _showError('Gagal mengambil lokasi GPS. $error');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedVillage == null) {
      if (_selectedVillage == null) {
        _showError('Pilih desa atau kelurahan terlebih dahulu.');
      }
      return;
    }
    if (_category.isEmpty) {
      _showError('Pilih kategori laporan terlebih dahulu.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final reportData = <String, String>{
        'nama_pelapor': _name.text.trim(),
        'no_wa': _phone.text.trim(),
        'id_desa': _selectedVillage!.id.toString(),
        'rt': _selectedRt ?? '',
        'rw': _selectedRw ?? '',
        'kategori_laporan': _category,
        'alamat_detail': _alamatDetail.text.trim(),
        'patokan_alamat': _alamatDetail.text.trim(),
        'deskripsi': _description.text.trim(),
      };
      if (_selectedPosition != null) {
        reportData['latitude'] = _selectedPosition!.latitude.toString();
        reportData['longitude'] = _selectedPosition!.longitude.toString();
      }
      final ticketCode = await widget.apiService.submitReport(
        reportData,
        imageFile: _image,
      );
      await _loadHistory();

      if (!mounted) return;
      final onReportSubmitted = widget.onReportSubmitted;
      if (onReportSubmitted != null) {
        onReportSubmitted(ticketCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan terkirim. Kode tiket: $ticketCode'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _formKey.currentState!.reset();
      _name.clear();
      _phone.clear();
      _alamatDetail.clear();
      _description.clear();
      setState(() {
        _selectedVillage = null;
        _selectedRt = null;
        _selectedRw = null;
        _category = '';
        _image = null;
        _imageBytes = null;
        _selectedPosition = null;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } on Exception catch (error) {
      _showError(
        'Laporan belum dapat dikirim. Periksa koneksi internet. $error',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

  Widget _buildCategoryGrid() {
    const categories = [
      (
        value: 'air_sumur_keruh_berbau',
        label: 'Air Sumur Keruh / Berbau',
        icon: Icons.water_drop_rounded,
      ),
      (
        value: 'sarang_nyamuk_dbd',
        label: 'Sarang Nyamuk / Indikasi DBD',
        icon: Icons.bug_report_rounded,
      ),
      (
        value: 'jamban_limbah_stbm',
        label: 'Masalah Jamban & Limbah (STBM)',
        icon: Icons.wc_rounded,
      ),
      (
        value: 'tumpukan_sampah',
        label: 'Tumpukan Sampah',
        icon: Icons.delete_sweep_rounded,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: categories.map((category) {
        final selected = _category == category.value;
        return _WaterCategoryCard(
          selected: selected,
          onTap: () => setState(() => _category = category.value),
          icon: category.icon,
          label: category.label,
        );
      }).toList(),
    );
  }

  String _categoryLabel(String category) {
    switch (category.trim()) {
      case 'air_sumur_keruh_berbau':
        return 'Air Sumur Keruh / Berbau';
      case 'sarang_nyamuk_dbd':
        return 'Sarang Nyamuk / Indikasi DBD';
      case 'jamban_limbah_stbm':
        return 'Masalah Jamban & Limbah';
      case 'tumpukan_sampah':
        return 'Tumpukan Sampah';
      default:
        if (category.trim().isEmpty) return 'Kategori tidak tersedia';
        return category.replaceAll('_', ' ');
    }
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'dikirim':
        return 'Dikirim';
      case 'menunggu':
      case 'pending':
      case 'diproses':
        return 'Diproses';
      case 'dijadwalkan':
        return 'Dijadwalkan';
      case 'ditindaklanjuti':
        return 'Ditindaklanjuti';
      case 'selesai':
        return 'Selesai';
      case 'ditolak':
        return 'Ditolak';
      default:
        return status.trim().isEmpty ? 'Dikirim' : status;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Tanggal tidak tersedia';
    }
    final date = DateTime.tryParse(raw.trim());
    if (date == null) return raw.trim();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildReportHistory() {
    if (_recentTickets.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Riwayat Laporan Terakhir Anda',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenAllHistory,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Lihat Semua', textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final ticket in _recentTickets.take(3)) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  final callback =
                      widget.onOpenTicketHistory ?? widget.onReportSubmitted;
                  callback?.call(ticket.code);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Salin kode tiket',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: ticket.code),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kode tiket disalin.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softRed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(ticket.status),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _categoryLabel(ticket.category),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(ticket.createdAt),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.softBlue,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.primary,
          ).asHeading,
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.bodyFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Header Curved Maroon Background
            DynamicWaterHeader(
              height: 250,
              child: Stack(
                children: [
                  Positioned(
                    right: 18,
                    top: 48,
                    child: Icon(
                      Icons.health_and_safety,
                      size: 96,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),

            // Content: Top Bar, Titles, and Overlapping Form Card
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Buat Laporan',
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFontFamily,
                            fontSize: 26,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ).asHeading,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sampaikan masalah air atau sanitasi\ndi lingkungan Anda.',
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFontFamily,
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),

                  // Overlapping White Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildReportHistory(),
                            // ============================================
                            // Section 1: Data Pelapor
                            // ============================================
                            if (!_sessionLoaded || !_isLoggedIn) ...[
                              _buildSectionHeader(
                                icon: Icons.person_outline,
                                title: 'Data Pelapor',
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _name,
                                validator: _required,
                                textCapitalization: TextCapitalization.words,
                                style: TextStyle(
                                  fontFamily: AppTheme.bodyFontFamily,
                                  fontSize: 14,
                                  color: AppColors.ink,
                                ),
                                decoration: _fieldDecoration(
                                  hintText: 'Nama Lengkap',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                validator: _required,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.ink,
                                ),
                                decoration: _fieldDecoration(
                                  hintText: 'Nomor WhatsApp Aktif',
                                  prefixIcon: const Icon(
                                    Icons.phone_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],

                            // ============================================
                            // Section 2: Lokasi Kejadian
                            // ============================================
                            const SizedBox(height: 22),
                            _buildSectionHeader(
                              icon: Icons.location_on_outlined,
                              title: 'Lokasi Kejadian',
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Desa / Kelurahan'),
                            FutureBuilder<List<Village>>(
                              future: _villages,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return _RetryVillage(
                                    onRetry: () => setState(
                                      () => _villages = widget.apiService
                                          .getVillages(),
                                    ),
                                  );
                                }
                                final villages = snapshot.data ?? [];
                                if (_selectedVillage == null &&
                                    _profileVillageName != null &&
                                    villages.isNotEmpty) {
                                  final matches = villages
                                      .where(
                                        (village) =>
                                            village.name.toLowerCase().trim() ==
                                            _profileVillageName!
                                                .toLowerCase()
                                                .trim(),
                                      )
                                      .toList();
                                  if (matches.isNotEmpty) {
                                    final match = matches.first;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted &&
                                              _selectedVillage == null) {
                                            setState(() {
                                              _selectedVillage = match;
                                            });
                                          }
                                        });
                                  }
                                }

                                return DropdownButtonFormField<Village>(
                                  initialValue: _selectedVillage,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.muted,
                                  ),
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFontFamily,
                                    fontSize: 14,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _fieldDecoration(
                                    hintText: 'Pilih desa',
                                    prefixIcon: const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.muted,
                                      size: 20,
                                    ),
                                  ),
                                  items: villages.map((village) {
                                    return DropdownMenuItem(
                                      value: village,
                                      child: Text(
                                        village.name,
                                        style: TextStyle(
                                          fontFamily: AppTheme.bodyFontFamily,
                                          fontSize: 14,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (village) => setState(
                                    () => _selectedVillage = village,
                                  ),
                                  validator: (val) => val == null
                                      ? 'Pilih desa atau kelurahan.'
                                      : null,
                                  hint: Text(
                                    'Pilih desa',
                                    style: TextStyle(
                                      fontFamily: AppTheme.bodyFontFamily,
                                      color: AppColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedRt,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.muted,
                                    ),
                                    style: TextStyle(
                                      fontFamily: AppTheme.bodyFontFamily,
                                      fontSize: 14,
                                      color: AppColors.ink,
                                    ),
                                    decoration: _fieldDecoration(
                                      hintText: 'RT',
                                      prefixIcon: const Icon(
                                        Icons.location_on_outlined,
                                        color: AppColors.muted,
                                        size: 20,
                                      ),
                                    ),
                                    hint: Text(
                                      'RT',
                                      style: TextStyle(
                                        fontFamily: AppTheme.bodyFontFamily,
                                        color: AppColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    items: List.generate(30, (i) {
                                      final numStr = (i + 1).toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      return DropdownMenuItem(
                                        value: numStr,
                                        child: Text(
                                          'RT $numStr',
                                          style: TextStyle(
                                            fontFamily: AppTheme.bodyFontFamily,
                                            fontSize: 14,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (val) =>
                                        setState(() => _selectedRt = val),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                        ? 'Pilih RT'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedRw,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.muted,
                                    ),
                                    style: TextStyle(
                                      fontFamily: AppTheme.bodyFontFamily,
                                      fontSize: 14,
                                      color: AppColors.ink,
                                    ),
                                    decoration: _fieldDecoration(
                                      hintText: 'RW',
                                      prefixIcon: const Icon(
                                        Icons.home_outlined,
                                        color: AppColors.muted,
                                        size: 20,
                                      ),
                                    ),
                                    hint: Text(
                                      'RW',
                                      style: TextStyle(
                                        fontFamily: AppTheme.bodyFontFamily,
                                        color: AppColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    items: List.generate(20, (i) {
                                      final numStr = (i + 1).toString().padLeft(
                                        2,
                                        '0',
                                      );
                                      return DropdownMenuItem(
                                        value: numStr,
                                        child: Text(
                                          'RW $numStr',
                                          style: TextStyle(
                                            fontFamily: AppTheme.bodyFontFamily,
                                            fontSize: 14,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (val) =>
                                        setState(() => _selectedRw = val),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                        ? 'Pilih RW'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _alamatDetail,
                              validator: _required,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Patokan / Detail Alamat (Contoh: Depan Masjid Al-Ikhlas, rumah pagar hitam)',
                                prefixIcon: const Icon(
                                  Icons.place_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isLoadingLocation
                                  ? null
                                  : _takeLocation,
                              icon: _isLoadingLocation
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                              label: Text(
                                _selectedPosition == null
                                    ? 'Ambil Titik Lokasi (GPS)'
                                    : 'Perbarui Titik Lokasi (GPS)',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: AppColors.softBlue,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            if (_selectedPosition != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Titik Koordinat Terkunci: '
                                '${_selectedPosition!.latitude.toStringAsFixed(6)}, '
                                '${_selectedPosition!.longitude.toStringAsFixed(6)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF267A58),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],

                            // ============================================
                            // Section 3: Detail Laporan
                            // ============================================
                            const SizedBox(height: 22),
                            _buildSectionHeader(
                              icon: Icons.description_outlined,
                              title: 'Detail Laporan',
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Kategori Laporan'),
                            _buildCategoryGrid(),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Deskripsi masalah'),
                            Stack(
                              children: [
                                TextFormField(
                                  controller: _description,
                                  minLines: 4,
                                  maxLines: 6,
                                  maxLength: 2000,
                                  buildCounter: (
                                    context, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) => null,
                                  onChanged: (_) => setState(() {}),
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFontFamily,
                                    fontSize: 14,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _fieldDecoration(
                                    hintText: 'Jelaskan secara singkat dan jelas mengenai masalah yang terjadi...',
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      40,
                                      14,
                                      14,
                                      28,
                                    ),
                                  ),
                                  validator: (value) {
                                    final required = _required(value);
                                    if (required != null) return required;
                                    return value!.trim().length < 10
                                        ? 'Deskripsi minimal 10 karakter.'
                                        : null;
                                  },
                                ),
                                const Positioned(
                                  top: 14,
                                  left: 12,
                                  child: Icon(
                                    Icons.description_outlined,
                                    color: AppColors.muted,
                                    size: 20,
                                  ),
                                ),
                                Positioned(
                                  right: 14,
                                  bottom: 8,
                                  child: Text(
                                    '${_description.text.length}/2000',
                                    style: TextStyle(
                                      fontFamily: AppTheme.bodyFontFamily,
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Optional photo proof attachment
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(16),
                              child: CustomPaint(
                                painter: _DashedBorderPainter(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.fieldFill,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _image == null
                                            ? Icons.camera_alt_outlined
                                            : Icons.check_circle,
                                        color: AppColors.primary,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _image == null
                                              ? 'Pilih foto bukti (opsional)'
                                              : 'Foto: ${_image!.name}',
                                          style: TextStyle(
                                            fontFamily: AppTheme.bodyFontFamily,
                                            color: _image == null
                                                ? AppColors.primary
                                                : AppColors.ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_image != null)
                                        InkWell(
                                          onTap: () => setState(() {
                                            _image = null;
                                            _imageBytes = null;
                                          }),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_image != null && _imageBytes != null) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _imageBytes!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],

                            // ============================================
                            // Tombol Aksi Utama: Kirim Laporan
                            // ============================================
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.rotate(
                                            angle: -0.4,
                                            child: const Icon(
                                              Icons.send_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'KIRIM LAPORAN PENGADUAN',
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTheme.bodyFontFamily,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryVillage extends StatelessWidget {
  const _RetryVillage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Desa / kelurahan',
        errorText: 'Daftar desa tidak dapat dimuat.',
        filled: true,
        fillColor: AppColors.fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          label: Text(
            'Muat ulang',
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final metric in borderPath.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 9) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
