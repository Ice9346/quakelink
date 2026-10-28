// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // โทนเดียวกับหน้าอื่น
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ---------------- Header ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),

            // ---------------- Body (scrollable) ----------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: const [
                    _AppInfoCard(),
                    SizedBox(height: 16),
                    _SettingsSectionCard(
                      header: 'GENERAL',
                      items: [
                        _SettingsItem(
                          icon: Icons.notifications_rounded,
                          title: 'Notifications',
                          subtitle: 'Manage alert preferences',
                        ),
                        _SettingsItem(
                          icon: Icons.language_rounded,
                          title: 'Language',
                          subtitle: 'English',
                        ),
                        _SettingsItem(
                          icon: Icons.palette_rounded,
                          title: 'Appearance',
                          subtitle: 'Dark mode',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _SettingsSectionCard(
                      header: 'DATA & PRIVACY',
                      items: [
                        _SettingsItem(
                          icon: Icons.shield_rounded,
                          title: 'Privacy Policy',
                          subtitle: '',
                        ),
                        _SettingsItem(
                          icon: Icons.storage_rounded,
                          title: 'Data Usage',
                          subtitle: 'Manage offline data',
                        ),
                        _SettingsItem(
                          icon: Icons.location_on_rounded,
                          title: 'Location Services',
                          subtitle: 'Required for alerts',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _SettingsSectionCard(
                      header: 'SUPPORT',
                      items: [
                        _SettingsItem(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & FAQ',
                          subtitle: '',
                        ),
                        _SettingsItem(
                          icon: Icons.feedback_rounded,
                          title: 'Send Feedback',
                          subtitle: '',
                        ),
                        _SettingsItem(
                          icon: Icons.info_outline_rounded,
                          title: 'About QuakeLink',
                          subtitle: '',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _EmergencyContactsCard(),
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

// ---------------------------------------------------------------------
// Top app info card
// ---------------------------------------------------------------------

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              size: 32,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'QuakeLink',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Real-time Earthquake Monitoring',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Section card + items
// ---------------------------------------------------------------------

class _SettingsSectionCard extends StatelessWidget {
  final String header;
  final List<_SettingsItem> items;

  const _SettingsSectionCard({
    required this.header,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _SettingsRow(item: items[i]),
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: Colors.grey.withOpacity(0.25),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingsItem item;

  const _SettingsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: () {
        // TODO: นำไปหน้า settings ย่อยต่าง ๆ
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(
                item.icon,
                size: 20,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Emergency contacts bottom card
// ---------------------------------------------------------------------

class _EmergencyContactsCard extends StatelessWidget {
  const _EmergencyContactsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.phone_rounded, size: 18, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                'EMERGENCY CONTACTS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _ContactRow(label: 'Emergency Services', number: '191'),
          _ContactRow(label: 'Medical Emergency', number: '1669'),
          _ContactRow(label: 'Disaster Prevention', number: '1784'),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
