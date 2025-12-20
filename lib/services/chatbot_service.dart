import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  // Backend API URL - Change this to your computer's IP address when testing on real device
  // For emulator, use 10.0.2.2 (Android emulator's special alias for localhost)
  static const String baseUrl = "http://10.0.2.2:8000";

  /// Send text message to chatbot
  ///
  /// [patientId] - Unique identifier for the patient
  /// [message] - User's text message
  ///
  /// Returns the chatbot's response text
  static Future<String> sendTextMessage({
    required String patientId,
    required String message,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/message');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patient_id': patientId,
          'message': message,
          'mode': 'text',
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Please check if the backend server is running.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as String;
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  /// Send voice message to chatbot
  ///
  /// [patientId] - Unique identifier for the patient
  /// [audioBytes] - Audio file bytes
  /// [filename] - Name of audio file
  ///
  /// Returns a map with transcription, response text, and audio URL
  static Future<Map<String, dynamic>> sendVoiceMessage({
    required String patientId,
    required List<int> audioBytes,
    required String filename,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/voice');

      var request = http.MultipartRequest('POST', url);

      // Add patient_id as form field
      request.fields['patient_id'] = patientId;

      // Add audio file
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out. Please check if the backend server is running.');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'transcription': data['transcription'] as String,
          'response': data['response'] as String,
          'audio_url': data['audio_url'] as String?,
        };
      } else {
        throw Exception('Failed to process voice: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending voice message: $e');
    }
  }

  /// Get chat history for a patient
  ///
  /// [patientId] - Unique identifier for the patient
  ///
  /// Returns list of chat messages
  static Future<List<Map<String, dynamic>>> getChatHistory({
    required String patientId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/history/$patientId');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out. Please check if the backend server is running.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final history = data['history'] as List;
        return history.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting history: $e');
    }
  }

  /// Clear chat history for a patient
  ///
  /// [patientId] - Unique identifier for the patient
  static Future<void> clearChatHistory({
    required String patientId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/history/$patientId');

      final response = await http.delete(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out. Please check if the backend server is running.');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to clear history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error clearing history: $e');
    }
  }
}
