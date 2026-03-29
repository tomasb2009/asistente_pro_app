import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/open_meteo_current.dart';
import '../../../providers/providers.dart';
import 'weather_code_icon.dart';

/// Cabecera del inicio: título a la izquierda; hora, fecha y clima (Open-Meteo) arriba a la derecha.
class DashboardHeader extends ConsumerStatefulWidget {
  const DashboardHeader({super.key});

  @override
  ConsumerState<DashboardHeader> createState() => _DashboardHeaderState();
}

String _weekdayEs(int weekday) {
  const names = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  return names[weekday - 1];
}

class _DashboardHeaderState extends ConsumerState<DashboardHeader> {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(_now);
    final dateStr =
        '${_weekdayEs(_now.weekday)}, ${DateFormat('dd/MM/yyyy').format(_now)}';

    final meteo = ref.watch(openMeteoCurrentProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.accentCyan.withValues(alpha: 0.95),
                      AppTheme.primaryBlue.withValues(alpha: 0.65),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentCyan.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Domótica',
                      style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Control del hogar',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeStr,
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: AppTheme.accentCyan,
                    letterSpacing: 1,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              dateStr,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            _MeteoChip(
              async: meteo,
              onRetry: () => ref.invalidate(openMeteoCurrentProvider),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeteoChip extends StatelessWidget {
  const _MeteoChip({
    required this.async,
    required this.onRetry,
  });

  final AsyncValue<OpenMeteoCurrent> async;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return async.when(
      data: (OpenMeteoCurrent data) {
        final t = data.temperatureC.round();
        return Tooltip(
          message: 'Open-Meteo · pulsa para actualizar',
          child: InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$t°',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                          height: 1,
                        ),
                  ),
                  const SizedBox(width: 8),
                  openMeteoWeatherIconWidget(data.weatherCode, size: 30),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 72,
        height: 32,
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, st) => Tooltip(
        message: '$e',
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 22,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Clima',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
