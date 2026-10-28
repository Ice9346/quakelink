// lib/screens/voice_chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/chat_service.dart';

enum VoiceUiState { idle, listening, thinking, speaking, error }

class VoiceChatResult {
  final String userText;
  final String assistantText;
  const VoiceChatResult({required this.userText, required this.assistantText});
}

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final AudioPlayer _player = AudioPlayer();

  bool _sttReady = false;
  bool _busy = false;
  bool _startingListen = false;

  VoiceUiState _state = VoiceUiState.idle;

  String _partial = '';
  String _finalSpoken = '';
  String? _error;

  // ✅ ข้อความแจ้งเตือนแบบไม่ใช่ error (เช่น iOS หยุดฟังเอง)
  String? _notice;

  Timer? _pollTimer;
  Timer? _watchdogTimer;

  late final AnimationController _pulse;

  // ✅ เก็บผลล่าสุดไว้เฉย ๆ (แต่ไม่ pop หน้าจอ)
  VoiceChatResult? _pendingResult;

  bool _closing = false;

  // ✅ DEBUG HUD (ซ่อนบนจอ แต่ยัง print ได้)
  final List<String> _dbg = [];
  DateTime? _listenStartedAt;
  double _lastSound = 0;

  // ✅ ปิด/เปิด debug hud บนจอ
  static const bool _showDebugHud = false;

  // ✅ กันปล่อยนิ้วซ้ำ / stop ซ้ำ
  bool _finishingByHoldRelease = false;

  void _log(String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    final line = '$t  $msg';
    if (_dbg.length > 14) _dbg.removeAt(0);
    _dbg.add(line);
    // ignore: avoid_print
    print('[VOICE] $line');
    if (mounted && _showDebugHud) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _log('initState');

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _initVoice();
  }

  @override
  void dispose() {
    _log('dispose');
    _watchdogTimer?.cancel();
    _pollTimer?.cancel();
    _stt.stop();
    _player.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // -------------------- iOS Audio Session (FIX) --------------------
  Future<void> _ensureRecordSession() async {
    try {
      final session = await AudioSession.instance;

      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.measurement,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        ),
      );

      await session.setActive(true);
      _log('audioSession active=true mode=measurement');
    } catch (e) {
      _log('audioSession config failed: $e');
    }
  }

  // -------------------- Locale helper --------------------
  Future<String?> _pickThaiLocale() async {
    try {
      final locales = await _stt.locales();
      final th = locales
          .where((l) => l.localeId.toLowerCase().startsWith('th'))
          .toList();
      if (th.isNotEmpty) return th.first.localeId;
    } catch (e) {
      _log('pickLocale failed: $e');
    }
    return null; // auto
  }

  // -------------------- Init (permissions + STT) --------------------
  Future<void> _initVoice() async {
    try {
      if (!mounted) return;

      setState(() {
        _error = null;
        _notice = null;
        _sttReady = false;
        _state = VoiceUiState.idle;
      });

      final mic = await Permission.microphone.request();
      final speech = await Permission.speech.request();
      _log('perm mic=${mic.isGranted} speech=${speech.isGranted}');

      if (!mic.isGranted || !speech.isGranted) {
        if (!mounted) return;
        setState(() {
          _error =
              'ไมค์/การรู้จำเสียงถูกปิด\nไปที่ Settings > Privacy & Security > Microphone / Speech Recognition';
          _state = VoiceUiState.error;
        });
        return;
      }

      await _ensureRecordSession();

      _sttReady = await _stt.initialize(
        onStatus: (s) async {
          _log('sttStatus=$s ui=$_state');
          if (!mounted) return;

          // ✅ ถ้าปล่อยนิ้วแล้ว เราจะจัดการ stop+send เอง
          if (_finishingByHoldRelease) return;

          if ((_state == VoiceUiState.listening) &&
              (s == 'notListening' || s == 'done')) {
            final spoken =
                (_finalSpoken.isNotEmpty ? _finalSpoken : _partial).trim();
            final ms = _listenStartedAt == null
                ? null
                : DateTime.now().difference(_listenStartedAt!).inMilliseconds;

            _log(
              'system ended listening after ${ms ?? "-"}ms spokenLen=${spoken.length} sound=$_lastSound',
            );

            if ((ms ?? 999999) < 900 && spoken.isEmpty) {
              await _ensureRecordSession();
              if (!mounted) return;
              setState(() {
                _state = VoiceUiState.idle;
                _notice =
                    'iOS หยุดฟังเร็วมาก (มักเป็นเรื่อง audio route)\nลองกดค้างวงกลมกลางใหม่อีกครั้งครับ';
              });
              return;
            }

            _watchdogTimer?.cancel();
            _pollTimer?.cancel();

            if (spoken.isEmpty) {
              setState(() {
                _state = VoiceUiState.idle;
                _notice =
                    'ระบบหยุดฟังเอง ลองกดค้างวงกลมกลางใหม่ แล้วพูดใกล้ไมค์นะครับ';
              });
              return;
            }

            // ✅ มีข้อความแล้ว -> ส่งอัตโนมัติ
            await _autoSend(spoken);
          }
        },
        onError: (e) {
          _log('sttError=${e.errorMsg} permanent=${e.permanent}');
          if (!mounted) return;
          _watchdogTimer?.cancel();
          _pollTimer?.cancel();
          setState(() {
            _error = 'Speech error: ${e.errorMsg}';
            _state = VoiceUiState.error;
          });
        },
      );

      _log('sttReady=$_sttReady avail=${_stt.isAvailable}');

      if (!mounted) return;
      setState(() {
        _error = _sttReady ? null : 'Speech init ไม่สำเร็จ';
        if (!_sttReady) _state = VoiceUiState.error;
      });
    } catch (e) {
      _log('initVoice exception: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Init voice failed: $e';
        _state = VoiceUiState.error;
      });
    }
  }

  // -------------------- Listening --------------------
  Future<void> _startListening() async {
    if (_busy) return;
    if (_startingListen) return;
    _startingListen = true;

    try {
      if (!_sttReady) {
        await _initVoice();
        if (!_sttReady) return;
      }

      await _stopAudio();
      await _stt.stop();

      await _ensureRecordSession();

      _watchdogTimer?.cancel();
      _pollTimer?.cancel();

      if (!mounted) return;
      setState(() {
        _partial = '';
        _finalSpoken = '';
        _error = null;
        _notice = null;
        _state = VoiceUiState.listening;
      });

      final locale = await _pickThaiLocale();
      _listenStartedAt = DateTime.now();
      _lastSound = 0;
      _log('listen start locale=${locale ?? "auto"}');

      await _stt.listen(
        localeId: locale,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 10),
        onSoundLevelChange: (level) {
          _lastSound = level;
        },
        onResult: (r) {
          final words = r.recognizedWords;
          _log(
              'result final=${r.finalResult} wordsLen=${words.length} sound=${_lastSound.toStringAsFixed(2)}');
          if (!mounted) return;
          setState(() {
            _partial = words;
            if (r.finalResult) _finalSpoken = words.trim();
          });
        },
      );

      _log('after listen isListening=${_stt.isListening}');

      // ✅ Watchdog: ตรวจ isListening เอง
      _watchdogTimer?.cancel();
      _watchdogTimer =
          Timer.periodic(const Duration(milliseconds: 300), (_) async {
        if (!mounted) return;
        if (_state != VoiceUiState.listening) return;
        if (_finishingByHoldRelease) return;

        if (!_stt.isListening) {
          _log('watchdog: isListening=false (system likely stopped)');
          await _ensureRecordSession();

          final spoken =
              (_finalSpoken.isNotEmpty ? _finalSpoken : _partial).trim();

          _watchdogTimer?.cancel();
          _pollTimer?.cancel();

          if (spoken.isEmpty) {
            setState(() {
              _state = VoiceUiState.idle;
              _notice = 'ระบบหยุดฟังเอง ลองกดค้างวงกลมกลางใหม่ครับ';
            });
            return;
          }

          await _autoSend(spoken);
        }
      });

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted) return;
        if (_state != VoiceUiState.listening) return;
        if (_showDebugHud) setState(() {});
      });
    } catch (e) {
      _log('startListening exception: $e');
      if (!mounted) return;
      setState(() {
        _error = 'เริ่มฟังไม่สำเร็จ: $e';
        _state = VoiceUiState.error;
      });
    } finally {
      _startingListen = false;
    }
  }

  // ✅ ใช้ตอน "ปล่อยนิ้ว" (stop + ส่งทันที)
  Future<void> _stopListeningByHoldReleaseAndSend() async {
    if (_busy) return;
    if (_state != VoiceUiState.listening) return;

    _finishingByHoldRelease = true;

    _watchdogTimer?.cancel();
    _pollTimer?.cancel();

    try {
      await _stt.stop();
    } catch (_) {}

    final spoken = (_finalSpoken.isNotEmpty ? _finalSpoken : _partial).trim();
    final started = _listenStartedAt;
    if (started != null) {
      final ms = DateTime.now().difference(started).inMilliseconds;
      _log('hold release after ${ms}ms spokenLen=${spoken.length}');
    } else {
      _log('hold release spokenLen=${spoken.length}');
    }

    if (!mounted) {
      _finishingByHoldRelease = false;
      return;
    }
    setState(() => _state = VoiceUiState.idle);

    if (spoken.isEmpty) {
      setState(() {
        _notice = 'ยังไม่ได้ยินข้อความ ลองกดค้างแล้วพูดใกล้ไมค์นะครับ';
      });
      _finishingByHoldRelease = false;
      return;
    }

    await _sendToAi(spoken);
    _finishingByHoldRelease = false;
  }

  Future<void> _autoSend(String spoken) async {
    if (_busy) return;

    if (!mounted) return;
    setState(() {
      _state = VoiceUiState.idle;
      _notice = null;
    });

    await _sendToAi(spoken);
  }

  // -------------------- Audio helpers --------------------
  Future<void> _stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<String> _writeTempAudioFile(List<int> bytes, {String ext = 'mp3'}) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/ql_voice_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // -------------------- Send to AI (VOICE) --------------------
  Future<void> _sendToAi(String spoken) async {
    if (_busy) return;

    if (!mounted) return;
    setState(() {
      _busy = true;
      _state = VoiceUiState.thinking;
      _error = null;
      _notice = null;
    });

    _log('sendToAi spoken="$spoken"');

    try {
      final vr = await ChatService.sendVoiceMessage(spoken);

      _pendingResult = VoiceChatResult(
        userText: spoken,
        assistantText: vr.text,
      );

      if (!mounted) return;
      setState(() => _state = VoiceUiState.speaking);

      await _stopAudio();

      final path = await _writeTempAudioFile(vr.audioBytes, ext: 'mp3');
      await _player.setFilePath(path);
      await _player.play();

      if (!mounted) return;
      setState(() {
        _state = VoiceUiState.idle;
        _notice = 'พร้อมแล้ว กดค้างที่วงกลมกลางเพื่อพูดต่อได้เลยครับ';
        _partial = '';
        _finalSpoken = '';
      });

      // ✅ ไม่ Navigator.pop (ค้างหน้าไว้)
    } catch (e) {
      _log('sendToAi exception: $e');
      if (!mounted) return;
      setState(() {
        _error = 'คุยกับ AI ไม่สำเร็จ: $e';
        _state = VoiceUiState.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------- Close safely --------------------
  Future<void> _closeScreen() async {
    if (_closing) return;
    _closing = true;

    _watchdogTimer?.cancel();
    _pollTimer?.cancel();

    await _stt.stop();
    await _stopAudio();

    if (!mounted) return;
    Navigator.pop(context);
  }

  // -------------------- UI helpers --------------------
  String _titleText() {
    switch (_state) {
      case VoiceUiState.listening:
        return 'QuakeLink AI กำลังฟัง…';
      case VoiceUiState.thinking:
        return 'กำลังประมวลผล…';
      case VoiceUiState.speaking:
        return 'QuakeLink AI กำลังพูด…';
      case VoiceUiState.error:
        return 'เกิดข้อผิดพลาด';
      case VoiceUiState.idle:
      default:
        return 'คุยด้วยเสียงกับ QuakeLink AI';
    }
  }

  String _subText() {
    if (_state == VoiceUiState.error) return _error ?? '';
    if (_state == VoiceUiState.listening) {
      final t = _partial.trim();
      return t.isEmpty ? 'พูดได้เลยครับ' : '“$t”';
    }
    if (_state == VoiceUiState.thinking) return 'รอสักครู่ครับ';
    if (_state == VoiceUiState.speaking) return 'กำลังตอบกลับด้วยเสียง';
    if (_notice != null && _notice!.trim().isNotEmpty) return _notice!;
    return 'กดค้างที่วงกลมกลางเพื่อพูด ปล่อยเพื่อส่งครับ';
  }

  Color _accent() {
    switch (_state) {
      case VoiceUiState.listening:
        return const Color(0xFFE53935);
      case VoiceUiState.thinking:
        return const Color(0xFFFFB300);
      case VoiceUiState.speaking:
        return const Color(0xFF111111);
      case VoiceUiState.error:
        return const Color(0xFFE53935);
      case VoiceUiState.idle:
      default:
        return const Color(0xFF111111);
    }
  }

  // ✅ จุดที่เพิ่ม: กดค้างที่วงกลมกลางเพื่อพูด / ปล่อยเพื่อส่ง
  Widget _statusOrb() {
    final isBusy = _state == VoiceUiState.thinking || _busy;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: isBusy
          ? null
          : (_) async {
              if (_state == VoiceUiState.listening) return;
              await _startListening();
            },
      onLongPressEnd: isBusy
          ? null
          : (_) async {
              await _stopListeningByHoldReleaseAndSend();
            },
      onLongPressCancel: isBusy
          ? null
          : () async {
              // ถ้ายกเลิก (เช่น นิ้วหลุดออกนอก) ให้หยุดฟังเฉย ๆ ไม่ส่ง
              if (_state != VoiceUiState.listening) return;
              _watchdogTimer?.cancel();
              _pollTimer?.cancel();
              try {
                await _stt.stop();
              } catch (_) {}
              if (!mounted) return;
              setState(() {
                _state = VoiceUiState.idle;
                _notice = 'ยกเลิกการพูดแล้วครับ ลองกดค้างใหม่ได้เลย';
              });
            },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final t = _pulse.value;
          final active =
              _state == VoiceUiState.listening || _state == VoiceUiState.speaking;
          final scale = (active ? 1.0 : 0.82) + (t * (active ? 0.20 : 0.10));

          IconData icon;
          if (_state == VoiceUiState.listening) {
            icon = Icons.hearing_rounded;
          } else if (_state == VoiceUiState.speaking) {
            icon = Icons.graphic_eq_rounded;
          } else if (_state == VoiceUiState.thinking) {
            icon = Icons.hourglass_top_rounded;
          } else if (_state == VoiceUiState.error) {
            icon = Icons.error_outline_rounded;
          } else {
            icon = Icons.mic_rounded;
          }

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent(),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 44,
                    spreadRadius: 2,
                    color: _accent().withOpacity(0.25 + t * 0.2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 44),
            ),
          );
        },
      ),
    );
  }

  // ✅ UI เดิม แต่เอาปุ่ม “ส่ง” ออกแล้ว เหลือ “ไมค์” ตลอด (สำรอง)
  Widget _controls() {
    final isListening = _state == VoiceUiState.listening;
    final isBusy = _state == VoiceUiState.thinking || _busy;

    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: 'ปิด',
            icon: Icons.close_rounded,
            fill: Colors.white,
            fg: Colors.black87,
            onTap: isBusy ? null : () => _closeScreen(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PillButton(
            label: 'ไมค์',
            icon: Icons.mic_rounded,
            fill: isBusy ? Colors.black12 : _accent(),
            fg: isBusy ? Colors.black45 : Colors.white,
            onTap: isBusy
                ? null
                : () async {
                    // ปุ่มนี้ยังมีไว้สำรอง (แต่ main UX คือกดค้างวงกลมกลาง)
                    if (isListening) {
                      try {
                        await _stt.stop();
                      } catch (_) {}
                      if (!mounted) return;
                      setState(() {
                        _state = VoiceUiState.idle;
                        _notice = 'หยุดฟังแล้วครับ (แนะนำให้กดค้างวงกลมกลางเพื่อส่งอัตโนมัติ)';
                      });
                    } else {
                      await _startListening();
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _debugHud() {
    if (!_showDebugHud) return const SizedBox.shrink();
    if (_dbg.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(
        _dbg.join('\n'),
        style: TextStyle(
          fontSize: 11,
          height: 1.25,
          color: Colors.black.withOpacity(0.70),
          fontFamily: 'Menlo',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Text(
                    _titleText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _subText(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.62),
                      height: 1.35,
                    ),
                  ),
                  _debugHud(),
                  const Spacer(),
                  _statusOrb(),
                  const Spacer(),
                  if (_state == VoiceUiState.thinking) ...[
                    const _DotsLoading(),
                    const SizedBox(height: 10),
                  ],
                  if (_state == VoiceUiState.error && _error != null) ...[
                    const SizedBox(height: 10),
                    _PillButton(
                      label: 'เปิด Settings',
                      icon: Icons.settings_rounded,
                      fill: Colors.white,
                      fg: Colors.black87,
                      onTap: () => openAppSettings(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _controls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color fill;
  final Color fg;
  final VoidCallback? onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.fill,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                offset: const Offset(0, 12),
                color: Colors.black.withOpacity(0.10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotsLoading extends StatefulWidget {
  const _DotsLoading();

  @override
  State<_DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<_DotsLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        double o(int i) {
          final phase = (t * 3 - i).clamp(0.0, 1.0);
          final v = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
          return 0.35 + v * 0.65;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: o(0)),
            const SizedBox(width: 6),
            _Dot(opacity: o(1)),
            const SizedBox(width: 6),
            _Dot(opacity: o(2)),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final double opacity;
  const _Dot({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
