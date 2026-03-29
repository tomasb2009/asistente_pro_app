import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Icono según código WMO devuelto por Open-Meteo.
IconData openMeteoWeatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_rounded;
  if (code == 1) return Icons.wb_twilight_rounded;
  if (code == 2) return Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.blur_on_rounded;
  if (code >= 51 && code <= 57) return Icons.grain_rounded;
  if (code >= 61 && code <= 67) return Icons.umbrella_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.water_drop_rounded;
  if (code == 85 || code == 86) return Icons.cloudy_snowing;
  if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
  return Icons.wb_cloudy_rounded;
}

Widget openMeteoWeatherIconWidget(int code, {double size = 26}) {
  return Icon(
    openMeteoWeatherIcon(code),
    size: size,
    color: AppTheme.accentCyan.withValues(alpha: 0.95),
  );
}
