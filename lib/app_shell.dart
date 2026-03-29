import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/settings/settings_page.dart';
import 'features/voice/voice_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['Domótica', 'Hablar', 'Ajustes'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1100,
            backgroundColor: AppTheme.backgroundAlt,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: MediaQuery.sizeOf(context).width >= 1100
                ? NavigationRailLabelType.all
                : NavigationRailLabelType.selected,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.auto_awesome, color: AppTheme.accentCyan.withValues(alpha: 0.9)),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('Domótica'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.mic_none_rounded),
                selectedIcon: Icon(Icons.mic_rounded),
                label: Text('Hablar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Ajustes'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: AppTheme.background.withValues(alpha: 0.96),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Row(
                      children: [
                        Text(
                          _titles[_index],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        Text(
                          'Asistente Pro',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_index) {
                      0 => const DashboardPage(key: ValueKey('d')),
                      1 => const VoicePage(key: ValueKey('v')),
                      _ => const SettingsPage(key: ValueKey('s')),
                    },
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
