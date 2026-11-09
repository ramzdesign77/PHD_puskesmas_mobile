import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/saved_address.dart';
import '../../models/village.dart';
import '../../services/api_service.dart';
import '../../services/profile_service.dart';

class AccountInfoView extends StatefulWidget {
  const AccountInfoView({
    super.key,
    required this.profile,
    required this.profileService,
    this.apiService,
  });

  final LocalProfile profile;
  final ProfileService profileService;
  final ApiService? apiService;

  @override
  State<AccountInfoView> createState() => _AccountInfoViewState();
}

class _AccountInfoViewState extends State<AccountInfoView> {
  final _formKey = GlobalKey<FormState>();
  final _detail = TextEditingController();
  late final ApiService _apiService = widget.apiService ?? ApiService();
  late Future<List<Village>> _villages;
  Village? _selectedVillage;
  String? _selectedRt;
  String? _selectedRw;
  bool _isLoadingAddress = true;
  bool _isSaving = false;
  bool _hasSavedAddress = false;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _villages = _apiService.getVillages();
    _loadAddress();
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    setState(() {
      _isLoadingAddress = true;
      _addressError = null;
    });
    try {
      final address = await widget.profileService.loadSavedAddress();
      if (!mounted) return;
      setState(() {
        _detail.text = address?.detail ?? '';
        _hasSavedAddress = address != null;
        _selectedVillage = null;
        _selectedRt = address?.rt.trim().padLeft(2, '0');
        _selectedRw = address?.rw.trim().padLeft(2, '0');
        _isLoadingAddress = false;
      });
      if (address != null) {
        final villages = await _villages;
        if (!mounted) return;
        setState(() {
          for (final village in villages) {
            if (village.id == address.villageId) {
              _selectedVillage = village;
              break;
            }
          }
        });
      }
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _addressError = error.message;
        _isLoadingAddress = false;
      });
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() {
        _addressError = 'Alamat belum dapat dimuat. Periksa koneksi internet.';
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _saveAddress() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final village = _selectedVillage;
    if (village == null) {
      _showMessage('Pilih desa atau kelurahan terlebih dahulu.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final saved = await widget.profileService.saveAddress(
        SavedAddress(
          villageId: village.id,
          villageName: village.name,
          rt: _selectedRt!,
          rw: _selectedRw!,
          detail: _detail.text.trim(),
        ),
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() {
        _selectedVillage = village;
        _hasSavedAddress = true;
        _selectedRt = saved.rt.trim().padLeft(2, '0');
        _selectedRw = saved.rw.trim().padLeft(2, '0');
        _detail.text = saved.detail;
        _addressError = null;
      });
      _showMessage('Alamat berhasil disimpan.');
    } on ProfileException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception catch (_) {
      if (mounted) {
        _showMessage('Alamat gagal disimpan. Periksa koneksi internet.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    key: const Key('saved_address_scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _buildAddressCard(),
                      const SizedBox(height: 16),
                      _buildPrivacyNote(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: textScale > 1.15 ? 190 : 170,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primary],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
            ),
          ),
          Positioned(top: -50, right: -28, child: _HeaderBubble(size: 152)),
          Positioned(bottom: -72, left: 34, child: _HeaderBubble(size: 118)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Muat ulang alamat',
                      onPressed: _isLoadingAddress ? null : _loadAddress,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                      ),
                      icon: _isLoadingAddress
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Alamat',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Atur alamat rumah untuk laporan lebih cepat',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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

  Widget _buildAddressCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: AppColors.primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alamat Saya',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dipakai sebagai lokasi utama saat membuat laporan.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _hasSavedAddress
                      ? const Color(0xFFEAF7F0)
                      : AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _hasSavedAddress
                        ? const Color(0xFFCBE9D8)
                        : AppColors.line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasSavedAddress
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 14,
                      color: _hasSavedAddress
                          ? AppColors.green
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _hasSavedAddress
                            ? 'Alamat tersimpan'
                            : 'Belum tersimpan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _hasSavedAddress
                              ? AppColors.green
                              : AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_addressError != null) ...[
              Container(
                key: const Key('saved_address_load_error'),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF5D6A8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _addressError!,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            FutureBuilder<List<Village>>(
              future: _villages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftar desa belum dapat dimuat.',
                          style: TextStyle(color: AppColors.ink, fontSize: 13),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _villages = _apiService.getVillages(),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final villages = snapshot.data!;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fieldLabel('WILAYAH'),
                      DropdownButtonFormField<Village>(
                        isExpanded: true,
                        key: ValueKey(
                          'saved_address_village_${_selectedVillage?.id ?? 'none'}',
                        ),
                        initialValue: _selectedVillage,
                        decoration: const InputDecoration(
                          labelText: 'Desa / Kelurahan',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                        items: villages
                            .map(
                              (village) => DropdownMenuItem(
                                value: village,
                                child: Text(
                                  village.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (village) =>
                                  setState(() => _selectedVillage = village),
                        validator: (value) =>
                            value == null ? 'Pilih desa atau kelurahan.' : null,
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('LINGKUNGAN'),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 360;
                          if (stacked) {
                            return Column(
                              children: [
                                _buildRtField(),
                                const SizedBox(height: 12),
                                _buildRwField(),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: _buildRtField()),
                              const SizedBox(width: 10),
                              Expanded(child: _buildRwField()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('PATOKAN'),
                      TextFormField(
                        key: const Key('saved_address_detail_field'),
                        controller: _detail,
                        enabled: !_isSaving,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        minLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Patokan / Detail Alamat',
                          hintText: 'Contoh: dekat balai desa',
                          prefixIcon: Icon(Icons.signpost_outlined),
                          alignLabelWithHint: true,
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('saved_address_save_button'),
                        onPressed: _isSaving || _isLoadingAddress
                            ? null
                            : _saveAddress,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          _isSaving ? 'Menyimpan alamat...' : 'Simpan Alamat',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.9,
      ),
    ),
  );

  Widget _buildRtField() => DropdownButtonFormField<String>(
    key: ValueKey('saved_address_rt_$_selectedRt'),
    isExpanded: true,
    initialValue: _selectedRt,
    decoration: const InputDecoration(
      labelText: 'RT',
      prefixIcon: Icon(Icons.location_on_outlined),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    items: List.generate(30, (index) => (index + 1).toString().padLeft(2, '0'))
        .map(
          (value) => DropdownMenuItem(
            value: value,
            child: Text('RT $value', overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: _isSaving
        ? null
        : (value) => setState(() => _selectedRt = value),
    validator: _required,
  );

  Widget _buildRwField() => DropdownButtonFormField<String>(
    key: ValueKey('saved_address_rw_$_selectedRw'),
    isExpanded: true,
    initialValue: _selectedRw,
    decoration: const InputDecoration(
      labelText: 'RW',
      prefixIcon: Icon(Icons.home_outlined),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    items: List.generate(20, (index) => (index + 1).toString().padLeft(2, '0'))
        .map(
          (value) => DropdownMenuItem(
            value: value,
            child: Text('RW $value', overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: _isSaving
        ? null
        : (value) => setState(() => _selectedRw = value),
    validator: _required,
  );

  Widget _buildPrivacyNote() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Alamat akun hanya digunakan sebagai lokasi awal. Anda tetap bisa memilih lokasi lain saat membuat laporan.',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _HeaderBubble extends StatelessWidget {
  const _HeaderBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
      color: Colors.white.withValues(alpha: 0.05),
    ),
  );
}
