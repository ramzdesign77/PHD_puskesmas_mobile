import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  final Uri _baseUri = Uri.parse(
    '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/',
  );

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      _endpoint('auth/login'),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier.trim(), 'password': password}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> register({
    required String namaLengkap,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _endpoint('auth/register'),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'nama_lengkap': namaLengkap.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
      }),
    );
    return _decode(response);
  }

  Future<void> logout(String token) async {
    final response = await _client.post(
      _endpoint('auth/logout'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    _decode(response);
  }

  Future<List<EducationArticle>> getArticles() async {
    final response = await _client.get(_endpoint('edukasi'), headers: {'Accept': 'application/json'});
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
    final response = await _client.get(_endpoint('desa'), headers: {'Accept': 'application/json'});
    final body = _decode(response);
    final rows = body['data'] as List<dynamic>? ?? [];

    return rows
        .map((row) => Village.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> submitReport({
    required Map<String, String> fields,
    XFile? image,
  }) async {
    final request = http.MultipartRequest('POST', _endpoint('laporan'))
      ..fields.addAll(fields);

    if (image != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_bukti', image.path),
      );
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decode(response);

    return body['kode_tiket'] as String? ?? '';
  }

  Future<TicketStatus> getTicket(String code) async {
    final response = await _client.get(
      _endpoint('laporan/${Uri.encodeComponent(code)}'),
    );
    final body = _decode(response);

    return TicketStatus.fromJson(body['data'] as Map<String, dynamic>);
  }

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
