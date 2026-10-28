import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart'; // ของหนูที่มี token + baseUrl

class VoiceChatService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _isListening = false;
  String _partial = '';

  bool get isListening => _isListening;
  String get partialTranscript => _partial;

  Future<void> init() async {
    // permissions
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception('Microphone permission denied');
    }

    // init STT
    _sttReady = await _stt.initialize(
      onStatus: (s) {},
      onError: (e) {},
    );

    // init TTS (ปรับได้)
    await _tts.setLanguage('th-TH');     // ถ้าจะสลับภาษา ค่อยทำทีหลัง
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  /// กดเริ่มฟัง (พูด)
  Future<void> startListening({
    String localeId = 'th-TH',
    Duration listenFor = const Duration(seconds: 8),
  }) async {
    if (!_sttReady) {
      throw Exception('STT not initialized. Call init() first.');
    }
    if (_isListening) return;

    _partial = '';
    _isListening = true;

    await _stt.listen(
      localeId: localeId,
      listenFor: listenFor,
      partialResults: true,
      onResult: (r) {
        _partial = r.recognizedWords;
      },
    );
  }

  /// กดหยุดฟัง แล้วส่งไปหา AI + ให้ TTS พูด
  Future<String> stopAndSend() async {
    if (!_isListening) return '';
    _isListening = false;

    await _stt.stop();
    final transcript = _partial.trim();
    if (transcript.isEmpty) return '';

    // เรียก backend /chat (ของเดิมที่หนูทำไว้)
    final token = await AuthService.instance.requireToken();
    final url = Uri.parse('${AuthService.baseUrl}/chat');

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': transcript}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Chat failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final reply = (data['reply'] ?? data['message'] ?? '').toString();

    // พูดตอบ
    await speak(reply);

    return reply;
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _tts.stop(); // กันเสียงซ้อน
    await _tts.speak(t);
  }

  Future<void> stopSpeaking() => _tts.stop();

  Future<void> dispose() async {
    await _stt.stop();
    await _tts.stop();
  }
}
