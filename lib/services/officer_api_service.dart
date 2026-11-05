import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/app_config.dart';
import '../models/officer_dashboard_data.dart';
import '../models/risk_score.dart';
import '../models/visit_schedule.dart';

/// API petugas untuk dashboard, tugas warga, STBM desa, dan inspeksi IKL.
class OfficerApiService {
  OfficerApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Uri _configuredUri = Uri.parse(AppConfig.apiBaseUrl.trim());

  Future<Map<String, dynamic>> loginOfficer({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      _legacyEndpoint('petugas/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );
    return _decode(response);
  }

  Future<void> logoutOfficer(String token) async {
    final response = await _requestWithFallback(
      () => _client.post(
        _officerEndpoint('logout'),
        headers: _authHeaders(token),
      ),
      () => _client.post(
        _legacyEndpoint('auth/logout'),
        headers: _authHeaders(token),
      ),
    );
    _decode(response);
  }

  Future<OfficerDashboardData> getDashboard(String token) async {
    final response = await _requestWithFallback(
      () => _client.get(
        _officerEndpoint('dashboard'),
        headers: _authHeaders(token),
      ),
      () => _client.get(
        _legacyEndpoint('petugas/jadwal'),
        headers: _authHeaders(token),
      ),
    );
    return OfficerDashboardData.fromJson(_decode(response));
  }

  Future<List<VisitSchedule>> getTasks(String token) async {
    final response = await _requestWithFallback(
      () =>
          _client.get(_officerEndpoint('tasks'), headers: _authHeaders(token)),
      () => _client.get(
        _legacyEndpoint('petugas/jadwal'),
        headers: _authHeaders(token),
      ),
    );
    return _extractSchedules(_decode(response));
  }

  /// Alias untuk kompatibilitas dengan pemanggil service sebelumnya.
  Future<List<VisitSchedule>> getMySchedules(String token) => getTasks(token);

  Future<List<StbmDesa>> getStbmDesa(String token) async {
    final response = await _requestWithFallback(
      () => _client.get(
        _officerEndpoint('stbm-desa'),
        headers: _authHeaders(token),
      ),
      () => _client.get(_legacyEndpoint('desa'), headers: _authHeaders(token)),
    );
    final body = _decode(response);
    final payload = body['data'] ?? body['desa'];
    if (payload is! List) return const [];
    return payload
        .whereType<Map>()
        .map((row) => StbmDesa.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<void> verifyReport({
    required String token,
    required int reportId,
    String note = '',
  }) async {
    final response = await _requestWithFallback(
      () => _client.post(
        _officerEndpoint('reports/$reportId/verify'),
        headers: _authHeaders(token),
        body: jsonEncode({'catatan_petugas': note}),
      ),
      () => _client.post(
        _legacyEndpoint('petugas/jadwal/$reportId/update'),
        headers: _authHeaders(token),
        body: jsonEncode({
          'status_kunjungan': 'diproses',
          'catatan_petugas': note,
        }),
      ),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> submitInspection({
    required String token,
    required int scheduleId,
    required String waterSource,
    required int pollutantDistance,
    required List<bool> riskIndicators,
    required String inspectionDate,
    required String intervention,
    required String interventionNote,
    required String recommendation,
    required String officerNote,
    XFile? photo,
  }) async {
    RiskScore.total(riskIndicators);
    final payload = <String, dynamic>{
      'id_jadwal': scheduleId,
      'jenis_sarana_air': waterSource,
      'jarak_sumber_pencemar': pollutantDistance,
      'tanggal_inspeksi': inspectionDate,
      for (var index = 0; index < RiskScore.fields.length; index++)
        RiskScore.fields[index]: riskIndicators[index],
      'intervensi_fisik': intervention,
      'catatan_intervensi': interventionNote,
      'rekomendasi_sanitarian': recommendation,
      'catatan_petugas': officerNote,
    };
    final http.Response response;
    if (photo == null) {
      response = await _client.post(
        _officerEndpoint('inspections'),
        headers: _authHeaders(token),
        body: jsonEncode(payload),
      );
    } else {
      final request = http.MultipartRequest('POST', _officerEndpoint('inspections'))
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        })
        ..fields.addAll({
          for (final entry in payload.entries)
            entry.key: entry.value is bool
                ? (entry.value == true ? '1' : '0')
                : entry.value.toString(),
        })
        ..files.add(http.MultipartFile.fromBytes(
          'foto_bukti',
          await photo.readAsBytes(),
          filename: photo.name,
        ));
      response = await http.Response.fromStream(await _client.send(request));
    }
    final body = _decode(response);
    final data = body['data'];
    if (data is! Map || data['status_kunjungan'] != 'selesai') {
      throw const ApiOfficerException(
        'Konfirmasi hasil inspeksi tidak lengkap. Segarkan daftar jadwal sebelum mencoba lagi.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> submitVisitResult({
    required String token,
    required int scheduleId,
    required String status,
    required String officerNote,
    XFile? photo,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            _legacyEndpoint('petugas/jadwal/$scheduleId/update'),
          )
          ..headers.addAll(_authHeaders(token))
          ..fields['status_kunjungan'] = status
          ..fields['catatan_petugas'] = officerNote;

    if (photo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_bukti', photo.path),
      );
    }

    final streamed = await _client.send(request);
    _decode(await http.Response.fromStream(streamed));
  }

  Future<http.Response> _requestWithFallback(
    Future<http.Response> Function() primary,
    Future<http.Response> Function() fallback,
  ) async {
    final response = await primary();
    if (response.statusCode != 404 && response.statusCode != 405) {
      return response;
    }
    return fallback();
  }

  List<VisitSchedule> _extractSchedules(Map<String, dynamic> body) {
    final payload = body['data'] ?? body['tasks'] ?? body['jadwal'];
    if (payload is Map) {
      final nested = payload['tasks'] ?? payload['jadwal'] ?? payload['data'];
      if (nested is List) return _scheduleList(nested);
    }
    if (payload is List) return _scheduleList(payload);
    return const [];
  }

  List<VisitSchedule> _scheduleList(List<dynamic> rows) => rows
      .whereType<Map>()
      .map((row) => VisitSchedule.fromJson(Map<String, dynamic>.from(row)))
      .toList(growable: false);

  Uri _officerEndpoint(String path) {
    final configuredPath = _configuredUri.path.replaceFirst(RegExp(r'/+$'), '');
    final apiPath = configuredPath.endsWith('/api/v1')
        ? configuredPath
        : configuredPath.endsWith('/api')
        ? '$configuredPath/v1'
        : '$configuredPath/api/v1';
    return _configuredUri.replace(path: '$apiPath/officer/$path');
  }

  Uri _legacyEndpoint(String path) {
    var basePath = _configuredUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (basePath.endsWith('/api/v1')) {
      basePath = basePath.substring(0, basePath.length - 3);
    }
    return _configuredUri.replace(path: '$basePath/$path');
  }

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Map<String, String> _authHeaders(String token) => {
    ..._jsonHeaders,
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    if (response.body.trim().isEmpty &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      body = const {};
    } else {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw const FormatException('Respons bukan objek JSON.');
        }
        body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        throw ApiOfficerException(
          'Respons server tidak dapat dibaca.',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = body['errors'];
      final firstError = errors is Map
          ? errors.values
                .whereType<List>()
                .expand((messages) => messages)
                .whereType<String>()
                .firstOrNull
          : null;
      final message = body['message'];
      final serverMessage = firstError ?? (message is String ? message : null);
      throw ApiOfficerException(
        _userFacingErrorMessage(serverMessage),
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  String _userFacingErrorMessage(String? message) {
    if (message == null || message.trim().isEmpty) {
      return 'Permintaan gagal. Coba lagi.';
    }
    final normalized = message.toLowerCase();
    if (normalized.contains('sqlstate[') ||
        normalized.contains('unknown column')) {
      return 'Data jadwal belum dapat dimuat. Hubungi admin untuk memeriksa konfigurasi server.';
    }
    return message;
  }
}

class ApiOfficerException implements Exception {
  const ApiOfficerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
