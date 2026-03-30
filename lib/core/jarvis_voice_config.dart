/// Detección de wake phrase por Whisper en ventanas cortas + grabación de comando.
class JarvisVoiceConfig {
  JarvisVoiceConfig._();

  /// Ventana de audio para buscar «ok asistente» (un poco larga para no exigir silencio previo).
  static const int wakeScanChunkSeconds = 4;

  /// Tras el wake: segundos de [current] por debajo del umbral = fin de frase (más corto = más ágil).
  static const int commandSilenceSeconds = 2;

  /// Máximo de grabación del comando (por si el VAD no corta: ruido de fondo, driver raro).
  static const int maxCommandRecordingSeconds = 40;

  /// Mínimo de grabación antes de poder cortar por silencio (evita cortar el pitido).
  static const int minCommandRecordingMs = 500;

  /// Tiempo inicial para "calibrar" ruido/voz del entorno al empezar cada comando.
  static const int vadCalibrationMs = 900;

  /// Umbral adaptativo: porcentaje del rango [ruido..voz] usado para decidir "hay voz".
  static const double vadThresholdVoiceRatio = 0.38;

  /// Diferencia mínima entre ruido y umbral para evitar cortes falsos por ruido.
  static const double vadMinDeltaDb = 6.0;

  /// Límite superior del umbral adaptativo (más cerca de 0 = más estricto).
  static const double vadMaxThresholdDb = -30.0;

  /// Umbral de respaldo si todavía no hay buena calibración de voz.
  static const double vadFallbackSpeechDb = -46.0;

  /// Wake word: **«ok asistente»**. Variantes: ok/okay/oye/okey y coma opcional.
  static final RegExp wakePhraseRegex = RegExp(
    r'(ok|okay|oke|oye|okey)[\s,]+asistente\b',
    caseSensitive: false,
  );

  static bool textContainsWakePhrase(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return wakePhraseRegex.hasMatch(text);
  }
}
