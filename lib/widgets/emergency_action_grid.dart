import 'package:flutter/material.dart';

import '../models/alert_event.dart';
import '../services/emergency_action_service.dart';

class EmergencyActionGrid extends StatelessWidget {
  final AlertEvent? event;
  final String title;
  final String callLabel;
  final String safeLabel;
  final String locationLabel;
  final bool elevated;
  final bool inverted;
  final bool showTitle;

  const EmergencyActionGrid({
    super.key,
    this.event,
    this.title = 'Emergency actions',
    this.callLabel = 'Call 1669',
    this.safeLabel = "I'm safe",
    this.locationLabel = 'Share location',
    this.elevated = false,
    this.inverted = false,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                size: 20,
                color: inverted ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: inverted ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final stackVertically = constraints.maxWidth < 340;
            final actions = [
              _EmergencyActionButton(
                icon: Icons.phone_rounded,
                label: callLabel,
                isPrimary: true,
                inverted: inverted,
                onPressed: () => EmergencyActionService.callNumber('1669'),
              ),
              _EmergencyActionButton(
                icon: Icons.check_circle_rounded,
                label: safeLabel,
                inverted: inverted,
                onPressed: () =>
                    EmergencyActionService.shareImSafe(event: event),
              ),
              _EmergencyActionButton(
                icon: Icons.my_location_rounded,
                label: locationLabel,
                inverted: inverted,
                onPressed: EmergencyActionService.shareCurrentLocation,
              ),
            ];

            if (stackVertically) {
              return Column(
                children: [
                  for (final action in actions) ...[
                    action,
                    if (action != actions.last) const SizedBox(height: 8),
                  ],
                ],
              );
            }

            return Column(
              children: [
                actions.first,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: actions[1]),
                    const SizedBox(width: 8),
                    Expanded(child: actions[2]),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );

    if (!elevated && !inverted) return content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: inverted ? Colors.white.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: inverted
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: content,
    );
  }
}

class _EmergencyActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool inverted;
  final Future<void> Function() onPressed;

  const _EmergencyActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w900),
    );

    final minimumSize = const Size.fromHeight(46);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    Future<void> handlePress() async {
      try {
        await onPressed();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }

    if (isPrimary) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: inverted ? Colors.white : Colors.black,
          foregroundColor: inverted ? const Color(0xFF9B1C1C) : Colors.white,
          minimumSize: minimumSize,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: shape,
        ),
        onPressed: handlePress,
        icon: Icon(icon, size: 19),
        label: child,
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: inverted ? Colors.white : Colors.black87,
        minimumSize: minimumSize,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(
          color: inverted
              ? Colors.white.withValues(alpha: 0.42)
              : Colors.black.withValues(alpha: 0.14),
        ),
        shape: shape,
      ),
      onPressed: handlePress,
      icon: Icon(icon, size: 18),
      label: child,
    );
  }
}
