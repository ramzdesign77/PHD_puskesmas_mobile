import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../models/education_article.dart';
import '../models/ticket_status.dart';
import '../models/village.dart';
import 'auth_token_storage.dart';
import 'profile_service.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

typedef CitizenReportPage = ({
  List<TicketStatus> reports,
  int currentPage,
  int lastPage,
});

class ApiService {
  ApiService({http.Client? client, AuthTokenStore? tokenStore})
    : _client = client ?? http.Client(),
      _tokenStore = tokenStore ?? AuthTokenStorage();

  static const int maxSavedTickets = 15;

  final http.Client _client;
  final AuthTokenStore _tokenStore;
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
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s()-]'), '');
    final requestBody = {
      'nama_lengkap': namaLengkap.trim(),
      'username': username.trim(),
      'email': normalizedEmail,
      'password': password,
      'password_confirmation': password,
      'no_telepon': normalizedPhone,
      'no_hp': normalizedPhone,
    };
    final response = await _post(
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
      fallbackEmail: normalizedEmail,
      fallbackPhone: normalizedPhone,
    );
  }

  Future<http.Response> _postLogin(
    String path, {
    required String identifier,
    required String password,
  }) => _post(
    _endpoint(path),
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    body: jsonEncode({'identifier': identifier.trim(), 'password': password}),
  );

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      await _invalidateExpiredSession(response, headers?['Authorization']);
      return response;
    } on TimeoutException {
      throw const ApiException('Server terlalu lama merespons. Coba lagi.');
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));
      await _invalidateExpiredSession(response, headers?['Authorization']);
      return response;
    } on TimeoutException {
      throw const ApiException('Server terlalu lama merespons. Coba lagi.');
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Future<http.StreamedResponse> _send(http.BaseRequest request) async {
    try {
      final response = await _client.send(request).timeout(
        const Duration(seconds: 8),
      );
      await _invalidateExpiredSession(
        http.Response('', response.statusCode),
        request.headers['Authorization'],
      );
      return response;
    } on TimeoutException {
      throw const ApiException('Server terlalu lama merespons. Coba lagi.');
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
  }

  Future<void> _invalidateExpiredSession(
    http.Response response,
    String? authorization,
  ) async {
    if ((response.statusCode != 401 && response.statusCode != 419) ||
        authorization == null ||
        !authorization.startsWith('Bearer ')) {
      return;
    }
    final requestToken = authorization.substring('Bearer '.length);
    if (await _tokenStore.getToken() != requestToken) return;
    try {
      await clearSavedSession(tokenStore: _tokenStore);
    } on AuthTokenStorageException {
      throw const ApiException(
        'Sesi berakhir, tetapi token lokal tidak dapat dihapus.',
      );
    }
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
    await clearSavedSession(tokenStore: _tokenStore);
    await _tokenStore.saveToken(token);
    final preferences = await SharedPreferences.getInstance();
    final roleSaved = await preferences.setString(_roleKey, role);
    await preferences.setString(
      _userPhoneKey,
      _firstNonEmptyString([
            user['no_telepon'],
            user['no_wa'],
            user['no_hp'],
            user['phone'],
            user['phone_number'],
            user['nomor_telepon'],
          ]) ??
          fallbackPhone?.trim() ??
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
      avatarUrl: _firstNonEmptyString([user['foto_url']]),
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
    if (!roleSaved || !profileSaved) {
      await clearSavedSession(tokenStore: _tokenStore);
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
    final token = await _tokenStore.getToken();
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

  static Future<void> clearSavedSession({AuthTokenStore? tokenStore}) async {
    await (tokenStore ?? AuthTokenStorage()).clearAuthentication();
    final preferences = await SharedPreferences.getInstance();
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
    final response = await _post(
      _endpoint('auth/logout'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    _decode(response);
  }

  Future<List<EducationArticle>> getArticles() async {
    final response = await _get(
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
    final response = await _get(
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
    final token = (await _tokenStore.getToken())?.trim();
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

    final streamedResponse = await _send(request);
    late final http.Response response;
    try {
      response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const ApiException('Server terlalu lama merespons. Coba lagi.');
    } on SocketException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }
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
    final response = await _get(
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

  Future<CitizenReportPage> getCitizenReportsPage({
    required int page,
    int perPage = 10,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    if (page < 1 || perPage < 1) {
      throw const ApiException('Halaman laporan tidak valid.');
    }

    final token = (await _tokenStore.getToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException('Sesi pengguna tidak ditemukan. Silakan masuk kembali.');
    }

    final uri = _endpoint('v1/laporan/history').replace(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
    );
    final response = await _get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final body = _decode(response);
    final payload = body['data'];
    final nestedPayload = payload is Map ? payload : null;
    final rows = payload is List
        ? payload
        : nestedPayload?['data'] is List
        ? nestedPayload!['data'] as List
        : null;
    if (rows == null) {
      throw ApiException(
        'Format daftar laporan dari server tidak valid.',
        statusCode: response.statusCode,
      );
    }

    final reports = <TicketStatus>[];
    for (final row in rows) {
      if (row is! Map) {
        throw ApiException(
          'Data laporan dari server tidak valid.',
          statusCode: response.statusCode,
        );
      }
      final report = TicketStatus.fromJson(Map<String, dynamic>.from(row));
      if (report.code.trim().isNotEmpty) reports.add(report);
    }

    final meta = body['meta'] is Map
        ? body['meta'] as Map
        : nestedPayload?['meta'] is Map
        ? nestedPayload!['meta'] as Map
        : nestedPayload;
    final links = body['links'] is Map
        ? body['links'] as Map
        : nestedPayload?['links'] is Map
        ? nestedPayload!['links'] as Map
        : null;
    final currentPage =
        _paginationInt(meta?['current_page']) ??
        _paginationInt(body['current_page']) ??
        page;
    final lastPage =
        _paginationInt(meta?['last_page']) ??
        _paginationInt(body['last_page']) ??
        (links?['next'] != null || rows.length >= perPage
            ? currentPage + 1
            : currentPage);

    return (
      reports: reports,
      currentPage: currentPage,
      lastPage: lastPage < currentPage ? currentPage : lastPage,
    );
  }

  int? _paginationInt(Object? value) {
    if (value is int) return value;
    return value is String ? int.tryParse(value) : null;
  }

  Future<List<String>> getSavedCitizenTicketCodes() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.get(_savedCitizenTicketsKey);
    if (stored == null) return const [];
    if (stored is! List) {
      await preferences.remove(_savedCitizenTicketsKey);
      return const [];
    }

    final codes = stored
        .whereType<String>()
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .take(maxSavedTickets)
        .toList();
    if (stored.length > maxSavedTickets &&
        !await preferences.setStringList(_savedCitizenTicketsKey, codes)) {
      throw const ApiException('Riwayat tiket tidak dapat dirapikan.');
    }
    return codes;
  }

  Future<List<String>> getSavedCitizenTickets() => getSavedCitizenTicketCodes();

  Future<List<TicketStatus>> getCachedCitizenTicketStatuses() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.get(_cachedCitizenTicketStatusesKey);
    if (stored is! String || stored.isEmpty) {
      if (stored != null) {
        await preferences.remove(_cachedCitizenTicketStatusesKey);
      }
      final codes = await getSavedCitizenTicketCodes();
      final statuses = <TicketStatus>[];
      for (final code in codes) {
        try {
          final status = await getCachedTicketStatus(code);
          if (status != null && !statuses.any((item) => item.code == code)) {
            statuses.add(status);
          }
        } on ApiException {
          continue;
        }
      }
      return statuses.take(maxSavedTickets).toList(growable: false);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      await preferences.remove(_cachedCitizenTicketStatusesKey);
      return const [];
    }
    if (decoded is! List) {
      await preferences.remove(_cachedCitizenTicketStatusesKey);
      return const [];
    }

    final statuses = <TicketStatus>[];
    for (final item in decoded.take(maxSavedTickets)) {
      if (item is! Map) continue;
      final json = <String, dynamic>{
        for (final entry in item.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
      final status = TicketStatus.fromJson(json);
      if (status.code.trim().isNotEmpty) statuses.add(status);
    }
    final boundedStatuses = statuses.take(maxSavedTickets).toList();
    if (decoded.length > maxSavedTickets) {
      final saved = await preferences.setString(
        _cachedCitizenTicketStatusesKey,
        jsonEncode(boundedStatuses.map((status) => status.toJson()).toList()),
      );
      if (!saved) {
        throw const ApiException('Cache riwayat tiket tidak dapat dirapikan.');
      }
    }
    return boundedStatuses;
  }

  Future<List<String>> syncCitizenTicketsHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final localCodes = await getSavedCitizenTicketCodes();
    final requestedCodes = localCodes.take(10).toList(growable: false);
    final token = (await _tokenStore.getToken())?.trim();
    final uri = _endpoint('v1/laporan/history').replace(
      queryParameters: {
        'limit': '$maxSavedTickets',
        if (requestedCodes.isNotEmpty) 'codes': requestedCodes.join(','),
      },
    );

    try {
      final response = await _get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
      final body = _decode(response);
      final payload = body['data'] ?? body['history'] ?? body['laporan'];
      final rows = payload is List
          ? payload
          : payload is Map
          ? (payload['data'] is List
                ? payload['data'] as List<dynamic>
                : <dynamic>[])
          : <dynamic>[];

      final serverStatuses = <TicketStatus>[];
      for (final row in rows.take(maxSavedTickets)) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final ticket = TicketStatus.fromJson(map);
        final code = ticket.code.trim();
        if (code.isNotEmpty) {
          serverStatuses.add(ticket);
        }
      }

      final cachedStatuses = await getCachedCitizenTicketStatuses();
      final statusesByCode = <String, TicketStatus>{
        for (final ticket in cachedStatuses) ticket.code: ticket,
        for (final ticket in serverStatuses) ticket.code: ticket,
      };
      final orderedCodes = <String>{
        ...serverStatuses.map((ticket) => ticket.code),
        ...cachedStatuses.map((ticket) => ticket.code),
      }.take(maxSavedTickets);
      final boundedStatuses = [
        for (final code in orderedCodes)
          if (statusesByCode[code] != null) statusesByCode[code]!,
      ];
      final merged = <String>{
        ...serverStatuses.map((ticket) => ticket.code),
        ...localCodes,
      }.take(maxSavedTickets).toList(growable: false);
      final savedCodes = await preferences.setStringList(
        _savedCitizenTicketsKey,
        merged,
      );
      final savedStatuses = await preferences.setString(
        _cachedCitizenTicketStatusesKey,
        jsonEncode(boundedStatuses.map((ticket) => ticket.toJson()).toList()),
      );
      if (!savedCodes || !savedStatuses) {
        throw const ApiException(
          'Riwayat tiket tidak dapat disimpan ke cache.',
        );
      }
      return merged;
    } on ApiException {
      rethrow;
    } on Exception catch (error) {
      throw ApiException('Riwayat laporan tidak dapat dimuat: $error');
    }
  }

  Future<void> saveCitizenTicketCode(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw const ApiException('Kode tiket tidak boleh kosong.');
    }

    final preferences = await SharedPreferences.getInstance();
    final savedCodes = await getSavedCitizenTicketCodes();
    final updatedCodes = [
      normalizedCode,
      ...savedCodes.where(
        (savedCode) => savedCode.toLowerCase() != normalizedCode.toLowerCase(),
      ),
    ].take(maxSavedTickets).toList(growable: false);
    if (!await preferences.setStringList(
      _savedCitizenTicketsKey,
      updatedCodes,
    )) {
      throw const ApiException('Riwayat tiket tidak dapat disimpan.');
    }
  }

  Future<TicketStatus?> getCachedTicketStatus(String code) async {
    final preferences = await SharedPreferences.getInstance();
    final cacheKey = _ticketCacheKey(code);
    final stored = preferences.get(cacheKey);
    if (stored == null) return null;
    if (stored is! String) {
      await preferences.remove(cacheKey);
      return null;
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) {
        await preferences.remove(cacheKey);
        return null;
      }
      final ticket = TicketStatus.fromJson({
        for (final entry in decoded.entries)
          if (entry.key is String) entry.key as String: entry.value,
      });
      return ticket.code.trim().isEmpty ? null : ticket;
    } on FormatException {
      await preferences.remove(cacheKey);
      return null;
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
    ].take(maxSavedTickets).toList(growable: false);
    final savedStatuses = await preferences.setString(
      _cachedCitizenTicketStatusesKey,
      jsonEncode(updated.map((status) => status.toJson()).toList()),
    );
    if (!savedStatuses) {
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
      final fieldErrors = <String, String>{};
      final rawErrors = body['errors'];
      if (rawErrors is Map) {
        for (final entry in rawErrors.entries) {
          final rawMessages = entry.value;
          final message = rawMessages is Iterable
              ? rawMessages
                    .whereType<String>()
                    .map((value) => value.trim())
                    .firstWhere((value) => value.isNotEmpty, orElse: () => '')
              : rawMessages is String
              ? rawMessages.trim()
              : '';
          if (message.isNotEmpty) {
            fieldErrors[entry.key.toString()] = message;
          }
        }
      }
      throw ApiException(
        fieldErrors.values.firstOrNull ??
            body['message'] as String? ??
            'Permintaan gagal. Coba lagi.',
        statusCode: response.statusCode,
        fieldErrors: Map.unmodifiable(fieldErrors),
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
