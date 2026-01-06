import 'package:flutter/material.dart';
import 'package:teleport/features/onboarding/widgets.dart';

class NextStepsPage extends StatelessWidget {
  const NextStepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  "You're ready",
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "Pair a device and start sending files right away.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What happens next",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  const InfoRow(
                    icon: Icons.link,
                    text: "Pair your first device to unlock transfers.",
                  ),
                  const SizedBox(height: 8),
                  const InfoRow(
                    icon: Icons.notifications_active,
                    text: "Transfers run in the background with notifications.",
                  ),
                  const SizedBox(height: 8),
                  const InfoRow(
                    icon: Icons.share,
                    text: "Send from the share sheet or desktop shortcuts.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
