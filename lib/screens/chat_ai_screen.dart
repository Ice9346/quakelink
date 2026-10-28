import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

// ✅ Voice (Permission + TTS เท่านั้น)
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/chat_service.dart';

// ✅ voice full-screen page (ทำ STT จริงในหน้านี้)
import 'voice_chat_screen.dart';

enum ChatRole { user, assistant }
enum SeverityTone { none, caution, severe }

class ChatMessage {
  final ChatRole role;
  final DateTime time;

  // สำหรับ render
  String text;

  // สำหรับ streaming
  final String? fullText;
  final bool isTyping;
  final bool isStreaming;

  // สำหรับ accent ตาม severity
  final SeverityTone tone;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? time,
    this.fullText,
    this.isTyping = false,
    this.isStreaming = false,
    this.tone = SeverityTone.none,
  }) : time = time ?? DateTime.now();
}

class ChatAiScreen extends StatefulWidget {
  const ChatAiScreen({super.key});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  bool _sending = false;
  bool _showJump = false;

  Timer? _streamTimer;

  // ---------- Voice ----------
  // ✅ หน้านี้ขอ permission อย่างเดียว (ไม่ init STT)
  final FlutterTts _tts = FlutterTts();

  // ✅ readiness = permission พร้อม
  bool _sttReady = false;

  // ✅ ใช้บอกเหตุผลว่าทำไมไมค์ใช้ไม่ได้
  String? _voiceError;

  final List<ChatMessage> _messages = [
    ChatMessage(
      role: ChatRole.assistant,
      text:
          'สวัสดีค่ะ 😊\n\nอยากให้ช่วยเรื่องไหนเลือกได้เลย:\n- สรุปแจ้งเตือนล่าสุด\n- แนะนำการปฏิบัติตัวตอนเกิดแรงสั่น\n- อธิบายระดับความรุนแรง (Caution/Severe)\n\nพิมพ์มาได้เลยค่ะ',
    ),
  ];

  // ---------- Theme ----------
  static const _bg = Color(0xFFF6F7FB);
  static const _black = Colors.black;
  static const _white = Colors.white;

  Color _toneColor(SeverityTone tone) {
    switch (tone) {
      case SeverityTone.severe:
        return const Color(0xFFE53935);
      case SeverityTone.caution:
        return const Color(0xFFFFB300);
      case SeverityTone.none:
        return Colors.transparent;
    }
  }

  SeverityTone _inferTone(String text) {
    final t = text.toLowerCase();

    if (t.contains('"severity"') && t.contains('severe')) return SeverityTone.severe;
    if (t.contains('"severity"') && (t.contains('caution') || t.contains('moderate'))) {
      return SeverityTone.caution;
    }

    if (t.contains('severe') || t.contains('รุนแรงมาก') || t.contains('อันตราย')) {
      return SeverityTone.severe;
    }
    if (t.contains('caution') || t.contains('เฝ้าระวัง') || t.contains('ปานกลาง')) {
      return SeverityTone.caution;
    }

    return SeverityTone.none;
  }

  // ---------- Lifecycle ----------
  @override
  void initState() {
    super.initState();

    // ✅ เตรียม permission เสียงไว้ล่วงหน้า
    _initVoice();

    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final offset = _scrollCtrl.offset;
      final shouldShow = (max - offset) > 280;
      if (shouldShow != _showJump) setState(() => _showJump = shouldShow);
    });
  }

  @override
  void dispose() {
    _streamTimer?.cancel();

    _tts.stop();

    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------- Utils ----------
  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openPermissionSettingsHint(String msg) async {
    _toast(msg);
    await Future.delayed(const Duration(milliseconds: 250));
    await openAppSettings();
  }

  // ---------- Voice Init (permission only) ----------
  Future<void> _initVoice() async {
    try {
      if (!mounted) return;
      setState(() {
        _voiceError = null;
        _sttReady = false;
      });

      final mic = await Permission.microphone.request();
      final speech = await Permission.speech.request();

      debugPrint('🎤 mic: $mic | 🗣 speech: $speech');

      if (!mic.isGranted || !speech.isGranted) {
        if (!mounted) return;
        setState(() {
          _sttReady = false;
          _voiceError =
              'ไมค์/การรู้จำเสียงถูกปิด\nไปที่ Settings > Privacy & Security > Microphone / Speech Recognition';
        });
        return;
      }

      // ✅ ตั้งค่า TTS พื้นฐานได้ แต่ "ห้าม" set iOS audio category เป็น playback ที่นี่
      await _tts.setLanguage('th-TH');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      if (!mounted) return;
      setState(() {
        _sttReady = true;
        _voiceError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sttReady = false;
        _voiceError = 'Init voice failed: $e';
      });
    }
  }

  Future<void> _ensureVoiceReadyOrExplain() async {
    if (_sttReady) return;

    await _initVoice();

    if (_sttReady) {
      _toast('ไมค์พร้อมแล้วครับ');
      return;
    }

    final msg = _voiceError ?? 'ไมค์ยังไม่พร้อม';
    if (msg.contains('ถาวร') || msg.contains('Settings')) {
      await _openPermissionSettingsHint(msg);
      return;
    }
    _toast(msg);
  }

  // ✅ เปิดหน้า Voice Chat เต็มจอ
  Future<void> _openVoiceChat() async {
    if (_sending) return;

    if (!_sttReady) {
      await _ensureVoiceReadyOrExplain();
      if (!_sttReady) return;
    }

    // ✅ กัน TTS ค้างก่อนสลับไปหน้าอัดเสียง
    await _tts.stop();

    FocusScope.of(context).unfocus();

    final result = await Navigator.push<VoiceChatResult>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceChatScreen()),
    );

    if (!mounted || result == null) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: result.userText));
      _messages.add(ChatMessage(
        role: ChatRole.assistant,
        text: result.assistantText,
        tone: _inferTone(result.assistantText),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent + 200;
      if (!animated) {
        _scrollCtrl.jumpTo(target);
      } else {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDay(DateTime t) {
    const months = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${t.day} ${months[t.month]} ${t.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------- Bottom sheet actions ----------
  Future<void> _openMessageActions(ChatMessage msg) async {
    final tone = msg.tone;
    final accent = _toneColor(tone);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                  color: Colors.black.withOpacity(0.12),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 46,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (tone != SeverityTone.none)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tone == SeverityTone.severe ? 'Severity: SEVERE' : 'Severity: CAUTION',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.black.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                _ActionTile(
                  icon: Icons.copy_rounded,
                  title: 'Copy',
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(ClipboardData(text: msg.text));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('คัดลอกข้อความแล้ว')),
                    );
                  },
                ),
                _ActionTile(
                  icon: Icons.ios_share_rounded,
                  title: 'Share',
                  onTap: () async {
                    Navigator.pop(context);
                    await Share.share(msg.text);
                  },
                ),
                _ActionTile(
                  icon: Icons.report_gmailerrorred_rounded,
                  title: 'Report',
                  danger: true,
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Report message'),
                        content: const Text(
                          'ตอนนี้ยังเป็นตัวอย่าง UI นะครับ\nถ้าหนูอยากให้ “Report ส่งเข้า backend” บอกได้ เดี๋ยวพี่ทำ endpoint ให้ต่อได้เลย',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ปิด'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Streaming ----------
  Future<void> _streamAssistantReply({
    required ChatMessage target,
    required String full,
    Duration speed = const Duration(milliseconds: 14),
  }) async {
    _streamTimer?.cancel();

    int i = 0;
    const chunk = 2;

    _streamTimer = Timer.periodic(speed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (i >= full.length) {
        timer.cancel();
        return;
      }
      final next = (i + chunk).clamp(0, full.length);
      setState(() {
        target.text = full.substring(0, next);
      });
      i = next;
      _scrollToBottom();
    });
  }

  // ---------- Send ----------
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
    });
    _ctrl.clear();
    _scrollToBottom();

    final typing = ChatMessage(role: ChatRole.assistant, text: '', isTyping: true);
    setState(() => _messages.add(typing));
    _scrollToBottom();

    try {
      final reply = await ChatService.sendMessage(text);
      final tone = _inferTone(reply);

      final streamed = ChatMessage(
        role: ChatRole.assistant,
        text: '',
        fullText: reply,
        isStreaming: true,
        tone: tone,
      );

      setState(() {
        _messages.remove(typing);
        _messages.add(streamed);
      });
      _scrollToBottom();

      await _streamAssistantReply(target: streamed, full: reply);

      // ถ้าจะให้หน้าแชทพูดเองค่อยเปิด แล้วอย่าลืม _tts.stop() ก่อนเข้า voice
      // await _tts.speak(reply);
    } catch (e) {
      setState(() {
        _messages.remove(typing);
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          text: 'ขอโทษครับ เกิดข้อผิดพลาดในการคุยกับบอท\n${e.toString()}',
          tone: SeverityTone.none,
        ));
      });
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        surfaceTintColor: _white,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.waves_rounded, color: _white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'QuakeLink AI',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                SizedBox(height: 2),
                Text(
                  'Assistant • Safety & Summary',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat (local)',
            onPressed: () {
              setState(() {
                _messages
                  ..clear()
                  ..add(ChatMessage(
                    role: ChatRole.assistant,
                    text:
                        'เริ่มใหม่ได้เลยครับ 😊\n\nพิมพ์มาได้เลยว่า:\n- “สรุปแจ้งเตือนล่าสุด”\n- “อธิบายระดับความรุนแรง”\n- “แนะนำการเอาตัวรอด”',
                  ));
              });
              _scrollToBottom(animated: false);
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 118),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isUser = m.role == ChatRole.user;

                      final prev = i > 0 ? _messages[i - 1] : null;
                      final showDay = prev == null || !_isSameDay(prev.time, m.time);

                      return Column(
                        children: [
                          if (showDay) _DayDivider(label: _formatDay(m.time)),
                          _MessageRow(
                            message: m,
                            isUser: isUser,
                            timeText: _formatTime(m.time),
                            toneColor: _toneColor(m.tone),
                            onActions: () => _openMessageActions(m),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _Composer(
                controller: _ctrl,
                focusNode: _focusNode,
                sending: _sending,
                onSend: _send,
                sttReady: _sttReady,
                onMicTap: _openVoiceChat,
                onMicTapWhenDisabled: _ensureVoiceReadyOrExplain,
              ),
            ),
            Positioned(
              right: 14,
              bottom: 100,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: _showJump ? 1 : 0.92,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showJump ? 1 : 0,
                  child: _JumpToBottomButton(onTap: () => _scrollToBottom()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- UI Pieces ----------------

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = danger ? const Color(0xFFE53935) : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: c),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: c,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  final String label;

  const _DayDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: Colors.black.withOpacity(0.08)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: Colors.black.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final String timeText;
  final Color toneColor;
  final VoidCallback onActions;

  const _MessageRow({
    required this.message,
    required this.isUser,
    required this.timeText,
    required this.toneColor,
    required this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBg = isUser ? Colors.black : Colors.white;
    final avatarFg = isUser ? Colors.white : Colors.black;
    final avatarIcon = isUser ? Icons.person_rounded : Icons.waves_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(bg: avatarBg, fg: avatarFg, icon: avatarIcon),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: message.isTyping
                ? const _TypingBubble()
                : _ModernBubble(
                    text: message.text,
                    isUser: isUser,
                    timeText: timeText,
                    toneColor: toneColor,
                    onLongPress: onActions,
                  ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _Avatar(bg: avatarBg, fg: avatarFg, icon: avatarIcon),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Color bg;
  final Color fg;
  final IconData icon;

  const _Avatar({required this.bg, required this.fg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Icon(icon, color: fg, size: 18),
    );
  }
}

class _ModernBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String timeText;
  final Color toneColor;
  final VoidCallback onLongPress;

  const _ModernBubble({
    required this.text,
    required this.isUser,
    required this.timeText,
    required this.toneColor,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? Colors.black : Colors.white;
    final borderColor = isUser ? Colors.transparent : Colors.black.withOpacity(0.07);
    final subColor = isUser ? Colors.white70 : Colors.black54;
    final hasTone = toneColor != Colors.transparent;

    final mdStyle = MarkdownStyleSheet(
      p: TextStyle(
        color: isUser ? Colors.white : Colors.black87,
        height: 1.35,
        fontSize: 15.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      code: TextStyle(
        color: isUser ? Colors.white : Colors.black87,
        fontFamily: 'monospace',
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
      codeblockDecoration: BoxDecoration(
        color: isUser ? Colors.white.withOpacity(0.12) : const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isUser ? Colors.white : Colors.black).withOpacity(0.12)),
      ),
      blockquoteDecoration: BoxDecoration(
        color: isUser ? Colors.white.withOpacity(0.10) : const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isUser ? Colors.white70 : Colors.black45,
            width: 3,
          ),
        ),
      ),
      listBullet: TextStyle(
        color: isUser ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w900,
      ),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 18),
              ),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(isUser ? 0.10 : 0.05),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (hasTone && !isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: toneColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Alert severity',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: Colors.black.withOpacity(0.70),
                          ),
                        ),
                      ],
                    ),
                  ),
                MarkdownBody(
                  data: text.isEmpty ? ' ' : text,
                  selectable: true,
                  styleSheet: mdStyle,
                  onTapLink: (txt, href, title) {},
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: subColor),
                    const SizedBox(width: 4),
                    Text(
                      timeText,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasTone && !isUser)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: toneColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: const _TypingDots(),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
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

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  final bool sttReady;
  final VoidCallback onMicTap;
  final VoidCallback onMicTapWhenDisabled;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.sttReady,
    required this.onMicTap,
    required this.onMicTapWhenDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            border: Border(top: BorderSide(color: Colors.black.withOpacity(0.07))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !sending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'พิมพ์ข้อความถึง QuakeLink AI…',
                    filled: true,
                    fillColor: const Color(0xFFF2F3F7),
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    prefixIconColor: Colors.black54,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: (!sttReady || sending) ? onMicTapWhenDisabled : onMicTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (!sttReady || sending) ? Colors.black12 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.10)),
                    boxShadow: (!sttReady || sending)
                        ? []
                        : [
                            BoxShadow(
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                              color: Colors.black.withOpacity(0.08),
                            )
                          ],
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: (!sttReady || sending) ? Colors.black45 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sending ? Colors.black26 : Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: sending
                        ? []
                        : [
                            BoxShadow(
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                              color: Colors.black.withOpacity(0.14),
                            )
                          ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpToBottomButton extends StatelessWidget {
  final VoidCallback onTap;

  const _JumpToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.arrow_downward_rounded, size: 18),
              SizedBox(width: 6),
              Text(
                'ล่าสุด',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
