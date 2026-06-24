import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Cloudinary credentials — set these after creating your free account at cloudinary.com
// 1. Sign up → Dashboard → copy "Cloud name"
// 2. Settings → Upload → Add upload preset → set to "Unsigned" → copy preset name
const _cloudName = 'dxs6abfvm';
const _uploadPreset = 'dohdehlw';

class StorageService {
  Future<String> uploadDogPhoto(String dogId, Uint8List bytes) async {
    return _upload(bytes, folder: 'dogs');
  }

  Future<String> uploadContractPhoto(String bookingId, Uint8List bytes) async {
    return _upload(bytes, folder: 'contracts');
  }

  Future<String> uploadProductPhoto(String productId, Uint8List bytes) async {
    return _upload(bytes, folder: 'products');
  }

  Future<void> deleteDogPhoto(String dogId) async {
    // Cloudinary deletion requires a signed request (server-side).
    // For a client app, simply leave the old image — it won't incur
    // meaningful cost on the free tier for a small facility.
  }

  Future<String> _upload(Uint8List bytes, {required String folder}) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }
}
