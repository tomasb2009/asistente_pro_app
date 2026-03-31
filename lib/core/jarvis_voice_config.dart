import 'package:flutter_dotenv/flutter_dotenv.dart';

class JarvisVoiceConfig {
  JarvisVoiceConfig._();

  static String get wakePhrase => _str('VOICE_WAKE_PHRASE', 'ok asistente');
  static final RegExp wakePhraseRegex = RegExp(
    r'(ok|okay|oke|oye|okey)[\s,]+asistente\b',
    caseSensitive: false,
  );

  static bool textContainsWakePhrase(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return wakePhraseRegex.hasMatch(text);
  }

  // Sidecar lifecycle
  static Duration get sidecarStartupTimeout =>
      Duration(seconds: _int('VOICE_SIDECAR_STARTUP_TIMEOUT_S', 10));
  static Duration get sidecarShutdownTimeout =>
      Duration(seconds: _int('VOICE_SIDECAR_SHUTDOWN_TIMEOUT_S', 3));
  static Duration get sidecarRestartBackoff =>
      Duration(milliseconds: _int('VOICE_SIDECAR_RESTART_BACKOFF_MS', 900));

  // IPC defaults
  static int get sampleRateHz => _int('VOICE_SAMPLE_RATE_HZ', 16000);
  static int get frameMs => _int('VOICE_FRAME_MS', 30);
  static int get commandSilenceMs => _int('VOICE_COMMAND_SILENCE_MS', 1400);
  static int get maxCommandMs => _int('VOICE_MAX_COMMAND_MS', 45000);
  static int get preRollMs => _int('VOICE_PRE_ROLL_MS', 350);
  static int get postRollMs => _int('VOICE_POST_ROLL_MS', 180);

  // Sidecar runtime toggles
  static bool get enableRnnoise => _bool('VOICE_ENABLE_RNNOISE', true);
  static bool get enableWebRtcVad => _bool('VOICE_ENABLE_WEBRTC_VAD', true);

  static String _str(String key, String fallback) {
    final fromDotenv = dotenv.isInitialized ? dotenv.env[key] : null;
    final v = (fromDotenv ?? '').trim();
    if (v.isNotEmpty) return v;
    return fallback;
  }

  static int _int(String key, int fallback) {
    final fromDotenv = dotenv.isInitialized ? dotenv.env[key] : null;
    final v = int.tryParse((fromDotenv ?? '').trim());
    return v ?? fallback;
  }

  static bool _bool(String key, bool fallback) {
    final fromDotenv = dotenv.isInitialized ? dotenv.env[key] : null;
    final raw = (fromDotenv ?? '').trim().toLowerCase();
    if (raw.isEmpty) return fallback;
    return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
  }
}

