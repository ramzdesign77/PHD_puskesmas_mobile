import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/education_article.dart';
import '../models/ticket_status.dart';
import '../models/village.dart';
import 'profile_service.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _userNameKey = 'auth_user_name';
  static const _userPhoneKey = 'auth_user_phone';
  static const _userVillageKey = 'auth_user_village';
  static const _userRtKey = 'auth_user_rt';
  static const _userRwKey = 'auth_user_rw';
  static const _rolesKey = 'auth_roles';
  static const _savedCitizenTicketsKey = 'saved_citizen_tickets';
  static const _ticketCachePrefix = 'citizen_ticket_cache_';
  static const _cachedCitizenTicketStatusesKey =
      'cached_citizen_ticket_statuses';
  final Uri _baseUri = Uri.parse(
    '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/',
  );

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _postLogin(
      'auth/login',
      identifier: identifier,
      password: password,
    );

    if (response.statusCode == 401 || response.statusCode == 404) {
      final officerResponse = await _postLogin(
        'petugas/login',
        identifier: identifier,
        password: password,
      );
      return _saveSession(_decode(officerResponse), fallbackRole: 'petugas');
    }

    return _saveSession(_decode(response), fallbackRole: 'warga');
  }

  Future<Map<String, dynamic>> register({
    required String namaLengkap,
    required String username,
    required String email,
    required String password,
    required String phone,
  }) async {
    final requestBody = {
      'nama_lengkap': namaLengkap.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': password,
      'no_telepon': phone.trim(),
    };
    final response = await _client.post(
      _endpoint('auth/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );
    return _saveSession(
      _decode(response),
      fallbackRole: 'warga',
      fallbackName: namaLengkap,
      fallbackUsername: username,
      fallbackEmail: email,
      fallbackPhone: phone,
    );
  }

  Future<http.Response> _postLogin(
    String path, {
    required String identifier,
    required String password,
  }) {
    return _client.post(
      _endpoint(path),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );
  }

  Future<Map<String, dynamic>> _saveSession(
    Map<String, dynamic> response, {
    required String fallbackRole,
    String? fallbackName,
    String? fallbackUsername,
    String? fallbackEmail,
    String? fallbackPhone,
  }) async {
    final data = response['data'] as Map<String, dynamic>?;
    final token = response['token'] as String? ?? data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Token login tidak diterima server.');
    }

    final user = _userFromResponse(response);
    final role = _roleFromResponse(response) ?? fallbackRole;
    final userName =
        _firstNonEmptyString([user['nama_lengkap'], user['name']]) ??
        fallbackName?.trim() ??
        '';
    final preferences = await SharedPreferences.getInstance();
    final tokenSaved = await preferences.setString(_tokenKey, token);
    final roleSaved = await preferences.setString(_roleKey, role);
    await preferences.setString(
      _userPhoneKey,
      user['no_telepon'] as String? ??
          user['no_wa'] as String? ??
          user['no_hp'] as String? ??
          user['phone'] as String? ??
          '',
    );
    await preferences.setString(
      _userVillageKey,
      user['nama_desa'] as String? ?? user['desa'] as String? ?? '',
    );
    await preferences.setString(_userRtKey, user['rt']?.toString() ?? '');
    await preferences.setString(_userRwKey, user['rw']?.toString() ?? '');
    final profileSaved = await ProfileService.replaceForSession(
      preferences,
      name: userName,
      email: _firstNonEmptyString([user['email']]) ?? fallbackEmail?.trim(),
      phone:
          _firstNonEmptyString([
            user['no_telepon'],
            user['phone'],
            user['phone_number'],
            user['no_hp'],
            user['nomor_telepon'],
          ]) ??
          fallbackPhone?.trim(),
      username:
          _firstNonEmptyString([user['username']]) ?? fallbackUsername?.trim(),
    );
    if (!tokenSaved || !roleSaved || !profileSaved) {
      await clearSavedSession();
      throw const ApiException(
        'Sesi login tidak dapat disimpan pada perangkat.',
      );
    }

    return {...response, 'token': token, 'role': role};
  }

  String? _firstNonEmptyString(Iterable<Object?> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<AuthSession?> loadSavedSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;

    return AuthSession(
      token: token,
      role: preferences.getString(_roleKey) ?? 'warga',
      userName: preferences.getString(_userNameKey) ?? '',
      phone: preferences.getString(_userPhoneKey),
      villageName: preferences.getString(_userVillageKey),
      rt: preferences.getString(_userRtKey),
      rw: preferences.getString(_userRwKey),
    );
  }

  static Future<void> clearSavedSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
    await ProfileService.clearForSession(preferences);
    await preferences.remove(_rolesKey);
    await preferences.remove(_userPhoneKey);
    await preferences.remove(_userVillageKey);
    await preferences.remove(_userRtKey);
    await preferences.remove(_userRwKey);
  }

  static bool isOfficerRole(String? role) {
    return (role ?? '')
        .split(',')
        .any(
          (value) => const {
            'petugas',
            'sanitarian',
            'staf_backup_kluster4',
            'admin',
            'kepala_puskesmas',
          }.contains(value.trim().toLowerCase()),
        );
  }

  Map<String, dynamic> _userFromResponse(Map<String, dynamic> response) {
    final user = response['user'];
    if (user is Map<String, dynamic>) return user;

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) return nestedUser;
      return data;
    }
    return const {};
  }

  String? _roleFromResponse(Map<String, dynamic> response) {
    final user = _userFromResponse(response);
    final data = response['data'] as Map<String, dynamic>?;
    final role =
        response['role'] ??
        response['level'] ??
        user['role'] ??
        user['level'] ??
        data?['role'] ??
        data?['level'];
    return role is String && role.trim().isNotEmpty
        ? role.trim().toLowerCase()
        : null;
  }

  Future<void> logout(String token) async {
    final response = await _client.post(
      _endpoint('auth/logout'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    _decode(response);
  }

  Future<List<EducationArticle>> getArticles() async {
    final response = await _client.get(
      _endpoint('edukasi'),
      headers: {'Accept': 'application/json'},
    );
    final body = _decode(response);
    final rows = body['data'] as List<dynamic>? ?? [];

    return rows
        .map(
          (row) =>
              EducationArticle.fromJson(row as Map<String, dynamic>, _baseUri),
        )
        .toList();
  }

  Future<List<Village>> getVillages() async {
    final response = await _client.get(
      _endpoint('desa'),
      headers: {'Accept': 'application/json'},
    );
    final body = _decode(response);
    final rows = body['data'] as List<dynamic>? ?? [];

    return rows
        .map((row) => Village.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> submitReport(
    Map<String, dynamic> reportData, {
    XFile? imageFile,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey)?.trim();
    final request = http.MultipartRequest('POST', _endpoint('laporan'))
      ..headers['Accept'] = 'application/json'
      ..fields.addAll({
        for (final entry in reportData.entries)
          if (entry.key != 'nik' && entry.key != 'nik_pelapor')
            entry.key: entry.value?.toString() ?? '',
      });

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (imageFile != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto_bukti',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
        ),
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decode(response);
    final ticketCode = body['kode_tiket'];
    if (ticketCode is! String || ticketCode.trim().isEmpty) {
      throw ApiException(
        'Kode tiket tidak diterima dari server.',
        statusCode: response.statusCode,
      );
    }
    final normalizedTicketCode = ticketCode.trim();
    await saveCitizenTicketCode(normalizedTicketCode);
    final responseData = body['data'] as Map<String, dynamic>? ?? const {};
    await cacheTicketStatus(
      TicketStatus.fromJson({
        ...responseData,
        'kode_tiket': normalizedTicketCode,
        'status_laporan': responseData['status_laporan'] ?? 'dikirim',
        'kategori_laporan':
            responseData['kategori_laporan'] ??
            reportData['kategori_laporan']?.toString() ??
            '',
        'deskripsi':
            responseData['deskripsi'] ??
            reportData['deskripsi']?.toString() ??
            '',
        'nama_pelapor':
            responseData['nama_pelapor'] ??
            reportData['nama_pelapor']?.toString(),
        'rt': responseData['rt'] ?? reportData['rt']?.toString() ?? '-',
        'rw': responseData['rw'] ?? reportData['rw']?.toString() ?? '-',
      }),
    );
    return normalizedTicketCode;
  }

  Future<TicketStatus> getTicket(String code) async {
    final response = await _client.get(
      _endpoint('laporan/${Uri.encodeComponent(code)}'),
      headers: {'Accept': 'application/json'},
    );
    final body = _decode(response);
    final ticketData = body['data'] as Map<String, dynamic>;
    final responseCode = ticketData['kode_tiket'];
    final ticket = TicketStatus.fromJson({
      ...ticketData,
      'kode_tiket': responseCode is String && responseCode.trim().isNotEmpty
          ? responseCode
          : code,
    });
    await cacheTicketStatus(ticket);
    return ticket;
  }

  Future<List<String>> getSavedCitizenTicketCodes() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_savedCitizenTicketsKey) ?? [];
  }

  Future<List<String>> getSavedCitizenTickets() => getSavedCitizenTicketCodes();

  Future<List<TicketStatus>> getCachedCitizenTicketStatuses() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cachedCitizenTicketStatusesKey);
    if (raw == null || raw.isEmpty) {
      final codes = await getSavedCitizenTicketCodes();
      final statuses = <TicketStatus>[];
      for (final code in codes) {
        final status = await getCachedTicketStatus(code);
        if (status != null) statuses.add(status);
      }
      return statuses;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => TicketStatus.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<List<String>> syncCitizenTicketsHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final localCodes = preferences.getStringList(_savedCitizenTicketsKey) ?? [];
    final token = preferences.getString(_tokenKey)?.trim();
    var uri = _endpoint('v1/laporan/history');
    if (localCodes.isNotEmpty) {
      uri = uri.replace(queryParameters: {'codes': localCodes.join(',')});
    }

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 4));
      final body = _decode(response);
      final payload = body['data'] ?? body['history'] ?? body['laporan'];
      final rows = payload is List
          ? payload
          : payload is Map
          ? (payload['data'] is List
                ? payload['data'] as List<dynamic>
                : <dynamic>[])
          : <dynamic>[];

      final serverCodes = <String>[];
      final serverStatuses = <TicketStatus>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final ticket = TicketStatus.fromJson(map);
        final code = ticket.code.trim();
        if (code.isNotEmpty) {
          serverCodes.add(code);
          serverStatuses.add(ticket);
          await cacheTicketStatus(ticket);
        }
      }

      final merged = <String>{
        for (final code in [...serverCodes, ...localCodes])
          if (code.trim().isNotEmpty) code.trim(),
      }.toList();
      await preferences.setStringList(_savedCitizenTicketsKey, merged);
      await preferences.setString(
        _cachedCitizenTicketStatusesKey,
        jsonEncode(serverStatuses.map((ticket) => ticket.toJson()).toList()),
      );
      return merged;
    } on ApiException {
      return localCodes;
    } on http.ClientException {
      return localCodes;
    } on Exception {
      return localCodes;
    }
  }

  Future<void> saveCitizenTicketCode(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw const ApiException('Kode tiket tidak boleh kosong.');
    }

    final preferences = await SharedPreferences.getInstance();
    final savedCodes = preferences.getStringList(_savedCitizenTicketsKey) ?? [];
    final updatedCodes = [
      normalizedCode,
      ...savedCodes.where(
        (savedCode) => savedCode.toLowerCase() != normalizedCode.toLowerCase(),
      ),
    ];
    if (!await preferences.setStringList(
      _savedCitizenTicketsKey,
      updatedCodes,
    )) {
      throw const ApiException('Riwayat tiket tidak dapat disimpan.');
    }
  }

  Future<TicketStatus?> getCachedTicketStatus(String code) async {
    final preferences = await SharedPreferences.getInstance();
    final cachedJson = preferences.getString(_ticketCacheKey(code));
    if (cachedJson == null) return null;

    try {
      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Cache tiket bukan objek JSON.');
      }
      return TicketStatus.fromJson(decoded);
    } on FormatException catch (error) {
      throw ApiException('Cache tiket tidak dapat dibaca: $error');
    }
  }

  Future<void> cacheTicketStatus(TicketStatus ticket) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _ticketCacheKey(ticket.code),
      jsonEncode(ticket.toJson()),
    );
    if (!saved) {
      throw const ApiException('Status tiket tidak dapat disimpan ke cache.');
    }

    final statuses = await getCachedCitizenTicketStatuses();
    final updated = [
      ticket,
      ...statuses.where((status) => status.code != ticket.code),
    ];
    await preferences.setString(
      _cachedCitizenTicketStatusesKey,
      jsonEncode(updated.map((status) => status.toJson()).toList()),
    );
  }

  String _ticketCacheKey(String code) =>
      '$_ticketCachePrefix${Uri.encodeComponent(code)}';

  Uri _endpoint(String path) => _baseUri.resolve(path);

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        'Respons server tidak dapat dibaca.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = body['errors'] as Map<String, dynamic>?;
      final firstError = errors?.values
          .whereType<List<dynamic>>()
          .expand((messages) => messages)
          .whereType<String>()
          .firstOrNull;
      throw ApiException(
        firstError ??
            body['message'] as String? ??
            'Permintaan gagal. Coba lagi.',
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.userName,
    this.phone,
    this.villageName,
    this.rt,
    this.rw,
  });

  final String token;
  final String role;
  final String userName;
  final String? phone;
  final String? villageName;
  final String? rt;
  final String? rw;
}
