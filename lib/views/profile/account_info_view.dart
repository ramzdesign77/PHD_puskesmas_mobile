import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/saved_address.dart';
import '../../models/village.dart';
import '../../services/api_service.dart';
import '../../services/profile_service.dart';
import 'profile_widgets.dart';

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                ProfilePageHeader(
                  title: 'Informasi akun',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.home_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Alamat Saya',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_isLoadingAddress)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        tooltip: 'Muat ulang alamat',
                        onPressed: _loadAddress,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_addressError != null)
                  Container(
                    key: const Key('saved_address_load_error'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _addressError!,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                Form(
                  key: _formKey,
                  child: ProfileCard(
                    child: FutureBuilder<List<Village>>(
                      future: _villages,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Daftar desa belum dapat dimuat.',
                                style: TextStyle(color: AppColors.ink),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _villages = _apiService.getVillages(),
                                ),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final villages = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<Village>(
                              key: ValueKey(
                                'saved_address_village_${_selectedVillage?.id ?? 'none'}',
                              ),
                              initialValue: _selectedVillage,
                              decoration: const InputDecoration(
                                labelText: 'Desa / Kelurahan',
                                prefixIcon: Icon(Icons.location_on_outlined),
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
                                  : (village) => setState(
                                      () => _selectedVillage = village,
                                    ),
                              validator: (value) => value == null
                                  ? 'Pilih desa atau kelurahan.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'saved_address_rt_$_selectedRt',
                                    ),
                                    initialValue: _selectedRt,
                                    decoration: const InputDecoration(
                                      labelText: 'RT',
                                      prefixIcon: Icon(
                                        Icons.location_on_outlined,
                                      ),
                                    ),
                                    items:
                                        List.generate(
                                              30,
                                              (index) => (index + 1)
                                                  .toString()
                                                  .padLeft(2, '0'),
                                            )
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text('RT $value'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _isSaving
                                        ? null
                                        : (value) => setState(
                                            () => _selectedRt = value,
                                          ),
                                    validator: _required,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'saved_address_rw_$_selectedRw',
                                    ),
                                    initialValue: _selectedRw,
                                    decoration: const InputDecoration(
                                      labelText: 'RW',
                                      prefixIcon: Icon(Icons.home_outlined),
                                    ),
                                    items:
                                        List.generate(
                                              20,
                                              (index) => (index + 1)
                                                  .toString()
                                                  .padLeft(2, '0'),
                                            )
                                            .map(
                                              (value) => DropdownMenuItem(
                                                value: value,
                                                child: Text('RW $value'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _isSaving
                                        ? null
                                        : (value) => setState(
                                            () => _selectedRw = value,
                                          ),
                                    validator: _required,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const Key('saved_address_detail_field'),
                              controller: _detail,
                              enabled: !_isSaving,
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Patokan / Detail Alamat',
                                hintText: 'Masukkan patokan atau detail alamat',
                                prefixIcon: Icon(Icons.signpost_outlined),
                                alignLabelWithHint: true,
                              ),
                              validator: _required,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Alamat'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
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
