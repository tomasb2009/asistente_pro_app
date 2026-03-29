/// URL base del backend FastAPI (sin barra final).
/// Override con `--dart-define=API_BASE=http://192.168.x.x:8000`
class AppConfig {
  AppConfig._();

  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE', defaultValue: '');
    if (fromEnv.isNotEmpty) return _trimSlash(fromEnv);
    return 'http://127.0.0.1:8000';
  }

  static String _trimSlash(String url) => url.replaceAll(RegExp(r'/$'), '');

  /// Timeout para respuestas del LLM (segundos).
  static const int queryTimeoutSeconds = 120;

  /// Timeout corto para `/health`.
  static const int healthTimeoutSeconds = 10;
}
