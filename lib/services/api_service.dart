import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/education_article.dart';
import '../models/ticket_status.dart';
import '../models/village.dart';

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
  static const _rolesKey = 'auth_roles';
  static const _savedCitizenTicketsKey = 'saved_citizen_tickets';
  static const _ticketCachePrefix = 'citizen_ticket_cache_';
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
  }) async {
    final response = await _client.post(
      _endpoint('auth/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'nama_lengkap': namaLengkap.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
      }),
    );
    return _saveSession(_decode(response), fallbackRole: 'warga');
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
  }) async {
    final data = response['data'] as Map<String, dynamic>?;
    final token = response['token'] as String? ?? data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Token login tidak diterima server.');
    }

    final user = _userFromResponse(response);
    final role = _roleFromResponse(response) ?? fallbackRole;
    final userName =
        user['nama_lengkap'] as String? ?? user['name'] as String? ?? '';
    final preferences = await SharedPreferences.getInstance();
    final tokenSaved = await preferences.setString(_tokenKey, token);
    final roleSaved = await preferences.setString(_roleKey, role);
    final userNameSaved = await preferences.setString(_userNameKey, userName);
    if (!tokenSaved || !roleSaved || !userNameSaved) {
      throw const ApiException(
        'Sesi login tidak dapat disimpan pada perangkat.',
      );
    }

    return {...response, 'token': token, 'role': role};
  }

  Future<AuthSession?> loadSavedSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;

    return AuthSession(
      token: token,
      role: preferences.getString(_roleKey) ?? 'warga',
      userName: preferences.getString(_userNameKey) ?? '',
    );
  }

  static Future<void> clearSavedSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
    await preferences.remove(_userNameKey);
    await preferences.remove(_rolesKey);
  }

  static bool isOfficerRole(String? role) {
    final normalizedRole = role?.trim().toLowerCase();
    return normalizedRole == 'petugas' || normalizedRole == 'admin';
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
    final request = http.MultipartRequest('POST', _endpoint('laporan'))
      ..headers['Accept'] = 'application/json'
      ..fields.addAll({
        for (final entry in reportData.entries)
          if (entry.key != 'nik' && entry.key != 'nik_pelapor')
            entry.key: entry.value?.toString() ?? '',
      });

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
  });

  final String token;
  final String role;
  final String userName;
}
