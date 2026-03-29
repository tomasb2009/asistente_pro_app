import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/openai_config.dart';

class OpenAiApiException implements Exception {
  const OpenAiApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Whisper (transcripción) + Speech (TTS) contra api.openai.com.
class OpenAiAudioApi {
  OpenAiAudioApi({required String apiKey})
      : _key = apiKey.trim(),
        _dio = Dio(
          BaseOptions(
            baseUrl: OpenAiConfig.apiBaseUrl,
            connectTimeout: Duration(seconds: OpenAiConfig.audioTimeoutSeconds),
            receiveTimeout: Duration(seconds: OpenAiConfig.audioTimeoutSeconds),
            sendTimeout: Duration(seconds: OpenAiConfig.audioTimeoutSeconds),
            validateStatus: (s) => s != null && s < 600,
          ),
        );

  final String _key;
  final Dio _dio;

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_key',
      };

  /// POST /audio/transcriptions (multipart).
  ///
  /// [language]:
  /// - `null`: se envía [OpenAiConfig.whisperLanguage] (p. ej. `es` para comandos).
  /// - `''`: no se envía el campo; Whisper **autodetecta** (recomendado para el barrido
  ///   de la wake phrase si mezclas idiomas).
  /// - otro valor: ISO-639-1 explícito.
  ///
  /// Si no hay voz reconocible, la API puede devolver `text` vacío: se devuelve `''`
  /// (no se lanza error; el llamador decide).
  Future<String> transcribeWavFile(
    String filePath, {
    String? language,
  }) async {
    final map = <String, dynamic>{
      'model': OpenAiConfig.whisperModel,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: 'audio.wav',
      ),
    };
    if (language == null) {
      final l = OpenAiConfig.whisperLanguage;
      if (l.isNotEmpty) {
        map['language'] = l;
      }
    } else if (language.isNotEmpty) {
      map['language'] = language;
    }

    final form = FormData.fromMap(map);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/audio/transcriptions',
        data: form,
        options: Options(
          headers: _authHeaders,
          contentType: 'multipart/form-data',
        ),
      );
      final code = res.statusCode ?? 0;
      if (code != 200) {
        throw OpenAiApiException(
          _parseError(res.data) ?? 'Transcripción rechazada ($code)',
          statusCode: code,
        );
      }
      final text = res.data?['text'] as String?;
      return (text ?? '').trim();
    } on DioException catch (e) {
      throw OpenAiApiException(_dioErr(e), statusCode: e.response?.statusCode);
    }
  }

  /// POST /audio/speech → audio MP3 (bytes).
  Future<Uint8List> synthesizeSpeech(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const OpenAiApiException('Texto vacío para TTS');
    }
    try {
      final res = await _dio.post<List<int>>(
        '/audio/speech',
        data: {
          'model': OpenAiConfig.ttsModel,
          'voice': OpenAiConfig.ttsVoice,
          'input': trimmed,
          'speed': OpenAiConfig.ttsSpeed,
          'instructions': OpenAiConfig.ttsInstructions,
          'response_format': OpenAiConfig.ttsResponseFormat,
        },
        options: Options(
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
      );
      final code = res.statusCode ?? 0;
      if (code != 200) {
        final msg = _errorMessageFromBytes(res.data);
        throw OpenAiApiException(
          msg ?? 'TTS rechazado ($code)',
          statusCode: code,
        );
      }
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw const OpenAiApiException('TTS devolvió audio vacío');
      }
      return Uint8List.fromList(bytes);
    } on DioException catch (e) {
      throw OpenAiApiException(_dioErr(e), statusCode: e.response?.statusCode);
    }
  }

  String _dioErr(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Tiempo de espera agotado con OpenAI.';
    }
    if (e.response?.statusCode == 401) {
      return 'API key de OpenAI inválida o revocada.';
    }
    final d = e.response?.data;
    if (d is Map) {
      return _parseError(d) ?? e.message ?? 'Error de red';
    }
    return e.message ?? 'Error de red';
  }

  String? _parseError(dynamic data) {
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return err['message'] as String?;
    }
    return null;
  }

  String? _errorMessageFromBytes(List<int>? data) {
    if (data == null || data.isEmpty) return null;
    try {
      final s = utf8.decode(data);
      if (s.startsWith('{')) {
        final map = jsonDecode(s);
        if (map is Map<String, dynamic>) {
          return _parseError(map);
        }
      }
    } catch (_) {}
    return null;
  }
}
