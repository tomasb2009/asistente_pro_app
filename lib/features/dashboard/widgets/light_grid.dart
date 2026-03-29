import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/home_zones.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class LightGrid extends ConsumerWidget {
  const LightGrid({super.key});

  Future<void> _runCommand(
    BuildContext context,
    WidgetRef ref,
    String message,
    void Function(bool success) onOptimistic,
  ) async {
    final api = ref.read(assistantApiProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.query(message);
      onOptimistic(true);
    } catch (e) {
      onOptimistic(false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final states = ref.watch(lightStatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Luces por zona',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Toca encender o apagar en cada zona.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
              ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cross = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                mainAxisExtent: 148,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: lightZoneConfigs.length,
              itemBuilder: (context, index) {
                final zone = lightZoneConfigs[index];
                final on = states[zone.id] ?? false;
                return _ZoneTile(
                  zone: zone,
                  isOn: on,
                  onOn: () => _runCommand(context, ref, zone.onMessage, (ok) {
                    if (ok) {
                      ref.read(lightStatesProvider.notifier).setZone(zone.id, true);
                    }
                  }),
                  onOff: () => _runCommand(context, ref, zone.offMessage, (ok) {
                    if (ok) {
                      ref.read(lightStatesProvider.notifier).setZone(zone.id, false);
                    }
                  }),
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _runCommand(context, ref, allLightsOnMessage, (ok) {
                if (ok) ref.read(lightStatesProvider.notifier).setAll(true);
              }),
              icon: const Icon(Icons.lightbulb_rounded),
              label: const Text('Todas ON'),
            ),
            OutlinedButton.icon(
              onPressed: () => _runCommand(context, ref, allLightsOffMessage, (ok) {
                if (ok) ref.read(lightStatesProvider.notifier).setAll(false);
              }),
              icon: const Icon(Icons.lightbulb_outline_rounded),
              label: const Text('Todas OFF'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.zone,
    required this.isOn,
    required this.onOn,
    required this.onOff,
  });

  final LightZoneConfig zone;
  final bool isOn;
  final VoidCallback onOn;
  final VoidCallback onOff;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                  color: isOn ? AppTheme.accentCyan : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zone.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOn
                        ? AppTheme.accentCyan.withValues(alpha: 0.15)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.border.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: isOn ? AppTheme.accentCyan : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOn,
                    child: const Text('Encender'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOff,
                    child: const Text('Apagar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
