// lib/services/chat_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class VoiceReply {
  final String text;
  final Uint8List audioBytes;
  final String mime;

  VoiceReply({
    required this.text,
    required this.audioBytes,
    required this.mime,
  });
}

class ChatService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<String> sendMessage(String message) async {
    final token = await AuthService.instance.requireToken();

    final url = Uri.parse('$baseUrl/chat');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': message}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Chat failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map) return res.body;

    if (data['ok'] != true) {
      throw Exception(
        (data['message'] ?? data['error'] ?? 'Chat failed').toString(),
      );
    }

    final reply =
        (data['reply'] ?? data['replyText'] ?? data['data']?['reply'] ?? '')
            .toString();

    return reply.trim().isEmpty ? '(no reply)' : reply;
  }

  // ✅ NEW: voice chat (text + audio)
  static Future<VoiceReply> sendVoiceMessage(String message) async {
    final token = await AuthService.instance.requireToken();

    final url = Uri.parse('$baseUrl/voice-chat');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': message}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Voice chat failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map) {
      throw Exception('Voice chat response is not JSON map');
    }

    // รองรับทั้ง ok=true แบบเดิม และแบบไม่ส่ง ok
    if (data.containsKey('ok') && data['ok'] != true) {
      throw Exception(
        (data['message'] ?? data['error'] ?? 'Voice chat failed').toString(),
      );
    }

    final text = (data['replyText'] ?? data['reply'] ?? '').toString().trim();
    final b64 = (data['audioBase64'] ?? '').toString();
    final mime = (data['mime'] ?? 'audio/mpeg').toString();

    if (text.isEmpty) throw Exception('Empty replyText');
    if (b64.isEmpty) throw Exception('Empty audioBase64');

    final bytes = base64Decode(b64);
    return VoiceReply(text: text, audioBytes: bytes, mime: mime);
  }
}
