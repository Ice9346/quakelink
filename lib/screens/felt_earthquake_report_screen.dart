import 'package:flutter/material.dart';

class FeltEarthquakeReportScreen extends StatefulWidget {
  const FeltEarthquakeReportScreen({super.key});

  @override
  State<FeltEarthquakeReportScreen> createState() =>
      _FeltEarthquakeReportScreenState();
}

class _FeltEarthquakeReportScreenState
    extends State<FeltEarthquakeReportScreen> {
  int _intensity = 5;
  String _buildingType = 'House';
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Color _intensityColor(int level) {
    // level: 1–10  → ไล่สีเขียว -> เหลือง -> แดง
    final t = (level - 1) / 9.0; // 0..1
    if (t < 0.5) {
      // เขียว → เหลือง
      return Color.lerp(Colors.green, Colors.orange, t / 0.5)!;
    } else {
      // เหลือง → แดง
      return Color.lerp(Colors.orange, Colors.red, (t - 0.5) / 0.5)!;
    }
  }

  Widget _buildIntensityDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(10, (index) {
        final level = index + 1;
        final selected = level <= _intensity;
        return GestureDetector(
          onTap: () {
            setState(() => _intensity = level);
          },
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _intensityColor(level) : Colors.grey.shade200,
              border: Border.all(
                color: selected ? Colors.black.withOpacity(0.15) : Colors.grey,
                width: selected ? 1.2 : 0.8,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBuildingChip(String label, IconData icon) {
    final selected = _buildingType == label;
    return GestureDetector(
      onTap: () => setState(() => _buildingType = label),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.shade300,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : Colors.black87,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        foregroundColor: Colors.black,
        title: const Text(
          'Report Earthquake',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Intro Card ----------
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 1.2),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.back_hand_rounded,
                        size: 28, color: Colors.black),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'I Felt The Shake',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Help us improve detection by reporting what you experienced.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---------- Intensity ----------
              _SectionCard(
                title: 'Intensity Level',
                subtitle:
                    'How strong was the shaking? (1 = barely felt, 10 = very strong)',
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      '$_intensity',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildIntensityDots(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'WEAK',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          'STRONG',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Building Type ----------
              _SectionCard(
                title: 'Building Type',
                subtitle: 'Where were you when you felt the earthquake?',
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildBuildingChip('House', Icons.home_rounded),
                      _buildBuildingChip('Condo', Icons.apartment_rounded),
                      _buildBuildingChip('School', Icons.school_rounded),
                      _buildBuildingChip('Factory', Icons.factory_rounded),
                      _buildBuildingChip('Office', Icons.business_center),
                      _buildBuildingChip('Other', Icons.other_houses_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Photo evidence ----------
              _SectionCard(
                title: 'Photo Evidence (Optional)',
                subtitle:
                    'Upload a photo of any damage or effects you observed',
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 28,
                          color: Colors.black45,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Upload Photo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap to select from gallery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---------- Contact number ----------
              _SectionCard(
                title: 'Contact Number (Optional)',
                subtitle: 'In case we need to follow up on your report',
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---------- Submit button ----------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: ส่งข้อมูลไประบบ backend
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted (mock).'),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text(
                    'Submit Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.lock_outline,
                      size: 14, color: Colors.black45),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your report is anonymous unless you provide contact information.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
