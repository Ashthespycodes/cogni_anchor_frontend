import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cogni_anchor/services/api_config.dart';
import 'package:cogni_anchor/services/pair_context.dart';

class ApiService {
  static String get _pairId => PairContext.require;

  // GET PEOPLE
  static Future<List<dynamic>> getPeople() async {
    final uri =
        Uri.parse("${ApiConfig.baseUrl}/api/getPeople?pair_id=$_pairId");

    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["people"] ?? [];
    } else {
      throw Exception("Failed to fetch people: ${res.body}");
    }
  }

  // ADD PERSON
  static Future<bool> addPerson({
    required Uint8List imageBytes,
    required String name,
    required String relationship,
    required String occupation,
    required int age,
    String? notes,
    required List<double> embedding,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/api/addPerson");
    final request = http.MultipartRequest('POST', uri);

    request.fields['pair_id'] = _pairId;
    request.fields['name'] = name;
    request.fields['relationship'] = relationship;
    request.fields['occupation'] = occupation;
    request.fields['age'] = age.toString();
    request.fields['notes'] = notes ?? '';
    request.fields['embedding'] = jsonEncode(embedding);

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'face.jpg',
      ),
    );

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    return resp.statusCode == 200;
  }

  // SCAN PERSON
  static Future<Map<String, dynamic>> scanPerson({
    required List<double> embedding,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/api/scan");

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pair_id': _pairId,
        'embedding': embedding,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception("Scan failed: ${res.body}");
    }
  }

  // UPDATE PERSON
  static Future<bool> updatePerson({
    required String personId,
    Uint8List? imageBytes,
    required String name,
    required String relationship,
    required String occupation,
    required int age,
    required String notes,
  }) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/api/updatePerson");
    final request = http.MultipartRequest("PUT", uri);

    request.fields["person_id"] = personId;
    request.fields["name"] = name;
    request.fields["relationship"] = relationship;
    request.fields["occupation"] = occupation;
    request.fields["age"] = age.toString();
    request.fields["notes"] = notes;

    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          imageBytes,
          filename: "updated.jpg",
        ),
      );
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    return resp.statusCode == 200;
  }

  // DELETE PERSON
  static Future<bool> deletePerson(String personId) async {
    final uri = Uri.parse("${ApiConfig.baseUrl}/api/deletePerson");

    final res = await http.delete(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"person_id": personId}),
    );

    return res.statusCode == 200;
  }
}
