/// Parámetros fijos para audio OpenAI (Whisper + TTS).
/// La clave API no va aquí: usa Ajustes, variable de entorno o `--dart-define`.
class OpenAiConfig {
  OpenAiConfig._();

  static const String apiBaseUrl = 'https://api.openai.com/v1';

  static const String whisperModel = 'whisper-1';

  /// TTS con [instructions] solo en modelos compatibles (p. ej. gpt-4o-mini-tts).
  static const String ttsModel = 'gpt-4o-mini-tts';

  static const String ttsVoice = 'cedar';

  /// Rango API habitual 0.25–4.0; 1.0 = normal.
  static const double ttsSpeed = 1.25;

  /// Guía de estilo para la voz generada.
  static const String ttsInstructions =
      'Hablás con calma y precisión. No tomes pausas innecesarias.';

  static const String ttsResponseFormat = 'mp3';

  /// Idioma esperado del usuario al transcribir (mejora precisión).
  static const String whisperLanguage = 'es';

  static const int audioTimeoutSeconds = 120;
}
