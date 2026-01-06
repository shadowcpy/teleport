import 'package:flutter/material.dart';
import 'package:teleport/features/onboarding/widgets.dart';

class BackgroundInfoPage extends StatelessWidget {
  const BackgroundInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Background presence",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Keep Teleport running in the background so it can receive files. Look for the Teleport icon in your taskbar or menu bar.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  const InfoRow(
                    icon: Icons.pin_end,
                    text:
                        "Pin Teleport to your taskbar or dock for quick access.",
                  ),
                  const SizedBox(height: 8),
                  const InfoRow(
                    icon: Icons.cloud_done,
                    text: "Keep it open to receive files in the background.",
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
