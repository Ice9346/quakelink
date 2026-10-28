import 'package:flutter/material.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // mock state
  String _language = 'en';
  bool _enableNotifications = true;
  bool _sound = true;
  bool _vibration = true;
  bool _nightSilent = true;
  double _minMagnitude = 3.0;
  String _userType = 'public';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ---------- Header ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // balance
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- Language ----------
                    _EditSectionCard(
                      title: 'Language',
                      child: Row(
                        children: [
                          _LanguageChip(
                            label: 'English',
                            isActive: _language == 'en',
                            onTap: () {
                              setState(() => _language = 'en');
                            },
                          ),
                          const SizedBox(width: 10),
                          _LanguageChip(
                            label: 'ไทย (Thai)',
                            isActive: _language == 'th',
                            onTap: () {
                              setState(() => _language = 'th');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---------- Notification Preferences ----------
                    _EditSectionCard(
                      title: 'Notification Preferences',
                      child: Column(
                        children: [
                          _SwitchRow(
                            title: 'Enable Notifications',
                            subtitle: 'Receive earthquake alerts',
                            value: _enableNotifications,
                            onChanged: (v) {
                              setState(() => _enableNotifications = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          _SwitchRow(
                            title: 'Sound',
                            subtitle: 'Play alert sound',
                            value: _sound,
                            onChanged: (v) {
                              setState(() => _sound = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          _SwitchRow(
                            title: 'Vibration',
                            subtitle: 'Vibrate on alerts',
                            value: _vibration,
                            onChanged: (v) {
                              setState(() => _vibration = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          _SwitchRow(
                            title: 'Night Mode Silent',
                            subtitle: 'Silent alerts at night (10 PM – 6 AM)',
                            value: _nightSilent,
                            onChanged: (v) {
                              setState(() => _nightSilent = v);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Minimum Magnitude
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Minimum Magnitude: 3.0',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Only notify for earthquakes above this magnitude',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _MagnitudeDots(
                            value: _minMagnitude,
                            onChanged: (v) {
                              setState(() => _minMagnitude = v);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---------- User Type ----------
                    _EditSectionCard(
                      title: 'User Type',
                      child: Column(
                        children: [
                          _UserTypeButton(
                            icon: Icons.person,
                            label: 'Public',
                            isActive: _userType == 'public',
                            onTap: () {
                              setState(() => _userType = 'public');
                            },
                          ),
                          const SizedBox(height: 8),
                          _UserTypeButton(
                            icon: Icons.groups_rounded,
                            label: 'Community Leader',
                            isActive: _userType == 'leader',
                            onTap: () {
                              setState(() => _userType = 'leader');
                            },
                          ),
                          const SizedBox(height: 8),
                          _UserTypeButton(
                            icon: Icons.shield_rounded,
                            label: 'Government',
                            isActive: _userType == 'gov',
                            onTap: () {
                              setState(() => _userType = 'gov');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: บันทึกข้อมูลจริง
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
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white),
                        label: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

// ---------- Widgets ย่อย ----------

class _EditSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _EditSectionCard({
    required this.title,
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: Colors.teal,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MagnitudeDots extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _MagnitudeDots({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 2.0 – 5.0 step 0.5 => 7 จุด (เอาแบบคร่าว ๆ)
    final List<double> options = [2, 2.5, 3, 3.5, 4, 4.5, 5];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: options.map((v) {
            final bool active = v <= value;
            return GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? Colors.black : Colors.white,
                  border: Border.all(
                    color: Colors.black26,
                    width: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('2.0',
                style: TextStyle(fontSize: 11, color: Colors.black54)),
            Text('5.0',
                style: TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ],
    );
  }
}

class _UserTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _UserTypeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
