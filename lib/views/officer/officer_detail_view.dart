import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/risk_score.dart';
import '../../models/visit_schedule.dart';
import '../../services/officer_api_service.dart';
import '../../theme/app_theme.dart';

class OfficerDetailView extends StatefulWidget {
  const OfficerDetailView({
    super.key,
    required this.schedule,
    required this.token,
    required this.apiService,
  });

  final VisitSchedule schedule;
  final String token;
  final OfficerApiService apiService;

  @override
  State<OfficerDetailView> createState() => _OfficerDetailViewState();
}

class _OfficerDetailViewState extends State<OfficerDetailView> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _interventionNoteController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _legacyNoteController = TextEditingController();
  final _picker = ImagePicker();
  final List<bool> _riskIndicators = List<bool>.filled(7, false);

  String _waterSource = 'sumur_gali';
  late String _categoryIkl;
  String _intervention = 'Tidak Ada';
  DateTime _inspectionDate = DateTime.now();
  Uint8List? _photoBytes;
  XFile? _pickedPhoto;
  bool _isSubmitting = false;

  static const _waterSources = {
    'sumur_gali': 'Sumur Gali',
    'sumur_terlindung': 'Sumur Terlindung',
    'sumur_bor': 'Sumur Bor',
    'pdam': 'Perpipaan / PDAM',
    'mata_air': 'Mata Air',
    'lainnya': 'Lainnya',
  };
  static const _interventions = [
    'Pembagian Kaporit',
    'Pembagian Bubuk Abate',
    'Edukasi STBM / PAMMRT',
    'Pemberantasan Sarang Nyamuk (PSN)',
    'Tidak Ada',
  ];
  List<String> get _riskLabels => RiskScore.questionsFor(_categoryIkl);

  int get _riskScore => RiskScore.totalDynamic(_riskIndicators);
  bool get _urgentWaterFinding =>
      _categoryIkl == 'sumur_bor' && _riskIndicators[6];
  String get _riskCategory => RiskScore.dynamicCategory(
    _riskScore,
    urgentWaterFinding: _urgentWaterFinding,
  );

  Color get _riskColor {
    return switch (_riskCategory) {
      'aman' => const Color(0xFF16A34A),
      'risiko_sedang' => const Color(0xFFD97706),
      'risiko_tinggi' => const Color(0xFFDC2626),
      _ => const Color(0xFF7F1D1D),
    };
  }

  String get _riskTitle => RiskScore.label(_riskCategory);
  String get _riskDescription => switch (_riskCategory) {
    'aman' => 'Kondisi sanitasi memenuhi syarat kesehatan. Tetap jaga kebersihan dan lakukan pemantauan rutin.',
    'risiko_sedang' => 'Terdapat potensi cemaran ringan. Disarankan edukasi perilaku higienis dan perbaikan fisik mandiri.',
    'risiko_tinggi' => 'Kondisi berisiko tinggi mencemari kesehatan. Perlu intervensi Puskesmas (Kaporit/Abate/KIE) dan perbaikan segera.',
    _ => 'Bahaya cemaran nyata! Air/sarana sangat berisiko menularkan penyakit dan wajib segera diintervensi.',
  };

  @override
  void initState() {
    super.initState();
    _categoryIkl = _detectIklCategory(widget.schedule);
    _waterSource = _categoryIkl == 'sumur_bor' ? 'sumur_bor' : 'sumur_gali';
    _legacyNoteController.text = widget.schedule.officerNote;
  }

  String _detectIklCategory(VisitSchedule schedule) {
    final raw = '${schedule.categoryCode ?? ''} ${schedule.category} ${schedule.description}'
        .toLowerCase()
        .replaceAll('_', ' ');
    if (raw.contains('dbd') || raw.contains('nyamuk') || raw.contains('jentik')) {
      return 'sarang_nyamuk_dbd';
    }
    if (raw.contains('jamban') || raw.contains('limbah') || raw.contains('stbm')) {
      return 'jamban_limbah_stbm';
    }
    if (raw.contains('sampah')) return 'tumpukan_sampah';
    if (raw.contains('bor') || raw.contains('pompa')) return 'sumur_bor';
    return 'sumur_gali';
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _interventionNoteController.dispose();
    _recommendationController.dispose();
    _legacyNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (mounted) {
          setState(() {
            _pickedPhoto = photo;
            _photoBytes = bytes;
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal membuka kamera: $error', isError: true);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    if (widget.schedule.scheduleId == null) {
      _showMessage(
        'Laporan ini belum memiliki ID jadwal inspeksi. Hubungi admin.',
        isError: true,
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final pollutantDistance =
          int.tryParse(_distanceController.text.trim()) ?? 0;
      final result = await widget.apiService.submitInspection(
        token: widget.token,
        scheduleId: widget.schedule.scheduleId!,
        reportId: widget.schedule.id,
        categoryIkl: _categoryIkl,
        indicatorQuestions: _riskLabels,
        waterSource: _waterSource,
        pollutantDistance: pollutantDistance,
        riskIndicators: List.unmodifiable(_riskIndicators),
        inspectionDate: _inspectionDate.toIso8601String().substring(0, 10),
        intervention: _intervention,
        interventionNote: _interventionNoteController.text.trim(),
        recommendation: _recommendationController.text.trim(),
        officerNote: _legacyNoteController.text.trim(),
        photo: _pickedPhoto,
      );
      if (!mounted) return;
      final riskLabel = RiskScore.label(result['kategori_risiko'] as String?);
      _showMessage('Hasil IKL tersimpan. Risiko: $riskLabel.');
      Navigator.of(context).pop(true);
    } on ApiOfficerException catch (error) {
      if (mounted) {
        _showMessage(error.message, isError: true);
      }
    } on FormatException catch (error) {
      if (mounted) {
        _showMessage(
          'Data IKL tidak dapat dibaca. Periksa kembali jarak sumber pencemar. ${error.message}',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal mengirim form IKL: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickInspectionDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _inspectionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _inspectionDate = date);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primaryDark : AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          schedule.ticketCode.isEmpty
              ? 'Form Inspeksi IKL'
              : schedule.ticketCode,
          style: const TextStyle(
            fontFamily: AppTheme.headlineFontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ).asHeading,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _sectionTitle('Informasi Laporan / Jadwal'),
            const SizedBox(height: 10),
            _buildScheduleCard(schedule),
            const SizedBox(height: 22),
            _sectionTitle('Kuesioner Inspeksi Kesehatan Lingkungan'),
            const SizedBox(height: 10),
            _buildWaterSourceCard(),
            const SizedBox(height: 14),
            _buildRiskIndicators(),
            const SizedBox(height: 14),
            _buildRiskScore(),
            const SizedBox(height: 22),
            _sectionTitle('Intervensi dan Rekomendasi'),
            const SizedBox(height: 10),
            _buildInterventionFields(),
            const SizedBox(height: 14),
            _buildLegacyVisitFields(),
            const SizedBox(height: 22),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _canSubmit ? 1 : 0.55,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  key: const Key('officer_submit_button'),
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan Hasil IKL',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_isSubmitting &&
      !const [
        'selesai',
        'batal',
      ].contains(widget.schedule.status.toLowerCase());

  Widget _buildScheduleCard(VisitSchedule schedule) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Nama Pelapor', value: schedule.reporterName),
          _InfoRow(label: 'Kategori', value: schedule.category),
          _InfoRow(label: 'Desa', value: schedule.village),
          _InfoRow(label: 'Alamat', value: schedule.address),
          _InfoRow(
            label: 'RT / RW',
            value: 'RT ${schedule.rt} / RW ${schedule.rw}',
          ),
          _InfoRow(label: 'Tanggal Kunjungan', value: schedule.visitDate),
          _InfoRow(
            label: 'Keterangan',
            value: schedule.description,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterSourceCard() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Jenis Formulir IKL'),
          const SizedBox(height: 8),
          if (_categoryIkl == 'sumur_gali' || _categoryIkl == 'sumur_bor')
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('1A. Sumur Gali'),
                  selected: _categoryIkl == 'sumur_gali',
                  onSelected: (_) => setState(() {
                    _categoryIkl = 'sumur_gali';
                    _waterSource = 'sumur_gali';
                    _riskIndicators.fillRange(0, 7, false);
                  }),
                ),
                ChoiceChip(
                  label: const Text('1B. Sumur Bor / Pompa'),
                  selected: _categoryIkl == 'sumur_bor',
                  onSelected: (_) => setState(() {
                    _categoryIkl = 'sumur_bor';
                    _waterSource = 'sumur_bor';
                    _riskIndicators.fillRange(0, 7, false);
                  }),
                ),
              ],
            )
          else
            Chip(
              label: Text(switch (_categoryIkl) {
                'sarang_nyamuk_dbd' => '2. Sarang Nyamuk / Indikasi DBD',
                'jamban_limbah_stbm' => '3. Masalah Jamban & Limbah (STBM)',
                _ => '4. Tumpukan Sampah',
              }),
              backgroundColor: AppColors.softBlue,
            ),
          const SizedBox(height: 12),
          const _FieldLabel(text: 'Jenis Sarana Air (kompatibilitas API)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('officer_water_source_dropdown'),
            initialValue: _waterSource,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.water_drop_outlined),
              isDense: true,
            ),
            items: _waterSources.entries
                .map(
                  (source) => DropdownMenuItem(
                    value: source.key,
                    child: Text(source.value),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _waterSource = value);
            },
          ),
          const SizedBox(height: 15),
          const _FieldLabel(text: 'Jarak ke Sumber Pencemar'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_pollutant_distance_field'),
            controller: _distanceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final distance = int.tryParse(value?.trim() ?? '');
              if (distance == null || distance < 0 || distance > 99999) {
                return 'Masukkan jarak bulat 0–99999 meter.';
              }
              return null;
            },
            decoration: const InputDecoration(
              hintText: 'Contoh: 10 (meter bulat)',
              suffixText: 'meter',
              prefixIcon: Icon(Icons.straighten_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskIndicators() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(text: '7 Indikator Risiko — ${_riskTitle}'),
          const SizedBox(height: 4),
          const Text(
            'Jawab Ya jika kondisi berisiko ditemukan; setiap Ya bernilai 1 poin.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _riskLabels.length; index++)
            CheckboxListTile(
              key: Key('officer_ikl_p${index + 1}'),
              value: _riskIndicators[index],
              onChanged: (value) =>
                  setState(() => _riskIndicators[index] = value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: false,
              activeColor: AppColors.primary,
              selected: _riskIndicators[index],
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: Colors.white,
              selectedTileColor: AppColors.softBlue.withValues(alpha: 0.8),
              visualDensity: const VisualDensity(vertical: -1),
              title: Text(
                _riskLabels[index],
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskScore() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _riskColor.withValues(alpha: 0.1),
        border: Border.all(color: _riskColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.health_and_safety_outlined, color: _riskColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perkiraan Skor Risiko',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  _riskTitle,
                  style: TextStyle(
                    color: _riskColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _riskDescription,
                  style: TextStyle(color: _riskColor, fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
          Text(
            '$_riskScore/7',
            style: TextStyle(
              color: _riskColor,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionFields() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Intervensi Fisik'),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('officer_intervention_choices'),
            spacing: 8,
            runSpacing: 8,
            children: _interventions
                .map((intervention) {
                  final selected = _intervention == intervention;
                  return ChoiceChip(
                    label: Text(intervention),
                    selected: selected,
                    selectedColor: AppColors.softBlue,
                    backgroundColor: AppColors.canvas,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.line,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : AppColors.ink,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                    onSelected: (_) {
                      setState(() => _intervention = intervention);
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          const _FieldLabel(text: 'Catatan Intervensi'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_intervention_note_field'),
            controller: _interventionNoteController,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Dosis Kaporit/Abate, jumlah, dan tindakan...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel(text: 'Rekomendasi Sanitarian'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_recommendation_field'),
            controller: _recommendationController,
            maxLines: 3,
            maxLength: 2000,
            validator: (value) => (value?.trim().length ?? 0) < 5
                ? 'Rekomendasi minimal 5 karakter.'
                : null,
            decoration: const InputDecoration(
              hintText: 'Tulis tindak lanjut dan edukasi yang disarankan...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyVisitFields() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Tanggal Inspeksi'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(_inspectionDate.toIso8601String().substring(0, 10)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _isSubmitting ? null : _pickInspectionDate,
          ),
          const Text(
            'Menyimpan hasil IKL akan menyelesaikan jadwal dan laporan terkait.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const _FieldLabel(text: 'Foto Bukti Kunjungan (opsional)'),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('officer_photo_picker'),
            borderRadius: BorderRadius.circular(20),
            onTap: _pickPhoto,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _pickedPhoto == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Ketuk untuk mengambil foto',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                    ),
            ),
          ),
          if (_pickedPhoto != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  _pickedPhoto = null;
                  _photoBytes = null;
                }),
                child: const Text('Hapus foto'),
              ),
            ),
          const SizedBox(height: 12),
          const _FieldLabel(text: 'Catatan Kunjungan'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_note_field'),
            controller: _legacyNoteController,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Catatan tambahan kunjungan lapangan...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 19,
          width: 4,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTheme.headlineFontFamily,
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ).asHeading,
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 117,
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
    );
  }
}
