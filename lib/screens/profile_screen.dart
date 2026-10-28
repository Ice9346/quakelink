import 'package:flutter/material.dart';
import '../app_router.dart';
import '../services/auth_service.dart';
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // mock data โปรไฟล์
    const name = 'Guest User';
    const province = 'Bangkok';
    const phoneNumber = '-';
    const userTypeLabel = 'Public';
    const language = 'English';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ---------- Modern App Bar ----------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    _IconPillButton(
                      icon: Icons.settings_outlined,
                      onTap: () {
                        // เผื่อหนูมี route settings อยู่แล้ว
                        // Navigator.of(context).pushNamed(AppRouter.settingsRoute);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ---------- Content ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // ---------- Profile Hero Card ----------
                    _ProfileHeroCard(
                      name: name,
                      userTypeLabel: userTypeLabel,
                      province: province,
                      phoneNumber: phoneNumber,
                    ),

                    const SizedBox(height: 14),

                    // ---------- Quick Actions ----------
                    _SectionTitle(
                      title: 'Quick actions',
                      subtitle: 'Shortcuts to common tasks',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.edit_outlined,
                            title: 'Edit',
                            subtitle: 'Update profile',
                            onTap: () {
                              Navigator.of(context)
                                  .pushNamed(AppRouter.profileEditRoute);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.health_and_safety_outlined,
                            title: 'Safety',
                            subtitle: 'Guidelines',
                            onTap: () {
                              // ถ้ามี route นี้อยู่
                              // Navigator.of(context).pushNamed(AppRouter.safetyGuideRoute);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ActionTileWide(
                      icon: Icons.history,
                      title: 'History',
                      subtitle: 'Recent alerts & activity',
                      onTap: () {
                        // ถ้ามี route history อยู่
                        // Navigator.of(context).pushNamed(AppRouter.historyRoute);
                      },
                    ),

                    const SizedBox(height: 18),

                    // ---------- Personal Info ----------
                    _SectionTitle(
                      title: 'Personal information',
                      subtitle: 'Basic profile details',
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: const [
                        _InfoTile(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: name,
                        ),
                        _DividerLine(),
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Province',
                          value: province,
                        ),
                        _DividerLine(),
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone number',
                          value: phoneNumber,
                          hint: 'Not provided',
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ---------- Preferences ----------
                    _SectionTitle(
                      title: 'Preferences',
                      subtitle: 'Language and notifications',
                    ),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _InfoTile(
                          icon: Icons.language_outlined,
                          label: 'Language',
                          value: language,
                        ),
                        const _DividerLine(),
                        const _InfoTile(
                          icon: Icons.notifications_active_outlined,
                          label: 'Earthquake alerts',
                          value: 'Enabled',
                          valueTone: _ValueTone.good,
                        ),
                        const _DividerLine(),
                        const _InfoTile(
                          icon: Icons.vibration_outlined,
                          label: 'Sound & vibration',
                          value: 'On',
                          valueTone: _ValueTone.good,
                        ),
                        const _DividerLine(),
                        const _InfoTile(
                          icon: Icons.nights_stay_outlined,
                          label: 'Night mode silent',
                          value: '10 PM – 6 AM',
                        ),
                        const _DividerLine(),
                        const _InfoTile(
                          icon: Icons.speed_outlined,
                          label: 'Minimum magnitude',
                          value: '3.0',
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ---------- CTA ----------
                    SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () async {
      // ลบ token
      await AuthService.instance.logout();

      if (!context.mounted) return;

      // เด้งไปหน้า login + เคลียร์ stack
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.loginRoute,
        (route) => false,
      );
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFB71C1C), // แดงเข้ม ดูเป็น action สำคัญ
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 18,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    icon: const Icon(Icons.logout, size: 18),
    label: const Text(
      'Logout',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    ),
  ),
),

                    const SizedBox(height: 10),

                    Center(
                      child: Text(
                        'QuakeLink • v1.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.45),
                          fontWeight: FontWeight.w600,
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

// ---------- UI Components ----------

class _ProfileHeroCard extends StatelessWidget {
  final String name;
  final String userTypeLabel;
  final String province;
  final String phoneNumber;

  const _ProfileHeroCard({
    required this.name,
    required this.userTypeLabel,
    required this.province,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    final safePhone = (phoneNumber.trim().isEmpty || phoneNumber == '-')
        ? 'Not provided'
        : phoneNumber;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.92),
            Colors.black.withOpacity(0.82),
          ],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),

              // Name + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Badge(
                      text: userTypeLabel.toUpperCase(),
                      icon: Icons.verified_user_outlined,
                    ),
                  ],
                ),
              ),

              // Edit small button
              _MiniIconButton(
                icon: Icons.edit_outlined,
                onTap: () {
                  Navigator.of(context).pushNamed(AppRouter.profileEditRoute);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Info chips
          Row(
            children: [
              Expanded(
                child: _GlassChip(
                  icon: Icons.location_on_outlined,
                  label: 'Province',
                  value: province,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassChip(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: safePhone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GlassChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Badge({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.title,
    this.subtitle,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black.withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

enum _ValueTone { normal, good, warn }

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final _ValueTone valueTone;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.valueTone = _ValueTone.normal,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value.trim().isNotEmpty && value != '-';
    final displayValue = hasValue ? value : (hint ?? '');

    Color valueColor = Colors.black87;
    if (!hasValue) valueColor = Colors.black45;

    if (valueTone == _ValueTone.good) {
      valueColor = const Color(0xFF1B5E20); // green-ish
    } else if (valueTone == _ValueTone.warn) {
      valueColor = const Color(0xFFB71C1C); // red-ish
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.62),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.black.withOpacity(0.28),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.black.withOpacity(0.06),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTileWide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTileWide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.black.withOpacity(0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconPillButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}
