import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:klinik_sanitasi_mobile/services/api_service.dart';

void main() {
  group('ApiService.submitReport', () {
    // Tes baru: memastikan kontrak POST /api/laporan dan kode tiket.
    test('posts multipart report data and returns the ticket code', () async {
      final client = MockClient((request) async {
        expect(request, isA<http.Request>());
        expect(request.method, 'POST');
        expect(request.url.path, '/api/laporan');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="nama_pelapor"'));
        expect(request.body, contains('Warga Contoh'));
        expect(request.body, contains('name="id_desa"'));
        expect(request.body, contains('\r\n12\r\n'));
        expect(request.body, contains('Air keruh'));
        expect(request.headers['Accept'], 'application/json');

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Laporan berhasil dikirim.',
            'kode_tiket': 'IKL-20261028-0001',
            'id_laporan': 1,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final apiService = ApiService(client: client);

      final ticketCode = await apiService.submitReport({
        'nama_pelapor': 'Warga Contoh',
        'id_desa': 12,
        'deskripsi': 'Air keruh',
      });

      expect(ticketCode, 'IKL-20261028-0001');
      client.close();
    });

    test('uploads image bytes as a multipart file', () async {
      final client = MockClient((request) async {
        expect(request, isA<http.Request>());
        expect(request.body, contains('name="foto_bukti"; filename='));
        expect(request.body, contains('\r\nIMG\r\n'));

        return http.Response(
          jsonEncode({'kode_tiket': 'IKL-20261028-0002'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final apiService = ApiService(client: client);

      final ticketCode = await apiService.submitReport(
        {'deskripsi': 'Air keruh'},
        imageFile: XFile.fromData(
          Uint8List.fromList([0x49, 0x4D, 0x47]),
          name: 'bukti.png',
          mimeType: 'image/png',
        ),
      );

      expect(ticketCode, 'IKL-20261028-0002');
      client.close();
    });

    test('surfaces validation errors from the laporan endpoint', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Data laporan tidak valid.',
            'errors': {
              'deskripsi': ['Deskripsi wajib diisi.'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );
      final apiService = ApiService(client: client);

      await expectLater(
        apiService.submitReport({'deskripsi': ''}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having(
                (error) => error.message,
                'message',
                'Deskripsi wajib diisi.',
              ),
        ),
      );
      client.close();
    });
  });
}
