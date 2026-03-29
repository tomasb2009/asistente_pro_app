import 'package:flutter/material.dart';

import 'widgets/dashboard_header.dart';
import 'widgets/light_grid.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const DashboardHeader(),
              const SizedBox(height: 28),
              const LightGrid(),
            ]),
          ),
        ),
      ],
    );
  }
}
