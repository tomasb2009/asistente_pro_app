import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../core/home_zones.dart';
import '../core/open_meteo_location.dart';
import '../data/api/assistant_api.dart';
import '../data/api/openai_audio_api.dart';
import '../data/api/open_meteo_api.dart';
import '../data/models/open_meteo_current.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider debe inyectarse en main()');
});

final apiBaseUrlProvider =
    NotifierProvider<ApiBaseUrlNotifier, String>(ApiBaseUrlNotifier.new);

class ApiBaseUrlNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_kKey) ?? AppConfig.defaultBaseUrl;
  }

  static const _kKey = 'api_base_url';

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    await ref.read(sharedPreferencesProvider).setString(_kKey, trimmed);
    state = trimmed;
  }
}

final assistantApiProvider = Provider<AssistantApi>((ref) {
  final base = ref.watch(apiBaseUrlProvider);
  return AssistantApi(baseUrl: base);
});

/// Clima actual (Open-Meteo, sin API key). [invalidate] para refrescar.
final openMeteoCurrentProvider =
    FutureProvider.autoDispose<OpenMeteoCurrent>((ref) {
  return OpenMeteoApi.fetchCurrent(
    latitude: OpenMeteoLocation.latitude,
    longitude: OpenMeteoLocation.longitude,
  );
});

/// Clave OpenAI: `OPENAI_API_KEY` en `.env` (raíz del proyecto o junto al .exe), o
/// `--dart-define=OPENAI_API_KEY=...` (tiene prioridad sobre el archivo).
final openAiApiKeyProvider = Provider<String?>((ref) {
  const fromDefine = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
  if (!dotenv.isInitialized) return null;
  final v = dotenv.env['OPENAI_API_KEY']?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
});

/// Cliente HTTP de audio; null si no hay clave configurada.
final openAiAudioApiProvider = Provider<OpenAiAudioApi?>((ref) {
  final k = ref.watch(openAiApiKeyProvider);
  return (k != null && k.isNotEmpty) ? OpenAiAudioApi(apiKey: k) : null;
});

final lightStatesProvider =
    NotifierProvider<LightStatesNotifier, Map<String, bool>>(
  LightStatesNotifier.new,
);

class LightStatesNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    return {for (final z in lightZoneConfigs) z.id: false};
  }

  void setZone(String id, bool on) {
    state = {...state, id: on};
  }

  void setAll(bool on) {
    state = {for (final z in lightZoneConfigs) z.id: on};
  }
}
