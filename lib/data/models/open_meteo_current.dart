/// Respuesta mínima del endpoint `current` de Open-Meteo.
class OpenMeteoCurrent {
  const OpenMeteoCurrent({
    required this.temperatureC,
    required this.weatherCode,
  });

  final double temperatureC;

  /// Código WMO según Open-Meteo (condición actual).
  final int weatherCode;
}
