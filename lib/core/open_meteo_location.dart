import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Coordenadas para [api.open-meteo.com](https://open-meteo.com) (sin API key).
/// Prioridad: `--dart-define=OPEN_METEO_LAT` / `OPEN_METEO_LON` → `.env` → Córdoba (AR).
class OpenMeteoLocation {
  OpenMeteoLocation._();

  /// Centro aproximado de Córdoba, Argentina.
  static const double _defaultLat = -31.4201;
  static const double _defaultLon = -64.1888;

  static double get latitude => _coord(
        const String.fromEnvironment('OPEN_METEO_LAT', defaultValue: ''),
        dotenv.isInitialized ? dotenv.env['OPEN_METEO_LAT'] : null,
        _defaultLat,
      );

  static double get longitude => _coord(
        const String.fromEnvironment('OPEN_METEO_LON', defaultValue: ''),
        dotenv.isInitialized ? dotenv.env['OPEN_METEO_LON'] : null,
        _defaultLon,
      );

  static double _coord(String fromDefine, String? fromDotenv, double fallback) {
    final t = fromDefine.trim().isNotEmpty
        ? fromDefine.trim()
        : (fromDotenv?.trim() ?? '');
    if (t.isEmpty) return fallback;
    return double.tryParse(t.replaceAll(',', '.')) ?? fallback;
  }
}
