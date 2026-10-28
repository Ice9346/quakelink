// lib/screens/safety_guide_screen.dart
import 'package:flutter/material.dart';

import '../services/emergency_action_service.dart';
import '../widgets/emergency_action_grid.dart';

enum AppLang { th, en }

class SafetyGuideScreen extends StatefulWidget {
  const SafetyGuideScreen({super.key});

  @override
  State<SafetyGuideScreen> createState() => _SafetyGuideScreenState();
}

class _SafetyGuideScreenState extends State<SafetyGuideScreen> {
  // ✅ เริ่มต้นเป็นภาษาไทย
  AppLang _lang = AppLang.th;

  String _t(String key) => _strings[_lang]?[key] ?? key;

  static const Map<AppLang, Map<String, String>> _strings = {
    AppLang.th: {
      'title': 'คู่มือความปลอดภัย',
      'offline': 'ใช้งานได้แบบออฟไลน์ - โปรดบันทึกคำแนะนำนี้ไว้ใช้ยามฉุกเฉิน',
      'quick_actions': 'การช่วยเหลือด่วน',
      'call_medical': 'โทร 1669',
      'im_safe': 'ฉันปลอดภัย',
      'share_location': 'แชร์ตำแหน่ง',

      'indoors_title': 'ควรทำอย่างไรเมื่ออยู่ในอาคาร',
      'indoors_b1': 'หมอบ-หลบ-ยึด (Drop, Cover, Hold) ใต้โต๊ะที่แข็งแรง',
      'indoors_b2': 'อยู่ห่างจากหน้าต่าง กระจก และเฟอร์นิเจอร์หนัก',
      'indoors_b3': 'ห้ามใช้ลิฟต์',

      'outdoors_title': 'ควรทำอย่างไรเมื่ออยู่นอกอาคาร',
      'outdoors_b1': 'ไปยังที่โล่ง ห่างจากอาคารและสายไฟ',
      'outdoors_b2': 'อยู่ห่างจากสะพานและทางยกระดับ',
      'outdoors_b3': 'หลีกเลี่ยงการยืนใต้ต้นไม้หรือป้าย',

      'car_title': 'ควรทำอย่างไรเมื่ออยู่ในรถ',
      'car_b1': 'จอดชิดข้างทางในจุดปลอดภัย ห่างจากสะพานและอาคาร',
      'car_b2': 'อยู่ในรถ คาดเข็มขัดนิรภัยไว้',
      'car_b3': 'ห้ามจอดใต้ทางยกระดับหรือใกล้สายไฟ',

      'tall_title': 'ใกล้อาคารสูง',
      'tall_b1': 'ออกห่างจากผนังอาคารและกระจกด้านหน้า',
      'tall_b2': 'ระวังของตกหล่นและเศษกระจก',
      'tall_b3': 'เมื่อการสั่นไหวหยุด ให้ย้ายไปยังพื้นที่โล่งที่ปลอดภัย',

      'kit_title': 'รายการอุปกรณ์ฉุกเฉิน',
      'kit_b1': 'น้ำดื่มและอาหารแห้ง/อาหารกระป๋อง (อย่างน้อย 3 วัน)',
      'kit_b2': 'ไฟฉาย ถ่าน/แบตเตอรี่สำรอง พาวเวอร์แบงก์',
      'kit_b3': 'ชุดปฐมพยาบาล ยาประจำตัว เอกสารสำคัญ',

      'firstaid_title': 'ข้อมูลปฐมพยาบาลเบื้องต้น',
      'firstaid_b1': 'ตรวจการหายใจและเลือดออกรุนแรงก่อน',
      'firstaid_b2': 'ห้ามเคลื่อนย้ายผู้บาดเจ็บหนัก เว้นแต่มีอันตราย',
      'firstaid_b3': 'โทรแจ้งหน่วยฉุกเฉินและปฏิบัติตามคำแนะนำ',

      'contacts_title': 'เบอร์ติดต่อฉุกเฉิน',
      'contact_191': 'เหตุด่วนเหตุร้าย',
      'contact_1669': 'แพทย์ฉุกเฉิน',
      'contact_1784': 'ป้องกันและบรรเทาสาธารณภัย',

      'th': 'TH',
      'en': 'EN',
    },
    AppLang.en: {
      'title': 'Safety Guide',
      'offline': 'Available offline - Save these instructions for emergencies',
      'quick_actions': 'Quick Actions',
      'call_medical': 'Call 1669',
      'im_safe': "I'm safe",
      'share_location': 'Share location',

      'indoors_title': 'What to Do Indoors',
      'indoors_b1': 'Drop, Cover, and Hold under a sturdy table.',
      'indoors_b2': 'Stay away from windows, glass, and heavy furniture.',
      'indoors_b3': 'Do not use elevators.',

      'outdoors_title': 'What to Do Outdoors',
      'outdoors_b1':
          'Move to an open area away from buildings and power lines.',
      'outdoors_b2': 'Stay away from bridges and overpasses.',
      'outdoors_b3': 'Avoid standing under trees or signs.',

      'car_title': 'What to Do in a Car',
      'car_b1': 'Pull over to a safe area away from bridges and buildings.',
      'car_b2': 'Stay inside the car with seatbelt fastened.',
      'car_b3': 'Do not park under overpasses or near power lines.',

      'tall_title': 'Near Tall Buildings',
      'tall_b1': 'Move away from building walls and glass facades.',
      'tall_b2': 'Watch out for falling objects and broken glass.',
      'tall_b3': 'Once shaking stops, move to a safe open area.',

      'kit_title': 'Emergency Kit Checklist',
      'kit_b1': 'Drinking water and non-perishable food (3 days).',
      'kit_b2': 'Flashlight, batteries, power bank.',
      'kit_b3': 'First-aid kit, medicines, important documents.',

      'firstaid_title': 'First Aid Quick Info',
      'firstaid_b1': 'Check for breathing and severe bleeding first.',
      'firstaid_b2': 'Do not move seriously injured persons unless in danger.',
      'firstaid_b3': 'Call emergency services and follow their instructions.',

      'contacts_title': 'Emergency Contacts',
      'contact_191': 'Emergency Services',
      'contact_1669': 'Medical Emergency',
      'contact_1784': 'Disaster Prevention',

      'th': 'TH',
      'en': 'EN',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ---------------- Header: Back + Title + Lang switch ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),

                  Expanded(
                    child: Text(
                      _t('title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  // ✅ ปุ่มเลือกภาษา (แทน SizedBox เดิม)
                  _LangToggle(
                    lang: _lang,
                    onChanged: (v) => setState(() => _lang = v),
                    thLabel: _t('th'),
                    enLabel: _t('en'),
                  ),
                ],
              ),
            ),

            // ---------------- Body (scrollable) ----------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _OfflineInfoCard(text: _t('offline')),
                    const SizedBox(height: 12),
                    EmergencyActionGrid(
                      title: _t('quick_actions'),
                      callLabel: _t('call_medical'),
                      safeLabel: _t('im_safe'),
                      locationLabel: _t('share_location'),
                      elevated: true,
                    ),
                    const SizedBox(height: 12),

                    _SafetySectionCard(
                      icon: Icons.home_rounded,
                      title: _t('indoors_title'),
                      bullets: [
                        _t('indoors_b1'),
                        _t('indoors_b2'),
                        _t('indoors_b3'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    _SafetySectionCard(
                      icon: Icons.park_rounded,
                      title: _t('outdoors_title'),
                      bullets: [
                        _t('outdoors_b1'),
                        _t('outdoors_b2'),
                        _t('outdoors_b3'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    _SafetySectionCard(
                      icon: Icons.directions_car_rounded,
                      title: _t('car_title'),
                      bullets: [_t('car_b1'), _t('car_b2'), _t('car_b3')],
                    ),
                    const SizedBox(height: 8),

                    _SafetySectionCard(
                      icon: Icons.location_city_rounded,
                      title: _t('tall_title'),
                      bullets: [_t('tall_b1'), _t('tall_b2'), _t('tall_b3')],
                    ),
                    const SizedBox(height: 8),

                    _SafetySectionCard(
                      icon: Icons.backpack_rounded,
                      title: _t('kit_title'),
                      bullets: [_t('kit_b1'), _t('kit_b2'), _t('kit_b3')],
                    ),
                    const SizedBox(height: 8),

                    _SafetySectionCard(
                      icon: Icons.medical_services_rounded,
                      title: _t('firstaid_title'),
                      bullets: [
                        _t('firstaid_b1'),
                        _t('firstaid_b2'),
                        _t('firstaid_b3'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _EmergencyContactsCard(
                      title: _t('contacts_title'),
                      rows: [
                        ContactRowData(label: _t('contact_191'), number: '191'),
                        ContactRowData(
                          label: _t('contact_1669'),
                          number: '1669',
                        ),
                        ContactRowData(
                          label: _t('contact_1784'),
                          number: '1784',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Toggle ภาษา TH/EN
class _LangToggle extends StatelessWidget {
  final AppLang lang;
  final ValueChanged<AppLang> onChanged;
  final String thLabel;
  final String enLabel;

  const _LangToggle({
    required this.lang,
    required this.onChanged,
    required this.thLabel,
    required this.enLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangChip(
            text: thLabel,
            selected: lang == AppLang.th,
            onTap: () => onChanged(AppLang.th),
          ),
          _LangChip(
            text: enLabel,
            selected: lang == AppLang.en,
            onTap: () => onChanged(AppLang.en),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// การ์ด Available offline (รับ text จากภายนอก)
class _OfflineInfoCard extends StatelessWidget {
  final String text;
  const _OfflineInfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดหัวข้อ Safety แต่ละอัน (แบบขยายได้)
class _SafetySectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> bullets;

  const _SafetySectionCard({
    required this.icon,
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.black12,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.keyboard_arrow_down_rounded),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bullets
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              b,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactRowData {
  final String label;
  final String number;
  const ContactRowData({required this.label, required this.number});
}

/// การ์ด Emergency Contacts ด้านล่างสุด (รับ title/rows จากภายนอก)
class _EmergencyContactsCard extends StatelessWidget {
  final String title;
  final List<ContactRowData> rows;

  const _EmergencyContactsCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.grey.shade300,
          splashColor: Colors.black12,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: const Icon(
              Icons.phone_rounded,
              size: 20,
              color: Colors.black87,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          children: rows
              .map((r) => _ContactRow(label: r.label, number: r.number))
              .toList(),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String label;
  final String number;

  const _ContactRow({required this.label, required this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Text(
            number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.call_rounded, size: 18),
            onPressed: () => EmergencyActionService.callNumber(number),
          ),
        ],
      ),
    );
  }
}
