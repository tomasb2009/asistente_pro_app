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

  /// Nivel **instantáneo** (`Amplitude.current`, no `max`): en Windows `max` es pico acumulado
  /// y se queda alto para siempre → el corte por silencio nunca ocurría.
  /// Si `current` supera este dBFS se considera que hay voz (se reinicia el contador de silencio).
  static const double commandSpeechActivityMinDb = -46;

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
