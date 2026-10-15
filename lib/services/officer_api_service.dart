import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/app_config.dart';
import '../models/visit_schedule.dart';

/// Service API khusus untuk fitur Petugas (Officer).
/// Terpisah dari ApiService warga agar tidak saling mengotori.
class OfficerApiService {
  OfficerApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Uri _baseUri = Uri.parse(
    '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/',
  );

  // ──────────────────────────────────────────────────────────────────
  // AUTH
  // ──────────────────────────────────────────────────────────────────

  /// Login khusus petugas. Mengembalikan Map berisi 'token' dan 'user'.
  Future<Map<String, dynamic>> loginOfficer({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      _endpoint('petugas/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
      }),
    );
    return _decode(response);
  }

  /// Logout petugas, membatalkan token di server.
  Future<void> logoutOfficer(String token) async {
    await _client.post(
      _endpoint('petugas/logout'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // JADWAL KUNJUNGAN
  // ──────────────────────────────────────────────────────────────────

  /// Ambil semua jadwal kunjungan yang ditugaskan ke petugas yang sedang login.
  Future<List<VisitSchedule>> getMySchedules(String token) async {
    final response = await _client.get(
      _endpoint('petugas/jadwal'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final body = _decode(response);
    final rows = body['data'] as List<dynamic>? ?? [];
    return rows
        .map((row) => VisitSchedule.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ──────────────────────────────────────────────────────────────────
  // AKSI PETUGAS — Submit Laporan Hasil Kunjungan
  // ──────────────────────────────────────────────────────────────────

  /// Kirim hasil kunjungan ke backend menggunakan multipart/form-data.
  /// [scheduleId]  : ID jadwal yang dikerjakan
  /// [status]      : 'diproses' atau 'selesai'
  /// [officerNote] : catatan / rekomendasi petugas
  /// [photo]       : foto bukti kunjungan (opsional)
  Future<void> submitVisitResult({
    required String token,
    required int scheduleId,
    required String status,
    required String officerNote,
    XFile? photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _endpoint('petugas/jadwal/$scheduleId/update'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['status_kunjungan'] = status
      ..fields['catatan_petugas'] = officerNote;

    if (photo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_bukti', photo.path),
      );
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    _decode(response); // lempar ApiOfficerException jika gagal
  }

  // ──────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────

  Uri _endpoint(String path) => _baseUri.resolve(path);

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiOfficerException(
        'Respons server tidak dapat dibaca.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = body['errors'] as Map<String, dynamic>?;
      final firstError = errors?.values
          .whereType<List<dynamic>>()
          .expand((msgs) => msgs)
          .whereType<String>()
          .firstOrNull;
      throw ApiOfficerException(
        firstError ??
            body['message'] as String? ??
            'Permintaan gagal. Coba lagi.',
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}

class ApiOfficerException implements Exception {
  const ApiOfficerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
